/// API functions exposed to Flutter via FFI
use crate::audio_file::{load_audio_file, AudioClip};
use crate::audio_graph::{AudioGraph, TransportState};
use crate::track::ClipId;  // Import from track module
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

    // M5.5: Add clip to first audio track (or create one if none exists)
    let target_track_id = {
        let track_manager = graph.track_manager.lock().map_err(|e| e.to_string())?;
        let all_tracks = track_manager.get_all_tracks();

        // Find first audio track
        let mut audio_track_id = None;
        for track_arc in all_tracks {
            let track = track_arc.lock().map_err(|e| e.to_string())?;
            if track.track_type == crate::track::TrackType::Audio {
                audio_track_id = Some(track.id);
                break;
            }
        }

        // If no audio track exists, create one
        if let Some(id) = audio_track_id {
            id
        } else {
            drop(track_manager); // Release lock before creating track
            let mut tm = graph.track_manager.lock().map_err(|e| e.to_string())?;
            tm.create_track(crate::track::TrackType::Audio, "Audio 1".to_string())
        }
    };

    // Add clip to track at position 0.0 for now
    let clip_id = graph.add_clip_to_track(target_track_id, clip_arc.clone(), 0.0)
        .ok_or(format!("Failed to add clip to track {}", target_track_id))?;

    // Also add to legacy timeline for backward compatibility (will be removed in future)
    graph.add_clip(clip_arc.clone(), 0.0);

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

// ============================================================================
// M2: Recording & Input API
// ============================================================================

/// Get list of available audio input devices
pub fn get_audio_input_devices() -> Result<Vec<(String, String, bool)>, String> {
    let graph_mutex = AUDIO_GRAPH.get()
        .ok_or("Audio graph not initialized")?;
    let graph = graph_mutex.lock().map_err(|e| e.to_string())?;
    
    let input_manager = graph.input_manager.lock().map_err(|e| e.to_string())?;
    let devices = input_manager.get_devices();
    
    // Convert to tuple format: (id, name, is_default)
    let device_list: Vec<(String, String, bool)> = devices
        .into_iter()
        .map(|d| (d.id, d.name, d.is_default))
        .collect();
    
    Ok(device_list)
}

/// Select an audio input device by index
pub fn set_audio_input_device(device_index: i32) -> Result<String, String> {
    if device_index < 0 {
        return Err("Invalid device index".to_string());
    }
    
    let graph_mutex = AUDIO_GRAPH.get()
        .ok_or("Audio graph not initialized")?;
    let graph = graph_mutex.lock().map_err(|e| e.to_string())?;
    
    let mut input_manager = graph.input_manager.lock().map_err(|e| e.to_string())?;
    input_manager.select_device(device_index as usize).map_err(|e| e.to_string())?;
    
    Ok(format!("Selected input device {}", device_index))
}

/// Start capturing audio from the selected input device
pub fn start_audio_input() -> Result<String, String> {
    let graph_mutex = AUDIO_GRAPH.get()
        .ok_or("Audio graph not initialized")?;
    let graph = graph_mutex.lock().map_err(|e| e.to_string())?;
    
    let mut input_manager = graph.input_manager.lock().map_err(|e| e.to_string())?;
    
    // Start capturing with 10 seconds of buffer
    input_manager.start_capture(10.0).map_err(|e| e.to_string())?;
    
    Ok("Audio input started".to_string())
}

/// Stop capturing audio
pub fn stop_audio_input() -> Result<String, String> {
    let graph_mutex = AUDIO_GRAPH.get()
        .ok_or("Audio graph not initialized")?;
    let graph = graph_mutex.lock().map_err(|e| e.to_string())?;
    
    let mut input_manager = graph.input_manager.lock().map_err(|e| e.to_string())?;
    input_manager.stop_capture().map_err(|e| e.to_string())?;
    
    Ok("Audio input stopped".to_string())
}

/// Start recording audio
pub fn start_recording() -> Result<String, String> {
    let graph_mutex = AUDIO_GRAPH.get()
        .ok_or("Audio graph not initialized")?;
    let mut graph = graph_mutex.lock().map_err(|e| e.to_string())?;

    // Start audio input if not already started
    {
        let mut input_manager = graph.input_manager.lock().map_err(|e| e.to_string())?;
        if !input_manager.is_capturing() {
            input_manager.start_capture(10.0).map_err(|e| e.to_string())?;
        }
    }

    // CRITICAL: Ensure output stream is running so audio callback processes recording
    // If not playing, we need to start the output stream for metronome and recording
    // Note: play() checks internally if already playing and returns early if so
    eprintln!("🔊 [API] Ensuring output stream is running for recording...");
    graph.play().map_err(|e| e.to_string())?;

    graph.recorder.start_recording()?;

    let state = graph.recorder.get_state();
    Ok(format!("Recording started: {:?}", state))
}

/// Stop recording and return the recorded clip ID
pub fn stop_recording() -> Result<Option<u64>, String> {
    let graph_mutex = AUDIO_GRAPH.get()
        .ok_or("Audio graph not initialized")?;
    let graph = graph_mutex.lock().map_err(|e| e.to_string())?;

    let clip_option = graph.recorder.stop_recording()?;

    // Stop audio input to prevent buffer overflow
    {
        let mut input_manager = graph.input_manager.lock().map_err(|e| e.to_string())?;
        if input_manager.is_capturing() {
            eprintln!("🛑 [API] Stopping audio input after recording...");
            input_manager.stop_capture().map_err(|e| e.to_string())?;
        }
    }

    if let Some(clip) = clip_option {
        // Store the recorded clip and add to timeline at position 0.0
        let clip_arc = Arc::new(clip);

        // Add to timeline first to get the ID
        let clip_id = graph.add_clip(clip_arc.clone(), 0.0);

        // Store in AUDIO_CLIPS map with the same ID
        let clips_mutex = AUDIO_CLIPS.get()
            .ok_or("Audio clips not initialized")?;
        let mut clips_map = clips_mutex.lock().map_err(|e| e.to_string())?;
        clips_map.insert(clip_id, clip_arc);

        eprintln!("✅ [API] Recorded clip stored with ID: {}, added to timeline at position 0.0", clip_id);

        Ok(Some(clip_id))
    } else {
        Ok(None)
    }
}

/// Get current recording state (0=Idle, 1=CountingIn, 2=Recording)
pub fn get_recording_state() -> Result<i32, String> {
    let graph_mutex = AUDIO_GRAPH.get()
        .ok_or("Audio graph not initialized")?;
    let graph = graph_mutex.lock().map_err(|e| e.to_string())?;
    
    use crate::recorder::RecordingState;
    let state = match graph.recorder.get_state() {
        RecordingState::Idle => 0,
        RecordingState::CountingIn => 1,
        RecordingState::Recording => 2,
    };
    
    Ok(state)
}

/// Get recorded duration in seconds
pub fn get_recorded_duration() -> Result<f64, String> {
    let graph_mutex = AUDIO_GRAPH.get()
        .ok_or("Audio graph not initialized")?;
    let graph = graph_mutex.lock().map_err(|e| e.to_string())?;
    
    Ok(graph.recorder.get_recorded_duration())
}

/// Set count-in duration in bars
pub fn set_count_in_bars(bars: u32) -> Result<String, String> {
    let graph_mutex = AUDIO_GRAPH.get()
        .ok_or("Audio graph not initialized")?;
    let graph = graph_mutex.lock().map_err(|e| e.to_string())?;
    
    graph.recorder.set_count_in_bars(bars);
    Ok(format!("Count-in set to {} bars", bars))
}

