# Boojy Audio

A modern, cross-platform DAW (Digital Audio Workstation) designed for **speed, simplicity, and collaboration**.

## Overview

Boojy Audio combines professional workflows with beginner-friendly UX. Built with Flutter (UI) and Rust (audio engine), it's designed to work seamlessly across macOS, iPad, and eventually web, Windows, Linux, iOS, and Android.

**Current Status:** 🚧 M7 In Progress - VST3 Plugin Support (Native GUI Integration)

## Core Features (v1 MVP)

- 🎙️ **Record audio & MIDI** with metronome and count-in
- ✂️ **Edit with precision** - Piano roll, step sequencer, clip automation
- 🎚️ **Mix like a pro** - Send effects, built-in EQ/reverb/compressor/delay
- 🎹 **Built-in instruments** - Subtractive synth, drum sampler, piano ROMpler
- 📋 **Track duplication** - Right-click to duplicate tracks with instruments & effects
- 💾 **Save & export** - Local autosave, crash recovery, export to WAV/MP3/stems
- ☁️ **Cloud snapshots** - Version history via Firebase
- ⌨️ **Keyboard-driven** - Command palette (⌘K) and comprehensive shortcuts
- 🎨 **Modern UI** - Flat design, clip gain handles, sample preview

## Recent Updates (M7 - December 2025)

🚧 **VST3 Plugin Support - Native GUI Integration (In Progress):**
- VST3 plugin scanning and loading infrastructure ✅
- Plugin parameter automation and preset management ✅
- Native VST3 GUI support (C++/Rust/Dart/Swift layers) 🚧
  * C++ VST3 editor lifecycle functions (IPlugView creation, attachment, cleanup)
  * Swift platform views and window manager for macOS
  * Dart/Flutter UI integration with platform channels
  * "Open GUI" button in plugin parameter panel
  * Both docked and floating window modes planned
- Context-aware editor placement (instruments in Instrument tab, effects in FX tab)

## Previous Updates (M6.4 - December 2025)

✅ **Bug Fixes & Synth Refinements:**

- Virtual piano now works during pause/stop (audio stream stays active)
- MIDI clip bar-snapping (Ableton-style: clips align to bar boundaries)
- Simplified synthesizer architecture:
  * Single oscillator (sine/saw/square/triangle)
  * One-pole lowpass filter with cutoff control
  * ADSR envelope (attack, decay, sustain, release)
  * 8-voice polyphony with voice stealing

## Previous Updates (M6.3 - October 30, 2025)

✅ **Native macOS Menu Bar & Editor Panel:**
- Native macOS menu bar integration with PlatformMenuBar:
  * **Audio menu**: About, Services, Hide, Quit (⌘Q)
  * **File menu**: New (⌘N), Open (⌘O), Save (⌘S), Save As (⇧⌘S), Make Copy, Export Audio/MIDI, Settings (⌘,), Close (⌘W)
  * **Edit menu**: Undo/Redo (disabled), Cut/Copy/Paste (disabled - future)
  * **View menu**: Toggle Library (⌘L), Mixer (⌘M), Editor (⌘E), Piano (⌘P), Reset Layout, Zoom (disabled - future)
- Renamed "Bottom Panel" to "Editor Panel" throughout codebase for clarity
- Added View dropdown menu to toolbar with checkmarks for panel visibility
- All keyboard shortcuts working natively through macOS system
- Panel toggle methods for Library, Mixer, Editor, and Virtual Piano

## Previous Updates (M6.2 - October 30, 2025)

✅ **Toolbar Reorganization:**
- Reorganized transport bar with grouped controls for better workflow
- New layout: `[Logo] [File] | [Transport Controls] | [Metronome Piano Tap BPM Time Position] | [Mixer]`
- Enhanced File menu with 10 actions (New, Open, Save, Save As, Make Copy, Export Audio, Export MIDI, Project Settings, Close Project)
- Visual dividers between control groups for improved clarity
- File menu now uses Material icons instead of emojis

## Previous Updates (M6.1 - October 29, 2025)

✅ **MIDI & Instruments Complete:**
- Piano roll editor with FL Studio-style layout
- Polyphonic synthesizer (8 voices, ADSR, filter)
- Virtual piano keyboard (computer keyboard mapping)
- Instrument browser with drag-and-drop workflow
- MIDI clip playback during transport ✨
- Proper track deletion cleanup (no stuck notes) ✨
- Ableton-style drag from library → timeline

✨ = Fixed in M6.1 post-release patch

## Previous Updates (M5.6 - October 29, 2025)

✅ **Track Duplication (Ableton-style):**
- Right-click context menu on tracks
- Duplicates instruments with all parameters
- Deep copies effects (independent instances)
- Copies all clips and mixer settings
- Delete option with confirmation dialog

## Previous Updates (M5.5 - October 2025)

✅ **UI Redesign Complete:**
- Professional 3-panel layout (Library | Timeline | Mixer)
- Light grey theme for better visibility
- Master track repositioned to bottom of timeline and mixer
- Resizable panel dividers (drag to adjust, double-click to collapse)
- Panel sizes saved per project (restored on load)
- Compact zoom controls in timeline header
- Improved track creation UX (+ button with dropdown menu)

