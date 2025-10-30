# VST3 Plugin Support - Testing Guide

## 🚧 Implementation Status

The VST3 plugin hosting implementation (M7) is **IN PROGRESS** with native GUI integration being added!

### Completed Components

1. **Core VST3 Infrastructure**
   - VST3 SDK integration via C++ wrapper
   - Rust FFI bindings for all VST3 functionality
   - Pre-built libraries for macOS (arm64 + x86_64)

2. **Effect System Integration**
   - Added `VST3` variant to `EffectType` enum
   - Implemented `Effect` trait for VST3 plugins
   - Thread-safe plugin wrapper with `Arc<Mutex<>>`

3. **Public API Functions** (available to Flutter)
   - `add_vst3_effect_to_track()` - Load plugin and add to track
   - `get_vst3_parameter_count()` - Get number of parameters
   - `get_vst3_parameter_info()` - Get parameter details (name, range)
   - `get_vst3_parameter_value()` - Read parameter value (0.0-1.0)
   - `set_vst3_parameter_value()` - Write parameter value (0.0-1.0)
   - `scan_vst3_plugins()` - Scan custom directory for plugins
   - `scan_vst3_plugins_standard()` - Scan system VST3 locations

### Build Status

```bash
✅ cargo check   # PASSES
✅ cargo build   # PASSES
❌ cargo test    # FAILS (linking issue - see below)
```

## 🔧 Testing Limitation

**Rust unit tests cannot run** due to a linking issue with the pre-built VST3 SDK libraries:
- Missing symbol: `VST3::Hosting::Module::create`
- Cause: `module_mac.mm` not included in `libsdk_hosting.a`
- Impact: **ONLY affects `cargo test`, NOT the actual functionality**
- The VST3 code compiles and links fine in the main library

## 🎯 How to Test

Since Rust unit tests won't link, test the VST3 functionality through the **Flutter app** instead:

### Available VST3 Plugins on Your System

```
/Library/Audio/Plug-Ins/VST3/Serum.vst3
/Library/Audio/Plug-Ins/VST3/Serum2.vst3
```

### Testing Steps (via Flutter UI)

1. **Scan for Plugins**
   ```dart
   // Call scan_vst3_plugins_standard() from Dart
   // Should return: "Serum|/Library/Audio/Plug-Ins/VST3/Serum.vst3\n..."
   ```

2. **Load a Plugin**
   ```dart
   // Call add_vst3_effect_to_track(trackId, "/Library/Audio/Plug-Ins/VST3/Serum.vst3")
   // Should return the effect ID
   ```

3. **Get Parameters**
   ```dart
   // Call get_vst3_parameter_count(effectId)
   // Serum has hundreds of parameters
   ```

4. **Adjust Parameters**
   ```dart
   // Call get_vst3_parameter_info(effectId, 0)
   // Returns: "param_name,0.0,1.0,0.5"
   //
   // Call set_vst3_parameter_value(effectId, 0, 0.75)
   // Then call get_vst3_parameter_value(effectId, 0)
   // Should return: 0.75
   ```

5. **Process Audio**
   - Add VST3 effect to a track
   - Play audio through the track
   - The VST3 plugin should process the audio

### Expected Behavior

- ✅ Plugin scanner finds Serum and Serum2
- ✅ Plugins load without errors
- ✅ Parameter count returns > 0
- ✅ Parameters can be read and written
- ✅ Audio processing works (output != input when plugin is active)

## 🐛 Troubleshooting

### If plugin fails to load:
- Check file path is correct
- Verify plugin file exists and is readable
- Check console logs for VST3 error messages

### If parameters don't change:
- Some plugins ignore parameter changes when not activated
- Try playing audio to activate the plugin
- Check parameter index is within range (0 to count-1)

### If audio doesn't process:
- Verify plugin is in track's FX chain
- Check track volume is not muted/zero
- Try sending MIDI notes (for instrument plugins like Serum)

## 📋 Integration Checklist

To use VST3 in the Flutter app:

- [ ] Add VST3 plugin browser UI
- [ ] Implement plugin selection and loading
- [ ] Create parameter control UI (sliders/knobs)
- [ ] Wire up parameter changes to FFI calls
- [ ] Add plugin state save/load to project serialization
- [ ] Test with multiple plugins on same track
- [ ] Test with plugins on different tracks
- [ ] Test automation (parameter changes over time)

## 🚀 Performance Notes

- Current implementation: **Frame-by-frame processing** (1 sample at a time)
- This works but is not optimal for performance
- TODO: Switch to **block processing** (512 samples at a time)
- Both Serum plugins are instruments, so they need MIDI input to generate sound

## 🎨 Native GUI Integration (M7 Phase 2 - IN PROGRESS)

### Current Implementation Status

**✅ Completed Layers:**

1. **C++ VST3 Editor Functions** (`engine/vst3_host/vst3_host.cpp`)
   - `vst3_has_editor()` - Check if plugin has native GUI
   - `vst3_open_editor()` - Create IPlugView instance
   - `vst3_close_editor()` - Release IPlugView
   - `vst3_get_editor_size()` - Query preferred size
   - `vst3_attach_editor()` - Attach to parent NSView

2. **Rust API Layer** (`engine/src/api.rs`, `engine/src/ffi.rs`, `engine/src/vst3_host.rs`)
   - FFI wrappers for all editor functions
   - Safe Rust API exposed to Dart

