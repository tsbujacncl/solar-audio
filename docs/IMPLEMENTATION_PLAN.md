# Solar Audio — Implementation Plan

**Version:** 1.0  
**Target:** v1 MVP (macOS + iPad)  
**Timeline:** 3–6 months (adjust based on availability)  
**Tech Stack:** Flutter (UI) + Rust (audio engine) + Firebase Firestore (cloud)

---

## Overview

This document breaks the MVP into **7 actionable milestones** (M1–M7), each representing ~2–4 weeks of work. Each milestone is demoable and builds toward the full v1 feature set defined in `MVP_SPEC.md`.

**Development Philosophy:**
- Build **vertical slices** (end-to-end features) rather than horizontal layers
- Prototype early, refine later
- Ship each milestone in a working state (even if rough)
- Test on macOS first, iPad second

---

## Milestone Overview (Gantt-Style Timeline)

| Milestone | Focus Area                  | Duration | Status      |
|-----------|-----------------------------|----------|-------------|
| **M0**    | Project Setup               | 1 week   | ✅ Complete |
| **M1**    | Audio Playback Foundation   | 3 weeks  | ✅ Complete |
| **M2**    | Recording & Input           | 3 weeks  | ✅ Complete |
| **M3**    | MIDI Editing                | 3 weeks  | 📋 Ready    |
| **M4**    | Mixing & Effects            | 4 weeks  | 📋 Ready    |
| **M5**    | Save & Export               | 2 weeks  | 📋 Ready    |
| **M6**    | Cloud & Versioning          | 2 weeks  | 📋 Ready    |
| **M7**    | Polish & Beta Launch        | 2 weeks  | 📋 Ready    |

**Total estimated time:** 20 weeks (~5 months)

---

## Phase Breakdown

### **Phase 1: Foundation** (M0–M1, ~4 weeks)
Get audio playing in a basic timeline. This validates the entire tech stack (Rust engine, Flutter UI, FFI bridge).

### **Phase 2: Core DAW Features** (M2–M4, ~10 weeks)
Recording, MIDI editing, mixing, and effects. This is the "meat" of the DAW.

### **Phase 3: Persistence & Cloud** (M5–M6, ~4 weeks)
Save/load projects, export audio, cloud snapshots, version history.

### **Phase 4: Polish & Launch** (M7, ~2 weeks)
Keyboard shortcuts, command palette, crash recovery, UI refinement, first beta release.

---

# Milestone Breakdown

---

## M0: Project Setup & Scaffolding

**Goal:** Get a "Hello World" running — Flutter UI talks to Rust audio engine via FFI.

**Duration:** 1 week  
**Deliverable:** App launches, plays a sine wave beep when you press a button.

### Tasks

#### Repository & Structure
- [x] Create GitHub repo: `solar-audio`
- [x] Set up folder structure (see `MVP_SPEC.md` for layout)
- [x] Add `MVP_SPEC.md` and `IMPLEMENTATION_PLAN.md` to `/docs/`
- [x] Create `.gitignore` (Rust: `/target/`, Flutter: `/build/`, etc.)
- [x] Add `README.md` with project description and setup instructions

#### Rust Audio Engine
- [x] Initialize Rust workspace: `cargo init engine --lib`
- [x] Add dependencies to `Cargo.toml`:
  - `cpal` (cross-platform audio I/O)
  - `symphonia` (audio file decoding)
  - `rubato` (sample rate conversion)
  - `ringbuf` (lock-free audio buffers)
- [x] Create basic audio callback (output silence to default device)
- [x] Test: Run `cargo run` and confirm no audio errors

#### Flutter UI
- [x] Initialize Flutter app: `flutter create ui`
- [x] Set up for macOS: `flutter config --enable-macos-desktop`
- [x] Create basic UI: single screen with a "Play Beep" button
- [x] Test: Run `flutter run -d macos` and confirm app launches

#### FFI Bridge (Rust ↔ Flutter)
- [x] Add `flutter_rust_bridge` to both projects
  - Rust: `flutter_rust_bridge` crate
  - Flutter: `flutter_rust_bridge` package
- [x] Generate FFI bindings: `flutter_rust_bridge_codegen`
- [x] Create simple Rust function: `play_sine_wave(frequency: f32, duration_ms: u32)`
- [x] Call from Flutter button press
- [x] Test: Press button → hear 440 Hz beep for 1 second

### Success Criteria
✅ App compiles on macOS  
✅ Button in Flutter triggers Rust function  
✅ Rust plays a sine wave through speakers  
✅ No crashes, FFI bridge works

