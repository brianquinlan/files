import 'dart:io';
import 'package:files/files.dart';
import 'package:test/test.dart';

void main() {
  group('move', () {
    final tmp = Directory.systemTemp.createTempSync('file');

    test('delete file', () {
      final path = '${tmp.path}/file1';
      fs().writeString(path, 'Hello World!');
      expect(File(path).readAsBytesSync(), 'Hello World');
      fs().delete(path);
      expect(FileSystemEntity.typeSync(path), FileSystemEntityType.notFound);
    });
  });
}
