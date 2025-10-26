import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../audio_engine.dart';
import '../widgets/transport_bar.dart';
import '../widgets/timeline_view.dart';
import '../widgets/file_drop_zone.dart';
import '../widgets/virtual_piano.dart';
import '../widgets/mixer_panel.dart';

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
  bool _mixerVisible = false;

  // M5: Project state
  String? _currentProjectPath;
  String _currentProjectName = 'Untitled Project';

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
    if (_audioEngine == null || _loadedClipId == null) return;

    try {
      _audioEngine!.transportPlay();
      setState(() {
        _isPlaying = true;
        _statusMessage = 'Playing...';
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
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        title: Image.asset(
          'assets/images/solar_logo.png',
          height: 32,
          fit: BoxFit.contain,
        ),
        backgroundColor: const Color(0xFFF5F5F5),
        actions: [
          // File menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.folder_open, color: Color(0xFF808080)),
            tooltip: 'File',
            onSelected: (String value) {
              switch (value) {
                case 'new':
                  _newProject();
                  break;
                case 'open':
                  _openProject();
                  break;
                case 'save':
                  _saveProject();
                  break;
                case 'save_as':
                  _saveProjectAs();
                  break;
                case 'export':
                  _exportProject();
                  break;
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'new',
                child: Row(
                  children: [
                    Icon(Icons.description, size: 18),
                    SizedBox(width: 8),
                    Text('New Project'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'open',
                child: Row(
                  children: [
                    Icon(Icons.folder_open, size: 18),
                    SizedBox(width: 8),
                    Text('Open...'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'save',
                child: Row(
                  children: [
                    Icon(Icons.save, size: 18),
                    SizedBox(width: 8),
                    Text('Save'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'save_as',
                child: Row(
                  children: [
                    Icon(Icons.save_as, size: 18),
                    SizedBox(width: 8),
                    Text('Save As...'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.upload, size: 18),
                    SizedBox(width: 8),
                    Text('Export...'),
                  ],
                ),
              ),
            ],
          ),
          // Mixer toggle button
          IconButton(
            icon: Icon(
              Icons.tune,
              color: _mixerVisible ? const Color(0xFF4CAF50) : const Color(0xFF808080),
            ),
            onPressed: _toggleMixer,
            tooltip: 'Toggle Mixer',
          ),
          // Status indicator
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF4CAF50),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Transport bar
          TransportBar(
            onPlay: _loadedClipId != null ? _play : null,
            onPause: _loadedClipId != null ? _pause : null,
            onStop: _loadedClipId != null ? _stopPlayback : null,
            onRecord: _toggleRecording,
            onMetronomeToggle: _toggleMetronome,
            onPianoToggle: _toggleVirtualPiano,
            playheadPosition: _playheadPosition,
            isPlaying: _isPlaying,
            canPlay: _loadedClipId != null,
            isRecording: _isRecording,
            isCountingIn: _isCountingIn,
            metronomeEnabled: _metronomeEnabled,
            virtualPianoEnabled: _virtualPianoEnabled,
            tempo: _tempo,
          ),

          // Main content area with mixer panel
          Expanded(
            child: Row(
              children: [
                // Timeline area
                Expanded(
                  child: _loadedClipId == null
                      ? _buildEmptyState()
                      : _buildTimelineView(),
                ),

                // Mixer panel (slide-in from right)
                if (_mixerVisible)
                  MixerPanel(
                    audioEngine: _audioEngine,
                    onClose: _toggleMixer,
                  ),
              ],
            ),
          ),

          // Status bar
          _buildStatusBar(),

          // Virtual piano keyboard (M3)
          if (_virtualPianoVisible)
            VirtualPiano(
              audioEngine: _audioEngine,
              isEnabled: _virtualPianoEnabled,
              onClose: _toggleVirtualPiano,
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        padding: const EdgeInsets.all(32),
        child: FileDropZone(
          onFileLoaded: _loadAudioFile,
          hasFile: _loadedClipId != null,
        ),
      ),
    );
  }

  Widget _buildTimelineView() {
    return Column(
      children: [
        // File info bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: const BoxDecoration(
            color: Color(0xFF2B2B2B),
            border: Border(
              bottom: BorderSide(color: Color(0xFF404040)),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.audio_file,
                size: 16,
                color: Color(0xFF808080),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _statusMessage,
                  style: const TextStyle(
                    color: Color(0xFF808080),
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton.icon(
                onPressed: _pickFile,
                icon: const Icon(Icons.folder_open, size: 16),
                label: const Text('Load Different File'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFA0A0A0),
                ),
              ),
            ],
          ),
        ),

        // Timeline
        Expanded(
          child: TimelineView(
            playheadPosition: _playheadPosition,
            clipDuration: _clipDuration,
            waveformPeaks: _waveformPeaks,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBar() {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF2B2B2B),
        border: Border(
          top: BorderSide(color: Color(0xFF404040)),
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
        ],
      ),
    );
  }
}