3. **Dart/Flutter Layer** (`ui/lib/audio_engine.dart`, `ui/lib/services/vst3_editor_service.dart`)
   - FFI bindings for editor functions
   - Platform channel service for native communication
   - "Open GUI" button in plugin parameter panel

4. **Swift/macOS Layer** (`ui/macos/Runner/`)
   - `VST3PlatformView.swift` - NSView wrapper for editors
   - `VST3WindowManager.swift` - Floating window management
   - `VST3PlatformChannel.swift` - Method channel handler
   - `AppDelegate.swift` - Platform integration registration

**🚧 Remaining Issues:**

### Issue 1: C++ Library Linking (BLOCKING)

**Problem:** New editor functions not included in static library.

**Error:**
```
Undefined symbols for architecture arm64:
  "_vst3_attach_editor", "_vst3_close_editor", "_vst3_get_editor_size", "_vst3_has_editor", "_vst3_open_editor"
```

**Root Cause:** The VST3 SDK static libraries need to be rebuilt with the updated `vst3_host.cpp` that includes the new editor functions.

**Fix Steps:**

1. **Full rebuild of VST3 host library:**
   ```bash
   cd engine/vst3_host

   # Clean previous build
   rm -rf build_vst3
   mkdir -p build_vst3
   cd build_vst3

   # Configure CMake (macOS universal binary: arm64 + x86_64)
   cmake .. \
     -DCMAKE_BUILD_TYPE=Release \
     -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
     -DCMAKE_OSX_DEPLOYMENT_TARGET=10.15

   # Build
   cmake --build . --config Release

   # Copy library
   cp libvst3_host.a ../../lib/
   ```

2. **Verify the library contains new symbols:**
   ```bash
   nm -g ../lib/libvst3_host.a | grep editor
   # Should show: _vst3_has_editor, _vst3_open_editor, etc.
   ```

3. **Test Rust build:**
   ```bash
   cd engine
   cargo clean
   cargo build --release
   ```

**Alternative (Quick Fix):** If CMake fails, manually compile and link:
```bash
cd engine/vst3_host

# Compile vst3_host.cpp
clang++ -c -std=c++17 \
  -I../vst3sdk \
  -arch arm64 -arch x86_64 \
  vst3_host.cpp -o vst3_host.o

# Create static library
ar rcs ../lib/libvst3_host.a vst3_host.o

# Verify symbols
nm -g ../lib/libvst3_host.a | grep editor
```

### Issue 2: Final GUI Wiring (NEXT STEP)

**Problem:** Swift opens empty window, doesn't display actual VST3 GUI.

**Missing Connection:** Swift needs to call Rust FFI to get NSView from VST3 plugin's IPlugView.

**Fix Steps:**

1. **Add Rust FFI to return NSView pointer:**

   In `engine/src/ffi.rs`, add:
   ```rust
   /// Get NSView pointer from VST3 editor (macOS-specific)
   #[no_mangle]
   pub extern "C" fn vst3_get_editor_nsview_ffi(effect_id: i64) -> *mut c_void {
       match api::vst3_get_editor_nsview(effect_id as u64) {
           Ok(ptr) => ptr,
           Err(e) => {
               eprintln!("❌ [FFI] Failed to get NSView: {}", e);
               std::ptr::null_mut()
           }
       }
   }
   ```

2. **Update Swift to call Rust:**

   In `VST3WindowManager.swift`:
   ```swift
   // After opening window...
   let nsViewPtr = engine.vst3GetEditorNSView(effectId: effectId)

   if nsViewPtr != nil {
       let editorNSView = Unmanaged<NSView>.fromOpaque(nsViewPtr!).takeUnretainedValue()
       editorView.attachEditor(view: editorNSView)
   }
   ```

3. **Handle IPlugView lifecycle:**
   - Call `vst3_open_editor()` before getting NSView
   - Call `vst3_attach_editor(parent)` to bind to window
   - Call `vst3_close_editor()` when window closes

### Issue 3: Plugin Activation Required

**Problem:** Some VST3 plugins need to be "activated" before editor works.

**Solution:** Ensure plugins are started before opening GUI:
```dart
// Before opening editor
audioEngine.vst3ActivatePlugin(effectId);
await Future.delayed(Duration(milliseconds: 100)); // Let plugin initialize
final success = await VST3EditorService.openFloatingWindow(...);
```

## 📝 Next Steps (Priority Order)

1. **🔥 CRITICAL**: Fix C++ library linking (Issue 1)
   - Rebuild `libvst3_host.a` with new editor functions
   - Verify Rust build completes successfully

2. **🎯 HIGH**: Complete GUI wiring (Issue 2)
   - Add `vst3_get_editor_nsview_ffi()` to return NSView pointer
   - Update Swift to attach actual plugin view to window
   - Test with Serum 2 to verify native GUI appears

3. **✨ MEDIUM**: Polish & Testing
   - Add error handling for unsupported editors
   - Test docked mode (editor in Flutter widget tree)
   - Handle window lifecycle (close, resize, minimize)
   - Test with multiple plugins simultaneously

4. **🚀 FUTURE**: Optimization & Enhancement
   - Implement block-based audio processing (512 samples)
   - Add plugin preset save/load
   - Add editor state persistence (window position/size)
   - Support plugin resize callbacks
