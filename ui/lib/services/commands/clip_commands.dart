import '../../audio_engine.dart';
import '../../models/midi_note_data.dart';
import 'command.dart';

/// Command to move a MIDI clip on the timeline
class MoveMidiClipCommand extends Command {
  final int clipId;
  final String clipName;
  final double newStartTime;
  final double oldStartTime;
  final int? newTrackId;
  final int? oldTrackId;

  MoveMidiClipCommand({
    required this.clipId,
    required this.clipName,
    required this.newStartTime,
    required this.oldStartTime,
    this.newTrackId,
    this.oldTrackId,
  });

  @override
  Future<void> execute(AudioEngine engine) async {
    // Note: This updates the clip position in the engine
    // The actual implementation depends on your engine API
    // For now, this is handled in Flutter state
  }

  @override
  Future<void> undo(AudioEngine engine) async {
    // Restore previous position
  }

  @override
  String get description =>
      'Move clip: $clipName (${oldStartTime.toStringAsFixed(2)}s → ${newStartTime.toStringAsFixed(2)}s)';
}

/// Command to move an audio clip on the timeline
class MoveAudioClipCommand extends Command {
  final int trackId;
  final int clipId;
  final String clipName;
  final double newStartTime;
  final double oldStartTime;

  MoveAudioClipCommand({
    required this.trackId,
    required this.clipId,
    required this.clipName,
    required this.newStartTime,
    required this.oldStartTime,
  });

  @override
  Future<void> execute(AudioEngine engine) async {
    engine.setClipStartTime(trackId, clipId, newStartTime);
  }

  @override
  Future<void> undo(AudioEngine engine) async {
    engine.setClipStartTime(trackId, clipId, oldStartTime);
  }

  @override
  String get description =>
      'Move audio clip: $clipName (${oldStartTime.toStringAsFixed(2)}s → ${newStartTime.toStringAsFixed(2)}s)';
}

/// Command to delete a MIDI clip
class DeleteMidiClipCommand extends Command {
  final MidiClipData clipData;

  DeleteMidiClipCommand({required this.clipData});

  @override
  Future<void> execute(AudioEngine engine) async {
    // Delete clip from engine
    // Note: Implement engine.deleteMidiClip() if not exists
  }

  @override
  Future<void> undo(AudioEngine engine) async {
    // Recreate the clip with stored data
    // This requires storing all clip state
  }

  @override
  String get description => 'Delete MIDI clip: ${clipData.name}';
}

/// Command to add/edit/delete MIDI notes
class EditMidiNotesCommand extends Command {
  final int clipId;
  final List<MidiNoteData> oldNotes;
  final List<MidiNoteData> newNotes;
  final String actionDescription;

  EditMidiNotesCommand({
    required this.clipId,
    required this.oldNotes,
    required this.newNotes,
    required this.actionDescription,
  });

  @override
  Future<void> execute(AudioEngine engine) async {
    // Notes are managed in Flutter state primarily
    // Engine sync happens via piano roll
  }

  @override
  Future<void> undo(AudioEngine engine) async {
    // Restore old notes
  }

  @override
  String get description => actionDescription;
}
