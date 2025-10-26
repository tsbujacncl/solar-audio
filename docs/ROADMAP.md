# Solar Audio - Development Roadmap

**Last Updated:** October 26, 2025  
**Current Status:** M5 Complete, M6 In Progress

---

## Timeline Overview

```
Week 0    Week 10   Week 15   Week 22
  │         │         │         │
  M0 ─ M5 ─┤         │         │
           M6 ─ M8 ──┤         │
                    M9 ── M10 ─┤
                             Beta: Dec 1
```

**Weeks 0-10:** Foundation (audio, recording, mixing) ✅  
**Weeks 11-15:** MIDI, VST3, Instruments 🚧  
**Weeks 16-22:** Polish, Beta Launch 📋  
**Target Beta:** December 1, 2025

---

## Current Status

**✅ Complete:**
- M0: Project Setup
- M1: Core Playback
- M2: Recording
- M3: Editing
- M4: Mixing
- M5: Save & Export

**🚧 In Progress:**
- M6: MIDI & Piano Roll

**📋 Upcoming:**
- M7: VST3 Plugin Support
- M8: Stock Instruments
- M9: Polish & UX
- M10: Beta Testing & Launch

---

## Milestones

### M6: MIDI & Piano Roll (Weeks 11-13) 🚧

- Piano roll with velocity lane (FL Studio-style)
- Virtual piano (bottom panel)
- MIDI recording (always listen to input)
- Quantize options
- Note editing (draw, move, resize, delete)
- Computer keyboard mapping (ASDF keys)

**Target:** Mid-November 2025

---

### M7: VST3 Plugin Support (Weeks 14-15)

- Scan installed VST3 plugins
- Load third-party plugins
- Plugin UI in separate window (Ableton-style)
- Parameter save/load with projects
- Compatible with commercial plugins

**Target:** Late November 2025

---

### M8: Stock Instruments (Weeks 16-18)

Build 5 high-quality instruments:
- Piano (sampled grand)
- Synth (2-oscillator subtractive)
- Sampler (drag audio, map to keys)
- Drums (16-pad machine, 808/909 kits)
- Bass (808-style sub bass)

**Target:** Mid-December 2025

---

### M9: Polish & UX (Weeks 19-20)

- Tooltips on all buttons
- Built-in tips system
- Error handling (toast notifications + banners)
- Preferences window (Audio, MIDI, File, Appearance)
- Track colors (auto-assign from palette)
- Keyboard shortcuts (Ableton-style)
- Bug fixes and optimization

**Target:** Late December 2025

---

### M10: Beta Testing & Launch (Weeks 21-22)

**Week 1: Private Beta**
- Invite small group of testers
- Collect feedback
- Fix critical bugs

**Week 2: Public Beta & Launch**
- Public beta on GitHub
- Tutorial videos and documentation
- v1.0 launch announcement
- Reddit, Hacker News, YouTube

**Target Beta Launch:** December 1, 2025

---

## Feature Priority

### v1.0 (Launch)

**Must-Have:**
- ✅ Audio recording/playback
- ✅ Multiple tracks with mixing
- ✅ Built-in effects (EQ, Compressor, Reverb, Delay, Limiter)
- ✅ Save/load/export
- 🚧 MIDI editing with piano roll
- 📋 VST3 plugin support
- 📋 5 stock instruments
- 📋 Windows release (alongside macOS)

**Won't-Have (v1.0):**
- Cloud saving → Future (TBD)
- Session View / DJ Mode → v1.2+
- Send effects → v1.2+
- MIDI learn → v1.2+
- Templates → v1.1
- Collaboration → Future (TBD)
- iPad/iPhone → v1.1
- Linux → Future (TBD)

---

### v1.1 (January 2026)

**Focus:** iPad + More Instruments

- iPad version (shared SwiftUI code)
- Touch-optimized UI
- Apple Pencil support
- 10-15 additional instruments
- Better onboarding

---

### v1.2+ (Timeline TBD)

**Focus:** Live Performance & Advanced Features

- MIDI learn (controller mapping)
- DJ/Live mode
- Session View (clip launching)
- Send effects (reverb/delay buses)
- Loop recording
- Collaboration features
- Linux support
- Cloud saving

---

## Launch Plan

### Phase 1: Private Beta

- Small group of trusted testers
- Focus on bug finding and UX feedback
- Iterate quickly on issues

### Phase 2: Public Beta

- Open beta on GitHub
- Announce on Reddit, Twitter
- Gather wider feedback
- Final bug fixes

### Phase 3: v1.0 Launch

- Official release on GitHub
- Tutorial videos on YouTube
- Launch posts on Reddit, Hacker News
- Update website and documentation

### Phase 4: Post-Launch

- Monitor feedback and issues
- Fix critical bugs
- Plan v1.1 based on user requests

---

## Technology

**Core:**
- Frontend: Flutter (Dart) + SwiftUI
- Backend: Rust (audio engine)
- FFI: C bindings (Rust ↔ Dart)

**Audio:**
- CPAL (cross-platform audio)
- Symphonia (audio decoding)
- VST3 plugin hosting

**Platform:**
- macOS 12+ (Monterey or later)
- Windows 10+ (v1.0 release alongside macOS)
- Intel + Apple Silicon (M1/M2/M3/M4)

**Future:**
- iPad/iPhone (v1.1 - shared codebase)
- Linux (TBD)
- Web (Flutter Web + WebAssembly - TBD)

---

## Contributing

Solar Audio is open-source (GPL v3). Contributions welcome!

**How to help:**
- Report bugs (GitHub Issues)
- Suggest features (GitHub Discussions)
- Contribute code (Pull Requests)
- Create sample packs and presets
- Write tutorials and documentation

---

## Communication

**Monthly Dev Vlogs/Blogs:**
- YouTube dev vlogs OR blog posts
- Behind-the-scenes development
- Demos and progress updates
- Posted once per month during development

**Launch Updates:**
- GitHub Discussions for announcements
- Twitter/X (@solaraudio)
- Reddit posts for major milestones

---

## Next Steps

**This Week:**
- Continue M6 (piano roll implementation)
- Test MIDI recording with hardware
- Update documentation

**This Month:**
- Complete M6
- Start M7 (VST3 support)
- Post monthly dev update (vlog or blog)

**By December 1:**
- Complete M7-M9
- Private beta testing
- Public beta launch 🚀

---

**Let's build the future of music production! 🌑☀️**