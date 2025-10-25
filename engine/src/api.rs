/// API functions exposed to Flutter via FFI
use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use std::f32::consts::PI;
use std::sync::Arc;

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

