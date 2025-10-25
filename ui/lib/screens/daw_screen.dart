import 'package:flutter/material.dart';
import 'dart:async';
import 'package:file_picker/file_picker.dart';
import '../audio_engine.dart';
import '../widgets/transport_bar.dart';
import '../widgets/timeline_view.dart';
import '../widgets/file_drop_zone.dart';
import '../widgets/virtual_piano.dart';

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
    if (_audioEngine == null) return;

    setState(() {
      _virtualPianoEnabled = !_virtualPianoEnabled;

      if (_virtualPianoEnabled) {
        // Enable: Initialize MIDI, start audio stream, and show panel
        try {
          _audioEngine!.startMidiInput();

          // CRITICAL: Start audio output stream so synthesizer can be heard
          // The synthesizer generates audio but needs the stream running to output it
          _audioEngine!.transportPlay();

          _virtualPianoVisible = true;
          _statusMessage = 'Virtual piano enabled - Press keys to play!';
          debugPrint('✅ Virtual piano enabled');
        } catch (e) {
          debugPrint('❌ Virtual piano enable error: $e');
          _statusMessage = 'Virtual piano error: $e';
          _virtualPianoEnabled = false;
          _virtualPianoVisible = false;
        }
      } else {
        // Disable: Hide panel
        _virtualPianoVisible = false;
        _statusMessage = 'Virtual piano disabled';
        debugPrint('🎹 Virtual piano disabled');
      }
    });
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

          // Main content area
          Expanded(
            child: _loadedClipId == null
                ? _buildEmptyState()
                : _buildTimelineView(),
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

