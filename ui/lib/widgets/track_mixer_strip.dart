import 'package:flutter/material.dart';
import '../audio_engine.dart';
import 'instrument_browser.dart';
import '../models/instrument_data.dart';

/// Unified track strip combining track info and mixer controls
/// Displayed on the right side of timeline, aligned with each track row
class TrackMixerStrip extends StatelessWidget {
  final int trackId;
  final String trackName;
  final String trackType;
  final double volumeDb;
  final double pan;
  final bool isMuted;
  final bool isSoloed;
  final double peakLevel; // 0.0 to 1.0
  final Color? trackColor; // Optional track color for left border
  final AudioEngine? audioEngine;

  // Callbacks
  final Function(double)? onVolumeChanged;
  final Function(double)? onPanChanged;
  final VoidCallback? onMuteToggle;
  final VoidCallback? onSoloToggle;
  final VoidCallback? onTap; // Unified track selection callback
  final VoidCallback? onDeletePressed;
  final VoidCallback? onDuplicatePressed;
  final bool isSelected; // Track selection state

  // MIDI instrument selection
  final InstrumentData? instrumentData;
  final Function(String)? onInstrumentSelect; // Callback with instrument ID

  const TrackMixerStrip({
    super.key,
    required this.trackId,
    required this.trackName,
    required this.trackType,
    required this.volumeDb,
    required this.pan,
    required this.isMuted,
    required this.isSoloed,
    this.peakLevel = 0.0,
    this.trackColor,
    this.audioEngine,
    this.onVolumeChanged,
    this.onPanChanged,
    this.onMuteToggle,
    this.onSoloToggle,
    this.onTap,
    this.onDeletePressed,
    this.onDuplicatePressed,
    this.isSelected = false,
    this.instrumentData,
    this.onInstrumentSelect,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap, // Track selection on left-click
      onSecondaryTapDown: (TapDownDetails details) {
        _showContextMenu(context, details.globalPosition);
      },
      child: Container(
        width: 380,
        height: 100, // Matches timeline track row height
        margin: const EdgeInsets.only(bottom: 4), // Match timeline track spacing
        decoration: BoxDecoration(
          // Ableton-style selection: brighter background and thicker border when selected
          color: isSelected ? const Color(0xFF505050) : null,
          border: Border.all(
            color: isSelected ? (trackColor ?? const Color(0xFF4CAF50)) : const Color(0xFF909090),
            width: isSelected ? 3 : 1,
          ),
        ),
        child: Row(
        children: [
          // Left section: Colored track name area (Ableton style)
          Container(
            width: 120,
            color: trackColor ?? const Color(0xFFA0A0A0),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: _buildTrackNameSection(),
          ),

          // Right section: Controls area (light grey)
          Expanded(
            child: Container(
              color: const Color(0xFFA8A8A8), // Medium grey like Ableton
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  // M, S, R buttons
                  _buildControlButtons(),

                  const SizedBox(width: 12),

                  // Horizontal volume slider
                  Expanded(
                    child: _buildHorizontalVolumeSlider(),
                  ),

                  const SizedBox(width: 12),

                  // Center-split pan slider
                  _buildPanSlider(),
                ],
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context, Offset position) {
    // Don't show context menu for master track
    if (trackType.toLowerCase() == 'master') {
      return;
    }

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: [
        const PopupMenuItem<String>(
          value: 'duplicate',
          child: Row(
            children: [
              Icon(Icons.content_copy, size: 16, color: Color(0xFF202020)),
              SizedBox(width: 8),
              Text('Duplicate', style: TextStyle(color: Color(0xFF202020))),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete, size: 16, color: Color(0xFFFF5722)),
              SizedBox(width: 8),
              Text('Delete', style: TextStyle(color: Color(0xFFFF5722))),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'duplicate' && onDuplicatePressed != null) {
        onDuplicatePressed!();
      } else if (value == 'delete' && onDeletePressed != null) {
        onDeletePressed!();
      }
    });
  }

  Widget _buildTrackNameSection() {
    final isMidiTrack = trackType.toLowerCase() == 'midi';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Track name row
        Row(
          children: [
            Text(
              _getTrackEmoji(),
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                trackName,
                style: const TextStyle(
                  color: Colors.black, // Black text on colored background
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),

        // Instrument selector for MIDI tracks
        if (isMidiTrack) ...[
          const SizedBox(height: 4),
          _buildInstrumentSelector(),
        ],
      ],
    );
  }

  Widget _buildInstrumentSelector() {
    return Builder(
      builder: (context) => GestureDetector(
        onTap: onInstrumentSelect != null
            ? () async {
                // Open instrument browser
                final selectedInstrument = await showInstrumentBrowser(context);
                if (selectedInstrument != null) {
                  onInstrumentSelect?.call(selectedInstrument.id);
                }
              }
            : null,
        child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.15), // Subtle dark overlay
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: Colors.black.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              instrumentData != null
                  ? Icons.music_note
                  : Icons.add_circle_outline,
              size: 10,
              color: instrumentData != null
                  ? Colors.black
                  : Colors.black.withOpacity(0.5),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                instrumentData != null
                    ? instrumentData!.type.toUpperCase()
                    : 'No Instrument',
                style: TextStyle(
                  color: instrumentData != null
                      ? Colors.black
                      : Colors.black.withOpacity(0.6),
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildControlButtons() {
    return Row(
      children: [
        // Mute button
        _buildControlButton('M', isMuted, const Color(0xFFFF5722), onMuteToggle),
        const SizedBox(width: 4),
        // Solo button
        _buildControlButton('S', isSoloed, const Color(0xFFFFC107), onSoloToggle),
        const SizedBox(width: 4),
        // Record button (placeholder - not wired up yet)
        _buildControlButton('R', false, const Color(0xFFFF5722), null),
      ],
    );
  }

  Widget _buildControlButton(String label, bool isActive, Color activeColor, VoidCallback? onPressed) {
    return SizedBox(
      width: 22,
      height: 22,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isActive ? activeColor : const Color(0xFFD0D0D0), // Light grey when inactive
          foregroundColor: isActive
              ? (label == 'S' ? Colors.black : Colors.white)
              : Colors.black, // Black text when inactive
          padding: EdgeInsets.zero,
          minimumSize: const Size(22, 22),
          textStyle: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        child: Text(label),
      ),
    );
  }

  Widget _buildHorizontalVolumeSlider() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // dB label
        Text(
          '${volumeDb.toStringAsFixed(1)} dB',
          style: const TextStyle(
            color: Colors.black, // Black text on light background
            fontSize: 9,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        // Horizontal slider
        SizedBox(
          height: 40,
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 8,
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 8,
              ),
              overlayShape: const RoundSliderOverlayShape(
                overlayRadius: 14,
              ),
              activeTrackColor: const Color(0xFF4CAF50), // Green active
              inactiveTrackColor: const Color(0xFF909090), // Medium grey inactive
              thumbColor: const Color(0xFF4CAF50),
            ),
            child: Slider(
              value: _volumeDbToSlider(volumeDb),
              min: 0.0,
              max: 1.0,
              onChanged: onVolumeChanged != null
                  ? (value) {
                      final volumeDb = _sliderToVolumeDb(value);
                      onVolumeChanged!(volumeDb);
                    }
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPanSlider() {
    return SizedBox(
      width: 70,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Pan label
          Text(
            _panToLabel(pan),
            style: const TextStyle(
              color: Colors.black, // Black text on light background
              fontSize: 9,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          // Center-split pan slider
          SizedBox(
            height: 40,
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 6,
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 6,
                ),
                overlayShape: const RoundSliderOverlayShape(
                  overlayRadius: 12,
                ),
                activeTrackColor: const Color(0xFF2196F3), // Blue
                inactiveTrackColor: const Color(0xFF909090), // Medium grey
                thumbColor: const Color(0xFF2196F3),
              ),
              child: Slider(
                value: pan,
                min: -1.0,
                max: 1.0,
                onChanged: onPanChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getTrackEmoji() {
    final lowerName = trackName.toLowerCase();
    final lowerType = trackType.toLowerCase();

    if (lowerType == 'master') return '🎚️';
    if (lowerName.contains('guitar')) return '🎸';
    if (lowerName.contains('piano') || lowerName.contains('keys')) return '🎹';
    if (lowerName.contains('drum')) return '🥁';
    if (lowerName.contains('vocal') || lowerName.contains('voice')) return '🎤';
    if (lowerName.contains('bass')) return '🎸';
    if (lowerName.contains('synth')) return '🎹';
    if (lowerType == 'midi') return '🎼';
    if (lowerType == 'audio') return '🔊';

    return '🎵'; // Default
  }

  // Helper functions for volume conversion
  double _volumeDbToSlider(double volumeDb) {
    // Convert dB (-60 to +6) to slider (0 to 1)
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

/// Master track strip - special styling for master track
class MasterTrackMixerStrip extends StatelessWidget {
  final double volumeDb;
  final double pan;
  final double peakLevel;
  final Function(double)? onVolumeChanged;
  final Function(double)? onPanChanged;

  const MasterTrackMixerStrip({
    super.key,
    required this.volumeDb,
    required this.pan,
    this.peakLevel = 0.0,
    this.onVolumeChanged,
    this.onPanChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 380,
      height: 100,
      margin: const EdgeInsets.only(bottom: 4), // Match timeline track spacing
      decoration: const BoxDecoration(
        color: Color(0xFFA8A8A8), // Light grey like other tracks
        border: Border(
          left: BorderSide(color: Color(0xFF4CAF50), width: 4),
          top: BorderSide(color: Color(0xFF4CAF50), width: 2),
          right: BorderSide(color: Color(0xFF4CAF50), width: 2),
          bottom: BorderSide(color: Color(0xFF4CAF50), width: 2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            // Master label
            const SizedBox(
              width: 90,
              child: Row(
                children: [
                  Text('🎚️', style: TextStyle(fontSize: 16)),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'MASTER',
                      style: TextStyle(
                        color: Colors.black, // Black text on light background
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Limiter indicator (where M/S/R buttons would be)
            Container(
              width: 74,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFD0D0D0), // Light grey
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFF4CAF50)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
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

            const SizedBox(width: 12),

            // Horizontal volume slider
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // dB label
                  Text(
                    '${volumeDb.toStringAsFixed(1)} dB',
                    style: const TextStyle(
                      color: Colors.black, // Black text on light background
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  // Horizontal slider
                  SizedBox(
                    height: 40,
                    child: SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 8,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 8,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 14,
                        ),
                        activeTrackColor: const Color(0xFF4CAF50),
                        inactiveTrackColor: const Color(0xFF909090), // Medium grey
                        thumbColor: const Color(0xFF4CAF50),
                      ),
                      child: Slider(
                        value: _volumeDbToSlider(volumeDb),
                        min: 0.0,
                        max: 1.0,
                        onChanged: onVolumeChanged != null
                            ? (value) {
                                final volumeDb = _sliderToVolumeDb(value);
                                onVolumeChanged!(volumeDb);
                              }
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // Center-split pan slider
            SizedBox(
              width: 70,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Pan label
                  Text(
                    _panToLabel(pan),
                    style: const TextStyle(
                      color: Colors.black, // Black text on light background
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Pan slider
                  SizedBox(
                    height: 40,
                    child: SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 6,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 6,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 12,
                        ),
                        activeTrackColor: const Color(0xFF4CAF50),
                        inactiveTrackColor: const Color(0xFF909090), // Medium grey
                        thumbColor: const Color(0xFF4CAF50),
                      ),
                      child: Slider(
                        value: pan,
                        min: -1.0,
                        max: 1.0,
                        onChanged: onPanChanged,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _volumeDbToSlider(double volumeDb) {
    return (volumeDb + 60.0) / 66.0;
  }

  double _sliderToVolumeDb(double slider) {
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
