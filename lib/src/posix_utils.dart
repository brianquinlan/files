import 'dart:ffi';

import 'package:ffi/ffi.dart';

sealed class Mutex {
  Mutex._();

  factory Mutex() => PosixMutex();

  factory Mutex.fromAddress(int address) => PosixMutex.fromAddress(address);

  int get rawAddress;

  void lock();

  void unlock();

  R holdingLock<R>(R Function() action) {
    lock();
    try {
      return action();
    } finally {
      unlock();
    }
  }
}

//
// POSIX threading primitives
//

/// Represents `pthread_mutex_t`
final class PthreadMutex extends Opaque {}

/// Represents `pthread_cond_t`
final class PthreadCond extends Opaque {}

@Native<Int Function(Pointer<PthreadMutex>, Pointer<Void>)>()
external int pthread_mutex_init(
    Pointer<PthreadMutex> mutex, Pointer<Void> attrs);

@Native<Int Function(Pointer<PthreadMutex>)>()
external int pthread_mutex_lock(Pointer<PthreadMutex> mutex);

@Native<Int Function(Pointer<PthreadMutex>)>()
external int pthread_mutex_unlock(Pointer<PthreadMutex> mutex);

@Native<Int Function(Pointer<PthreadMutex>)>()
external int pthread_mutex_destroy(Pointer<PthreadMutex> cond);

@Native<Int Function(Pointer<PthreadCond>, Pointer<Void>)>()
external int pthread_cond_init(Pointer<PthreadCond> cond, Pointer<Void> attrs);

@Native<Int Function(Pointer<PthreadCond>, Pointer<PthreadMutex>)>()
external int pthread_cond_wait(
    Pointer<PthreadCond> cond, Pointer<PthreadMutex> mutex);

@Native<Int Function(Pointer<PthreadCond>)>()
external int pthread_cond_destroy(Pointer<PthreadCond> cond);

@Native<Int Function(Pointer<PthreadCond>)>()
external int pthread_cond_signal(Pointer<PthreadCond> cond);

class PosixMutex extends Mutex {
  static const _sizeInBytes = 64;

  final Pointer<PthreadMutex> _impl;

  // TODO(@mraleph) this should be a native finalizer, also we probably want to
  // do reference counting on the mutex so that the last owner destroys it.
  static final _finalizer = Finalizer<Pointer<PthreadMutex>>((ptr) {
    pthread_mutex_destroy(ptr);
    calloc.free(ptr);
  });

  PosixMutex()
      : _impl = calloc.allocate(PosixMutex._sizeInBytes),
        super._() {
    if (pthread_mutex_init(_impl, nullptr) != 0) {
      calloc.free(_impl);
      throw StateError('failed to initialize mutex');
    }
    _finalizer.attach(this, _impl);
  }

  PosixMutex.fromAddress(int address)
      : _impl = Pointer.fromAddress(address),
        super._();

  @override
  void lock() {
    if (pthread_mutex_lock(_impl) != 0) {
      throw StateError('failed to lock mutex');
    }
  }

  @override
  void unlock() {
    if (pthread_mutex_unlock(_impl) != 0) {
      throw StateError('failed to unlock mutex');
    }
  }

  @override
  int get rawAddress => _impl.address;
}
