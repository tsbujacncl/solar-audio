import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../audio_engine.dart';
import '../widgets/transport_bar.dart';
import '../widgets/timeline_view.dart';
import '../widgets/track_mixer_panel.dart';
import '../widgets/library_panel.dart';
import '../widgets/editor_panel.dart';
import '../widgets/resizable_divider.dart';
import '../widgets/instrument_browser.dart';
import '../widgets/vst3_plugin_browser.dart';
import '../models/midi_note_data.dart';
import '../models/instrument_data.dart';
import '../models/vst3_plugin_data.dart';

/// Main DAW screen with timeline, transport controls, and file import
class DAWScreen extends StatefulWidget {
  const DAWScreen({super.key});

  @override
  State<DAWScreen> createState() => _DAWScreenState();
}

class _DAWScreenState extends State<DAWScreen> {
  AudioEngine? _audioEngine;
  Timer? _playheadTimer;
  Timer? _recordingStateTimer;

  // State
  double _playheadPosition = 0.0;
  int? _loadedClipId;
  double? _clipDuration;
  List<double> _waveformPeaks = [];
  bool _isPlaying = false;
  bool _audioGraphInitialized = false;
  String _statusMessage = '';
  bool _isLoading = false;

  // M2: Recording state
  bool _isRecording = false;
  bool _isCountingIn = false;
  bool _metronomeEnabled = true;
  double _tempo = 120.0;

  // M3: Virtual piano state
  bool _virtualPianoEnabled = false;
  bool _virtualPianoVisible = false;

  // M4: Mixer state
  bool _mixerVisible = true; // Always visible by default

  // M5: Project state
  String? _currentProjectPath;
  String _currentProjectName = 'Untitled Project';

  // M6: UI panel state
  bool _libraryPanelCollapsed = false;
  bool _editorPanelVisible = true; // Show editor panel by default

  // M7: Resizable panels state
  double _libraryPanelWidth = 200.0;
  double _mixerPanelWidth = 380.0;
  double _editorPanelHeight = 250.0;
  static const double _libraryMinWidth = 40.0;
  static const double _libraryMaxWidth = 400.0;
  static const double _mixerMinWidth = 200.0;
  static const double _mixerMaxWidth = 600.0;
  static const double _editorMinHeight = 100.0;
  static const double _editorMaxHeight = 500.0;

  // M8: MIDI editing state
  int? _selectedTrackId; // Unified track selection for piano roll, FX, and instrument panels
  int? _selectedMidiClipId;
  MidiClipData? _currentEditingClip;
  List<MidiClipData> _midiClips = []; // All MIDI clips for timeline
  Map<int, int> _dartToRustClipIds = {}; // Maps Dart clip ID -> Rust clip ID

  // M9: Instrument state
  Map<int, InstrumentData> _trackInstruments = {}; // trackId -> InstrumentData

  // M10: VST3 Plugin state
  List<Map<String, String>> _availableVst3Plugins = []; // Scanned plugin list
  Map<int, List<int>> _trackVst3Effects = {}; // trackId -> [effectIds]
  Map<int, Map<String, String>> _vst3PluginCache = {}; // effectId -> plugin metadata
  bool _pluginsScanned = false;
  bool _isScanningVst3Plugins = false;

