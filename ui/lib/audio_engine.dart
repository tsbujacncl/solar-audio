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
    // For M0, we use absolute path. In M1, we'll bundle the library properly.
    if (Platform.isMacOS) {
      final libPath = '/Users/tyrbujac/Documents/Developments/2025/Flutter/Solar Audio/engine/target/release/libengine.dylib';
      print('🔍 [AudioEngine] Attempting to load library from: $libPath');
      
      // Check if file exists
      final file = File(libPath);
      if (file.existsSync()) {
        print('✅ [AudioEngine] Library file exists');
      } else {
        print('❌ [AudioEngine] Library file NOT found!');
        throw Exception('Library file not found at: $libPath');
      }
      
      try {
        _lib = ffi.DynamicLibrary.open(libPath);
        print('✅ [AudioEngine] Library loaded successfully');
      } catch (e) {
        print('❌ [AudioEngine] Failed to load library: $e');
        rethrow;
      }
    } else if (Platform.isWindows) {
      _lib = ffi.DynamicLibrary.open('../engine/target/release/engine.dll');
    } else if (Platform.isLinux) {
      _lib = ffi.DynamicLibrary.open('../engine/target/release/libengine.so');
    } else {
      throw UnsupportedError('Unsupported platform');
    }

    // Bind functions
    print('🔗 [AudioEngine] Binding FFI functions...');
    try {
      _initAudioEngine = _lib
          .lookup<ffi.NativeFunction<_InitAudioEngineFfiNative>>(
              'init_audio_engine_ffi')
          .asFunction();
      print('  ✅ init_audio_engine_ffi bound');

      _playSineWave = _lib
          .lookup<ffi.NativeFunction<_PlaySineWaveFfiNative>>(
              'play_sine_wave_ffi')
          .asFunction();
      print('  ✅ play_sine_wave_ffi bound');

      _freeRustString = _lib
          .lookup<ffi.NativeFunction<_FreeRustStringNative>>(
              'free_rust_string')
          .asFunction();
      print('  ✅ free_rust_string bound');
      
      print('✅ [AudioEngine] All functions bound successfully');
    } catch (e) {
      print('❌ [AudioEngine] Failed to bind functions: $e');
      rethrow;
    }
  }

  /// Initialize the audio engine
  String initAudioEngine() {
    print('🎵 [AudioEngine] Calling initAudioEngine...');
    try {
      final resultPtr = _initAudioEngine();
      final result = resultPtr.toDartString();
      _freeRustString(resultPtr);
      print('✅ [AudioEngine] Init result: $result');
      return result;
    } catch (e) {
      print('❌ [AudioEngine] Init failed: $e');
      rethrow;
    }
  }

  /// Play a sine wave at the specified frequency
  String playSineWave(double frequency, int durationMs) {
    print('🔊 [AudioEngine] Playing sine wave: $frequency Hz for $durationMs ms');
    try {
      final resultPtr = _playSineWave(frequency, durationMs);
      final result = resultPtr.toDartString();
      _freeRustString(resultPtr);
      print('✅ [AudioEngine] Play result: $result');
      return result;
    } catch (e) {
      print('❌ [AudioEngine] Play failed: $e');
      rethrow;
    }
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

