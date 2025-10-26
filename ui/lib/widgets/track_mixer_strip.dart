import 'package:flutter/material.dart';
import '../audio_engine.dart';

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
  final VoidCallback? onFXPressed;
  final VoidCallback? onDeletePressed;
  final bool isFXActive;

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
    this.onFXPressed,
    this.onDeletePressed,
    this.isFXActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 380,
      height: 100, // Matches timeline track row height
      margin: const EdgeInsets.only(bottom: 4), // Match timeline track spacing
      decoration: BoxDecoration(
        color: const Color(0xFF707070),
        border: Border(
          left: BorderSide(
            color: trackColor ?? const Color(0xFF909090),
            width: trackColor != null ? 4 : 1,
          ),
          top: const BorderSide(color: Color(0xFF909090)),
          right: const BorderSide(color: Color(0xFF909090)),
          bottom: const BorderSide(color: Color(0xFF909090)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            // Track emoji + name
            _buildTrackNameSection(),

            const SizedBox(width: 8),

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
    );
  }

  Widget _buildTrackNameSection() {
    return SizedBox(
      width: 90,
      child: Row(
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
                color: Color(0xFF202020),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
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
          backgroundColor: isActive ? activeColor : const Color(0xFF909090),
          foregroundColor: isActive
              ? (label == 'S' ? Colors.black : Colors.white)
              : const Color(0xFF404040),
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
            color: Color(0xFF404040),
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
              inactiveTrackColor: const Color(0xFF606060),
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
              color: Color(0xFF404040),
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
                activeTrackColor: const Color(0xFF2196F3),
                inactiveTrackColor: const Color(0xFF606060),
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
        color: Color(0xFF606060),
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
                        color: Color(0xFF4CAF50),
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
                color: const Color(0xFF707070),
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
                      color: Color(0xFF4CAF50),
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
                        inactiveTrackColor: const Color(0xFF505050),
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
                      color: Color(0xFF4CAF50),
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
                        inactiveTrackColor: const Color(0xFF505050),
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
