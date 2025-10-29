import 'package:flutter/material.dart';
import '../audio_engine.dart';
import 'virtual_piano.dart';
import 'effect_parameter_panel.dart';
import 'piano_roll.dart';
import 'synthesizer_panel.dart';
import '../models/midi_note_data.dart';
import '../models/instrument_data.dart';

/// Bottom panel widget - tabbed interface for Piano Roll, FX Chain, Instrument, and Virtual Piano
class BottomPanel extends StatefulWidget {
  final AudioEngine? audioEngine;
  final bool virtualPianoEnabled;
  final int? selectedTrackForFX;
  final int? selectedTrackForInstrument;
  final InstrumentData? currentInstrumentData;
  final VoidCallback? onVirtualPianoClose;
  final MidiClipData? currentEditingClip;
  final int? selectedMidiTrackId;
  final Function(MidiClipData)? onMidiClipUpdated;
  final Function(InstrumentData)? onInstrumentParameterChanged;

  const BottomPanel({
    super.key,
    this.audioEngine,
    this.virtualPianoEnabled = false,
    this.selectedTrackForFX,
    this.selectedTrackForInstrument,
    this.currentInstrumentData,
    this.onVirtualPianoClose,
    this.currentEditingClip,
    this.selectedMidiTrackId,
    this.onMidiClipUpdated,
    this.onInstrumentParameterChanged,
  });

  @override
  State<BottomPanel> createState() => _BottomPanelState();
}

class _BottomPanelState extends State<BottomPanel> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void didUpdateWidget(BottomPanel oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Auto-switch to Instrument tab when track with instrument selected
    if (widget.selectedTrackForInstrument != null &&
        oldWidget.selectedTrackForInstrument == null) {
      _tabController.index = 2; // Instrument is 3rd tab
    }

    // Auto-switch to FX Chain tab when track selected
    if (widget.selectedTrackForFX != null && oldWidget.selectedTrackForFX == null) {
      _tabController.index = 1;
    }

    // Auto-switch to Piano Roll tab when MIDI track or clip selected
    if ((widget.selectedMidiTrackId != null && oldWidget.selectedMidiTrackId == null) ||
        (widget.currentEditingClip != null && oldWidget.currentEditingClip == null)) {
      _tabController.index = 0; // Piano Roll is first tab
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 250,
      decoration: const BoxDecoration(
        color: Color(0xFF707070),
        border: Border(
          top: BorderSide(color: Color(0xFF909090)),
        ),
      ),
      child: Column(
        children: [
          // Tab bar
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF656565),
              border: Border(
                bottom: BorderSide(color: Color(0xFF909090)),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFF4CAF50),
              labelColor: const Color(0xFF202020),
              unselectedLabelColor: const Color(0xFF505050),
              labelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              tabs: const [
                Tab(text: 'Piano Roll'),
                Tab(text: 'FX Chain'),
                Tab(text: 'Instrument'),
              ],
            ),
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPianoRollTab(),
                _buildFXChainTab(),
                _buildInstrumentTab(),
              ],
            ),
          ),

          // Virtual Piano (below tabs, always visible when enabled)
          if (widget.virtualPianoEnabled)
            VirtualPiano(
              audioEngine: widget.audioEngine,
              isEnabled: widget.virtualPianoEnabled,
              onClose: widget.onVirtualPianoClose,
              selectedTrackId: widget.selectedMidiTrackId,
            ),
        ],
      ),
    );
  }

  Widget _buildPianoRollTab() {
    // Use real clip data if available, otherwise create an empty clip for the selected track
    final clipData = widget.currentEditingClip ?? (widget.selectedMidiTrackId != null
      ? MidiClipData(
          clipId: -1, // -1 indicates a new, unsaved clip
          trackId: widget.selectedMidiTrackId!,
          startTime: 0.0,
          duration: 16.0,
          name: 'New MIDI Clip',
          notes: [],
        )
      : null);

    if (clipData == null) {
      // No track selected - show empty state
      return Container(
        color: const Color(0xFF707070),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.piano_outlined,
                size: 64,
                color: Color(0xFF909090),
              ),
              const SizedBox(height: 16),
              const Text(
                'Piano Roll',
                style: TextStyle(
                  color: Color(0xFF202020),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select a MIDI track or clip to start editing',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return PianoRoll(
      audioEngine: widget.audioEngine,
      clipData: clipData,
      onClipUpdated: widget.onMidiClipUpdated,
      onClose: () {
        // Switch back to another tab or close bottom panel
        _tabController.index = 3; // Switch to Virtual Piano tab
      },
    );
  }

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF606060),
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildFXChainTab() {
    if (widget.selectedTrackForFX == null) {
      return Container(
        color: const Color(0xFF707070),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.graphic_eq,
                size: 64,
                color: Color(0xFF909090),
              ),
              const SizedBox(height: 16),
              const Text(
                'FX Chain',
                style: TextStyle(
                  color: Color(0xFF202020),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select a track and click FX to edit effects',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Show effect parameter panel when track selected
    return EffectParameterPanel(
      audioEngine: widget.audioEngine,
      trackId: widget.selectedTrackForFX!,
      onClose: () {
        // Don't close the panel, just show empty state
        // Parent widget handles clearing selectedTrackForFX
      },
    );
  }

  Widget _buildInstrumentTab() {
    if (widget.selectedTrackForInstrument == null || widget.currentInstrumentData == null) {
      return Container(
        color: const Color(0xFF707070),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.piano,
                size: 64,
                color: Color(0xFF909090),
              ),
              const SizedBox(height: 16),
              const Text(
                'Instrument',
                style: TextStyle(
                  color: Color(0xFF202020),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select a track with an instrument to edit',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Show synthesizer panel when track with instrument selected
    return SynthesizerPanel(
      audioEngine: widget.audioEngine,
      trackId: widget.selectedTrackForInstrument!,
      instrumentData: widget.currentInstrumentData,
      onParameterChanged: (instrumentData) {
        widget.onInstrumentParameterChanged?.call(instrumentData);
      },
      onClose: () {
        // Parent widget handles clearing selectedTrackForInstrument
      },
    );
  }

}