### Risks & Mitigations
- **FFI setup is complex** → Follow `flutter_rust_bridge` tutorial closely, ask in Discord/GitHub issues if stuck
- **CPAL audio device errors** → Test on multiple devices, add error handling

---

## M1: Audio Playback Foundation

**Goal:** Load a WAV file, display waveform, play/pause/stop with transport controls.

**Duration:** 3 weeks  
**Deliverable:** Drag a WAV file into the app, see waveform, click play and hear it.

### Tasks

#### Rust: Audio File Loading & Decoding
- [x] Implement WAV file parser using `symphonia`
- [x] Decode to internal format: `Vec<f32>` (interleaved stereo, 48 kHz)
- [x] Handle sample rate conversion (if file is 44.1 kHz, resample to 48 kHz)
- [x] Expose FFI function: `load_audio_file(path: String) -> AudioClipHandle`
- [x] Test: Load a 5-second WAV, verify decoded samples are correct

#### Rust: Audio Playback Engine
- [x] Create `AudioGraph` struct (holds clips, tracks, playhead position)
- [x] Implement playback loop:
  - Read samples from clip based on playhead position
  - Mix to output buffer
  - Advance playhead
- [x] Add transport controls:
  - `play()`, `pause()`, `stop()`, `seek(position_seconds: f64)`
- [x] Expose FFI functions: `transport_play()`, `transport_pause()`, `transport_stop()`, `transport_seek(pos: f64)`
- [x] Test: Load file, call `play()`, hear audio from start to end

#### Flutter: Timeline UI (Basic)
- [x] Create `TimelineView` widget (horizontal scrollable canvas)
- [x] Render time ruler (bars/beats or seconds)
- [x] Render single audio track (empty for now)
- [x] Add playhead line (vertical line that moves during playback)
- [x] Test: Timeline displays, playhead visible

#### Flutter: Waveform Rendering
- [x] Request waveform data from Rust: `get_waveform_peaks(clip_id, resolution) -> Vec<f32>`
  - Rust: downsample audio to ~1000-2000 peaks per clip
- [x] Render waveform as path (peaks/valleys) on timeline
- [x] Update waveform when clip is loaded
- [x] Test: Drag a WAV file → waveform appears on timeline

#### Flutter: Transport Controls
- [x] Create transport bar UI (top of window):
  - Play button (▶)
  - Pause button (⏸)
  - Stop button (⏹)
  - Time display (00:00.000)
- [x] Wire buttons to FFI calls: `transport_play()`, `transport_pause()`, `transport_stop()`
- [x] Update time display every 50ms (poll playhead position from Rust)
- [x] Test: Click play → hear audio, time updates, playhead moves

#### Flutter: File Import (Drag & Drop)
- [x] Add drag-drop listener to timeline
- [x] On file drop: call `load_audio_file(path)`
- [x] Display clip on timeline at drop position
- [x] Test: Drag WAV from Finder → clip appears and plays

### Success Criteria
✅ Load a WAV file via drag-drop  
✅ See waveform rendered on timeline  
✅ Click play → audio plays from start  
✅ Playhead moves in real-time  
✅ Pause/stop/seek work correctly  
✅ No audio glitches or dropouts

### Risks & Mitigations
- **Waveform rendering is slow** → Downsample peaks in Rust, cache on first load
- **Playhead updates janky** → Use timer in Flutter, don't poll too frequently
- **Audio thread drops frames** → Profile with `cargo flamegraph`, optimize hot paths

---

## M2: Recording & Input

**Goal:** Record audio from microphone, add to timeline, with metronome and count-in.

**Duration:** 3 weeks  
**Deliverable:** Click record → hear metronome → speak into mic → see recorded clip on timeline.

### Tasks

#### Rust: Audio Input Setup
- [x] Enumerate input devices using `cpal`
- [x] Expose FFI: `get_audio_input_devices() -> Vec<AudioDevice>`
- [x] Create input stream (mono/stereo auto-detected, 48 kHz)
- [x] Test: Print input samples to console, confirm mic signal is captured

#### Rust: Recording Engine
- [x] Implement `start_recording()` function (simplified from original spec)
- [x] Record input samples to buffer during count-in
- [x] After count-in, transition to recording state
- [x] Implement `stop_recording() -> AudioClipHandle` (returns recorded clip)
- [x] Test: Record 5 seconds, verify clip has correct length and audio data

#### Rust: Metronome
- [x] Generate click sound (sine wave burst at 1200 Hz downbeat, 800 Hz other beats)
- [x] Play click on every beat based on tempo (default 120 BPM)
- [x] Add metronome enable/disable flag
- [x] Mix metronome into output during playback and recording
- [x] Test: Play with metronome → hear clicks on beats

