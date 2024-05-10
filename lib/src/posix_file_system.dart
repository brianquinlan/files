import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ffi';

import 'package:stdlibc/stdlibc.dart' as libc;
import 'package:stdlibc/src/std/ffigen.dart' as ffigen;

import 'filesystem.dart';

// POSIX error codes.
// See https://pubs.opengroup.org/onlinepubs/9699919799/basedefs/errno.h.html
const _ePerm = 1;
const _eNoEnt = 2;
const _eAccess = 13;
const _eExist = 17;

// TODO(bquinlan): make this work.
class Fd implements Finalizable {
  final int fd;

  Fd(this.fd);
  void close() {
    libc.close(fd);
  }
}

base class PosixFilesystem extends FileSystem {
  Exception _getError(String message, String path) {
    final errno = libc.errno;

    return switch (errno) {
      _ePerm => PathAccessException(path, OSError('', errno)),
      // Do less crappy error decoding.
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
  void delete(String path) {
    if (libc.unlink(path) != 0) {
      throw _getError('could not delete file', path);
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
      WriteMode.failExisting => 0, // libc.O_EXCL,
      WriteMode.truncateExisting => libc.O_TRUNC,
      _ => throw ArgumentError.value(mode, 'invalid write mode'),
    };

    final fd = Fd(_retry(() => libc.open(path, flags: flags)));
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
