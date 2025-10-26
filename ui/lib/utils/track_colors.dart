import 'package:flutter/material.dart';

/// Track color utilities for assigning colors to tracks
class TrackColors {
  /// Available track colors (cycling palette)
  static const List<Color> palette = [
    Color(0xFFE91E63), // Pink/Magenta
    Color(0xFF2196F3), // Blue
    Color(0xFFFF9800), // Orange
    Color(0xFF9C27B0), // Purple
    Color(0xFF00BCD4), // Cyan/Teal
    Color(0xFFFF5722), // Deep Orange
    Color(0xFF4CAF50), // Green
    Color(0xFFFFC107), // Amber/Yellow
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
