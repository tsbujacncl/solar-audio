import 'dart:ffi' as ffi;
import 'dart:io';
import 'package:ffi/ffi.dart';

/// FFI bindings for the Rust audio engine
class AudioEngine {
  late final ffi.DynamicLibrary _lib;
  
  // M0 functions
  late final _InitAudioEngineFfi _initAudioEngine;
  late final _PlaySineWaveFfi _playSineWave;
  late final _FreeRustString _freeRustString;
  
  // M1 functions
  late final _InitAudioGraphFfi _initAudioGraph;
  late final _LoadAudioFileFfi _loadAudioFile;
  late final _TransportPlayFfi _transportPlay;
  late final _TransportPauseFfi _transportPause;
  late final _TransportStopFfi _transportStop;
  late final _TransportSeekFfi _transportSeek;
  late final _GetPlayheadPositionFfi _getPlayheadPosition;
  late final _GetTransportStateFfi _getTransportState;
  late final _GetClipDurationFfi _getClipDuration;
  late final _GetWaveformPeaksFfi _getWaveformPeaks;
  late final _FreeWaveformPeaksFfi _freeWaveformPeaks;

  AudioEngine() {
    // Load the native library
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

    // Bind M0 functions
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
      
      // Bind M1 functions
      _initAudioGraph = _lib
          .lookup<ffi.NativeFunction<_InitAudioGraphFfiNative>>(
              'init_audio_graph_ffi')
          .asFunction();
      print('  ✅ init_audio_graph_ffi bound');
      
      _loadAudioFile = _lib
          .lookup<ffi.NativeFunction<_LoadAudioFileFfiNative>>(
              'load_audio_file_ffi')
          .asFunction();
      print('  ✅ load_audio_file_ffi bound');
      
      _transportPlay = _lib
          .lookup<ffi.NativeFunction<_TransportPlayFfiNative>>(
              'transport_play_ffi')
          .asFunction();
      print('  ✅ transport_play_ffi bound');
      
      _transportPause = _lib
          .lookup<ffi.NativeFunction<_TransportPauseFfiNative>>(
              'transport_pause_ffi')
          .asFunction();
      print('  ✅ transport_pause_ffi bound');
      
      _transportStop = _lib
          .lookup<ffi.NativeFunction<_TransportStopFfiNative>>(
              'transport_stop_ffi')
          .asFunction();
      print('  ✅ transport_stop_ffi bound');
      
      _transportSeek = _lib
          .lookup<ffi.NativeFunction<_TransportSeekFfiNative>>(
              'transport_seek_ffi')
          .asFunction();
      print('  ✅ transport_seek_ffi bound');
      
      _getPlayheadPosition = _lib
          .lookup<ffi.NativeFunction<_GetPlayheadPositionFfiNative>>(
              'get_playhead_position_ffi')
          .asFunction();
      print('  ✅ get_playhead_position_ffi bound');
      
      _getTransportState = _lib
          .lookup<ffi.NativeFunction<_GetTransportStateFfiNative>>(
              'get_transport_state_ffi')
          .asFunction();
      print('  ✅ get_transport_state_ffi bound');
      
      _getClipDuration = _lib
          .lookup<ffi.NativeFunction<_GetClipDurationFfiNative>>(
              'get_clip_duration_ffi')
          .asFunction();
      print('  ✅ get_clip_duration_ffi bound');
      
      _getWaveformPeaks = _lib
          .lookup<ffi.NativeFunction<_GetWaveformPeaksFfiNative>>(
              'get_waveform_peaks_ffi')
          .asFunction();
      print('  ✅ get_waveform_peaks_ffi bound');
      
      _freeWaveformPeaks = _lib
          .lookup<ffi.NativeFunction<_FreeWaveformPeaksFfiNative>>(
              'free_waveform_peaks_ffi')
          .asFunction();
      print('  ✅ free_waveform_peaks_ffi bound');
      
      print('✅ [AudioEngine] All functions bound successfully');
    } catch (e) {
      print('❌ [AudioEngine] Failed to bind functions: $e');
      rethrow;
    }
  }

  // ========================================================================
  // M0 API
  // ========================================================================

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

  // ========================================================================
  // M1 API
  // ========================================================================

  /// Initialize the audio graph
  String initAudioGraph() {
    print('🎵 [AudioEngine] Initializing audio graph...');
    try {
      final resultPtr = _initAudioGraph();
      final result = resultPtr.toDartString();
      _freeRustString(resultPtr);
      print('✅ [AudioEngine] Audio graph initialized: $result');
      return result;
    } catch (e) {
      print('❌ [AudioEngine] Audio graph init failed: $e');
      rethrow;
    }
  }

  /// Load an audio file and return clip ID (-1 on error)
  int loadAudioFile(String path) {
    print('📂 [AudioEngine] Loading audio file: $path');
    try {
      final pathPtr = path.toNativeUtf8();
      final clipId = _loadAudioFile(pathPtr.cast());
      malloc.free(pathPtr);
      
      if (clipId < 0) {
        print('❌ [AudioEngine] Failed to load audio file');
        return -1;
      }
      
      print('✅ [AudioEngine] Audio file loaded, clip ID: $clipId');
      return clipId;
    } catch (e) {
      print('❌ [AudioEngine] Load audio file failed: $e');
      rethrow;
    }
  }

  /// Start playback
  String transportPlay() {
    print('▶️  [AudioEngine] Starting playback...');
    try {
      final resultPtr = _transportPlay();
      final result = resultPtr.toDartString();
      _freeRustString(resultPtr);
      print('✅ [AudioEngine] $result');
      return result;
    } catch (e) {
      print('❌ [AudioEngine] Play failed: $e');
      rethrow;
    }
  }

  /// Pause playback
  String transportPause() {
    print('⏸️  [AudioEngine] Pausing playback...');
    try {
      final resultPtr = _transportPause();
      final result = resultPtr.toDartString();
      _freeRustString(resultPtr);
      print('✅ [AudioEngine] $result');
      return result;
    } catch (e) {
      print('❌ [AudioEngine] Pause failed: $e');
      rethrow;
    }
  }

  /// Stop playback
  String transportStop() {
    print('⏹️  [AudioEngine] Stopping playback...');
    try {
      final resultPtr = _transportStop();
      final result = resultPtr.toDartString();
      _freeRustString(resultPtr);
      print('✅ [AudioEngine] $result');
      return result;
    } catch (e) {
      print('❌ [AudioEngine] Stop failed: $e');
      rethrow;
    }
  }

  /// Seek to position in seconds
  String transportSeek(double positionSeconds) {
    print('⏩ [AudioEngine] Seeking to $positionSeconds seconds...');
    try {
      final resultPtr = _transportSeek(positionSeconds);
      final result = resultPtr.toDartString();
      _freeRustString(resultPtr);
      print('✅ [AudioEngine] $result');
      return result;
    } catch (e) {
      print('❌ [AudioEngine] Seek failed: $e');
      rethrow;
    }
  }

  /// Get current playhead position in seconds
  double getPlayheadPosition() {
    try {
      return _getPlayheadPosition();
    } catch (e) {
      print('❌ [AudioEngine] Get playhead position failed: $e');
      return 0.0;
    }
  }

  /// Get transport state (0=Stopped, 1=Playing, 2=Paused)
  int getTransportState() {
    try {
      return _getTransportState();
    } catch (e) {
      print('❌ [AudioEngine] Get transport state failed: $e');
      return 0;
    }
  }

  /// Get clip duration in seconds
  double getClipDuration(int clipId) {
    try {
      return _getClipDuration(clipId);
    } catch (e) {
      print('❌ [AudioEngine] Get clip duration failed: $e');
      return 0.0;
    }
  }

  /// Get waveform peaks for visualization
  List<double> getWaveformPeaks(int clipId, int resolution) {
    print('📊 [AudioEngine] Getting waveform peaks (resolution: $resolution)...');
    try {
      final lengthPtr = malloc<ffi.Size>();
      final peaksPtr = _getWaveformPeaks(clipId, resolution, lengthPtr);
      final length = lengthPtr.value;
      malloc.free(lengthPtr);
      
      if (peaksPtr == ffi.nullptr || length == 0) {
        print('❌ [AudioEngine] No waveform peaks returned');
        return [];
      }
      
      // Convert to Dart list
      final peaks = <double>[];
      for (int i = 0; i < length; i++) {
        peaks.add(peaksPtr[i]);
      }
      
      // Free the peaks array
      _freeWaveformPeaks(peaksPtr, length);
      
      print('✅ [AudioEngine] Got $length waveform peaks');
      return peaks;
    } catch (e) {
      print('❌ [AudioEngine] Get waveform peaks failed: $e');
      return [];
    }
  }
}

