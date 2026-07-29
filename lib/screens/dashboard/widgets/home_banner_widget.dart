import 'package:flutter/material.dart';
import 'package:aplikasi_sekolah/core/constants/app_colors.dart';

class HomeBannerWidget extends StatelessWidget {
  final String namaUser;
  final String role;
  final Map<String, dynamic> extraData;

  const HomeBannerWidget({
    super.key,
    required this.namaUser,
    required this.role,
    required this.extraData,
  });

  @override
  Widget build(BuildContext context) {
    String keteranganKelas = extraData['kelas_diajar'] ?? 'Belum Diatur';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Selamat Datang,',
            style: TextStyle(fontSize: 14, color: Colors.white70),
          ),
          Text(
            namaUser,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            role == 'admin'
                ? 'Sistem Kendali Administrator Sekolah'
                : role == 'guru'
                ? 'Portal Pendidik - Wali $keteranganKelas'
                : 'Portal Pantauan Wali Murid • Siswa Aktif: $keteranganKelas',
            style: const TextStyle(fontSize: 13, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