/// Get count-in duration in bars
pub fn get_count_in_bars() -> Result<u32, String> {
    let graph_mutex = AUDIO_GRAPH.get()
        .ok_or("Audio graph not initialized")?;
    let graph = graph_mutex.lock().map_err(|e| e.to_string())?;
    
    Ok(graph.recorder.get_count_in_bars())
}

/// Set tempo in BPM
pub fn set_tempo(bpm: f64) -> Result<String, String> {
    let graph_mutex = AUDIO_GRAPH.get()
        .ok_or("Audio graph not initialized")?;
    let graph = graph_mutex.lock().map_err(|e| e.to_string())?;
    
    graph.recorder.set_tempo(bpm);
    Ok(format!("Tempo set to {:.1} BPM", bpm))
}

/// Get tempo in BPM
pub fn get_tempo() -> Result<f64, String> {
    let graph_mutex = AUDIO_GRAPH.get()
        .ok_or("Audio graph not initialized")?;
    let graph = graph_mutex.lock().map_err(|e| e.to_string())?;
    
    Ok(graph.recorder.get_tempo())
}

/// Enable or disable metronome
pub fn set_metronome_enabled(enabled: bool) -> Result<String, String> {
    let graph_mutex = AUDIO_GRAPH.get()
        .ok_or("Audio graph not initialized")?;
    let graph = graph_mutex.lock().map_err(|e| e.to_string())?;
    
    graph.recorder.set_metronome_enabled(enabled);
    Ok(format!("Metronome {}", if enabled { "enabled" } else { "disabled" }))
}

/// Check if metronome is enabled
pub fn is_metronome_enabled() -> Result<bool, String> {
    let graph_mutex = AUDIO_GRAPH.get()
        .ok_or("Audio graph not initialized")?;
    let graph = graph_mutex.lock().map_err(|e| e.to_string())?;

    Ok(graph.recorder.is_metronome_enabled())
}

// ============================================================================
// M3: MIDI API
// ============================================================================

/// Get list of available MIDI input devices
pub fn get_midi_input_devices() -> Result<Vec<(String, String, bool)>, String> {
    let graph_mutex = AUDIO_GRAPH.get()
        .ok_or("Audio graph not initialized")?;
    let graph = graph_mutex.lock().map_err(|e| e.to_string())?;

    let midi_manager = graph.midi_input_manager.lock().map_err(|e| e.to_string())?;
    let devices = midi_manager.get_devices();

    // Convert to tuple format: (id, name, is_default)
    let device_list: Vec<(String, String, bool)> = devices
        .into_iter()
        .map(|d| (d.id, d.name, d.is_default))
        .collect();

    Ok(device_list)
}

/// Select a MIDI input device by index
pub fn select_midi_input_device(device_index: i32) -> Result<String, String> {
    if device_index < 0 {
        return Err("Invalid device index".to_string());
    }

    let graph_mutex = AUDIO_GRAPH.get()
        .ok_or("Audio graph not initialized")?;
    let graph = graph_mutex.lock().map_err(|e| e.to_string())?;

    let mut midi_manager = graph.midi_input_manager.lock().map_err(|e| e.to_string())?;
    midi_manager.select_device(device_index as usize).map_err(|e| e.to_string())?;

    Ok(format!("Selected MIDI input device {}", device_index))
}

/// Start capturing MIDI input
pub fn start_midi_input() -> Result<String, String> {
    let graph_mutex = AUDIO_GRAPH.get()
        .ok_or("Audio graph not initialized")?;
    let graph = graph_mutex.lock().map_err(|e| e.to_string())?;

    let mut midi_manager = graph.midi_input_manager.lock().map_err(|e| e.to_string())?;

    // Set up event callback to forward to MIDI recorder and synthesizer
    let midi_recorder = graph.midi_recorder.clone();
    let synthesizer = graph.synthesizer.clone();

    midi_manager.set_event_callback(move |event| {
        // Send to recorder if recording
        if let Ok(mut recorder) = midi_recorder.lock() {
            if recorder.is_recording() {
                recorder.record_event(event);
            }
        }

        // Send to synthesizer for live playback
        if let Ok(mut synth) = synthesizer.lock() {
            synth.process_event(&event);
        }
    });

    midi_manager.start_capture().map_err(|e| e.to_string())?;

    Ok("MIDI input started".to_string())
}

/// Stop capturing MIDI input
pub fn stop_midi_input() -> Result<String, String> {
    let graph_mutex = AUDIO_GRAPH.get()
        .ok_or("Audio graph not initialized")?;
    let graph = graph_mutex.lock().map_err(|e| e.to_string())?;

    let mut midi_manager = graph.midi_input_manager.lock().map_err(|e| e.to_string())?;
    midi_manager.stop_capture().map_err(|e| e.to_string())?;

    Ok("MIDI input stopped".to_string())
}

/// Start recording MIDI
pub fn start_midi_recording() -> Result<String, String> {
    let graph_mutex = AUDIO_GRAPH.get()
        .ok_or("Audio graph not initialized")?;
    let graph = graph_mutex.lock().map_err(|e| e.to_string())?;

    let mut midi_recorder = graph.midi_recorder.lock().map_err(|e| e.to_string())?;
    midi_recorder.start_recording()?;

    Ok("MIDI recording started".to_string())
}

/// Stop recording MIDI and return the clip ID
pub fn stop_midi_recording() -> Result<Option<u64>, String> {
    let graph_mutex = AUDIO_GRAPH.get()
        .ok_or("Audio graph not initialized")?;
    let graph = graph_mutex.lock().map_err(|e| e.to_string())?;

    let mut midi_recorder = graph.midi_recorder.lock().map_err(|e| e.to_string())?;
    let clip_option = midi_recorder.stop_recording()?;

    if let Some(clip) = clip_option {
        let clip_arc = Arc::new(clip);
        let clip_id = graph.add_midi_clip(clip_arc, 0.0);

        eprintln!("✅ [API] MIDI clip recorded with ID: {}", clip_id);
        Ok(Some(clip_id))
    } else {
        Ok(None)
    }
}

/// Get current MIDI recording state (0=Idle, 1=Recording)
pub fn get_midi_recording_state() -> Result<i32, String> {
    let graph_mutex = AUDIO_GRAPH.get()
        .ok_or("Audio graph not initialized")?;
    let graph = graph_mutex.lock().map_err(|e| e.to_string())?;

    let midi_recorder = graph.midi_recorder.lock().map_err(|e| e.to_string())?;

    use crate::midi_recorder::MidiRecordingState;
    let state = match midi_recorder.get_state() {
        MidiRecordingState::Idle => 0,
        MidiRecordingState::Recording => 1,
    };

    Ok(state)
}

/// Set synthesizer oscillator type (0=Sine, 1=Saw, 2=Square)
pub fn set_synth_oscillator_type(osc_type: i32) -> Result<String, String> {
    let graph_mutex = AUDIO_GRAPH.get()
        .ok_or("Audio graph not initialized")?;
    let graph = graph_mutex.lock().map_err(|e| e.to_string())?;

    let mut synth = graph.synthesizer.lock().map_err(|e| e.to_string())?;

    use crate::synth::OscillatorType;
    let osc = match osc_type {
        0 => OscillatorType::Sine,
        1 => OscillatorType::Saw,
        2 => OscillatorType::Square,
        _ => return Err("Invalid oscillator type".to_string()),
    };

    synth.set_oscillator_type(osc);
    Ok(format!("Oscillator type set to {:?}", osc))
}

/// Set synthesizer master volume (0.0 to 1.0)
pub fn set_synth_volume(volume: f32) -> Result<String, String> {
    let graph_mutex = AUDIO_GRAPH.get()
        .ok_or("Audio graph not initialized")?;
    let graph = graph_mutex.lock().map_err(|e| e.to_string())?;

    let mut synth = graph.synthesizer.lock().map_err(|e| e.to_string())?;
    synth.set_master_volume(volume);

    Ok(format!("Synth volume set to {:.2}", volume))
}

