/// Built-in subtractive synthesizer
use crate::midi::{MidiEvent, MidiEventType};
use std::f32::consts::PI;

const MAX_VOICES: usize = 16; // Polyphony limit
const SAMPLE_RATE: f32 = 48000.0;

/// Oscillator waveform type
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum OscillatorType {
    Sine,
    Saw,
    Square,
}

/// ADSR envelope state
#[derive(Debug, Clone, Copy, PartialEq)]
enum EnvelopeState {
    Idle,
    Attack,
    Decay,
    Sustain,
    Release,
}

/// ADSR envelope parameters (in seconds)
#[derive(Debug, Clone, Copy)]
pub struct EnvelopeParams {
    pub attack: f32,
    pub decay: f32,
    pub sustain: f32, // Amplitude level (0.0 to 1.0)
    pub release: f32,
}

impl Default for EnvelopeParams {
    fn default() -> Self {
        Self {
            attack: 0.01,   // 10ms attack
            decay: 0.1,     // 100ms decay
            sustain: 0.7,   // 70% sustain level
            release: 0.2,   // 200ms release
        }
    }
}

/// ADSR envelope generator
#[derive(Debug, Clone, Copy)]
struct Envelope {
    params: EnvelopeParams,
    state: EnvelopeState,
    level: f32,
    time: f32, // Time in current state (in samples)
}

impl Envelope {
    fn new(params: EnvelopeParams) -> Self {
        Self {
            params,
            state: EnvelopeState::Idle,
            level: 0.0,
            time: 0.0,
        }
    }

    fn note_on(&mut self) {
        self.state = EnvelopeState::Attack;
        self.time = 0.0;
        // Don't reset level - allows for re-triggering
    }

    fn note_off(&mut self) {
        self.state = EnvelopeState::Release;
        self.time = 0.0;
    }

    fn process(&mut self) -> f32 {
        match self.state {
            EnvelopeState::Idle => {
                self.level = 0.0;
            }
            EnvelopeState::Attack => {
                let attack_samples = self.params.attack * SAMPLE_RATE;
                if attack_samples > 0.0 {
                    self.level = self.time / attack_samples;
                    if self.level >= 1.0 {
                        self.level = 1.0;
                        self.state = EnvelopeState::Decay;
                        self.time = 0.0;
                    }
                } else {
                    self.level = 1.0;
                    self.state = EnvelopeState::Decay;
                    self.time = 0.0;
                }
            }
            EnvelopeState::Decay => {
                let decay_samples = self.params.decay * SAMPLE_RATE;
                if decay_samples > 0.0 {
                    let decay_amount = 1.0 - self.params.sustain;
                    self.level = 1.0 - (self.time / decay_samples * decay_amount);
                    if self.level <= self.params.sustain {
                        self.level = self.params.sustain;
                        self.state = EnvelopeState::Sustain;
                    }
                } else {
                    self.level = self.params.sustain;
                    self.state = EnvelopeState::Sustain;
                }
            }
            EnvelopeState::Sustain => {
                self.level = self.params.sustain;
            }
            EnvelopeState::Release => {
                let release_samples = self.params.release * SAMPLE_RATE;
                if release_samples > 0.0 {
                    let start_level = self.level;
                    self.level = start_level * (1.0 - self.time / release_samples);
                    if self.level <= 0.0001 {
                        self.level = 0.0;
                        self.state = EnvelopeState::Idle;
                    }
                } else {
                    self.level = 0.0;
                    self.state = EnvelopeState::Idle;
                }
            }
        }

        self.time += 1.0;
        self.level.max(0.0).min(1.0)
    }

    fn is_active(&self) -> bool {
        self.state != EnvelopeState::Idle
    }
}

/// Single synthesizer voice
#[derive(Debug, Clone, Copy)]
struct Voice {
    note: u8,
    velocity: f32,
    phase: f32,      // Oscillator phase (0.0 to 1.0)
    frequency: f32,  // Hz
    envelope: Envelope,
    is_active: bool,
}

impl Voice {
    fn new() -> Self {
        Self {
            note: 0,
            velocity: 0.0,
            phase: 0.0,
            frequency: 440.0,
            envelope: Envelope::new(EnvelopeParams::default()),
            is_active: false,
        }
    }

    fn note_on(&mut self, note: u8, velocity: f32, envelope_params: EnvelopeParams) {
        self.note = note;
        self.velocity = velocity;
        self.phase = 0.0;
        self.frequency = midi_note_to_frequency(note);
        self.envelope = Envelope::new(envelope_params);
        self.envelope.note_on();
        self.is_active = true;
    }

    fn note_off(&mut self) {
        self.envelope.note_off();
    }

    fn process(&mut self, osc_type: OscillatorType) -> f32 {
        if !self.is_active {
            return 0.0;
        }

        // Generate oscillator waveform
        let sample = match osc_type {
            OscillatorType::Sine => (self.phase * 2.0 * PI).sin(),
            OscillatorType::Saw => 2.0 * self.phase - 1.0,
            OscillatorType::Square => {
                if self.phase < 0.5 {
                    1.0
                } else {
                    -1.0
                }
            }
        };

        // Apply envelope
        let env_level = self.envelope.process();
        let output = sample * env_level * self.velocity;

        // Update phase
        self.phase += self.frequency / SAMPLE_RATE;
        while self.phase >= 1.0 {
            self.phase -= 1.0;
        }

        // Deactivate voice if envelope is done
        if !self.envelope.is_active() {
            self.is_active = false;
        }

        output
    }
}

