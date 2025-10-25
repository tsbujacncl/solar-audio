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

// ============================================================================
// M1: Audio Playback FFI
// ============================================================================

/// Initialize the audio graph
#[no_mangle]
pub extern "C" fn init_audio_graph_ffi() -> *mut c_char {
    match api::init_audio_graph() {
        Ok(msg) => CString::new(msg).unwrap().into_raw(),
        Err(e) => CString::new(format!("Error: {}", e)).unwrap().into_raw(),
    }
}

/// Load an audio file and return clip ID
#[no_mangle]
pub extern "C" fn load_audio_file_ffi(path: *const c_char) -> i64 {
    if path.is_null() {
        return -1;
    }
    
    let c_str = unsafe { std::ffi::CStr::from_ptr(path) };
    let path_str = match c_str.to_str() {
        Ok(s) => s,
        Err(_) => return -1,
    };
    
    match api::load_audio_file_api(path_str.to_string()) {
        Ok(id) => id as i64,
        Err(_) => -1,
    }
}

/// Start playback
#[no_mangle]
pub extern "C" fn transport_play_ffi() -> *mut c_char {
    match api::transport_play() {
        Ok(msg) => CString::new(msg).unwrap().into_raw(),
        Err(e) => CString::new(format!("Error: {}", e)).unwrap().into_raw(),
    }
}

/// Pause playback
#[no_mangle]
pub extern "C" fn transport_pause_ffi() -> *mut c_char {
    match api::transport_pause() {
        Ok(msg) => CString::new(msg).unwrap().into_raw(),
        Err(e) => CString::new(format!("Error: {}", e)).unwrap().into_raw(),
    }
}

/// Stop playback
#[no_mangle]
pub extern "C" fn transport_stop_ffi() -> *mut c_char {
    match api::transport_stop() {
        Ok(msg) => CString::new(msg).unwrap().into_raw(),
        Err(e) => CString::new(format!("Error: {}", e)).unwrap().into_raw(),
    }
}

/// Seek to position in seconds
#[no_mangle]
pub extern "C" fn transport_seek_ffi(position_seconds: f64) -> *mut c_char {
    match api::transport_seek(position_seconds) {
        Ok(msg) => CString::new(msg).unwrap().into_raw(),
        Err(e) => CString::new(format!("Error: {}", e)).unwrap().into_raw(),
    }
}

/// Get playhead position in seconds
#[no_mangle]
pub extern "C" fn get_playhead_position_ffi() -> f64 {
    api::get_playhead_position().unwrap_or(0.0)
}

/// Get transport state (0=Stopped, 1=Playing, 2=Paused)
#[no_mangle]
pub extern "C" fn get_transport_state_ffi() -> i32 {
    api::get_transport_state().unwrap_or(0)
}

/// Get clip duration in seconds
#[no_mangle]
pub extern "C" fn get_clip_duration_ffi(clip_id: u64) -> f64 {
    api::get_clip_duration(clip_id).unwrap_or(0.0)
}

/// Get waveform peaks
/// Returns pointer to float array, and writes the length to out_length
/// Caller must free the returned array with free_waveform_peaks_ffi
#[no_mangle]
pub extern "C" fn get_waveform_peaks_ffi(
    clip_id: u64,
    resolution: usize,
    out_length: *mut usize,
) -> *mut f32 {
    match api::get_waveform_peaks(clip_id, resolution) {
        Ok(peaks) => {
            let len = peaks.len();
            let ptr = peaks.as_ptr() as *mut f32;
            std::mem::forget(peaks); // Don't drop the Vec
            
            if !out_length.is_null() {
                unsafe {
                    *out_length = len;
                }
            }
            
            ptr
        }
        Err(_) => {
            if !out_length.is_null() {
                unsafe {
                    *out_length = 0;
                }
            }
            std::ptr::null_mut()
        }
    }
}

/// Free waveform peaks array
#[no_mangle]
pub extern "C" fn free_waveform_peaks_ffi(ptr: *mut f32, length: usize) {
    if !ptr.is_null() {
        unsafe {
            let _ = Vec::from_raw_parts(ptr, length, length);
        }
    }
}

