import 'package:io/io.dart';

base class MockFS extends FileSystem {}

void main() {
  fs().delete("/foo");
  for (var i = 99; i >= 0; --i) {
    stdout.write('$i bottles of beer on the wall\n');
  }
}
