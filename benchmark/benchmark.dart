import 'dart:io';
import 'dart:typed_data';

import 'package:benchmark_harness/benchmark_harness.dart';

import 'package:files/src/windows_file_system.dart';

class ReadBenchmark extends AsyncBenchmarkBase {
  late Directory dir;
  late String path;

  ReadBenchmark(super.name);

  @override
  Future setup() async {
    dir = Directory.systemTemp.createTempSync('bench');
    path = '${dir.path}\\file';
    final f = File(path).openWrite();
    f.write(Uint8List(10 * 1024 * 1024));
    await f.flush();
    await f.close();
  }

  // Not measured teardown code executed after the benchmark runs.
  @override
  Future teardown() async {}
}

class PackageReadIntoBenchmark extends ReadBenchmark {
  PackageReadIntoBenchmark() : super('PackageReadIntoBenchmark');

  static void main() {
    PackageReadIntoBenchmark().report();
  }

  // The benchmark code.
  @override
  Future run() async {
    final file = RandomAccessFile.open(path);
    final buffer = Uint8List(10 * 1024 * 1024);
    file.readInto(buffer, 0, 10 * 1024 * 1024);
  }
}

class DartIOReadIntoBenchmark extends ReadBenchmark {
  DartIOReadIntoBenchmark() : super('DartIOReadIntoBenchmark');

  static void main() {
    DartIOReadIntoBenchmark().report();
  }

  // The benchmark code.
  @override
  Future run() async {
    final file = File(path).openSync();
    final buffer = Uint8List(10 * 1024 * 1024);
    file.readInto(buffer, 0, 10 * 1024 * 1024);
  }
}

void main() {
  // Run TemplateBenchmark
  DartIOReadIntoBenchmark.main();
  PackageReadIntoBenchmark.main();
}
