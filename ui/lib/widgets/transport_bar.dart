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

  // File menu callbacks
  final VoidCallback? onNewProject;
  final VoidCallback? onOpenProject;
  final VoidCallback? onSaveProject;
  final VoidCallback? onSaveProjectAs;
  final VoidCallback? onExportProject;
  final VoidCallback? onToggleMixer;
  final bool mixerVisible;
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
    this.onNewProject,
    this.onOpenProject,
    this.onSaveProject,
    this.onSaveProjectAs,
    this.onExportProject,
    this.onToggleMixer,
    this.mixerVisible = true,
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

          // Tempo display
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
                  Icons.speed,
                  size: 14,
                  color: Color(0xFF404040),
                ),
                const SizedBox(width: 6),
                Text(
                  '${tempo.toStringAsFixed(0)} BPM',
                  style: const TextStyle(
                    color: Color(0xFF202020),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 24),
          const VerticalDivider(color: Color(0xFF909090), width: 1),
          const SizedBox(width: 24),
          
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
          
          const Spacer(),

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

          const Spacer(),

          const SizedBox(width: 8),

          // File menu button
          PopupMenuButton<String>(
            icon: const Icon(Icons.folder_open, color: Color(0xFF404040), size: 20),
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
                case 'export':
                  onExportProject?.call();
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

          const SizedBox(width: 4),

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

          // Loading indicator
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF4CAF50),
                ),
              ),
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