#### Rust: Count-In
- [x] Add count-in duration parameter (0/1/2/4 bars)
- [x] During count-in: play metronome, don't record yet
- [x] After count-in: start recording (automatic state transition)
- [x] Expose FFI: `set_count_in_bars(bars: u32)`, `get_count_in_bars()`
- [x] Test: Record with 2-bar count-in → recording starts after 8 beats

#### Flutter: Input Device Selector *(Deferred to M4/M7)*
- [ ] **DEFERRED:** Add settings panel (slide-in from right) → M7 (Polish)
- [ ] **DEFERRED:** Display list of audio input devices → M7 (Settings UI)
- [ ] **DEFERRED:** Allow user to select device → M7 (Settings UI)
- [x] API implemented: `get_audio_input_devices()`, `set_audio_input_device()` work
- **Note:** Currently uses default input device; API is ready for UI implementation

#### Flutter: Record Button & Basic Recording
- [x] Add record button (⏺) to transport bar
- [ ] **DEFERRED:** Add "Arm" button to each track → M4 (Multi-track)
- [x] When record pressed:
  - [x] Call `start_recording()` (simplified, no track_id for now)
  - [ ] **DEFERRED:** Show count-in timer in UI (4... 3... 2... 1...) → M7 (Polish)
  - [x] Show "Counting In..." / "Recording..." status indicator
- [x] On stop: call `stop_recording()`, display new clip on timeline
- [x] Test: Press record → hear count-in → speak → stop → clip appears with waveform
- **Note:** Basic recording works; per-track arming requires multi-track architecture (M4)

#### Flutter: Metronome Toggle
- [x] Add metronome button to transport bar (🎵 icon)
- [x] Toggle on/off: call `set_metronome_enabled(bool)`
- [x] Visual feedback when enabled (blue highlight)
- [x] Test: Toggle metronome during playback → hear clicks start/stop

### Success Criteria
✅ Select audio input device *(API implemented, UI deferred to M7)*
✅ Click record → hear count-in metronome
✅ Record audio to timeline
✅ Stop recording → clip appears with correct audio
✅ Metronome plays during recording and playback
✅ No audio latency issues (monitor input in real-time)

### Deferred Items (moved to future milestones)
- **Input Device Selector UI** → M7 (Settings panel)
- **Per-Track Arming** → M4 (Multi-track system)
- **Count-In Visual Timer (4...3...2...1...)** → M7 (Polish)
- **Input Monitoring Volume Control** → M4 (Mixer panel)

### Risks & Mitigations
- **Input latency too high** → Use lowest buffer size possible (64-128 samples), test on different devices
- **Metronome drifts out of sync** → Use sample-accurate timing, not wall-clock time
- **Recording fails on some devices** → Add error handling, test with USB interfaces

---

## M3: MIDI Editing

**Goal:** Record MIDI, edit in piano roll, program drums in step sequencer.

**Duration:** 3 weeks  
**Deliverable:** Play MIDI keyboard → notes appear on timeline → edit in piano roll → hear synth playback.

### Tasks

#### Rust: MIDI Input
- [ ] Add `midir` crate for MIDI I/O
- [ ] Enumerate MIDI input devices
- [ ] Expose FFI: `get_midi_input_devices() -> Vec<MidiDevice>`
- [ ] Capture MIDI events (note on/off, velocity, timestamp)
- [ ] Test: Press keys on MIDI controller → print events to console

#### Rust: MIDI Recording
- [ ] Implement `start_midi_recording(track_id)`
- [ ] Record MIDI events with sample-accurate timestamps
- [ ] Quantize input optionally (snap to grid)
- [ ] Implement `stop_midi_recording() -> MidiClipHandle`
- [ ] Test: Play keyboard → stop → MIDI clip contains correct notes

#### Rust: MIDI Playback
- [ ] Store MIDI clips as `Vec<MidiEvent>` (note, velocity, timestamp)
- [ ] During playback: send MIDI events to instruments at correct times
- [ ] Test: Load MIDI clip → playback triggers notes

#### Rust: Built-in Subtractive Synth
- [ ] Implement basic synth:
  - Oscillators: sine, saw, square (choose 1-2 for v1)
  - ADSR envelope
  - Low-pass filter (resonant)
- [ ] Expose as instrument: `create_synth_instrument() -> InstrumentHandle`
- [ ] Route MIDI events to synth
- [ ] Test: Play MIDI clip → hear synth notes

#### Flutter: Piano Roll Editor
- [ ] Create `PianoRollView` widget (bottom panel, slides in/out)
- [ ] Display piano keys (vertical axis) and time (horizontal axis)
- [ ] Render MIDI notes as rectangles (position = time, height = pitch)
- [ ] Implement note selection (click to select, shift-click for multi-select)
- [ ] Implement note editing:
  - Drag to move notes
  - Resize to change duration
  - Click+drag on empty space to draw new notes
