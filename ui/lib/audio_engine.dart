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

  // M6 functions - Per-track Synthesizer
  late final _SetTrackInstrumentFfi _setTrackInstrument;
  late final _SetSynthParameterFfi _setSynthParameter;
  late final _GetSynthParametersFfi _getSynthParameters;
  late final _SendTrackMidiNoteOnFfi _sendTrackMidiNoteOn;
  late final _SendTrackMidiNoteOffFfi _sendTrackMidiNoteOff;

  // M4 functions - Tracks & Mixer
  late final _CreateTrackFfi _createTrack;
  late final _SetTrackVolumeFfi _setTrackVolume;
  late final _SetTrackPanFfi _setTrackPan;
  late final _SetTrackMuteFfi _setTrackMute;
  late final _SetTrackSoloFfi _setTrackSolo;
  late final _GetTrackCountFfi _getTrackCount;
  late final _GetAllTrackIdsFfi _getAllTrackIds;
  late final _GetTrackInfoFfi _getTrackInfo;
  late final _GetTrackPeakLevelsFfi _getTrackPeakLevels;
  late final _DeleteTrackFfi _deleteTrack;

  // M4 functions - Effects
  late final _AddEffectToTrackFfi _addEffectToTrack;
  late final _RemoveEffectFromTrackFfi _removeEffectFromTrack;
  late final _GetTrackEffectsFfi _getTrackEffects;
  late final _GetEffectInfoFfi _getEffectInfo;
  late final _SetEffectParameterFfi _setEffectParameter;

  // M5 functions - Save/Load Project
  late final _SaveProjectFfi _saveProject;
  late final _LoadProjectFfi _loadProject;
  late final _ExportToWavFfi _exportToWav;

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

      // Bind M4 functions
      _createTrack = _lib
          .lookup<ffi.NativeFunction<_CreateTrackFfiNative>>(
              'create_track_ffi')
          .asFunction();
      print('  ✅ create_track_ffi bound');

      _setTrackVolume = _lib
          .lookup<ffi.NativeFunction<_SetTrackVolumeFfiNative>>(
              'set_track_volume_ffi')
          .asFunction();
      print('  ✅ set_track_volume_ffi bound');

      _setTrackPan = _lib
          .lookup<ffi.NativeFunction<_SetTrackPanFfiNative>>(
              'set_track_pan_ffi')
          .asFunction();
      print('  ✅ set_track_pan_ffi bound');

      _setTrackMute = _lib
          .lookup<ffi.NativeFunction<_SetTrackMuteFfiNative>>(
              'set_track_mute_ffi')
          .asFunction();
      print('  ✅ set_track_mute_ffi bound');

      _setTrackSolo = _lib
          .lookup<ffi.NativeFunction<_SetTrackSoloFfiNative>>(
              'set_track_solo_ffi')
          .asFunction();
      print('  ✅ set_track_solo_ffi bound');

      _getTrackCount = _lib
          .lookup<ffi.NativeFunction<_GetTrackCountFfiNative>>(
              'get_track_count_ffi')
          .asFunction();
      print('  ✅ get_track_count_ffi bound');

      _getAllTrackIds = _lib
          .lookup<ffi.NativeFunction<_GetAllTrackIdsFfiNative>>(
              'get_all_track_ids_ffi')
          .asFunction();
      print('  ✅ get_all_track_ids_ffi bound');

      _getTrackInfo = _lib
          .lookup<ffi.NativeFunction<_GetTrackInfoFfiNative>>(
              'get_track_info_ffi')
          .asFunction();
      print('  ✅ get_track_info_ffi bound');

      _getTrackPeakLevels = _lib
          .lookup<ffi.NativeFunction<_GetTrackPeakLevelsFfiNative>>(
              'get_track_peak_levels_ffi')
          .asFunction();
      print('  ✅ get_track_peak_levels_ffi bound');

      _deleteTrack = _lib
          .lookup<ffi.NativeFunction<_DeleteTrackFfiNative>>(
              'delete_track_ffi')
          .asFunction();
      print('  ✅ delete_track_ffi bound');

      // Bind M4 effect functions
      _addEffectToTrack = _lib
          .lookup<ffi.NativeFunction<_AddEffectToTrackFfiNative>>(
              'add_effect_to_track_ffi')
          .asFunction();
      print('  ✅ add_effect_to_track_ffi bound');

      _removeEffectFromTrack = _lib
          .lookup<ffi.NativeFunction<_RemoveEffectFromTrackFfiNative>>(
              'remove_effect_from_track_ffi')
          .asFunction();
      print('  ✅ remove_effect_from_track_ffi bound');

      _getTrackEffects = _lib
          .lookup<ffi.NativeFunction<_GetTrackEffectsFfiNative>>(
              'get_track_effects_ffi')
          .asFunction();
      print('  ✅ get_track_effects_ffi bound');

      _getEffectInfo = _lib
          .lookup<ffi.NativeFunction<_GetEffectInfoFfiNative>>(
              'get_effect_info_ffi')
          .asFunction();
      print('  ✅ get_effect_info_ffi bound');

      _setEffectParameter = _lib
          .lookup<ffi.NativeFunction<_SetEffectParameterFfiNative>>(
              'set_effect_parameter_ffi')
          .asFunction();
      print('  ✅ set_effect_parameter_ffi bound');

      // Bind M5 functions - Save/Load
      _saveProject = _lib
          .lookup<ffi.NativeFunction<_SaveProjectFfiNative>>(
              'save_project_ffi')
          .asFunction();
      print('  ✅ save_project_ffi bound');

      _loadProject = _lib
          .lookup<ffi.NativeFunction<_LoadProjectFfiNative>>(
              'load_project_ffi')
          .asFunction();
      print('  ✅ load_project_ffi bound');

      _exportToWav = _lib
          .lookup<ffi.NativeFunction<_ExportToWavFfiNative>>(
              'export_to_wav_ffi')
          .asFunction();
      print('  ✅ export_to_wav_ffi bound');

      // Bind M6 functions - Per-track Synthesizer
      _setTrackInstrument = _lib
          .lookup<ffi.NativeFunction<_SetTrackInstrumentFfiNative>>(
              'set_track_instrument_ffi')
          .asFunction();
      print('  ✅ set_track_instrument_ffi bound');

      _setSynthParameter = _lib
          .lookup<ffi.NativeFunction<_SetSynthParameterFfiNative>>(
              'set_synth_parameter_ffi')
          .asFunction();
      print('  ✅ set_synth_parameter_ffi bound');

      _getSynthParameters = _lib
          .lookup<ffi.NativeFunction<_GetSynthParametersFfiNative>>(
              'get_synth_parameters_ffi')
          .asFunction();
      print('  ✅ get_synth_parameters_ffi bound');

      _sendTrackMidiNoteOn = _lib
          .lookup<ffi.NativeFunction<_SendTrackMidiNoteOnFfiNative>>(
              'send_track_midi_note_on_ffi')
          .asFunction();
      print('  ✅ send_track_midi_note_on_ffi bound');

      _sendTrackMidiNoteOff = _lib
          .lookup<ffi.NativeFunction<_SendTrackMidiNoteOffFfiNative>>(
              'send_track_midi_note_off_ffi')
          .asFunction();
      print('  ✅ send_track_midi_note_off_ffi bound');

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

  // ========================================================================
  // M4 API - Tracks & Mixer
  // ========================================================================

  /// Create a new track
  /// trackType: "audio", "midi", "return", "group", or "master"
  /// Returns track ID or -1 on error
  int createTrack(String trackType, String name) {
    print('🎚️  [AudioEngine] Creating $trackType track: $name');
    try {
      final typePtr = trackType.toNativeUtf8();
      final namePtr = name.toNativeUtf8();
      final trackId = _createTrack(typePtr.cast(), namePtr.cast());
      malloc.free(typePtr);
      malloc.free(namePtr);

      if (trackId < 0) {
        print('❌ [AudioEngine] Failed to create track');
        return -1;
      }

      print('✅ [AudioEngine] Track created with ID: $trackId');
      return trackId;
    } catch (e) {
      print('❌ [AudioEngine] Create track failed: $e');
      return -1;
    }
  }

  /// Set track volume in dB (-∞ to +6 dB)
  String setTrackVolume(int trackId, double volumeDb) {
    try {
      final resultPtr = _setTrackVolume(trackId, volumeDb);
      final result = resultPtr.toDartString();
      _freeRustString(resultPtr);
      return result;
    } catch (e) {
      print('❌ [AudioEngine] Set track volume failed: $e');
      rethrow;
    }
  }

  /// Set track pan (-1.0 = full left, 0.0 = center, 1.0 = full right)
  String setTrackPan(int trackId, double pan) {
    try {
      final resultPtr = _setTrackPan(trackId, pan);
      final result = resultPtr.toDartString();
      _freeRustString(resultPtr);
      return result;
    } catch (e) {
      print('❌ [AudioEngine] Set track pan failed: $e');
      rethrow;
    }
  }

  /// Mute or unmute a track
  String setTrackMute(int trackId, bool mute) {
    try {
      final resultPtr = _setTrackMute(trackId, mute);
      final result = resultPtr.toDartString();
      _freeRustString(resultPtr);
      return result;
    } catch (e) {
      print('❌ [AudioEngine] Set track mute failed: $e');
      rethrow;
    }
  }

  /// Solo or unsolo a track
  String setTrackSolo(int trackId, bool solo) {
    try {
      final resultPtr = _setTrackSolo(trackId, solo);
      final result = resultPtr.toDartString();
      _freeRustString(resultPtr);
      return result;
    } catch (e) {
      print('❌ [AudioEngine] Set track solo failed: $e');
      rethrow;
    }
  }

  /// Get total number of tracks
  int getTrackCount() {
    try {
      return _getTrackCount();
    } catch (e) {
      print('❌ [AudioEngine] Get track count failed: $e');
      return 0;
    }
  }

  /// Get all track IDs as list
  List<int> getAllTrackIds() {
    try {
      final resultPtr = _getAllTrackIds();
      final result = resultPtr.toDartString();
      _freeRustString(resultPtr);

      if (result.isEmpty || result.startsWith('Error:')) {
        return [];
      }

      return result.split(',').map((id) => int.parse(id)).toList();
    } catch (e) {
      print('❌ [AudioEngine] Get all track IDs failed: $e');
      return [];
    }
  }

  /// Get track info as CSV: "track_id,name,type,volume_db,pan,mute,solo"
  String getTrackInfo(int trackId) {
    try {
      final resultPtr = _getTrackInfo(trackId);
      final result = resultPtr.toDartString();
      _freeRustString(resultPtr);
      return result;
    } catch (e) {
      print('❌ [AudioEngine] Get track info failed: $e');
      return '';
    }
  }

  /// Get track peak levels (M5.5) as CSV: "peak_left_db,peak_right_db"
  String getTrackPeakLevels(int trackId) {
    try {
      final resultPtr = _getTrackPeakLevels(trackId);
      final result = resultPtr.toDartString();
      _freeRustString(resultPtr);
      return result;
    } catch (e) {
      // Fail silently for peak levels (called frequently)
      return '-96.0,-96.0';
    }
  }

  /// Delete a track (cannot delete master track)
  String deleteTrack(int trackId) {
    print('🗑️ [AudioEngine] Deleting track $trackId...');
    try {
      final resultPtr = _deleteTrack(trackId);
      final result = resultPtr.toDartString();
      _freeRustString(resultPtr);
      print('✅ [AudioEngine] $result');
      return result;
    } catch (e) {
      print('❌ [AudioEngine] Delete track failed: $e');
      rethrow;
    }
  }

  // ========================================================================
  // M4 API - Effects
  // ========================================================================

  /// Add an effect to a track's FX chain
  /// effectType: "eq", "compressor", "reverb", "delay", "chorus", "limiter"
  /// Returns effect ID or -1 on error
  int addEffectToTrack(int trackId, String effectType) {
    print('🎛️  [AudioEngine] Adding $effectType to track $trackId');
    try {
      final typePtr = effectType.toNativeUtf8();
      final effectId = _addEffectToTrack(trackId, typePtr.cast());
      malloc.free(typePtr);

      if (effectId < 0) {
        print('❌ [AudioEngine] Failed to add effect');
        return -1;
      }

      print('✅ [AudioEngine] Effect added with ID: $effectId');
      return effectId;
    } catch (e) {
      print('❌ [AudioEngine] Add effect failed: $e');
      return -1;
    }
  }

  /// Remove an effect from a track's FX chain
  String removeEffectFromTrack(int trackId, int effectId) {
    print('🗑️  [AudioEngine] Removing effect $effectId from track $trackId');
    try {
      final resultPtr = _removeEffectFromTrack(trackId, effectId);
      final result = resultPtr.toDartString();
      _freeRustString(resultPtr);
      print('✅ [AudioEngine] $result');
      return result;
    } catch (e) {
      print('❌ [AudioEngine] Remove effect failed: $e');
      rethrow;
    }
  }

  /// Get all effects on a track (returns CSV of effect IDs)
  String getTrackEffects(int trackId) {
    try {
      final resultPtr = _getTrackEffects(trackId);
      final result = resultPtr.toDartString();
      _freeRustString(resultPtr);
      return result;
    } catch (e) {
      print('❌ [AudioEngine] Get track effects failed: $e');
      return '';
    }
  }

  /// Get effect info (type and parameters)
  /// Returns format: "type:eq,low_freq:100,low_gain:0,..."
  String getEffectInfo(int effectId) {
    try {
      final resultPtr = _getEffectInfo(effectId);
      final result = resultPtr.toDartString();
      _freeRustString(resultPtr);
      return result;
    } catch (e) {
      print('❌ [AudioEngine] Get effect info failed: $e');
      return '';
    }
  }

  /// Set an effect parameter
  String setEffectParameter(int effectId, String paramName, double value) {
    try {
      final namePtr = paramName.toNativeUtf8();
      final resultPtr = _setEffectParameter(effectId, namePtr.cast(), value);
      malloc.free(namePtr);
      final result = resultPtr.toDartString();
      _freeRustString(resultPtr);
      return result;
    } catch (e) {
      print('❌ [AudioEngine] Set effect parameter failed: $e');
      rethrow;
    }
  }

  // ========================================================================
  // M5 API - Save/Load Project
  // ========================================================================

  /// Save project to .solar folder
  String saveProject(String projectName, String projectPath) {
    print('💾 [AudioEngine] Saving project: $projectName to $projectPath');
    try {
      final namePtr = projectName.toNativeUtf8();
      final pathPtr = projectPath.toNativeUtf8();
      final resultPtr = _saveProject(namePtr.cast(), pathPtr.cast());
      malloc.free(namePtr);
      malloc.free(pathPtr);
      final result = resultPtr.toDartString();
      _freeRustString(resultPtr);
      print('✅ [AudioEngine] Save complete: $result');
      return result;
    } catch (e) {
      print('❌ [AudioEngine] Save project failed: $e');
      rethrow;
    }
  }

  /// Load project from .solar folder
  String loadProject(String projectPath) {
    print('📂 [AudioEngine] Loading project from: $projectPath');
    try {
      final pathPtr = projectPath.toNativeUtf8();
      final resultPtr = _loadProject(pathPtr.cast());
      malloc.free(pathPtr);
      final result = resultPtr.toDartString();
      _freeRustString(resultPtr);
      print('✅ [AudioEngine] Load complete: $result');
      return result;
    } catch (e) {
      print('❌ [AudioEngine] Load project failed: $e');
      rethrow;
    }
  }

  /// Export project to WAV file
  String exportToWav(String outputPath, bool normalize) {
    print('🎵 [AudioEngine] Exporting to WAV: $outputPath (normalize: $normalize)');
    try {
      final pathPtr = outputPath.toNativeUtf8();
      final resultPtr = _exportToWav(pathPtr.cast(), normalize);
      malloc.free(pathPtr);
      final result = resultPtr.toDartString();
      _freeRustString(resultPtr);
      print('✅ [AudioEngine] Export complete: $result');
      return result;
    } catch (e) {
      print('❌ [AudioEngine] Export failed: $e');
      rethrow;
    }
  }

  // ========================================================================
  // M6 API - Per-track Synthesizer
  // ========================================================================

  /// Set the instrument for a track
  /// Returns the instrument ID or -1 on error
  int setTrackInstrument(int trackId, String instrumentType) {
    print('🎹 [AudioEngine] Setting instrument for track $trackId: $instrumentType');
    try {
      final typePtr = instrumentType.toNativeUtf8();
      final instrumentId = _setTrackInstrument(trackId, typePtr.cast());
      malloc.free(typePtr);

      if (instrumentId < 0) {
        print('❌ [AudioEngine] Failed to set instrument');
        return -1;
      }

      print('✅ [AudioEngine] Instrument set, ID: $instrumentId');
      return instrumentId;
    } catch (e) {
      print('❌ [AudioEngine] Set track instrument failed: $e');
      rethrow;
    }
  }

  /// Set a synthesizer parameter for a track
  /// paramName: parameter name (e.g., 'osc1_type', 'filter_cutoff')
  /// value: parameter value (will be converted to string)
  String setSynthParameter(int trackId, String paramName, dynamic value) {
    try {
      final namePtr = paramName.toNativeUtf8();
      final valueStr = value.toString();
      final valuePtr = valueStr.toNativeUtf8();
      final resultPtr = _setSynthParameter(trackId, namePtr.cast(), valuePtr.cast());
      malloc.free(namePtr);
      malloc.free(valuePtr);
      final result = resultPtr.toDartString();
      _freeRustString(resultPtr);
      return result;
    } catch (e) {
      print('❌ [AudioEngine] Set synth parameter failed: $e');
      rethrow;
    }
  }

  /// Get all synthesizer parameters for a track
  /// Returns a comma-separated string of key:value pairs
  String getSynthParameters(int trackId) {
    print('🎹 [AudioEngine] Getting synth parameters for track $trackId');
    try {
      final resultPtr = _getSynthParameters(trackId);
      final result = resultPtr.toDartString();
      _freeRustString(resultPtr);
      print('✅ [AudioEngine] Got parameters: $result');
      return result;
    } catch (e) {
      print('❌ [AudioEngine] Get synth parameters failed: $e');
      rethrow;
    }
  }

  /// Send MIDI note on to a specific track's instrument
  /// trackId: the track to send MIDI to
  /// note: MIDI note number (0-127)
  /// velocity: MIDI velocity (0-127)
  String sendTrackMidiNoteOn(int trackId, int note, int velocity) {
    try {
      final resultPtr = _sendTrackMidiNoteOn(trackId, note, velocity);
      final result = resultPtr.toDartString();
      _freeRustString(resultPtr);
      return result;
    } catch (e) {
      print('❌ [AudioEngine] Send track MIDI note on failed: $e');
      rethrow;
    }
  }

  /// Send MIDI note off to a specific track's instrument
  /// trackId: the track to send MIDI to
  /// note: MIDI note number (0-127)
  /// velocity: MIDI velocity (0-127)
  String sendTrackMidiNoteOff(int trackId, int note, int velocity) {
    try {
      final resultPtr = _sendTrackMidiNoteOff(trackId, note, velocity);
      final result = resultPtr.toDartString();
      _freeRustString(resultPtr);
      return result;
    } catch (e) {
      print('❌ [AudioEngine] Send track MIDI note off failed: $e');
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

// M4 types - Tracks & Mixer
typedef _CreateTrackFfiNative = ffi.Int64 Function(ffi.Pointer<ffi.Char>, ffi.Pointer<ffi.Char>);
typedef _CreateTrackFfi = int Function(ffi.Pointer<ffi.Char>, ffi.Pointer<ffi.Char>);

typedef _SetTrackVolumeFfiNative = ffi.Pointer<Utf8> Function(ffi.Uint64, ffi.Float);
typedef _SetTrackVolumeFfi = ffi.Pointer<Utf8> Function(int, double);

typedef _SetTrackPanFfiNative = ffi.Pointer<Utf8> Function(ffi.Uint64, ffi.Float);
typedef _SetTrackPanFfi = ffi.Pointer<Utf8> Function(int, double);

typedef _SetTrackMuteFfiNative = ffi.Pointer<Utf8> Function(ffi.Uint64, ffi.Bool);
typedef _SetTrackMuteFfi = ffi.Pointer<Utf8> Function(int, bool);

typedef _SetTrackSoloFfiNative = ffi.Pointer<Utf8> Function(ffi.Uint64, ffi.Bool);
typedef _SetTrackSoloFfi = ffi.Pointer<Utf8> Function(int, bool);

typedef _GetTrackCountFfiNative = ffi.Size Function();
typedef _GetTrackCountFfi = int Function();

typedef _GetAllTrackIdsFfiNative = ffi.Pointer<Utf8> Function();
typedef _GetAllTrackIdsFfi = ffi.Pointer<Utf8> Function();

typedef _GetTrackInfoFfiNative = ffi.Pointer<Utf8> Function(ffi.Uint64);
typedef _GetTrackInfoFfi = ffi.Pointer<Utf8> Function(int);

typedef _GetTrackPeakLevelsFfiNative = ffi.Pointer<Utf8> Function(ffi.Uint64);
typedef _GetTrackPeakLevelsFfi = ffi.Pointer<Utf8> Function(int);

typedef _DeleteTrackFfiNative = ffi.Pointer<Utf8> Function(ffi.Uint64);
typedef _DeleteTrackFfi = ffi.Pointer<Utf8> Function(int);

// M4 types - Effects
typedef _AddEffectToTrackFfiNative = ffi.Int64 Function(ffi.Uint64, ffi.Pointer<ffi.Char>);
typedef _AddEffectToTrackFfi = int Function(int, ffi.Pointer<ffi.Char>);

typedef _RemoveEffectFromTrackFfiNative = ffi.Pointer<Utf8> Function(ffi.Uint64, ffi.Uint64);
typedef _RemoveEffectFromTrackFfi = ffi.Pointer<Utf8> Function(int, int);

typedef _GetTrackEffectsFfiNative = ffi.Pointer<Utf8> Function(ffi.Uint64);
typedef _GetTrackEffectsFfi = ffi.Pointer<Utf8> Function(int);

typedef _GetEffectInfoFfiNative = ffi.Pointer<Utf8> Function(ffi.Uint64);
typedef _GetEffectInfoFfi = ffi.Pointer<Utf8> Function(int);

typedef _SetEffectParameterFfiNative = ffi.Pointer<Utf8> Function(ffi.Uint64, ffi.Pointer<ffi.Char>, ffi.Float);
typedef _SetEffectParameterFfi = ffi.Pointer<Utf8> Function(int, ffi.Pointer<ffi.Char>, double);

// M5 types - Save/Load Project
typedef _SaveProjectFfiNative = ffi.Pointer<Utf8> Function(ffi.Pointer<ffi.Char>, ffi.Pointer<ffi.Char>);
typedef _SaveProjectFfi = ffi.Pointer<Utf8> Function(ffi.Pointer<ffi.Char>, ffi.Pointer<ffi.Char>);

typedef _LoadProjectFfiNative = ffi.Pointer<Utf8> Function(ffi.Pointer<ffi.Char>);
typedef _LoadProjectFfi = ffi.Pointer<Utf8> Function(ffi.Pointer<ffi.Char>);

typedef _ExportToWavFfiNative = ffi.Pointer<Utf8> Function(ffi.Pointer<ffi.Char>, ffi.Bool);
typedef _ExportToWavFfi = ffi.Pointer<Utf8> Function(ffi.Pointer<ffi.Char>, bool);

// M6 types - Per-track Synthesizer
typedef _SetTrackInstrumentFfiNative = ffi.Int64 Function(ffi.Uint64, ffi.Pointer<ffi.Char>);
typedef _SetTrackInstrumentFfi = int Function(int, ffi.Pointer<ffi.Char>);

typedef _SetSynthParameterFfiNative = ffi.Pointer<Utf8> Function(ffi.Uint64, ffi.Pointer<ffi.Char>, ffi.Pointer<ffi.Char>);
typedef _SetSynthParameterFfi = ffi.Pointer<Utf8> Function(int, ffi.Pointer<ffi.Char>, ffi.Pointer<ffi.Char>);

typedef _GetSynthParametersFfiNative = ffi.Pointer<Utf8> Function(ffi.Uint64);
typedef _GetSynthParametersFfi = ffi.Pointer<Utf8> Function(int);

typedef _SendTrackMidiNoteOnFfiNative = ffi.Pointer<Utf8> Function(ffi.Uint64, ffi.Uint8, ffi.Uint8);
typedef _SendTrackMidiNoteOnFfi = ffi.Pointer<Utf8> Function(int, int, int);

typedef _SendTrackMidiNoteOffFfiNative = ffi.Pointer<Utf8> Function(ffi.Uint64, ffi.Uint8, ffi.Uint8);
typedef _SendTrackMidiNoteOffFfi = ffi.Pointer<Utf8> Function(int, int, int);
