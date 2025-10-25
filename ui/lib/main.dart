import 'package:flutter/material.dart';
import 'screens/daw_screen.dart';

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
      home: const DAWScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