- [ ] Add delete key to remove selected notes
- [ ] Test: Draw notes with mouse → hear them on playback

#### Flutter: Quantize Function
- [ ] Add quantize button (Q) or menu item
- [ ] Show quantize dialog: grid size (1/4, 1/8, 1/16, 1/32)
- [ ] Call FFI: `quantize_midi_clip(clip_id, grid_size)`
- [ ] Test: Record sloppy MIDI → quantize → notes snap to grid

#### Rust: Step Sequencer (Drum Programming)
- [ ] Create 16-step grid (4 beats × 4 steps per beat)
- [ ] Store as MIDI clip with notes on grid positions
- [ ] Expose FFI: `set_step(step_index, pitch, velocity, enabled)`
- [ ] Test: Enable steps → hear drum pattern on loop

#### Flutter: Step Sequencer UI
- [ ] Create `StepSequencerView` widget (bottom panel, alternative to piano roll)
- [ ] Display 16 pads (4×4 grid)
- [ ] Each row = drum sound (kick, snare, hi-hat, etc.)
- [ ] Click pad to toggle step on/off
- [ ] Highlight current step during playback
- [ ] Test: Click steps → hear drum loop

#### Rust: Drum Sampler Instrument
- [ ] Load drum samples (kick.wav, snare.wav, hihat.wav, etc.)
- [ ] Map MIDI notes to samples (C1 = kick, D1 = snare, etc.)
- [ ] Trigger samples on MIDI events
- [ ] Test: Step sequencer triggers drum samples correctly

### Success Criteria
✅ Record MIDI from keyboard  
✅ Edit notes in piano roll (draw, move, resize, delete)  
✅ Quantize MIDI notes  
✅ Program drums in step sequencer  
✅ Hear built-in synth and drum sampler on playback  
✅ Switch between piano roll and step sequencer views (Tab key)

### Risks & Mitigations
- **MIDI timing is imprecise** → Use sample-accurate timestamps, not millisecond resolution
- **Piano roll performance issues** → Render only visible notes, cache drawing
- **Synth sounds bad** → Use proper anti-aliasing, add basic filter, tune envelope

---

## M4: Mixing & Effects

**Goal:** Add tracks, mixer panel, sends/returns, built-in effects (EQ, reverb, delay, compressor).

**Duration:** 4 weeks  
**Deliverable:** Multi-track project with effects, mix with faders/pans, send tracks to shared reverb.

### Tasks

#### Rust: Track System
- [ ] Implement track types: Audio, MIDI, Return, Group, Master
- [ ] Each track has:
  - Volume fader (dB, -∞ to +6 dB)
  - Pan knob (-100% L to +100% R)
  - Mute/solo buttons
  - Send knobs (amount to send to Return tracks)
  - FX chain (list of effects)
- [ ] Expose FFI: `create_track(type) -> TrackHandle`, `set_track_volume(id, db)`, `set_track_pan(id, pan)`, etc.
- [ ] Test: Create 3 tracks, adjust volume/pan, hear changes in mix

#### Rust: Audio Mixing Engine
- [ ] Implement mixer graph:
  - Audio/MIDI tracks → apply FX → sum to master
  - Send buses → Return tracks → mix back to master
- [ ] Apply volume/pan to each track
- [ ] Sum all tracks to stereo master output
- [ ] Test: Play 3 audio clips simultaneously → hear mixed output

#### Rust: Send Effects Architecture
- [ ] Implement Return tracks (no clips, only receive from sends)
- [ ] Add send amount per track (0-100%)
- [ ] Route send output to Return track input
- [ ] Mix Return track output back to master
- [ ] Test: Send track to reverb Return → hear wet signal mixed with dry

#### Rust: Built-in Effects (DSP)

**Parametric EQ:**
- [ ] Implement 4-band EQ (low shelf, 2× parametric, high shelf)
- [ ] Parameters: frequency, gain, Q
- [ ] Use biquad filter design
- [ ] Test: Boost 5 kHz → hear brighter sound

**Compressor:**
- [ ] Implement dynamics processor:
  - Threshold, ratio, attack, release, makeup gain
- [ ] Use RMS or peak detection
- [ ] Apply gain reduction based on input level
- [ ] Test: Apply to drums → hear more consistent volume

**Reverb:**
- [ ] Implement simple reverb (Freeverb algorithm or similar)
- [ ] Parameters: room size, damping, wet/dry mix
- [ ] Test: Apply to vocal → hear spacious sound