/// Get number of MIDI clips on timeline
pub fn get_midi_clip_count() -> Result<usize, String> {
    let graph_mutex = AUDIO_GRAPH.get()
        .ok_or("Audio graph not initialized")?;
    let graph = graph_mutex.lock().map_err(|e| e.to_string())?;

    Ok(graph.midi_clip_count())
}

/// Send MIDI note on event directly to synthesizer (for virtual piano)
pub fn send_midi_note_on(note: u8, velocity: u8) -> Result<String, String> {
    let graph_mutex = AUDIO_GRAPH.get()
        .ok_or("Audio graph not initialized")?;
    let graph = graph_mutex.lock().map_err(|e| e.to_string())?;

    let mut synth = graph.synthesizer.lock().map_err(|e| e.to_string())?;

    use crate::midi::{MidiEvent, MidiEventType};
    let event = MidiEvent {
        event_type: MidiEventType::NoteOn { note, velocity },
        timestamp_samples: 0, // Immediate playback
    };

    synth.process_event(&event);
    Ok(format!("Note On: {} (velocity: {})", note, velocity))
}

/// Send MIDI note off event directly to synthesizer (for virtual piano)
pub fn send_midi_note_off(note: u8, velocity: u8) -> Result<String, String> {
    let graph_mutex = AUDIO_GRAPH.get()
        .ok_or("Audio graph not initialized")?;
    let graph = graph_mutex.lock().map_err(|e| e.to_string())?;

    let mut synth = graph.synthesizer.lock().map_err(|e| e.to_string())?;

    use crate::midi::{MidiEvent, MidiEventType};
    let event = MidiEvent {
        event_type: MidiEventType::NoteOff { note, velocity },
        timestamp_samples: 0, // Immediate playback
    };

    synth.process_event(&event);
    Ok(format!("Note Off: {} (velocity: {})", note, velocity))
}

// ================================================================================
// MIDI Clip Manipulation API (for Piano Roll)
// ================================================================================

/// Create a new empty MIDI clip
pub fn create_midi_clip() -> Result<u64, String> {
    use crate::midi::MidiClip;

    let graph_mutex = AUDIO_GRAPH.get()
        .ok_or("Audio graph not initialized")?;
    let graph = graph_mutex.lock().map_err(|e| e.to_string())?;

    // Create empty MIDI clip
    let clip = MidiClip::new(crate::audio_file::TARGET_SAMPLE_RATE);
    let clip_arc = Arc::new(clip);

    // Add to timeline at position 0.0 (can be moved later)
    let clip_id = graph.add_midi_clip(clip_arc, 0.0);

    Ok(clip_id)
}

/// Add a MIDI note to a clip
///
/// # Arguments
/// * `clip_id` - The MIDI clip ID
/// * `note` - MIDI note number (0-127)
/// * `velocity` - Note velocity (0-127)
/// * `start_time` - Start time in seconds
/// * `duration` - Duration in seconds
pub fn add_midi_note_to_clip(
    clip_id: u64,
    note: u8,
    velocity: u8,
    start_time: f64,
    duration: f64,
) -> Result<String, String> {
    use crate::midi::MidiEvent;

    let graph_mutex = AUDIO_GRAPH.get()
        .ok_or("Audio graph not initialized")?;
    let graph = graph_mutex.lock().map_err(|e| e.to_string())?;

    // Get the MIDI clip
    let mut midi_clips = graph.get_midi_clips().lock().map_err(|e| e.to_string())?;
    let timeline_clip = midi_clips
        .iter_mut()
        .find(|c| c.id == clip_id)
        .ok_or("MIDI clip not found")?;

    // Get mutable reference to the clip data
    // Note: We need to clone the Arc, get the data, modify it, and replace it
    let clip_data: &mut crate::midi::MidiClip = Arc::make_mut(&mut timeline_clip.clip);

    // Convert time to samples
    let start_samples = (start_time * crate::audio_file::TARGET_SAMPLE_RATE as f64) as u64;
    let duration_samples = (duration * crate::audio_file::TARGET_SAMPLE_RATE as f64) as u64;

    // Create note events
    let note_on = MidiEvent::note_on(note, velocity, start_samples);
    let note_off = MidiEvent::note_off(note, 64, start_samples + duration_samples);

    // Add events to clip
    clip_data.add_event(note_on);
    clip_data.add_event(note_off);

    Ok(format!("Added note {} at {:.3}s, duration {:.3}s", note, start_time, duration))
}

/// Get all MIDI events from a clip
/// Returns: Vec<(event_type, note, velocity, timestamp_seconds)>
/// event_type: 0 = NoteOn, 1 = NoteOff
pub fn get_midi_clip_events(clip_id: u64) -> Result<Vec<(i32, u8, u8, f64)>, String> {
    use crate::midi::MidiEventType;

    let graph_mutex = AUDIO_GRAPH.get()
        .ok_or("Audio graph not initialized")?;
    let graph = graph_mutex.lock().map_err(|e| e.to_string())?;

    // Get the MIDI clip
    let midi_clips = graph.get_midi_clips().lock().map_err(|e| e.to_string())?;
    let timeline_clip = midi_clips
        .iter()
        .find(|c| c.id == clip_id)
        .ok_or("MIDI clip not found")?;

    // Convert events to a format that can cross FFI
    let events: Vec<(i32, u8, u8, f64)> = timeline_clip
        .clip
        .events
        .iter()
        .map(|event| {
            let (event_type, note, velocity) = match event.event_type {
                MidiEventType::NoteOn { note, velocity } => (0, note, velocity),
                MidiEventType::NoteOff { note, velocity } => (1, note, velocity),
            };
            let timestamp_seconds = event.timestamp_samples as f64 / crate::audio_file::TARGET_SAMPLE_RATE as f64;
            (event_type, note, velocity, timestamp_seconds)
        })
        .collect();

    Ok(events)
}

/// Remove a MIDI event at the specified index
pub fn remove_midi_event(clip_id: u64, event_index: usize) -> Result<String, String> {
    let graph_mutex = AUDIO_GRAPH.get()
        .ok_or("Audio graph not initialized")?;
    let graph = graph_mutex.lock().map_err(|e| e.to_string())?;

    // Get the MIDI clip
    let mut midi_clips = graph.get_midi_clips().lock().map_err(|e| e.to_string())?;
    let timeline_clip = midi_clips
        .iter_mut()
        .find(|c| c.id == clip_id)
        .ok_or("MIDI clip not found")?;

    // Get mutable reference to the clip data
    let clip_data: &mut crate::midi::MidiClip = Arc::make_mut(&mut timeline_clip.clip);

    // Remove the event
    clip_data.remove_event(event_index)
        .ok_or("Event index out of bounds")?;

    Ok(format!("Removed event at index {}", event_index))
}

/// Clear all MIDI events from a clip
pub fn clear_midi_clip(clip_id: u64) -> Result<String, String> {
    let graph_mutex = AUDIO_GRAPH.get()
        .ok_or("Audio graph not initialized")?;
    let graph = graph_mutex.lock().map_err(|e| e.to_string())?;

    // Get the MIDI clip
    let mut midi_clips = graph.get_midi_clips().lock().map_err(|e| e.to_string())?;
    let timeline_clip = midi_clips
        .iter_mut()
        .find(|c| c.id == clip_id)
        .ok_or("MIDI clip not found")?;

    // Get mutable reference to the clip data
    let clip_data: &mut crate::midi::MidiClip = Arc::make_mut(&mut timeline_clip.clip);

    // Clear all events
    clip_data.clear();

    Ok("Cleared all events".to_string())
}

