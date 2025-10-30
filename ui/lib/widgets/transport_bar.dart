import 'package:flutter/material.dart';

/// Transport control bar for play/pause/stop/record controls
class TransportBar extends StatelessWidget {
  final VoidCallback? onPlay;
  final VoidCallback? onPause;
  final VoidCallback? onStop;
  final VoidCallback? onRecord;
  final VoidCallback? onMetronomeToggle;
  final VoidCallback? onPianoToggle;
  final double playheadPosition; // in seconds
  final bool isPlaying;
  final bool canPlay;
  final bool isRecording;
  final bool isCountingIn;
  final bool metronomeEnabled;
  final bool virtualPianoEnabled;
  final double tempo;
  final Function(double)? onTempoChanged;

  // File menu callbacks
  final VoidCallback? onNewProject;
  final VoidCallback? onOpenProject;
  final VoidCallback? onSaveProject;
  final VoidCallback? onSaveProjectAs;
  final VoidCallback? onMakeCopy;
  final VoidCallback? onExportAudio;
  final VoidCallback? onExportMidi;
  final VoidCallback? onProjectSettings;
  final VoidCallback? onCloseProject;

  // View menu callbacks
  final VoidCallback? onToggleLibrary;
  final VoidCallback? onToggleMixer;
  final VoidCallback? onToggleEditor;
  final VoidCallback? onTogglePiano;
  final VoidCallback? onResetPanelLayout;

  // View menu state
  final bool libraryVisible;
  final bool mixerVisible;
  final bool editorVisible;
  final bool pianoVisible;

  final bool isLoading;

