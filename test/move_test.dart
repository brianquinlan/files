import 'dart:io';
import 'package:files/files.dart';
import 'package:test/test.dart';

void main() {
  group('move', () {
    final tmp = Directory.systemTemp.createTempSync('move');

    test('move file', () {
      final path1 = '${tmp.path}/file1';
      final path2 = '${tmp.path}/file2';
      fs().writeString(path1, 'Hello World!');
      expect(File(path1).existsSync(), isTrue);
      fs().move(path1, path2);
      expect(File(path1).existsSync(), isFalse);
      expect(File(path2).existsSync(), isTrue);
    });
  });
}
