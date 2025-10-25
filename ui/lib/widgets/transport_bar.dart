import 'package:flutter/material.dart';

/// Transport control bar for play/pause/stop/record controls
class TransportBar extends StatelessWidget {
  final VoidCallback? onPlay;
  final VoidCallback? onPause;
  final VoidCallback? onStop;
  final VoidCallback? onRecord;
  final VoidCallback? onMetronomeToggle;
  final double playheadPosition; // in seconds
  final bool isPlaying;
  final bool canPlay;
  final bool isRecording;
  final bool isCountingIn;
  final bool metronomeEnabled;
  final double tempo;

  const TransportBar({
    super.key,
    this.onPlay,
    this.onPause,
    this.onStop,
    this.onRecord,
    this.onMetronomeToggle,
    required this.playheadPosition,
    this.isPlaying = false,
    this.canPlay = false,
    this.isRecording = false,
    this.isCountingIn = false,
    this.metronomeEnabled = true,
    this.tempo = 120.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      decoration: const BoxDecoration(
        color: Color(0xFF2B2B2B),
        border: Border(
          bottom: BorderSide(color: Color(0xFF404040)),
        ),
      ),
      child: Row(
        children: [
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
          const VerticalDivider(color: Color(0xFF404040), width: 1),
          const SizedBox(width: 16),
          
          // Metronome toggle
          _MetronomeButton(
            enabled: metronomeEnabled,
            onPressed: onMetronomeToggle,
          ),
          
          const SizedBox(width: 8),
          
          // Tempo display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFF404040)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.speed,
                  size: 14,
                  color: Color(0xFF808080),
                ),
                const SizedBox(width: 6),
                Text(
                  '${tempo.toStringAsFixed(0)} BPM',
                  style: const TextStyle(
                    color: Color(0xFFA0A0A0),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 24),
          const VerticalDivider(color: Color(0xFF404040), width: 1),
          const SizedBox(width: 24),
          
          // Time display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFF404040)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.access_time,
                  size: 16,
                  color: Color(0xFF808080),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatTime(playheadPosition),
                  style: const TextStyle(
                    color: Color(0xFFA0A0A0),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          
          const Spacer(),
          
          // Status indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _getStatusColor().withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _getStatusColor()),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _getStatusColor(),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _getStatusText(),
                  style: TextStyle(
                    color: _getStatusColor(),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
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

  Color _getStatusColor() {
    if (isRecording) return const Color(0xFFFF0000);
    if (isCountingIn) return const Color(0xFFFFC107);
    if (isPlaying) return const Color(0xFF4CAF50);
    return const Color(0xFF808080);
  }

  String _getStatusText() {
    if (isRecording) return 'Recording';
    if (isCountingIn) return 'Count-In';
    if (isPlaying) return 'Playing';
    return 'Stopped';
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
                  : const Color(0xFF303030),
              shape: BoxShape.circle,
              border: Border.all(
                color: onPressed != null 
                    ? color
                    : const Color(0xFF404040),
                width: 2,
              ),
            ),
            child: Icon(
              icon,
              size: size * 0.5,
              color: onPressed != null 
                  ? color
                  : const Color(0xFF606060),
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
                  : const Color(0xFF1E1E1E),
              shape: BoxShape.circle,
              border: Border.all(
                color: enabled 
                    ? const Color(0xFF2196F3)
                    : const Color(0xFF404040),
                width: 2,
              ),
            ),
            child: Icon(
              Icons.graphic_eq,
              size: 20,
              color: enabled 
                  ? const Color(0xFF2196F3)
                  : const Color(0xFF808080),
            ),
          ),
        ),
      ),
    );
  }
}

