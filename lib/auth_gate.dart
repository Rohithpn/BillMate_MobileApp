// lib/auth_gate.dart
import 'package:bm/core/main_layout.dart'; // 👈 Import the new MainLayout
import 'package:bm/features/auth/screens/login_page.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final session = snapshot.data?.session;

        if (session != null) {
          // Show the new MainLayout with the BottomNavigationBar
          return const MainLayout(); // 👈 Change this line
        } else {
          return const LoginPage();
        }
      },
    );
  }
}