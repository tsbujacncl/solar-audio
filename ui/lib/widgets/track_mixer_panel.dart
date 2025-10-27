import 'package:flutter/material.dart';
import 'dart:async';
import '../audio_engine.dart';
import 'track_mixer_strip.dart';
import '../utils/track_colors.dart';

/// Track data model
class TrackData {
  final int id;
  final String name;
  final String type;
  double volumeDb;
  double pan;
  bool mute;
  bool solo;

  TrackData({
    required this.id,
    required this.name,
    required this.type,
    required this.volumeDb,
    required this.pan,
    required this.mute,
    required this.solo,
  });

  /// Parse track info from CSV format: "track_id,name,type,volume_db,pan,mute,solo"
  static TrackData? fromCSV(String csv) {
    try {
      final parts = csv.split(',');
      if (parts.length < 7) return null;

      return TrackData(
        id: int.parse(parts[0]),
        name: parts[1],
        type: parts[2],
        volumeDb: double.parse(parts[3]),
        pan: double.parse(parts[4]),
        mute: parts[5] == 'true' || parts[5] == '1',
        solo: parts[6] == 'true' || parts[6] == '1',
      );
    } catch (e) {
      debugPrint('❌ Failed to parse track data: $e');
      return null;
    }
  }
}

/// Track mixer panel - displays track mixer strips vertically aligned with timeline
class TrackMixerPanel extends StatefulWidget {
  final AudioEngine? audioEngine;
  final Function(int?)? onFXButtonClicked;
  final ScrollController? scrollController; // For syncing with timeline

  const TrackMixerPanel({
    super.key,
    required this.audioEngine,
    this.onFXButtonClicked,
    this.scrollController,
  });

  @override
  State<TrackMixerPanel> createState() => _TrackMixerPanelState();
}

class _TrackMixerPanelState extends State<TrackMixerPanel> {
  List<TrackData> _tracks = [];
  Timer? _refreshTimer;
  int? _selectedTrackForFX;

