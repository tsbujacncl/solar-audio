import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../audio_engine.dart';
import 'track_header.dart';

/// Timeline view widget for displaying audio clips and playhead
class TimelineView extends StatefulWidget {
  final double playheadPosition; // in seconds
  final double? clipDuration; // in seconds (null if no clip loaded)
  final List<double> waveformPeaks; // waveform data
  final AudioEngine? audioEngine;
  final VoidCallback? onSeek; // callback when user clicks timeline

  const TimelineView({
    super.key,
    required this.playheadPosition,
    this.clipDuration,
    this.waveformPeaks = const [],
    this.audioEngine,
    this.onSeek,
  });

  @override
  State<TimelineView> createState() => _TimelineViewState();
}

class _TimelineViewState extends State<TimelineView> {
  final ScrollController _scrollController = ScrollController();
  double _pixelsPerSecond = 100.0; // Zoom level
  
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewWidth = MediaQuery.of(context).size.width;
    final duration = widget.clipDuration ?? 10.0; // Default 10s if no clip
    final totalWidth = math.max(duration * _pixelsPerSecond, viewWidth);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF909090),
        border: Border.all(color: const Color(0xFFAAAAAA)),
      ),
      child: Column(
        children: [
          // Time ruler (with left padding for track headers)
          Row(
            children: [
              const SizedBox(width: 120), // Space for track headers
              Expanded(
                child: _buildTimeRuler(totalWidth, duration),
              ),
            ],
          ),

          // Timeline tracks area with headers
          Expanded(
            child: Row(
              children: [
                // Track headers column
                _buildTrackHeaders(),

                // Timeline tracks scrollable area
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: totalWidth,
                      child: Stack(
                        children: [
                          // Grid lines
                          _buildGrid(totalWidth, duration),

                          // Tracks
                          _buildTracks(totalWidth),

                          // Playhead
                          _buildPlayhead(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Zoom controls
          _buildZoomControls(),
        ],
      ),
    );
  }

  Widget _buildTrackHeaders() {
    // For now, show default track + master track
    return Container(
      width: 120,
      decoration: const BoxDecoration(
        color: Color(0xFF9A9A9A),
        border: Border(
          right: BorderSide(color: Color(0xFFAAAAAA)),
        ),
      ),
      child: Column(
        children: [
          // Audio Track 1 (default)
          TrackHeader(
            trackId: 0,
            trackName: 'Audio 1',
            trackType: 'Audio',
            isMuted: false,
            isSoloed: false,
            peakLevel: 0.0,
            audioEngine: widget.audioEngine,
          ),

          const Spacer(),

          // Master Track
          const MasterTrackHeader(
            peakLevel: 0.0,
          ),
        ],
      ),
    );
  }

  Widget _buildTracks(double width) {
    return Column(
      children: [
        // Audio Track 1
        _buildAudioTrack(width, 0),

        const Spacer(),

        // Master Track (shorter)
        Container(
          height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFF9A9A9A),
            border: Border.all(color: const Color(0xFFAAAAAA)),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeRuler(double width, double duration) {
    return Container(
      height: 30,
      width: width,
      decoration: const BoxDecoration(
        color: Color(0xFF9A9A9A),
        border: Border(
          bottom: BorderSide(color: Color(0xFFAAAAAA)),
        ),
      ),
      child: CustomPaint(
        painter: _TimeRulerPainter(
          duration: duration,
          pixelsPerSecond: _pixelsPerSecond,
        ),
      ),
    );
  }

  Widget _buildGrid(double width, double duration) {
    return CustomPaint(
      size: Size(width, double.infinity),
      painter: _GridPainter(
        duration: duration,
        pixelsPerSecond: _pixelsPerSecond,
      ),
    );
  }

  Widget _buildAudioTrack(double width, int trackIndex) {
    // Empty track container
    return Container(
      height: 100,
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF9A9A9A),
        border: Border.all(color: const Color(0xFFAAAAAA)),
      ),
      child: Stack(
        children: [
          // Show waveform if clip exists
          if (widget.clipDuration != null && widget.waveformPeaks.isNotEmpty)
            _buildClip(widget.clipDuration!, widget.waveformPeaks, 0),
        ],
      ),
    );
  }

  Widget _buildClip(double duration, List<double> peaks, double startPosition) {
    final clipWidth = duration * _pixelsPerSecond;
    final clipX = startPosition * _pixelsPerSecond;

    return Positioned(
      left: clipX,
      top: 8,
      child: Container(
        width: clipWidth,
        height: 84,
        decoration: BoxDecoration(
          color: const Color(0xFF909090),
          border: Border.all(color: const Color(0xFF4CAF50), width: 1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: CustomPaint(
            painter: _WaveformPainter(
              peaks: peaks,
              color: const Color(0xFF4CAF50),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayhead() {
    final playheadX = widget.playheadPosition * _pixelsPerSecond;
    
    return Positioned(
      left: playheadX,
      top: 0,
      bottom: 0,
      child: Column(
        children: [
          // Playhead handle
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: const Color(0xFFF44336),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(
              Icons.play_arrow,
              size: 12,
              color: Colors.white,
            ),
          ),
          // Playhead line
          Expanded(
            child: Container(
              width: 2,
              color: const Color(0xFFF44336),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoomControls() {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF9A9A9A),
        border: Border(
          top: BorderSide(color: Color(0xFFAAAAAA)),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              setState(() {
                _pixelsPerSecond = math.max(20, _pixelsPerSecond - 20);
              });
            },
            icon: const Icon(Icons.zoom_out, size: 20),
            color: const Color(0xFF202020),
            tooltip: 'Zoom Out',
          ),
          Expanded(
            child: Slider(
              value: _pixelsPerSecond,
              min: 20,
              max: 200,
              divisions: 18,
              onChanged: (value) {
                setState(() {
                  _pixelsPerSecond = value;
                });
              },
              activeColor: const Color(0xFF202020),
              inactiveColor: const Color(0xFFAAAAAA),
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _pixelsPerSecond = math.min(200, _pixelsPerSecond + 20);
              });
            },
            icon: const Icon(Icons.zoom_in, size: 20),
            color: const Color(0xFF202020),
            tooltip: 'Zoom In',
          ),
          const SizedBox(width: 16),
          Text(
            '${_pixelsPerSecond.toInt()}px/s',
            style: const TextStyle(
              color: Color(0xFF353535),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// Painter for the time ruler
class _TimeRulerPainter extends CustomPainter {
  final double duration;
  final double pixelsPerSecond;

  _TimeRulerPainter({
    required this.duration,
    required this.pixelsPerSecond,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF353535)
      ..strokeWidth = 1;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    // Draw markers every second
    for (double sec = 0; sec <= duration; sec += 1.0) {
      final x = sec * pixelsPerSecond;
      
      if (x > size.width) break;

      // Major tick every 5 seconds
      final isMajor = sec % 5 == 0;
      final tickHeight = isMajor ? 15.0 : 8.0;
      
      canvas.drawLine(
        Offset(x, size.height - tickHeight),
        Offset(x, size.height),
        paint,
      );

      // Draw time labels for major ticks
      if (isMajor) {
        final minutes = (sec / 60).floor();
        final seconds = (sec % 60).floor();
        final timeText = '$minutes:${seconds.toString().padLeft(2, '0')}';
        
        textPainter.text = TextSpan(
          text: timeText,
          style: const TextStyle(
            color: Color(0xFF202020),
            fontSize: 11,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        );
        
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(x - textPainter.width / 2, 2),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_TimeRulerPainter oldDelegate) {
    return oldDelegate.duration != duration ||
           oldDelegate.pixelsPerSecond != pixelsPerSecond;
  }
}

/// Painter for the grid lines
class _GridPainter extends CustomPainter {
  final double duration;
  final double pixelsPerSecond;

  _GridPainter({
    required this.duration,
    required this.pixelsPerSecond,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF202020)
      ..strokeWidth = 0.5;

    // Vertical grid lines every second
    for (double sec = 0; sec <= duration; sec += 1.0) {
      final x = sec * pixelsPerSecond;
      
      if (x > size.width) break;

      // Major line every 5 seconds
      if (sec % 5 == 0) {
        paint.color = const Color(0xFFAAAAAA);
      } else {
        paint.color = const Color(0xFF202020);
      }
      
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) {
    return oldDelegate.duration != duration ||
           oldDelegate.pixelsPerSecond != pixelsPerSecond;
  }
}

/// Painter for the waveform
class _WaveformPainter extends CustomPainter {
  final List<double> peaks;
  final Color color;

  _WaveformPainter({
    required this.peaks,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (peaks.isEmpty) return;

    final paint = Paint()
      ..color = color.withOpacity(0.7)
      ..style = PaintingStyle.fill;

    final path = Path();
    final centerY = size.height / 2;
    final pixelsPerPeak = size.width / (peaks.length / 2);

    path.moveTo(0, centerY);

    // Draw waveform (peaks come as min/max pairs)
    for (int i = 0; i < peaks.length; i += 2) {
      if (i + 1 >= peaks.length) break;

      final x = (i / 2) * pixelsPerPeak;
      final max = peaks[i + 1];

      final maxY = centerY + (max * centerY);

      if (i == 0) {
        path.moveTo(x, maxY);
      } else {
        path.lineTo(x, maxY);
      }
    }

    // Draw bottom half
    for (int i = peaks.length - 2; i >= 0; i -= 2) {
      final x = (i / 2) * pixelsPerPeak;
      final min = peaks[i];
      final minY = centerY + (min * centerY);
      path.lineTo(x, minY);
    }

    path.close();
    canvas.drawPath(path, paint);

    // Draw center line
    final centerLinePaint = Paint()
      ..color = color.withOpacity(0.3)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, centerY),
      Offset(size.width, centerY),
      centerLinePaint,
    );
  }

  @override
  bool shouldRepaint(_WaveformPainter oldDelegate) {
    return oldDelegate.peaks != peaks || oldDelegate.color != color;
  }
}