/// Quantize a MIDI clip to the specified grid
///
/// # Arguments
/// * `clip_id` - The MIDI clip ID
/// * `grid_division` - Grid division (4 = quarter note, 8 = eighth note, 16 = sixteenth note, etc.)
pub fn quantize_midi_clip(clip_id: u64, grid_division: u32) -> Result<String, String> {
    let graph_mutex = AUDIO_GRAPH.get()
        .ok_or("Audio graph not initialized")?;
    let graph = graph_mutex.lock().map_err(|e| e.to_string())?;

    // Get the MIDI clip
    let mut midi_clips = graph.get_midi_clips().lock().map_err(|e| e.to_string())?;
    let timeline_clip = midi_clips
        .iter_mut()
        .find(|c| c.id == clip_id)
        .ok_or("MIDI clip not found")?;

    // Calculate grid size in samples based on tempo (assume 120 BPM for now)
    let tempo = 120.0;
    let seconds_per_beat = 60.0 / tempo;
    let samples_per_beat = (seconds_per_beat * crate::audio_file::TARGET_SAMPLE_RATE as f64) as u64;
    let grid_samples = samples_per_beat / grid_division as u64;

    // Get mutable reference to the clip data
    let clip_data: &mut crate::midi::MidiClip = Arc::make_mut(&mut timeline_clip.clip);

    // Quantize the clip
    clip_data.quantize(grid_samples);

    Ok(format!("Quantized to 1/{} note grid", grid_division))
}

// ============================================================================
// M4: TRACK & MIXING API
// ============================================================================

use crate::track::{TrackType, TrackId};

/// Create a new track
///
/// # Arguments
/// * `track_type_str` - Track type: "audio", "midi", "return", "group", "master"
/// * `name` - Display name for the track
///
/// # Returns
/// Track ID on success
pub fn create_track(track_type_str: &str, name: String) -> Result<TrackId, String> {
    let track_type = match track_type_str.to_lowercase().as_str() {
        "audio" => TrackType::Audio,
        "midi" => TrackType::Midi,
        "return" => TrackType::Return,
        "group" => TrackType::Group,
        "master" => return Err("Cannot create additional master tracks".to_string()),
        _ => return Err(format!("Unknown track type: {}", track_type_str)),
    };

    let graph_mutex = AUDIO_GRAPH.get()
        .ok_or("Audio graph not initialized")?;
    let graph = graph_mutex.lock().map_err(|e| e.to_string())?;
    let mut track_manager = graph.track_manager.lock().map_err(|e| e.to_string())?;

    let track_id = track_manager.create_track(track_type, name);
    Ok(track_id)
}

/// Set track volume
///
/// # Arguments
/// * `track_id` - Track ID
/// * `volume_db` - Volume in dB (-96.0 to +6.0)
pub fn set_track_volume(track_id: TrackId, volume_db: f32) -> Result<String, String> {
    let graph_mutex = AUDIO_GRAPH.get()
        .ok_or("Audio graph not initialized")?;
    let graph = graph_mutex.lock().map_err(|e| e.to_string())?;
    let track_manager = graph.track_manager.lock().map_err(|e| e.to_string())?;

    if let Some(track_arc) = track_manager.get_track(track_id) {
        let mut track = track_arc.lock().map_err(|e| e.to_string())?;
        track.volume_db = volume_db.clamp(-96.0, 6.0);
        Ok(format!("Track {} volume set to {:.2} dB", track_id, track.volume_db))
    } else {
        Err(format!("Track {} not found", track_id))
    }
}

/// Set track pan
///
/// # Arguments
/// * `track_id` - Track ID
/// * `pan` - Pan position (-1.0 = left, 0.0 = center, +1.0 = right)
pub fn set_track_pan(track_id: TrackId, pan: f32) -> Result<String, String> {
    let graph_mutex = AUDIO_GRAPH.get()
        .ok_or("Audio graph not initialized")?;
    let graph = graph_mutex.lock().map_err(|e| e.to_string())?;
    let track_manager = graph.track_manager.lock().map_err(|e| e.to_string())?;

    if let Some(track_arc) = track_manager.get_track(track_id) {
        let mut track = track_arc.lock().map_err(|e| e.to_string())?;
        track.pan = pan.clamp(-1.0, 1.0);
        Ok(format!("Track {} pan set to {:.2}", track_id, track.pan))
    } else {
        Err(format!("Track {} not found", track_id))
    }
}

/// Set track mute state
pub fn set_track_mute(track_id: TrackId, mute: bool) -> Result<String, String> {
    let graph_mutex = AUDIO_GRAPH.get()
        .ok_or("Audio graph not initialized")?;
    let graph = graph_mutex.lock().map_err(|e| e.to_string())?;
    let track_manager = graph.track_manager.lock().map_err(|e| e.to_string())?;

    if let Some(track_arc) = track_manager.get_track(track_id) {
        let mut track = track_arc.lock().map_err(|e| e.to_string())?;
        track.mute = mute;
        Ok(format!("Track {} mute: {}", track_id, mute))
    } else {
        Err(format!("Track {} not found", track_id))
    }
}

/// Set track solo state
pub fn set_track_solo(track_id: TrackId, solo: bool) -> Result<String, String> {
    let graph_mutex = AUDIO_GRAPH.get()
        .ok_or("Audio graph not initialized")?;
    let graph = graph_mutex.lock().map_err(|e| e.to_string())?;
    let track_manager = graph.track_manager.lock().map_err(|e| e.to_string())?;

    if let Some(track_arc) = track_manager.get_track(track_id) {
        let mut track = track_arc.lock().map_err(|e| e.to_string())?;
        track.solo = solo;
        Ok(format!("Track {} solo: {}", track_id, solo))
    } else {
        Err(format!("Track {} not found", track_id))
    }
}

/// Get total number of tracks (including master)
pub fn get_track_count() -> Result<usize, String> {
    let graph_mutex = AUDIO_GRAPH.get()
        .ok_or("Audio graph not initialized")?;
    let graph = graph_mutex.lock().map_err(|e| e.to_string())?;
    let track_manager = graph.track_manager.lock().map_err(|e| e.to_string())?;

    let count = track_manager.get_all_tracks().len();
    Ok(count)
}

/// Get all track IDs as comma-separated string
pub fn get_all_track_ids() -> Result<String, String> {
    let graph_mutex = AUDIO_GRAPH.get()
        .ok_or("Audio graph not initialized")?;
    let graph = graph_mutex.lock().map_err(|e| e.to_string())?;
    let track_manager = graph.track_manager.lock().map_err(|e| e.to_string())?;

    let all_tracks = track_manager.get_all_tracks();
    let ids: Vec<String> = all_tracks.iter().map(|track_arc| {
        let track = track_arc.lock().unwrap();
        track.id.to_string()
    }).collect();

    Ok(ids.join(","))
}

/// Get track info (for UI display)
///
/// Returns: "track_id,name,type,volume_db,pan,mute,solo"
pub fn get_track_info(track_id: TrackId) -> Result<String, String> {
    let graph_mutex = AUDIO_GRAPH.get()
        .ok_or("Audio graph not initialized")?;
    let graph = graph_mutex.lock().map_err(|e| e.to_string())?;
    let track_manager = graph.track_manager.lock().map_err(|e| e.to_string())?;

    if let Some(track_arc) = track_manager.get_track(track_id) {
        let track = track_arc.lock().map_err(|e| e.to_string())?;
        let type_str = match track.track_type {
            TrackType::Audio => "Audio",
            TrackType::Midi => "MIDI",
            TrackType::Return => "Return",
            TrackType::Group => "Group",
            TrackType::Master => "Master",
        };
        Ok(format!(
            "{},{},{},{:.2},{:.2},{},{}",
            track.id,
            track.name,
            type_str,
            track.volume_db,
            track.pan,
            track.mute as u8,
            track.solo as u8
        ))
    } else {
        Err(format!("Track {} not found", track_id))
    }
}

