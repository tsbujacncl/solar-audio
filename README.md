# Solar Audio 🌑☀️

A modern, cross-platform DAW (Digital Audio Workstation) designed for **speed, simplicity, and collaboration**.

## Overview

Solar Audio combines professional workflows with beginner-friendly UX. Built with Flutter (UI) and Rust (audio engine), it's designed to work seamlessly across macOS, iPad, and eventually web, Windows, Linux, iOS, and Android.

**Current Status:** ✅ M5.5 Complete - Save/Export + UI Polish | Ready for M6 (MIDI)

## Core Features (v1 MVP)

- 🎙️ **Record audio & MIDI** with metronome and count-in
- ✂️ **Edit with precision** - Piano roll, step sequencer, clip automation
- 🎚️ **Mix like a pro** - Send effects, built-in EQ/reverb/compressor/delay
- 🎹 **Built-in instruments** - Subtractive synth, drum sampler, piano ROMpler
- 💾 **Save & export** - Local autosave, crash recovery, export to WAV/MP3/stems
- ☁️ **Cloud snapshots** - Version history via Firebase
- ⌨️ **Keyboard-driven** - Command palette (⌘K) and comprehensive shortcuts
- 🎨 **Modern UI** - Flat design, clip gain handles, sample preview

## Recent Updates (M5.5 - October 2025)

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

### Build & Run (Coming Soon - M0 in progress)

```bash
# Clone the repository
git clone https://github.com/tsbujacncl/solar-audio.git
cd solar-audio

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
| **M6**    | MIDI & Piano Roll           | 🚧 Ready    |
| **M7**    | VST3 Plugin Support         | 📋 Planned  |
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
- **Repository:** [solar-audio](https://github.com/tsbujacncl/solar-audio)

---

**Built with ❤️ using Rust and Flutter**

