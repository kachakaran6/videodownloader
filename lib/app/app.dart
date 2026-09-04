import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../features/inspect/presentation/home_screen.dart';

class MediaSaverApp extends StatelessWidget {
  const MediaSaverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Media Saver',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      home: const HomeScreen(),
    );
  }
}
