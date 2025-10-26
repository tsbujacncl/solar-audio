/// Simple C-compatible FFI layer for M0
/// This will be replaced with flutter_rust_bridge in M1
use std::ffi::{CStr, CString};
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

// ============================================================================
// M2: Recording & Input FFI
// ============================================================================

/// Start recording audio
#[no_mangle]
pub extern "C" fn start_recording_ffi() -> *mut c_char {
    match api::start_recording() {
        Ok(msg) => CString::new(msg).unwrap().into_raw(),
        Err(e) => CString::new(format!("Error: {}", e)).unwrap().into_raw(),
    }
}

/// Stop recording and return clip ID (-1 if no recording)
#[no_mangle]
pub extern "C" fn stop_recording_ffi() -> i64 {
    match api::stop_recording() {
        Ok(Some(clip_id)) => clip_id as i64,
        Ok(None) => -1,  // No recording to stop
        Err(e) => {
            eprintln!("❌ [FFI] Stop recording failed: {}", e);
            -1
        }
    }
}

/// Get recording state (0=Idle, 1=CountingIn, 2=Recording)
#[no_mangle]
pub extern "C" fn get_recording_state_ffi() -> i32 {
    api::get_recording_state().unwrap_or_else(|e| {
        eprintln!("❌ [FFI] Get recording state failed: {}", e);
        0  // Return Idle state on error
    })
}

/// Get recorded duration in seconds
#[no_mangle]
pub extern "C" fn get_recorded_duration_ffi() -> f64 {
    api::get_recorded_duration().unwrap_or_else(|e| {
        eprintln!("❌ [FFI] Get recorded duration failed: {}", e);
        0.0
    })
}

/// Set count-in duration in bars
#[no_mangle]
pub extern "C" fn set_count_in_bars_ffi(bars: u32) -> *mut c_char {
    match api::set_count_in_bars(bars) {
        Ok(msg) => CString::new(msg).unwrap().into_raw(),
        Err(e) => CString::new(format!("Error: {}", e)).unwrap().into_raw(),
    }
}

/// Get count-in duration in bars
#[no_mangle]
pub extern "C" fn get_count_in_bars_ffi() -> u32 {
    api::get_count_in_bars().unwrap_or(2)
}

/// Set tempo in BPM
#[no_mangle]
pub extern "C" fn set_tempo_ffi(bpm: f64) -> *mut c_char {
    match api::set_tempo(bpm) {
        Ok(msg) => CString::new(msg).unwrap().into_raw(),
        Err(e) => CString::new(format!("Error: {}", e)).unwrap().into_raw(),
    }
}

/// Get tempo in BPM
#[no_mangle]
pub extern "C" fn get_tempo_ffi() -> f64 {
    api::get_tempo().unwrap_or(120.0)
}

/// Enable or disable metronome
#[no_mangle]
pub extern "C" fn set_metronome_enabled_ffi(enabled: i32) -> *mut c_char {
    match api::set_metronome_enabled(enabled != 0) {
        Ok(msg) => CString::new(msg).unwrap().into_raw(),
        Err(e) => CString::new(format!("Error: {}", e)).unwrap().into_raw(),
    }
}

/// Check if metronome is enabled
#[no_mangle]
pub extern "C" fn is_metronome_enabled_ffi() -> i32 {
    if api::is_metronome_enabled().unwrap_or(true) { 1 } else { 0 }
}

// ============================================================================
// M3: MIDI FFI
// ============================================================================

/// Start MIDI input
#[no_mangle]
pub extern "C" fn start_midi_input_ffi() -> *mut c_char {
    match api::start_midi_input() {
        Ok(msg) => CString::new(msg).unwrap().into_raw(),
        Err(e) => CString::new(format!("Error: {}", e)).unwrap().into_raw(),
    }
}

