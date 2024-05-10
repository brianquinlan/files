import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart' as win32;

import 'filesystem.dart';

base class WindowsFilesystem extends FileSystem {
  @override
  void delete(String path) {
    using((arena) {
      if (win32.DeleteFile(path.toNativeUtf16(allocator: arena)) == 0) {}
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
        win32.FILE_ACCESS_RIGHTS
            .FILE_APPEND_DATA, // Might need write if truncating
        0,
        nullptr,
        createFlags,
        win32.FILE_FLAGS_AND_ATTRIBUTES.FILE_ATTRIBUTE_NORMAL,
        win32.NULL,
      );
      final buffer = arena.allocate<Uint8>(bytes.length);
      buffer.asTypedList(bytes.length).setAll(0, bytes);
      final dwBytesWritten = arena<win32.DWORD>();
      win32.WriteFile(
          fileHandle, buffer.cast(), bytes.length, dwBytesWritten, nullptr);
    });
  }
}