**Delay:**
- [ ] Implement delay line (circular buffer)
- [ ] Parameters: delay time (ms or synced to tempo), feedback, wet/dry mix
- [ ] Test: Apply to synth → hear echoes

**Limiter:**
- [ ] Implement brick-wall limiter (for master track)
- [ ] Parameters: threshold, release
- [ ] Prevent clipping (samples > 1.0)
- [ ] Test: Play loud audio → no distortion, peaks stay under 0 dBFS

**Chorus:**
- [ ] Implement modulated delay (LFO modulates delay time)
- [ ] Parameters: rate, depth, wet/dry mix
- [ ] Test: Apply to synth → hear thicker, detuned sound

#### Rust: FX Chain System
- [ ] Each track has `Vec<EffectHandle>` (ordered list)
- [ ] Process audio through FX chain in order
- [ ] Expose FFI: `add_effect_to_track(track_id, effect_type)`, `remove_effect(track_id, effect_id)`, `set_effect_param(effect_id, param_name, value)`
- [ ] Test: Add EQ → Compressor → Reverb to track → hear cascaded effects

#### Flutter: Mixer Panel UI
- [ ] Create `MixerView` (slide-in panel from right, or bottom)
- [ ] Display all tracks as vertical fader strips:
  - Fader (volume)
  - Pan knob
  - Mute/Solo buttons
  - Level meter (peak, VU-style)
  - Send knobs (if Return tracks exist)
- [ ] Add master fader on right
- [ ] Test: Adjust faders → hear volume changes in real-time

#### Flutter: Track Headers (Timeline)
- [ ] Display track names on left side of timeline
- [ ] Add buttons: Mute (M), Solo (S), Arm (⏺) *(Track arming deferred from M2)*
- [ ] Add FX button (opens effect list for that track)
- [ ] Wire arm button to recording system (enable per-track recording)
- [ ] Add input monitoring toggle per track *(Deferred from M2)*
- [ ] Test: Click mute → track goes silent
- [ ] Test: Arm track → press record → only armed tracks record

#### Flutter: Effect Plugin UI
- [ ] Create generic effect panel (slide-in or modal)
- [ ] Display effect parameters as knobs/sliders
- [ ] Update parameters in real-time (call FFI on drag)
- [ ] Example: EQ panel shows 4 bands with frequency/gain/Q sliders
- [ ] Test: Tweak EQ → hear immediate changes

#### Flutter: Peak Meters
- [ ] Request peak levels from Rust every 50ms: `get_track_peak_level(track_id) -> (left_db, right_db)`
- [ ] Render vertical bar meters (green → yellow → red gradient)
- [ ] Display in mixer panel and track headers
- [ ] Test: Play audio → meters move with signal

### Success Criteria
✅ Create multiple audio/MIDI tracks  
✅ Adjust volume/pan per track  
✅ Mute/solo tracks  
✅ Add effects to tracks (EQ, compressor, reverb, delay)  
✅ Adjust effect parameters and hear changes  
✅ Send tracks to shared reverb (Return track)  
✅ See peak meters for each track  
✅ Master limiter prevents clipping

### Risks & Mitigations
- **DSP algorithms are complex** → Start with simple implementations, optimize later (or use existing crates like `biquad`, `rubato`)
- **Real-time parameter updates cause clicks** → Smooth parameter changes over 10-20ms
- **Mixer UI is cluttered** → Keep it minimal for v1, add advanced features later

---

## M5: Save & Export

**Goal:** Save projects locally, load them, export to WAV/MP3/stems.

**Duration:** 2 weeks  
**Deliverable:** Work on a project, save it, close app, reopen, load project, export as WAV.

### Tasks

#### Rust: Project Serialization
- [ ] Design project file format (see `MVP_SPEC.md` for structure):
  ```
  MySong.solar/
    project.json
    audio/
    cache/
  ```
- [ ] Serialize project state to JSON:
  - Tracks (type, name, volume, pan, mute, solo)
  - Clips (position, length, file path, MIDI data)
  - Effects (type, parameters)
  - Tempo, time signature, sample rate
- [ ] Expose FFI: `save_project(path: String)`, `load_project(path: String)`
- [ ] Test: Save project → load project → verify all data is correct

#### Rust: Audio File Management
- [ ] Copy imported audio files to `project.solar/audio/` folder
- [ ] Use relative paths in project.json
- [ ] On load: resolve paths relative to project folder
- [ ] Test: Save project → move folder → load → audio still works

#### Rust: Autosave
- [ ] Implement autosave timer (every 2-3 minutes)
- [ ] Save to temp location: `~/.solar/autosave/`
- [ ] Don't interrupt audio thread
- [ ] Test: Make changes → wait 3 min → app crashes → relaunch → autosave recovery prompt

