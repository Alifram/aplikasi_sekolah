import 'dart:async';
import 'package:flutter/material.dart';
import 'package:aplikasi_sekolah/core/constants/app_colors.dart';
import 'package:aplikasi_sekolah/core/services/auth_service.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SplashScreenStateful();
  }
}

class _SplashScreenStateful extends StatefulWidget {
  const _SplashScreenStateful();

  @override
  State<_SplashScreenStateful> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreenStateful> {
  @override
  void initState() {
    super.initState();
    _periksaSesiLoginAplikasi();
  }

  Future<void> _periksaSesiLoginAplikasi() async {
    await Future.delayed(const Duration(seconds: 3));

    Map<String, dynamic>? profile;
    try {
      profile = await AuthService.currentUserProfile();
    } catch (error) {
      debugPrint('Tidak dapat memuat profil sesi Supabase: $error');
    }
    if (!mounted) return;

    if (profile != null) {
      Navigator.pushReplacementNamed(
        context,
        '/dashboard',
        arguments: profile,
      );
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 140,
              height: 140,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(70),
                child: Image.asset(
                  'assets/logo_mim.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.school,
                      size: 70,
                      color: AppColors.primary,
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'MIM PASIR LOR',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Membangun Generasi Islami & Unggul',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white70,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