/// Get track peak levels (M5.5)
/// Returns CSV: "peak_left_db,peak_right_db"
pub fn get_track_peak_levels(track_id: TrackId) -> Result<String, String> {
    let graph_mutex = AUDIO_GRAPH.get()
        .ok_or("Audio graph not initialized")?;
    let graph = graph_mutex.lock().map_err(|e| e.to_string())?;
    let track_manager = graph.track_manager.lock().map_err(|e| e.to_string())?;

    if let Some(track_arc) = track_manager.get_track(track_id) {
        let track = track_arc.lock().map_err(|e| e.to_string())?;
        let (peak_left_db, peak_right_db) = track.get_peak_db();
        Ok(format!("{:.2},{:.2}", peak_left_db, peak_right_db))
    } else {
        Err(format!("Track {} not found", track_id))
    }
}

/// Move an existing clip to a track
///
/// This migrates clips from the legacy global timeline to track-based system
pub fn move_clip_to_track(track_id: TrackId, clip_id: ClipId) -> Result<String, String> {
    let graph_mutex = AUDIO_GRAPH.get()
        .ok_or("Audio graph not initialized")?;
    let graph = graph_mutex.lock().map_err(|e| e.to_string())?;
    let track_manager = graph.track_manager.lock().map_err(|e| e.to_string())?;

    // Find the clip in the global timeline
    let mut clips = graph.get_clips().lock().map_err(|e| e.to_string())?;
    let clip_idx = clips.iter().position(|c| c.id == clip_id)
        .ok_or(format!("Clip {} not found in global timeline", clip_id))?;

    // Remove from global timeline
    let timeline_clip = clips.remove(clip_idx);

    // Add to track
    if let Some(track_arc) = track_manager.get_track(track_id) {
        let mut track = track_arc.lock().map_err(|e| e.to_string())?;

        // Verify track type matches clip type
        if track.track_type != TrackType::Audio && track.track_type != TrackType::Group {
            clips.insert(clip_idx, timeline_clip); // Put it back
            return Err(format!("Track {} is not an audio track", track_id));
        }

        track.audio_clips.push(timeline_clip);
        Ok(format!("Moved clip {} to track {}", clip_id, track_id))
    } else {
        clips.insert(clip_idx, timeline_clip); // Put it back
        Err(format!("Track {} not found", track_id))
    }
}

// ============================================================================
// M4: EFFECT MANAGEMENT
// ============================================================================

/// Add an effect to a track's FX chain
pub fn add_effect_to_track(track_id: TrackId, effect_type_str: &str) -> Result<u64, String> {
    use crate::effects::*;

    let graph_mutex = AUDIO_GRAPH.get()
        .ok_or("Audio graph not initialized")?;
    let graph = graph_mutex.lock().map_err(|e| e.to_string())?;
    let track_manager = graph.track_manager.lock().map_err(|e| e.to_string())?;
    let mut effect_manager = graph.effect_manager.lock().map_err(|e| e.to_string())?;

    // Create the effect
    let effect = match effect_type_str.to_lowercase().as_str() {
        "eq" => EffectType::EQ(ParametricEQ::new()),
        "compressor" => EffectType::Compressor(Compressor::new()),
        "reverb" => EffectType::Reverb(Reverb::new()),
        "delay" => EffectType::Delay(Delay::new()),
        "chorus" => EffectType::Chorus(Chorus::new()),
        "limiter" => EffectType::Limiter(Limiter::new()),
        _ => return Err(format!("Unknown effect type: {}", effect_type_str)),
    };

    // Add effect to effect manager
    let effect_id = effect_manager.create_effect(effect);

    // Add effect to track's FX chain
    if let Some(track_arc) = track_manager.get_track(track_id) {
        let mut track = track_arc.lock().map_err(|e| e.to_string())?;
        track.fx_chain.push(effect_id);
        eprintln!("🎛️ [API] Added {} effect (ID: {}) to track {}", effect_type_str, effect_id, track_id);
        Ok(effect_id)
    } else {
        Err(format!("Track {} not found", track_id))
    }
}

/// Remove an effect from a track's FX chain
pub fn remove_effect_from_track(track_id: TrackId, effect_id: u64) -> Result<String, String> {
    let graph_mutex = AUDIO_GRAPH.get()
        .ok_or("Audio graph not initialized")?;
    let graph = graph_mutex.lock().map_err(|e| e.to_string())?;
    let track_manager = graph.track_manager.lock().map_err(|e| e.to_string())?;
    let mut effect_manager = graph.effect_manager.lock().map_err(|e| e.to_string())?;

    // Remove from track's FX chain
    if let Some(track_arc) = track_manager.get_track(track_id) {
        let mut track = track_arc.lock().map_err(|e| e.to_string())?;
        if let Some(pos) = track.fx_chain.iter().position(|&id| id == effect_id) {
            track.fx_chain.remove(pos);
            // Remove from effect manager
            effect_manager.remove_effect(effect_id);
            eprintln!("🗑️ [API] Removed effect {} from track {}", effect_id, track_id);
            Ok(format!("Effect {} removed from track {}", effect_id, track_id))
        } else {
            Err(format!("Effect {} not found in track {}'s FX chain", effect_id, track_id))
        }
    } else {
        Err(format!("Track {} not found", track_id))
    }
}

/// Get all effects on a track (returns CSV: "effect_id,effect_id,...")
pub fn get_track_effects(track_id: TrackId) -> Result<String, String> {
    let graph_mutex = AUDIO_GRAPH.get()
        .ok_or("Audio graph not initialized")?;
    let graph = graph_mutex.lock().map_err(|e| e.to_string())?;
    let track_manager = graph.track_manager.lock().map_err(|e| e.to_string())?;

    if let Some(track_arc) = track_manager.get_track(track_id) {
        let track = track_arc.lock().map_err(|e| e.to_string())?;
        let ids: Vec<String> = track.fx_chain.iter().map(|id| id.to_string()).collect();
        Ok(ids.join(","))
    } else {
        Err(format!("Track {} not found", track_id))
    }
}

/// Get effect info (returns JSON-like string with type and parameters)
pub fn get_effect_info(effect_id: u64) -> Result<String, String> {
    use crate::effects::*;

    let graph_mutex = AUDIO_GRAPH.get()
        .ok_or("Audio graph not initialized")?;
    let graph = graph_mutex.lock().map_err(|e| e.to_string())?;
    let effect_manager = graph.effect_manager.lock().map_err(|e| e.to_string())?;

    if let Some(effect_arc) = effect_manager.get_effect(effect_id) {
        let effect = effect_arc.lock().map_err(|e| e.to_string())?;

        let info = match &*effect {
            EffectType::EQ(eq) => format!(
                "type:eq,low_freq:{},low_gain:{},mid1_freq:{},mid1_gain:{},mid1_q:{},mid2_freq:{},mid2_gain:{},mid2_q:{},high_freq:{},high_gain:{}",
                eq.low_freq, eq.low_gain_db, eq.mid1_freq, eq.mid1_gain_db, eq.mid1_q,
                eq.mid2_freq, eq.mid2_gain_db, eq.mid2_q, eq.high_freq, eq.high_gain_db
            ),
            EffectType::Compressor(comp) => format!(
                "type:compressor,threshold:{},ratio:{},attack:{},release:{},makeup:{}",
                comp.threshold_db, comp.ratio, comp.attack_ms, comp.release_ms, comp.makeup_gain_db
            ),
            EffectType::Reverb(rev) => format!(
                "type:reverb,room_size:{},damping:{},wet_dry:{}",
                rev.room_size, rev.damping, rev.wet_dry_mix
            ),
            EffectType::Delay(delay) => format!(
                "type:delay,time:{},feedback:{},wet_dry:{}",
                delay.delay_time_ms, delay.feedback, delay.wet_dry_mix
            ),
            EffectType::Chorus(chorus) => format!(
                "type:chorus,rate:{},depth:{},wet_dry:{}",
                chorus.rate_hz, chorus.depth, chorus.wet_dry_mix
            ),
            EffectType::Limiter(lim) => format!(
                "type:limiter,threshold:{},release:{}",
                lim.threshold_db, lim.release_ms
            ),
        };
        Ok(info)
    } else {
        Err(format!("Effect {} not found", effect_id))
    }
}

