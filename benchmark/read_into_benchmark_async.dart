import 'dart:io';
import 'dart:typed_data';

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:files/files.dart';

class ReadIntoBenchmark extends AsyncBenchmarkBase {
  late Directory dir;
  late String path;
  final buffer = Uint8List(10 * 1024 * 1024);

  ReadIntoBenchmark(super.name);

  @override
  Future setup() async {
    dir = Directory.systemTemp.createTempSync('bench');
    path = '${dir.path}/file';
    File(path).writeAsBytesSync(Uint8List(10 * 1024 * 1024));
  }
}

class PackageReadIntoBenchmark extends ReadIntoBenchmark {
  PackageReadIntoBenchmark() : super('PackageReadIntoBenchmark');

  static void main() {
    PackageReadIntoBenchmark().report();
  }

  @override
  Future run() async {
    final rFile = fs().open(path);
    await rFile.readIntoAsync(buffer, 0, buffer.length);
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
    await rFile.readInto(buffer, 0, buffer.length);
    rFile.closeSync();
  }
}

void main() {
  DartIOReadIntoBenchmark.main();
  PackageReadIntoBenchmark.main();
}
