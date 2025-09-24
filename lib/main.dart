// lib/main.dart
import 'package:bm/auth_gate.dart';
import 'package:bm/core/app_theme.dart';
import 'package:bm/core/theme_notifier.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://lnqggkuxmyitsgrdgxsq.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxucWdna3V4bXlpdHNncmRneHNxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTc0ODIzNTgsImV4cCI6MjA3MzA1ODM1OH0.vMx11DveAadFZpBzqZ2u9jAB4H-HqwfgYy33eAFEIHk',
  );

  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeNotifier(),
      child: const BillMateApp(),
    ),
  );
}

class BillMateApp extends StatelessWidget {
  const BillMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Listen to the ThemeNotifier
    final themeNotifier = Provider.of<ThemeNotifier>(context);

    return MaterialApp(
      title: 'BillMate',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      // Use the themeMode from the notifier
      themeMode: themeNotifier.themeMode,
      home: const AuthGate(),
    );
  }
}