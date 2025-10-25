import 'package:flutter/material.dart';
import 'audio_engine.dart';

void main() {
  runApp(const SolarAudioApp());
}

class SolarAudioApp extends StatelessWidget {
  const SolarAudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Solar Audio',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2B2B2B),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _statusMessage = 'Ready';
  AudioEngine? _audioEngine;
  
  @override
  void initState() {
    super.initState();
    _initAudioEngine();
  }
  
  void _initAudioEngine() {
    try {
      _audioEngine = AudioEngine();
      final initMessage = _audioEngine!.initAudioEngine();
      setState(() {
        _statusMessage = initMessage;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Failed to initialize audio: $e';
      });
    }
  }

  void _playBeep() {
    if (_audioEngine == null) {
      setState(() {
        _statusMessage = 'Audio engine not initialized';
      });
      return;
    }
    
    try {
      final result = _audioEngine!.playSineWave(440.0, 1000);
      setState(() {
        _statusMessage = result;
      });
      
      // Reset message after playback
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          setState(() {
            _statusMessage = 'Ready';
          });
        }
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        title: Image.asset(
          'assets/images/solar_logo.png',
          height: 40,
          fit: BoxFit.contain,
        ),
        backgroundColor: const Color(0xFFF5F5F5),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'M0: Project Setup & Scaffolding',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w300,
                color: Color(0xFFA0A0A0),
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: _playBeep,
              icon: const Icon(Icons.play_arrow, size: 32),
              label: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Text(
                  'Play Beep',
                  style: TextStyle(fontSize: 20),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFA0A0A0),
                foregroundColor: const Color(0xFF2B2B2B),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _statusMessage,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF808080),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
