/// Audio graph and playback engine
use crate::audio_file::{AudioClip, TARGET_SAMPLE_RATE};
use crate::audio_input::AudioInputManager;
use crate::recorder::Recorder;
use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use std::sync::{Arc, Mutex};
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};

/// Unique identifier for audio clips
pub type ClipId = u64;

/// Represents a clip placed on the timeline
#[derive(Clone)]
pub struct TimelineClip {
    pub id: ClipId,
    pub clip: Arc<AudioClip>,
    /// Position on timeline in seconds
    pub start_time: f64,
    /// Offset into the clip in seconds (for trimming start)
    pub offset: f64,
    /// Duration to play (None = play entire clip)
    pub duration: Option<f64>,
}

/// Transport state
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TransportState {
    Stopped,
    Playing,
    Paused,
}

/// The main audio graph that manages playback
pub struct AudioGraph {
    /// All clips on the timeline
    clips: Arc<Mutex<Vec<TimelineClip>>>,
    /// Current playhead position in samples
    playhead_samples: Arc<AtomicU64>,
    /// Transport state
    state: Arc<Mutex<TransportState>>,
    /// Audio output stream (kept alive)
    stream: Option<cpal::Stream>,
    /// Next clip ID
    next_clip_id: Arc<Mutex<ClipId>>,
    /// Audio input manager
    pub input_manager: Arc<Mutex<AudioInputManager>>,
    /// Recorder
    pub recorder: Arc<Recorder>,
}

// SAFETY: AudioGraph is only accessed through a Mutex in the API layer,
// ensuring thread-safe access even though cpal::Stream is not Send.
// The stream is created and used only within the context of the Mutex lock.
unsafe impl Send for AudioGraph {}

impl AudioGraph {
    /// Create a new audio graph
    pub fn new() -> anyhow::Result<Self> {
        let mut input_manager = AudioInputManager::new()?;
        // Enumerate devices on creation
        let _ = input_manager.enumerate_devices();
        
        Ok(Self {
            clips: Arc::new(Mutex::new(Vec::new())),
            playhead_samples: Arc::new(AtomicU64::new(0)),
            state: Arc::new(Mutex::new(TransportState::Stopped)),
            stream: None,
            next_clip_id: Arc::new(Mutex::new(0)),
            input_manager: Arc::new(Mutex::new(input_manager)),
            recorder: Arc::new(Recorder::new()),
        })
    }

    /// Add a clip to the timeline
    pub fn add_clip(&self, clip: Arc<AudioClip>, start_time: f64) -> ClipId {
        let mut clips = self.clips.lock().unwrap();
        let id = {
            let mut next_id = self.next_clip_id.lock().unwrap();
            let id = *next_id;
            *next_id += 1;
            id
        };

        clips.push(TimelineClip {
            id,
            clip,
            start_time,
            offset: 0.0,
            duration: None,
        });

        id
    }

    /// Remove a clip from the timeline
    pub fn remove_clip(&self, clip_id: ClipId) -> bool {
        let mut clips = self.clips.lock().unwrap();
        if let Some(pos) = clips.iter().position(|c| c.id == clip_id) {
            clips.remove(pos);
            true
        } else {
            false
        }
    }

    /// Get the current playhead position in seconds
    pub fn get_playhead_position(&self) -> f64 {
        let samples = self.playhead_samples.load(Ordering::SeqCst);
        samples as f64 / TARGET_SAMPLE_RATE as f64
    }

    /// Seek to a specific position in seconds
    pub fn seek(&self, position_seconds: f64) {
        let samples = (position_seconds * TARGET_SAMPLE_RATE as f64) as u64;
        self.playhead_samples.store(samples, Ordering::SeqCst);
    }

    /// Get current transport state
    pub fn get_state(&self) -> TransportState {
        *self.state.lock().unwrap()
    }

    /// Start playback
    pub fn play(&mut self) -> anyhow::Result<()> {
        {
            let mut state = self.state.lock().unwrap();
            if *state == TransportState::Playing {
                return Ok(()); // Already playing
            }
            *state = TransportState::Playing;
        }

        // If no stream exists, create one
        if self.stream.is_none() {
            let stream = self.create_audio_stream()?;
            stream.play()?;
            self.stream = Some(stream);
        } else {
            // Resume existing stream
            if let Some(stream) = &self.stream {
                stream.play()?;
            }
        }

        Ok(())
    }

    /// Pause playback (keeps position)
    pub fn pause(&mut self) -> anyhow::Result<()> {
        {
            let mut state = self.state.lock().unwrap();
            *state = TransportState::Paused;
        }

        if let Some(stream) = &self.stream {
            stream.pause()?;
        }

        Ok(())
    }