// ==========================================================================
// Native function type definitions
// ==========================================================================

// M0 types
typedef _InitAudioEngineFfiNative = ffi.Pointer<Utf8> Function();
typedef _InitAudioEngineFfi = ffi.Pointer<Utf8> Function();

typedef _PlaySineWaveFfiNative = ffi.Pointer<Utf8> Function(
    ffi.Float frequency, ffi.Uint32 durationMs);
typedef _PlaySineWaveFfi = ffi.Pointer<Utf8> Function(
    double frequency, int durationMs);

typedef _FreeRustStringNative = ffi.Void Function(ffi.Pointer<Utf8>);
typedef _FreeRustString = void Function(ffi.Pointer<Utf8>);

// M1 types
typedef _InitAudioGraphFfiNative = ffi.Pointer<Utf8> Function();
typedef _InitAudioGraphFfi = ffi.Pointer<Utf8> Function();

typedef _LoadAudioFileFfiNative = ffi.Int64 Function(ffi.Pointer<ffi.Char>);
typedef _LoadAudioFileFfi = int Function(ffi.Pointer<ffi.Char>);

typedef _TransportPlayFfiNative = ffi.Pointer<Utf8> Function();
typedef _TransportPlayFfi = ffi.Pointer<Utf8> Function();

typedef _TransportPauseFfiNative = ffi.Pointer<Utf8> Function();
typedef _TransportPauseFfi = ffi.Pointer<Utf8> Function();

