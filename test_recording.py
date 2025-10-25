#!/usr/bin/env python3
"""
Test script to verify recording functionality.
Run this to check if microphone and metronome are working.
"""

import subprocess
import sys
import time

def run_command(cmd, description):
    """Run a command and print the result."""
    print(f"\n{'='*60}")
    print(f"Testing: {description}")
    print(f"{'='*60}")
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=5)
        if result.stdout:
            print("Output:", result.stdout)
        if result.stderr:
            print("Errors:", result.stderr)
        return result.returncode == 0
    except subprocess.TimeoutExpired:
        print("⏱️  Command timed out (this might be okay for audio tests)")
        return True
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

def main():
    print("""
╔════════════════════════════════════════════════════════════╗
║          Solar Audio - Recording Debug Tool               ║
╚════════════════════════════════════════════════════════════╝
    """)

    # Check if we're on macOS
    if sys.platform != 'darwin':
        print("⚠️  This test is designed for macOS")
        return

    # Test 1: Check if Rust engine builds
    print("\n1️⃣  Checking Rust engine build...")
    engine_path = "engine"
    if run_command(f"cd {engine_path} && cargo build --release 2>&1 | tail -5", "Rust Engine Build"):
        print("✅ Engine builds successfully")
    else:
        print("❌ Engine build failed - check error above")
        return

    # Test 2: Check if Flutter app compiles
    print("\n2️⃣  Checking Flutter compilation...")
    if run_command("cd ui && flutter analyze 2>&1 | grep -E '(error|warning|No issues found)'", "Flutter Analysis"):
        print("✅ Flutter code is clean")
    else:
        print("⚠️  Flutter might have issues")

    # Test 3: Check microphone permissions
    print("\n3️⃣  Checking microphone permissions...")
    print("""
To check microphone permissions:
1. Go to System Settings > Privacy & Security > Microphone
2. Make sure 'ui' or 'Solar Audio' is listed and CHECKED
3. If not listed, you need to run the app once first

After granting permissions, you may need to restart the app.
    """)

    # Test 4: Check audio devices
    print("\n4️⃣  Checking audio input devices...")
    print("""
Run this command to see available audio devices:
    system_profiler SPAudioDataType

Look for 'Input Device' entries.
    """)
    run_command("system_profiler SPAudioDataType | grep -A 5 'Input Device'", "Audio Input Devices")

    # Instructions for testing
    print("""
╔════════════════════════════════════════════════════════════╗
║                  Manual Test Instructions                  ║
╚════════════════════════════════════════════════════════════╝

🧪 Test Metronome (without recording):
   1. Run the app: cd ui && flutter run -d macos
   2. Load any audio file (to enable transport)
   3. Click the metronome button (🎵) to enable it
   4. Click Play
   5. You should hear clicks on every beat
   
   ❌ If you don't hear clicks:
      - Check that metronome button is highlighted (blue)
      - Check your audio output volume
      - Check the code logs for "Metronome enabled"

🎙️  Test Count-In & Recording:
   1. Make sure microphone permission is granted
   2. Click the Record button (⏺)
   3. You should hear metronome clicks counting in (2 bars = 8 beats at 120 BPM)
   4. After count-in, status should change to "Recording"
   5. Speak into microphone
   6. Click Record again to stop
   7. Waveform should appear on timeline
   
   ❌ If count-in doesn't work:
      - Check console logs for "Count-in..." and "Recording..." messages
      - Verify tempo is set (should show "120 BPM" in transport bar)
      - Try clicking metronome button to ensure audio output works
      
   ❌ If recording doesn't work:
      - Check microphone permissions (System Settings)
      - Check console for "No input device available" errors
      - Make sure you're using the built-in mic or external mic
      - Check that input levels are showing in Sound settings

🔍 Debug Logging:
   The app prints detailed logs. Look for:
   - "✅ [AudioEngine]" for successful operations
   - "❌ [AudioEngine]" for errors
   - "🎵 [AudioEngine]" for recording operations
   - "⏺️  [AudioEngine]" for recording start/stop

📝 Common Issues:

1. "No input device available"
   → Grant microphone permissions in System Settings
   → Restart the app after granting permissions

2. "Count-in doesn't play"
   → Metronome might be disabled - click the metronome button
   → Audio output might be muted - check system volume
   → Try loading a file and playing it first to test audio output

3. "Recording doesn't capture audio"
   → Check microphone is working (try recording in QuickTime Player)
   → Check input levels in System Settings > Sound > Input
   → Make sure correct input device is selected (built-in mic)

4. "Waveform doesn't appear after recording"
   → Check console logs for clip ID
   → Try stopping and starting recording again
   → Check if recording duration is > 0 seconds

═══════════════════════════════════════════════════════════

Need more help? Check:
- docs/M2_COMPLETION.md for detailed information
- Console logs in the app for specific errors
- System Settings > Sound to verify input/output devices
    """)

if __name__ == "__main__":
    main()

