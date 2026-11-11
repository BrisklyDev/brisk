import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;

typedef _StartNative = Uint64 Function(Pointer<Utf8> config);
typedef _StartDart = int Function(Pointer<Utf8> config);
typedef _CommandNative = Int32 Function(Uint64 handle, Int32 command);
typedef _CommandDart = int Function(int handle, int command);
typedef _PollNative = Pointer<Utf8> Function(Uint64 handle);
typedef _PollDart = Pointer<Utf8> Function(int handle);
typedef _SetSpeedLimitNative = Int32 Function(Uint64 handle, Int64 bytesPerSec);
typedef _SetSpeedLimitDart = int Function(int handle, int bytesPerSec);
typedef _DisposeNative = Void Function(Uint64 handle);
typedef _DisposeDart = void Function(int handle);
typedef _FreeNative = Void Function(Pointer<Utf8> ptr);
typedef _FreeDart = void Function(Pointer<Utf8> ptr);
typedef _LastErrorNative = Pointer<Utf8> Function();
typedef _ApiVersionNative = Int32 Function();
typedef _ApiVersionDart = int Function();

/// Low level bindings of the kasma C API (see `kasma_engine/rust/src/ffi.rs`).
class KasmaBindings {
  static const supportedApiVersion = 3;

  static const commandPause = 0;
  static const commandResume = 1;
  static const commandTerminate = 2;

  static KasmaBindings? _instance;
  static bool _loadAttempted = false;

  static String? loadError;

  final _StartDart _start;
  final _CommandDart _command;
  final _SetSpeedLimitDart _setSpeedLimit;
  final _PollDart _poll;
  final _DisposeDart _dispose;
  final _FreeDart _free;
  final _LastErrorNative _lastError;

  KasmaBindings._(DynamicLibrary lib)
      : _start = lib.lookupFunction<_StartNative, _StartDart>('kasma_start'),
        _command =
            lib.lookupFunction<_CommandNative, _CommandDart>('kasma_command'),
        _setSpeedLimit =
            lib.lookupFunction<_SetSpeedLimitNative, _SetSpeedLimitDart>(
                'kasma_set_speed_limit'),
        _poll = lib.lookupFunction<_PollNative, _PollDart>('kasma_poll'),
        _dispose =
            lib.lookupFunction<_DisposeNative, _DisposeDart>('kasma_dispose'),
        _free = lib.lookupFunction<_FreeNative, _FreeDart>('kasma_free_string'),
        _lastError = lib.lookupFunction<_LastErrorNative, _LastErrorNative>(
          'kasma_last_error',
        );

  static KasmaBindings? get instance {
    if (_loadAttempted) return _instance;
    _loadAttempted = true;
    try {
      final lib = _openLibrary();
      final version = lib.lookupFunction<_ApiVersionNative, _ApiVersionDart>(
        'kasma_api_version',
      )();
      if (version != supportedApiVersion) {
        loadError = "Unsupported kasma API version $version "
            "(expected $supportedApiVersion)";
        return null;
      }
      _instance = KasmaBindings._(lib);
    } catch (e) {
      loadError = e.toString();
    }
    return _instance;
  }

  static DynamicLibrary _openLibrary() {
    final candidates = <String>[];
    final override = Platform.environment['KASMA_LIBRARY_PATH'];
    if (override != null && override.isNotEmpty) {
      candidates.add(override);
    }
    final exeDir = p.dirname(Platform.resolvedExecutable);
    if (Platform.isLinux) {
      candidates
        ..add('libkasma.so')
        ..add(p.join(exeDir, 'lib', 'libkasma.so'));
    } else if (Platform.isWindows) {
      candidates
        ..add('kasma.dll')
        ..add(p.join(exeDir, 'kasma.dll'));
    } else if (Platform.isMacOS) {
      // Statically linked into the kasma_engine pod framework
      final process = DynamicLibrary.process();
      if (process.providesSymbol('kasma_start')) return process;
      candidates
        ..add('kasma_engine.framework/kasma_engine')
        ..add(p.join(exeDir, '..', 'Frameworks', 'kasma_engine.framework',
            'kasma_engine'));
    }
    Object? lastError;
    for (final candidate in candidates) {
      try {
        return DynamicLibrary.open(candidate);
      } catch (e) {
        lastError = e;
      }
    }
    throw lastError ?? UnsupportedError('kasma is not supported on this OS');
  }

  int start(String configJson) {
    final ptr = configJson.toNativeUtf8();
    try {
      return _start(ptr);
    } finally {
      malloc.free(ptr);
    }
  }

  int command(int handle, int command) => _command(handle, command);

  /// Changes the speed limit of a running download. [bytesPerSec] <= 0 removes the limit.
  /// Returns 0 on success, -1 if the handle is unknown, -3 if the engine has stopped.
  int setSpeedLimit(int handle, int bytesPerSec) =>
      _setSpeedLimit(handle, bytesPerSec);

  String? poll(int handle) => _takeString(_poll(handle));

  void dispose(int handle) => _dispose(handle);

  String? lastError() => _takeString(_lastError());

  String? _takeString(Pointer<Utf8> ptr) {
    if (ptr == nullptr) return null;
    try {
      return ptr.toDartString();
    } finally {
      _free(ptr);
    }
  }
}
