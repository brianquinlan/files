import 'dart:io';
import 'dart:typed_data';

import 'package:benchmark_harness/benchmark_harness.dart';

import 'package:files/files.dart';

class WriteStringBenchmark extends BenchmarkBase {
  late Directory dir;
  late File file;
  late String path;
  int _fileIndex = 0;

  WriteStringBenchmark(super.name);

  File nextFile() => File('${dir.path}/out${_fileIndex++}.txt');

  @override
  void setup() {
    dir = Directory.systemTemp.createTempSync('bench');
  }

  // Not measured teardown code executed after the benchmark runs.
  @override
  void teardown() {
    dir.deleteSync(recursive: true);
  }
}

class PackageWriteStringBenchmark extends WriteStringBenchmark {
  late FileSystem fileSystem;

  PackageWriteStringBenchmark() : super('PackageWriteStringBenchmark');

  static void main() {
    PackageWriteStringBenchmark().report();
  }

  @override
  void setup() {
    super.setup();
    fileSystem = fs();
  }

  @override
  void run() {
    fileSystem.writeString(nextFile().path, 'Hello',
        mode: WriteMode.failExisting);
  }
}

class DartIOWriteStringBenchmark extends WriteStringBenchmark {
  DartIOWriteStringBenchmark() : super('DartIOWriteStringBenchmark');

  static void main() {
    DartIOWriteStringBenchmark().report();
  }

  @override
  void run() {
    nextFile().writeAsStringSync('Hello', mode: FileMode.write);
  }
}

void main() {
  // Run TemplateBenchmark
  DartIOWriteStringBenchmark.main();
  PackageWriteStringBenchmark.main();
}