/// Polyphonic subtractive synthesizer
pub struct Synthesizer {
    voices: [Voice; MAX_VOICES],
    oscillator_type: OscillatorType,
    envelope_params: EnvelopeParams,
    master_volume: f32,
}

impl Synthesizer {
    /// Create a new synthesizer
    pub fn new() -> Self {
        Self {
            voices: [Voice::new(); MAX_VOICES],
            oscillator_type: OscillatorType::Saw,
            envelope_params: EnvelopeParams::default(),
            master_volume: 0.3, // Prevent clipping
        }
    }

    /// Set oscillator type
    pub fn set_oscillator_type(&mut self, osc_type: OscillatorType) {
        self.oscillator_type = osc_type;
    }

    /// Set envelope parameters
    pub fn set_envelope(&mut self, params: EnvelopeParams) {
        self.envelope_params = params;
    }

    /// Set master volume (0.0 to 1.0)
    pub fn set_master_volume(&mut self, volume: f32) {
        self.master_volume = volume.max(0.0).min(1.0);
    }

    /// Process a MIDI event
    pub fn process_event(&mut self, event: &MidiEvent) {
        match event.event_type {
            MidiEventType::NoteOn { note, velocity } => {
                self.note_on(note, velocity);
            }
            MidiEventType::NoteOff { note, .. } => {
                self.note_off(note);
            }
        }
    }

    /// Trigger a note on
    fn note_on(&mut self, note: u8, velocity: u8) {
        let velocity_normalized = velocity as f32 / 127.0;
        let envelope_params = self.envelope_params; // Copy the envelope params

        // Find an available voice (prefer inactive, then oldest)
        if let Some(voice) = self.find_free_voice() {
            voice.note_on(note, velocity_normalized, envelope_params);
            eprintln!("🎹 [SYNTH] Note On: {} (vel: {})", note, velocity);
        } else {
            eprintln!("⚠️ [SYNTH] No free voices for note {}", note);
        }
    }

    /// Trigger a note off
    fn note_off(&mut self, note: u8) {
        // Find the voice playing this note
        for voice in &mut self.voices {
            if voice.is_active && voice.note == note {
                voice.note_off();
                eprintln!("🎹 [SYNTH] Note Off: {}", note);
                break;
            }
        }
    }

    /// Find a free voice (prefer inactive, then steal oldest)
    fn find_free_voice(&mut self) -> Option<&mut Voice> {
        // Find an inactive voice index first
        if let Some(index) = self.voices.iter().position(|v| !v.is_active) {
            return Some(&mut self.voices[index]);
        }

        // All voices active - steal the first one (could use more sophisticated logic)
        Some(&mut self.voices[0])
    }

    /// Process one audio sample (mono)
    pub fn process_sample(&mut self) -> f32 {
        let mut output = 0.0;

        for voice in &mut self.voices {
            if voice.is_active {
                output += voice.process(self.oscillator_type);
            }
        }

        output * self.master_volume
    }

    /// Process a buffer of audio samples (stereo)
    pub fn process_buffer(&mut self, output: &mut [f32], channels: usize) {
        let num_frames = output.len() / channels;

        for i in 0..num_frames {
            let sample = self.process_sample();

            // Write to all channels (mono -> stereo)
            for ch in 0..channels {
                output[i * channels + ch] = sample;
            }
        }
    }

    /// Get the number of active voices
    pub fn active_voice_count(&self) -> usize {
        self.voices.iter().filter(|v| v.is_active).count()
    }
}

/// Convert MIDI note number to frequency in Hz
fn midi_note_to_frequency(note: u8) -> f32 {
    // A4 (note 69) = 440 Hz
    // f = 440 * 2^((n - 69) / 12)
    440.0 * 2.0_f32.powf((note as f32 - 69.0) / 12.0)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_midi_to_frequency() {
        let a4 = midi_note_to_frequency(69);
        assert!((a4 - 440.0).abs() < 0.1);

        let c4 = midi_note_to_frequency(60);
        assert!((c4 - 261.63).abs() < 1.0);
    }

    #[test]
    fn test_envelope() {
        let mut env = Envelope::new(EnvelopeParams::default());
        env.note_on();

        // Should start at 0
        assert_eq!(env.state, EnvelopeState::Attack);

        // Process some samples
        for _ in 0..100 {
            env.process();
        }

        // Should be in attack phase
        assert!(env.level > 0.0);
    }

    #[test]
    fn test_synth_note_on_off() {
        let mut synth = Synthesizer::new();

        // Trigger note on
        synth.note_on(60, 100);
        assert_eq!(synth.active_voice_count(), 1);

        // Process some samples
        for _ in 0..1000 {
            synth.process_sample();
        }

        // Trigger note off
        synth.note_off(60);

        // Voice should still be active during release
        assert!(synth.active_voice_count() > 0);
    }

    #[test]
    fn test_synth_polyphony() {
        let mut synth = Synthesizer::new();

        // Play multiple notes
        for note in 60..65 {
            synth.note_on(note, 100);
        }

        assert_eq!(synth.active_voice_count(), 5);
    }
}
