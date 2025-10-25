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
  
  // M2 functions - Recording & Input
  late final _StartRecordingFfi _startRecording;
  late final _StopRecordingFfi _stopRecording;
  late final _GetRecordingStateFfi _getRecordingState;
  late final _GetRecordedDurationFfi _getRecordedDuration;
  late final _SetCountInBarsFfi _setCountInBars;
  late final _GetCountInBarsFfi _getCountInBars;
  late final _SetTempoFfi _setTempo;
  late final _GetTempoFfi _getTempo;
  late final _SetMetronomeEnabledFfi _setMetronomeEnabled;
  late final _IsMetronomeEnabledFfi _isMetronomeEnabled;

  // M3 functions - MIDI
  late final _StartMidiInputFfi _startMidiInput;
  late final _StopMidiInputFfi _stopMidiInput;
  late final _SetSynthOscillatorTypeFfi _setSynthOscillatorType;
  late final _SetSynthVolumeFfi _setSynthVolume;
  late final _SendMidiNoteOnFfi _sendMidiNoteOn;
  late final _SendMidiNoteOffFfi _sendMidiNoteOff;

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
      
      // Bind M2 functions
      _startRecording = _lib
          .lookup<ffi.NativeFunction<_StartRecordingFfiNative>>(
              'start_recording_ffi')
          .asFunction();
      print('  ✅ start_recording_ffi bound');
      
      _stopRecording = _lib
          .lookup<ffi.NativeFunction<_StopRecordingFfiNative>>(
              'stop_recording_ffi')
          .asFunction();
      print('  ✅ stop_recording_ffi bound');
      
      _getRecordingState = _lib
          .lookup<ffi.NativeFunction<_GetRecordingStateFfiNative>>(
              'get_recording_state_ffi')
          .asFunction();
      print('  ✅ get_recording_state_ffi bound');
      
      _getRecordedDuration = _lib
          .lookup<ffi.NativeFunction<_GetRecordedDurationFfiNative>>(
              'get_recorded_duration_ffi')
          .asFunction();
      print('  ✅ get_recorded_duration_ffi bound');
      
      _setCountInBars = _lib
          .lookup<ffi.NativeFunction<_SetCountInBarsFfiNative>>(
              'set_count_in_bars_ffi')
          .asFunction();
      print('  ✅ set_count_in_bars_ffi bound');
      
      _getCountInBars = _lib
          .lookup<ffi.NativeFunction<_GetCountInBarsFfiNative>>(
              'get_count_in_bars_ffi')
          .asFunction();
      print('  ✅ get_count_in_bars_ffi bound');
      
      _setTempo = _lib
          .lookup<ffi.NativeFunction<_SetTempoFfiNative>>(
              'set_tempo_ffi')
          .asFunction();
      print('  ✅ set_tempo_ffi bound');
      
      _getTempo = _lib
          .lookup<ffi.NativeFunction<_GetTempoFfiNative>>(
              'get_tempo_ffi')
          .asFunction();
      print('  ✅ get_tempo_ffi bound');
      
      _setMetronomeEnabled = _lib
          .lookup<ffi.NativeFunction<_SetMetronomeEnabledFfiNative>>(
              'set_metronome_enabled_ffi')
          .asFunction();
      print('  ✅ set_metronome_enabled_ffi bound');
      
      _isMetronomeEnabled = _lib
          .lookup<ffi.NativeFunction<_IsMetronomeEnabledFfiNative>>(
              'is_metronome_enabled_ffi')
          .asFunction();
      print('  ✅ is_metronome_enabled_ffi bound');

      // Bind M3 functions
      _startMidiInput = _lib
          .lookup<ffi.NativeFunction<_StartMidiInputFfiNative>>(
              'start_midi_input_ffi')
          .asFunction();
      print('  ✅ start_midi_input_ffi bound');

      _stopMidiInput = _lib
          .lookup<ffi.NativeFunction<_StopMidiInputFfiNative>>(
              'stop_midi_input_ffi')
          .asFunction();
      print('  ✅ stop_midi_input_ffi bound');

      _setSynthOscillatorType = _lib
          .lookup<ffi.NativeFunction<_SetSynthOscillatorTypeFfiNative>>(
              'set_synth_oscillator_type_ffi')
          .asFunction();
      print('  ✅ set_synth_oscillator_type_ffi bound');

      _setSynthVolume = _lib
          .lookup<ffi.NativeFunction<_SetSynthVolumeFfiNative>>(
              'set_synth_volume_ffi')
          .asFunction();
      print('  ✅ set_synth_volume_ffi bound');

      _sendMidiNoteOn = _lib
          .lookup<ffi.NativeFunction<_SendMidiNoteOnFfiNative>>(
              'send_midi_note_on_ffi')
          .asFunction();
      print('  ✅ send_midi_note_on_ffi bound');

      _sendMidiNoteOff = _lib
          .lookup<ffi.NativeFunction<_SendMidiNoteOffFfiNative>>(
              'send_midi_note_off_ffi')
          .asFunction();
      print('  ✅ send_midi_note_off_ffi bound');

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

  // ========================================================================
  // M2 API - Recording & Input
  // ========================================================================

  /// Start recording audio
  String startRecording() {
    print('⏺️  [AudioEngine] Starting recording...');
    try {
      final resultPtr = _startRecording();
      final result = resultPtr.toDartString();
      _freeRustString(resultPtr);
      print('✅ [AudioEngine] $result');
      return result;
    } catch (e) {
      print('❌ [AudioEngine] Start recording failed: $e');
      rethrow;
    }
  }

  /// Stop recording and return clip ID (-1 if no recording)
  int stopRecording() {
    print('⏹️  [AudioEngine] Stopping recording...');
    try {
      final clipId = _stopRecording();
      print('✅ [AudioEngine] Recording stopped, clip ID: $clipId');
      return clipId;
    } catch (e) {
      print('❌ [AudioEngine] Stop recording failed: $e');
      return -1;
    }
  }

  /// Get recording state (0=Idle, 1=CountingIn, 2=Recording)
  int getRecordingState() {
    try {
      return _getRecordingState();
    } catch (e) {
      print('❌ [AudioEngine] Get recording state failed: $e');
      return 0;
    }
  }

  /// Get recorded duration in seconds
  double getRecordedDuration() {
    try {
      return _getRecordedDuration();
    } catch (e) {
      print('❌ [AudioEngine] Get recorded duration failed: $e');
      return 0.0;
    }
  }

  /// Set count-in duration in bars
  String setCountInBars(int bars) {
    print('🎵 [AudioEngine] Setting count-in to $bars bars...');
    try {
      final resultPtr = _setCountInBars(bars);
      final result = resultPtr.toDartString();
      _freeRustString(resultPtr);
      print('✅ [AudioEngine] $result');
      return result;
    } catch (e) {
      print('❌ [AudioEngine] Set count-in failed: $e');
      rethrow;
    }
  }

  /// Get count-in duration in bars
  int getCountInBars() {
    try {
      return _getCountInBars();
    } catch (e) {
      print('❌ [AudioEngine] Get count-in bars failed: $e');
      return 2;
    }
  }

  /// Set tempo in BPM
  String setTempo(double bpm) {
    print('🎵 [AudioEngine] Setting tempo to $bpm BPM...');
    try {
      final resultPtr = _setTempo(bpm);
      final result = resultPtr.toDartString();
      _freeRustString(resultPtr);
      print('✅ [AudioEngine] $result');
      return result;
    } catch (e) {
      print('❌ [AudioEngine] Set tempo failed: $e');
      rethrow;
    }
  }

  /// Get tempo in BPM
  double getTempo() {
    try {
      return _getTempo();
    } catch (e) {
      print('❌ [AudioEngine] Get tempo failed: $e');
      return 120.0;
    }
  }

  /// Enable or disable metronome
  String setMetronomeEnabled(bool enabled) {
    print('🎵 [AudioEngine] ${enabled ? "Enabling" : "Disabling"} metronome...');
    try {
      final resultPtr = _setMetronomeEnabled(enabled ? 1 : 0);
      final result = resultPtr.toDartString();
      _freeRustString(resultPtr);
      print('✅ [AudioEngine] $result');
      return result;
    } catch (e) {
      print('❌ [AudioEngine] Set metronome enabled failed: $e');
      rethrow;
    }
  }

  /// Check if metronome is enabled
  bool isMetronomeEnabled() {
    try {
      return _isMetronomeEnabled() != 0;
    } catch (e) {
      print('❌ [AudioEngine] Is metronome enabled failed: $e');
      return true;
    }
  }

  // ========================================================================
  // M3 API - MIDI
  // ========================================================================

  /// Start MIDI input (initializes MIDI system and synthesizer)
  String startMidiInput() {
    print('🎹 [AudioEngine] Starting MIDI input...');
    try {
      final resultPtr = _startMidiInput();
      final result = resultPtr.toDartString();
      _freeRustString(resultPtr);
      print('✅ [AudioEngine] $result');
      return result;
    } catch (e) {
      print('❌ [AudioEngine] Start MIDI input failed: $e');
      rethrow;
    }
  }

  /// Stop MIDI input
  String stopMidiInput() {
    print('🎹 [AudioEngine] Stopping MIDI input...');
    try {
      final resultPtr = _stopMidiInput();
      final result = resultPtr.toDartString();
      _freeRustString(resultPtr);
      print('✅ [AudioEngine] $result');
      return result;
    } catch (e) {
      print('❌ [AudioEngine] Stop MIDI input failed: $e');
      rethrow;
    }
  }

  /// Set synthesizer oscillator type (0=Sine, 1=Saw, 2=Square)
  String setSynthOscillatorType(int oscType) {
    print('🎹 [AudioEngine] Setting synth oscillator type to $oscType...');
    try {
      final resultPtr = _setSynthOscillatorType(oscType);
      final result = resultPtr.toDartString();
      _freeRustString(resultPtr);
      print('✅ [AudioEngine] $result');
      return result;
    } catch (e) {
      print('❌ [AudioEngine] Set synth oscillator type failed: $e');
      rethrow;
    }
  }

  /// Set synthesizer volume (0.0 to 1.0)
  String setSynthVolume(double volume) {
    print('🎹 [AudioEngine] Setting synth volume to $volume...');
    try {
      final resultPtr = _setSynthVolume(volume);
      final result = resultPtr.toDartString();
      _freeRustString(resultPtr);
      print('✅ [AudioEngine] $result');
      return result;
    } catch (e) {
      print('❌ [AudioEngine] Set synth volume failed: $e');
      rethrow;
    }
  }

  /// Send MIDI note on event to synthesizer (for virtual piano)
  String sendMidiNoteOn(int note, int velocity) {
    try {
      final resultPtr = _sendMidiNoteOn(note, velocity);
      final result = resultPtr.toDartString();
      _freeRustString(resultPtr);
      return result;
    } catch (e) {
      print('❌ [AudioEngine] Send MIDI note on failed: $e');
      rethrow;
    }
  }

  /// Send MIDI note off event to synthesizer (for virtual piano)
  String sendMidiNoteOff(int note, int velocity) {
    try {
      final resultPtr = _sendMidiNoteOff(note, velocity);
      final result = resultPtr.toDartString();
      _freeRustString(resultPtr);
      return result;
    } catch (e) {
      print('❌ [AudioEngine] Send MIDI note off failed: $e');
      rethrow;
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

// M2 types - Recording & Input
typedef _StartRecordingFfiNative = ffi.Pointer<Utf8> Function();
typedef _StartRecordingFfi = ffi.Pointer<Utf8> Function();

typedef _StopRecordingFfiNative = ffi.Int64 Function();
typedef _StopRecordingFfi = int Function();

typedef _GetRecordingStateFfiNative = ffi.Int32 Function();
typedef _GetRecordingStateFfi = int Function();

typedef _GetRecordedDurationFfiNative = ffi.Double Function();
typedef _GetRecordedDurationFfi = double Function();

typedef _SetCountInBarsFfiNative = ffi.Pointer<Utf8> Function(ffi.Uint32);
typedef _SetCountInBarsFfi = ffi.Pointer<Utf8> Function(int);

typedef _GetCountInBarsFfiNative = ffi.Uint32 Function();
typedef _GetCountInBarsFfi = int Function();

typedef _SetTempoFfiNative = ffi.Pointer<Utf8> Function(ffi.Double);
typedef _SetTempoFfi = ffi.Pointer<Utf8> Function(double);

typedef _GetTempoFfiNative = ffi.Double Function();
typedef _GetTempoFfi = double Function();

typedef _SetMetronomeEnabledFfiNative = ffi.Pointer<Utf8> Function(ffi.Int32);
typedef _SetMetronomeEnabledFfi = ffi.Pointer<Utf8> Function(int);

typedef _IsMetronomeEnabledFfiNative = ffi.Int32 Function();
typedef _IsMetronomeEnabledFfi = int Function();

// M3 types - MIDI
typedef _StartMidiInputFfiNative = ffi.Pointer<Utf8> Function();
typedef _StartMidiInputFfi = ffi.Pointer<Utf8> Function();

typedef _StopMidiInputFfiNative = ffi.Pointer<Utf8> Function();
typedef _StopMidiInputFfi = ffi.Pointer<Utf8> Function();

typedef _SetSynthOscillatorTypeFfiNative = ffi.Pointer<Utf8> Function(ffi.Int32);
typedef _SetSynthOscillatorTypeFfi = ffi.Pointer<Utf8> Function(int);

typedef _SetSynthVolumeFfiNative = ffi.Pointer<Utf8> Function(ffi.Float);
typedef _SetSynthVolumeFfi = ffi.Pointer<Utf8> Function(double);

typedef _SendMidiNoteOnFfiNative = ffi.Pointer<Utf8> Function(ffi.Uint8, ffi.Uint8);
typedef _SendMidiNoteOnFfi = ffi.Pointer<Utf8> Function(int, int);

typedef _SendMidiNoteOffFfiNative = ffi.Pointer<Utf8> Function(ffi.Uint8, ffi.Uint8);
typedef _SendMidiNoteOffFfi = ffi.Pointer<Utf8> Function(int, int);
