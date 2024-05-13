import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'posix_file_system.dart';
import 'windows_file_system.dart';

class WriteMode {
  static const appendExisting = WriteMode._(1);
  static const truncateExisting = WriteMode._(2);
  static const failExisting = WriteMode._(3);

  final int _mode;
  const WriteMode._(this._mode);

  @override
  bool operator ==(Object other) => other is WriteMode && _mode == other._mode;

  @override
  int get hashCode => _mode.hashCode;
}

mixin Writer on MinWriter {
  Future<void> writeLn() async {
    writeString("\n");
  }
}

abstract interface class MinWriter {
  Future<void> writeString(String s);
  Future<void> writeBytes(Uint8List l);
  Future<void> writeStringSync(String s);
  Future<void> writeBytesSync(Uint8List l);
}

late Writer w;

base class FileSystem {
  void delete(String path) {
    throw UnimplementedError('delete(...)');
  }

  bool isFile(String path, {bool resolveSymlinks = true}) {
    throw UnimplementedError('isFile(...)');
  }

  void openWrite(path) {}

  // If the target is a symlink, delete the symlink. If the target is a
  // directory, its an error.
  void rename(String oldName, String newName) {
    throw UnimplementedError('rename(...)');
  }

  void writeBytes(String path, List<int> bytes,
      {WriteMode mode = WriteMode.failExisting}) {
    throw UnimplementedError('writeBytes(...)');
  }

  void writeString(String path, String value,
      {WriteMode mode = WriteMode.failExisting,
      Encoding encoding = utf8,
      String? lineEnding}) {
    throw UnimplementedError('writeString(...)');
  }
}

FileSystem fs() {
  if (Platform.isWindows) {
    return WindowsFilesystem();
  }
  return PosixFilesystem();
}