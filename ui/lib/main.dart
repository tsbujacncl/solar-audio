import 'package:flutter/material.dart';
import 'screens/daw_screen.dart';
import 'utils/app_colors.dart';

void main() {
  runApp(const BoojyAudioApp());
}

class BoojyAudioApp extends StatelessWidget {
  const BoojyAudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Boojy Audio',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.background,
          brightness: Brightness.dark,
        ).copyWith(
          primary: AppColors.primary,
          surface: AppColors.background,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        popupMenuTheme: const PopupMenuThemeData(
          color: AppColors.divider,
        ),
      ),
      home: const DAWScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
