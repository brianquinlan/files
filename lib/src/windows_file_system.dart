import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart' as win32;

import 'filesystem.dart';

int _open(String path, {Allocator allocator = malloc}) {
  return win32.CreateFile(
    path.toNativeUtf16(allocator: allocator),
    win32.GENERIC_ACCESS_RIGHTS.GENERIC_READ, //win32.FILE_ACCESS_RIGHTS
    //    .FILE_APPEND_DATA, // Might need write if truncating
    win32.FILE_SHARE_MODE.FILE_SHARE_READ |
        win32.FILE_SHARE_MODE.FILE_SHARE_WRITE,
    nullptr,
    win32.FILE_CREATION_DISPOSITION.OPEN_EXISTING,
    win32.FILE_FLAGS_AND_ATTRIBUTES.FILE_ATTRIBUTE_NORMAL,
    win32.NULL,
  );
}

class RandomAccessFile {
  final int fileHandle;

  RandomAccessFile._(this.fileHandle);

  factory RandomAccessFile.open(String path) {
    final fd = _open(path);
    if (fd == win32.INVALID_HANDLE_VALUE) {
      throw Exception('Open failed');
    }

    return RandomAccessFile._(fd);
  }

  int readInto(List<int> buffer, [int start = 0, int? end]) {
    final buffEnd = RangeError.checkValidRange(start, end, buffer.length);
    final numBytes = buffEnd - start;
    if (numBytes == 0) {
      return 0;
    }

    return using((arena) {
      final buffPtr = arena.allocate<Uint8>(numBytes);
      final bytesWritten = arena<win32.DWORD>();
      if (win32.ReadFile(
              fileHandle, buffPtr, numBytes, bytesWritten, nullptr) ==
          0) {
        throw Exception('did not work');
      }
      buffer.setRange(start, buffEnd, buffPtr.asTypedList(numBytes));
      return bytesWritten.value;
    });
  }
}

base class WindowsFilesystem extends FileSystem {
  Exception _getError(String message, String path) {
    // TODO: GetLastError doesn't work:
    // https://github.com/dart-windows/win32/issues/189
    final exception = win32.WindowsException(win32.GetLastError());

    return switch (exception.hr) {
      // TODO(bquinlan): Do less crappy error decoding.
      _ => FileSystemException(
          message,
          path,
          OSError(exception.convertWindowsErrorToString(exception.hr),
              exception.hr))
    };
  }

  @override
  void delete(String path) {
    using((arena) {
      if (win32.DeleteFile(path.toNativeUtf16(allocator: arena)) == 0) {
        throw _getError('could not delete', path);
      }
    });
  }

  @override
  void move(String from, String to) {
//    int flags = win32.FILE_FLAGS_AND_ATTRIBUTES.FILE_FLAG_WRITE_THROUGH;
    // TODO(bquinlan): Where is MOVEFILE_REPLACE_EXISTING?

    using((arena) {
      if (win32.MoveFile(from.toNativeUtf16(allocator: arena),
              to.toNativeUtf16(allocator: arena)) ==
          0) {
        throw _getError('could not delete', from);
      }
    });
  }

  @override
  void writeBytes(String path, List<int> bytes,
      {WriteMode mode = WriteMode.failExisting}) {
    int createFlags = 0;
    createFlags |= switch (mode) {
      WriteMode.appendExisting => 0,
      WriteMode.failExisting => win32.FILE_CREATION_DISPOSITION.CREATE_NEW,
      WriteMode.truncateExisting =>
        win32.FILE_CREATION_DISPOSITION.CREATE_ALWAYS,
      _ => throw ArgumentError.value(mode, 'invalid write mode'),
    };
    using((arena) {
      final fileHandle = win32.CreateFile(
        path.toNativeUtf16(allocator: arena),
        win32.GENERIC_ACCESS_RIGHTS.GENERIC_WRITE, //win32.FILE_ACCESS_RIGHTS
        //    .FILE_APPEND_DATA, // Might need write if truncating
        0,
        nullptr,
        createFlags,
        win32.FILE_FLAGS_AND_ATTRIBUTES.FILE_ATTRIBUTE_NORMAL,
        win32.NULL,
      );
      if (fileHandle == win32.INVALID_HANDLE_VALUE) {
        throw _getError('could not open file', path);
      }
      using((arena) {
        try {
          final buffer = arena.allocate<Uint8>(bytes.length);
          buffer.asTypedList(bytes.length).setAll(0, bytes);
          final dwBytesWritten = arena<win32.DWORD>();
          if (win32.WriteFile(fileHandle, buffer.cast(), bytes.length,
                  dwBytesWritten, nullptr) ==
              0) {
            throw _getError('could not write to file', path);
          }
        } finally {
          win32.CloseHandle(fileHandle);
        }
      });
    });
  }

  @override
  void writeString(String path, String value,
      {WriteMode mode = WriteMode.failExisting,
      Encoding encoding = utf8,
      String? lineEnding}) {
    if (lineEnding == null && lineEnding != '\n') {
      value = value.replaceAll('\n', lineEnding ?? '\r\n');
    }
    return writeBytes(path, encoding.encode(value));
  }
}
