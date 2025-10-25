/// API functions exposed to Flutter via FFI
use crate::audio_file::{load_audio_file, AudioClip};
use crate::audio_graph::{AudioGraph, ClipId, TransportState};
use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use std::collections::HashMap;
use std::f32::consts::PI;
use std::sync::{Arc, Mutex, OnceLock};

/// Global audio graph instance (thread-safe, lazy-initialized)
static AUDIO_GRAPH: OnceLock<Mutex<AudioGraph>> = OnceLock::new();

/// Map of loaded audio clips (thread-safe, lazy-initialized)
static AUDIO_CLIPS: OnceLock<Mutex<HashMap<ClipId, Arc<AudioClip>>>> = OnceLock::new();

/// Play a sine wave at the specified frequency for the given duration
/// 
/// # Arguments
/// * `frequency` - Frequency in Hz (e.g., 440 for A4)
/// * `duration_ms` - Duration in milliseconds
pub fn play_sine_wave(frequency: f32, duration_ms: u32) -> Result<String, String> {
    // This is a simplified implementation for M0
    // In production, this would integrate with the AudioEngine
    
    std::thread::spawn(move || {
        if let Err(e) = play_sine_wave_internal(frequency, duration_ms) {
            eprintln!("Error playing sine wave: {}", e);
        }
    });
    
    Ok(format!(
        "Playing {} Hz sine wave for {} ms",
        frequency, duration_ms
    ))
}

fn play_sine_wave_internal(frequency: f32, duration_ms: u32) -> Result<(), String> {
    let host = cpal::default_host();
    let device = host
        .default_output_device()
        .ok_or("No output device available")?;

    let config = device
        .default_output_config()
        .map_err(|e| format!("Failed to get output config: {}", e))?;

    let sample_rate = config.sample_rate().0 as f32;
    let channels = config.channels() as usize;

    // Track samples for sine wave generation
    let samples_to_play = (sample_rate * duration_ms as f32 / 1000.0) as usize;
    let sample_count = Arc::new(std::sync::atomic::AtomicUsize::new(0));
    let sample_count_clone = sample_count.clone();

    let stream = device
        .build_output_stream(
            &config.into(),
            move |data: &mut [f32], _: &cpal::OutputCallbackInfo| {
                let count = sample_count_clone.load(std::sync::atomic::Ordering::SeqCst);
                let num_frames = data.len() / channels;
                
                for i in 0..num_frames {
                    let current_sample = count + i;
                    
                    let value = if current_sample >= samples_to_play {
                        // Silence after duration
                        0.0
                    } else {
                        // Generate sine wave
                        let t = current_sample as f32 / sample_rate;
                        (t * frequency * 2.0 * PI).sin() * 0.3 // 0.3 amplitude to avoid clipping
                    };
                    
                    // Copy to all channels
                    for ch in 0..channels {
                        data[i * channels + ch] = value;
                    }
                }
                
                sample_count_clone.fetch_add(num_frames, std::sync::atomic::Ordering::SeqCst);
            },
            |err| {
                eprintln!("Audio stream error: {}", err);
            },
            None,
        )
        .map_err(|e| format!("Failed to build output stream: {}", e))?;

    stream
        .play()
        .map_err(|e| format!("Failed to play stream: {}", e))?;

    // Keep the stream alive for the duration
    std::thread::sleep(std::time::Duration::from_millis(duration_ms as u64));

    Ok(())
}

/// Initialize the audio engine
pub fn init_audio_engine() -> Result<String, String> {
    // For M0, just verify audio devices are available
    let host = cpal::default_host();
    let device = host
        .default_output_device()
        .ok_or("No output device available")?;
    
    let device_name = device
        .name()
        .unwrap_or_else(|_| "Unknown Device".to_string());
    
    Ok(format!("Audio engine initialized. Device: {}", device_name))
}

// ============================================================================
// M1: Audio Playback API
// ============================================================================

/// Initialize the audio graph for playback
pub fn init_audio_graph() -> Result<String, String> {
    let graph = AudioGraph::new().map_err(|e| e.to_string())?;
    AUDIO_GRAPH.set(Mutex::new(graph))
        .map_err(|_| "Audio graph already initialized")?;
    
    AUDIO_CLIPS.set(Mutex::new(HashMap::new()))
        .map_err(|_| "Audio clips already initialized")?;
    
    Ok("Audio graph initialized".to_string())
}

