import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import '../audio_engine.dart';
import '../widgets/transport_bar.dart';
import '../widgets/timeline_view.dart';
import '../widgets/track_mixer_panel.dart';
import '../widgets/library_panel.dart';
import '../widgets/bottom_panel.dart';
import '../widgets/resizable_divider.dart';
import '../widgets/instrument_browser.dart';
import '../models/midi_note_data.dart';
import '../models/instrument_data.dart';

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
  int? _selectedTrackForFX;

  // M5: Project state
  String? _currentProjectPath;
  String _currentProjectName = 'Untitled Project';

  // M6: UI panel state
  bool _libraryPanelCollapsed = false;
  bool _bottomPanelVisible = true; // Show piano roll by default for M6 testing

  // M7: Resizable panels state
  double _libraryPanelWidth = 200.0;
  double _mixerPanelWidth = 380.0;
  double _bottomPanelHeight = 250.0;
  static const double _libraryMinWidth = 40.0;
  static const double _libraryMaxWidth = 400.0;
  static const double _mixerMinWidth = 200.0;
  static const double _mixerMaxWidth = 600.0;
  static const double _bottomMinHeight = 100.0;
  static const double _bottomMaxHeight = 500.0;

  // M8: MIDI editing state
  int? _selectedMidiTrackId;
  int? _selectedMidiClipId;
  MidiClipData? _currentEditingClip;

  // M9: Instrument state
  Map<int, InstrumentData> _trackInstruments = {}; // trackId -> InstrumentData
  int? _selectedTrackForInstrument;

  @override
  void initState() {
    super.initState();
    _initAudioEngine();
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
      _audioEngine = AudioEngine();
      _audioEngine!.initAudioEngine();
      
      // Initialize audio graph immediately
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
      
      setState(() {
        _audioGraphInitialized = true;
        _statusMessage = 'Ready to record or load audio files';
        _tempo = 120.0;
        _metronomeEnabled = true;
      });
      
      debugPrint('✅ Audio graph initialized: $result');
    } catch (e) {
      setState(() {
        _statusMessage = 'Failed to initialize: $e';
      });
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
    _playheadTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (_audioEngine != null && mounted) {
        final pos = _audioEngine!.getPlayheadPosition();
        setState(() {
          _playheadPosition = pos;
        });
        
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
    if (_audioEngine == null) return;

    try {
      _audioEngine!.transportStop();
      setState(() {
        _isPlaying = false;
        _playheadPosition = 0.0;
        _statusMessage = 'Stopped';
      });
      _stopPlayheadTimer();
    } catch (e) {
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
        _bottomPanelVisible = false; // Hide bottom panel when piano disabled
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

  void _onFXButtonClicked(int? trackId) {
    setState(() {
      _selectedTrackForFX = trackId;
      _bottomPanelVisible = trackId != null; // Show bottom panel when FX selected
    });
  }

  // M9: Instrument methods
  void _onInstrumentSelected(int trackId, String instrumentId) {
    setState(() {
      // Create default instrument data for the track
      final instrumentData = InstrumentData.defaultSynthesizer(trackId);
      _trackInstruments[trackId] = instrumentData;
      _selectedTrackForInstrument = trackId;
      _bottomPanelVisible = true; // Show bottom panel when instrument selected

      // Call audio engine to set instrument
      if (_audioEngine != null) {
        _audioEngine!.setTrackInstrument(trackId, instrumentId);
      }
    });
    debugPrint('🎹 Track $trackId instrument set to: $instrumentId');
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

  void _onInstrumentParameterChanged(InstrumentData instrumentData) {
    setState(() {
      _trackInstruments[instrumentData.trackId] = instrumentData;
    });
    debugPrint('🎹 Updated instrument parameters for track ${instrumentData.trackId}');
  }

  // M6: Panel toggle methods
  void _toggleLibraryPanel() {
    setState(() {
      _libraryPanelCollapsed = !_libraryPanelCollapsed;
    });
  }

  // M8: MIDI track/clip selection methods
  void _onMidiTrackSelected(int? trackId) {
    setState(() {
      _selectedMidiTrackId = trackId;
      if (trackId != null) {
        // Open piano roll when MIDI track selected
        _bottomPanelVisible = true;
        // Clear clip selection when selecting just a track
        _selectedMidiClipId = null;
        _currentEditingClip = null;
      }
    });
  }

  void _onMidiClipSelected(int? clipId, MidiClipData? clipData) {
    setState(() {
      _selectedMidiClipId = clipId;
      _currentEditingClip = clipData;
      if (clipId != null && clipData != null) {
        // Open piano roll and set the selected track
        _bottomPanelVisible = true;
        _selectedMidiTrackId = clipData.trackId;
      }
    });
  }

  void _onMidiClipUpdated(MidiClipData updatedClip) {
    setState(() {
      // Check if this is a new clip (clipId == -1) with notes - auto-create it
      if (updatedClip.clipId == -1 && updatedClip.notes.isNotEmpty) {
        // Generate a unique clip ID (use timestamp for now)
        final newClipId = DateTime.now().millisecondsSinceEpoch;

        // Create clip at playhead position
        _currentEditingClip = updatedClip.copyWith(
          clipId: newClipId,
          startTime: _playheadPosition, // Use current playhead position
        );
        _selectedMidiClipId = newClipId;

        debugPrint('✅ Auto-created MIDI clip $newClipId at ${_playheadPosition.toStringAsFixed(2)}s');
      } else {
        // Just update existing clip
        _currentEditingClip = updatedClip;
      }
    });

    // Schedule MIDI clip for playback
    if (_audioEngine != null && _currentEditingClip != null) {
      _scheduleMidiClipPlayback(_currentEditingClip!);
    }
  }

  /// Schedule MIDI clip notes for playback during transport
  void _scheduleMidiClipPlayback(MidiClipData clip) {
    debugPrint('🎵 Scheduling ${clip.notes.length} MIDI notes for playback');
    debugPrint('   Clip: ${clip.name} (ID: ${clip.clipId})');
    debugPrint('   Track: ${clip.trackId}');
    debugPrint('   Start time: ${clip.startTime}s');

    // TODO: Implement MIDI clip scheduling in Rust audio engine
    // For now, this logs what would be scheduled
    // The Rust side needs to:
    // 1. Store MIDI clip data with timing information
    // 2. During transport play, trigger notes at correct timestamps
    // 3. Handle tempo/BPM conversion from beats to seconds

    for (final note in clip.notes) {
      final tempo = _tempo; // Current tempo
      final startTimeInSeconds = note.startTimeInSeconds(tempo) + clip.startTime;
      final durationInSeconds = note.durationInSeconds(tempo);

      debugPrint('   Note: ${note.noteName} at ${startTimeInSeconds.toStringAsFixed(3)}s for ${durationInSeconds.toStringAsFixed(3)}s');
    }

    // Example immediate playback (for testing - remove once scheduling is implemented):
    // Uncomment to hear notes immediately when drawn
    // _playMidiClipImmediately(clip);
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
          'bottom_height': _bottomPanelHeight,
        },
        'panel_collapsed': {
          'library': _libraryPanelCollapsed,
          'mixer': !_mixerVisible,
          'bottom': !(_bottomPanelVisible || _virtualPianoVisible),
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
          _bottomPanelHeight = (panelSizes['bottom_height'] as num?)?.toDouble() ?? 250.0;

          // Clamp to min/max values
          _libraryPanelWidth = _libraryPanelWidth.clamp(_libraryMinWidth, _libraryMaxWidth);
          _mixerPanelWidth = _mixerPanelWidth.clamp(_mixerMinWidth, _mixerMaxWidth);
          _bottomPanelHeight = _bottomPanelHeight.clamp(_bottomMinHeight, _bottomMaxHeight);
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

  void _exportProject() {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            // New parameters for file menu and mixer toggle
            onNewProject: _newProject,
            onOpenProject: _openProject,
            onSaveProject: _saveProject,
            onSaveProjectAs: _saveProjectAs,
            onExportProject: _exportProject,
            onToggleMixer: _toggleMixer,
            mixerVisible: _mixerVisible,
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
                          selectedMidiTrackId: _selectedMidiTrackId,
                          selectedMidiClipId: _selectedMidiClipId,
                          currentEditingClip: _currentEditingClip,
                          onMidiTrackSelected: _onMidiTrackSelected,
                          onMidiClipSelected: _onMidiClipSelected,
                          onMidiClipUpdated: _onMidiClipUpdated,
                          onInstrumentDropped: _onInstrumentDropped,
                          onInstrumentDroppedOnEmpty: _onInstrumentDroppedOnEmpty,
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
                            onFXButtonClicked: _onFXButtonClicked,
                            selectedMidiTrackId: _selectedMidiTrackId,
                            onMidiTrackSelected: _onMidiTrackSelected,
                            onInstrumentSelected: _onInstrumentSelected,
                            onTrackDuplicated: _onTrackDuplicated,
                            trackInstruments: _trackInstruments,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Bottom panel: Piano Roll / FX Chain / Virtual Piano
                if (_bottomPanelVisible || _virtualPianoVisible) ...[
                  // Divider: Timeline/Bottom Panel
                  ResizableDivider(
                    orientation: DividerOrientation.horizontal,
                    isCollapsed: false,
                    onDrag: (delta) {
                      setState(() {
                        _bottomPanelHeight = (_bottomPanelHeight - delta)
                            .clamp(_bottomMinHeight, _bottomMaxHeight);
                      });
                    },
                    onDoubleClick: () {
                      setState(() {
                        _bottomPanelVisible = false;
                        _virtualPianoVisible = false;
                        _virtualPianoEnabled = false;
                      });
                    },
                  ),

                  SizedBox(
                    height: _bottomPanelHeight,
                    child: BottomPanel(
                      audioEngine: _audioEngine,
                      virtualPianoEnabled: _virtualPianoEnabled,
                      selectedTrackForFX: _selectedTrackForFX,
                      selectedTrackForInstrument: _selectedTrackForInstrument,
                      currentInstrumentData: _selectedTrackForInstrument != null
                          ? _trackInstruments[_selectedTrackForInstrument]
                          : null,
                      onVirtualPianoClose: _toggleVirtualPiano,
                      currentEditingClip: _currentEditingClip,
                      selectedMidiTrackId: _selectedMidiTrackId,
                      onMidiClipUpdated: _onMidiClipUpdated,
                      onInstrumentParameterChanged: _onInstrumentParameterChanged,
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