#### Rust: Export (Bounce/Render)
- [ ] Implement offline rendering:
  - Run audio graph without real-time constraint
  - Render from start to end (or selection)
  - Write to output file
- [ ] Export formats:
  - WAV (16/24-bit, 48 kHz)
  - MP3 (using `lame` or `minimp3` crate)
- [ ] Export stems: render each track individually
- [ ] Expose FFI: `export_project(path, format, bit_depth, include_stems)`
- [ ] Test: Export 30-second project → open in another DAW → verify audio is correct

#### Flutter: Save/Load UI
- [ ] Add File menu: New, Open, Save, Save As
- [ ] Use native file picker for Open/Save dialogs
- [ ] Implement "Save to Cloud" (deferred to M6, just show button for now)
- [ ] Show unsaved changes indicator (dot in title bar)
- [ ] Test: Create project → save → load → verify state is restored

#### Flutter: Export Dialog
- [ ] Create export dialog with options:
  - Format: WAV / MP3
  - Bit depth (WAV): 16 / 24
  - Sample rate: 44.1 / 48 / 96 kHz
  - Include stems: yes/no
- [ ] Show progress bar during export
- [ ] Test: Export → verify files are created

#### Flutter: Autosave Recovery
- [ ] On app launch: check for autosave files
- [ ] If found, show dialog: "Recover unsaved project?"
- [ ] Load autosave or discard
- [ ] Test: Crash app mid-session → relaunch → see recovery prompt

### Success Criteria
✅ Save project to `.solar` folder  
✅ Load project and restore all state  
✅ Autosave runs every 2-3 minutes  
✅ Recover project after crash  
✅ Export to WAV/MP3  
✅ Export stems (each track as separate file)  
✅ Exported audio sounds identical to in-app playback

### Risks & Mitigations
- **JSON gets huge for large projects** → Compress or use binary format later (v1.1)
- **Export is slow** → Show progress bar, run in background thread
- **File paths break on load** → Use relative paths, validate on load

---

## M6: Cloud & Versioning

**Goal:** Save snapshots to Firebase, browse version history, restore previous versions.

**Duration:** 2 weeks  
**Deliverable:** Click "Save to Cloud" → project uploads → see version list → restore old version.

### Tasks

#### Firebase Setup
- [ ] Create Firebase project
- [ ] Enable Firestore database
- [ ] Enable Firebase Authentication (email/password)
- [ ] Set up security rules (users can only access their own projects)
- [ ] Add Firebase SDK to Flutter app

#### Flutter: Authentication UI
- [ ] Create login screen (email + password)
- [ ] Create sign-up screen
- [ ] Implement "Forgot password" flow
- [ ] Store auth token locally (persist login)
- [ ] Test: Sign up → log in → stay logged in on app relaunch

#### Rust: Project Compression
- [ ] Compress `.solar` folder to `.zip` or `.tar.gz`
- [ ] Expose FFI: `compress_project(project_path) -> Vec<u8>` (returns bytes)
- [ ] Test: Compress 10 MB project → verify size is reduced

#### Flutter: Save to Cloud
- [ ] Add "Save to Cloud" button (Cmd+Shift+S)
- [ ] Compress project (call Rust FFI)
- [ ] Upload compressed bytes to Firebase Storage
- [ ] Create Firestore document with metadata:
  - Project name
  - Timestamp
  - User ID
  - File size
  - Storage path
- [ ] Show progress indicator during upload
- [ ] Test: Save to cloud → check Firebase console → verify file is uploaded

#### Flutter: Version History UI
- [ ] Create "Version History" panel (slide-in from right or modal)
- [ ] Query Firestore for user's project snapshots
- [ ] Display list:
  - Version name (auto-generated or user-editable)
  - Timestamp ("2 hours ago", "Jan 15, 2025")
  - File size
- [ ] Add "Restore" button per version
- [ ] Test: See list of snapshots sorted by date

#### Flutter: Restore Version
- [ ] On "Restore" click:
  - Download compressed project from Firebase Storage
  - Decompress to local temp folder
  - Load project
- [ ] Show progress during download
- [ ] Confirm before overwriting current project
- [ ] Test: Restore old version → verify project state matches snapshot

#### Flutter: Project Sharing (Basic)
- [ ] Add "Share Project" button
- [ ] Generate shareable link (Firebase dynamic link or simple URL with project ID)
- [ ] Copy link to clipboard
- [ ] Other user opens link → downloads read-only copy
- [ ] Test: Share link → open in browser → download project

