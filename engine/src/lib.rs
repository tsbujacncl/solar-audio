// Audio engine modules
mod api;
mod ffi;

// Re-export API functions
pub use api::*;
// FFI exports are handled by #[no_mangle] in ffi.rs

use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use std::sync::{Arc, atomic::{AtomicBool, Ordering}};

/// Simple audio engine that outputs silence to default device
pub struct AudioEngine {
    is_running: Arc<AtomicBool>,
}

impl AudioEngine {
    pub fn new() -> Result<Self, anyhow::Error> {
        Ok(Self {
            is_running: Arc::new(AtomicBool::new(false)),
        })
    }

    /// Start audio output (currently just silence)
    pub fn start(&self) -> Result<(), anyhow::Error> {
        let host = cpal::default_host();
        let device = host
            .default_output_device()
            .ok_or_else(|| anyhow::anyhow!("No output device available"))?;
        
        let config = device.default_output_config()?;
        
        println!("Audio device: {}", device.name()?);
        println!("Audio config: {:?}", config);
        
        // Create stream that outputs silence
        let stream = device.build_output_stream(
            &config.into(),
            move |data: &mut [f32], _: &cpal::OutputCallbackInfo| {
                // Output silence (zeros)
                for sample in data.iter_mut() {
                    *sample = 0.0;
                }
            },
            move |err| {
                eprintln!("Audio stream error: {}", err);
            },
            None,
        )?;
        
        stream.play()?;
        self.is_running.store(true, Ordering::SeqCst);
        
        // Keep stream alive
        std::mem::forget(stream);
        
        Ok(())
    }
    
    pub fn is_running(&self) -> bool {
        self.is_running.load(Ordering::SeqCst)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_engine_creation() {
        let engine = AudioEngine::new();
        assert!(engine.is_ok());
    }
}
