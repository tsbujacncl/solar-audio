/// Simple C-compatible FFI layer for M0
/// This will be replaced with flutter_rust_bridge in M1
use std::ffi::CString;
use std::os::raw::c_char;
use crate::api;

/// Play a sine wave - C-compatible wrapper
/// Returns a success message as a C string
#[no_mangle]
pub extern "C" fn play_sine_wave_ffi(frequency: f32, duration_ms: u32) -> *mut c_char {
    match api::play_sine_wave(frequency, duration_ms) {
        Ok(msg) => CString::new(msg).unwrap().into_raw(),
        Err(e) => CString::new(format!("Error: {}", e)).unwrap().into_raw(),
    }
}

/// Initialize audio engine - C-compatible wrapper
#[no_mangle]
pub extern "C" fn init_audio_engine_ffi() -> *mut c_char {
    match api::init_audio_engine() {
        Ok(msg) => CString::new(msg).unwrap().into_raw(),
        Err(e) => CString::new(format!("Error: {}", e)).unwrap().into_raw(),
    }
}

/// Free a string allocated by Rust
#[no_mangle]
pub extern "C" fn free_rust_string(ptr: *mut c_char) {
    if !ptr.is_null() {
        unsafe {
            let _ = CString::from_raw(ptr);
        }
    }
}