### Success Criteria
✅ Sign up / log in with email + password  
✅ Click "Save to Cloud" → project uploads to Firebase  
✅ See list of previous snapshots  
✅ Restore old version and verify state is correct  
✅ Share project link (basic, read-only access)  
✅ Uploads/downloads show progress indicators

### Risks & Mitigations
- **Upload is slow for large projects** → Compress aggressively, show progress
- **Firebase costs too much at scale** → Start with free tier, add usage limits
- **Security rules are misconfigured** → Test with multiple users, review Firestore rules carefully

---

## M7: Polish & Beta Launch

**Goal:** Add final UX polish, keyboard shortcuts, command palette, crash recovery, fix bugs.

**Duration:** 2 weeks  
**Deliverable:** Stable, polished app ready for beta testers.

### Tasks

#### Flutter: Keyboard Shortcuts
- [ ] Implement shortcuts (see `MVP_SPEC.md` for list):
  - Space: Play/Stop
  - R: Record toggle
  - L: Loop on/off
  - Cmd+N: New project
  - Cmd+S: Save
  - Cmd+Shift+S: Save to Cloud
  - Cmd+Z / Cmd+Shift+Z: Undo/Redo
  - Cmd+E: Split at playhead
  - Cmd+G: Group tracks
  - 1/2/3/4: Tool cycle (Select/Draw/Erase/Blade)
  - Cmd+K: Command Palette
  - Arrow keys: Nudge selection
  - Q: Quantise
  - M/S: Mute/Solo focused track
  - Tab: Toggle Piano Roll ↔ Step Sequencer
- [ ] Test: Every shortcut works as expected

#### Flutter: Command Palette (⌘K)
- [ ] Create searchable command list:
  - "Add Audio Track"
  - "Add MIDI Track"
  - "Quantise Selection"
  - "Split Clip"
  - "Export to WAV"
  - etc. (all major actions)
- [ ] Fuzzy search (type "exp" → finds "Export to WAV")
- [ ] Execute command on Enter
- [ ] Show keyboard shortcut hints next to commands
- [ ] Test: Open palette → search → run commands

#### Rust: Undo/Redo System
- [ ] Implement command pattern for all mutations (add track, delete clip, change parameter, etc.)
- [ ] Store history stack (max 100 actions)
- [ ] Expose FFI: `undo()`, `redo()`
- [ ] Test: Make 10 changes → undo all → redo all → verify state is correct

#### Flutter: Clip Gain Handles
- [ ] Add gain handles to audio clips (small circles at top corners)
- [ ] Drag to adjust clip volume (-∞ to +12 dB)
- [ ] Show dB value while dragging
- [ ] Test: Drag handle down → clip gets quieter

#### Flutter: Sample Preview in Browser
- [ ] Add browser panel on left (Instruments / Effects / Samples / Files)
- [ ] Display sample library (from starter packs)
- [ ] Add play button (▶) next to each sample
- [ ] Click to preview (plays through default output)
- [ ] Drag sample to timeline to add clip
- [ ] Test: Click preview → hear sample → drag to timeline

#### Rust: Crash-Safe Recovery (Enhanced)
- [ ] Save app state to temp file every 1 minute (lighter than full autosave)
- [ ] On crash: write crash log to `~/.solar/crashes/`
- [ ] On relaunch: detect abnormal exit, offer recovery
- [ ] Test: Force crash → relaunch → verify recovery works

#### Flutter: Settings Panel *(Deferred from M2)*
- [ ] Create settings panel (slide-in from right or modal)
- [ ] Add "Audio" tab with:
  - [ ] Audio input device selector (list devices, select one) *(Deferred from M2)*
  - [ ] Audio output device selector
  - [ ] Sample rate selector (44.1/48/96 kHz)
  - [ ] Buffer size selector (64/128/256/512 samples)
- [ ] Add "Recording" tab with:
  - [ ] Count-in bars selector (0/1/2/4)
  - [ ] Metronome volume slider
  - [ ] Default tempo setting
- [ ] Wire to existing FFI functions from M2
- [ ] Test: Change input device → recording uses new device
- [ ] Test: Adjust buffer size → see latency change

#### Flutter: Recording Enhancements *(Deferred from M2)*
- [ ] Add count-in visual timer (4... 3... 2... 1...) during recording *(Deferred from M2)*
- [ ] Show beat indicator (highlights on each metronome click)
- [ ] Add recording waveform preview (show input levels during recording)
- [ ] Test: Start recording → see countdown → see beat flashes