/// Stop MIDI input
#[no_mangle]
pub extern "C" fn stop_midi_input_ffi() -> *mut c_char {
    match api::stop_midi_input() {
        Ok(msg) => CString::new(msg).unwrap().into_raw(),
        Err(e) => CString::new(format!("Error: {}", e)).unwrap().into_raw(),
    }
}

/// Set synthesizer oscillator type (0=Sine, 1=Saw, 2=Square)
#[no_mangle]
pub extern "C" fn set_synth_oscillator_type_ffi(osc_type: i32) -> *mut c_char {
    match api::set_synth_oscillator_type(osc_type) {
        Ok(msg) => CString::new(msg).unwrap().into_raw(),
        Err(e) => CString::new(format!("Error: {}", e)).unwrap().into_raw(),
    }
}

/// Set synthesizer volume (0.0 to 1.0)
#[no_mangle]
pub extern "C" fn set_synth_volume_ffi(volume: f32) -> *mut c_char {
    match api::set_synth_volume(volume) {
        Ok(msg) => CString::new(msg).unwrap().into_raw(),
        Err(e) => CString::new(format!("Error: {}", e)).unwrap().into_raw(),
    }
}

/// Send MIDI note on event to synthesizer (for virtual piano)
#[no_mangle]
pub extern "C" fn send_midi_note_on_ffi(note: u8, velocity: u8) -> *mut c_char {
    match api::send_midi_note_on(note, velocity) {
        Ok(msg) => CString::new(msg).unwrap().into_raw(),
        Err(e) => CString::new(format!("Error: {}", e)).unwrap().into_raw(),
    }
}

/// Send MIDI note off event to synthesizer (for virtual piano)
#[no_mangle]
pub extern "C" fn send_midi_note_off_ffi(note: u8, velocity: u8) -> *mut c_char {
    match api::send_midi_note_off(note, velocity) {
        Ok(msg) => CString::new(msg).unwrap().into_raw(),
        Err(e) => CString::new(format!("Error: {}", e)).unwrap().into_raw(),
    }
}

// ============================================================================
// MIDI Recording and Clip Manipulation FFI
// ============================================================================

/// Start MIDI recording
#[no_mangle]
pub extern "C" fn start_midi_recording_ffi() -> *mut c_char {
    match api::start_midi_recording() {
        Ok(msg) => CString::new(msg).unwrap().into_raw(),
        Err(e) => CString::new(format!("Error: {}", e)).unwrap().into_raw(),
    }
}

/// Stop MIDI recording and return the clip ID (-1 if no events recorded)
#[no_mangle]
pub extern "C" fn stop_midi_recording_ffi() -> i64 {
    match api::stop_midi_recording() {
        Ok(Some(clip_id)) => clip_id as i64,
        Ok(None) => -1,
        Err(_) => -1,
    }
}

/// Get MIDI recording state (0 = Idle, 1 = Recording)
#[no_mangle]
pub extern "C" fn get_midi_recording_state_ffi() -> i32 {
    match api::get_midi_recording_state() {
        Ok(state) => state,
        Err(_) => -1,
    }
}

/// Create a new empty MIDI clip
#[no_mangle]
pub extern "C" fn create_midi_clip_ffi() -> i64 {
    match api::create_midi_clip() {
        Ok(clip_id) => clip_id as i64,
        Err(_) => -1,
    }
}

/// Add a MIDI note to a clip
#[no_mangle]
pub extern "C" fn add_midi_note_to_clip_ffi(
    clip_id: u64,
    note: u8,
    velocity: u8,
    start_time: f64,
    duration: f64,
) -> *mut c_char {
    match api::add_midi_note_to_clip(clip_id, note, velocity, start_time, duration) {
        Ok(msg) => CString::new(msg).unwrap().into_raw(),
        Err(e) => CString::new(format!("Error: {}", e)).unwrap().into_raw(),
    }
}

