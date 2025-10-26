import 'package:flutter/material.dart';

/// Library panel widget - left sidebar with browsable content categories
class LibraryPanel extends StatefulWidget {
  final bool isCollapsed;
  final VoidCallback? onToggle;

  const LibraryPanel({
    super.key,
    this.isCollapsed = false,
    this.onToggle,
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
                _buildCategory(
                  index: 3,
                  icon: Icons.extension,
                  title: 'Plug-Ins',
                  items: [
                    'No VST3 plugins found',
                  ],
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
                children: items.map((item) => _buildItem(item)).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildItem(String name) {
    return InkWell(
      onTap: () {
        // TODO: Handle item selection (future: drag to timeline)
        debugPrint('📚 Library item tapped: $name');
      },
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
}
