import 'package:flutter/material.dart';
import '../audio_engine.dart';
import 'virtual_piano.dart';
import 'effect_parameter_panel.dart';

/// Bottom panel widget - tabbed interface for Piano Roll, FX Chain, and Virtual Piano
class BottomPanel extends StatefulWidget {
  final AudioEngine? audioEngine;
  final bool virtualPianoEnabled;
  final int? selectedTrackForFX;
  final VoidCallback? onVirtualPianoClose;

  const BottomPanel({
    super.key,
    this.audioEngine,
    this.virtualPianoEnabled = false,
    this.selectedTrackForFX,
    this.onVirtualPianoClose,
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

    // Auto-switch to Virtual Piano tab when enabled
    if (widget.virtualPianoEnabled) {
      _tabController.index = 2;
    }
  }

  @override
  void didUpdateWidget(BottomPanel oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Auto-switch to Virtual Piano tab when enabled
    if (widget.virtualPianoEnabled && !oldWidget.virtualPianoEnabled) {
      _tabController.index = 2;
    }

    // Auto-switch to FX Chain tab when track selected
    if (widget.selectedTrackForFX != null && oldWidget.selectedTrackForFX == null) {
      _tabController.index = 1;
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
              labelColor: const Color(0xFFA0A0A0),
              unselectedLabelColor: const Color(0xFF606060),
              labelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              tabs: const [
                Tab(text: 'Piano Roll'),
                Tab(text: 'FX Chain'),
                Tab(text: 'Virtual Piano'),
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
                _buildVirtualPianoTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPianoRollTab() {
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
              'Coming in M6',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(horizontal: 32),
              decoration: BoxDecoration(
                color: const Color(0xFF656565),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF909090)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.info_outline, size: 16, color: Color(0xFF202020)),
                      SizedBox(width: 8),
                      Text(
                        'MIDI Editing Features',
                        style: TextStyle(
                          color: Color(0xFF202020),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildFeatureItem('• Draw, edit, and resize MIDI notes'),
                  _buildFeatureItem('• Velocity lane for dynamics'),
                  _buildFeatureItem('• Grid snap and quantization'),
                  _buildFeatureItem('• Multi-note selection and editing'),
                ],
              ),
            ),
          ],
        ),
      ),
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

  Widget _buildVirtualPianoTab() {
    if (!widget.virtualPianoEnabled) {
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
                'Virtual Piano',
                style: TextStyle(
                  color: Color(0xFF202020),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Click the piano button in the transport bar to enable',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: widget.onVirtualPianoClose, // This will toggle it on
                icon: const Icon(Icons.piano, size: 18),
                label: const Text('Enable Virtual Piano'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Show virtual piano when enabled
    return VirtualPiano(
      audioEngine: widget.audioEngine,
      isEnabled: widget.virtualPianoEnabled,
      onClose: widget.onVirtualPianoClose,
    );
  }
}
