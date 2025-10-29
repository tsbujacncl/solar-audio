import 'package:flutter/material.dart';

/// Track color utilities for assigning colors to tracks
class TrackColors {
  /// Available track colors (Ableton-style pastels)
  static const List<Color> palette = [
    Color(0xFF7DB3D9), // Light blue (Ableton Track 4)
    Color(0xFFE87368), // Coral red (Ableton Track 5)
    Color(0xFF8B7355), // Brown/tan (Ableton Track 6)
    Color(0xFFE89EB3), // Pink (Ableton Track 7)
    Color(0xFF7FA894), // Sage green
    Color(0xFFD4A574), // Light gold/amber
    Color(0xFF9B8DC4), // Light purple/lavender
    Color(0xFFB8A890), // Beige/tan
  ];

  /// Master track color
  static const Color masterColor = Color(0xFF4CAF50); // Green

  /// Get color for a track by index (cycles through palette)
  static Color getTrackColor(int trackIndex, {bool isMaster = false}) {
    if (isMaster) return masterColor;
    return palette[trackIndex % palette.length];
  }

  /// Get formatted track name with type and number
  /// Examples: "Audio 1 - Drums", "MIDI 2 - Bass", "Master"
  static String getFormattedTrackName({
    required String trackType,
    required String trackName,
    required int audioCount,
    required int midiCount,
  }) {
    final lowerType = trackType.toLowerCase();

    if (lowerType == 'master') {
      return trackName; // Just "Master", no number
    } else if (lowerType == 'audio') {
      return 'Audio $audioCount - $trackName';
    } else if (lowerType == 'midi') {
      return 'MIDI $midiCount - $trackName';
    } else {
      return trackName; // Fallback
    }
  }

  /// Get track emoji based on name or type
  static String getTrackEmoji(String trackName, String trackType) {
    final lowerName = trackName.toLowerCase();
    final lowerType = trackType.toLowerCase();

    if (lowerType == 'master') return '🎚️';
    if (lowerName.contains('guitar')) return '🎸';
    if (lowerName.contains('piano') || lowerName.contains('keys')) return '🎹';
    if (lowerName.contains('drum')) return '🥁';
    if (lowerName.contains('vocal') || lowerName.contains('voice')) return '🎤';
    if (lowerName.contains('bass')) return '🎸';
    if (lowerName.contains('synth')) return '🎹';
    if (lowerName.contains('pluck')) return '🎸';
    if (lowerType == 'midi') return '🎼';
    if (lowerType == 'audio') return '🔊';

    return '🎵'; // Default
  }
}
