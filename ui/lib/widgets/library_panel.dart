import 'package:flutter/material.dart';
import 'instrument_browser.dart';
import '../models/vst3_plugin_data.dart';

/// Library panel widget - left sidebar with browsable content categories
class LibraryPanel extends StatefulWidget {
  final bool isCollapsed;
  final VoidCallback? onToggle;
  final List<Map<String, String>> availableVst3Plugins;

  const LibraryPanel({
    super.key,
    this.isCollapsed = false,
    this.onToggle,
    this.availableVst3Plugins = const [],
  });

  @override
  State<LibraryPanel> createState() => _LibraryPanelState();
}

class _LibraryPanelState extends State<LibraryPanel> {
  int? _expandedCategoryIndex;

  @override
  Widget build(BuildContext context) {
    if (widget.isCollapsed) {
      return Container(
        width: 40,
        decoration: const BoxDecoration(
          color: Color(0xFF707070),
          border: Border(
            right: BorderSide(color: Color(0xFF909090)),
          ),
        ),
        child: Column(
          children: [
            IconButton(
              icon: const Icon(Icons.menu),
              color: const Color(0xFF404040),
              onPressed: widget.onToggle,
              tooltip: 'Show Library (B)',
            ),
          ],
        ),
      );
    }

    return Container(
      width: 200,
      decoration: const BoxDecoration(
        color: Color(0xFF707070),
        border: Border(
          right: BorderSide(color: Color(0xFF909090)),
        ),
      ),
      child: Column(
        children: [
          // Header
          _buildHeader(),

          // Categories list
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildCategory(
                  index: 0,
                  icon: Icons.audiotrack,
                  title: 'Sounds',
                  items: [
                    'Drum Loops',
                    'Bass Loops',
                    'Vocal Samples',
                    'FX & Risers',
                  ],
                ),
                _buildCategory(
                  index: 1,
                  icon: Icons.piano,
                  title: 'Instruments',
                  items: [
                    'Piano',
                    'Synthesizer',
                    'Drums',
                    'Bass',
                    'Sampler',
                  ],
                ),
                _buildCategory(
                  index: 2,
                  icon: Icons.graphic_eq,
                  title: 'Effects',
                  items: [
                    'EQ',
                    'Compressor',
                    'Reverb',
                    'Delay',
                    'Chorus',
                    'Limiter',
                  ],
                ),
                // VST3 Instruments category
                _buildCategory(
                  index: 3,
                  icon: Icons.piano,
                  title: 'VST3 Instruments',
                  items: () {
                    final instruments = widget.availableVst3Plugins
                        .where((plugin) => plugin['is_instrument'] == '1')
                        .map((plugin) => plugin['name'] ?? 'Unknown')
                        .toList();
                    return instruments.isEmpty ? ['No VST3 instruments found'] : instruments;
                  }(),
                  isVst3Category: true,
                  isVst3Instrument: true,
                ),
                // VST3 Effects category
                _buildCategory(
                  index: 4,
                  icon: Icons.graphic_eq,
                  title: 'VST3 Effects',
                  items: () {
                    final effects = widget.availableVst3Plugins
                        .where((plugin) => plugin['is_effect'] == '1')
                        .map((plugin) => plugin['name'] ?? 'Unknown')
                        .toList();
                    return effects.isEmpty ? ['No VST3 effects found'] : effects;
                  }(),
                  isVst3Category: true,
                  isVst3Instrument: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Color(0xFF656565),
        border: Border(
          bottom: BorderSide(color: Color(0xFF909090)),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.library_music,
            color: Color(0xFF202020),
            size: 18,
          ),
          const SizedBox(width: 8),
          const Text(
            'LIBRARY',
            style: TextStyle(
              color: Color(0xFF202020),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const Spacer(),
          if (widget.onToggle != null)
            IconButton(
              icon: const Icon(Icons.chevron_left),
              color: const Color(0xFF404040),
              iconSize: 18,
              onPressed: widget.onToggle,
              tooltip: 'Hide Library (B)',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }

  Widget _buildCategory({
    required int index,
    required IconData icon,
    required String title,
    required List<String> items,
    bool isVst3Category = false,
    bool isVst3Instrument = false,
  }) {
    final isExpanded = _expandedCategoryIndex == index;

    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFF656565)),
        ),
      ),
      child: Column(
        children: [
          // Category header (clickable)
          InkWell(
            onTap: () {
              setState(() {
                _expandedCategoryIndex = isExpanded ? null : index;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 16,
                    color: const Color(0xFF404040),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF202020),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_more : Icons.chevron_right,
                    size: 18,
                    color: const Color(0xFF505050),
                  ),
                ],
              ),
            ),
          ),

          // Category items (expandable)
          if (isExpanded)
            Container(
              padding: const EdgeInsets.only(left: 20, bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: items.map((item) => _buildItem(item, isVst3: isVst3Category, isVst3Instrument: isVst3Instrument)).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildItem(String name, {bool isVst3 = false, bool isVst3Instrument = false}) {
    // Handle VST3 plugins
    if (isVst3 && name != 'No VST3 plugins found' && name != 'No VST3 instruments found' && name != 'No VST3 effects found') {
      final vst3Plugin = _findVst3PluginByName(name);
      if (vst3Plugin != null) {
        return _buildVst3PluginItem(vst3Plugin, isInstrument: isVst3Instrument);
      }
    }

    // Try to find matching instrument for dragging
    final instrument = _findInstrumentByName(name);

    if (instrument != null) {
      // Instrument items are draggable (instant drag, no long press)
      return Draggable<Instrument>(
        data: instrument,
        onDragStarted: () {},
        onDragEnd: (details) {},
        onDraggableCanceled: (velocity, offset) {},
        feedback: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(instrument.icon, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  instrument.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        childWhenDragging: Opacity(
          opacity: 0.5,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            child: Text(
              name,
              style: const TextStyle(
                color: Color(0xFF404040),
                fontSize: 12,
              ),
            ),
          ),
        ),
        child: MouseRegion(
          cursor: SystemMouseCursors.grab,
          child: InkWell(
            onTap: () {},
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              child: Text(
                name,
                style: const TextStyle(
                  color: Color(0xFF404040),
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Non-instrument items are not draggable
    return InkWell(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        child: Text(
          name,
          style: const TextStyle(
            color: Color(0xFF404040),
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  /// Find instrument by name from available instruments
  Instrument? _findInstrumentByName(String name) {
    try {
      return availableInstruments.firstWhere(
        (inst) => inst.name.toLowerCase() == name.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }

  /// Find VST3 plugin by name from available plugins
  Vst3Plugin? _findVst3PluginByName(String name) {
    try {
      final pluginData = widget.availableVst3Plugins.firstWhere(
        (plugin) => plugin['name'] == name,
      );
      return Vst3Plugin.fromMap(pluginData);
    } catch (e) {
      return null;
    }
  }

  /// Build a draggable VST3 plugin item
  Widget _buildVst3PluginItem(Vst3Plugin plugin, {required bool isInstrument}) {
    return Draggable<Vst3Plugin>(
      data: plugin,
      onDragStarted: () {},
      onDragEnd: (details) {},
      onDraggableCanceled: (velocity, offset) {},
      feedback: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF4CAF50),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                plugin.isInstrument ? Icons.piano : Icons.graphic_eq,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                plugin.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.5,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          child: Text(
            plugin.name,
            style: const TextStyle(
              color: Color(0xFF404040),
              fontSize: 12,
            ),
          ),
        ),
      ),
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: InkWell(
          onTap: () {},
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            child: Text(
              plugin.name,
              style: const TextStyle(
                color: Color(0xFF404040),
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
