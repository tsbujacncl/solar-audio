import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Timeline view widget for displaying audio clips and playhead
class TimelineView extends StatefulWidget {
  final double playheadPosition; // in seconds
  final double? clipDuration; // in seconds (null if no clip loaded)
  final List<double> waveformPeaks; // waveform data
  final VoidCallback? onSeek; // callback when user clicks timeline
  
  const TimelineView({
    super.key,
    required this.playheadPosition,
    this.clipDuration,
    this.waveformPeaks = const [],
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
        color: const Color(0xFF1E1E1E),
        border: Border.all(color: const Color(0xFF404040)),
      ),
      child: Column(
        children: [
          // Time ruler
          _buildTimeRuler(totalWidth, duration),
          
          // Timeline tracks area
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
                    
                    // Audio track
                    _buildAudioTrack(totalWidth),
                    
                    // Playhead
                    _buildPlayhead(),
                  ],
                ),
              ),
            ),
          ),
          
          // Zoom controls
          _buildZoomControls(),
        ],
      ),
    );
  }

  Widget _buildTimeRuler(double width, double duration) {
    return Container(
      height: 30,
      width: width,
      decoration: const BoxDecoration(
        color: Color(0xFF2B2B2B),
        border: Border(
          bottom: BorderSide(color: Color(0xFF404040)),
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

  Widget _buildAudioTrack(double width) {
    if (widget.clipDuration == null || widget.waveformPeaks.isEmpty) {
      return Positioned(
        top: 20,
        left: 0,
        child: Container(
          width: width,
          height: 120,
          decoration: BoxDecoration(
            color: const Color(0xFF2B2B2B),
            border: Border.all(color: const Color(0xFF404040)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Center(
            child: Text(
              'No audio loaded',
              style: TextStyle(
                color: Color(0xFF606060),
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ),
      );
    }

    final clipWidth = widget.clipDuration! * _pixelsPerSecond;
    
    return Positioned(
      top: 20,
      left: 0,
      child: Container(
        width: clipWidth,
        height: 120,
        decoration: BoxDecoration(
          color: const Color(0xFF2B2B2B),
          border: Border.all(color: const Color(0xFF4CAF50), width: 1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: CustomPaint(
            painter: _WaveformPainter(
              peaks: widget.waveformPeaks,
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
        color: Color(0xFF2B2B2B),
        border: Border(
          top: BorderSide(color: Color(0xFF404040)),
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
            color: const Color(0xFFA0A0A0),
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
              activeColor: const Color(0xFFA0A0A0),
              inactiveColor: const Color(0xFF404040),
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _pixelsPerSecond = math.min(200, _pixelsPerSecond + 20);
              });
            },
            icon: const Icon(Icons.zoom_in, size: 20),
            color: const Color(0xFFA0A0A0),
            tooltip: 'Zoom In',
          ),
          const SizedBox(width: 16),
          Text(
            '${_pixelsPerSecond.toInt()}px/s',
            style: const TextStyle(
              color: Color(0xFF808080),
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
      ..color = const Color(0xFF808080)
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
            color: Color(0xFFA0A0A0),
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
      ..color = const Color(0xFF303030)
      ..strokeWidth = 0.5;

    // Vertical grid lines every second
    for (double sec = 0; sec <= duration; sec += 1.0) {
      final x = sec * pixelsPerSecond;
      
      if (x > size.width) break;

      // Major line every 5 seconds
      if (sec % 5 == 0) {
        paint.color = const Color(0xFF404040);
      } else {
        paint.color = const Color(0xFF303030);
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

