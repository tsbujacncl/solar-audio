import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:async';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:cross_file/cross_file.dart';
import '../audio_engine.dart';
import '../utils/track_colors.dart';
import '../models/clip_data.dart';
import '../models/midi_note_data.dart';
import 'instrument_browser.dart';

/// Track data model for timeline
class TimelineTrackData {
  final int id;
  final String name;
  final String type;

  TimelineTrackData({
    required this.id,
    required this.name,
    required this.type,
  });

  static TimelineTrackData? fromCSV(String csv) {
    try {
      final parts = csv.split(',');
      if (parts.length < 3) return null;
      return TimelineTrackData(
        id: int.parse(parts[0]),
        name: parts[1],
        type: parts[2],
      );
    } catch (e) {
      return null;
    }
  }
}

/// Timeline view widget for displaying audio clips and playhead
class TimelineView extends StatefulWidget {
  final double playheadPosition; // in seconds
  final double? clipDuration; // in seconds (null if no clip loaded)
  final List<double> waveformPeaks; // waveform data
  final AudioEngine? audioEngine;
  final VoidCallback? onSeek; // callback when user clicks timeline

  // MIDI editing state
  final int? selectedMidiTrackId;
  final int? selectedMidiClipId;
  final MidiClipData? currentEditingClip;
  final Function(int?)? onMidiTrackSelected;
  final Function(int?, MidiClipData?)? onMidiClipSelected;
  final Function(MidiClipData)? onMidiClipUpdated;

  // Instrument drag-and-drop
  final Function(int trackId, Instrument instrument)? onInstrumentDropped;
  final Function(Instrument instrument)? onInstrumentDroppedOnEmpty;

  const TimelineView({
    super.key,
    required this.playheadPosition,
    this.clipDuration,
    this.waveformPeaks = const [],
    this.audioEngine,
    this.onSeek,
    this.selectedMidiTrackId,
    this.selectedMidiClipId,
    this.currentEditingClip,
    this.onMidiTrackSelected,
    this.onMidiClipSelected,
    this.onMidiClipUpdated,
    this.onInstrumentDropped,
    this.onInstrumentDroppedOnEmpty,
  });

  @override
  State<TimelineView> createState() => _TimelineViewState();
}

class _TimelineViewState extends State<TimelineView> {
  final ScrollController _scrollController = ScrollController();
  double _pixelsPerSecond = 100.0; // Zoom level
  List<TimelineTrackData> _tracks = [];
  Timer? _refreshTimer;

  // Clip management
  List<ClipData> _clips = [];
  PreviewClip? _previewClip;
  int? _dragHoveredTrackId;

  // MIDI clip management
  Map<int, MidiClipData> _midiClips = {}; // clipId -> MidiClipData

