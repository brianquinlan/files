import 'dart:io';
import 'package:files/files.dart';
import 'package:test/test.dart';

void main() {
  group('writeBytes', () {
    final tmp = Directory.systemTemp.createTempSync('file');

    test('write to new file', () {
      final path = '${tmp.path}/file1';
      addTearDown(File(path).deleteSync);

      fs().writeBytes(path, [1, 2, 3]);
      expect(File(path).readAsBytesSync(), [1, 2, 3]);
    });

    test('write to new file, existing', () {
      final path = '${tmp.path}/file1';
      addTearDown(File(path).deleteSync);

      fs().writeBytes(path, [1, 2, 3]);
      // Check more detailed exception state.
      expect(() => fs().writeBytes(path, [1, 2, 3]),
          throwsA(isA<FileSystemException>()));
    });
  });
}