/// Set an effect parameter
pub fn set_effect_parameter(effect_id: u64, param_name: &str, value: f32) -> Result<String, String> {
    use crate::effects::*;

    let graph_mutex = AUDIO_GRAPH.get()
        .ok_or("Audio graph not initialized")?;
    let graph = graph_mutex.lock().map_err(|e| e.to_string())?;
    let effect_manager = graph.effect_manager.lock().map_err(|e| e.to_string())?;

    if let Some(effect_arc) = effect_manager.get_effect(effect_id) {
        let mut effect = effect_arc.lock().map_err(|e| e.to_string())?;

        match &mut *effect {
            EffectType::EQ(eq) => {
                match param_name {
                    "low_freq" => { eq.low_freq = value; eq.update_coefficients(); }
                    "low_gain" => { eq.low_gain_db = value; eq.update_coefficients(); }
                    "mid1_freq" => { eq.mid1_freq = value; eq.update_coefficients(); }
                    "mid1_gain" => { eq.mid1_gain_db = value; eq.update_coefficients(); }
                    "mid1_q" => { eq.mid1_q = value; eq.update_coefficients(); }
                    "mid2_freq" => { eq.mid2_freq = value; eq.update_coefficients(); }
                    "mid2_gain" => { eq.mid2_gain_db = value; eq.update_coefficients(); }
                    "mid2_q" => { eq.mid2_q = value; eq.update_coefficients(); }
                    "high_freq" => { eq.high_freq = value; eq.update_coefficients(); }
                    "high_gain" => { eq.high_gain_db = value; eq.update_coefficients(); }
                    _ => return Err(format!("Unknown EQ parameter: {}", param_name)),
                }
            }
            EffectType::Compressor(comp) => {
                match param_name {
                    "threshold" => { comp.threshold_db = value; }
                    "ratio" => { comp.ratio = value; }
                    "attack" => { comp.attack_ms = value; comp.update_coefficients(); }
                    "release" => { comp.release_ms = value; comp.update_coefficients(); }
                    "makeup" => { comp.makeup_gain_db = value; }
                    _ => return Err(format!("Unknown Compressor parameter: {}", param_name)),
                }
            }
            EffectType::Reverb(rev) => {
                match param_name {
                    "room_size" => { rev.room_size = value; }
                    "damping" => { rev.damping = value; }
                    "wet_dry" => { rev.wet_dry_mix = value; }
                    _ => return Err(format!("Unknown Reverb parameter: {}", param_name)),
                }
            }
            EffectType::Delay(delay) => {
                match param_name {
                    "time" => { delay.delay_time_ms = value; }
                    "feedback" => { delay.feedback = value; }
                    "wet_dry" => { delay.wet_dry_mix = value; }
                    _ => return Err(format!("Unknown Delay parameter: {}", param_name)),
                }
            }
            EffectType::Chorus(chorus) => {
                match param_name {
                    "rate" => { chorus.rate_hz = value; }
                    "depth" => { chorus.depth = value; }
                    "wet_dry" => { chorus.wet_dry_mix = value; }
                    _ => return Err(format!("Unknown Chorus parameter: {}", param_name)),
                }
            }
            EffectType::Limiter(lim) => {
                match param_name {
                    "threshold" => { lim.threshold_db = value; }
                    "release" => { lim.release_ms = value; lim.update_coefficients(); }
                    _ => return Err(format!("Unknown Limiter parameter: {}", param_name)),
                }
            }
        }
        Ok(format!("Set {} = {} on effect {}", param_name, value, effect_id))
    } else {
        Err(format!("Effect {} not found", effect_id))
    }
}

/// Delete a track (cannot delete master)
pub fn delete_track(track_id: TrackId) -> Result<String, String> {
    let graph_mutex = AUDIO_GRAPH.get()
        .ok_or("Audio graph not initialized")?;
    let graph = graph_mutex.lock().map_err(|e| e.to_string())?;
    let mut track_manager = graph.track_manager.lock().map_err(|e| e.to_string())?;

    if track_manager.remove_track(track_id) {
        Ok(format!("Track {} deleted", track_id))
    } else {
        Err(format!("Cannot delete track {} (either not found or is master track)", track_id))
    }
}

// ============================================================================
// M5: PROJECT SAVE/LOAD API
// ============================================================================

use std::path::Path;

/// Save project to .solar folder
///
/// # Arguments
/// * `project_name` - Name of the project
/// * `project_path_str` - Path to the .solar folder (e.g., "/path/to/MyProject.solar")
///
/// # Returns
/// Success message on completion
pub fn save_project(project_name: String, project_path_str: String) -> Result<String, String> {
    use crate::project;

    let project_path = Path::new(&project_path_str);

    eprintln!("💾 [API] Saving project '{}' to {:?}", project_name, project_path);

    // Get audio graph
    let graph_mutex = AUDIO_GRAPH.get()
        .ok_or("Audio graph not initialized")?;
    let graph = graph_mutex.lock().map_err(|e| e.to_string())?;

    // Export audio graph state to ProjectData
    let mut project_data = graph.export_to_project_data(project_name);

    // Copy audio files to project folder and update paths
    let clips_mutex = AUDIO_CLIPS.get()
        .ok_or("Audio clips not initialized")?;
    let clips_map = clips_mutex.lock().map_err(|e| e.to_string())?;

    for audio_file in &mut project_data.audio_files {
        // Find the corresponding clip
        if let Some(clip_arc) = clips_map.get(&audio_file.id) {
            let source_path = Path::new(&clip_arc.file_path);

            // Copy file to project folder
            let relative_path = project::copy_audio_file_to_project(
                source_path,
                project_path,
                audio_file.id
            ).map_err(|e| e.to_string())?;

            // Update the relative path in project data
            audio_file.relative_path = relative_path;
        }
    }

    // Save project data to JSON
    project::save_project(&project_data, project_path)
        .map_err(|e| e.to_string())?;

    eprintln!("✅ [API] Project saved successfully");
    Ok(format!("Project saved to {:?}", project_path))
}

