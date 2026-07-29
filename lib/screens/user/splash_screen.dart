import 'dart:async';
import 'package:flutter/material.dart';
import 'package:aplikasi_sekolah/core/constants/app_colors.dart'; // IMPORT TEMA GLOBAL

// SOLUSI: Diubah menjadi StatelessWidget agar struktur fungsi build di bawahnya valid
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
    // Menunggu 3 detik di halaman Splash, lalu pindah otomatis ke Onboarding
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/onboarding');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary, // Menggunakan tema warna global sekolah
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Kontainer Logo melingkar di tengah
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
                  'assets/images/logo_sekolah.png', // Menyelaraskan path folder aset terstruktur
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    // Jika file gambar belum ada di folder assets, tampilkan ikon default ini agar tidak error
                    return const Icon(
                      Icons.school,
                      size: 70,
                      color: AppColors.primary, // Menggunakan tema warna global sekolah
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Teks Nama Sekolah
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
                color: Colors.white70, // SOLUSI: Dikembalikan ke format stabil yang cocok dengan SDK laptop Anda
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