typedef _TransportStopFfiNative = ffi.Pointer<Utf8> Function();
typedef _TransportStopFfi = ffi.Pointer<Utf8> Function();

typedef _TransportSeekFfiNative = ffi.Pointer<Utf8> Function(ffi.Double);
typedef _TransportSeekFfi = ffi.Pointer<Utf8> Function(double);

typedef _GetPlayheadPositionFfiNative = ffi.Double Function();
typedef _GetPlayheadPositionFfi = double Function();

typedef _GetTransportStateFfiNative = ffi.Int32 Function();
typedef _GetTransportStateFfi = int Function();

typedef _GetClipDurationFfiNative = ffi.Double Function(ffi.Uint64);
typedef _GetClipDurationFfi = double Function(int);

typedef _GetWaveformPeaksFfiNative = ffi.Pointer<ffi.Float> Function(
    ffi.Uint64, ffi.Size, ffi.Pointer<ffi.Size>);
typedef _GetWaveformPeaksFfi = ffi.Pointer<ffi.Float> Function(
    int, int, ffi.Pointer<ffi.Size>);

typedef _FreeWaveformPeaksFfiNative = ffi.Void Function(
    ffi.Pointer<ffi.Float>, ffi.Size);
typedef _FreeWaveformPeaksFfi = void Function(ffi.Pointer<ffi.Float>, int);
