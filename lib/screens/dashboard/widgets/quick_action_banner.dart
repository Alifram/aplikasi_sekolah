import 'package:flutter/material.dart';
import 'package:aplikasi_sekolah/core/constants/app_colors.dart';
import '../../informasi/pantau_data_screen.dart';

class QuickActionBanner extends StatelessWidget {
  final String role;
  final Function(int) onNavigateToTab;

  const QuickActionBanner({
    super.key,
    required this.role,
    required this.onNavigateToTab,
  });

  @override
  Widget build(BuildContext context) {
    String txtJudul = role == 'admin'
        ? 'Pendaftaran & Pantau Anggota'
        : role == 'guru'
        ? 'Akses Cepat Penginputan Nilai'
        : 'History Nilai Rapor Digital';
        
    String txtSub = role == 'admin'
        ? 'Lihat daftar nama siswa dan mutasi jenjang kelas'
        : role == 'guru'
        ? 'Input skor tugas, UTS & UAS murid'
        : 'Cek rekam jejak nilai kelas 1-6 anak Anda';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, Colors.green.shade800],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  txtJudul,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  txtSub,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
            onPressed: () {
              if (role == 'admin') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PantauDataScreen(
                      statusTemaGelap: false,
                    ),
                  ),
                );
              } else {
                onNavigateToTab(2);
              }
            },
            child: const Text(
              'Buka Form',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
