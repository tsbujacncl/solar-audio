import 'package:flutter/material.dart';
import 'dart:async';
import '../audio_engine.dart';
import '../widgets/transport_bar.dart';
import '../widgets/timeline_view.dart';
import '../widgets/file_drop_zone.dart';

/// Main DAW screen with timeline, transport controls, and file import
class DAWScreen extends StatefulWidget {
  const DAWScreen({super.key});

  @override
  State<DAWScreen> createState() => _DAWScreenState();
}

class _DAWScreenState extends State<DAWScreen> {
  AudioEngine? _audioEngine;
  Timer? _playheadTimer;
  
  // State
  double _playheadPosition = 0.0;
  int? _loadedClipId;
  double? _clipDuration;
  List<double> _waveformPeaks = [];
  bool _isPlaying = false;
  bool _audioGraphInitialized = false;
  String _statusMessage = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initAudioEngine();
  }

  @override
  void dispose() {
    _playheadTimer?.cancel();
    _stopPlayback();
    super.dispose();
  }

  void _initAudioEngine() async {
    try {
      _audioEngine = AudioEngine();
      _audioEngine!.initAudioEngine();
      
      // Initialize audio graph immediately
      final result = _audioEngine!.initAudioGraph();
      setState(() {
        _audioGraphInitialized = true;
        _statusMessage = 'Ready to load audio files';
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
            playheadPosition: _playheadPosition,
            isPlaying: _isPlaying,
            canPlay: _loadedClipId != null,
          ),

          // Main content area
          Expanded(
            child: _loadedClipId == null
                ? _buildEmptyState()
                : _buildTimelineView(),
          ),

          // Status bar
          _buildStatusBar(),
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
                onPressed: () {
                  setState(() {
                    _loadedClipId = null;
                    _clipDuration = null;
                    _waveformPeaks = [];
                    _playheadPosition = 0.0;
                    _isPlaying = false;
                    _statusMessage = 'Ready to load audio files';
                  });
                  _stopPlayback();
                },
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

