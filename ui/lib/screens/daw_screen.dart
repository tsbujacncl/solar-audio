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
import '../services/undo_redo_manager.dart';
import '../services/commands/track_commands.dart';

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

  // Undo/Redo manager
  final UndoRedoManager _undoRedoManager = UndoRedoManager();

  // State
  double _playheadPosition = 0.0;
  int? _loadedClipId;
  double? _clipDuration;
  List<double> _waveformPeaks = [];
  bool _isPlaying = false;
  bool _isAudioGraphInitialized = false;
  String _statusMessage = '';
  bool _isLoading = false;

  // M2: Recording state
  bool _isRecording = false;
  bool _isCountingIn = false;
  bool _isMetronomeEnabled = true;
  double _tempo = 120.0;

  // M3: Virtual piano state
  bool _isVirtualPianoEnabled = false;
  bool _isVirtualPianoVisible = false;

  // M4: Mixer state
  bool _isMixerVisible = true; // Always visible by default

  // M5: Project state
  String? _currentProjectPath;
  String _currentProjectName = 'Untitled Project';

  // M6: UI panel state
  bool _isLibraryPanelCollapsed = false;
  bool _isEditorPanelVisible = true; // Show editor panel by default

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
  bool _isPluginsScanned = false;
  bool _isScanningVst3Plugins = false;

  // MIDI Recording state
  List<Map<String, dynamic>> _midiDevices = [];
  int _selectedMidiDeviceIndex = -1;
  bool _isMidiRecording = false;

  // GlobalKeys for child widgets that need immediate refresh
  final GlobalKey<TimelineViewState> _timelineKey = GlobalKey<TimelineViewState>();
  final GlobalKey<TrackMixerPanelState> _mixerKey = GlobalKey<TrackMixerPanelState>();

  /// Trigger immediate refresh of track lists in both timeline and mixer panels
  void _refreshTrackWidgets() {
    _timelineKey.currentState?.refreshTracks();
    _mixerKey.currentState?.refreshTracks();
  }

  @override
  void initState() {
    super.initState();

    // Listen for undo/redo state changes to update menu
    _undoRedoManager.addListener(_onUndoRedoChanged);

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

  void _onUndoRedoChanged() {
    if (mounted) {
      setState(() {
        // Trigger rebuild to update Edit menu state
      });
    }
  }

  @override
  void dispose() {
    // Remove undo/redo listener
    _undoRedoManager.removeListener(_onUndoRedoChanged);

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
      _audioEngine!.initAudioGraph();

      // Initialize recording settings
      try {
        _audioEngine!.setCountInBars(2); // Default: 2 bars
        _audioEngine!.setTempo(120.0);   // Default: 120 BPM
        _audioEngine!.setMetronomeEnabled(true); // Default: enabled

      } catch (e) {
        debugPrint('❌ Failed to initialize recording settings: $e');
      }

      if (mounted) {
        setState(() {
          _isAudioGraphInitialized = true;
          _statusMessage = 'Ready to record or load audio files';
          _tempo = 120.0;
          _isMetronomeEnabled = true;
        });
      }

      // Initialize undo/redo manager with engine
      _undoRedoManager.initialize(_audioEngine!);

      // Scan VST3 plugins after audio graph is ready
      if (!_isPluginsScanned && mounted) {
        _scanVst3Plugins();
      }

      // Load MIDI devices
      _loadMidiDevices();
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
    if (_audioEngine == null || !_isAudioGraphInitialized) return;

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
      // Check current settings for status message
      final countInBars = _audioEngine!.getCountInBars();
      final tempo = _audioEngine!.getTempo();

      // Start audio recording
      _audioEngine!.startRecording();

      // Also start MIDI recording (for armed MIDI tracks)
      _audioEngine!.startMidiRecording();

      setState(() {
        _isCountingIn = true;
        _isMidiRecording = true;
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
      // Stop audio recording
      final audioClipId = _audioEngine!.stopRecording();

      // Stop MIDI recording
      final midiClipId = _audioEngine!.stopMidiRecording();

      setState(() {
        _isRecording = false;
        _isCountingIn = false;
        _isMidiRecording = false;
      });

      // Build status message based on what was recorded
      final List<String> recordedItems = [];

      if (audioClipId >= 0) {
        // Audio recording successful - get clip info
        final duration = _audioEngine!.getClipDuration(audioClipId);
        final peaks = _audioEngine!.getWaveformPeaks(audioClipId, 2000);

        setState(() {
          _loadedClipId = audioClipId;
          _clipDuration = duration;
          _waveformPeaks = peaks;
        });
        recordedItems.add('Audio ${duration.toStringAsFixed(2)}s');
      }

      if (midiClipId > 0) {
        // Get clip info from engine: "clip_id,track_id,start_time,duration,note_count"
        final clipInfo = _audioEngine!.getMidiClipInfo(midiClipId);

        if (!clipInfo.startsWith('Error')) {
          try {
            final parts = clipInfo.split(',');
            if (parts.length >= 5) {
              final trackId = int.parse(parts[1]);
              final startTime = double.parse(parts[2]);
              final duration = double.parse(parts[3]);
              final noteCount = int.parse(parts[4]);

              // Create MidiClipData and add to timeline
              final clipData = MidiClipData(
                clipId: midiClipId,
                trackId: trackId >= 0 ? trackId : (_selectedTrackId ?? 0),
                startTime: startTime,
                duration: duration > 0 ? duration : 4.0, // Default 4 seconds if no duration
                name: 'Recorded MIDI',
                notes: [], // Notes are managed by the engine
              );

              setState(() {
                _midiClips.add(clipData);
              });

              recordedItems.add('MIDI ($noteCount notes)');
            }
          } catch (e) {
            debugPrint('❌ Failed to parse MIDI clip info: $e');
            recordedItems.add('MIDI clip');
          }
        } else {
          recordedItems.add('MIDI clip');
        }
      }

      setState(() {
        if (recordedItems.isNotEmpty) {
          _statusMessage = 'Recorded: ${recordedItems.join(', ')}';
        } else {
          _statusMessage = 'No recording captured';
        }
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Stop recording error: $e';
        _isRecording = false;
        _isCountingIn = false;
        _isMidiRecording = false;
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
      final newState = !_isMetronomeEnabled;
      _audioEngine!.setMetronomeEnabled(newState);
      setState(() {
        _isMetronomeEnabled = newState;
        _statusMessage = newState ? 'Metronome enabled' : 'Metronome disabled';
      });
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
    } catch (e) {
      debugPrint('❌ Tempo change error: $e');
      setState(() {
        _statusMessage = 'Tempo change error: $e';
      });
    }
  }

  // M3: Virtual piano methods
  void _toggleVirtualPiano() {
    if (_audioEngine == null) return;

    setState(() {
      _isVirtualPianoEnabled = !_isVirtualPianoEnabled;

      if (_isVirtualPianoEnabled) {
        // Enable: Initialize MIDI, start audio stream, and show panel
        try {
          _audioEngine!.startMidiInput();

          // CRITICAL: Start audio output stream so synthesizer can be heard
          // The synthesizer generates audio but needs the stream running to output it
          _audioEngine!.transportPlay();

          _isVirtualPianoVisible = true;
          _statusMessage = 'Virtual piano enabled - Press keys to play!';
        } catch (e) {
          debugPrint('❌ Virtual piano enable error: $e');
          _statusMessage = 'Virtual piano error: $e';
          _isVirtualPianoEnabled = false;
          _isVirtualPianoVisible = false;
        }
      } else {
        // Disable: Hide panel
        _isVirtualPianoVisible = false;
        _isEditorPanelVisible = false; // Hide editor panel when piano disabled
        _statusMessage = 'Virtual piano disabled';
      }
    });
  }

  // MIDI Device methods
  void _loadMidiDevices() {
    if (_audioEngine == null) return;

    try {
      final devices = _audioEngine!.getMidiInputDevices();

      setState(() {
        _midiDevices = devices;

        // Auto-select default device if available
        if (_selectedMidiDeviceIndex < 0 && devices.isNotEmpty) {
          final defaultIndex = devices.indexWhere((d) => d['isDefault'] == true);
          if (defaultIndex >= 0) {
            _selectedMidiDeviceIndex = defaultIndex;
            _onMidiDeviceSelected(defaultIndex);
          }
        }
      });
    } catch (e) {
      debugPrint('❌ Failed to load MIDI devices: $e');
    }
  }

  void _onMidiDeviceSelected(int deviceIndex) {
    if (_audioEngine == null) return;

    try {
      _audioEngine!.selectMidiInputDevice(deviceIndex);

      setState(() {
        _selectedMidiDeviceIndex = deviceIndex;
      });

      // Show feedback
      if (_midiDevices.isNotEmpty && deviceIndex >= 0 && deviceIndex < _midiDevices.length) {
        final deviceName = _midiDevices[deviceIndex]['name'] as String? ?? 'Unknown';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎹 Selected: $deviceName'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Failed to select MIDI device: $e');
    }
  }

  void _refreshMidiDevices() {
    if (_audioEngine == null) return;

    try {
      _audioEngine!.refreshMidiDevices();
      _loadMidiDevices();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎹 MIDI devices refreshed'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('❌ Failed to refresh MIDI devices: $e');
    }
  }

  // M4: Mixer methods
  void _toggleMixer() {
    setState(() {
      _isMixerVisible = !_isMixerVisible;
    });
  }

  // Unified track selection method - handles both timeline and mixer clicks
  void _onTrackSelected(int? trackId) {
    if (trackId == null) {
      setState(() {
        _selectedTrackId = null;
        _isEditorPanelVisible = false;
      });
      return;
    }

    setState(() {
      _selectedTrackId = trackId;
      _isEditorPanelVisible = true;

      // Clear clip selection when selecting just a track
      _selectedMidiClipId = null;
      _currentEditingClip = null;
    });
  }

  // M9: Instrument methods
  void _onInstrumentSelected(int trackId, String instrumentId) {
    setState(() {
      // Create default instrument data for the track
      final instrumentData = InstrumentData.defaultSynthesizer(trackId);
      _trackInstruments[trackId] = instrumentData;
      _selectedTrackId = trackId; // Select the track when instrument is assigned
      _isEditorPanelVisible = true; // Show editor panel when instrument selected

      // Call audio engine to set instrument
      if (_audioEngine != null) {
        _audioEngine!.setTrackInstrument(trackId, instrumentId);
      }
    });
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
      }
    });
  }

  void _onInstrumentDropped(int trackId, Instrument instrument) {
    // Reuse the same logic as _onInstrumentSelected
    _onInstrumentSelected(trackId, instrument.id);
  }

  void _onInstrumentDroppedOnEmpty(Instrument instrument) async {
    if (_audioEngine == null) return;

    // Create a new MIDI track using UndoRedoManager
    final command = CreateTrackCommand(
      trackType: 'midi',
      trackName: 'MIDI',
    );

    await _undoRedoManager.execute(command);

    final trackId = command.createdTrackId;
    if (trackId == null || trackId < 0) {
      debugPrint('❌ Failed to create new MIDI track');
      return;
    }

    // Assign the instrument to the new track
    _onInstrumentSelected(trackId, instrument.id);

    // Immediately refresh track widgets so the new track appears instantly
    _refreshTrackWidgets();
  }

  // VST3 Instrument drop handlers
  void _onVst3InstrumentDropped(int trackId, Vst3Plugin plugin) async {
    if (_audioEngine == null) return;

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
    } catch (e) {
      debugPrint('❌ Error loading VST3 instrument: $e');
    }
  }

  void _onVst3InstrumentDroppedOnEmpty(Vst3Plugin plugin) async {
    if (_audioEngine == null) return;

    try {
      // Create a new MIDI track using UndoRedoManager
      final command = CreateTrackCommand(
        trackType: 'midi',
        trackName: 'MIDI',
      );

      await _undoRedoManager.execute(command);

      final trackId = command.createdTrackId;
      if (trackId == null || trackId < 0) {
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

      // Immediately refresh track widgets so the new track appears instantly
      _refreshTrackWidgets();
    } catch (e) {
      debugPrint('❌ Error creating MIDI track with VST3 instrument: $e');
    }
  }

  void _onInstrumentParameterChanged(InstrumentData instrumentData) {
    setState(() {
      _trackInstruments[instrumentData.trackId] = instrumentData;
    });
  }

  // M10: VST3 Plugin methods
  Future<void> _loadCachedVst3Plugins() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedVersion = prefs.getInt('vst3_cache_version') ?? 0;
      const currentVersion = 8; // Incremented - default to INSTRUMENT instead of EFFECT

      // Invalidate cache if version doesn't match
      if (cachedVersion != currentVersion) {
        await prefs.remove('vst3_plugins_cache');
        await prefs.remove('vst3_plugins_cache');
        await prefs.remove('vst3_scan_timestamp');
        await prefs.setInt('vst3_cache_version', currentVersion);
        return;
      }

      final cachedJson = prefs.getString('vst3_plugins_cache');

      if (cachedJson != null) {
        final List<dynamic> decoded = jsonDecode(cachedJson);
        final plugins = decoded.map((item) => Map<String, String>.from(item as Map)).toList();

        // Verify that plugins have type information
        bool hasTypeInfo = plugins.every((plugin) =>
          plugin.containsKey('is_instrument') && plugin.containsKey('is_effect')
        );

        if (!hasTypeInfo) {
          await prefs.remove('vst3_plugins_cache');
          return;
        }

        setState(() {
          _availableVst3Plugins = plugins;
          _isPluginsScanned = true;
        });
      }
    } catch (e) {
      debugPrint('❌ Failed to load VST3 cache: $e');
    }
  }

  Future<void> _saveVst3PluginsCache(List<Map<String, String>> plugins) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(plugins);
      await prefs.setString('vst3_plugins_cache', json);
      await prefs.setInt('vst3_scan_timestamp', DateTime.now().millisecondsSinceEpoch);
      await prefs.setInt('vst3_cache_version', 8); // Save cache version
    } catch (e) {
      debugPrint('❌ Failed to save VST3 cache: $e');
    }
  }

  void _scanVst3Plugins({bool forceRescan = false}) async {
    if (_audioEngine == null || _isScanningVst3Plugins) return;

    // Load from cache if not forcing rescan
    if (!forceRescan && !_isPluginsScanned) {
      await _loadCachedVst3Plugins();

      // If cache loaded successfully, we're done
      if (_availableVst3Plugins.isNotEmpty) {
        return;
      }
    }

    setState(() {
      _isScanningVst3Plugins = true;
      _statusMessage = forceRescan ? 'Rescanning VST3 plugins...' : 'Scanning VST3 plugins...';
    });

    try {
      final plugins = _audioEngine!.scanVst3PluginsStandard();

      // Save to cache
      await _saveVst3PluginsCache(plugins);

      setState(() {
        _availableVst3Plugins = plugins;
        _isPluginsScanned = true;
        _isScanningVst3Plugins = false;
        _statusMessage = 'Found ${plugins.length} VST3 plugin${plugins.length == 1 ? '' : 's'}';
      });
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
    } catch (e) {
      setState(() {
        _statusMessage = 'Error removing plugin: $e';
      });
      debugPrint('❌ Error removing VST3 plugin: $e');
    }
  }

  void _showVst3PluginBrowser(int trackId) async {
    if (_audioEngine == null) return;

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
      _isLibraryPanelCollapsed = !_isLibraryPanelCollapsed;
    });
  }

  void _toggleEditor() {
    setState(() {
      _isEditorPanelVisible = !_isEditorPanelVisible;
    });
  }

  void _resetPanelLayout() {
    setState(() {
      // Reset to default panel sizes
      _libraryPanelWidth = 200.0;
      _mixerPanelWidth = 380.0;
      _editorPanelHeight = 250.0;

      // Reset visibility states
      _isLibraryPanelCollapsed = false;
      _isMixerVisible = true;
      _isEditorPanelVisible = true;

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
        _isEditorPanelVisible = true;
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

    // Check if this Dart clip already has a Rust clip
    int rustClipId;
    bool isNewClip = false;

    if (_dartToRustClipIds.containsKey(clip.clipId)) {
      // Existing clip - reuse the Rust clip ID
      rustClipId = _dartToRustClipIds[clip.clipId]!;

      // Clear existing notes (we'll re-add all of them)
      _audioEngine!.clearMidiClip(rustClipId);
    } else {
      // New clip - create in Rust
      rustClipId = _audioEngine!.createMidiClip();
      if (rustClipId < 0) {
        debugPrint('❌ Failed to create Rust MIDI clip');
        return;
      }
      _dartToRustClipIds[clip.clipId] = rustClipId;
      isNewClip = true;
    }

    // Add all notes to the Rust clip
    for (final note in clip.notes) {
      // Convert beats to seconds using current tempo
      final startTimeSeconds = note.startTimeInSeconds(_tempo);
      final durationSeconds = note.durationInSeconds(_tempo);

      _audioEngine!.addMidiNoteToClip(
        rustClipId,
        note.note,
        note.velocity,
        startTimeSeconds,
        durationSeconds,
      );
    }

    // Only add to timeline if this is a new clip
    if (isNewClip) {
      final result = _audioEngine!.addMidiClipToTrack(
        clip.trackId,
        rustClipId,
        clip.startTime,
      );

      if (result != 0) {
        debugPrint('❌ Failed to add MIDI clip to track timeline (result: $result)');
      }
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

  // ========================================================================
  // Undo/Redo methods
  // ========================================================================

  void _performUndo() async {
    final success = await _undoRedoManager.undo();
    if (success && mounted) {
      setState(() {
        _statusMessage = 'Undone: ${_undoRedoManager.redoDescription ?? "action"}';
      });
      _refreshTrackWidgets();
    }
  }

  void _performRedo() async {
    final success = await _undoRedoManager.redo();
    if (success && mounted) {
      setState(() {
        _statusMessage = 'Redone: ${_undoRedoManager.undoDescription ?? "action"}';
      });
      _refreshTrackWidgets();
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
        'POSIX path of (choose folder with prompt "Select Boojy Audio Project (.audio folder)")'
      ]);

      if (result.exitCode == 0) {
        var path = result.stdout.toString().trim();
        // Remove trailing slash if present
        if (path.endsWith('/')) {
          path = path.substring(0, path.length - 1);
        }

        if (path.isEmpty) {
          return;
        }

        if (!path.endsWith('.audio')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Please select a .audio folder')),
          );
          return;
        }

        setState(() => _isLoading = true);

        try {
          final loadResult = _audioEngine!.loadProject(path);

          // Clear MIDI clip ID mappings since Rust side has reset
          _dartToRustClipIds.clear();

          // Load UI layout data
          _loadUILayout(path);

          setState(() {
            _currentProjectPath = path;
            _currentProjectName = path.split('/').last.replaceAll('.audio', '');
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
          final projectPath = '$parentPath/$projectName.audio';
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
          'library': _isLibraryPanelCollapsed,
          'mixer': !_isMixerVisible,
          'bottom': !(_isEditorPanelVisible || _isVirtualPianoVisible),
        },
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(uiLayoutData);
      final uiLayoutFile = File('$projectPath/ui_layout.json');
      uiLayoutFile.writeAsStringSync(jsonString);
    } catch (e) {
      debugPrint('❌ Failed to save UI layout: $e');
    }
  }

  /// Load UI layout state from JSON file
  void _loadUILayout(String projectPath) {
    try {
      final uiLayoutFile = File('$projectPath/ui_layout.json');
      if (!uiLayoutFile.existsSync()) {
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
          _isLibraryPanelCollapsed = panelCollapsed['library'] as bool? ?? false;
          _isMixerVisible = !(panelCollapsed['mixer'] as bool? ?? false);
          final bottomCollapsed = panelCollapsed['bottom'] as bool? ?? false;
          if (!bottomCollapsed) {
            // Only restore if it was expanded before
            // Don't auto-open bottom panel on load
          }
        }
      });
    } catch (e) {
      debugPrint('❌ Failed to load UI layout: $e');
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
          final copyPath = '$parentPath/$copyName.audio';

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
    // Get current audio devices
    final inputDevices = _audioEngine?.getAudioInputDevices() ?? [];
    final outputDevices = _audioEngine?.getAudioOutputDevices() ?? [];
    final sampleRate = _audioEngine?.getSampleRate() ?? 48000;

    // Find default devices
    String? selectedInputDevice;
    String? selectedOutputDevice;
    for (final device in inputDevices) {
      if (device['isDefault'] == true) {
        selectedInputDevice = device['name'] as String?;
        break;
      }
    }
    for (final device in outputDevices) {
      if (device['isDefault'] == true) {
        selectedOutputDevice = device['name'] as String?;
        break;
      }
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Audio Settings'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Audio Output Device
                const Text(
                  'Audio Output Device',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: DropdownButton<String>(
                    value: selectedOutputDevice,
                    isExpanded: true,
                    underline: const SizedBox(),
                    hint: const Text('Select output device'),
                    items: outputDevices.map((device) {
                      final name = device['name'] as String;
                      final isDefault = device['isDefault'] as bool;
                      return DropdownMenuItem<String>(
                        value: name,
                        child: Text(isDefault ? '$name (Default)' : name),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedOutputDevice = value;
                      });
                      // Note: Output device switching requires stream recreation
                      // which is not yet implemented
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // Audio Input Device
                const Text(
                  'Audio Input Device',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: DropdownButton<String>(
                    value: selectedInputDevice,
                    isExpanded: true,
                    underline: const SizedBox(),
                    hint: const Text('Select input device'),
                    items: inputDevices.map((device) {
                      final name = device['name'] as String;
                      final isDefault = device['isDefault'] as bool;
                      return DropdownMenuItem<String>(
                        value: name,
                        child: Text(isDefault ? '$name (Default)' : name),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedInputDevice = value;
                      });
                      // Find index and set device
                      final index = inputDevices.indexWhere((d) => d['name'] == value);
                      if (index >= 0) {
                        _audioEngine?.setAudioInputDevice(index);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // Sample Rate (read-only)
                const Text(
                  'Sample Rate',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Text('$sampleRate Hz'),
                      const Spacer(),
                      Icon(Icons.lock_outline, size: 16, color: Colors.grey.shade500),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sample rate is fixed at 48kHz for optimal compatibility.',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
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
        // Standard macOS app menu (Audio)
        PlatformMenu(
          label: 'Audio',
          menus: [
            PlatformMenuItem(
              label: 'About Audio',
              onSelected: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('About Audio'),
                    content: const Text('Audio\nVersion M6.2\n\nA modern, cross-platform DAW'),
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
              label: 'Quit Audio',
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
              label: _undoRedoManager.canUndo
                  ? 'Undo ${_undoRedoManager.undoDescription ?? ""}'
                  : 'Undo',
              shortcut: const SingleActivator(LogicalKeyboardKey.keyZ, meta: true),
              onSelected: _undoRedoManager.canUndo ? _performUndo : null,
            ),
            PlatformMenuItem(
              label: _undoRedoManager.canRedo
                  ? 'Redo ${_undoRedoManager.redoDescription ?? ""}'
                  : 'Redo',
              shortcut: const SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true),
              onSelected: _undoRedoManager.canRedo ? _performRedo : null,
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
              label: !_isLibraryPanelCollapsed ? '✓ Show Library Panel' : 'Show Library Panel',
              shortcut: const SingleActivator(LogicalKeyboardKey.keyL, meta: true),
              onSelected: _toggleLibraryPanel,
            ),
            PlatformMenuItem(
              label: _isMixerVisible ? '✓ Show Mixer Panel' : 'Show Mixer Panel',
              shortcut: const SingleActivator(LogicalKeyboardKey.keyM, meta: true),
              onSelected: _toggleMixer,
            ),
            PlatformMenuItem(
              label: _isEditorPanelVisible ? '✓ Show Editor Panel' : 'Show Editor Panel',
              shortcut: const SingleActivator(LogicalKeyboardKey.keyE, meta: true),
              onSelected: _toggleEditor,
            ),
            PlatformMenuItem(
              label: _isVirtualPianoEnabled ? '✓ Show Virtual Piano' : 'Show Virtual Piano',
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
        backgroundColor: const Color(0xFF242424), // Dark grey background
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
            metronomeEnabled: _isMetronomeEnabled,
            virtualPianoEnabled: _isVirtualPianoEnabled,
            tempo: _tempo,
            onTempoChanged: _onTempoChanged,
            // MIDI device selection
            midiDevices: _midiDevices,
            selectedMidiDeviceIndex: _selectedMidiDeviceIndex,
            onMidiDeviceSelected: _onMidiDeviceSelected,
            onRefreshMidiDevices: _refreshMidiDevices,
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
            libraryVisible: !_isLibraryPanelCollapsed,
            mixerVisible: _isMixerVisible,
            editorVisible: _isEditorPanelVisible,
            pianoVisible: _isVirtualPianoEnabled,
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
                        width: _isLibraryPanelCollapsed ? 40 : _libraryPanelWidth,
                        child: LibraryPanel(
                          isCollapsed: _isLibraryPanelCollapsed,
                          onToggle: _toggleLibraryPanel,
                          availableVst3Plugins: _availableVst3Plugins,
                        ),
                      ),

                      // Divider: Library/Timeline
                      ResizableDivider(
                        orientation: DividerOrientation.vertical,
                        isCollapsed: _isLibraryPanelCollapsed,
                        onDrag: (delta) {
                          setState(() {
                            _libraryPanelWidth = (_libraryPanelWidth + delta)
                                .clamp(_libraryMinWidth, _libraryMaxWidth);
                          });
                        },
                        onDoubleClick: () {
                          setState(() {
                            _isLibraryPanelCollapsed = !_isLibraryPanelCollapsed;
                          });
                        },
                      ),

                      // Center: Timeline area
                      Expanded(
                        child: TimelineView(
                          key: _timelineKey,
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
                      if (_isMixerVisible) ...[
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
                              _isMixerVisible = false;
                            });
                          },
                        ),

                        SizedBox(
                          width: _mixerPanelWidth,
                          child: TrackMixerPanel(
                            key: _mixerKey,
                            audioEngine: _audioEngine,
                            isEngineReady: _isAudioGraphInitialized,
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
                if (_isEditorPanelVisible || _isVirtualPianoVisible) ...[
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
                        _isEditorPanelVisible = false;
                        _isVirtualPianoVisible = false;
                        _isVirtualPianoEnabled = false;
                      });
                    },
                  ),

                  SizedBox(
                    height: _editorPanelHeight,
                    child: EditorPanel(
                      audioEngine: _audioEngine,
                      virtualPianoEnabled: _isVirtualPianoEnabled,
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
        color: Color(0xFF181818),
        border: Border(
          top: BorderSide(color: Color(0xFF363636)),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isAudioGraphInitialized ? Icons.check_circle : Icons.error,
            size: 12,
            color: _isAudioGraphInitialized
                ? const Color(0xFF00BCD4)
                : const Color(0xFF616161),
          ),
          const SizedBox(width: 6),
          Text(
            _isAudioGraphInitialized ? 'Audio Engine Ready' : 'Initializing...',
            style: TextStyle(
              color: _isAudioGraphInitialized
                  ? const Color(0xFF9E9E9E)
                  : const Color(0xFF616161),
              fontSize: 11,
            ),
          ),
          const Spacer(),
          if (_clipDuration != null)
            Text(
              'Duration: ${_clipDuration!.toStringAsFixed(3)}s',
              style: const TextStyle(
                color: Color(0xFF9E9E9E),
                fontSize: 11,
              ),
            ),
          if (_clipDuration != null) const SizedBox(width: 16),
          Text(
            'Sample Rate: 48kHz',
            style: const TextStyle(
              color: Color(0xFF9E9E9E),
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'CPU: 0%', // TODO: Get real CPU usage from audio engine
            style: const TextStyle(
              color: Color(0xFF9E9E9E),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