  @override
  void initState() {
    super.initState();
    // CRITICAL: Schedule audio engine initialization with a delay to prevent UI freeze
    // Even with postFrameCallback, FFI calls to Rust/C++ can block the main thread
    // Use Future.delayed to ensure UI renders multiple frames before any FFI initialization
    // DO NOT move this back to initState() or earlier - it will freeze the app on startup
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        _initAudioEngine();
      }
    });
  }

  @override
  void dispose() {
    // Clean up timers
    _playheadTimer?.cancel();
    _recordingStateTimer?.cancel();

    // Stop playback
    _stopPlayback();

    super.dispose();
  }

  void _initAudioEngine() async {
    try {
      // Called after 800ms delay from initState, so UI has rendered
      _audioEngine = AudioEngine();
      _audioEngine!.initAudioEngine();

      // Initialize audio graph
      final result = _audioEngine!.initAudioGraph();

      // Initialize recording settings
      try {
        _audioEngine!.setCountInBars(2); // Default: 2 bars
        _audioEngine!.setTempo(120.0);   // Default: 120 BPM
        _audioEngine!.setMetronomeEnabled(true); // Default: enabled

        // Get initial values
        final tempo = _audioEngine!.getTempo();
        final metronome = _audioEngine!.isMetronomeEnabled();

        debugPrint('🎵 Recording settings initialized:');
        debugPrint('   - Count-in: 2 bars');
        debugPrint('   - Tempo: $tempo BPM');
        debugPrint('   - Metronome: ${metronome ? "ON" : "OFF"}');
      } catch (e) {
        debugPrint('⚠️  Failed to initialize recording settings: $e');
      }

      if (mounted) {
        setState(() {
          _audioGraphInitialized = true;
          _statusMessage = 'Ready to record or load audio files';
          _tempo = 120.0;
          _metronomeEnabled = true;
        });
      }

      debugPrint('✅ Audio graph initialized: $result');

      // Scan VST3 plugins after audio graph is ready
      if (!_pluginsScanned && mounted) {
        debugPrint('📦 Starting deferred VST3 plugin scan...');
        _scanVst3Plugins();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Failed to initialize: $e';
        });
      }
      debugPrint('❌ Audio engine init failed: $e');
    }
  }

  void _loadAudioFile(String path) async {
    if (_audioEngine == null || !_audioGraphInitialized) return;

    setState(() {
      _isLoading = true;
      _statusMessage = 'Loading file...';
    });

    try {
      // Load the file
      final clipId = _audioEngine!.loadAudioFile(path);
      
      if (clipId < 0) {
        setState(() {
          _statusMessage = 'Failed to load file';
          _isLoading = false;
        });
        return;
      }

      // Get duration
      final duration = _audioEngine!.getClipDuration(clipId);
      
      // Get waveform peaks for visualization
      final peaks = _audioEngine!.getWaveformPeaks(clipId, 2000);
      
      setState(() {
        _loadedClipId = clipId;
        _clipDuration = duration;
        _waveformPeaks = peaks;
        _statusMessage = 'Loaded: ${path.split('/').last} (${duration.toStringAsFixed(2)}s)';
        _isLoading = false;
      });
      
      debugPrint('✅ Loaded clip $clipId: $duration seconds, ${peaks.length} peaks');
    } catch (e) {
      setState(() {
        _statusMessage = 'Error loading file: $e';
        _isLoading = false;
      });
      debugPrint('❌ Load error: $e');
    }
  }

  void _startPlayheadTimer() {
    _playheadTimer?.cancel();
    print('⏱️  Starting playhead timer');
    _playheadTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (_audioEngine != null && mounted) {
        final pos = _audioEngine!.getPlayheadPosition();
        if (mounted) {
          setState(() {
            _playheadPosition = pos;
          });
        }

        // Auto-stop at end of clip
        if (_clipDuration != null && pos >= _clipDuration!) {
          _stopPlayback();
        }
      }
    });
  }

  void _stopPlayheadTimer() {
    _playheadTimer?.cancel();
  }

  void _play() {
    print('▶️  [Flutter] _play() called');
    if (_audioEngine == null) return;

    try {
      _audioEngine!.transportPlay();
      setState(() {
        _isPlaying = true;
        _statusMessage = _loadedClipId != null ? 'Playing...' : 'Playing (empty)';
      });
      _startPlayheadTimer();
      print('✅ [Flutter] _play() completed');
    } catch (e) {
      setState(() {
        _statusMessage = 'Play error: $e';
      });
    }
  }

  void _pause() {
    if (_audioEngine == null) return;

    try {
      _audioEngine!.transportPause();
      setState(() {
        _isPlaying = false;
        _statusMessage = 'Paused';
      });
      _stopPlayheadTimer();
    } catch (e) {
      setState(() {
        _statusMessage = 'Pause error: $e';
      });
    }
  }

  void _stopPlayback() {
    print('🛑 [Flutter] _stopPlayback() called');
    if (_audioEngine == null) {
      print('⚠️  [Flutter] _audioEngine is null, returning');
      return;
    }

    try {
      print('📞 [Flutter] Calling _audioEngine.transportStop()...');
      final result = _audioEngine!.transportStop();
      print('✅ [Flutter] transportStop() returned: $result');

      setState(() {
        _isPlaying = false;
        _playheadPosition = 0.0;
        _statusMessage = 'Stopped';
      });
      _stopPlayheadTimer();
      print('🏁 [Flutter] _stopPlayback() completed');
    } catch (e) {
      print('❌ [Flutter] Stop error: $e');
      setState(() {
        _statusMessage = 'Stop error: $e';
      });
    }
  }

  // File picking method
  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['wav', 'mp3', 'flac', 'aif', 'aiff'],
      dialogTitle: 'Select Audio File',
    );

    if (result != null && result.files.single.path != null) {
      _loadAudioFile(result.files.single.path!);
    }
  }

  // M2: Recording methods
  void _toggleRecording() {
    if (_audioEngine == null) return;

    if (_isRecording || _isCountingIn) {
      // Stop recording
      _stopRecording();
    } else {
      // Start recording
      _startRecording();
    }
  }

  void _startRecording() {
    if (_audioEngine == null) return;

    try {
      // Check current settings
      final countInBars = _audioEngine!.getCountInBars();
      final tempo = _audioEngine!.getTempo();
      final metronomeEnabled = _audioEngine!.isMetronomeEnabled();
      
      debugPrint('🎙️  Starting recording with:');
      debugPrint('   - Count-in: $countInBars bars');
      debugPrint('   - Tempo: $tempo BPM');
      debugPrint('   - Metronome: ${metronomeEnabled ? "ON" : "OFF"}');
      
      final result = _audioEngine!.startRecording();
      debugPrint('   - Result: $result');
      
      setState(() {
        _isCountingIn = true;
        _statusMessage = 'Count-in... ($countInBars bars at $tempo BPM)';
        _tempo = tempo;
      });
      
      // Start timer to poll recording state
      _startRecordingStateTimer();
    } catch (e) {
      debugPrint('❌ Recording error: $e');
      setState(() {
        _statusMessage = 'Recording error: $e';
      });
    }
  }

  void _stopRecording() {
    if (_audioEngine == null) return;

    try {
      final clipId = _audioEngine!.stopRecording();
      
      setState(() {
        _isRecording = false;
        _isCountingIn = false;
      });
      
      if (clipId >= 0) {
        // Recording successful - get clip info
        final duration = _audioEngine!.getClipDuration(clipId);
        final peaks = _audioEngine!.getWaveformPeaks(clipId, 2000);
        
        setState(() {
          _loadedClipId = clipId;
          _clipDuration = duration;
          _waveformPeaks = peaks;
          _statusMessage = 'Recorded ${duration.toStringAsFixed(2)}s';
        });
      } else {
        setState(() {
          _statusMessage = 'No recording captured';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Stop recording error: $e';
        _isRecording = false;
        _isCountingIn = false;
      });
    }
  }

  void _startRecordingStateTimer() {
    // Cancel any existing timer to prevent leaks
    _recordingStateTimer?.cancel();

    _recordingStateTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_audioEngine == null || (!_isRecording && !_isCountingIn)) {
        timer.cancel();
        _recordingStateTimer = null;
        return;
      }

      final state = _audioEngine!.getRecordingState();
      final duration = _audioEngine!.getRecordedDuration();

      // Debug: Log state changes
      if (state == 1 && !_isCountingIn) {
        debugPrint('📊 State: Counting In');
      } else if (state == 2 && !_isRecording) {
        debugPrint('📊 State: Recording (duration: ${duration.toStringAsFixed(1)}s)');
      } else if (state == 0 && (_isRecording || _isCountingIn)) {
        debugPrint('📊 State: Stopped');
      }

      if (state == 1 && !_isCountingIn) {
        // Transitioned to count-in
        setState(() {
          _isCountingIn = true;
          _statusMessage = 'Count-in...';
        });
      } else if (state == 2 && !_isRecording) {
        // Transitioned to recording
        setState(() {
          _isCountingIn = false;
          _isRecording = true;
          _statusMessage = 'Recording... ${duration.toStringAsFixed(1)}s';
        });
      } else if (state == 2 && _isRecording) {
        // Update recording duration display
        setState(() {
          _statusMessage = 'Recording... ${duration.toStringAsFixed(1)}s';
        });
      } else if (state == 0 && (_isRecording || _isCountingIn)) {
        // Recording stopped
        timer.cancel();
        _recordingStateTimer = null;
        setState(() {
          _isRecording = false;
          _isCountingIn = false;
        });
      }
    });
  }

  void _toggleMetronome() {
    if (_audioEngine == null) return;

    try {
      final newState = !_metronomeEnabled;
      debugPrint('🎵 Toggling metronome: ${newState ? "ON" : "OFF"}');
      _audioEngine!.setMetronomeEnabled(newState);
      setState(() {
        _metronomeEnabled = newState;
        _statusMessage = newState ? 'Metronome enabled' : 'Metronome disabled';
      });
      debugPrint('✅ Metronome toggled successfully');
    } catch (e) {
      debugPrint('❌ Metronome toggle error: $e');
      setState(() {
        _statusMessage = 'Metronome toggle error: $e';
      });
    }
  }

  void _onTempoChanged(double bpm) {
    if (_audioEngine == null) return;

    // Clamp tempo to valid range (20-300 BPM)
    final clampedBpm = bpm.clamp(20.0, 300.0);

    try {
      _audioEngine!.setTempo(clampedBpm);
      setState(() {
        _tempo = clampedBpm;
      });
      debugPrint('🎵 Tempo changed to: ${clampedBpm.toStringAsFixed(1)} BPM');
    } catch (e) {
      debugPrint('❌ Tempo change error: $e');
      setState(() {
        _statusMessage = 'Tempo change error: $e';
      });
    }
  }

  // M3: Virtual piano methods
  void _toggleVirtualPiano() {
    debugPrint('🎹 [DEBUG] _toggleVirtualPiano called');
    debugPrint('🎹 [DEBUG] _audioEngine is null: ${_audioEngine == null}');
    debugPrint('🎹 [DEBUG] Current _virtualPianoEnabled: $_virtualPianoEnabled');
    debugPrint('🎹 [DEBUG] Current _virtualPianoVisible: $_virtualPianoVisible');

    if (_audioEngine == null) {
      debugPrint('❌ [DEBUG] Audio engine is null, returning');
      return;
    }

    setState(() {
      _virtualPianoEnabled = !_virtualPianoEnabled;
      debugPrint('🎹 [DEBUG] New _virtualPianoEnabled: $_virtualPianoEnabled');

      if (_virtualPianoEnabled) {
        // Enable: Initialize MIDI, start audio stream, and show panel
        try {
          debugPrint('🎹 [DEBUG] Starting MIDI input...');
          _audioEngine!.startMidiInput();
          debugPrint('✅ [DEBUG] MIDI input started');

          // CRITICAL: Start audio output stream so synthesizer can be heard
          // The synthesizer generates audio but needs the stream running to output it
          debugPrint('🎹 [DEBUG] Starting transport play...');
          _audioEngine!.transportPlay();
          debugPrint('✅ [DEBUG] Transport play started');

          _virtualPianoVisible = true;
          debugPrint('🎹 [DEBUG] Set _virtualPianoVisible = true');
          _statusMessage = 'Virtual piano enabled - Press keys to play!';
          debugPrint('✅ Virtual piano enabled');
        } catch (e) {
          debugPrint('❌ Virtual piano enable error: $e');
          debugPrint('❌ [DEBUG] Stack trace: ${StackTrace.current}');
          _statusMessage = 'Virtual piano error: $e';
          _virtualPianoEnabled = false;
          _virtualPianoVisible = false;
        }
      } else {
        // Disable: Hide panel
        debugPrint('🎹 [DEBUG] Hiding piano panel...');
        _virtualPianoVisible = false;
        _editorPanelVisible = false; // Hide editor panel when piano disabled
        _statusMessage = 'Virtual piano disabled';
        debugPrint('🎹 Virtual piano disabled');
      }
    });

    debugPrint('🎹 [DEBUG] After setState - _virtualPianoVisible: $_virtualPianoVisible');
  }

  // M4: Mixer methods
  void _toggleMixer() {
    setState(() {
      _mixerVisible = !_mixerVisible;
    });
  }

  // Unified track selection method - handles both timeline and mixer clicks
  void _onTrackSelected(int? trackId) {
    if (trackId == null) {
      setState(() {
        _selectedTrackId = null;
        _editorPanelVisible = false;
      });
      return;
    }

    setState(() {
      _selectedTrackId = trackId;
      _editorPanelVisible = true;

      // Clear clip selection when selecting just a track
      _selectedMidiClipId = null;
      _currentEditingClip = null;
    });

    debugPrint('🎯 Track $trackId selected');
  }

  // M9: Instrument methods
  void _onInstrumentSelected(int trackId, String instrumentId) {
    setState(() {
      // Create default instrument data for the track
      final instrumentData = InstrumentData.defaultSynthesizer(trackId);
      _trackInstruments[trackId] = instrumentData;
      _selectedTrackId = trackId; // Select the track when instrument is assigned
      _editorPanelVisible = true; // Show editor panel when instrument selected

      // Call audio engine to set instrument
      if (_audioEngine != null) {
        _audioEngine!.setTrackInstrument(trackId, instrumentId);
      }
    });
    debugPrint('🎹 Track $trackId instrument set to: $instrumentId');
  }

  void _onTrackDeleted(int trackId) {
    setState(() {
      // Find all MIDI clips on this track and remove their mappings
      final clipsToRemove = _midiClips.where((clip) => clip.trackId == trackId).toList();
      for (final clip in clipsToRemove) {
        _dartToRustClipIds.remove(clip.clipId);
      }

      // Remove all MIDI clips associated with this track
      _midiClips.removeWhere((clip) => clip.trackId == trackId);

      // Clear current editing clip if it was on this track
      if (_currentEditingClip != null && _currentEditingClip!.trackId == trackId) {
        _currentEditingClip = null;
        _selectedMidiClipId = null;
      }

      // Remove instrument mapping
      _trackInstruments.remove(trackId);

      debugPrint('🧹 Cleaned up MIDI state for deleted track $trackId');
    });
  }

  void _onTrackDuplicated(int sourceTrackId, int newTrackId) {
    setState(() {
      // Copy instrument mapping from source track to new track if it exists
      if (_trackInstruments.containsKey(sourceTrackId)) {
        final sourceInstrument = _trackInstruments[sourceTrackId]!;
        // Create a copy with the new track ID
        _trackInstruments[newTrackId] = InstrumentData(
          trackId: newTrackId,
          type: sourceInstrument.type,
          parameters: Map.from(sourceInstrument.parameters),
        );
        debugPrint('🎹 Copied instrument from track $sourceTrackId to track $newTrackId');
      }
    });
  }

  void _onInstrumentDropped(int trackId, Instrument instrument) {
    debugPrint('🎹 _onInstrumentDropped CALLED: track=$trackId, instrument=${instrument.name}');
    // Reuse the same logic as _onInstrumentSelected
    _onInstrumentSelected(trackId, instrument.id);
    debugPrint('🎹 Instrument "${instrument.name}" dropped on track $trackId');
  }

  void _onInstrumentDroppedOnEmpty(Instrument instrument) {
    debugPrint('🎹 _onInstrumentDroppedOnEmpty CALLED: instrument=${instrument.name}');
    if (_audioEngine == null) {
      debugPrint('❌ Audio engine is null');
      return;
    }

    // Create a new MIDI track
    final trackId = _audioEngine!.createTrack('midi', 'MIDI');
    if (trackId < 0) {
      debugPrint('❌ Failed to create new MIDI track');
      return;
    }

    // Assign the instrument to the new track
    _onInstrumentSelected(trackId, instrument.id);
    debugPrint('✅ Created new MIDI track $trackId with instrument "${instrument.name}"');
  }

  // VST3 Instrument drop handlers
  void _onVst3InstrumentDropped(int trackId, Vst3Plugin plugin) async {
    debugPrint('🎹 _onVst3InstrumentDropped CALLED: track=$trackId, plugin=${plugin.name}');
    if (_audioEngine == null) {
      debugPrint('❌ Audio engine is null');
      return;
    }

    try {
      // Load the VST3 plugin as a track instrument
      final effectId = _audioEngine!.addVst3EffectToTrack(trackId, plugin.path);
      if (effectId < 0) {
        debugPrint('❌ Failed to load VST3 instrument: ${plugin.name}');
        return;
      }

      // Create and store InstrumentData for this VST3 instrument
      setState(() {
        _trackInstruments[trackId] = InstrumentData.vst3Instrument(
          trackId: trackId,
          pluginPath: plugin.path,
          pluginName: plugin.name,
          effectId: effectId,
        );
      });

      debugPrint('✅ VST3 instrument "${plugin.name}" loaded on track $trackId (effectId: $effectId)');
    } catch (e) {
      debugPrint('❌ Error loading VST3 instrument: $e');
    }
  }

  void _onVst3InstrumentDroppedOnEmpty(Vst3Plugin plugin) async {
    debugPrint('🎹 _onVst3InstrumentDroppedOnEmpty CALLED: plugin=${plugin.name}');
    if (_audioEngine == null) {
      debugPrint('❌ Audio engine is null');
      return;
    }

    try {
      // Create a new MIDI track
      final trackId = _audioEngine!.createTrack('midi', 'MIDI');
      if (trackId < 0) {
        debugPrint('❌ Failed to create new MIDI track');
        return;
      }

      // Load the VST3 plugin as a track instrument
      final effectId = _audioEngine!.addVst3EffectToTrack(trackId, plugin.path);
      if (effectId < 0) {
        debugPrint('❌ Failed to load VST3 instrument: ${plugin.name}');
        return;
      }

      // Create and store InstrumentData for this VST3 instrument
      setState(() {
        _trackInstruments[trackId] = InstrumentData.vst3Instrument(
          trackId: trackId,
          pluginPath: plugin.path,
          pluginName: plugin.name,
          effectId: effectId,
        );
      });

      debugPrint('✅ Created new MIDI track $trackId with VST3 instrument "${plugin.name}" (effectId: $effectId)');
    } catch (e) {
      debugPrint('❌ Error creating MIDI track with VST3 instrument: $e');
    }
  }

  void _onInstrumentParameterChanged(InstrumentData instrumentData) {
    setState(() {
      _trackInstruments[instrumentData.trackId] = instrumentData;
    });
    debugPrint('🎹 Updated instrument parameters for track ${instrumentData.trackId}');
  }

  // M10: VST3 Plugin methods
  Future<void> _loadCachedVst3Plugins() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedVersion = prefs.getInt('vst3_cache_version') ?? 0;
      const currentVersion = 8; // Incremented - default to INSTRUMENT instead of EFFECT

      debugPrint('📦 Cache check: cached version=$cachedVersion, current version=$currentVersion');

      // Invalidate cache if version doesn't match
      if (cachedVersion != currentVersion) {
        debugPrint('📦 ❌ Cache version MISMATCH - deleting old cache and forcing fresh scan');
        await prefs.remove('vst3_plugins_cache');
        debugPrint('📦 ✅ Old cache deleted');
        await prefs.remove('vst3_plugins_cache');
        await prefs.remove('vst3_scan_timestamp');
        await prefs.setInt('vst3_cache_version', currentVersion);
        return;
      }

      final cachedJson = prefs.getString('vst3_plugins_cache');

      if (cachedJson != null) {
        debugPrint('📦 Loading VST3 cache from SharedPreferences');
        final List<dynamic> decoded = jsonDecode(cachedJson);
        final plugins = decoded.map((item) => Map<String, String>.from(item as Map)).toList();

        debugPrint('📦 Decoded ${plugins.length} plugins from cache:');
        for (var plugin in plugins) {
          debugPrint('  - ${plugin['name']} at ${plugin['path']} (instrument: ${plugin['is_instrument']}, effect: ${plugin['is_effect']})');
        }

        // Verify that plugins have type information
        bool hasTypeInfo = plugins.every((plugin) =>
          plugin.containsKey('is_instrument') && plugin.containsKey('is_effect')
        );

        if (!hasTypeInfo) {
          debugPrint('⚠️  Cache missing type information - invalidating cache');
          await prefs.remove('vst3_plugins_cache');
          return;
        }

        setState(() {
          _availableVst3Plugins = plugins;
          _pluginsScanned = true;
        });

        debugPrint('✅ Loaded ${plugins.length} VST3 plugins from cache');
        debugPrint('✅ _availableVst3Plugins now has ${_availableVst3Plugins.length} items');
      } else {
        debugPrint('⚠️  No VST3 cache found in SharedPreferences');
      }
    } catch (e) {
      debugPrint('⚠️  Failed to load VST3 cache: $e');
    }
  }

  Future<void> _saveVst3PluginsCache(List<Map<String, String>> plugins) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(plugins);
      await prefs.setString('vst3_plugins_cache', json);
      await prefs.setInt('vst3_scan_timestamp', DateTime.now().millisecondsSinceEpoch);
      await prefs.setInt('vst3_cache_version', 8); // Save cache version
      debugPrint('✅ Saved ${plugins.length} VST3 plugins to cache (version 8)');
    } catch (e) {
      debugPrint('⚠️  Failed to save VST3 cache: $e');
    }
  }

  void _scanVst3Plugins({bool forceRescan = false}) async {
    if (_audioEngine == null || _isScanningVst3Plugins) return;

    debugPrint('📦 _scanVst3Plugins called (forceRescan=$forceRescan, _pluginsScanned=$_pluginsScanned)');

    // Load from cache if not forcing rescan
    if (!forceRescan && !_pluginsScanned) {
      debugPrint('📦 Attempting to load from cache...');
      await _loadCachedVst3Plugins();

      // If cache loaded successfully, we're done
      if (_availableVst3Plugins.isNotEmpty) {
        debugPrint('📦 ✅ Cache loaded successfully, skipping fresh scan');
        return;
      }
      debugPrint('📦 ⚠️  Cache empty, proceeding to fresh scan');
    }

    setState(() {
      _isScanningVst3Plugins = true;
      _statusMessage = forceRescan ? 'Rescanning VST3 plugins...' : 'Scanning VST3 plugins...';
    });

    try {
      debugPrint('📦 🔍 Starting fresh VST3 plugin scan from C++...');
      final plugins = _audioEngine!.scanVst3PluginsStandard();
      debugPrint('📦 🔍 Scan returned ${plugins.length} plugins');

      // Log each plugin's categorization
      for (final plugin in plugins) {
        debugPrint('📦 Plugin: ${plugin['name']} | is_instrument: ${plugin['is_instrument']} | is_effect: ${plugin['is_effect']}');
      }

      // Save to cache
      await _saveVst3PluginsCache(plugins);

      setState(() {
        _availableVst3Plugins = plugins;
        _pluginsScanned = true;
        _isScanningVst3Plugins = false;
        _statusMessage = 'Found ${plugins.length} VST3 plugin${plugins.length == 1 ? '' : 's'}';
      });

      debugPrint('✅ Found ${plugins.length} VST3 plugins');
    } catch (e) {
      setState(() {
        _isScanningVst3Plugins = false;
        _statusMessage = 'VST3 scan failed: $e';
      });
      debugPrint('❌ VST3 scan failed: $e');
    }
  }

  void _addVst3PluginToTrack(int trackId, Map<String, String> plugin) {
    if (_audioEngine == null) return;

    debugPrint('🔌 Adding VST3 plugin "${plugin['name']}" to track $trackId');

    try {
      final pluginPath = plugin['path'] ?? '';
      final effectId = _audioEngine!.addVst3EffectToTrack(trackId, pluginPath);

      if (effectId >= 0) {
        setState(() {
          _trackVst3Effects[trackId] ??= [];
          _trackVst3Effects[trackId]!.add(effectId);
          _vst3PluginCache[effectId] = plugin;
          _statusMessage = 'Added ${plugin['name']} to track $trackId';
        });

        // Show success snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Added ${plugin['name']} to track'),
            duration: const Duration(seconds: 2),
            backgroundColor: const Color(0xFF4CAF50),
          ),
        );

        debugPrint('✅ VST3 plugin added with effect ID: $effectId');
      } else {
        setState(() {
          _statusMessage = 'Failed to add VST3 plugin';
        });

        // Show error snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to load ${plugin['name']}'),
            duration: const Duration(seconds: 3),
            backgroundColor: const Color(0xFFFF5722),
          ),
        );

        debugPrint('❌ Failed to add VST3 plugin');
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error adding plugin: $e';
      });

      // Show error snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: $e'),
          duration: const Duration(seconds: 3),
          backgroundColor: const Color(0xFFFF5722),
        ),
      );

      debugPrint('❌ Error adding VST3 plugin: $e');
    }
  }

  void _removeVst3Plugin(int effectId) {
    if (_audioEngine == null) return;

    debugPrint('🗑️ Removing VST3 plugin effect $effectId');

    // Find which track this effect is on
    int? trackId;
    for (final entry in _trackVst3Effects.entries) {
      if (entry.value.contains(effectId)) {
        trackId = entry.key;
        break;
      }
    }

    if (trackId == null) {
      debugPrint('❌ Could not find track for effect $effectId');
      return;
    }

    try {
      // Remove via audio engine (uses existing removeEffectFromTrack)
      _audioEngine!.removeEffectFromTrack(trackId, effectId);

      setState(() {
        _trackVst3Effects[trackId]?.remove(effectId);
        _vst3PluginCache.remove(effectId);
        _statusMessage = 'Removed VST3 plugin';
      });

      debugPrint('✅ VST3 plugin removed');
    } catch (e) {
      setState(() {
        _statusMessage = 'Error removing plugin: $e';
      });
      debugPrint('❌ Error removing VST3 plugin: $e');
    }
  }

  void _showVst3PluginBrowser(int trackId) async {
    if (_audioEngine == null) return;

    debugPrint('🔍 Opening VST3 browser with ${_availableVst3Plugins.length} plugins');
    debugPrint('🔍 _pluginsScanned: $_pluginsScanned, _isScanningVst3Plugins: $_isScanningVst3Plugins');
    for (var plugin in _availableVst3Plugins) {
      debugPrint('  - ${plugin['name']} (${plugin['path']})');
    }

    // Import the browser
    final vst3Browser = await showVst3PluginBrowser(
      context,
      availablePlugins: _availableVst3Plugins,
      isScanning: _isScanningVst3Plugins,
      onRescanRequested: () {
        _scanVst3Plugins(forceRescan: true);
      },
    );

    if (vst3Browser != null) {
      // User selected a plugin - add it to the track
      _addVst3PluginToTrack(trackId, {
        'name': vst3Browser.name,
        'path': vst3Browser.path,
        'vendor': vst3Browser.vendor ?? '',
      });
    }
  }

  void _onVst3PluginDropped(int trackId, Vst3Plugin plugin) {
    debugPrint('🎯 VST3 plugin dropped on track $trackId: ${plugin.name}');

    // Add the plugin to the track
    _addVst3PluginToTrack(trackId, {
      'name': plugin.name,
      'path': plugin.path,
      'vendor': plugin.vendor ?? '',
    });
  }

  Map<int, int> _getTrackVst3PluginCounts() {
    final counts = <int, int>{};
    for (final entry in _trackVst3Effects.entries) {
      counts[entry.key] = entry.value.length;
    }
    return counts;
  }

  List<Vst3PluginInstance> _getTrackVst3Plugins(int trackId) {
    final effectIds = _trackVst3Effects[trackId] ?? [];
    final plugins = <Vst3PluginInstance>[];

    for (final effectId in effectIds) {
      final pluginInfo = _vst3PluginCache[effectId];
      if (pluginInfo != null && _audioEngine != null) {
        try {
          // Fetch parameter count and info
          final paramCount = _audioEngine!.getVst3ParameterCount(effectId);
          final parameters = <int, Vst3ParameterInfo>{};
          final parameterValues = <int, double>{};

          for (int i = 0; i < paramCount; i++) {
            final info = _audioEngine!.getVst3ParameterInfo(effectId, i);
            if (info != null) {
              parameters[i] = Vst3ParameterInfo(
                index: i,
                name: info['name'] as String? ?? 'Parameter $i',
                min: (info['min'] as num?)?.toDouble() ?? 0.0,
                max: (info['max'] as num?)?.toDouble() ?? 1.0,
                defaultValue: (info['default'] as num?)?.toDouble() ?? 0.5,
                unit: '',
              );

              // Fetch current value
              parameterValues[i] = _audioEngine!.getVst3ParameterValue(effectId, i);
            }
          }

          plugins.add(Vst3PluginInstance(
            effectId: effectId,
            pluginName: pluginInfo['name'] ?? 'Unknown',
            pluginPath: pluginInfo['path'] ?? '',
            parameters: parameters,
            parameterValues: parameterValues,
          ));
        } catch (e) {
          debugPrint('❌ Error fetching VST3 plugin info for effect $effectId: $e');
        }
      }
    }

    return plugins;
  }

  void _onVst3ParameterChanged(int effectId, int paramIndex, double value) {
    if (_audioEngine == null) return;

    try {
      _audioEngine!.setVst3ParameterValue(effectId, paramIndex, value);
      debugPrint('🎛️  VST3 parameter changed: effect=$effectId, param=$paramIndex, value=$value');
    } catch (e) {
      debugPrint('❌ Error setting VST3 parameter: $e');
    }
  }

  void _showVst3PluginEditor(int trackId) {
    final effectIds = _trackVst3Effects[trackId] ?? [];
    if (effectIds.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Plugins - Track $trackId'),
        content: SizedBox(
          width: 400,
          child: ListView.builder(
            itemCount: effectIds.length,
            itemBuilder: (context, index) {
              final effectId = effectIds[index];
              final pluginInfo = _vst3PluginCache[effectId];
              final pluginName = pluginInfo?['name'] ?? 'Unknown Plugin';

              return ListTile(
                title: Text(pluginName),
                trailing: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _showPluginParameterEditor(effectId, pluginName);
                  },
                  child: const Text('Edit'),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showPluginParameterEditor(int effectId, String pluginName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$pluginName - Parameters'),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Parameter editing',
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Drag the sliders to adjust plugin parameters.',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('🎛️  Native editor support coming soon! For now, use the parameter sliders.'),
                                  duration: Duration(seconds: 3),
                                ),
                              );
                            },
                            icon: const Icon(Icons.open_in_new, size: 16),
                            label: const Text('Open GUI'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Show a few example parameters
                      ..._buildParameterSliders(effectId),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildParameterSliders(int effectId) {
    // Show first 8 parameters or however many are available
    List<Widget> sliders = [];

    for (int i = 0; i < 8; i++) {
      sliders.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Parameter ${i + 1}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    '0.50',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Slider(
                value: 0.5,
                min: 0.0,
                max: 1.0,
                divisions: 100,
                onChanged: (value) {
                  _onVst3ParameterChanged(effectId, i, value);
                },
              ),
            ],
          ),
        ),
      );
    }

    return sliders;
  }

  // M6: Panel toggle methods
  void _toggleLibraryPanel() {
    setState(() {
      _libraryPanelCollapsed = !_libraryPanelCollapsed;
    });
  }

  void _toggleEditor() {
    setState(() {
      _editorPanelVisible = !_editorPanelVisible;
    });
  }

  void _resetPanelLayout() {
    setState(() {
      // Reset to default panel sizes
      _libraryPanelWidth = 200.0;
      _mixerPanelWidth = 380.0;
      _editorPanelHeight = 250.0;

      // Reset visibility states
      _libraryPanelCollapsed = false;
      _mixerVisible = true;
      _editorPanelVisible = true;

      _statusMessage = 'Panel layout reset';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Panel layout reset to defaults')),
    );
  }

  // M8: MIDI clip selection methods
  void _onMidiClipSelected(int? clipId, MidiClipData? clipData) {
    setState(() {
      _selectedMidiClipId = clipId;
      _currentEditingClip = clipData;
      if (clipId != null && clipData != null) {
        // Open piano roll and set the selected track
        _editorPanelVisible = true;
        _selectedTrackId = clipData.trackId;
      }
    });
  }

  void _onMidiClipUpdated(MidiClipData updatedClip) {
    setState(() {
      // Calculate clip duration based on notes (convert from beats to seconds)
      double durationInSeconds;

      if (updatedClip.notes.isEmpty) {
        // Default to 4 bars (16 beats) if no notes
        final defaultBeats = 16.0;
        durationInSeconds = (defaultBeats / _tempo) * 60.0;
      } else {
        // Find the furthest note end time (in beats)
        final furthestBeat = updatedClip.notes
            .map((note) => note.startTime + note.duration)
            .reduce((a, b) => a > b ? a : b);

        // Add 1 bar (4 beats) of padding after the last note
        final totalBeats = furthestBeat + 4.0;

        // Convert beats to seconds: seconds = (beats / BPM) * 60
        durationInSeconds = (totalBeats / _tempo) * 60.0;
      }

      // Check if we're editing an existing clip or need to create a new one
      if (updatedClip.clipId == -1) {
        // No clip ID provided - check if we're editing an existing clip
        if (_currentEditingClip != null && _currentEditingClip!.clipId != -1) {
          // Reuse the existing clip we're editing
          _currentEditingClip = updatedClip.copyWith(
            clipId: _currentEditingClip!.clipId,
            startTime: _currentEditingClip!.startTime,
            duration: durationInSeconds,
          );

          // Update in clips list
          final index = _midiClips.indexWhere((c) => c.clipId == _currentEditingClip!.clipId);
          if (index != -1) {
            _midiClips[index] = _currentEditingClip!;
          }

          debugPrint('✅ Updated existing MIDI clip ${_currentEditingClip!.clipId} (duration: ${durationInSeconds.toStringAsFixed(2)}s)');
        } else if (updatedClip.notes.isNotEmpty) {
          // Create a brand new clip only if we have notes and no clip is being edited
          final newClipId = DateTime.now().millisecondsSinceEpoch;

          _currentEditingClip = updatedClip.copyWith(
            clipId: newClipId,
            startTime: _playheadPosition,
            duration: durationInSeconds,
          );
          _selectedMidiClipId = newClipId;

          // Add to clips list for timeline visualization
          _midiClips.add(_currentEditingClip!);

          debugPrint('✅ Auto-created MIDI clip $newClipId at ${_playheadPosition.toStringAsFixed(2)}s (duration: ${durationInSeconds.toStringAsFixed(2)}s)');
        } else {
          // No notes and no existing clip - just update current editing clip
          _currentEditingClip = updatedClip.copyWith(
            duration: durationInSeconds,
          );
        }
      } else {
        // Clip ID provided - update existing clip with new duration
        _currentEditingClip = updatedClip.copyWith(
          duration: durationInSeconds,
        );

        // Update in clips list
        final index = _midiClips.indexWhere((c) => c.clipId == updatedClip.clipId);
        if (index != -1) {
          _midiClips[index] = _currentEditingClip!;
        }
      }
    });

    // Schedule MIDI clip for playback
    if (_audioEngine != null && _currentEditingClip != null) {
      _scheduleMidiClipPlayback(_currentEditingClip!);
    }
  }

  /// Schedule MIDI clip notes for playback during transport
  void _scheduleMidiClipPlayback(MidiClipData clip) {
    if (_audioEngine == null) return;

    debugPrint('🎵 Syncing MIDI clip to Rust audio graph');
    debugPrint('   Clip: ${clip.name} (Dart ID: ${clip.clipId})');
    debugPrint('   Track: ${clip.trackId}');
    debugPrint('   Start time: ${clip.startTime}s');
    debugPrint('   ${clip.notes.length} notes');

    // Check if this Dart clip already has a Rust clip
    int rustClipId;
    bool isNewClip = false;

    if (_dartToRustClipIds.containsKey(clip.clipId)) {
      // Existing clip - reuse the Rust clip ID
      rustClipId = _dartToRustClipIds[clip.clipId]!;
      debugPrint('   Reusing existing Rust clip ID: $rustClipId');

      // Clear existing notes (we'll re-add all of them)
      final clearResult = _audioEngine!.clearMidiClip(rustClipId);
      if (clearResult.startsWith('Error')) {
        debugPrint('   ⚠️  Failed to clear clip: $clearResult');
      } else {
        debugPrint('   ✓ Cleared existing notes');
      }
    } else {
      // New clip - create in Rust
      rustClipId = _audioEngine!.createMidiClip();
      if (rustClipId < 0) {
        debugPrint('❌ Failed to create Rust MIDI clip');
        return;
      }
      _dartToRustClipIds[clip.clipId] = rustClipId;
      isNewClip = true;
      debugPrint('   Created new Rust clip ID: $rustClipId');
    }

    // Add all notes to the Rust clip
    for (final note in clip.notes) {
      // Convert beats to seconds using current tempo
      final startTimeSeconds = note.startTimeInSeconds(_tempo);
      final durationSeconds = note.durationInSeconds(_tempo);

      final result = _audioEngine!.addMidiNoteToClip(
        rustClipId,
        note.note,
        note.velocity,
        startTimeSeconds,
        durationSeconds,
      );

      if (result.startsWith('Error')) {
        debugPrint('   ⚠️  Failed to add note ${note.noteName}: $result');
      }
    }

    // Only add to timeline if this is a new clip
    if (isNewClip) {
      final result = _audioEngine!.addMidiClipToTrack(
        clip.trackId,
        rustClipId,
        clip.startTime,
      );

      if (result == 0) {
        debugPrint('✅ MIDI clip synced to audio graph successfully');
      } else {
        debugPrint('❌ Failed to add MIDI clip to track timeline (result: $result)');
      }
    } else {
      debugPrint('✅ MIDI clip notes updated (${clip.notes.length} notes)');
    }
  }

  /// Play MIDI clip immediately (for testing/preview)
  void _playMidiClipImmediately(MidiClipData clip) {
    for (final note in clip.notes) {
      // Trigger note on
      _audioEngine?.sendMidiNoteOn(note.note, note.velocity);

      // Schedule note off after duration
      final tempo = _tempo;
      final durationMs = (note.durationInSeconds(tempo) * 1000).toInt();
      Future.delayed(Duration(milliseconds: durationMs), () {
        _audioEngine?.sendMidiNoteOff(note.note, 0);
      });
    }
  }

  // M5: Project file methods
  void _newProject() {
    // Show confirmation dialog if current project has unsaved changes
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Project'),
        content: const Text('Create a new project? Any unsaved changes will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _currentProjectPath = null;
                _currentProjectName = 'Untitled Project';
                _loadedClipId = null;
                _waveformPeaks = [];
                _statusMessage = 'New project created';

                // Clear MIDI state
                _midiClips.clear();
                _dartToRustClipIds.clear();
                _selectedMidiClipId = null;
                _currentEditingClip = null;
              });
              debugPrint('🧹 Cleared MIDI clip state for new project');
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _openProject() async {
    try {
      // Use macOS native file picker
      final result = await Process.run('osascript', [
        '-e',
        'POSIX path of (choose folder with prompt "Select Solar Audio Project (.solar folder)")'
      ]);

      if (result.exitCode == 0) {
        var path = result.stdout.toString().trim();
        // Remove trailing slash if present
        if (path.endsWith('/')) {
          path = path.substring(0, path.length - 1);
        }

        debugPrint('📂 Selected path: $path');

        if (path.isEmpty) {
          debugPrint('❌ Path is empty');
          return;
        }

        if (!path.endsWith('.solar')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Please select a .solar folder')),
          );
          return;
        }

        setState(() => _isLoading = true);

        try {
          final loadResult = _audioEngine!.loadProject(path);

          // Clear MIDI clip ID mappings since Rust side has reset
          _dartToRustClipIds.clear();
          debugPrint('🧹 Cleared MIDI clip ID mappings on project load');

          // Load UI layout data
          _loadUILayout(path);

          setState(() {
            _currentProjectPath = path;
            _currentProjectName = path.split('/').last.replaceAll('.solar', '');
            _statusMessage = 'Project loaded: $_currentProjectName';
            _isLoading = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(loadResult)),
          );
        } catch (e) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load project: $e')),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Open project failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open project: $e')),
      );
    }
  }

  void _saveProject() {
    if (_currentProjectPath != null) {
      _saveProjectToPath(_currentProjectPath!);
    } else {
      _saveProjectAs();
    }
  }

  void _saveProjectAs() async {
    // Show dialog to enter project name
    final nameController = TextEditingController(text: _currentProjectName);

    final projectName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Project As'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Project Name',
            hintText: 'Enter project name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, nameController.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (projectName == null || projectName.isEmpty) return;

    try {
      // Use macOS native file picker for save location
      final result = await Process.run('osascript', [
        '-e',
        'POSIX path of (choose folder with prompt "Choose location to save project")'
      ]);

      if (result.exitCode == 0) {
        final parentPath = result.stdout.toString().trim();
        if (parentPath.isNotEmpty) {
          final projectPath = '$parentPath/$projectName.solar';
          _saveProjectToPath(projectPath);
        }
      }
    } catch (e) {
      debugPrint('❌ Save As failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save project: $e')),
      );
    }
  }

  void _saveProjectToPath(String path) {
    setState(() => _isLoading = true);

    try {
      final result = _audioEngine!.saveProject(_currentProjectName, path);

      // Save UI layout data
      _saveUILayout(path);

      setState(() {
        _currentProjectPath = path;
        _statusMessage = 'Project saved';
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result)),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('❌ Save project failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save project: $e')),
      );
    }
  }

  /// Save UI layout state to JSON file
  void _saveUILayout(String projectPath) {
    try {
      final uiLayoutData = {
        'version': '1.0',
        'panel_sizes': {
          'library_width': _libraryPanelWidth,
          'mixer_width': _mixerPanelWidth,
          'bottom_height': _editorPanelHeight,
        },
        'panel_collapsed': {
          'library': _libraryPanelCollapsed,
          'mixer': !_mixerVisible,
          'bottom': !(_editorPanelVisible || _virtualPianoVisible),
        },
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(uiLayoutData);
      final uiLayoutFile = File('$projectPath/ui_layout.json');
      uiLayoutFile.writeAsStringSync(jsonString);
      debugPrint('💾 UI layout saved to: ${uiLayoutFile.path}');
    } catch (e) {
      debugPrint('⚠️  Failed to save UI layout: $e');
    }
  }

  /// Load UI layout state from JSON file
  void _loadUILayout(String projectPath) {
    try {
      final uiLayoutFile = File('$projectPath/ui_layout.json');
      if (!uiLayoutFile.existsSync()) {
        debugPrint('ℹ️  No UI layout file found, using defaults');
        return;
      }

      final jsonString = uiLayoutFile.readAsStringSync();
      final Map<String, dynamic> data = jsonDecode(jsonString);

      setState(() {
        // Load panel sizes
        final panelSizes = data['panel_sizes'] as Map<String, dynamic>?;
        if (panelSizes != null) {
          _libraryPanelWidth = (panelSizes['library_width'] as num?)?.toDouble() ?? 200.0;
          _mixerPanelWidth = (panelSizes['mixer_width'] as num?)?.toDouble() ?? 380.0;
          _editorPanelHeight = (panelSizes['bottom_height'] as num?)?.toDouble() ?? 250.0;

          // Clamp to min/max values
          _libraryPanelWidth = _libraryPanelWidth.clamp(_libraryMinWidth, _libraryMaxWidth);
          _mixerPanelWidth = _mixerPanelWidth.clamp(_mixerMinWidth, _mixerMaxWidth);
          _editorPanelHeight = _editorPanelHeight.clamp(_editorMinHeight, _editorMaxHeight);
        }

        // Load collapsed states
        final panelCollapsed = data['panel_collapsed'] as Map<String, dynamic>?;
        if (panelCollapsed != null) {
          _libraryPanelCollapsed = panelCollapsed['library'] as bool? ?? false;
          _mixerVisible = !(panelCollapsed['mixer'] as bool? ?? false);
          final bottomCollapsed = panelCollapsed['bottom'] as bool? ?? false;
          if (!bottomCollapsed) {
            // Only restore if it was expanded before
            // Don't auto-open bottom panel on load
          }
        }
      });

      debugPrint('📂 UI layout loaded from: ${uiLayoutFile.path}');
    } catch (e) {
      debugPrint('⚠️  Failed to load UI layout: $e');
    }
  }

  void _exportAudio() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Audio'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Choose export format:'),
            SizedBox(height: 16),
            Text('• WAV - Lossless (Recommended)'),
            Text('• MP3 - 128 kbps (Coming Soon)'),
            Text('• Stems - Individual tracks (Coming Soon)'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              // Get export path
              try {
                final result = await Process.run('osascript', [
                  '-e',
                  'POSIX path of (choose file name with prompt "Export as" default name "${_currentProjectName}.wav")'
                ]);

                if (result.exitCode == 0) {
                  final path = result.stdout.toString().trim();
                  if (path.isNotEmpty) {
                    try {
                      final exportResult = _audioEngine!.exportToWav(path, true);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(exportResult)),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Export not yet implemented: $e')),
                      );
                    }
                  }
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to export: $e')),
                );
              }
            },
            child: const Text('Export WAV'),
          ),
        ],
      ),
    );
  }

  void _exportMidi() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export MIDI'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Export MIDI functionality coming soon.'),
            SizedBox(height: 16),
            Text('This will export:'),
            Text('• All MIDI tracks as .mid file'),
            Text('• Preserve tempo and time signatures'),
            Text('• Include all note data and velocities'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _makeCopy() async {
    if (_currentProjectPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No project to copy')),
      );
      return;
    }

    // Show dialog to enter copy name
    final nameController = TextEditingController(text: '$_currentProjectName Copy');

    final copyName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Make a Copy'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Copy Name',
            hintText: 'Enter name for the copy',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, nameController.text),
            child: const Text('Create Copy'),
          ),
        ],
      ),
    );

    if (copyName == null || copyName.isEmpty) return;

    try {
      // Use macOS native file picker for save location
      final result = await Process.run('osascript', [
        '-e',
        'POSIX path of (choose folder with prompt "Choose location for copy")'
      ]);

      if (result.exitCode == 0) {
        final parentPath = result.stdout.toString().trim();
        if (parentPath.isNotEmpty) {
          final copyPath = '$parentPath/$copyName.solar';

          // Save current project state to the new location
          setState(() => _isLoading = true);

          try {
            final saveResult = _audioEngine!.saveProject(copyName, copyPath);

            // Save UI layout data for the copy
            _saveUILayout(copyPath);

            setState(() => _isLoading = false);

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Copy created: $copyName')),
            );
          } catch (e) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to create copy: $e')),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Make Copy failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create copy: $e')),
      );
    }
  }

  void _projectSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Project Settings'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Project settings coming soon.'),
            SizedBox(height: 16),
            Text('Available settings will include:'),
            Text('• Sample Rate'),
            Text('• Bit Depth'),
            Text('• Default Time Signature'),
            Text('• Audio File Location'),
            Text('• Auto-save Interval'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _closeProject() {
    // Show confirmation dialog if current project has unsaved changes
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Close Project'),
        content: const Text('Are you sure you want to close the current project?\n\nAny unsaved changes will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);

              // Stop playback if active
              if (_isPlaying) {
                _stopPlayback();
              }

              // Clear project state
              setState(() {
                _currentProjectPath = null;
                _currentProjectName = 'Untitled';
                _statusMessage = 'No project loaded';
              });

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Project closed')),
              );
            },
            child: const Text('Close', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PlatformMenuBar(
      menus: [
        // Standard macOS app menu (Solar Audio)
        PlatformMenu(
          label: 'Solar Audio',
          menus: [
            PlatformMenuItem(
              label: 'About Solar Audio',
              onSelected: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('About Solar Audio'),
                    content: const Text('Solar Audio\nVersion M6.2\n\nA modern, cross-platform DAW'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              },
            ),
            if (Platform.isMacOS)
              const PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.servicesSubmenu),
            if (Platform.isMacOS)
              const PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.hide),
            if (Platform.isMacOS)
              const PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.hideOtherApplications),
            if (Platform.isMacOS)
              const PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.showAllApplications),
            PlatformMenuItem(
              label: 'Quit Solar Audio',
              shortcut: const SingleActivator(LogicalKeyboardKey.keyQ, meta: true),
              onSelected: () {
                // Close the app
                exit(0);
              },
            ),
          ],
        ),

        // File Menu
        PlatformMenu(
          label: 'File',
          menus: [
            PlatformMenuItem(
              label: 'New Project',
              shortcut: const SingleActivator(LogicalKeyboardKey.keyN, meta: true),
              onSelected: _newProject,
            ),
            PlatformMenuItem(
              label: 'Open Project...',
              shortcut: const SingleActivator(LogicalKeyboardKey.keyO, meta: true),
              onSelected: _openProject,
            ),
            PlatformMenuItem(
              label: 'Save',
              shortcut: const SingleActivator(LogicalKeyboardKey.keyS, meta: true),
              onSelected: _saveProject,
            ),
            PlatformMenuItem(
              label: 'Save As...',
              shortcut: const SingleActivator(LogicalKeyboardKey.keyS, meta: true, shift: true),
              onSelected: _saveProjectAs,
            ),
            PlatformMenuItem(
              label: 'Make a Copy...',
              onSelected: _makeCopy,
            ),
            PlatformMenuItem(
              label: 'Export Audio...',
              onSelected: _exportAudio,
            ),
            PlatformMenuItem(
              label: 'Export MIDI...',
              onSelected: _exportMidi,
            ),
            PlatformMenuItem(
              label: 'Project Settings...',
              shortcut: const SingleActivator(LogicalKeyboardKey.comma, meta: true),
              onSelected: _projectSettings,
            ),
            PlatformMenuItem(
              label: 'Close Project',
              shortcut: const SingleActivator(LogicalKeyboardKey.keyW, meta: true),
              onSelected: _closeProject,
            ),
          ],
        ),

        // Edit Menu
        PlatformMenu(
          label: 'Edit',
          menus: [
            PlatformMenuItem(
              label: 'Undo',
              shortcut: const SingleActivator(LogicalKeyboardKey.keyZ, meta: true),
              onSelected: null, // Disabled for now
            ),
            PlatformMenuItem(
              label: 'Redo',
              shortcut: const SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true),
              onSelected: null, // Disabled for now
            ),
            PlatformMenuItem(
              label: 'Cut',
              shortcut: const SingleActivator(LogicalKeyboardKey.keyX, meta: true),
              onSelected: null, // Disabled - future feature
            ),
            PlatformMenuItem(
              label: 'Copy',
              shortcut: const SingleActivator(LogicalKeyboardKey.keyC, meta: true),
              onSelected: null, // Disabled - future feature
            ),
            PlatformMenuItem(
              label: 'Paste',
              shortcut: const SingleActivator(LogicalKeyboardKey.keyV, meta: true),
              onSelected: null, // Disabled - future feature
            ),
            PlatformMenuItem(
              label: 'Delete',
              shortcut: const SingleActivator(LogicalKeyboardKey.delete),
              onSelected: null, // Disabled - future feature
            ),
            PlatformMenuItem(
              label: 'Select All',
              shortcut: const SingleActivator(LogicalKeyboardKey.keyA, meta: true),
              onSelected: null, // Disabled - future feature
            ),
          ],
        ),

        // View Menu
        PlatformMenu(
          label: 'View',
          menus: [
            PlatformMenuItem(
              label: !_libraryPanelCollapsed ? '✓ Show Library Panel' : 'Show Library Panel',
              shortcut: const SingleActivator(LogicalKeyboardKey.keyL, meta: true),
              onSelected: _toggleLibraryPanel,
            ),
            PlatformMenuItem(
              label: _mixerVisible ? '✓ Show Mixer Panel' : 'Show Mixer Panel',
              shortcut: const SingleActivator(LogicalKeyboardKey.keyM, meta: true),
              onSelected: _toggleMixer,
            ),
            PlatformMenuItem(
              label: _editorPanelVisible ? '✓ Show Editor Panel' : 'Show Editor Panel',
              shortcut: const SingleActivator(LogicalKeyboardKey.keyE, meta: true),
              onSelected: _toggleEditor,
            ),
            PlatformMenuItem(
              label: _virtualPianoEnabled ? '✓ Show Virtual Piano' : 'Show Virtual Piano',
              shortcut: const SingleActivator(LogicalKeyboardKey.keyP, meta: true),
              onSelected: _toggleVirtualPiano,
            ),
            PlatformMenuItem(
              label: 'Reset Panel Layout',
              onSelected: _resetPanelLayout,
            ),
            PlatformMenuItem(
              label: 'Zoom In',
              shortcut: const SingleActivator(LogicalKeyboardKey.equal, meta: true),
              onSelected: null, // Disabled - future feature
            ),
            PlatformMenuItem(
              label: 'Zoom Out',
              shortcut: const SingleActivator(LogicalKeyboardKey.minus, meta: true),
              onSelected: null, // Disabled - future feature
            ),
            PlatformMenuItem(
              label: 'Zoom to Fit',
              shortcut: const SingleActivator(LogicalKeyboardKey.digit0, meta: true),
              onSelected: null, // Disabled - future feature
            ),
          ],
        ),
      ],
      child: Scaffold(
        backgroundColor: const Color(0xFF909090), // Light grey background
        body: Column(
        children: [
          // Transport bar (with logo and file/mixer buttons)
          TransportBar(
            onPlay: _play,
            onPause: _pause,
            onStop: _stopPlayback,
            onRecord: _toggleRecording,
            onMetronomeToggle: _toggleMetronome,
            onPianoToggle: _toggleVirtualPiano,
            playheadPosition: _playheadPosition,
            isPlaying: _isPlaying,
            canPlay: true, // Always allow transport controls
            isRecording: _isRecording,
            isCountingIn: _isCountingIn,
            metronomeEnabled: _metronomeEnabled,
            virtualPianoEnabled: _virtualPianoEnabled,
            tempo: _tempo,
            onTempoChanged: _onTempoChanged,
            // New parameters for file menu and mixer toggle
            onNewProject: _newProject,
            onOpenProject: _openProject,
            onSaveProject: _saveProject,
            onSaveProjectAs: _saveProjectAs,
            onMakeCopy: _makeCopy,
            onExportAudio: _exportAudio,
            onExportMidi: _exportMidi,
            onProjectSettings: _projectSettings,
            onCloseProject: _closeProject,
            // View menu parameters
            onToggleLibrary: _toggleLibraryPanel,
            onToggleMixer: _toggleMixer,
            onToggleEditor: _toggleEditor,
            onTogglePiano: _toggleVirtualPiano,
            onResetPanelLayout: _resetPanelLayout,
            libraryVisible: !_libraryPanelCollapsed,
            mixerVisible: _mixerVisible,
            editorVisible: _editorPanelVisible,
            pianoVisible: _virtualPianoEnabled,
            isLoading: _isLoading,
          ),

          // Main content area - 3-column layout
          Expanded(
            child: Column(
              children: [
                // Top section: Library + Timeline + Mixer
                Expanded(
                  child: Row(
                    children: [
                      // Left: Library panel
                      SizedBox(
                        width: _libraryPanelCollapsed ? 40 : _libraryPanelWidth,
                        child: LibraryPanel(
                          isCollapsed: _libraryPanelCollapsed,
                          onToggle: _toggleLibraryPanel,
                          availableVst3Plugins: _availableVst3Plugins,
                        ),
                      ),

                      // Divider: Library/Timeline
                      ResizableDivider(
                        orientation: DividerOrientation.vertical,
                        isCollapsed: _libraryPanelCollapsed,
                        onDrag: (delta) {
                          setState(() {
                            _libraryPanelWidth = (_libraryPanelWidth + delta)
                                .clamp(_libraryMinWidth, _libraryMaxWidth);
                          });
                        },
                        onDoubleClick: () {
                          setState(() {
                            _libraryPanelCollapsed = !_libraryPanelCollapsed;
                          });
                        },
                      ),

                      // Center: Timeline area
                      Expanded(
                        child: TimelineView(
                          playheadPosition: _playheadPosition,
                          clipDuration: _clipDuration,
                          waveformPeaks: _waveformPeaks,
                          audioEngine: _audioEngine,
                          selectedMidiTrackId: _selectedTrackId,
                          selectedMidiClipId: _selectedMidiClipId,
                          currentEditingClip: _currentEditingClip,
                          midiClips: _midiClips, // Pass all MIDI clips for visualization
                          onMidiTrackSelected: _onTrackSelected,
                          onMidiClipSelected: _onMidiClipSelected,
                          onMidiClipUpdated: _onMidiClipUpdated,
                          onInstrumentDropped: _onInstrumentDropped,
                          onInstrumentDroppedOnEmpty: _onInstrumentDroppedOnEmpty,
                          onVst3InstrumentDropped: _onVst3InstrumentDropped,
                          onVst3InstrumentDroppedOnEmpty: _onVst3InstrumentDroppedOnEmpty,
                        ),
                      ),

                      // Right: Track mixer panel (always visible)
                      if (_mixerVisible) ...[
                        // Divider: Timeline/Mixer
                        ResizableDivider(
                          orientation: DividerOrientation.vertical,
                          isCollapsed: false,
                          onDrag: (delta) {
                            setState(() {
                              _mixerPanelWidth = (_mixerPanelWidth - delta)
                                  .clamp(_mixerMinWidth, _mixerMaxWidth);
                            });
                          },
                          onDoubleClick: () {
                            setState(() {
                              _mixerVisible = false;
                            });
                          },
                        ),

                        SizedBox(
                          width: _mixerPanelWidth,
                          child: TrackMixerPanel(
                            audioEngine: _audioEngine,
                            selectedTrackId: _selectedTrackId,
                            onTrackSelected: _onTrackSelected,
                            onInstrumentSelected: _onInstrumentSelected,
                            onTrackDuplicated: _onTrackDuplicated,
                            onTrackDeleted: _onTrackDeleted,
                            trackInstruments: _trackInstruments,
                            trackVst3PluginCounts: _getTrackVst3PluginCounts(), // M10
                            onFxButtonPressed: _showVst3PluginBrowser, // M10
                            onVst3PluginDropped: _onVst3PluginDropped, // M10
                            onEditPluginsPressed: _showVst3PluginEditor, // M10
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Editor panel: Piano Roll / FX Chain / Instrument / Virtual Piano
                if (_editorPanelVisible || _virtualPianoVisible) ...[
                  // Divider: Timeline/Editor Panel
                  ResizableDivider(
                    orientation: DividerOrientation.horizontal,
                    isCollapsed: false,
                    onDrag: (delta) {
                      setState(() {
                        _editorPanelHeight = (_editorPanelHeight - delta)
                            .clamp(_editorMinHeight, _editorMaxHeight);
                      });
                    },
                    onDoubleClick: () {
                      setState(() {
                        _editorPanelVisible = false;
                        _virtualPianoVisible = false;
                        _virtualPianoEnabled = false;
                      });
                    },
                  ),

                  SizedBox(
                    height: _editorPanelHeight,
                    child: EditorPanel(
                      audioEngine: _audioEngine,
                      virtualPianoEnabled: _virtualPianoEnabled,
                      selectedTrackId: _selectedTrackId,
                      currentInstrumentData: _selectedTrackId != null
                          ? _trackInstruments[_selectedTrackId]
                          : null,
                      onVirtualPianoClose: _toggleVirtualPiano,
                      currentEditingClip: _currentEditingClip,
                      onMidiClipUpdated: _onMidiClipUpdated,
                      onInstrumentParameterChanged: _onInstrumentParameterChanged,
                      currentTrackPlugins: _selectedTrackId != null // M10
                          ? _getTrackVst3Plugins(_selectedTrackId!)
                          : null,
                      onVst3ParameterChanged: _onVst3ParameterChanged, // M10
                      onVst3PluginRemoved: _removeVst3Plugin, // M10
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Status bar
          _buildStatusBar(),
        ],
      ),
    ),
    );
  }

  // Removed _buildTimelineView - now built inline in build method

  Widget _buildStatusBar() {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF606060),
        border: Border(
          top: BorderSide(color: Color(0xFF808080)),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _audioGraphInitialized ? Icons.check_circle : Icons.error,
            size: 12,
            color: _audioGraphInitialized 
                ? const Color(0xFF4CAF50)
                : const Color(0xFF808080),
          ),
          const SizedBox(width: 6),
          Text(
            _audioGraphInitialized ? 'Audio Engine Ready' : 'Initializing...',
            style: TextStyle(
              color: _audioGraphInitialized 
                  ? const Color(0xFF808080)
                  : const Color(0xFF606060),
              fontSize: 11,
            ),
          ),
          const Spacer(),
          if (_clipDuration != null)
            Text(
              'Duration: ${_clipDuration!.toStringAsFixed(3)}s',
              style: const TextStyle(
                color: Color(0xFF808080),
                fontSize: 11,
              ),
            ),
          if (_clipDuration != null) const SizedBox(width: 16),
          Text(
            'Sample Rate: 48kHz',
            style: const TextStyle(
              color: Color(0xFF808080),
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'CPU: 0%', // TODO: Get real CPU usage from audio engine
            style: const TextStyle(
              color: Color(0xFF808080),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

