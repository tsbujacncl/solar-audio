import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import '../models/midi_note_data.dart';
import '../audio_engine.dart';

/// Interaction modes for piano roll
enum InteractionMode { draw, select, move, resize }

/// Piano Roll MIDI editor widget
class PianoRoll extends StatefulWidget {
  final AudioEngine? audioEngine;
  final MidiClipData? clipData;
  final VoidCallback? onClose;
  final Function(MidiClipData)? onClipUpdated;

  const PianoRoll({
    super.key,
    this.audioEngine,
    this.clipData,
    this.onClose,
    this.onClipUpdated,
  });

  @override
  State<PianoRoll> createState() => _PianoRollState();
}

class _PianoRollState extends State<PianoRoll> {
  // Zoom levels
  double _pixelsPerBeat = 80.0; // Horizontal zoom
  double _pixelsPerNote = 16.0; // Vertical zoom (height of each piano key)

  // Scroll controllers
  final ScrollController _horizontalScroll = ScrollController();
  final ScrollController _verticalScroll = ScrollController();

  // Grid settings
  double _gridDivision = 0.25; // 1/16th note (quarter / 4)
  bool _snapEnabled = true;

  // View range (88 piano keys: A0 = 21 to C8 = 108)
  static const int _minMidiNote = 0;
  static const int _maxMidiNote = 127;
  static const int _defaultViewStartNote = 36; // C2
  static const int _defaultViewEndNote = 84;   // C6 (4 octaves)

  // Clip state
  MidiClipData? _currentClip;

  // UI state
  bool _isDrawingNote = false;
  MidiNoteData? _previewNote;
  Offset? _dragStart;

  // Interaction mode
  InteractionMode _currentMode = InteractionMode.draw;

  // Selection state
  MidiNoteData? _hoveredNote;
  bool _isResizing = false;
  String? _resizingNoteId;

  // Multi-select state
  bool _isSelecting = false;
  Offset? _selectionStart;
  Offset? _selectionEnd;

  // Undo/redo history
  List<MidiClipData> _undoHistory = [];
  List<MidiClipData> _redoHistory = [];
  static const int _maxHistorySize = 50;

  // Clipboard for copy/paste
  List<MidiNoteData> _clipboard = [];

  // Remember last note duration (default = 1 beat = quarter note)
  double _lastNoteDuration = 1.0;