/// Load an audio file and return a clip ID
pub fn load_audio_file_api(path: String) -> Result<u64, String> {
    let clip = load_audio_file(&path).map_err(|e| e.to_string())?;
    let clip_arc = Arc::new(clip);
    
    let clips_mutex = AUDIO_CLIPS.get()
        .ok_or("Audio graph not initialized")?;
    let mut clips_map = clips_mutex.lock().map_err(|e| e.to_string())?;
    
    let graph_mutex = AUDIO_GRAPH.get()
        .ok_or("Audio graph not initialized")?;
    let graph = graph_mutex.lock().map_err(|e| e.to_string())?;
    
    // Add clip to timeline at position 0.0 for now
    let clip_id = graph.add_clip(clip_arc.clone(), 0.0);
    clips_map.insert(clip_id, clip_arc);
    
    Ok(clip_id)
}

/// Start playback
pub fn transport_play() -> Result<String, String> {
    let graph_mutex = AUDIO_GRAPH.get()
        .ok_or("Audio graph not initialized")?;
    let mut graph = graph_mutex.lock().map_err(|e| e.to_string())?;
    
    graph.play().map_err(|e| e.to_string())?;
    Ok("Playing".to_string())
}

/// Pause playback
pub fn transport_pause() -> Result<String, String> {
    let graph_mutex = AUDIO_GRAPH.get()
        .ok_or("Audio graph not initialized")?;
    let mut graph = graph_mutex.lock().map_err(|e| e.to_string())?;
    
    graph.pause().map_err(|e| e.to_string())?;
    Ok("Paused".to_string())
}

/// Stop playback and reset to start
pub fn transport_stop() -> Result<String, String> {
    let graph_mutex = AUDIO_GRAPH.get()
        .ok_or("Audio graph not initialized")?;
    let mut graph = graph_mutex.lock().map_err(|e| e.to_string())?;
    
    graph.stop().map_err(|e| e.to_string())?;
    Ok("Stopped".to_string())
}

/// Seek to a position in seconds
pub fn transport_seek(position_seconds: f64) -> Result<String, String> {
    let graph_mutex = AUDIO_GRAPH.get()
        .ok_or("Audio graph not initialized")?;
    let graph = graph_mutex.lock().map_err(|e| e.to_string())?;
    
    graph.seek(position_seconds);
    Ok(format!("Seeked to {:.2}s", position_seconds))
}

/// Get current playhead position in seconds
pub fn get_playhead_position() -> Result<f64, String> {
    let graph_mutex = AUDIO_GRAPH.get()
        .ok_or("Audio graph not initialized")?;
    let graph = graph_mutex.lock().map_err(|e| e.to_string())?;
    
    Ok(graph.get_playhead_position())
}

/// Get transport state (0=Stopped, 1=Playing, 2=Paused)
pub fn get_transport_state() -> Result<i32, String> {
    let graph_mutex = AUDIO_GRAPH.get()
        .ok_or("Audio graph not initialized")?;
    let graph = graph_mutex.lock().map_err(|e| e.to_string())?;
    
    let state = match graph.get_state() {
        TransportState::Stopped => 0,
        TransportState::Playing => 1,
        TransportState::Paused => 2,
    };
    
    Ok(state)
}

/// Get waveform peaks for visualization
/// Returns downsampled peaks (min/max pairs) for rendering
pub fn get_waveform_peaks(clip_id: u64, resolution: usize) -> Result<Vec<f32>, String> {
    let clips_mutex = AUDIO_CLIPS.get()
        .ok_or("Audio graph not initialized")?;
    let clips_map = clips_mutex.lock().map_err(|e| e.to_string())?;
    
    let clip = clips_map
        .get(&clip_id)
        .ok_or_else(|| format!("Clip {} not found", clip_id))?;
    
    // Downsample to resolution peaks
    let frames = clip.frame_count();
    let samples_per_peak = (frames / resolution).max(1);
    
    let mut peaks = Vec::with_capacity(resolution * 2); // min/max pairs
    
    for i in 0..resolution {
        let start = i * samples_per_peak;
        let end = ((i + 1) * samples_per_peak).min(frames);
        
        if start >= frames {
            break;
        }
        
        let mut min: f32 = 1.0;
        let mut max: f32 = -1.0;
        
        // Find min/max in this window (use left channel for mono visualization)
        for frame in start..end {
            if let Some(sample) = clip.get_sample(frame, 0) {
                min = min.min(sample);
                max = max.max(sample);
            }
        }
        
        peaks.push(min);
        peaks.push(max);
    }
    
    Ok(peaks)
}

/// Get clip duration in seconds
pub fn get_clip_duration(clip_id: u64) -> Result<f64, String> {
    let clips_mutex = AUDIO_CLIPS.get()
        .ok_or("Audio graph not initialized")?;
    let clips_map = clips_mutex.lock().map_err(|e| e.to_string())?;
    
    let clip = clips_map
        .get(&clip_id)
        .ok_or_else(|| format!("Clip {} not found", clip_id))?;
    
    Ok(clip.duration_seconds)
}