#### UI Polish
- [ ] Add app icon (Solar logo: #2B2B2B + #A0A0A0 circle)
- [ ] Refine colors, spacing, alignment
- [ ] Add tooltips to all buttons
- [ ] Smooth animations (panel slide-ins, playhead scrubbing)
- [ ] Dark mode support (optional, if time permits)
- [ ] Test: App feels polished and professional

#### Bug Fixes & Optimization
- [ ] Profile audio performance (aim for <5% CPU at idle, <30% with 16 tracks)
- [ ] Fix any crashes or hangs discovered during testing
- [ ] Test on multiple macOS versions (12, 13, 14)
- [ ] Test on iPad (if time permits, or defer to v1.1)

#### Documentation
- [ ] Update `README.md` with:
  - Installation instructions
  - Quick start guide
  - Keyboard shortcuts
  - Link to `MVP_SPEC.md`
- [ ] Add `CHANGELOG.md` (list features in v1)
- [ ] Create GitHub issues for known bugs and v1.1 features

#### Beta Testing Prep
- [ ] Set up TestFlight (for macOS/iPad beta distribution)
- [ ] Create feedback form (Google Form or Typeform)
- [ ] Write beta tester guide (PDF or web page)
- [ ] Invite 5-10 beta testers

### Success Criteria
✅ All keyboard shortcuts work  
✅ Command palette is fast and searchable  
✅ Undo/redo works for all actions  
✅ Clip gain handles adjust volume smoothly  
✅ Sample preview plays before dragging to timeline  
✅ App recovers from crashes  
✅ UI is polished and bug-free  
✅ Beta testers can install and use the app

### Risks & Mitigations
- **Too many bugs to fix in 2 weeks** → Prioritize critical bugs, defer minor issues to v1.1
- **Performance issues on older Macs** → Profile and optimize hot paths, reduce track limit if needed
- **Beta testers find major UX issues** → Be prepared to iterate post-launch

---

## Post-M7: v1.1 Planning

After M7 ships, gather feedback and plan v1.1 features:

### Top Priorities for v1.1
1. **Time-stretch/warp** (elastic audio editing)
2. **Track freeze / bounce in place** (render plugins to audio)
3. **Collaboration** (soft real-time with per-clip locks)
4. **Web version** (edit/mix in browser, no recording)
5. **Mobile apps** (iOS, Android via same Rust codebase)
6. **Windows & Linux** (desktop builds)
7. **LUFS metering** (loudness standards)
8. **More samples & instruments** (guitars, bass, orchestral)
9. **CLAP plugin support**
10. **Group track folders**

---

## Development Best Practices

### Daily Workflow
1. **Start each day** by reviewing this doc and checking off completed tasks
2. **Commit often** (every feature or bug fix)
3. **Write tests** for critical audio code (playback, recording, export)
4. **Profile performance** weekly (use `cargo flamegraph` for Rust, Dart DevTools for Flutter)
5. **Document decisions** (add notes to this doc or `ARCHITECTURE.md`)

### Testing Strategy
- **Unit tests:** Rust DSP code (verify EQ frequency response, compressor gain reduction, etc.)
- **Integration tests:** FFI bridge (call Rust from Flutter, verify results)
- **Manual testing:** Play, record, mix, export — test every milestone deliverable
- **Performance tests:** Measure CPU usage, memory, latency

### When You Get Stuck
- **Audio issues:** Check [Rust Audio Discourse](https://rust-audio.discourse.group/), CPAL GitHub issues
- **Flutter issues:** Flutter Discord, StackOverflow
- **FFI issues:** `flutter_rust_bridge` GitHub, examples repo
- **DSP algorithms:** Read "Designing Audio Effect Plugins in C++" by Will Pirkle, or "The Scientist and Engineer's Guide to Digital Signal Processing"

---

## Appendix: Key Technical Decisions

### Why Rust?
- Memory-safe (no segfaults on audio thread)
- Compiles to native + WASM (future-proof for web/mobile)
- Growing audio ecosystem (`cpal`, `symphonia`, `fundsp`, etc.)
- Fast and efficient

### Why Flutter?
- Cross-platform UI (macOS, iPad, web, mobile from one codebase)
- Fast iteration (hot reload)
- Good performance (Skia rendering)

### Why Firebase?
- Simple auth + cloud storage
- Free tier generous for early users
- Well-integrated with Flutter

### Why Local-First?
- Works offline
- Fast (no network latency)
- User owns their data
- Cloud is optional enhancement

---

## Final Notes

This plan is **aggressive but achievable** if you work consistently (~15-20 hours/week). Adjust timelines based on your availability. The key is to **ship each milestone in a working state** — even if rough — and iterate.

**Good luck building Solar Audio! 🌑☀️**

---

**Document Version:** 1.0  
**Last Updated:** October 25, 2025  
**Next Review:** After M2 completion (✅ Complete - Ready for M3)