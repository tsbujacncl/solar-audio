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
    Triangle,
}

impl OscillatorType {
    pub fn from_str(s: &str) -> Self {
        match s.to_lowercase().as_str() {
            "sine" => OscillatorType::Sine,
            "saw" => OscillatorType::Saw,
            "square" => OscillatorType::Square,
            "triangle" => OscillatorType::Triangle,
            _ => OscillatorType::Sine,
        }
    }
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
            OscillatorType::Triangle => {
                4.0 * (self.phase - 0.5).abs() - 1.0
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

// ============================================================================
// PER-TRACK SYNTHESIZER (M6)
// ============================================================================

use std::collections::HashMap;

/// Filter types
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum FilterType {
    LowPass,
    HighPass,
    BandPass,
}

impl FilterType {
    pub fn from_str(s: &str) -> Self {
        match s.to_lowercase().as_str() {
            "lowpass" => FilterType::LowPass,
            "highpass" => FilterType::HighPass,
            "bandpass" => FilterType::BandPass,
            _ => FilterType::LowPass,
        }
    }
}

/// Biquad Filter (Audio EQ Cookbook)
#[derive(Debug, Clone)]
pub struct BiquadFilter {
    filter_type: FilterType,
    cutoff: f32,      // 0.0 to 1.0
    resonance: f32,   // 0.0 to 1.0
    sample_rate: f32,

    // Biquad coefficients
    a0: f32,
    a1: f32,
    a2: f32,
    b1: f32,
    b2: f32,

    // State
    x1: f32,
    x2: f32,
    y1: f32,
    y2: f32,
}

impl BiquadFilter {
    pub fn new(sample_rate: f32) -> Self {
        let mut filter = Self {
            filter_type: FilterType::LowPass,
            cutoff: 0.8,
            resonance: 0.2,
            sample_rate,
            a0: 1.0,
            a1: 0.0,
            a2: 0.0,
            b1: 0.0,
            b2: 0.0,
            x1: 0.0,
            x2: 0.0,
            y1: 0.0,
            y2: 0.0,
        };
        filter.update_coefficients();
        filter
    }

    pub fn set_filter_type(&mut self, filter_type: FilterType) {
        self.filter_type = filter_type;
        self.update_coefficients();
    }

    pub fn set_cutoff(&mut self, cutoff: f32) {
        self.cutoff = cutoff.clamp(0.0, 1.0);
        self.update_coefficients();
    }

    pub fn set_resonance(&mut self, resonance: f32) {
        self.resonance = resonance.clamp(0.0, 1.0);
        self.update_coefficients();
    }

    fn update_coefficients(&mut self) {
        // Map cutoff (0-1) to frequency (50Hz - 10kHz)
        let freq = 50.0 * (5.3 * self.cutoff).exp();
        let freq = freq.min(self.sample_rate * 0.49);

        // Map resonance (0-1) to Q factor (0.5 - 10.0)
        let q = 0.5 + self.resonance * 9.5;

        let omega = 2.0 * PI * freq / self.sample_rate;
        let sin_omega = omega.sin();
        let cos_omega = omega.cos();
        let alpha = sin_omega / (2.0 * q);

        match self.filter_type {
            FilterType::LowPass => {
                let b0 = (1.0 - cos_omega) / 2.0;
                let b1 = 1.0 - cos_omega;
                let b2 = (1.0 - cos_omega) / 2.0;
                let a0 = 1.0 + alpha;
                let a1 = -2.0 * cos_omega;
                let a2 = 1.0 - alpha;

                self.a0 = b0 / a0;
                self.a1 = b1 / a0;
                self.a2 = b2 / a0;
                self.b1 = a1 / a0;
                self.b2 = a2 / a0;
            }
            FilterType::HighPass => {
                let b0 = (1.0 + cos_omega) / 2.0;
                let b1 = -(1.0 + cos_omega);
                let b2 = (1.0 + cos_omega) / 2.0;
                let a0 = 1.0 + alpha;
                let a1 = -2.0 * cos_omega;
                let a2 = 1.0 - alpha;

                self.a0 = b0 / a0;
                self.a1 = b1 / a0;
                self.a2 = b2 / a0;
                self.b1 = a1 / a0;
                self.b2 = a2 / a0;
            }
            FilterType::BandPass => {
                let b0 = alpha;
                let b1 = 0.0;
                let b2 = -alpha;
                let a0 = 1.0 + alpha;
                let a1 = -2.0 * cos_omega;
                let a2 = 1.0 - alpha;

                self.a0 = b0 / a0;
                self.a1 = b1 / a0;
                self.a2 = b2 / a0;
                self.b1 = a1 / a0;
                self.b2 = a2 / a0;
            }
        }
    }

    pub fn process(&mut self, input: f32) -> f32 {
        let output = self.a0 * input + self.a1 * self.x1 + self.a2 * self.x2
            - self.b1 * self.y1 - self.b2 * self.y2;

        self.x2 = self.x1;
        self.x1 = input;
        self.y2 = self.y1;
        self.y1 = output;

        output
    }
}

/// Dual Oscillator with Detune
#[derive(Debug, Clone)]
struct DualOscillator {
    osc1_type: OscillatorType,
    osc2_type: OscillatorType,
    osc1_level: f32,
    osc2_level: f32,
    osc1_detune: f32,  // cents
    osc2_detune: f32,  // cents
    phase1: f32,
    phase2: f32,
    frequency: f32,
    sample_rate: f32,
}

impl DualOscillator {
    fn new(sample_rate: f32) -> Self {
        Self {
            osc1_type: OscillatorType::Saw,
            osc2_type: OscillatorType::Square,
            osc1_level: 0.8,
            osc2_level: 0.4,
            osc1_detune: 0.0,
            osc2_detune: 7.0,
            phase1: 0.0,
            phase2: 0.0,
            frequency: 440.0,
            sample_rate,
        }
    }

    fn set_frequency(&mut self, freq: f32) {
        self.frequency = freq;
    }

    fn reset_phase(&mut self) {
        self.phase1 = 0.0;
        self.phase2 = 0.0;
    }

    fn process(&mut self) -> f32 {
        // Osc 1 with detune
        let detune1_ratio = 2.0_f32.powf(self.osc1_detune / 1200.0);
        let freq1 = self.frequency * detune1_ratio;
        let sample1 = self.generate_waveform(self.osc1_type, self.phase1);
        self.phase1 += freq1 / self.sample_rate;
        if self.phase1 >= 1.0 {
            self.phase1 -= 1.0;
        }

        // Osc 2 with detune
        let detune2_ratio = 2.0_f32.powf(self.osc2_detune / 1200.0);
        let freq2 = self.frequency * detune2_ratio;
        let sample2 = self.generate_waveform(self.osc2_type, self.phase2);
        self.phase2 += freq2 / self.sample_rate;
        if self.phase2 >= 1.0 {
            self.phase2 -= 1.0;
        }

        // Mix
        sample1 * self.osc1_level + sample2 * self.osc2_level
    }

    fn generate_waveform(&self, osc_type: OscillatorType, phase: f32) -> f32 {
        match osc_type {
            OscillatorType::Sine => (phase * 2.0 * PI).sin(),
            OscillatorType::Saw => 2.0 * phase - 1.0,
            OscillatorType::Square => if phase < 0.5 { 1.0 } else { -1.0 },
            OscillatorType::Triangle => 4.0 * (phase - 0.5).abs() - 1.0,
        }
    }
}

/// Single voice for per-track synthesizer
struct TrackVoice {
    oscillator: DualOscillator,
    envelope: Envelope,
    filter: BiquadFilter,
    note: u8,
    is_active: bool,
}

impl TrackVoice {
    fn new(sample_rate: f32) -> Self {
        Self {
            oscillator: DualOscillator::new(sample_rate),
            envelope: Envelope::new(EnvelopeParams::default()),
            filter: BiquadFilter::new(sample_rate),
            note: 0,
            is_active: false,
        }
    }

    fn note_on(&mut self, note: u8, _velocity: u8) {
        let freq = midi_note_to_frequency(note);
        self.oscillator.set_frequency(freq);
        self.oscillator.reset_phase();
        self.envelope.note_on();
        self.note = note;
        self.is_active = true;
    }

    fn note_off(&mut self) {
        self.envelope.note_off();
    }

    fn process(&mut self) -> f32 {
        if !self.envelope.is_active() {
            self.is_active = false;
            return 0.0;
        }

        let osc_output = self.oscillator.process();
        let env_level = self.envelope.process();
        let enveloped = osc_output * env_level;
        let filtered = self.filter.process(enveloped);

        filtered
    }
}

/// Per-Track Synthesizer (Polyphonic)
pub struct TrackSynthesizer {
    voices: [TrackVoice; MAX_VOICES],
    // Shared parameters that get applied to all voices
    osc1_type: OscillatorType,
    osc1_level: f32,
    osc1_detune: f32,
    osc2_type: OscillatorType,
    osc2_level: f32,
    osc2_detune: f32,
    filter_type: FilterType,
    filter_cutoff: f32,
    filter_resonance: f32,
    envelope_params: EnvelopeParams,
    sample_rate: f32,
}

impl TrackSynthesizer {
    pub fn new(sample_rate: f32) -> Self {
        // Initialize voice array with default voices
        let voices = std::array::from_fn(|_| TrackVoice::new(sample_rate));

        Self {
            voices,
            osc1_type: OscillatorType::Saw,
            osc1_level: 0.8,
            osc1_detune: 0.0,
            osc2_type: OscillatorType::Square,
            osc2_level: 0.4,
            osc2_detune: 7.0,
            filter_type: FilterType::LowPass,
            filter_cutoff: 0.8,
            filter_resonance: 0.2,
            envelope_params: EnvelopeParams::default(),
            sample_rate,
        }
    }

    pub fn set_parameter(&mut self, key: &str, value: &str) {
        match key {
            "osc1_type" => {
                self.osc1_type = OscillatorType::from_str(value);
                for voice in &mut self.voices {
                    voice.oscillator.osc1_type = self.osc1_type;
                }
            }
            "osc1_level" => {
                if let Ok(val) = value.parse::<f32>() {
                    self.osc1_level = val.clamp(0.0, 1.0);
                    for voice in &mut self.voices {
                        voice.oscillator.osc1_level = self.osc1_level;
                    }
                }
            }
            "osc1_detune" => {
                if let Ok(val) = value.parse::<f32>() {
                    self.osc1_detune = val.clamp(-50.0, 50.0);
                    for voice in &mut self.voices {
                        voice.oscillator.osc1_detune = self.osc1_detune;
                    }
                }
            }
            "osc2_type" => {
                self.osc2_type = OscillatorType::from_str(value);
                for voice in &mut self.voices {
                    voice.oscillator.osc2_type = self.osc2_type;
                }
            }
            "osc2_level" => {
                if let Ok(val) = value.parse::<f32>() {
                    self.osc2_level = val.clamp(0.0, 1.0);
                    for voice in &mut self.voices {
                        voice.oscillator.osc2_level = self.osc2_level;
                    }
                }
            }
            "osc2_detune" => {
                if let Ok(val) = value.parse::<f32>() {
                    self.osc2_detune = val.clamp(-50.0, 50.0);
                    for voice in &mut self.voices {
                        voice.oscillator.osc2_detune = self.osc2_detune;
                    }
                }
            }
            "filter_type" => {
                self.filter_type = FilterType::from_str(value);
                for voice in &mut self.voices {
                    voice.filter.set_filter_type(self.filter_type);
                }
            }
            "filter_cutoff" => {
                if let Ok(val) = value.parse::<f32>() {
                    self.filter_cutoff = val;
                    for voice in &mut self.voices {
                        voice.filter.set_cutoff(self.filter_cutoff);
                    }
                }
            }
            "filter_resonance" => {
                if let Ok(val) = value.parse::<f32>() {
                    self.filter_resonance = val;
                    for voice in &mut self.voices {
                        voice.filter.set_resonance(self.filter_resonance);
                    }
                }
            }
            "env_attack" => {
                if let Ok(val) = value.parse::<f32>() {
                    self.envelope_params.attack = val.max(0.001);
                    for voice in &mut self.voices {
                        voice.envelope.params.attack = self.envelope_params.attack;
                    }
                }
            }
            "env_decay" => {
                if let Ok(val) = value.parse::<f32>() {
                    self.envelope_params.decay = val.max(0.001);
                    for voice in &mut self.voices {
                        voice.envelope.params.decay = self.envelope_params.decay;
                    }
                }
            }
            "env_sustain" => {
                if let Ok(val) = value.parse::<f32>() {
                    self.envelope_params.sustain = val.clamp(0.0, 1.0);
                    for voice in &mut self.voices {
                        voice.envelope.params.sustain = self.envelope_params.sustain;
                    }
                }
            }
            "env_release" => {
                if let Ok(val) = value.parse::<f32>() {
                    self.envelope_params.release = val.max(0.001);
                    for voice in &mut self.voices {
                        voice.envelope.params.release = self.envelope_params.release;
                    }
                }
            }
            _ => println!("⚠️ Unknown synth parameter: {}", key),
        }
    }

    /// Find a free voice or steal the oldest one
    fn find_free_voice(&mut self) -> &mut TrackVoice {
        // First, try to find an inactive voice
        let inactive_index = self.voices.iter().position(|v| !v.is_active);

        if let Some(index) = inactive_index {
            return &mut self.voices[index];
        }

        // All voices active - steal the first one (simple voice stealing)
        // TODO: Could implement more sophisticated stealing (oldest, quietest, etc.)
        &mut self.voices[0]
    }

    pub fn note_on(&mut self, note: u8, velocity: u8) {
        let voice = self.find_free_voice();
        voice.note_on(note, velocity);
        println!("🎹 Track synth note ON: {} (polyphonic)", note);
    }

    pub fn note_off(&mut self, note: u8, _velocity: u8) {
        // Find all voices playing this note and release them
        for voice in &mut self.voices {
            if voice.is_active && voice.note == note {
                voice.note_off();
                println!("🎹 Track synth note OFF: {}", note);
            }
        }
    }

    pub fn process_sample(&mut self) -> f32 {
        let mut output = 0.0;

        // Mix all active voices
        for voice in &mut self.voices {
            if voice.is_active {
                output += voice.process();
            }
        }

        output * 0.5  // Output gain (adjusted for polyphony)
    }

    pub fn is_active(&self) -> bool {
        self.voices.iter().any(|v| v.is_active)
    }

    pub fn active_voice_count(&self) -> usize {
        self.voices.iter().filter(|v| v.is_active).count()
    }
}

/// Manager for per-track synthesizers
pub struct TrackSynthManager {
    synths: HashMap<u64, TrackSynthesizer>,
    sample_rate: f32,
}

impl TrackSynthManager {
    pub fn new(sample_rate: f32) -> Self {
        Self {
            synths: HashMap::new(),
            sample_rate,
        }
    }

    pub fn create_synth(&mut self, track_id: u64) -> u64 {
        let synth = TrackSynthesizer::new(self.sample_rate);
        self.synths.insert(track_id, synth);
        println!("✅ Created track synthesizer for track {}", track_id);
        track_id
    }

    pub fn set_parameter(&mut self, track_id: u64, key: &str, value: &str) {
        if let Some(synth) = self.synths.get_mut(&track_id) {
            synth.set_parameter(key, value);
        }
    }

    pub fn note_on(&mut self, track_id: u64, note: u8, velocity: u8) {
        if let Some(synth) = self.synths.get_mut(&track_id) {
            synth.note_on(note, velocity);
        }
    }

    pub fn note_off(&mut self, track_id: u64, note: u8, velocity: u8) {
        if let Some(synth) = self.synths.get_mut(&track_id) {
            synth.note_off(note, velocity);
        }
    }

    pub fn process_sample(&mut self, track_id: u64) -> f32 {
        if let Some(synth) = self.synths.get_mut(&track_id) {
            synth.process_sample()
        } else {
            0.0
        }
    }

    pub fn has_synth(&self, track_id: u64) -> bool {
        self.synths.contains_key(&track_id)
    }

    /// Copy synthesizer from one track to another
    /// Creates a new synth for dest_track_id with same parameters as source_track_id
    pub fn copy_synth(&mut self, source_track_id: u64, dest_track_id: u64) -> bool {
        if let Some(source_synth) = self.synths.get(&source_track_id) {
            // Create new synth with same parameters
            let mut new_synth = TrackSynthesizer::new(self.sample_rate);

            // Copy all parameters
            new_synth.osc1_type = source_synth.osc1_type;
            new_synth.osc1_level = source_synth.osc1_level;
            new_synth.osc1_detune = source_synth.osc1_detune;
            new_synth.osc2_type = source_synth.osc2_type;
            new_synth.osc2_level = source_synth.osc2_level;
            new_synth.osc2_detune = source_synth.osc2_detune;
            new_synth.filter_type = source_synth.filter_type;
            new_synth.filter_cutoff = source_synth.filter_cutoff;
            new_synth.filter_resonance = source_synth.filter_resonance;
            new_synth.envelope_params = source_synth.envelope_params.clone();

            // Update all voices with the new parameters
            for voice in &mut new_synth.voices {
                voice.oscillator.osc1_type = new_synth.osc1_type;
                voice.oscillator.osc1_level = new_synth.osc1_level;
                voice.oscillator.osc1_detune = new_synth.osc1_detune;
                voice.oscillator.osc2_type = new_synth.osc2_type;
                voice.oscillator.osc2_level = new_synth.osc2_level;
                voice.oscillator.osc2_detune = new_synth.osc2_detune;
                voice.filter.filter_type = new_synth.filter_type;
                voice.filter.cutoff = new_synth.filter_cutoff;
                voice.filter.resonance = new_synth.filter_resonance;
                voice.envelope.params = new_synth.envelope_params.clone();
            }

            self.synths.insert(dest_track_id, new_synth);
            eprintln!("🎹 [TrackSynthManager] Copied synth from track {} to track {}", source_track_id, dest_track_id);
            true
        } else {
            false
        }
    }
}
