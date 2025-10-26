import 'package:flutter/material.dart';
import 'dart:async';
import '../audio_engine.dart';

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

/// Mixer panel widget - slide-in from right
class MixerPanel extends StatefulWidget {
  final AudioEngine? audioEngine;
  final VoidCallback onClose;
  final Function(int?)? onFXButtonClicked;

  const MixerPanel({
    super.key,
    required this.audioEngine,
    required this.onClose,
    this.onFXButtonClicked,
  });

  @override
  State<MixerPanel> createState() => _MixerPanelState();
}

class _MixerPanelState extends State<MixerPanel> {
  List<TrackData> _tracks = [];
  Timer? _refreshTimer;
  int? _selectedTrackForFX;

  @override
  void initState() {
    super.initState();
    _loadTracksAsync(); // Load asynchronously on init

    // Refresh tracks every 2 seconds (reduced frequency to avoid UI blocking)
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

    // Run FFI calls in a future to avoid blocking UI
    try {
      // These FFI calls can block if audio thread holds locks,
      // so we yield to the event loop between calls
      final trackIds = await Future.microtask(() {
        return widget.audioEngine!.getAllTrackIds();
      });

      final tracks = <TrackData>[];

      for (int trackId in trackIds) {
        // Yield to event loop between each track query
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

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300, // Reduced from 400px
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

          // Track strips
          Expanded(
            child: _tracks.isEmpty
                ? _buildEmptyState()
                : _buildTrackList(),
          ),

          // Add track buttons
          _buildAddTrackBar(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
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
            size: 20,
          ),
          const SizedBox(width: 12),
          const Text(
            'MIXER',
            style: TextStyle(
              color: Color(0xFF202020),
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close),
            color: const Color(0xFF202020),
            iconSize: 20,
            onPressed: widget.onClose,
            tooltip: 'Close mixer',
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

  Widget _buildTrackList() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Regular tracks
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _tracks.where((t) => t.type != 'Master').map((track) => _buildTrackStrip(track)).toList(),
            ),
          ),
        ),

        // Master track
        if (_tracks.any((t) => t.type == 'Master'))
          _buildMasterTrackStrip(_tracks.firstWhere((t) => t.type == 'Master')),
      ],
    );
  }

  Widget _buildTrackStrip(TrackData track) {
    return Container(
      width: 100,
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF656565),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF909090)),
      ),
      child: Column(
        children: [
          // Track name and type
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFF707070),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Column(
              children: [
                Text(
                  track.name,
                  style: const TextStyle(
                    color: Color(0xFF202020),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  track.type.toUpperCase(),
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),

          // Volume fader
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: _buildVolumeFader(track),
            ),
          ),

          // Pan knob (simplified as slider for now)
          _buildPanControl(track),

          // Mute/Solo buttons
          _buildMuteSoloButtons(track),

          const SizedBox(height: 8),

          // FX and Delete buttons
          _buildTrackActions(track),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildTrackActions(TrackData track) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          // FX button
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                if (widget.onFXButtonClicked != null) {
                  // Use parent callback (new bottom panel approach)
                  widget.onFXButtonClicked!(
                    _selectedTrackForFX == track.id ? null : track.id
                  );
                  setState(() {
                    _selectedTrackForFX =
                        _selectedTrackForFX == track.id ? null : track.id;
                  });
                } else {
                  // Fallback to old approach (show effect panel on right)
                  setState(() {
                    _selectedTrackForFX =
                        _selectedTrackForFX == track.id ? null : track.id;
                  });
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedTrackForFX == track.id
                    ? const Color(0xFF4CAF50)
                    : const Color(0xFF909090),
                foregroundColor: _selectedTrackForFX == track.id
                    ? Colors.white
                    : const Color(0xFF404040),
                padding: const EdgeInsets.symmetric(vertical: 4),
                minimumSize: const Size(0, 24),
              ),
              child: const Text('FX', style: TextStyle(fontSize: 10)),
            ),
          ),
          const SizedBox(width: 4),

          // Delete button
          SizedBox(
            width: 24,
            child: IconButton(
              icon: const Icon(Icons.close, size: 14),
              color: const Color(0xFF404040),
              padding: EdgeInsets.zero,
              onPressed: () => _confirmDeleteTrack(track),
              tooltip: 'Delete track',
            ),
          ),
        ],
      ),
    );
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

  Widget _buildMasterTrackStrip(TrackData track) {
    return Container(
      width: 120,
      margin: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF606060),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF4CAF50), width: 2),
      ),
      child: Column(
        children: [
          // Track name
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFF707070),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(6),
              ),
            ),
            child: Column(
              children: [
                const Text(
                  'MASTER',
                  style: TextStyle(
                    color: Color(0xFF4CAF50),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  track.type.toUpperCase(),
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),

          // Volume fader
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: _buildVolumeFader(track),
            ),
          ),

          // Pan control
          _buildPanControl(track),

          const SizedBox(height: 8),

          // Limiter indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF707070),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.security, size: 12, color: Color(0xFF4CAF50)),
                  SizedBox(width: 4),
                  Text(
                    'LIMITER',
                    style: TextStyle(
                      color: Color(0xFF4CAF50),
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildVolumeFader(TrackData track) {
    return Column(
      children: [
        // Volume label
        Text(
          '${track.volumeDb.toStringAsFixed(1)} dB',
          style: const TextStyle(
            color: Color(0xFF404040),
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 8),

        // Vertical slider
        Expanded(
          child: RotatedBox(
            quarterTurns: 3,
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 6,
                ),
                overlayShape: const RoundSliderOverlayShape(
                  overlayRadius: 12,
                ),
                activeTrackColor: const Color(0xFF4CAF50),
                inactiveTrackColor: const Color(0xFF909090),
                thumbColor: const Color(0xFF202020),
              ),
              child: Slider(
                value: _volumeDbToSlider(track.volumeDb),
                min: 0.0,
                max: 1.0,
                onChanged: (value) {
                  final volumeDb = _sliderToVolumeDb(value);
                  setState(() {
                    track.volumeDb = volumeDb;
                  });
                  widget.audioEngine?.setTrackVolume(track.id, volumeDb);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPanControl(TrackData track) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Text(
            _panToLabel(track.pan),
            style: const TextStyle(
              color: Color(0xFF404040),
              fontSize: 10,
            ),
          ),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 5,
              ),
              overlayShape: const RoundSliderOverlayShape(
                overlayRadius: 10,
              ),
              activeTrackColor: const Color(0xFF2196F3),
              inactiveTrackColor: const Color(0xFF909090),
              thumbColor: const Color(0xFF202020),
            ),
            child: Slider(
              value: track.pan,
              min: -1.0,
              max: 1.0,
              onChanged: (value) {
                setState(() {
                  track.pan = value;
                });
                widget.audioEngine?.setTrackPan(track.id, value);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMuteSoloButtons(TrackData track) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          // Mute button
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  track.mute = !track.mute;
                });
                widget.audioEngine?.setTrackMute(track.id, track.mute);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: track.mute
                    ? const Color(0xFFFF5722)
                    : const Color(0xFF909090),
                foregroundColor: track.mute
                    ? Colors.white
                    : const Color(0xFF404040),
                padding: const EdgeInsets.symmetric(vertical: 4),
                minimumSize: const Size(0, 24),
              ),
              child: const Text('M', style: TextStyle(fontSize: 11)),
            ),
          ),
          const SizedBox(width: 4),

          // Solo button
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  track.solo = !track.solo;
                });
                widget.audioEngine?.setTrackSolo(track.id, track.solo);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: track.solo
                    ? const Color(0xFFFFC107)
                    : const Color(0xFF909090),
                foregroundColor: track.solo
                    ? Colors.black
                    : const Color(0xFF404040),
                padding: const EdgeInsets.symmetric(vertical: 4),
                minimumSize: const Size(0, 24),
              ),
              child: const Text('S', style: TextStyle(fontSize: 11)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddTrackBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Color(0xFF656565),
        border: Border(
          top: BorderSide(color: Color(0xFF909090)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _createTrack('audio'),
              icon: const Icon(Icons.audiotrack, size: 16),
              label: const Text('Audio'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF909090),
                foregroundColor: const Color(0xFF202020),
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _createTrack('midi'),
              icon: const Icon(Icons.piano, size: 16),
              label: const Text('MIDI'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF909090),
                foregroundColor: const Color(0xFF202020),
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper functions for volume conversion
  double _volumeDbToSlider(double volumeDb) {
    // Convert dB (-60 to +6) to slider (0 to 1)
    // 0 dB should be at 0.75 position
    return (volumeDb + 60.0) / 66.0;
  }

  double _sliderToVolumeDb(double slider) {
    // Convert slider (0 to 1) to dB (-60 to +6)
    return (slider * 66.0) - 60.0;
  }

  String _panToLabel(double pan) {
    if (pan < -0.05) {
      return 'L${(pan.abs() * 100).toStringAsFixed(0)}';
    } else if (pan > 0.05) {
      return 'R${(pan * 100).toStringAsFixed(0)}';
    } else {
      return 'C';
    }
  }
}
