import 'package:flutter/material.dart';
import '../audio_engine.dart';
import 'instrument_browser.dart';
import '../models/instrument_data.dart';
import '../models/vst3_plugin_data.dart';
import 'pan_knob.dart';
import 'horizontal_level_meter.dart';

/// Unified track strip combining track info and mixer controls
/// Displayed on the right side of timeline, aligned with each track row
class TrackMixerStrip extends StatefulWidget {
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
  final VoidCallback? onArmToggle; // Toggle recording arm
  final VoidCallback? onTap; // Unified track selection callback
  final VoidCallback? onDeletePressed;
  final VoidCallback? onDuplicatePressed;
  final Function(String)? onNameChanged; // Inline rename callback
  final bool isSelected; // Track selection state
  final bool isArmed; // Recording arm state

  // MIDI instrument selection
  final InstrumentData? instrumentData;
  final Function(String)? onInstrumentSelect; // Callback with instrument ID

  // M10: VST3 Plugin support
  final int vst3PluginCount;
  final VoidCallback? onFxButtonPressed;
  final Function(Vst3Plugin)? onVst3PluginDropped;
  final VoidCallback? onEditPluginsPressed; // New: Edit active plugins

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
    this.onArmToggle,
    this.onTap,
    this.onDeletePressed,
    this.onDuplicatePressed,
    this.onNameChanged,
    this.isSelected = false,
    this.isArmed = false,
    this.instrumentData,
    this.onInstrumentSelect,
    this.vst3PluginCount = 0,
    this.onFxButtonPressed,
    this.onVst3PluginDropped,
    this.onEditPluginsPressed,
  });

  @override
  State<TrackMixerStrip> createState() => _TrackMixerStripState();
}

