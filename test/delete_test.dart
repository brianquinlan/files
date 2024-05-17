import 'dart:io';
import 'package:files/files.dart';
import 'package:test/test.dart';

void main() {
  group('move', () {
    final tmp = Directory.systemTemp.createTempSync('delete');

    test('delete file', () {
      final path = '${tmp.path}/file1';
      fs().writeString(path, 'Hello World!');
      expect(File(path).existsSync(), isTrue);
      fs().delete(path);
      expect(FileSystemEntity.typeSync(path), FileSystemEntityType.notFound);
    });
  });
}
