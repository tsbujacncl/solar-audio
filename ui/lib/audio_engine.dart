import 'dart:ffi' as ffi;
import 'dart:io';
import 'package:ffi/ffi.dart';

/// FFI bindings for the Rust audio engine
class AudioEngine {
  late final ffi.DynamicLibrary _lib;
  late final _InitAudioEngineFfi _initAudioEngine;
  late final _PlaySineWaveFfi _playSineWave;
  late final _FreeRustString _freeRustString;

  AudioEngine() {
    // Load the native library
    if (Platform.isMacOS) {
      _lib = ffi.DynamicLibrary.open('../engine/target/release/libengine.dylib');
    } else if (Platform.isWindows) {
      _lib = ffi.DynamicLibrary.open('../engine/target/release/engine.dll');
    } else if (Platform.isLinux) {
      _lib = ffi.DynamicLibrary.open('../engine/target/release/libengine.so');
    } else {
      throw UnsupportedError('Unsupported platform');
    }

    // Bind functions
    _initAudioEngine = _lib
        .lookup<ffi.NativeFunction<_InitAudioEngineFfiNative>>(
            'init_audio_engine_ffi')
        .asFunction();

    _playSineWave = _lib
        .lookup<ffi.NativeFunction<_PlaySineWaveFfiNative>>(
            'play_sine_wave_ffi')
        .asFunction();

    _freeRustString = _lib
        .lookup<ffi.NativeFunction<_FreeRustStringNative>>(
            'free_rust_string')
        .asFunction();
  }

  /// Initialize the audio engine
  String initAudioEngine() {
    final resultPtr = _initAudioEngine();
    final result = resultPtr.toDartString();
    _freeRustString(resultPtr);
    return result;
  }

  /// Play a sine wave at the specified frequency
  String playSineWave(double frequency, int durationMs) {
    final resultPtr = _playSineWave(frequency, durationMs);
    final result = resultPtr.toDartString();
    _freeRustString(resultPtr);
    return result;
  }
}

// Native function type definitions
typedef _InitAudioEngineFfiNative = ffi.Pointer<Utf8> Function();
typedef _InitAudioEngineFfi = ffi.Pointer<Utf8> Function();

typedef _PlaySineWaveFfiNative = ffi.Pointer<Utf8> Function(
    ffi.Float frequency, ffi.Uint32 durationMs);
typedef _PlaySineWaveFfi = ffi.Pointer<Utf8> Function(
    double frequency, int durationMs);

typedef _FreeRustStringNative = ffi.Void Function(ffi.Pointer<Utf8>);
typedef _FreeRustString = void Function(ffi.Pointer<Utf8>);

// Extension to convert C strings to Dart strings
extension on ffi.Pointer<Utf8> {
  String toDartString() {
    return cast<ffi.Utf8>().toDartString();
  }
}