/// Quantize a MIDI clip
#[no_mangle]
pub extern "C" fn quantize_midi_clip_ffi(clip_id: u64, grid_division: u32) -> *mut c_char {
    match api::quantize_midi_clip(clip_id, grid_division) {
        Ok(msg) => CString::new(msg).unwrap().into_raw(),
        Err(e) => CString::new(format!("Error: {}", e)).unwrap().into_raw(),
    }
}

/// Get MIDI clip count
#[no_mangle]
pub extern "C" fn get_midi_clip_count_ffi() -> usize {
    api::get_midi_clip_count().unwrap_or(0)
}

// ============================================================================
// M4: TRACK & MIXING FFI
// ============================================================================

/// Create a new track
///
/// # Arguments
/// * `track_type` - Track type: "audio", "midi", "return", "group"
/// * `name` - Display name for the track
///
/// # Returns
/// Track ID on success, or -1 on error
#[no_mangle]
pub extern "C" fn create_track_ffi(
    track_type: *const c_char,
    name: *const c_char,
) -> i64 {
    let track_type_str = unsafe {
        match CStr::from_ptr(track_type).to_str() {
            Ok(s) => s,
            Err(_) => return -1,
        }
    };
    let name_str = unsafe {
        match CStr::from_ptr(name).to_str() {
            Ok(s) => s.to_string(),
            Err(_) => return -1,
        }
    };

    match api::create_track(track_type_str, name_str) {
        Ok(id) => id as i64,
        Err(e) => {
            eprintln!("❌ [FFI] create_track error: {}", e);
            -1
        }
    }
}

/// Set track volume
#[no_mangle]
pub extern "C" fn set_track_volume_ffi(track_id: u64, volume_db: f32) -> *mut c_char {
    match api::set_track_volume(track_id, volume_db) {
        Ok(msg) => CString::new(msg).unwrap().into_raw(),
        Err(e) => CString::new(format!("Error: {}", e)).unwrap().into_raw(),
    }
}

/// Set track pan
#[no_mangle]
pub extern "C" fn set_track_pan_ffi(track_id: u64, pan: f32) -> *mut c_char {
    match api::set_track_pan(track_id, pan) {
        Ok(msg) => CString::new(msg).unwrap().into_raw(),
        Err(e) => CString::new(format!("Error: {}", e)).unwrap().into_raw(),
    }
}

/// Set track mute
#[no_mangle]
pub extern "C" fn set_track_mute_ffi(track_id: u64, mute: bool) -> *mut c_char {
    match api::set_track_mute(track_id, mute) {
        Ok(msg) => CString::new(msg).unwrap().into_raw(),
        Err(e) => CString::new(format!("Error: {}", e)).unwrap().into_raw(),
    }
}

/// Set track solo
#[no_mangle]
pub extern "C" fn set_track_solo_ffi(track_id: u64, solo: bool) -> *mut c_char {
    match api::set_track_solo(track_id, solo) {
        Ok(msg) => CString::new(msg).unwrap().into_raw(),
        Err(e) => CString::new(format!("Error: {}", e)).unwrap().into_raw(),
    }
}

/// Get track count
#[no_mangle]
pub extern "C" fn get_track_count_ffi() -> usize {
    api::get_track_count().unwrap_or(0)
}

/// Get track info (CSV format)
///
/// Returns: "track_id,name,type,volume_db,pan,mute,solo"
/// Caller must free the returned string
#[no_mangle]
pub extern "C" fn get_track_info_ffi(track_id: u64) -> *mut c_char {
    match api::get_track_info(track_id) {
        Ok(info) => CString::new(info).unwrap().into_raw(),
        Err(e) => CString::new(format!("Error: {}", e)).unwrap().into_raw(),
    }
}

/// Move clip to track
#[no_mangle]
pub extern "C" fn move_clip_to_track_ffi(track_id: u64, clip_id: u64) -> *mut c_char {
    match api::move_clip_to_track(track_id, clip_id) {
        Ok(msg) => CString::new(msg).unwrap().into_raw(),
        Err(e) => CString::new(format!("Error: {}", e)).unwrap().into_raw(),
    }
}

