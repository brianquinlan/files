import 'dart:async';
import 'dart:concurrent';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

Uint8List readAsBytesSync(String path) {
  return File(path).readAsBytesSync();
}

const maxWorkers = 8;

@pragma('vm:shared')
final workQueueMutex = Mutex();

@pragma('vm:shared')
final workQueueCondition = ConditionVariable();

@pragma('vm:shared')
final resultsMutex = Mutex();

@pragma('vm:shared')
final workerCountMutex = Mutex();

@pragma('vm:shared')
final workqueue = <(int, SendPort, Object)>[];

@pragma('vm:shared')
int nextResult = 0;

@pragma('vm:shared')
final results = <int, Object>{};

@pragma('vm:shared')
int numWorkers = 0;
void maybeStartNewWorker() {
  if (numWorkers < maxWorkers) {
    final workerNumber = workerCountMutex.runLocked(() => ++numWorkers);
    Isolate.run(() => worker(workerNumber));
  }
}

final ports = <(SendPort, StreamSubscription<dynamic>)>[];

(SendPort, StreamSubscription<dynamic>) getPorts() {
  if (ports.isEmpty) {
    final p = ReceivePort();
    return (
      p.sendPort,
      p.listen((_) {
        print('???');
      })
    );
  } else {
    return ports.removeLast();
  }
}

void returnPorts(SendPort port, StreamSubscription s) {
  ports.add((port, s));
  if (workqueue.isEmpty && results.isEmpty) {
    // If there is no work to do, empty the port list.
    for (var (_, stream) in ports) {
      stream.cancel();
    }
    ports.clear();
  }
}

Future<Uint8List> readAsBytes(String path) {
  final c = Completer<Uint8List>();
  final (port, subscription) = getPorts();
  subscription.onData((k) {
    final result = resultsMutex.runLocked(() {
      return results.remove(k) as Uint8List;
    });
    returnPorts(port, subscription);
    c.complete(result);
  });
  workQueueMutex.runLocked(() {
    workqueue.add((1, port, path));
    workQueueCondition.notify();
  });
  maybeStartNewWorker();
  return c.future;
}

void worker(int num) {
  print('Worker($num) started');
  while (true) {
    int type;
    SendPort port;
    Object args;
    try {
      (type, port, args) = workQueueMutex.runLocked(() {
        while (workqueue.isEmpty) {
          // This needs a timeout.
          workQueueCondition.wait(workQueueMutex);
        }
        return workqueue.removeLast();
      });
    } on RangeError {
      workerCountMutex.runLocked(() => --numWorkers);
      break;
    }
    switch ((type, args)) {
      case (1, String path):
        final data = readAsBytesSync(path);
        late final int resultIndex;
        resultsMutex.runLocked(() {
          resultIndex = nextResult;
          results[resultIndex] = data;
          ++nextResult;
        });
        port.send(resultIndex);
      case (_, _):
        print('Unexpected operation: $type: $args');
    }
  }
}

void main() async {
  // Read the file 1000 times sequentially but async.
  final start = DateTime.now();
  for (int i = 0; i < 1000; ++i) {
    await readAsBytes("test.txt");
  }
  print('Done loop: ${(DateTime.now().difference(start)).inMilliseconds}');

  // Read the file 100 times concurrently.
  final start2 = DateTime.now();
  final f = [for (var i = 0; i < 100; ++i) readAsBytes("test.txt")];
  await Future.wait(f);
  print('Done loop2: ${(DateTime.now().difference(start2)).inMilliseconds}');
}