    /// Stop playback (resets to start)
    pub fn stop(&mut self) -> anyhow::Result<()> {
        {
            let mut state = self.state.lock().unwrap();
            *state = TransportState::Stopped;
        }

        if let Some(stream) = &self.stream {
            stream.pause()?;
        }

        // Reset playhead to start
        self.playhead_samples.store(0, Ordering::SeqCst);

        Ok(())
    }

    /// Create the audio output stream
    fn create_audio_stream(&self) -> anyhow::Result<cpal::Stream> {
        let host = cpal::default_host();
        let device = host
            .default_output_device()
            .ok_or_else(|| anyhow::anyhow!("No output device available"))?;

        let config = device.default_output_config()?;
        
        // Clone Arcs for the audio callback
        let clips = self.clips.clone();
        let playhead_samples = self.playhead_samples.clone();
        let state = self.state.clone();
        let input_manager = self.input_manager.clone();
        let recorder_refs = self.recorder.get_callback_refs();

        let stream = device.build_output_stream(
            &config.into(),
            move |data: &mut [f32], _: &cpal::OutputCallbackInfo| {
                // Check if we should be playing
                let is_playing = {
                    let s = state.lock().unwrap();
                    *s == TransportState::Playing
                };

                if !is_playing {
                    // Even when not playing, we might be recording
                    // Process metronome and recording
                    let frames = data.len() / 2;
                    
                    // Log channel info once
                    static LOGGED_CHANNELS: AtomicBool = AtomicBool::new(false);

                    for frame_idx in 0..frames {
                        // Get input samples (if recording)
                        let (input_left, input_right) = if let Ok(input_mgr) = input_manager.lock() {
                            let channels = input_mgr.get_input_channels();

                            // Log once for debugging
                            if !LOGGED_CHANNELS.swap(true, Ordering::Relaxed) {
                                eprintln!("🔊 [AudioGraph] Reading input with {} channels", channels);
                            }

                            if channels == 1 {
                                // Mono input: read 1 sample and duplicate to both channels
                                if let Some(samples) = input_mgr.read_samples(1) {
                                    let mono_sample = samples.get(0).copied().unwrap_or(0.0);
                                    (mono_sample, mono_sample)
                                } else {
                                    (0.0, 0.0)
                                }
                            } else {
                                // Stereo input: read 2 samples
                                if let Some(samples) = input_mgr.read_samples(2) {
                                    (samples.get(0).copied().unwrap_or(0.0),
                                     samples.get(1).copied().unwrap_or(0.0))
                                } else {
                                    (0.0, 0.0)
                                }
                            }
                        } else {
                            // Failed to acquire input manager lock - audio samples will be dropped
                            eprintln!("⚠️  [AudioGraph] Input mutex lock contention - samples dropped!");
                            (0.0, 0.0)
                        };

                        // Process recording and get metronome output
                        let (met_left, met_right) = recorder_refs.process_frame(input_left, input_right);

                        // Output only metronome when not playing
                        data[frame_idx * 2] = met_left;
                        data[frame_idx * 2 + 1] = met_right;
                    }
                    return;
                }

                // Calculate how many frames we need (stereo = 2 samples per frame)
                let frames = data.len() / 2;
                let current_playhead = playhead_samples.load(Ordering::SeqCst);

                // Get clips (lock briefly)
                let clips_snapshot = {
                    let clips_lock = clips.lock().unwrap();
                    clips_lock.clone()
                };

                // Debug: Log clip count periodically
                static PLAYBACK_FRAME_COUNTER: AtomicU64 = AtomicU64::new(0);
                let frame_count = PLAYBACK_FRAME_COUNTER.fetch_add(1, Ordering::Relaxed);
                if frame_count % 4800 == 0 {  // Log every ~0.1s
                    eprintln!("🔊 [Playback] {} clips on timeline, playhead: {:.2}s",
                        clips_snapshot.len(), current_playhead as f64 / TARGET_SAMPLE_RATE as f64);
                }

                // Mix all clips into the output buffer
                for frame_idx in 0..frames {
                    let playhead_frame = current_playhead + frame_idx as u64;
                    let playhead_seconds = playhead_frame as f64 / TARGET_SAMPLE_RATE as f64;

                    let mut left = 0.0;
                    let mut right = 0.0;

                    // Mix all active clips
                    for timeline_clip in &clips_snapshot {
                        // Check if this clip is active at current playhead
                        let clip_duration = timeline_clip.duration
                            .unwrap_or(timeline_clip.clip.duration_seconds);
                        let clip_end = timeline_clip.start_time + clip_duration;

                        if playhead_seconds >= timeline_clip.start_time 
                            && playhead_seconds < clip_end 
                        {
                            // Calculate position within the clip
                            let time_in_clip = playhead_seconds - timeline_clip.start_time + timeline_clip.offset;
                            let frame_in_clip = (time_in_clip * TARGET_SAMPLE_RATE as f64) as usize;

                            // Get samples from clip
                            if let Some(l) = timeline_clip.clip.get_sample(frame_in_clip, 0) {
                                left += l;
                            }
                            if timeline_clip.clip.channels > 1 {
                                if let Some(r) = timeline_clip.clip.get_sample(frame_in_clip, 1) {
                                    right += r;
                                }
                            } else {
                                // Mono clip - duplicate to right channel
                                if let Some(l) = timeline_clip.clip.get_sample(frame_in_clip, 0) {
                                    right += l;
                                }
                            }
                        }
                    }

                    // Get input samples (if recording)
                    let (input_left, input_right) = if let Ok(input_mgr) = input_manager.lock() {
                        let channels = input_mgr.get_input_channels();
                        if channels == 1 {
                            // Mono input: read 1 sample and duplicate to both channels
                            if let Some(samples) = input_mgr.read_samples(1) {
                                let mono_sample = samples.get(0).copied().unwrap_or(0.0);
                                (mono_sample, mono_sample)
                            } else {
                                (0.0, 0.0)
                            }
                        } else {
                            // Stereo input: read 2 samples
                            if let Some(samples) = input_mgr.read_samples(2) {
                                (samples.get(0).copied().unwrap_or(0.0),
                                 samples.get(1).copied().unwrap_or(0.0))
                            } else {
                                (0.0, 0.0)
                            }
                        }
                    } else {
                        // Failed to acquire input manager lock
                        eprintln!("⚠️  [AudioGraph] Input mutex lock contention during playback - samples dropped!");
                        (0.0, 0.0)
                    };

                    // Process recording and get metronome output
                    let (met_left, met_right) = recorder_refs.process_frame(input_left, input_right);

                    // Mix playback + metronome
                    left += met_left;
                    right += met_right;

                    // Clamp to prevent clipping
                    left = left.clamp(-1.0, 1.0);
                    right = right.clamp(-1.0, 1.0);

                    // Write to output buffer (interleaved stereo)
                    data[frame_idx * 2] = left;
                    data[frame_idx * 2 + 1] = right;
                }

                // Advance playhead
                playhead_samples.fetch_add(frames as u64, Ordering::SeqCst);
            },
            move |err| {
                eprintln!("Audio stream error: {}", err);
            },
            None,
        )?;

        Ok(stream)
    }