  @override
  void initState() {
    super.initState();
    _loadTracksAsync();

    // Refresh tracks every 2 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _loadTracksAsync();
    });

    // Initialize with current editing clip if present
    if (widget.currentEditingClip != null) {
      _midiClips[widget.currentEditingClip!.clipId] = widget.currentEditingClip!;
    }
  }

  @override
  void didUpdateWidget(TimelineView oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update MIDI clips when currentEditingClip changes
    if (widget.currentEditingClip != null) {
      setState(() {
        _midiClips[widget.currentEditingClip!.clipId] = widget.currentEditingClip!;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  /// Calculate timeline position from mouse X coordinate
  double _calculateTimelinePosition(Offset localPosition) {
    final scrollOffset = _scrollController.hasClients ? _scrollController.offset : 0.0;
    final totalX = localPosition.dx + scrollOffset;
    return totalX / _pixelsPerSecond;
  }

  /// Handle file drop on track
  Future<void> _handleFileDrop(List<XFile> files, int trackId, Offset localPosition) async {
    if (files.isEmpty || widget.audioEngine == null) return;

    final file = files.first;
    final filePath = file.path;

    // Only accept audio files
    if (!filePath.endsWith('.wav') &&
        !filePath.endsWith('.mp3') &&
        !filePath.endsWith('.aif') &&
        !filePath.endsWith('.aiff') &&
        !filePath.endsWith('.flac')) {
      debugPrint('⚠️  Unsupported file type: $filePath');
      return;
    }

    try {
      // Load audio file
      final clipId = widget.audioEngine!.loadAudioFile(filePath);
      if (clipId < 0) {
        debugPrint('❌ Failed to load file: $filePath');
        return;
      }

      // Get duration and waveform
      final duration = widget.audioEngine!.getClipDuration(clipId);
      final peaks = widget.audioEngine!.getWaveformPeaks(clipId, 2000);

      // Calculate drop position
      final startTime = _calculateTimelinePosition(localPosition);

      // Create clip
      final clip = ClipData(
        clipId: clipId,
        trackId: trackId,
        filePath: filePath,
        startTime: startTime,
        duration: duration,
        waveformPeaks: peaks,
        color: const Color(0xFF4CAF50),
      );

      setState(() {
        _clips.add(clip);
        _previewClip = null;
        _dragHoveredTrackId = null;
      });

      debugPrint('✅ Dropped clip on track $trackId at ${startTime.toStringAsFixed(2)}s');
    } catch (e) {
      debugPrint('❌ Error loading dropped file: $e');
    }
  }

  /// Load tracks from audio engine
  Future<void> _loadTracksAsync() async {
    if (widget.audioEngine == null) return;

    try {
      final trackIds = await Future.microtask(() {
        return widget.audioEngine!.getAllTrackIds();
      });

      final tracks = <TimelineTrackData>[];

      for (int trackId in trackIds) {
        final info = await Future.microtask(() {
          return widget.audioEngine!.getTrackInfo(trackId);
        });

        final track = TimelineTrackData.fromCSV(info);
        if (track != null) {
          tracks.add(track);
        }
      }

      if (mounted) {
        setState(() {
          _tracks = tracks;
        });
      }
    } catch (e) {
      debugPrint('❌ Failed to load tracks for timeline: $e');
    }
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
          // Time ruler with zoom controls
          _buildTimeRulerWithZoom(totalWidth, duration),

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
    );
  }

  Widget _buildTracks(double width) {
    // Only show empty state if audio engine is not initialized
    // Master track should always exist, so empty _tracks means audio engine issue
    if (_tracks.isEmpty && widget.audioEngine == null) {
      // Show empty state only if no audio engine
      return Container(
        height: 200,
        color: const Color(0xFF9A9A9A),
        child: Center(
          child: Text(
            'Audio engine not initialized',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ),
      );
    }

    // Separate regular tracks from master
    final regularTracks = _tracks.where((t) => t.type != 'Master').toList();
    final masterTrack = _tracks.firstWhere(
      (t) => t.type == 'Master',
      orElse: () => TimelineTrackData(id: -1, name: 'Master', type: 'Master'),
    );

    // Count audio and MIDI tracks for numbering
    int audioCount = 0;
    int midiCount = 0;

    return Column(
      children: [
        // Regular tracks
        ...regularTracks.asMap().entries.map((entry) {
          final index = entry.key;
          final track = entry.value;

          // Increment counters for track numbering
          if (track.type.toLowerCase() == 'audio') {
            audioCount++;
          } else if (track.type.toLowerCase() == 'midi') {
            midiCount++;
          }

          final trackColor = TrackColors.getTrackColor(index);
          final currentAudioCount = track.type.toLowerCase() == 'audio' ? audioCount : 0;
          final currentMidiCount = track.type.toLowerCase() == 'midi' ? midiCount : 0;

          return _buildTrack(
            width,
            track,
            trackColor,
            currentAudioCount,
            currentMidiCount,
          );
        }),

        // Empty space drop target - wraps spacer to push master track to bottom
        Expanded(
          child: DragTarget<Instrument>(
            onWillAcceptWithDetails: (details) {
              debugPrint('🎯 onWillAccept EMPTY SPACE: instrument=${details.data.name}');
              return true; // Always accept instruments
            },
            onAcceptWithDetails: (details) {
              debugPrint('🎯 onAccept EMPTY SPACE: instrument=${details.data.name}');
              widget.onInstrumentDroppedOnEmpty?.call(details.data);
            },
            builder: (context, candidateInstruments, rejectedInstruments) {
              final isInstrumentHovering = candidateInstruments.isNotEmpty;

              return Container(
                decoration: isInstrumentHovering
                    ? BoxDecoration(
                        color: const Color(0xFF4CAF50).withOpacity(0.1),
                        border: Border.all(
                          color: const Color(0xFF4CAF50),
                          width: 3,
                          style: BorderStyle.solid,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      )
                    : null,
                child: isInstrumentHovering
                    ? Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4CAF50),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.add_circle_outline,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Drop to create new MIDI track with ${candidateInstruments.first?.name ?? "instrument"}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : const SizedBox.expand(),
              );
            },
          ),
        ),

        // Master track at bottom
        if (masterTrack.id != -1)
          _buildMasterTrack(width, masterTrack),
      ],
    );
  }

  Widget _buildTimeRulerWithZoom(double width, double duration) {
    return Container(
      height: 30,
      decoration: const BoxDecoration(
        color: Color(0xFF9A9A9A),
        border: Border(
          bottom: BorderSide(color: Color(0xFFAAAAAA)),
        ),
      ),
      child: Stack(
        children: [
          // Time ruler (full width)
          SizedBox(
            width: width,
            child: CustomPaint(
              painter: _TimeRulerPainter(
                duration: duration,
                pixelsPerSecond: _pixelsPerSecond,
              ),
            ),
          ),

          // Zoom controls (top-right, fixed position)
          Positioned(
            right: 8,
            top: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF9A9A9A).withOpacity(0.95),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _pixelsPerSecond = math.max(20, _pixelsPerSecond - 20);
                      });
                    },
                    icon: const Icon(Icons.remove, size: 14),
                    iconSize: 14,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                    color: const Color(0xFF202020),
                    tooltip: 'Zoom out (Cmd -)',
                  ),
                  Text(
                    '${_pixelsPerSecond.toInt()}',
                    style: const TextStyle(
                      color: Color(0xFF353535),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _pixelsPerSecond = math.min(200, _pixelsPerSecond + 20);
                      });
                    },
                    icon: const Icon(Icons.add, size: 14),
                    iconSize: 14,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                    color: const Color(0xFF202020),
                    tooltip: 'Zoom in (Cmd +)',
                  ),
                ],
              ),
            ),
          ),
        ],
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

  Widget _buildTrack(
    double width,
    TimelineTrackData track,
    Color trackColor,
    int audioCount,
    int midiCount,
  ) {
    // Build formatted name
    final formattedName = TrackColors.getFormattedTrackName(
      trackType: track.type,
      trackName: track.name,
      audioCount: audioCount,
      midiCount: midiCount,
    );
    final emoji = TrackColors.getTrackEmoji(track.name, track.type);

    // Find clips for this track
    final trackClips = _clips.where((c) => c.trackId == track.id).toList();
    final trackMidiClips = _midiClips.values.where((c) => c.trackId == track.id).toList();
    final isHovered = _dragHoveredTrackId == track.id;
    final isSelected = widget.selectedMidiTrackId == track.id;
    final isMidiTrack = track.type.toLowerCase() == 'midi';

    return DragTarget<Instrument>(
      onWillAcceptWithDetails: (details) {
        debugPrint('🎯 onWillAccept: track=${track.id} (${track.type}), isMidiTrack=$isMidiTrack, instrument=${details.data.name}');
        return isMidiTrack;
      },
      onAcceptWithDetails: (details) {
        debugPrint('🎯 onAccept: track=${track.id}, instrument=${details.data.name}');
        widget.onInstrumentDropped?.call(track.id, details.data);
      },
      builder: (context, candidateInstruments, rejectedInstruments) {
        final isInstrumentHovering = candidateInstruments.isNotEmpty;
        final isInstrumentRejected = rejectedInstruments.isNotEmpty;

        return DropTarget(
          onDragEntered: (details) {
            setState(() {
              _dragHoveredTrackId = track.id;
            });
          },
          onDragExited: (details) {
            setState(() {
              _dragHoveredTrackId = null;
              _previewClip = null;
            });
          },
          onDragUpdated: (details) {
            // Update preview position
            final fileName = 'Preview'; // We don't have filename yet
            final startTime = _calculateTimelinePosition(details.localPosition);

            setState(() {
              _previewClip = PreviewClip(
                fileName: fileName,
                startTime: startTime,
                trackId: track.id,
                mousePosition: details.localPosition,
              );
            });
          },
          onDragDone: (details) async {
            await _handleFileDrop(details.files, track.id, details.localPosition);
          },
          child: GestureDetector(
        onTap: isMidiTrack
            ? () {
                // Select MIDI track when clicked
                widget.onMidiTrackSelected?.call(track.id);
              }
            : null,
        child: Container(
        height: 100,
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: isHovered
              ? const Color(0xFF505050) // Lighter when hovered
              : (isSelected
                  ? const Color(0xFF454545) // Slightly lighter when selected
                  : const Color(0xFF404040)),
          border: Border.all(
            color: isInstrumentHovering
                ? const Color(0xFF4CAF50) // Green when valid instrument drag
                : (isInstrumentRejected
                    ? Colors.red.withOpacity(0.8) // Red when invalid drop
                    : (isSelected
                        ? trackColor.withOpacity(1.0)
                        : (isHovered ? trackColor.withOpacity(0.8) : trackColor))),
            width: (isInstrumentHovering || isInstrumentRejected)
                ? 3
                : (isSelected ? 3 : (isHovered ? 3 : 2)),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Track header bar
            Container(
              height: 20,
              color: trackColor.withOpacity(0.3),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Text(
                    '$emoji $formattedName',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // Content area (for clips/waveforms/MIDI)
            Expanded(
              child: Stack(
                children: [
                  // Grid pattern
                  CustomPaint(
                    painter: _GridPatternPainter(),
                  ),

                  // Render audio clips for this track
                  ...trackClips.map((clip) => _buildClip(
                        clip.duration,
                        clip.waveformPeaks,
                        clip.startTime,
                        clip.fileName,
                      )),

                  // Render MIDI clips for this track
                  ...trackMidiClips.map((midiClip) => _buildMidiClip(
                        midiClip,
                        trackColor,
                      )),

                  // Show preview clip if hovering over this track
                  if (_previewClip != null && _previewClip!.trackId == track.id)
                    _buildPreviewClip(_previewClip!),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
        );
      },
    );
  }

  Widget _buildMasterTrack(double width, TimelineTrackData track) {
    return Container(
      height: 100,
      margin: const EdgeInsets.only(bottom: 4), // Match other tracks
      decoration: BoxDecoration(
        color: const Color(0xFF404040),
        border: Border.all(color: TrackColors.masterColor, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Track header bar
          Container(
            height: 20,
            color: TrackColors.masterColor.withOpacity(0.3),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: const Row(
              children: [
                Text(
                  '🎚️ Master',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // Empty content area
          Expanded(
            child: CustomPaint(
              painter: _GridPatternPainter(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClip(double duration, List<double> peaks, double startPosition, String fileName) {
    final clipWidth = duration * _pixelsPerSecond;
    final clipX = startPosition * _pixelsPerSecond;

    return Positioned(
      left: clipX,
      top: 4,
      child: Container(
        width: clipWidth,
        height: 72,
        decoration: BoxDecoration(
          color: const Color(0xFF505050),
          border: Border.all(color: const Color(0xFF4CAF50), width: 2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Stack(
          children: [
            // Waveform
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: CustomPaint(
                painter: _WaveformPainter(
                  peaks: peaks,
                  color: const Color(0xFF4CAF50),
                ),
              ),
            ),
            // File name label
            Positioned(
              top: 2,
              left: 4,
              child: Text(
                fileName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMidiClip(MidiClipData midiClip, Color trackColor) {
    final clipWidth = midiClip.duration * _pixelsPerSecond;
    final clipX = midiClip.startTime * _pixelsPerSecond;
    final isSelected = widget.selectedMidiClipId == midiClip.clipId;

    return Positioned(
      left: clipX,
      top: 4,
      child: GestureDetector(
        onDoubleTap: () {
          // Double-click to open in piano roll
          widget.onMidiClipSelected?.call(midiClip.clipId, midiClip);
        },
        child: Container(
          width: clipWidth,
          height: 72,
          decoration: BoxDecoration(
            color: const Color(0xFF505050),
            border: Border.all(
              color: isSelected ? trackColor.withOpacity(1.0) : trackColor.withOpacity(0.7),
              width: isSelected ? 3 : 2,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Stack(
            children: [
              // Mini piano roll preview
              if (midiClip.notes.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: CustomPaint(
                    painter: _MidiClipPainter(
                      notes: midiClip.notes,
                      clipDuration: midiClip.duration,
                      color: trackColor,
                    ),
                  ),
                ),

              // Clip name label
              Positioned(
                top: 2,
                left: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.piano,
                        size: 10,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        midiClip.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),

              // Show note count
              if (midiClip.notes.isNotEmpty)
                Positioned(
                  bottom: 2,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      '${midiClip.notes.length} notes',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 9,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewClip(PreviewClip preview) {
    const previewDuration = 3.0; // seconds (placeholder)
    final clipWidth = previewDuration * _pixelsPerSecond;
    final clipX = preview.startTime * _pixelsPerSecond;

    return Positioned(
      left: clipX,
      top: 4,
      child: Container(
        width: clipWidth,
        height: 72,
        decoration: BoxDecoration(
          color: const Color(0xFF4CAF50).withOpacity(0.3),
          border: Border.all(
            color: const Color(0xFF4CAF50),
            width: 2,
            strokeAlign: BorderSide.strokeAlignOutside,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: Icon(
            Icons.audiotrack,
            color: const Color(0xFF4CAF50).withOpacity(0.6),
            size: 32,
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

/// Painter for grid pattern in track background
class _GridPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF303030)
      ..strokeWidth = 0.5;

    // Draw subtle horizontal line in middle
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(_GridPatternPainter oldDelegate) => false;
}

/// Painter for mini MIDI clip preview
class _MidiClipPainter extends CustomPainter {
  final List<MidiNoteData> notes;
  final double clipDuration;
  final Color color;

  _MidiClipPainter({
    required this.notes,
    required this.clipDuration,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (notes.isEmpty || clipDuration == 0) return;

    // Find note range for vertical scaling
    final minNote = notes.map((n) => n.note).reduce(math.min);
    final maxNote = notes.map((n) => n.note).reduce(math.max);
    final noteRange = (maxNote - minNote).toDouble();
    final effectiveRange = noteRange == 0 ? 12.0 : noteRange; // At least one octave

    // Calculate scaling factors
    final secondsPerPixel = clipDuration / size.width;
    final pixelsPerNote = size.height / (effectiveRange + 4); // Add padding

    // Draw each note as a rectangle
    for (final note in notes) {
      // Calculate note position in beats, then convert to seconds
      final noteStartInBeats = note.startTime;
      final noteDurationInBeats = note.duration;

      // For display, assume 120 BPM (2 beats per second)
      // This is just for visualization in the mini preview
      final tempo = 120.0;
      final noteStartInSeconds = (noteStartInBeats / tempo) * 60.0;
      final noteDurationInSeconds = (noteDurationInBeats / tempo) * 60.0;

      // Calculate pixel coordinates
      final x = noteStartInSeconds / secondsPerPixel;
      final width = noteDurationInSeconds / secondsPerPixel;
      final y = size.height - ((note.note - minNote + 2) * pixelsPerNote);
      final height = pixelsPerNote * 0.8; // Slight gap between notes

      // Draw note rectangle
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, math.max(width, 2.0), height),
        const Radius.circular(1),
      );

      final notePaint = Paint()
        ..color = note.velocityColor.withOpacity(0.8)
        ..style = PaintingStyle.fill;

      canvas.drawRRect(rect, notePaint);
    }
  }

  @override
  bool shouldRepaint(_MidiClipPainter oldDelegate) {
    return notes != oldDelegate.notes ||
           clipDuration != oldDelegate.clipDuration ||
           color != oldDelegate.color;
  }
}

