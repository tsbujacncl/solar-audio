import 'package:flutter/material.dart';

/// Orientation of the resizable divider
enum DividerOrientation {
  vertical,   // Left-right resize (vertical line)
  horizontal, // Up-down resize (horizontal line)
}

/// A draggable divider that allows resizing panels
///
/// Features:
/// - Drag to resize
/// - Double-click to collapse/expand
/// - Hover highlight for discoverability
/// - Custom cursor on hover
class ResizableDivider extends StatefulWidget {
  final DividerOrientation orientation;
  final Function(double delta) onDrag;
  final VoidCallback onDoubleClick;
  final bool isCollapsed;

  const ResizableDivider({
    super.key,
    required this.orientation,
    required this.onDrag,
    required this.onDoubleClick,
    this.isCollapsed = false,
  });

  @override
  State<ResizableDivider> createState() => _ResizableDividerState();
}

class _ResizableDividerState extends State<ResizableDivider> {
  bool _isHovered = false;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final isVertical = widget.orientation == DividerOrientation.vertical;

    return MouseRegion(
      cursor: isVertical
        ? SystemMouseCursors.resizeColumn
        : SystemMouseCursors.resizeRow,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onPanUpdate: (details) {
          if (!widget.isCollapsed) {
            setState(() => _isDragging = true);
            final delta = isVertical ? details.delta.dx : details.delta.dy;
            widget.onDrag(delta);
          }
        },
        onPanEnd: (_) => setState(() => _isDragging = false),
        onDoubleTap: widget.onDoubleClick,
        child: Container(
          width: isVertical ? (_isHovered || _isDragging ? 3 : 1) : double.infinity,
          height: isVertical ? double.infinity : (_isHovered || _isDragging ? 3 : 1),
          color: _isDragging
              ? const Color(0xFF4CAF50) // Green when dragging
              : _isHovered
                  ? const Color(0xFFAAAAAA) // Bright grey on hover
                  : const Color(0xFF909090), // Subtle grey default
        ),
      ),
    );
  }
}