    /// Get number of clips
    pub fn clip_count(&self) -> usize {
        self.clips.lock().unwrap().len()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::audio_file::AudioClip;

    fn create_test_clip(duration: f64) -> AudioClip {
        let frames = (duration * TARGET_SAMPLE_RATE as f64) as usize;
        let samples = vec![0.1; frames * 2]; // Stereo
        AudioClip {
            samples,
            channels: 2,
            sample_rate: TARGET_SAMPLE_RATE,
            duration_seconds: duration,
            file_path: "test.wav".to_string(),
        }
    }

    #[test]
    fn test_audio_graph_creation() {
        let graph = AudioGraph::new();
        assert!(graph.is_ok());
    }

    #[test]
    fn test_add_clip() {
        let graph = AudioGraph::new().unwrap();
        let clip = Arc::new(create_test_clip(1.0));
        let id = graph.add_clip(clip, 0.0);
        assert_eq!(graph.clip_count(), 1);
        assert_eq!(id, 0);
    }

    #[test]
    fn test_remove_clip() {
        let graph = AudioGraph::new().unwrap();
        let clip = Arc::new(create_test_clip(1.0));
        let id = graph.add_clip(clip, 0.0);
        assert_eq!(graph.clip_count(), 1);
        
        let removed = graph.remove_clip(id);
        assert!(removed);
        assert_eq!(graph.clip_count(), 0);
    }

    #[test]
    fn test_playhead_position() {
        let graph = AudioGraph::new().unwrap();
        assert_eq!(graph.get_playhead_position(), 0.0);
        
        graph.seek(5.5);
        assert!((graph.get_playhead_position() - 5.5).abs() < 0.001);
    }

    #[test]
    fn test_transport_state() {
        let mut graph = AudioGraph::new().unwrap();
        assert_eq!(graph.get_state(), TransportState::Stopped);
        
        // Note: We can't test play() without audio device in CI
        // Just test state management
        graph.stop().unwrap();
        assert_eq!(graph.get_state(), TransportState::Stopped);
    }
}

