#!/usr/bin/env python3
"""
Generate a test WAV file for Solar Audio M1 integration testing.
Creates a simple sine wave tone at 48kHz stereo.
"""

import wave
import struct
import math
import os
from pathlib import Path

def generate_test_wav(
    output_path: str,
    duration_seconds: float = 3.0,
    frequency_hz: float = 440.0,
    sample_rate: int = 48000,
    amplitude: float = 0.3
):
    """
    Generate a sine wave test file.
    
    Args:
        output_path: Path where the WAV file will be saved
        duration_seconds: Length of the audio file in seconds
        frequency_hz: Frequency of the sine wave (A4 = 440Hz)
        sample_rate: Sample rate in Hz (48000 is standard for DAWs)
        amplitude: Amplitude of the wave (0.0 to 1.0, recommend 0.3 to avoid clipping)
    """
    print(f"🎵 Generating test WAV file...")
    print(f"   Duration: {duration_seconds}s")
    print(f"   Frequency: {frequency_hz}Hz")
    print(f"   Sample Rate: {sample_rate}Hz")
    print(f"   Amplitude: {amplitude}")
    
    # Ensure output directory exists
    output_dir = os.path.dirname(output_path)
    if output_dir:
        Path(output_dir).mkdir(parents=True, exist_ok=True)
    
    with wave.open(output_path, 'w') as wav_file:
        # Set WAV parameters
        wav_file.setnchannels(2)         # Stereo
        wav_file.setsampwidth(2)         # 16-bit
        wav_file.setframerate(sample_rate)
        
        total_samples = int(sample_rate * duration_seconds)
        
        # Generate sine wave samples
        for i in range(total_samples):
            # Calculate sine wave value
            t = i / sample_rate
            value = math.sin(2 * math.pi * frequency_hz * t)
            
            # Convert to 16-bit integer
            sample = int(32767 * amplitude * value)
            
            # Pack as signed 16-bit integer
            packed_value = struct.pack('h', sample)
            
            # Write to both channels (stereo)
            wav_file.writeframes(packed_value + packed_value)
    
    # Get file size
    file_size = os.path.getsize(output_path)
    file_size_kb = file_size / 1024
    
    print(f"✅ Test file created successfully!")
    print(f"   Path: {output_path}")
    print(f"   Size: {file_size_kb:.1f} KB")
    print(f"   Ready for M1 integration test!")

def main():
    # Default output path
    home = os.path.expanduser("~")
    output_path = os.path.join(home, "Downloads", "test.wav")
    
    print("=" * 60)
    print("Solar Audio - Test WAV Generator")
    print("=" * 60)
    print()
    
    try:
        generate_test_wav(output_path)
        print()
        print("🎯 Next steps:")
        print("   1. Run the Flutter app: cd ui && flutter run -d macos")
        print("   2. Click '1. Initialize Audio Graph'")
        print("   3. Click '2. Load Test File'")
        print("   4. Click the Play button to hear the test tone!")
        print()
        
    except Exception as e:
        print(f"❌ Error generating test file: {e}")
        return 1
    
    return 0

if __name__ == "__main__":
    exit(main())

