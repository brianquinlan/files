import 'dart:io';
import 'dart:typed_data';
import 'package:files/files.dart';
import 'package:test/test.dart';

void main() {
  group('read_into_sync', () {
    late String tmp;

    setUp(() => tmp = Directory.systemTemp.createTempSync('move').path);
    tearDown(() => Directory(tmp).deleteSync(recursive: true));

    test('read exact file length', () {
      final path = '$tmp/file1';
      final contents = List.generate(256, (i) => i % 256);
      fs().writeBytes(path, contents);

      final file = fs().open(path);
      final buffer = Uint8List(256);
      final read = file.readInto(buffer, 0, buffer.length);
      expect(read, 256);
      expect(buffer, contents);
      file.close();
    });

    test('read past end-of-file', () {
      final path = '$tmp/file1';
      fs().writeBytes(path, List.generate(10, (i) => i % 256));

      final file = fs().open(path);
      final buffer = Uint8List(15);
      int read = file.readInto(buffer, 0, buffer.length);
      expect(read, 10);
      expect(buffer.sublist(0, 10), [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]);
      file.close();
    });
  });
}
