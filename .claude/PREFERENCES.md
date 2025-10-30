# Development Preferences

## Git Commits

**DO NOT** include "Generated with Claude Code" or similar attributions in commit messages.

Write professional commit messages that describe the changes without mentioning AI assistance.

## Building & Running

**DO NOT** run `flutter build` after making changes.

### Important: Rust Engine Build Mode

The Flutter app uses a **symlink** at `ui/macos/Runner/libengine.dylib` that points to:
```
engine/target/release/libengine.dylib
```

**After making Rust changes, you MUST build in release mode:**
```bash
cd engine
cargo build --release
```

Then the user will run:
```bash
cd ../ui
flutter clean
flutter run -d macos
```

**Note:** `cargo build` (debug mode) builds to `target/debug/` which Flutter won't pick up!
