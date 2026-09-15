import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // <-- 1. Tambah import ini
import 'package:aplikasi_sekolah/core/constants/app_colors.dart';
import '../dashboard/dashboard_screen.dart'; // <-- 2. Tambah import dashboard untuk navigasi langsung

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
    _periksaSesiLoginAplikasi(); // <-- 3. Picu fungsi pengecekan sesi otomatis
  }

  // LOGIKA UTAMA: Membaca memori lokal HP saat aplikasi pertama kali dibuka
  Future<void> _periksaSesiLoginAplikasi() async {
    final prefs = await SharedPreferences.getInstance();
    final bool isLogin = prefs.getBool('is_login') ?? false;

    // Menunggu jeda estetika splash screen selama 3 detik
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return; // Pengaman context asinkronus

    if (isLogin) {
      // AMAN: Jika user sudah login sebelumnya, tarik data profil lama dan lompat langsung ke Dashboard
      final String userId = prefs.getString('user_id') ?? '';
      final String nomorInduk = prefs.getString('nomor_induk') ?? '';
      final String namaLengkap = prefs.getString('nama_lengkap') ?? 'Pengguna';
      final String role = prefs.getString('role') ?? 'siswa';
      final String kelasDiajar = prefs.getString('kelas_diajar') ?? 'Belum Diatur';

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => DashboardScreen(
            role: role,
            namaUser: namaLengkap,
            extraData: {
              "id": userId,
              "nomor_induk": nomorInduk,
              "nama_lengkap": namaLengkap,
              "role": role,
              "kelas_diajar": kelasDiajar,
            },
          ),
        ),
      );
    } else {
      // Jika data sesi kosong, arahkan ke Onboarding awal seperti biasa
      Navigator.pushReplacementNamed(context, '/onboarding');
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
                  'assets/images/logo_sekolah.png',
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