  const TransportBar({
    super.key,
    this.onPlay,
    this.onPause,
    this.onStop,
    this.onRecord,
    this.onMetronomeToggle,
    this.onPianoToggle,
    required this.playheadPosition,
    this.isPlaying = false,
    this.canPlay = false,
    this.isRecording = false,
    this.isCountingIn = false,
    this.metronomeEnabled = true,
    this.virtualPianoEnabled = false,
    this.tempo = 120.0,
    this.onTempoChanged,
    this.onNewProject,
    this.onOpenProject,
    this.onSaveProject,
    this.onSaveProjectAs,
    this.onMakeCopy,
    this.onExportAudio,
    this.onExportMidi,
    this.onProjectSettings,
    this.onCloseProject,
    this.onToggleLibrary,
    this.onToggleMixer,
    this.onToggleEditor,
    this.onTogglePiano,
    this.onResetPanelLayout,
    this.libraryVisible = true,
    this.mixerVisible = true,
    this.editorVisible = true,
    this.pianoVisible = false,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      decoration: const BoxDecoration(
        color: Color(0xFF707070), // Medium grey panel
        border: Border(
          bottom: BorderSide(color: Color(0xFF909090)), // Light grey border
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),

          // Solar logo
          Image.asset(
            'assets/images/solar_logo.png',
            height: 32,
            fit: BoxFit.contain,
          ),

          const SizedBox(width: 8),

          // File menu button
          PopupMenuButton<String>(
            icon: const Icon(Icons.folder, color: Color(0xFF404040), size: 20),
            tooltip: 'File',
            onSelected: (String value) {
              switch (value) {
                case 'new':
                  onNewProject?.call();
                  break;
                case 'open':
                  onOpenProject?.call();
                  break;
                case 'save':
                  onSaveProject?.call();
                  break;
                case 'save_as':
                  onSaveProjectAs?.call();
                  break;
                case 'make_copy':
                  onMakeCopy?.call();
                  break;
                case 'export_audio':
                  onExportAudio?.call();
                  break;
                case 'export_midi':
                  onExportMidi?.call();
                  break;
                case 'settings':
                  onProjectSettings?.call();
                  break;
                case 'close':
                  onCloseProject?.call();
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
                    Text('Open Project...'),
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
              const PopupMenuItem<String>(
                value: 'make_copy',
                child: Row(
                  children: [
                    Icon(Icons.content_copy, size: 18),
                    SizedBox(width: 8),
                    Text('Make a Copy...'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'export_audio',
                child: Row(
                  children: [
                    Icon(Icons.audio_file, size: 18),
                    SizedBox(width: 8),
                    Text('Export Audio...'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'export_midi',
                child: Row(
                  children: [
                    Icon(Icons.music_note, size: 18),
                    SizedBox(width: 8),
                    Text('Export MIDI...'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings, size: 18),
                    SizedBox(width: 8),
                    Text('Project Settings...'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'close',
                child: Row(
                  children: [
                    Icon(Icons.close, size: 18),
                    SizedBox(width: 8),
                    Text('Close Project'),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(width: 4),

          // View menu button
          PopupMenuButton<String>(
            icon: const Icon(Icons.visibility, color: Color(0xFF404040), size: 20),
            tooltip: 'View',
            onSelected: (String value) {
              switch (value) {
                case 'library':
                  onToggleLibrary?.call();
                  break;
                case 'mixer':
                  onToggleMixer?.call();
                  break;
                case 'editor':
                  onToggleEditor?.call();
                  break;
                case 'piano':
                  onTogglePiano?.call();
                  break;
                case 'reset':
                  onResetPanelLayout?.call();
                  break;
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'library',
                child: Row(
                  children: [
                    Icon(
                      libraryVisible ? Icons.check_box : Icons.check_box_outline_blank,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    const Text('Library Panel'),
                    const Spacer(),
                    const Text('L', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'mixer',
                child: Row(
                  children: [
                    Icon(
                      mixerVisible ? Icons.check_box : Icons.check_box_outline_blank,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    const Text('Mixer Panel'),
                    const Spacer(),
                    const Text('M', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'editor',
                child: Row(
                  children: [
                    Icon(
                      editorVisible ? Icons.check_box : Icons.check_box_outline_blank,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    const Text('Editor Panel'),
                    const Spacer(),
                    const Text('E', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'piano',
                child: Row(
                  children: [
                    Icon(
                      pianoVisible ? Icons.check_box : Icons.check_box_outline_blank,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    const Text('Virtual Piano'),
                    const Spacer(),
                    const Text('P', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'reset',
                child: Row(
                  children: [
                    Icon(Icons.restart_alt, size: 18),
                    SizedBox(width: 8),
                    Text('Reset Panel Layout'),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(width: 24),
          const VerticalDivider(color: Color(0xFF909090), width: 1),
          const SizedBox(width: 16),

          // Play/Pause button
          _TransportButton(
            icon: isPlaying ? Icons.pause : Icons.play_arrow,
            color: isPlaying ? const Color(0xFFFFC107) : const Color(0xFF4CAF50),
            onPressed: canPlay ? (isPlaying ? onPause : onPlay) : null,
            tooltip: isPlaying ? 'Pause' : 'Play',
            size: 48,
          ),

          const SizedBox(width: 8),

          // Stop button
          _TransportButton(
            icon: Icons.stop,
            color: const Color(0xFFF44336),
            onPressed: canPlay ? onStop : null,
            tooltip: 'Stop',
            size: 40,
          ),

          const SizedBox(width: 16),

          // Record button
          _TransportButton(
            icon: Icons.fiber_manual_record,
            color: isRecording || isCountingIn
                ? const Color(0xFFFF0000)
                : const Color(0xFFE91E63),
            onPressed: onRecord,
            tooltip: isRecording
                ? 'Stop Recording'
                : (isCountingIn ? 'Counting In...' : 'Record'),
            size: 44,
          ),

          const SizedBox(width: 24),
          const VerticalDivider(color: Color(0xFF909090), width: 1),
          const SizedBox(width: 16),

          // Metronome toggle
          _MetronomeButton(
            enabled: metronomeEnabled,
            onPressed: onMetronomeToggle,
          ),

          const SizedBox(width: 8),

          // Virtual piano toggle
          _PianoButton(
            enabled: virtualPianoEnabled,
            onPressed: onPianoToggle,
          ),

          const SizedBox(width: 8),

          // Tempo control with drag and tap
          _TempoControl(
            tempo: tempo,
            onTempoChanged: onTempoChanged,
          ),

          const SizedBox(width: 8),

          // Time display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF656565),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFF909090)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.access_time,
                  size: 14,
                  color: Color(0xFF404040),
                ),
                const SizedBox(width: 6),
                Text(
                  _formatTime(playheadPosition),
                  style: const TextStyle(
                    color: Color(0xFF202020),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Position display (bars.beats.subdivision)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF656565),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFF909090)),
            ),
            child: Text(
              _formatPosition(playheadPosition, tempo),
              style: const TextStyle(
                color: Color(0xFF202020),
                fontSize: 14,
                fontWeight: FontWeight.w600,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),

          const SizedBox(width: 24),
          const VerticalDivider(color: Color(0xFF909090), width: 1),
          const SizedBox(width: 16),

          // Mixer toggle button
          IconButton(
            icon: Icon(
              Icons.tune,
              color: mixerVisible ? const Color(0xFF4CAF50) : const Color(0xFF404040),
              size: 20,
            ),
            onPressed: onToggleMixer,
            tooltip: 'Toggle Mixer',
          ),

          const SizedBox(width: 16),
        ],
      ),
    );
  }

  String _formatTime(double seconds) {
    final minutes = (seconds / 60).floor();
    final secs = (seconds % 60).floor();
    final ms = ((seconds % 1) * 1000).floor();

    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}.${ms.toString().padLeft(3, '0')}';
  }

  String _formatPosition(double seconds, double bpm) {
    // Calculate position in bars.beats.subdivision format
    final beatsPerSecond = bpm / 60.0;
    final totalBeats = seconds * beatsPerSecond;

    // Assuming 4/4 time signature
    final beatsPerBar = 4;
    final subdivisionsPerBeat = 4; // 16th notes

    final bar = (totalBeats / beatsPerBar).floor() + 1; // 1-indexed
    final beat = (totalBeats % beatsPerBar).floor() + 1; // 1-indexed
    final subdivision = ((totalBeats % 1) * subdivisionsPerBeat).floor() + 1; // 1-indexed

    return '$bar.$beat.$subdivision';
  }
}

/// Individual transport button widget
class _TransportButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;
  final String tooltip;
  final double size;

  const _TransportButton({
    required this.icon,
    required this.color,
    required this.onPressed,
    required this.tooltip,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(size / 2),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: onPressed != null 
                  ? color.withOpacity(0.2)
                  : const Color(0xFF404040),
              shape: BoxShape.circle,
              border: Border.all(
                color: onPressed != null 
                    ? color
                    : const Color(0xFF909090),
                width: 2,
              ),
            ),
            child: Icon(
              icon,
              size: size * 0.5,
              color: onPressed != null 
                  ? color
                  : const Color(0xFF505050),
            ),
          ),
        ),
      ),
    );
  }
}

/// Metronome toggle button widget
class _MetronomeButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback? onPressed;

  const _MetronomeButton({
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: enabled ? 'Metronome On' : 'Metronome Off',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: enabled
                  ? const Color(0xFF2196F3).withOpacity(0.2)
                  : const Color(0xFF5A5A5A),
              shape: BoxShape.circle,
              border: Border.all(
                color: enabled
                    ? const Color(0xFF2196F3)
                    : const Color(0xFF909090),
                width: 2,
              ),
            ),
            child: Icon(
              Icons.graphic_eq,
              size: 20,
              color: enabled
                  ? const Color(0xFF2196F3)
                  : const Color(0xFF404040),
            ),
          ),
        ),
      ),
    );
  }
}

/// Virtual piano toggle button widget
class _PianoButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback? onPressed;

  const _PianoButton({
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: enabled ? 'Virtual Piano On (z,x,c,w,e,r...)' : 'Virtual Piano Off',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: enabled
                  ? const Color(0xFF4CAF50).withOpacity(0.2)
                  : const Color(0xFF5A5A5A),
              shape: BoxShape.circle,
              border: Border.all(
                color: enabled
                    ? const Color(0xFF4CAF50)
                    : const Color(0xFF909090),
                width: 2,
              ),
            ),
            child: Icon(
              Icons.piano,
              size: 20,
              color: enabled
                  ? const Color(0xFF4CAF50)
                  : const Color(0xFF404040),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tempo control widget with drag interaction and tap tempo (Ableton-style)
class _TempoControl extends StatefulWidget {
  final double tempo;
  final Function(double)? onTempoChanged;

  const _TempoControl({
    required this.tempo,
    this.onTempoChanged,
  });

  @override
  State<_TempoControl> createState() => _TempoControlState();
}

class _TempoControlState extends State<_TempoControl> {
  bool _isDragging = false;
  double _dragStartY = 0.0;
  double _dragStartTempo = 120.0;
  List<DateTime> _tapTimes = [];

  void _onTapTempo() {
    final now = DateTime.now();
    setState(() {
      // Remove taps older than 3 seconds
      _tapTimes.removeWhere((time) => now.difference(time).inSeconds > 3);

      // Add current tap
      _tapTimes.add(now);

      // Need at least 2 taps to calculate tempo
      if (_tapTimes.length >= 2) {
        // Calculate average interval between taps
        double totalInterval = 0.0;
        for (int i = 1; i < _tapTimes.length; i++) {
          totalInterval += _tapTimes[i].difference(_tapTimes[i - 1]).inMilliseconds;
        }
        final avgInterval = totalInterval / (_tapTimes.length - 1);

        // Convert interval to BPM (60000ms = 1 minute)
        final bpm = (60000.0 / avgInterval).clamp(20.0, 300.0).roundToDouble();
        widget.onTempoChanged?.call(bpm);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Always show integers (tempo is rounded to whole numbers)
    final tempoText = widget.tempo.toStringAsFixed(0);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Tap tempo button
        InkWell(
          onTap: _onTapTempo,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _tapTimes.isNotEmpty &&
                     DateTime.now().difference(_tapTimes.last).inMilliseconds < 500
                  ? const Color(0xFF4CAF50).withOpacity(0.3)
                  : const Color(0xFF656565),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFF909090)),
            ),
            child: const Text(
              'Tap',
              style: TextStyle(
                color: Color(0xFF202020),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),

        const SizedBox(width: 4),

        // Tempo display with drag interaction
        GestureDetector(
          onVerticalDragStart: (details) {
            setState(() {
              _isDragging = true;
              _dragStartY = details.globalPosition.dy;
              _dragStartTempo = widget.tempo;
            });
          },
          onVerticalDragUpdate: (details) {
            if (widget.onTempoChanged != null) {
              // Drag up = increase tempo, drag down = decrease tempo
              final deltaY = _dragStartY - details.globalPosition.dy;
              // ~0.5 BPM per pixel (like Ableton)
              final deltaTempo = deltaY * 0.5;
              final newTempo = (_dragStartTempo + deltaTempo).clamp(20.0, 300.0).roundToDouble();
              widget.onTempoChanged!(newTempo);
            }
          },
          onVerticalDragEnd: (details) {
            setState(() {
              _isDragging = false;
            });
          },
          child: MouseRegion(
            cursor: SystemMouseCursors.resizeUpDown,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _isDragging
                    ? const Color(0xFF4CAF50).withOpacity(0.2)
                    : const Color(0xFF656565),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: _isDragging
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFF909090),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.speed,
                    size: 14,
                    color: Color(0xFF404040),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$tempoText BPM',
                    style: const TextStyle(
                      color: Color(0xFF202020),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