  @override
  void initState() {
    super.initState();
    _loadTracksAsync();

    // Refresh tracks every 2 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _loadTracksAsync();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  /// Load tracks asynchronously to avoid blocking UI thread
  Future<void> _loadTracksAsync() async {
    if (widget.audioEngine == null) return;

    try {
      final trackIds = await Future.microtask(() {
        return widget.audioEngine!.getAllTrackIds();
      });

      final tracks = <TrackData>[];

      for (int trackId in trackIds) {
        final info = await Future.microtask(() {
          return widget.audioEngine!.getTrackInfo(trackId);
        });

        final track = TrackData.fromCSV(info);
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
      debugPrint('❌ Failed to load tracks: $e');
    }
  }

  void _createTrack(String type) {
    if (widget.audioEngine == null) return;

    final name = '${type.toUpperCase()} ${_tracks.length + 1}';
    final trackId = widget.audioEngine!.createTrack(type, name);

    if (trackId >= 0) {
      _loadTracksAsync();
    }
  }

  void _showAddTrackMenu() {
    // Find the button position
    final RenderBox? overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;

    // Show popup menu
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        overlay.size.width - 380, // Position near the + button (380 is panel width)
        30, // Below the header
        overlay.size.width,
        0,
      ),
      items: [
        PopupMenuItem<String>(
          value: 'audio',
          child: Row(
            children: const [
              Icon(Icons.audiotrack, size: 18, color: Color(0xFF202020)),
              SizedBox(width: 12),
              Text('Audio Track', style: TextStyle(fontSize: 14)),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'midi',
          child: Row(
            children: const [
              Icon(Icons.piano, size: 18, color: Color(0xFF202020)),
              SizedBox(width: 12),
              Text('MIDI Track', style: TextStyle(fontSize: 14)),
            ],
          ),
        ),
      ],
      elevation: 8,
    ).then((value) {
      if (value != null) {
        _createTrack(value);
      }
    });
  }

  void _confirmDeleteTrack(TrackData track) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Track'),
        content: Text('Are you sure you want to delete "${track.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              widget.audioEngine?.deleteTrack(track.id);
              Navigator.of(context).pop();
              _loadTracksAsync();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 380,
      decoration: const BoxDecoration(
        color: Color(0xFF707070),
        border: Border(
          left: BorderSide(color: Color(0xFF909090)),
        ),
      ),
      child: Column(
        children: [
          // Header
          _buildHeader(),

          // Track strips (vertically scrollable)
          Expanded(
            child: _tracks.isEmpty
                ? _buildEmptyState()
                : _buildTrackStrips(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 30, // Match timeline ruler height
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF656565),
        border: Border(
          bottom: BorderSide(color: Color(0xFF909090)),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.tune,
            color: Color(0xFF202020),
            size: 16,
          ),
          const SizedBox(width: 8),
          const Text(
            'TRACK MIXER',
            style: TextStyle(
              color: Color(0xFF202020),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const Spacer(),
          // Add track button
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            color: const Color(0xFF202020),
            iconSize: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            onPressed: _showAddTrackMenu,
            tooltip: 'Add track',
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.audio_file_outlined,
            size: 48,
            color: Colors.grey[700],
          ),
          const SizedBox(height: 16),
          Text(
            'No tracks yet',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a track to get started',
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackStrips() {
    // Separate regular tracks from master track
    final regularTracks = _tracks.where((t) => t.type != 'Master').toList();
    final masterTrack = _tracks.firstWhere(
      (t) => t.type == 'Master',
      orElse: () => TrackData(
        id: -1,
        name: 'Master',
        type: 'Master',
        volumeDb: 0.0,
        pan: 0.0,
        mute: false,
        solo: false,
      ),
    );

    return Column(
      children: [
        // Regular tracks in scrollable area
        Expanded(
          child: SingleChildScrollView(
            controller: widget.scrollController,
            child: Column(
              children: regularTracks.asMap().entries.map((entry) {
                final index = entry.key;
                final track = entry.value;
                final trackColor = TrackColors.getTrackColor(index);

                return TrackMixerStrip(
                    trackId: track.id,
                    trackName: track.name,
                    trackType: track.type,
                    volumeDb: track.volumeDb,
                    pan: track.pan,
                    isMuted: track.mute,
                    isSoloed: track.solo,
                    peakLevel: 0.0, // TODO: Get real-time level from audio engine
                    trackColor: trackColor,
                    audioEngine: widget.audioEngine,
                    isFXActive: _selectedTrackForFX == track.id,
                    onVolumeChanged: (volumeDb) {
                      setState(() {
                        track.volumeDb = volumeDb;
                      });
                      widget.audioEngine?.setTrackVolume(track.id, volumeDb);
                    },
                    onPanChanged: (pan) {
                      setState(() {
                        track.pan = pan;
                      });
                      widget.audioEngine?.setTrackPan(track.id, pan);
                    },
                    onMuteToggle: () {
                      setState(() {
                        track.mute = !track.mute;
                      });
                      widget.audioEngine?.setTrackMute(track.id, track.mute);
                    },
                    onSoloToggle: () {
                      setState(() {
                        track.solo = !track.solo;
                      });
                      widget.audioEngine?.setTrackSolo(track.id, track.solo);
                    },
                    onFXPressed: () {
                      if (widget.onFXButtonClicked != null) {
                        widget.onFXButtonClicked!(
                          _selectedTrackForFX == track.id ? null : track.id
                        );
                      }
                      setState(() {
                        _selectedTrackForFX =
                            _selectedTrackForFX == track.id ? null : track.id;
                      });
                    },
                    onDeletePressed: () => _confirmDeleteTrack(track),
                  );
                }).toList(),
            ),
          ),
        ),

        // Master track pinned at bottom (outside scroll area)
        if (masterTrack.id != -1)
          MasterTrackMixerStrip(
            volumeDb: masterTrack.volumeDb,
            pan: masterTrack.pan,
            peakLevel: 0.0, // TODO: Get real-time level
            onVolumeChanged: (volumeDb) {
              setState(() {
                masterTrack.volumeDb = volumeDb;
              });
              widget.audioEngine?.setTrackVolume(masterTrack.id, volumeDb);
            },
            onPanChanged: (pan) {
              setState(() {
                masterTrack.pan = pan;
              });
              widget.audioEngine?.setTrackPan(masterTrack.id, pan);
            },
          ),
      ],
    );
  }

}