/// Load project from .solar folder
///
/// # Arguments
/// * `project_path_str` - Path to the .solar folder
///
/// # Returns
/// Success message with project name
pub fn load_project(project_path_str: String) -> Result<String, String> {
    use crate::project;
    use crate::audio_file::load_audio_file;

    let project_path = Path::new(&project_path_str);

    eprintln!("📂 [API] Loading project from {:?}", project_path);

    // Load project data from JSON
    let project_data = project::load_project(project_path)
        .map_err(|e| e.to_string())?;

    // Get audio graph
    let graph_mutex = AUDIO_GRAPH.get()
        .ok_or("Audio graph not initialized")?;
    let mut graph = graph_mutex.lock().map_err(|e| e.to_string())?;

    // Stop playback if running
    let _ = graph.stop();

    // Clear existing clips and tracks (except master)
    // TODO: Add proper clear methods to AudioGraph

    // Load audio files from project folder
    let clips_mutex = AUDIO_CLIPS.get()
        .ok_or("Audio clips not initialized")?;
    let mut clips_map = clips_mutex.lock().map_err(|e| e.to_string())?;

    // Clear existing clips
    clips_map.clear();

    for audio_file_data in &project_data.audio_files {
        let audio_file_path = project::resolve_audio_file_path(
            project_path,
            &audio_file_data.relative_path
        );

        eprintln!("📁 [API] Loading audio file: {:?}", audio_file_path);

        // Load the audio file
        let clip = load_audio_file(&audio_file_path)
            .map_err(|e| format!("Failed to load audio file {:?}: {}", audio_file_path, e))?;

        let clip_arc = Arc::new(clip);
        clips_map.insert(audio_file_data.id, clip_arc);
    }

    // Restore audio graph state from project data
    graph.restore_from_project_data(project_data.clone())
        .map_err(|e| e.to_string())?;

    eprintln!("✅ [API] Project loaded successfully");
    Ok(format!("Loaded project: {}", project_data.name))
}

/// Export project to WAV file
///
/// # Arguments
/// * `project_path_str` - Path to the .solar folder (for reading project data)
/// * `output_path_str` - Path to output WAV file
/// * `normalize` - Whether to normalize the output to -0.1 dBFS
///
/// # Returns
/// Success message with file path
pub fn export_to_wav(
    output_path_str: String,
    normalize: bool,
) -> Result<String, String> {
    use hound;

    let output_path = Path::new(&output_path_str);

    eprintln!("🎵 [API] Exporting to WAV: {:?}", output_path);

    // Get audio graph
    let graph_mutex = AUDIO_GRAPH.get()
        .ok_or("Audio graph not initialized")?;
    let graph = graph_mutex.lock().map_err(|e| e.to_string())?;

    // TODO: Implement offline rendering
    // For now, return error saying it's not implemented yet
    Err("WAV export not yet implemented - deferred to later in M5".to_string())
}

// ============================================================================
// M4: AUTOMATED TESTS
// ============================================================================

#[cfg(test)]
mod m4_tests {
    use super::*;

    fn setup_test_graph() -> Result<(), String> {
        // Initialize audio graph if not already initialized
        let _ = init_audio_graph();
        Ok(())
    }

    #[test]
    fn test_track_creation_audio() {
        setup_test_graph().unwrap();

        let result = create_track("audio", "Test Audio Track".to_string());
        assert!(result.is_ok(), "Failed to create audio track: {:?}", result);

        let track_id = result.unwrap();
        assert!(track_id >= 1, "Track ID should be >= 1 (master is 0)");

        println!("✅ Created audio track with ID: {}", track_id);
    }

    #[test]
    fn test_track_creation_midi() {
        setup_test_graph().unwrap();

        let result = create_track("midi", "Test MIDI Track".to_string());
        assert!(result.is_ok(), "Failed to create MIDI track");

        println!("✅ Created MIDI track with ID: {}", result.unwrap());
    }

    #[test]
    fn test_track_creation_return() {
        setup_test_graph().unwrap();

        let result = create_track("return", "Test Return Track".to_string());
        assert!(result.is_ok(), "Failed to create return track");

        println!("✅ Created return track with ID: {}", result.unwrap());
    }

    #[test]
    fn test_track_creation_invalid_type() {
        setup_test_graph().unwrap();

        let result = create_track("invalid_type", "Test".to_string());
        assert!(result.is_err(), "Should reject invalid track type");
        assert!(result.unwrap_err().contains("Unknown track type"));

        println!("✅ Correctly rejected invalid track type");
    }

    #[test]
    fn test_cannot_create_master_track() {
        setup_test_graph().unwrap();

        let result = create_track("master", "Another Master".to_string());
        assert!(result.is_err(), "Should not allow creating additional master tracks");
        assert!(result.unwrap_err().contains("Cannot create additional master tracks"));

        println!("✅ Correctly prevented duplicate master track");
    }

    #[test]
    fn test_track_count() {
        setup_test_graph().unwrap();

        let initial_count = get_track_count().unwrap();
        assert!(initial_count >= 1, "Should have at least master track");

        // Create a track
        let _ = create_track("audio", "Count Test".to_string()).unwrap();

        let new_count = get_track_count().unwrap();
        assert_eq!(new_count, initial_count + 1, "Track count should increase by 1");

        println!("✅ Track count: {} -> {} after creation", initial_count, new_count);
    }

    #[test]
    fn test_set_track_volume() {
        setup_test_graph().unwrap();

        let track_id = create_track("audio", "Volume Test".to_string()).unwrap();

        // Test various volume levels
        let test_cases = vec![
            (-6.0, "Set to -6 dB"),
            (0.0, "Set to unity (0 dB)"),
            (3.0, "Set to +3 dB"),
            (-96.0, "Set to silent (-96 dB)"),
            (6.0, "Set to max (+6 dB)"),
        ];

        for (volume_db, desc) in test_cases {
            let result = set_track_volume(track_id, volume_db);
            assert!(result.is_ok(), "{} failed: {:?}", desc, result);

            // Verify the volume was set
            let info = get_track_info(track_id).unwrap();
            let parts: Vec<&str> = info.split(',').collect();
            let stored_volume: f32 = parts[3].parse().unwrap();
            assert!((stored_volume - volume_db).abs() < 0.01,
                "{}: expected {}, got {}", desc, volume_db, stored_volume);
        }

        println!("✅ All volume levels set correctly");
    }

    #[test]
    fn test_volume_clamping() {
        setup_test_graph().unwrap();

        let track_id = create_track("audio", "Clamp Test".to_string()).unwrap();

        // Test out-of-range values (should clamp)
        set_track_volume(track_id, 100.0).unwrap(); // Should clamp to +6
        let info = get_track_info(track_id).unwrap();
        let parts: Vec<&str> = info.split(',').collect();
        let volume: f32 = parts[3].parse().unwrap();
        assert!(volume <= 6.0, "Volume should clamp to max +6 dB, got {}", volume);

        set_track_volume(track_id, -200.0).unwrap(); // Should clamp to -96
        let info = get_track_info(track_id).unwrap();
        let parts: Vec<&str> = info.split(',').collect();
        let volume: f32 = parts[3].parse().unwrap();
        assert!(volume >= -96.0, "Volume should clamp to min -96 dB, got {}", volume);

        println!("✅ Volume clamping works correctly");
    }

    #[test]
    fn test_set_track_pan() {
        setup_test_graph().unwrap();

        let track_id = create_track("audio", "Pan Test".to_string()).unwrap();

        // Test various pan positions
        let test_cases = vec![
            (-1.0, "Full left"),
            (0.0, "Center"),
            (1.0, "Full right"),
            (-0.5, "Half left"),
            (0.5, "Half right"),
        ];

        for (pan, desc) in test_cases {
            let result = set_track_pan(track_id, pan);
            assert!(result.is_ok(), "{} failed: {:?}", desc, result);

            // Verify the pan was set
            let info = get_track_info(track_id).unwrap();
            let parts: Vec<&str> = info.split(',').collect();
            let stored_pan: f32 = parts[4].parse().unwrap();
            assert!((stored_pan - pan).abs() < 0.01,
                "{}: expected {}, got {}", desc, pan, stored_pan);
        }

        println!("✅ All pan positions set correctly");
    }