class _TrackMixerStripState extends State<TrackMixerStrip> {
  bool _isEditing = false;
  late TextEditingController _nameController;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.trackName);
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(TrackMixerStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trackName != widget.trackName && !_isEditing) {
      _nameController.text = widget.trackName;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus && _isEditing) {
      _submitName();
    }
  }

  void _startEditing() {
    setState(() {
      _isEditing = true;
      _nameController.text = widget.trackName;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      _nameController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _nameController.text.length,
      );
    });
  }

  void _submitName() {
    final newName = _nameController.text.trim();
    setState(() {
      _isEditing = false;
    });
    if (newName.isNotEmpty && newName != widget.trackName) {
      widget.onNameChanged?.call(newName);
    }
  }

  void _cancelEditing() {
    setState(() {
      _isEditing = false;
      _nameController.text = widget.trackName;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DragTarget<Vst3Plugin>(
      onAcceptWithDetails: (details) {
        widget.onVst3PluginDropped?.call(details.data);
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;

        return GestureDetector(
          onTap: widget.onTap, // Track selection on left-click
          onSecondaryTapDown: (TapDownDetails details) {
            _showContextMenu(context, details.globalPosition);
          },
          child: Container(
            width: 380,
            height: 100, // Matches timeline track row height
            margin: const EdgeInsets.only(bottom: 4), // Match timeline track spacing
            decoration: BoxDecoration(
              // Ableton-style selection: brighter background and thicker border when selected
              // M10: Highlight when VST3 plugin is being dragged over
              color: isHovered
                  ? const Color(0xFF00BCD4).withValues(alpha: 0.2)
                  : (widget.isSelected ? const Color(0xFF363636) : const Color(0xFF242424)),
              border: Border.all(
                color: isHovered
                    ? const Color(0xFF00BCD4)
                    : (widget.isSelected ? (widget.trackColor ?? const Color(0xFF00BCD4)) : const Color(0xFF363636)),
                width: isHovered ? 2 : (widget.isSelected ? 3 : 1),
              ),
            ),
        child: Row(
        children: [
          // Left section: Colored track name area (Ableton style)
          Container(
            width: 120,
            color: widget.trackColor ?? const Color(0xFF363636),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: _buildTrackNameSection(),
          ),

          // Right section: Controls area (dark grey)
          Expanded(
            child: Container(
              color: const Color(0xFF363636), // Dark grey
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  // M, S, R buttons
                  _buildControlButtons(),

                  const SizedBox(width: 12),

                  // Horizontal level meter with volume slider overlaid
                  Expanded(
                    child: HorizontalLevelMeter(
                      leftLevel: widget.peakLevel,
                      rightLevel: widget.peakLevel, // TODO: Add stereo levels from engine
                      volumeDb: widget.volumeDb,
                      onVolumeChanged: widget.onVolumeChanged,
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Rotary pan knob (Ableton-style)
                  PanKnob(
                    pan: widget.pan,
                    onChanged: widget.onPanChanged,
                    size: 36,
                  ),
                ],
              ),
            ),
          ),
            ],
          ),
        ),
      );
      },
    );
  }

  void _showContextMenu(BuildContext context, Offset position) {
    // Don't show context menu for master track
    if (widget.trackType.toLowerCase() == 'master') {
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
          value: 'rename',
          child: Row(
            children: [
              Icon(Icons.edit, size: 16, color: Color(0xFFE0E0E0)),
              SizedBox(width: 8),
              Text('Rename', style: TextStyle(color: Color(0xFFE0E0E0))),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'duplicate',
          child: Row(
            children: [
              Icon(Icons.content_copy, size: 16, color: Color(0xFFE0E0E0)),
              SizedBox(width: 8),
              Text('Duplicate', style: TextStyle(color: Color(0xFFE0E0E0))),
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
      if (value == 'rename') {
        _startEditing();
      } else if (value == 'duplicate' && widget.onDuplicatePressed != null) {
        widget.onDuplicatePressed!();
      } else if (value == 'delete' && widget.onDeletePressed != null) {
        widget.onDeletePressed!();
      }
    });
  }

  Widget _buildTrackNameSection() {
    final isMidiTrack = widget.trackType.toLowerCase() == 'midi';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Track name row - editable on double-click
        Row(
          children: [
            Text(
              _getTrackEmoji(),
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _isEditing
                  ? TextField(
                      controller: _nameController,
                      focusNode: _focusNode,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        border: OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.black),
                        ),
                      ),
                      onSubmitted: (_) => _submitName(),
                    )
                  : GestureDetector(
                      onDoubleTap: _startEditing,
                      child: Text(
                        widget.trackName,
                        style: const TextStyle(
                          color: Colors.black, // Black text on colored background
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
            ),
          ],
        ),

        // Instrument selector for MIDI tracks
        if (isMidiTrack) ...[
          const SizedBox(height: 4),
          _buildInstrumentSelector(),
        ],

        // M10: VST3 FX button (all tracks)
        const SizedBox(height: 4),
        _buildFxButton(),
      ],
    );
  }

  Widget _buildInstrumentSelector() {
    return Builder(
      builder: (context) => GestureDetector(
        onTap: widget.onInstrumentSelect != null
            ? () async {
                // Open instrument browser
                final selectedInstrument = await showInstrumentBrowser(context);
                if (selectedInstrument != null) {
                  widget.onInstrumentSelect?.call(selectedInstrument.id);
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
              widget.instrumentData != null
                  ? Icons.music_note
                  : Icons.add_circle_outline,
              size: 10,
              color: widget.instrumentData != null
                  ? Colors.black
                  : Colors.black.withOpacity(0.5),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                widget.instrumentData != null
                    ? widget.instrumentData!.type.toUpperCase()
                    : 'No Instrument',
                style: TextStyle(
                  color: widget.instrumentData != null
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

  Widget _buildFxButton() {
    return GestureDetector(
      onLongPress: widget.vst3PluginCount > 0 ? widget.onEditPluginsPressed : null,
      onTap: widget.onFxButtonPressed,
      child: Tooltip(
        message: widget.vst3PluginCount > 0
            ? 'Click to browse plugins, long-press to edit'
            : 'Click to add plugins',
        child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: widget.vst3PluginCount > 0
              ? const Color(0xFF4CAF50).withOpacity(0.3) // Green tint when plugins loaded
              : Colors.black.withOpacity(0.15),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: widget.vst3PluginCount > 0
                ? const Color(0xFF4CAF50)
                : Colors.black.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              widget.vst3PluginCount > 0 ? Icons.extension : Icons.add_circle_outline,
              size: 10,
              color: widget.vst3PluginCount > 0
                  ? const Color(0xFF4CAF50)
                  : Colors.black.withOpacity(0.5),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                widget.vst3PluginCount > 0
                    ? 'FX (${widget.vst3PluginCount})'
                    : 'Add FX',
                style: TextStyle(
                  color: widget.vst3PluginCount > 0
                      ? const Color(0xFF4CAF50)
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
    // Show arm button only for Audio and MIDI tracks (not master, return, group)
    final canArm = widget.trackType.toLowerCase() == 'audio' || widget.trackType.toLowerCase() == 'midi';

    return Row(
      children: [
        // Mute button
        _buildControlButton('M', widget.isMuted, const Color(0xFFFF5722), widget.onMuteToggle),
        const SizedBox(width: 4),
        // Solo button
        _buildControlButton('S', widget.isSoloed, const Color(0xFFFFC107), widget.onSoloToggle),
        const SizedBox(width: 4),
        // Record arm button (only for audio/midi tracks)
        _buildControlButton(
          'R',
          widget.isArmed,
          const Color(0xFFFF0000), // Bright red when armed
          canArm ? widget.onArmToggle : null,
        ),
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
          backgroundColor: isActive ? activeColor : const Color(0xFF3a3a3a), // Dark grey when inactive
          foregroundColor: isActive
              ? (label == 'S' ? Colors.black : Colors.white)
              : const Color(0xFF9E9E9E), // Grey text when inactive
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

  String _getTrackEmoji() {
    final lowerName = widget.trackName.toLowerCase();
    final lowerType = widget.trackType.toLowerCase();

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
        color: Color(0xFF242424), // Dark grey like other tracks
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
                        color: Color(0xFFE0E0E0), // Light text on dark background
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
                color: const Color(0xFF363636), // Dark grey
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

            // Horizontal level meter with volume slider overlaid
            Expanded(
              child: HorizontalLevelMeter(
                leftLevel: peakLevel,
                rightLevel: peakLevel,
                volumeDb: volumeDb,
                onVolumeChanged: onVolumeChanged,
              ),
            ),

            const SizedBox(width: 12),

            // Rotary pan knob (Ableton-style)
            PanKnob(
              pan: pan,
              onChanged: onPanChanged,
              size: 36,
            ),
          ],
        ),
      ),
    );
  }
}
