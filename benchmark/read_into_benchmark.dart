import 'dart:io';
import 'dart:typed_data';

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:files/files.dart';

class ReadIntoBenchmark extends BenchmarkBase {
  late Directory dir;
  late String path;
  final buffer = Uint8List(10 * 1024 * 1024);

  ReadIntoBenchmark(super.name);

  @override
  void setup() {
    dir = Directory.systemTemp.createTempSync('bench');
    path = '${dir.path}/file';
    File(path).writeAsBytesSync(Uint8List(10 * 1024 * 1024));
  }

  @override
  void teardown() {}
}

class PackageReadIntoBenchmark extends ReadIntoBenchmark {
  PackageReadIntoBenchmark() : super('PackageReadIntoBenchmark');

  static void main() {
    PackageReadIntoBenchmark().report();
  }

  @override
  void run() {
    final rFile = fs().open(path);
    rFile.readInto(buffer, 0, buffer.length);
    rFile.close();
  }
}

class DartIOReadIntoBenchmark extends ReadIntoBenchmark {
  DartIOReadIntoBenchmark() : super('DartIOReadIntoBenchmark');

  static void main() {
    DartIOReadIntoBenchmark().report();
  }

  // The benchmark code.
  @override
  Future run() async {
    final rFile = File(path).openSync(mode: FileMode.read);
    rFile.readIntoSync(buffer, 0, buffer.length);
    rFile.closeSync();
  }
}

void main() {
  DartIOReadIntoBenchmark.main();
  PackageReadIntoBenchmark.main();
}