    #[test]
    fn test_pan_clamping() {
        setup_test_graph().unwrap();

        let track_id = create_track("audio", "Pan Clamp Test".to_string()).unwrap();

        // Test out-of-range values
        set_track_pan(track_id, 5.0).unwrap(); // Should clamp to +1.0
        let info = get_track_info(track_id).unwrap();
        let parts: Vec<&str> = info.split(',').collect();
        let pan: f32 = parts[4].parse().unwrap();
        assert!(pan <= 1.0, "Pan should clamp to max +1.0, got {}", pan);

        set_track_pan(track_id, -5.0).unwrap(); // Should clamp to -1.0
        let info = get_track_info(track_id).unwrap();
        let parts: Vec<&str> = info.split(',').collect();
        let pan: f32 = parts[4].parse().unwrap();
        assert!(pan >= -1.0, "Pan should clamp to min -1.0, got {}", pan);

        println!("✅ Pan clamping works correctly");
    }

    #[test]
    fn test_track_mute() {
        setup_test_graph().unwrap();

        let track_id = create_track("audio", "Mute Test".to_string()).unwrap();

        // Test mute
        set_track_mute(track_id, true).unwrap();
        let info = get_track_info(track_id).unwrap();
        let parts: Vec<&str> = info.split(',').collect();
        let mute: u8 = parts[5].parse().unwrap();
        assert_eq!(mute, 1, "Mute should be 1 when enabled");

        // Test unmute
        set_track_mute(track_id, false).unwrap();
        let info = get_track_info(track_id).unwrap();
        let parts: Vec<&str> = info.split(',').collect();
        let mute: u8 = parts[5].parse().unwrap();
        assert_eq!(mute, 0, "Mute should be 0 when disabled");

        println!("✅ Mute/unmute works correctly");
    }

    #[test]
    fn test_track_solo() {
        setup_test_graph().unwrap();

        let track_id = create_track("audio", "Solo Test".to_string()).unwrap();

        // Test solo
        set_track_solo(track_id, true).unwrap();
        let info = get_track_info(track_id).unwrap();
        let parts: Vec<&str> = info.split(',').collect();
        let solo: u8 = parts[6].parse().unwrap();
        assert_eq!(solo, 1, "Solo should be 1 when enabled");

        // Test unsolo
        set_track_solo(track_id, false).unwrap();
        let info = get_track_info(track_id).unwrap();
        let parts: Vec<&str> = info.split(',').collect();
        let solo: u8 = parts[6].parse().unwrap();
        assert_eq!(solo, 0, "Solo should be 0 when disabled");

        println!("✅ Solo/unsolo works correctly");
    }

    #[test]
    fn test_get_track_info_format() {
        setup_test_graph().unwrap();

        let track_id = create_track("audio", "Info Test".to_string()).unwrap();

        let info = get_track_info(track_id).unwrap();
        println!("Track info: {}", info);

        // Parse CSV format: "id,name,type,volume_db,pan,mute,solo"
        let parts: Vec<&str> = info.split(',').collect();
        assert_eq!(parts.len(), 7, "Track info should have 7 fields");

        // Verify each field
        let id: u64 = parts[0].parse().expect("ID should be u64");
        assert_eq!(id, track_id, "ID should match");

        assert_eq!(parts[1], "Info Test", "Name should match");
        assert_eq!(parts[2], "Audio", "Type should be Audio");

        let volume: f32 = parts[3].parse().expect("Volume should be f32");
        assert_eq!(volume, 0.0, "Default volume should be 0 dB");

        let pan: f32 = parts[4].parse().expect("Pan should be f32");
        assert_eq!(pan, 0.0, "Default pan should be 0.0 (center)");

        let mute: u8 = parts[5].parse().expect("Mute should be u8");
        assert_eq!(mute, 0, "Default mute should be 0");

        let solo: u8 = parts[6].parse().expect("Solo should be u8");
        assert_eq!(solo, 0, "Default solo should be 0");

        println!("✅ Track info format is correct");
    }

    #[test]
    fn test_master_track_info() {
        setup_test_graph().unwrap();

        let info = get_track_info(0).unwrap(); // Master track is always ID 0
        println!("Master track info: {}", info);

        let parts: Vec<&str> = info.split(',').collect();
        assert_eq!(parts[0], "0", "Master track ID should be 0");
        assert_eq!(parts[1], "Master", "Master track name should be 'Master'");
        assert_eq!(parts[2], "Master", "Master track type should be 'Master'");

        println!("✅ Master track info is correct");
    }

    #[test]
    fn test_invalid_track_operations() {
        setup_test_graph().unwrap();

        let invalid_id = 9999u64;

        // All operations on invalid track should return errors
        assert!(get_track_info(invalid_id).is_err(), "get_track_info should fail");
        assert!(set_track_volume(invalid_id, 0.0).is_err(), "set_track_volume should fail");
        assert!(set_track_pan(invalid_id, 0.0).is_err(), "set_track_pan should fail");
        assert!(set_track_mute(invalid_id, true).is_err(), "set_track_mute should fail");
        assert!(set_track_solo(invalid_id, true).is_err(), "set_track_solo should fail");

        println!("✅ All operations correctly reject invalid track ID");
    }

    #[test]
    fn test_multiple_tracks_independence() {
        setup_test_graph().unwrap();

        // Create multiple tracks
        let track1 = create_track("audio", "Track 1".to_string()).unwrap();
        let track2 = create_track("audio", "Track 2".to_string()).unwrap();
        let track3 = create_track("audio", "Track 3".to_string()).unwrap();

        // Set different values
        set_track_volume(track1, -6.0).unwrap();
        set_track_volume(track2, 0.0).unwrap();
        set_track_volume(track3, 3.0).unwrap();

        set_track_pan(track1, -1.0).unwrap();
        set_track_pan(track2, 0.0).unwrap();
        set_track_pan(track3, 1.0).unwrap();

        set_track_mute(track1, true).unwrap();
        set_track_solo(track3, true).unwrap();

        // Verify each track has independent state
        let info1 = get_track_info(track1).unwrap();
        let parts1: Vec<&str> = info1.split(',').collect();
        assert_eq!(parts1[3], "-6.00", "Track 1 volume");
        assert_eq!(parts1[4], "-1.00", "Track 1 pan");
        assert_eq!(parts1[5], "1", "Track 1 mute");
        assert_eq!(parts1[6], "0", "Track 1 solo");

        let info2 = get_track_info(track2).unwrap();
        let parts2: Vec<&str> = info2.split(',').collect();
        assert_eq!(parts2[3], "0.00", "Track 2 volume");
        assert_eq!(parts2[4], "0.00", "Track 2 pan");
        assert_eq!(parts2[5], "0", "Track 2 mute");
        assert_eq!(parts2[6], "0", "Track 2 solo");

        let info3 = get_track_info(track3).unwrap();
        let parts3: Vec<&str> = info3.split(',').collect();
        assert_eq!(parts3[3], "3.00", "Track 3 volume");
        assert_eq!(parts3[4], "1.00", "Track 3 pan");
        assert_eq!(parts3[5], "0", "Track 3 mute");
        assert_eq!(parts3[6], "1", "Track 3 solo");

        println!("✅ Multiple tracks maintain independent state");
    }

    #[test]
    fn test_track_type_names() {
        setup_test_graph().unwrap();

        let audio = create_track("audio", "A".to_string()).unwrap();
        let midi = create_track("midi", "M".to_string()).unwrap();
        let return_track = create_track("return", "R".to_string()).unwrap();

        let audio_info = get_track_info(audio).unwrap();
        assert!(audio_info.contains("Audio"), "Audio track should have 'Audio' type");

        let midi_info = get_track_info(midi).unwrap();
        assert!(midi_info.contains("MIDI"), "MIDI track should have 'MIDI' type");

        let return_info = get_track_info(return_track).unwrap();
        assert!(return_info.contains("Return"), "Return track should have 'Return' type");

        println!("✅ Track type names are correct");
    }
}
