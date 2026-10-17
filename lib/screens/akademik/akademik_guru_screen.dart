import 'package:flutter/material.dart';
import 'package:aplikasi_sekolah/core/constants/app_colors.dart';
import 'input_nilai_screen.dart';

class AkademikGuruScreen extends StatelessWidget {
  final String namaGuru;
  final String kelasGuru;
  final String idGuru;
  final ValueChanged<int>? onNilaiTersimpan;
  final VoidCallback onBukaStatistik;

  const AkademikGuruScreen({
    super.key,
    required this.namaGuru,
    required this.kelasGuru,
    required this.idGuru,
    required this.onBukaStatistik,
    this.onNilaiTersimpan,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = Theme.of(context).colorScheme.surface;
    final secondaryText = Theme.of(context).colorScheme.onSurfaceVariant;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F5132), Color(0xFF218354)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.school_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Text(
                        kelasGuru,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Text(
                  'Halo, $namaGuru',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Ruang Akademik',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 25,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  'Kelola nilai dan pantau perkembangan belajar siswa dalam satu tempat.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.84),
                    height: 1.4,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Aktivitas akademik',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Pilih aktivitas yang ingin Anda buka.',
            style: TextStyle(color: secondaryText, fontSize: 13),
          ),
          const SizedBox(height: 16),
          _AcademicActionCard(
            icon: Icons.edit_note_rounded,
            title: 'Input Nilai Rapor',
            description: 'Masukkan nilai tugas, UTS, dan UAS siswa.',
            accent: const Color(0xFF218354),
            isDark: isDark,
            surfaceColor: surfaceColor,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => InputNilaiScreen(
                    kelasGuru: kelasGuru,
                    idGuru: idGuru,
                    onNilaiTersimpan: onNilaiTersimpan,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _AcademicActionCard(
            icon: Icons.insights_rounded,
            title: 'Statistik Akademik',
            description: 'Lihat ringkasan dan perkembangan nilai siswa.',
            accent: const Color(0xFF5676D8),
            isDark: isDark,
            surfaceColor: surfaceColor,
            onTap: onBukaStatistik,
          ),
        ],
      ),
    );
  }
}

class _AcademicActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color accent;
  final bool isDark;
  final Color surfaceColor;
  final VoidCallback onTap;

  const _AcademicActionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.accent,
    required this.isDark,
    required this.surfaceColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: surfaceColor,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.55),
            ),
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.035),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: accent, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