✅ **Core Features Working:**
- Audio recording with count-in and metronome
- Multi-track timeline with waveform display
- Track mixer with volume, pan, mute, solo
- Built-in effects (EQ, Compressor, Reverb, Delay, Chorus, Limiter)
- Project save/load with audio files
- WAV export

## Tech Stack

- **UI:** Flutter (cross-platform)
- **Audio Engine:** Rust (native + WASM-ready)
- **Cloud:** Firebase Firestore
- **Plugin Support:** VST3 (optional module)

## Architecture

```
┌─────────────────────────────────────┐
│   UI Layer (Flutter)                │  ← Cross-platform UI
└──────────────┬──────────────────────┘
               │ flutter_rust_bridge
┌──────────────▼──────────────────────┐
│   Audio Engine Core (Rust)          │  ← Platform-agnostic DSP
│   - Audio graph, DSP, automation    │
│   - Built-in FX & instruments       │
└──────────────┬──────────────────────┘
               │
    ┌──────────┴──────────┐
    │                     │
┌───▼─────┐         ┌────▼──────┐
│ Native  │         │  Web      │
│ I/O     │         │  I/O      │
│ (CPAL)  │         │ (WebAudio)│
└─────────┘         └───────────┘
```

## Project Structure

```
/engine         # Rust audio engine
  /core         # Platform-agnostic DSP & graph
  /dsp          # Built-in effects & instruments
  /host-vst3    # VST3 hosting (optional)
  /io           # I/O backends (native/web)
  /bridge       # FFI glue for Flutter
/ui             # Flutter application
  /lib          # Dart code
    /screens    # Main views
    /widgets    # Reusable components
    /state      # State management
  /assets       # Icons, fonts, samples
/packs          # Starter sample packs
/docs           # Documentation
```

## Setup Instructions

### Prerequisites

- **Rust:** `curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh`
- **Flutter:** [Install Flutter](https://docs.flutter.dev/get-started/install)
- **macOS:** Xcode Command Line Tools

### Build & Run

```bash
# Clone the repository
git clone https://github.com/tsbujacncl/boojy-audio.git
cd boojy-audio

# Build Rust engine
cd engine
cargo build --release

# Run Flutter app
cd ../ui
flutter run -d macos
```

## Development Roadmap

See [`docs/IMPLEMENTATION_PLAN.md`](docs/IMPLEMENTATION_PLAN.md) for detailed milestone breakdown.

| Milestone | Focus                       | Status      |
|-----------|-----------------------------|-------------|
| **M0**    | Project Setup               | ✅ Complete |
| **M1**    | Audio Playback              | ✅ Complete |
| **M2**    | Recording & Input           | ✅ Complete |
| **M3**    | Editing                     | ✅ Complete |
| **M4**    | Mixing & Effects            | ✅ Complete |
| **M5**    | Save & Export               | ✅ Complete |
| **M5.5**  | UI Polish & Resizable Panels| ✅ Complete |
| **M5.6**  | Track Duplication           | ✅ Complete |
| **M6**    | MIDI & Piano Roll           | ✅ Complete |
| **M6.1**  | MIDI Playback Fixes         | ✅ Complete |
| **M6.2**  | Toolbar Reorganization      | ✅ Complete |
| **M6.3**  | Native Menu Bar & Editor    | ✅ Complete |
| **M6.4**  | Bug Fixes & Synth Refinements | ✅ Complete |
| **M7**    | VST3 Plugin Support         | 🚧 In Progress |
| **M8**    | Stock Instruments           | 📋 Planned  |
| **M9**    | Polish & UX                 | 📋 Planned  |
| **M10**   | Beta Testing & Launch       | 📋 Planned  |

## Documentation

- [MVP Specification](docs/MVP_SPEC.md) - Full feature set and design decisions
- [Implementation Plan](docs/IMPLEMENTATION_PLAN.md) - Milestone breakdown and timelines

## Keyboard Shortcuts (v1)

| Shortcut              | Action                  |
|-----------------------|-------------------------|
| Space                 | Play/Stop               |
| R                     | Record toggle           |
| B                     | Toggle Library Panel    |
| M                     | Toggle Mixer Panel      |
| Cmd+K                 | Command Palette         |
| Cmd+S                 | Save                    |
| Cmd+Shift+S           | Save to Cloud           |
| Cmd+Z / Cmd+Shift+Z   | Undo/Redo              |
| Tab                   | Toggle Piano Roll ↔ Step Sequencer |

[Full shortcut reference](docs/MVP_SPEC.md#keyboard-shortcuts-starter-set)

## Contributing

This project is currently in early development (pre-v1). Contributions will be welcomed after beta launch (M10).

## License

TBD (To be decided before v1 launch)

## Contact

- **GitHub:** [@tsbujacncl](https://github.com/tsbujacncl)
- **Repository:** [boojy-audio](https://github.com/tsbujacncl/boojy-audio)

---

**Built with ❤️ using Rust and Flutter**

