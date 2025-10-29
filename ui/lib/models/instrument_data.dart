/// Data model for synthesizer instrument parameters
class InstrumentData {
  final int trackId;
  final String type; // 'synthesizer'
  final Map<String, dynamic> parameters;

  InstrumentData({
    required this.trackId,
    required this.type,
    required this.parameters,
  });

  /// Create default synthesizer with basic settings
  factory InstrumentData.defaultSynthesizer(int trackId) {
    return InstrumentData(
      trackId: trackId,
      type: 'synthesizer',
      parameters: {
        // Oscillator 1
        'osc1_type': 'saw', // saw, sine, square, triangle
        'osc1_level': 0.8,
        'osc1_detune': 0.0, // cents: -50 to +50

        // Oscillator 2
        'osc2_type': 'square',
        'osc2_level': 0.4,
        'osc2_detune': 7.0, // cents: -50 to +50

        // Filter
        'filter_type': 'lowpass', // lowpass, highpass, bandpass
        'filter_cutoff': 0.8, // 0.0 to 1.0 (maps to frequency range)
        'filter_resonance': 0.2, // 0.0 to 1.0

        // ADSR Envelope
        'env_attack': 0.01, // seconds: 0.001 to 2.0
        'env_decay': 0.1, // seconds: 0.001 to 2.0
        'env_sustain': 0.7, // level: 0.0 to 1.0
        'env_release': 0.3, // seconds: 0.001 to 5.0
      },
    );
  }

  /// Get a parameter value with type casting
  T getParameter<T>(String key, T defaultValue) {
    final value = parameters[key];
    if (value is T) {
      return value;
    }
    return defaultValue;
  }

  /// Update a parameter and return new instance (immutable pattern)
  InstrumentData updateParameter(String key, dynamic value) {
    final newParams = Map<String, dynamic>.from(parameters);
    newParams[key] = value;
    return InstrumentData(
      trackId: trackId,
      type: type,
      parameters: newParams,
    );
  }

  /// Convert to map for serialization
  Map<String, dynamic> toJson() {
    return {
      'trackId': trackId,
      'type': type,
      'parameters': parameters,
    };
  }

  /// Create from map for deserialization
  factory InstrumentData.fromJson(Map<String, dynamic> json) {
    return InstrumentData(
      trackId: json['trackId'] as int,
      type: json['type'] as String,
      parameters: Map<String, dynamic>.from(json['parameters'] as Map),
    );
  }

  /// Copy with new values
  InstrumentData copyWith({
    int? trackId,
    String? type,
    Map<String, dynamic>? parameters,
  }) {
    return InstrumentData(
      trackId: trackId ?? this.trackId,
      type: type ?? this.type,
      parameters: parameters ?? this.parameters,
    );
  }
}