  @override
  void initState() {
    super.initState();
    _currentClip = widget.clipData;

    // Scroll to default view (middle of piano)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToDefaultView();
    });
  }

  @override
  void dispose() {
    _horizontalScroll.dispose();
    _verticalScroll.dispose();
    super.dispose();
  }

  void _scrollToDefaultView() {
    // Scroll to show C2-C6 range by default
    final scrollOffset = _calculateNoteY(_defaultViewEndNote);
    _verticalScroll.jumpTo(scrollOffset);
  }

  /// Notify parent widget that clip has been updated
  void _notifyClipUpdated() {
    if (widget.onClipUpdated != null && _currentClip != null) {
      widget.onClipUpdated!(_currentClip!);
    }

    // Trigger rebuild to recalculate totalBeats and update grey overlay
    setState(() {});
  }

  /// Save current state to history before making changes
  void _saveToHistory() {
    if (_currentClip == null) return;

    // Save current state to undo stack
    _undoHistory.add(_currentClip!);

    // Limit history size
    if (_undoHistory.length > _maxHistorySize) {
      _undoHistory.removeAt(0);
    }

    // Clear redo history when new action is performed
    _redoHistory.clear();
  }

  /// Undo last action
  void _undo() {
    if (_undoHistory.isEmpty) {
      debugPrint('⚠️ Nothing to undo');
      return;
    }

    // Save current state to redo stack
    if (_currentClip != null) {
      _redoHistory.add(_currentClip!);
    }

    // Restore previous state
    setState(() {
      _currentClip = _undoHistory.removeLast();
    });

    _notifyClipUpdated();
    debugPrint('↩️ Undo performed (${_undoHistory.length} actions remaining)');
  }

  /// Redo last undone action
  void _redo() {
    if (_redoHistory.isEmpty) {
      debugPrint('⚠️ Nothing to redo');
      return;
    }

    // Save current state to undo stack
    if (_currentClip != null) {
      _undoHistory.add(_currentClip!);
    }

    // Restore next state
    setState(() {
      _currentClip = _redoHistory.removeLast();
    });

    _notifyClipUpdated();
    debugPrint('↪️ Redo performed');
  }

  double _calculateNoteY(int midiNote) {
    // Higher notes = lower Y coordinate (inverted)
    return (_maxMidiNote - midiNote) * _pixelsPerNote;
  }

  double _calculateBeatX(double beat) {
    return beat * _pixelsPerBeat;
  }

  int _getNoteAtY(double y) {
    return _maxMidiNote - (y / _pixelsPerNote).floor();
  }

  double _getBeatAtX(double x) {
    return x / _pixelsPerBeat;
  }

  double _snapToGrid(double beat) {
    if (!_snapEnabled) return beat;
    return (beat / _gridDivision).round() * _gridDivision;
  }

  void _zoomIn() {
    setState(() {
      _pixelsPerBeat = (_pixelsPerBeat * 1.2).clamp(20.0, 500.0);
    });
  }

  void _zoomOut() {
    setState(() {
      _pixelsPerBeat = (_pixelsPerBeat / 1.2).clamp(20.0, 500.0);
    });
  }

  void _toggleSnap() {
    setState(() {
      _snapEnabled = !_snapEnabled;
    });
  }

  void _changeGridDivision() {
    setState(() {
      // Cycle through: 1/4, 1/8, 1/16, 1/32
      if (_gridDivision == 0.25) {
        _gridDivision = 0.125;
      } else if (_gridDivision == 0.125) {
        _gridDivision = 0.0625;
      } else if (_gridDivision == 0.0625) {
        _gridDivision = 0.03125;
      } else {
        _gridDivision = 0.25;
      }
    });
  }

  String _getGridDivisionLabel() {
    if (_gridDivision == 0.25) return '1/16';
    if (_gridDivision == 0.125) return '1/32';
    if (_gridDivision == 0.0625) return '1/64';
    if (_gridDivision == 0.03125) return '1/128';
    return '1/16';
  }

  /// Calculate required beats based on notes, extending by 4-bar sections
  double _calculateRequiredBeats() {
    if (_currentClip == null || _currentClip!.notes.isEmpty) {
      return 16.0; // Default 4 bars (4 * 4 beats)
    }

    // Find the furthest note end time
    final furthestBeat = _currentClip!.notes
        .map((note) => note.startTime + note.duration)
        .reduce((a, b) => a > b ? a : b);

    // Round up to next 4-bar boundary
    final requiredBars = (furthestBeat / 4).ceil();

    // Minimum 4 bars, extend by 4 bars at a time
    final bars = requiredBars < 4 ? 4 : ((requiredBars / 4).ceil() * 4);

    return bars * 4.0; // Convert bars to beats
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        _handleKeyEvent(event);
        return KeyEventResult.handled;
      },
      child: Container(
        color: const Color(0xFFE0E0E0), // Light grey background
        child: Column(
          children: [
            _buildHeader(),
            _buildPianoRollContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildPianoRollContent() {
    // Calculate required beats dynamically (auto-extends by 4 bars)
    final requiredBeats = _calculateRequiredBeats();
    final totalBeats = requiredBeats;
    final activeBeats = requiredBeats; // Active region (not greyed out)

    final canvasWidth = totalBeats * _pixelsPerBeat;
    final canvasHeight = (_maxMidiNote - _minMidiNote + 1) * _pixelsPerNote;

    return Expanded(
      child: Column(
        children: [
          // Bar ruler row - FIXED at top (outside vertical scroll)
          Row(
            children: [
              // Spacer for piano keys width
              Container(
                width: 60,
                height: 30,
                decoration: const BoxDecoration(
                  color: Color(0xFFE8E8E8),
                  border: Border(
                    right: BorderSide(color: Color(0xFF909090), width: 1),
                    bottom: BorderSide(color: Color(0xFF909090), width: 1),
                  ),
                ),
              ),
              // Bar ruler with horizontal scroll
              Expanded(
                child: Scrollbar(
                  controller: _horizontalScroll,
                  child: SingleChildScrollView(
                    controller: _horizontalScroll,
                    scrollDirection: Axis.horizontal,
                    child: _buildBarRuler(totalBeats, canvasWidth),
                  ),
                ),
              ),
            ],
          ),
          // Content row - ONE vertical scroll for both piano keys and grid
          Expanded(
            child: Scrollbar(
              controller: _verticalScroll,
              child: SingleChildScrollView(
                controller: _verticalScroll,
                scrollDirection: Axis.vertical,
                child: SizedBox(
                  height: canvasHeight,
                  child: Row(
                    children: [
                      // Piano keys (no separate scroll - inside shared vertical scroll)
                      Container(
                        width: 60,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF8F8F8),
                          border: Border(
                            right: BorderSide(color: Color(0xFF909090), width: 1),
                          ),
                        ),
                        child: Column(
                          children: List.generate(
                            _maxMidiNote - _minMidiNote + 1,
                            (index) {
                              final midiNote = _maxMidiNote - index;
                              return _buildPianoKey(midiNote);
                            },
                          ),
                        ),
                      ),
                      // Grid with horizontal scroll (no separate vertical scroll)
                      Expanded(
                        child: Scrollbar(
                          controller: _horizontalScroll,
                          child: SingleChildScrollView(
                            controller: _horizontalScroll,
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(
                              width: canvasWidth,
                              height: canvasHeight,
                              child: GestureDetector(
                                behavior: HitTestBehavior.translucent,
                                onTapDown: _onTapDown,
                                onSecondaryTapDown: _onRightClick,
                                onPanStart: _onPanStart,
                                onPanUpdate: _onPanUpdate,
                                onPanEnd: _onPanEnd,
                                child: Container(
                                  color: Colors.transparent,
                                  child: Stack(
                                    children: [
                                      CustomPaint(
                                        size: Size(canvasWidth, canvasHeight),
                                        painter: _GridPainter(
                                          pixelsPerBeat: _pixelsPerBeat,
                                          pixelsPerNote: _pixelsPerNote,
                                          gridDivision: _gridDivision,
                                          maxMidiNote: _maxMidiNote,
                                          totalBeats: totalBeats,
                                          activeBeats: activeBeats,
                                        ),
                                      ),
                                      CustomPaint(
                                        size: Size(canvasWidth, canvasHeight),
                                        painter: _NotePainter(
                                          notes: _currentClip?.notes ?? [],
                                          previewNote: _previewNote,
                                          pixelsPerBeat: _pixelsPerBeat,
                                          pixelsPerNote: _pixelsPerNote,
                                          maxMidiNote: _maxMidiNote,
                                          selectionStart: _selectionStart,
                                          selectionEnd: _selectionEnd,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFFD0D0D0), // Light grey header
        border: Border(
          bottom: BorderSide(color: Color(0xFF909090), width: 1),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.piano_outlined,
            color: Colors.black, // Black icon on light background
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            'Piano Roll - ${widget.clipData?.name ?? "Unnamed Clip"}',
            style: const TextStyle(
              color: Colors.black, // Black text on light background
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),

          // Snap toggle
          _buildHeaderButton(
            icon: Icons.grid_on,
            label: 'Snap: ${_snapEnabled ? _getGridDivisionLabel() : "OFF"}',
            isActive: _snapEnabled,
            onTap: _toggleSnap,
            onLongPress: _changeGridDivision,
          ),

          const SizedBox(width: 8),

          // Zoom controls
          _buildHeaderButton(
            icon: Icons.remove,
            label: 'Zoom Out',
            onTap: _zoomOut,
          ),
          const SizedBox(width: 4),
          Text(
            '${_pixelsPerBeat.toInt()}px',
            style: const TextStyle(
              color: Colors.black, // Black text
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 4),
          _buildHeaderButton(
            icon: Icons.add,
            label: 'Zoom In',
            onTap: _zoomIn,
          ),

          const SizedBox(width: 16),

          // Close button
          IconButton(
            icon: const Icon(Icons.close),
            color: Colors.black, // Black icon
            iconSize: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: widget.onClose,
            tooltip: 'Close Piano Roll',
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderButton({
    required IconData icon,
    required String label,
    bool isActive = false,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
  }) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF4CAF50) : const Color(0xFFB8B8B8), // Light grey when inactive
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive ? Colors.white : Colors.black, // Black when inactive
            ),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.black, // Black when inactive
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPianoKey(int midiNote) {
    final isBlackKey = _isBlackKey(midiNote);
    final noteName = _getNoteNameForKey(midiNote);
    final isC = midiNote % 12 == 0; // Only show labels for C notes

    return Container(
      height: _pixelsPerNote,
      decoration: BoxDecoration(
        // Pure white for white keys, dark grey/black for black keys
        color: isBlackKey ? const Color(0xFF303030) : const Color(0xFFFFFFFF),
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFFCCCCCC), // Light grey border
            width: 0.5,
          ),
        ),
      ),
      child: Center(
        child: isC // Only show note names for C notes
            ? Text(
                noteName,
                style: TextStyle(
                  color: isBlackKey ? const Color(0xFFA0A0A0) : Colors.black, // Black text on white, grey on black
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  bool _isBlackKey(int midiNote) {
    final noteInOctave = midiNote % 12;
    return [1, 3, 6, 8, 10].contains(noteInOctave); // C#, D#, F#, G#, A#
  }

  String _getNoteNameForKey(int midiNote) {
    const noteNames = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    final octave = (midiNote ~/ 12) - 1;
    final noteName = noteNames[midiNote % 12];
    return '$noteName$octave';
  }

  /// Build bar number ruler (no ScrollView - will be inside grid's horizontal scroll)
  Widget _buildBarRuler(double totalBeats, double canvasWidth) {
    return Container(
      height: 30,
      width: canvasWidth,
      decoration: const BoxDecoration(
        color: Color(0xFFE8E8E8), // Light grey
        border: Border(
          bottom: BorderSide(color: Color(0xFF909090), width: 1),
        ),
      ),
      child: CustomPaint(
        size: Size(canvasWidth, 30),
        painter: _BarRulerPainter(
          pixelsPerBeat: _pixelsPerBeat,
          totalBeats: totalBeats,
          playheadPosition: 0.0, // TODO: Sync with actual playhead
        ),
      ),
    );
  }

  // Find note at position
  MidiNoteData? _findNoteAtPosition(Offset position) {
    final beat = _getBeatAtX(position.dx);
    final note = _getNoteAtY(position.dy);

    for (final midiNote in _currentClip?.notes ?? []) {
      if (midiNote.contains(beat, note)) {
        return midiNote;
      }
    }
    return null;
  }

  // Check if position is near right edge of note (for resizing)
  bool _isNearNoteEdge(Offset position, MidiNoteData note) {
    final beat = _getBeatAtX(position.dx);
    final edgeBeat = note.endTime;
    final threshold = 0.25; // 1/16th note threshold
    return (beat - edgeBeat).abs() < threshold && note.note == _getNoteAtY(position.dy);
  }

  void _onTapDown(TapDownDetails details) {
    final clickedNote = _findNoteAtPosition(details.localPosition);

    if (clickedNote != null) {
      // Select note
      setState(() {
        _currentClip = _currentClip?.copyWith(
          notes: _currentClip!.notes.map((n) {
            return n.copyWith(isSelected: n.id == clickedNote.id);
          }).toList(),
        );
      });
    } else {
      // Create new note on single click (no dragging required)
      _saveToHistory(); // Save before creating note

      final beat = _snapToGrid(_getBeatAtX(details.localPosition.dx));
      final note = _getNoteAtY(details.localPosition.dy);

      final newNote = MidiNoteData(
        note: note,
        velocity: 100,
        startTime: beat,
        duration: _lastNoteDuration, // Use remembered duration
      );

      setState(() {
        _currentClip = _currentClip?.addNote(newNote);
      });
      _notifyClipUpdated();

      debugPrint('🎵 Created note: ${newNote.noteName} (duration: $_lastNoteDuration beats)');
    }
  }

  void _onPanStart(DragStartDetails details) {
    _dragStart = details.localPosition;
    final clickedNote = _findNoteAtPosition(details.localPosition);
    final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;

    if (isShiftPressed && clickedNote == null) {
      // Start multi-select with shift+drag
      setState(() {
        _isSelecting = true;
        _selectionStart = details.localPosition;
        _selectionEnd = details.localPosition;
        _currentMode = InteractionMode.select;
      });
    } else if (clickedNote != null) {
      // Check if we're near the edge for resizing
      if (_isNearNoteEdge(details.localPosition, clickedNote)) {
        _saveToHistory(); // Save before resizing
        setState(() {
          _isResizing = true;
          _resizingNoteId = clickedNote.id;
          _currentMode = InteractionMode.resize;
        });
      } else {
        // Start moving the note
        _saveToHistory(); // Save before moving
        setState(() {
          _currentMode = InteractionMode.move;
          // Make sure note is selected
          _currentClip = _currentClip?.copyWith(
            notes: _currentClip!.notes.map((n) {
              return n.copyWith(isSelected: n.id == clickedNote.id);
            }).toList(),
          );
        });
      }
    }
    // Note: No longer need to handle drawing here - single-click in _onTapDown creates notes
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_currentMode == InteractionMode.select && _isSelecting) {
      // Update selection rectangle
      setState(() {
        _selectionEnd = details.localPosition;
      });
    } else if (_currentMode == InteractionMode.move && _dragStart != null) {
      // Move selected notes
      final deltaX = details.localPosition.dx - _dragStart!.dx;
      final deltaY = details.localPosition.dy - _dragStart!.dy;

      final deltaBeat = deltaX / _pixelsPerBeat;
      final deltaNote = -(deltaY / _pixelsPerNote).round(); // Inverted Y

      setState(() {
        _currentClip = _currentClip?.copyWith(
          notes: _currentClip!.notes.map((n) {
            if (n.isSelected) {
              final newStartTime = _snapToGrid(n.startTime + deltaBeat).clamp(0.0, 64.0);
              final newNote = (n.note + deltaNote).clamp(0, 127);
              return n.copyWith(
                startTime: newStartTime,
                note: newNote,
              );
            }
            return n;
          }).toList(),
        );
        _dragStart = details.localPosition;
      });
      _notifyClipUpdated();
    } else if (_currentMode == InteractionMode.resize && _resizingNoteId != null) {
      // Resize note
      setState(() {
        _currentClip = _currentClip?.copyWith(
          notes: _currentClip!.notes.map((n) {
            if (n.id == _resizingNoteId) {
              final endBeat = _snapToGrid(_getBeatAtX(details.localPosition.dx));
              final newDuration = (endBeat - n.startTime).clamp(_gridDivision, 64.0);
              return n.copyWith(duration: newDuration);
            }
            return n;
          }).toList(),
        );
      });
      _notifyClipUpdated();
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (_currentMode == InteractionMode.select && _isSelecting) {
      // Apply selection rectangle
      if (_selectionStart != null && _selectionEnd != null) {
        final startBeat = _getBeatAtX(_selectionStart!.dx.clamp(0, double.infinity));
        final endBeat = _getBeatAtX(_selectionEnd!.dx.clamp(0, double.infinity));
        final startNote = _getNoteAtY(_selectionStart!.dy.clamp(0, double.infinity));
        final endNote = _getNoteAtY(_selectionEnd!.dy.clamp(0, double.infinity));

        final minBeat = startBeat < endBeat ? startBeat : endBeat;
        final maxBeat = startBeat < endBeat ? endBeat : startBeat;
        final minNote = startNote < endNote ? startNote : endNote;
        final maxNote = startNote < endNote ? endNote : startNote;

        setState(() {
          _currentClip = _currentClip?.copyWith(
            notes: _currentClip!.notes.map((note) {
              final isInRange = note.startTime >= minBeat &&
                                note.endTime <= maxBeat &&
                                note.note >= minNote &&
                                note.note <= maxNote;
              return note.copyWith(isSelected: isInRange);
            }).toList(),
          );
        });
      }

      setState(() {
        _isSelecting = false;
        _selectionStart = null;
        _selectionEnd = null;
      });
    }

    // Remember duration of resized note for next creation
    if (_currentMode == InteractionMode.resize && _resizingNoteId != null) {
      final resizedNote = _currentClip?.notes.firstWhere((n) => n.id == _resizingNoteId);
      if (resizedNote != null) {
        _lastNoteDuration = resizedNote.duration;
        debugPrint('📝 Remembered note duration: $_lastNoteDuration beats');
      }
    }

    // Reset state
    setState(() {
      _dragStart = null;
      _isResizing = false;
      _resizingNoteId = null;
      _currentMode = InteractionMode.draw;
    });
  }

  // Handle keyboard events for deletion, undo/redo, and copy/paste
  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      // Delete key
      if (event.logicalKey == LogicalKeyboardKey.delete ||
          event.logicalKey == LogicalKeyboardKey.backspace) {
        if (_currentClip?.selectedNotes.isNotEmpty ?? false) {
          _saveToHistory();
          _deleteSelectedNotes();
        }
      }
      // Undo (Cmd+Z or Ctrl+Z)
      else if ((event.logicalKey == LogicalKeyboardKey.keyZ) &&
          (HardwareKeyboard.instance.isMetaPressed ||
           HardwareKeyboard.instance.isControlPressed) &&
          !HardwareKeyboard.instance.isShiftPressed) {
        _undo();
      }
      // Redo (Cmd+Shift+Z or Ctrl+Shift+Z)
      else if ((event.logicalKey == LogicalKeyboardKey.keyZ) &&
          (HardwareKeyboard.instance.isMetaPressed ||
           HardwareKeyboard.instance.isControlPressed) &&
          HardwareKeyboard.instance.isShiftPressed) {
        _redo();
      }
      // Copy (Cmd+C or Ctrl+C)
      else if ((event.logicalKey == LogicalKeyboardKey.keyC) &&
          (HardwareKeyboard.instance.isMetaPressed ||
           HardwareKeyboard.instance.isControlPressed)) {
        _copySelectedNotes();
      }
      // Paste (Cmd+V or Ctrl+V)
      else if ((event.logicalKey == LogicalKeyboardKey.keyV) &&
          (HardwareKeyboard.instance.isMetaPressed ||
           HardwareKeyboard.instance.isControlPressed)) {
        _pasteNotes();
      }
    }
  }

  /// Copy selected notes to clipboard
  void _copySelectedNotes() {
    final selectedNotes = _currentClip?.selectedNotes ?? [];
    if (selectedNotes.isEmpty) {
      debugPrint('⚠️ No notes selected to copy');
      return;
    }

    // Store copies of selected notes (deselected)
    _clipboard = selectedNotes.map((note) => note.copyWith(isSelected: false)).toList();
    debugPrint('📋 Copied ${_clipboard.length} notes to clipboard');
  }

  /// Paste notes from clipboard
  void _pasteNotes() {
    if (_clipboard.isEmpty) {
      debugPrint('⚠️ Clipboard is empty');
      return;
    }

    if (_currentClip == null) {
      debugPrint('⚠️ No clip to paste into');
      return;
    }

    _saveToHistory(); // Save before pasting

    // Find the earliest note in clipboard to use as reference point
    final earliestTime = _clipboard.map((n) => n.startTime).reduce((a, b) => a < b ? a : b);

    // Paste at current view position (center of visible area)
    // Or use a reasonable default position
    final pasteTime = 0.0; // Paste at start for now - could be improved to use playhead

    // Calculate offset
    final timeOffset = pasteTime - earliestTime;

    // Create new notes with offset and new IDs
    final newNotes = _clipboard.map((note) {
      return note.copyWith(
        id: DateTime.now().microsecondsSinceEpoch.toString() + '_${note.note}',
        startTime: note.startTime + timeOffset,
        isSelected: true, // Select pasted notes
      );
    }).toList();

    // Deselect all existing notes and add new ones
    setState(() {
      _currentClip = _currentClip?.copyWith(
        notes: [
          ..._currentClip!.notes.map((n) => n.copyWith(isSelected: false)),
          ...newNotes,
        ],
      );
    });

    _notifyClipUpdated();
    debugPrint('📌 Pasted ${newNotes.length} notes');
  }

  void _deleteSelectedNotes() {
    setState(() {
      final selectedIds = _currentClip?.selectedNotes.map((n) => n.id).toSet() ?? {};
      _currentClip = _currentClip?.copyWith(
        notes: _currentClip!.notes.where((n) => !selectedIds.contains(n.id)).toList(),
      );
    });
    _notifyClipUpdated();
  }

  /// Handle right-click on canvas
  void _onRightClick(TapDownDetails details) {
    final clickedNote = _findNoteAtPosition(details.localPosition);

    if (clickedNote != null) {
      // Right-clicked on a note - delete it immediately
      _saveToHistory(); // Save before deleting
      setState(() {
        _currentClip = _currentClip?.copyWith(
          notes: _currentClip!.notes.where((n) => n.id != clickedNote.id).toList(),
        );
      });
      _notifyClipUpdated();
      debugPrint('🗑️ Deleted note: ${clickedNote.noteName}');
    }
  }
}

/// Custom painter for grid background
class _GridPainter extends CustomPainter {
  final double pixelsPerBeat;
  final double pixelsPerNote;
  final double gridDivision;
  final int maxMidiNote;
  final double totalBeats;
  final double activeBeats; // Active region boundary

  _GridPainter({
    required this.pixelsPerBeat,
    required this.pixelsPerNote,
    required this.gridDivision,
    required this.maxMidiNote,
    required this.totalBeats,
    required this.activeBeats,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // STEP 1: Draw backgrounds FIRST (so vertical lines can be drawn on top)
    for (int note = 0; note <= maxMidiNote; note++) {
      final y = (maxMidiNote - note) * pixelsPerNote;
      final isBlackKey = _isBlackKey(note);

      // Draw background color (medium grey theme to match DAW UI)
      final bgPaint = Paint()
        ..color = isBlackKey ? const Color(0xFFB8B8B8) : const Color(0xFFC8C8C8);

      canvas.drawRect(
        Rect.fromLTWH(0, y, size.width, pixelsPerNote),
        bgPaint,
      );

      // Draw horizontal separator line
      final linePaint = Paint()
        ..color = const Color(0xFFE0E0E0) // Subtle light grey line
        ..strokeWidth = 0.5;

      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    // STEP 2: Draw vertical grid lines ON TOP (so they're visible)
    // Light theme grid colors - MEDIUM GREY for subtle but clear visibility
    final subdivisionPaint = Paint()
      ..color = const Color(0xFFB0B0B0) // Light grey for 16th note lines
      ..strokeWidth = 1.0;

    final beatPaint = Paint()
      ..color = const Color(0xFF989898) // Medium grey for beats
      ..strokeWidth = 1.5;

    final barPaint = Paint()
      ..color = const Color(0xFF808080) // Medium grey for bars
      ..strokeWidth = 2.5;

    // Vertical lines (beats and bars)
    for (double beat = 0; beat <= totalBeats; beat += gridDivision) {
      final x = beat * pixelsPerBeat;
      final isBar = (beat % 4.0) == 0.0; // 4/4 time
      final isBeat = (beat % 1.0) == 0.0;

      final paint = isBar ? barPaint : (isBeat ? beatPaint : subdivisionPaint);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Draw grey overlay for inactive bars (beyond active region)
    if (totalBeats > activeBeats) {
      final inactiveStartX = activeBeats * pixelsPerBeat;
      final overlayRect = Rect.fromLTWH(
        inactiveStartX,
        0,
        size.width - inactiveStartX,
        size.height,
      );

      // Dark overlay on inactive region
      final overlayPaint = Paint()
        ..color = Colors.black.withOpacity(0.15); // 15% dark overlay

      canvas.drawRect(overlayRect, overlayPaint);

      // Separator line at the boundary
      final separatorPaint = Paint()
        ..color = const Color(0xFF606060)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;

      canvas.drawLine(
        Offset(inactiveStartX, 0),
        Offset(inactiveStartX, size.height),
        separatorPaint,
      );
    }
  }

  bool _isBlackKey(int midiNote) {
    final noteInOctave = midiNote % 12;
    return [1, 3, 6, 8, 10].contains(noteInOctave);
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) {
    return pixelsPerBeat != oldDelegate.pixelsPerBeat ||
           pixelsPerNote != oldDelegate.pixelsPerNote ||
           gridDivision != oldDelegate.gridDivision;
  }
}

/// Custom painter for MIDI notes
class _NotePainter extends CustomPainter {
  final List<MidiNoteData> notes;
  final MidiNoteData? previewNote;
  final double pixelsPerBeat;
  final double pixelsPerNote;
  final int maxMidiNote;
  final Offset? selectionStart;
  final Offset? selectionEnd;

  _NotePainter({
    required this.notes,
    this.previewNote,
    required this.pixelsPerBeat,
    required this.pixelsPerNote,
    required this.maxMidiNote,
    this.selectionStart,
    this.selectionEnd,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw all notes
    for (final note in notes) {
      _drawNote(canvas, note, isSelected: note.isSelected);
    }

    // Draw preview note
    if (previewNote != null) {
      _drawNote(canvas, previewNote!, isPreview: true);
    }

    // Draw selection rectangle
    if (selectionStart != null && selectionEnd != null) {
      final rect = Rect.fromPoints(selectionStart!, selectionEnd!);

      // Fill
      final fillPaint = Paint()
        ..color = const Color(0xFF2196F3).withOpacity(0.2) // Blue fill
        ..style = PaintingStyle.fill;
      canvas.drawRect(rect, fillPaint);

      // Border
      final borderPaint = Paint()
        ..color = const Color(0xFF2196F3) // Blue border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawRect(rect, borderPaint);
    }
  }

  void _drawNote(Canvas canvas, MidiNoteData note, {bool isSelected = false, bool isPreview = false}) {
    final x = note.startTime * pixelsPerBeat;
    final y = (maxMidiNote - note.note) * pixelsPerNote;
    final width = note.duration * pixelsPerBeat;
    final height = pixelsPerNote - 2; // Small gap between notes

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, y + 1, width, height),
      const Radius.circular(4), // Slightly rounded corners
    );

    // Note fill - keep mint green for now (will update to track colors in next phase)
    final fillPaint = Paint()
      ..color = isPreview
          ? const Color(0xFF7FD4A0).withOpacity(0.5) // Mint green preview
          : note.velocityColor;

    canvas.drawRRect(rect, fillPaint);

    // Note border
    final borderPaint = Paint()
      ..color = isSelected
          ? Colors.black // Black border when selected
          : const Color(0xFF5FB085) // Darker mint border normally
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSelected ? 2.5 : 1.5;

    canvas.drawRRect(rect, borderPaint);

    // Draw note name inside
    if (width > 30) { // Only show label if note is wide enough
      final textPainter = TextPainter(
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.left,
      );

      textPainter.text = TextSpan(
        text: note.noteName, // e.g., "G5", "D#4", "C3"
        style: TextStyle(
          color: Colors.black.withOpacity(0.7), // Dark text on colored background
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      );

      textPainter.layout();

      // Position label at left edge with small padding
      final textX = x + 4;
      final textY = y + (height / 2) - (textPainter.height / 2) + 1;

      textPainter.paint(canvas, Offset(textX, textY));
    }
  }

  @override
  bool shouldRepaint(_NotePainter oldDelegate) {
    return notes != oldDelegate.notes ||
           previewNote != oldDelegate.previewNote ||
           pixelsPerBeat != oldDelegate.pixelsPerBeat ||
           pixelsPerNote != oldDelegate.pixelsPerNote ||
           selectionStart != oldDelegate.selectionStart ||
           selectionEnd != oldDelegate.selectionEnd;
  }
}


/// Painter for bar number ruler (FL Studio style)
class _BarRulerPainter extends CustomPainter {
  final double pixelsPerBeat;
  final double totalBeats;
  final double playheadPosition; // in beats

  _BarRulerPainter({
    required this.pixelsPerBeat,
    required this.totalBeats,
    required this.playheadPosition,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    // Draw bar numbers (every 4 beats)
    final totalBars = (totalBeats / 4).ceil();
    for (int bar = 0; bar < totalBars; bar++) {
      final barStartBeat = bar * 4.0;
      final x = barStartBeat * pixelsPerBeat;

      // Bar number
      final barNumber = bar + 1; // 1-indexed
      textPainter.text = TextSpan(
        text: "$barNumber",
        style: const TextStyle(
          color: Colors.black, // Black text on light background
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      );

      textPainter.layout();
      // Draw bar number at LEFT edge of bar (not centered)
      textPainter.paint(
        canvas,
        Offset(x + 4, 7), // 4px padding from left edge
      );

      // Draw beat ticks
      for (int beat = 0; beat < 4; beat++) {
        final beatX = (barStartBeat + beat) * pixelsPerBeat;
        final tickPaint = Paint()
          ..color = const Color(0xFF909090).withOpacity(0.5) // Grey ticks
          ..strokeWidth = 1;

        canvas.drawLine(
          Offset(beatX, size.height - 5),
          Offset(beatX, size.height),
          tickPaint,
        );
      }
    }

    // Draw playhead triangle (orange)
    if (playheadPosition >= 0 && playheadPosition <= totalBeats) {
      final playheadX = playheadPosition * pixelsPerBeat;

      final trianglePath = Path()
        ..moveTo(playheadX, size.height - 2)
        ..lineTo(playheadX - 8, 0)
        ..lineTo(playheadX + 8, 0)
        ..close();

      final playheadPaint = Paint()
        ..color = const Color(0xFFFF9800) // Orange
        ..style = PaintingStyle.fill;

      canvas.drawPath(trianglePath, playheadPaint);

      // Playhead border for definition
      final borderPaint = Paint()
        ..color = const Color(0xFFE65100) // Darker orange border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      canvas.drawPath(trianglePath, borderPaint);
    }
  }

  @override
  bool shouldRepaint(_BarRulerPainter oldDelegate) {
    return playheadPosition != oldDelegate.playheadPosition ||
           pixelsPerBeat != oldDelegate.pixelsPerBeat ||
           totalBeats != oldDelegate.totalBeats;
  }
}

