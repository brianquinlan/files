import 'dart:convert';
import 'dart:io';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';
import 'package:ffi/ffi.dart' as ffi;
import 'package:files/src/posix_utils.dart';
import 'package:stdlibc/stdlibc.dart' as libc;

import 'filesystem.dart';

// POSIX error codes.
// See https://pubs.opengroup.org/onlinepubs/9699919799/basedefs/errno.h.html
//
// TODO(bquinlan): Investigate getting these codes from `package:stdlibc`
const _ePerm = 1;

// TODO(bquinlan): Make this work.
//
// The problem is that native finalizers consume a `void *` but file descriptors
// are `int`. On some platforms (e.g. Android), sizeof(void *) != sizeof(int).
class Fd implements Finalizable {
  final int fd;

  Fd(this.fd);
  void close() {
    libc.close(fd);
  }
}

/// The POSIX `read` function.
///
/// See https://pubs.opengroup.org/onlinepubs/9699919799/functions/read.html
@Native<Int Function(Int, Pointer<Uint8>, Int)>(isLeaf: true)
external int read(int fd, Pointer<Uint8> buf, int count);

int _tempFailureRetry(int Function() f) {
  int result;
  do {
    result = f();
  } while (result == -1 && libc.errno == libc.EINTR);
  return result;
}

Exception _getError(String message, String path) {
  final errno = libc.errno;

  return switch (errno) {
    _ePerm => PathAccessException(path, OSError('', errno)),
    // TODO(bquinlan): Do less crappy error decoding.
    _ => FileSystemException(message, path, OSError('', errno))
  };
}

int _readInto(int fd, List<int> buffer, [int start = 0, int? end]) {
  end = RangeError.checkValidRange(start, end, buffer.length);
  if (end == start) {
    return 0;
  }
  final count = end - start;
  late int r;
  if (buffer is Uint8List) {
    // This approach is also used in `dart:io` but the consequence is that
    // GC cannot be performed while the `read` call is outstanding.
    r = _tempFailureRetry(() => read(fd, buffer.address, count));
  } else {
    ffi.using((arena) {
      final buf = arena<Int8>(count);
      r = _tempFailureRetry(() => read(fd, buf.cast(), count));
      buffer.setAll(0, buf.asTypedList(r));
    });
  }

  if (r == -1) {
    // Handle errors!
  }
  return r;
}

/// The data needed to make call `readInto`.
///
/// I'm not sure that I like have this class as a pure data container.
class _ReadIntoWork {
  int fd;
  Uint8List buffer;
  int start;
  int? end;

  _ReadIntoWork(this.fd, this.buffer, this.start, this.end);
}

@pragma('vm:shared')
final mutex = Mutex();

@pragma('vm:shared')
final _work = <Object, Object>{};

base class PosixRandomAccessFile extends RandomAccessFile {
  final Fd fd;

  PosixRandomAccessFile(this.fd);

  @override
  Future<int> readIntoAsync(List<int> buffer, [int start = 0, int? end]) {
    if (buffer is TypedData) {
      // Presumably TypedData is safe for multithreaded access.
      mutex.lock();
      final index = Object();
      _work[index] = _ReadIntoWork(
          fd.fd, (buffer as TypedData).buffer.asUint8List(), start, end);
      mutex.unlock();

      return Isolate.run(() {
        mutex.lock();
        final w = _work.remove(index) as _ReadIntoWork;
        mutex.unlock();
        return _readInto(w.fd, w.buffer, w.start, w.end);
      });
    } else {
      // List<int> may not be safe to share so do a slower/safer code path here.
      // I think that the trick would be to *not* copy the buffer to the isolate
      // and only transfer the data actual read back. This function can merge
      // the original list with the read data.
      throw UnimplementedError('sorry, only TypedData is supported for now');
    }
  }

  @override
  int readInto(List<int> buffer, [int start = 0, int? end]) {
    return _readInto(fd.fd, buffer, start, end);
  }

  @override
  void close() {
    fd.close();
  }
}

base class PosixFilesystem extends FileSystem {
  @override
  RandomAccessFile open(String path,
      {WriteMode mode = WriteMode.appendExisting}) {
    int flags = libc.O_RDONLY;

    final fd = Fd(_tempFailureRetry(
        () => libc.open(path, flags: flags, mode: 438 // Octal: 666
            )));
    if (fd.fd == -1) {
      throw _getError('could not open file', path);
    }
    return PosixRandomAccessFile(fd);
  }

  @override
  void delete(String path) {
    if (libc.unlink(path) != 0) {
      throw _getError('could not delete file', path);
    }
  }

  @override
  void move(String from, String to) {
    if (libc.rename(from, to) != 0) {
      throw _getError('could not move file', to);
    }
  }

  @override
  bool isFile(String path, {bool resolveSymlinks = true}) {
    final stat = resolveSymlinks ? libc.stat(path) : libc.lstat(path);
    if (stat == null) {
      throw _getError('could not stat file', path);
    }
    return stat.st_mode & libc.S_IFMT == libc.S_IFREG;
  }

  @override
  void writeBytes(String path, List<int> bytes,
      {WriteMode mode = WriteMode.failExisting}) {
    int flags = libc.O_RDWR | libc.O_CREAT;
    flags |= switch (mode) {
      WriteMode.appendExisting => libc.O_APPEND,
      WriteMode.failExisting => libc.O_EXCL,
      WriteMode.truncateExisting => libc.O_TRUNC,
      _ => throw ArgumentError.value(mode, 'invalid write mode'),
    };

    // Pass 0x666 when https://github.com/canonical/stdlibc.dart/pull/121 lands.
    final fd = Fd(_tempFailureRetry(
        () => libc.open(path, flags: flags, mode: 438 // Octal: 666
            )));
    if (fd.fd == -1) {
      throw _getError('could not open file', path);
    }
    try {
      if (_tempFailureRetry(() => libc.write(fd.fd, bytes)) == -1) {
        throw _getError('could not write to file', path);
      }
    } finally {
      fd.close();
    }
  }

  @override
  void writeString(String path, String value,
      {WriteMode mode = WriteMode.failExisting,
      Encoding encoding = utf8,
      String? lineEnding}) {
    if (lineEnding != null && lineEnding != '\n') {
      value = value.replaceAll('\n', lineEnding);
    }
    return writeBytes(path, encoding.encode(value));
  }
}
