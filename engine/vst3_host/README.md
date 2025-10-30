# VST3 Host Wrapper

This directory contains a C++ wrapper for the Steinberg VST3 SDK, providing a C ABI for use from Rust.

## Status

**✅ Completed:**
- VST3 SDK integration (git submodule)
- C++ wrapper with clean C ABI (`vst3_host.h`, `vst3_host.cpp`)
- CMake build system with Xcode generator support
- Pre-built static libraries for macOS (arm64 + x86_64)
- Rust FFI bindings (`src/vst3_host.rs`)
- Compilation succeeds (`cargo check` works)

**🚧 Known Issues:**
- Linking for tests/binaries fails - `module_mac.mm` not included in `libsdk_hosting.a`
- Need to rebuild SDK with proper Objective-C++ file inclusion
- Workaround: Use pre-built libraries in `../lib/` for now

## Building

### Standalone C++ Build

```bash
cd vst3_host
mkdir -p build && cd build
cmake -G Xcode ..
cmake --build . --config Release --target vst3_host
```

This creates `build/lib/Release/libvst3_host.a` (universal binary).

### Rebuild All Libraries

To regenerate all VST3 libraries (when fixing the module_mac.mm issue):

```bash
cd vst3_host/build
cmake --build . --config Release
cp lib/Release/*.a ../../lib/
```

## Architecture

```
vst3_host.h          # C API header
vst3_host.cpp        # C++ implementation using VST3 SDK
CMakeLists.txt       # Build configuration
../lib/*.a           # Pre-built libraries (committed)
../src/vst3_host.rs  # Rust FFI bindings
```

## API Overview

The C API provides:
- Plugin scanning (`vst3_scan_directory`, `vst3_scan_standard_locations`)
- Plugin loading (`vst3_load_plugin`, `vst3_unload_plugin`)
- Audio processing (`vst3_process_audio`)
- MIDI events (`vst3_process_midi_event`)
- Parameter management (`vst3_get/set_parameter_value`)
- State persistence (`vst3_get/set_state`)

## Next Steps

To fix the linking issue:
1. Update `vst3sdk/public.sdk/source/vst/hosting/CMakeLists.txt` to include `module_mac.mm`
2. Rebuild with `cmake --build . --config Release`
3. Copy updated `lib/Release/*.a` to `../lib/`
4. Test with `cargo test vst3`

## License

The VST3 SDK is licensed under the Steinberg VST3 license.
See `vst3sdk/LICENSE.txt` for details.
