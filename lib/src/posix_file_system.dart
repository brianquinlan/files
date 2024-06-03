import 'dart:convert';
import 'dart:io';
import 'dart:ffi';

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

base class PosixRFile extends RFile {
  final Fd fd;

  PosixRFile(this.fd);

  @override
  int readInto(List<int> buffer, [int start = 0, int? end]) {
    end = RangeError.checkValidRange(start, end, buffer.length);
    if (end == start) {
      return 0;
    }
    final count = end - start;
    final readBytes = libc.read(fd.fd, count);
//    buffer.setAll(start, readBytes);
    return readBytes.length;
  }

  @override
  void close() {
    fd.close();
  }
}

base class PosixFilesystem extends FileSystem {
  Exception _getError(String message, String path) {
    final errno = libc.errno;

    return switch (errno) {
      _ePerm => PathAccessException(path, OSError('', errno)),
      // TODO(bquinlan): Do less crappy error decoding.
      _ => FileSystemException(message, path, OSError('', errno))
    };
  }

  int _retry(int Function() f) {
    int result;
    do {
      result = f();
    } while (result == -1 && libc.errno == libc.EINTR);
    return result;
  }

  @override
  RFile open(String path, {WriteMode mode = WriteMode.appendExisting}) {
    int flags = libc.O_RDONLY;

    final fd =
        Fd(_retry(() => libc.open(path, flags: flags, mode: 438 // Octal: 666
            )));
    if (fd.fd == -1) {
      throw _getError('could not open file', path);
    }
    return PosixRFile(fd);
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
    final fd =
        Fd(_retry(() => libc.open(path, flags: flags, mode: 438 // Octal: 666
            )));
    if (fd.fd == -1) {
      throw _getError('could not open file', path);
    }
    try {
      if (_retry(() => libc.write(fd.fd, bytes)) == -1) {
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
