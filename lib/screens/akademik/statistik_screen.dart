import 'package:flutter/material.dart';
import 'package:aplikasi_sekolah/core/constants/app_colors.dart';
import 'package:aplikasi_sekolah/core/services/api_service.dart';
import '../informasi/pantau_data_screen.dart';

class StatistikScreen extends StatefulWidget {
  final String loginRole;
  final String kelasDiajarGuru;
  final bool statusTemaGelap;

  const StatistikScreen({
    super.key,
    required this.loginRole,
    required this.kelasDiajarGuru,
    required this.statusTemaGelap,
  });

  @override
  State<StatistikScreen> createState() => _StatistikScreenState();
}

class _StatistikScreenState extends State<StatistikScreen> {
  String _angkatanTerpilih = '2026';
  bool _isLoading = false;

  Map<String, dynamic> _dataStatistik = {
    "Kelas 1": {"Semester 1": 0.0, "Semester 2": 0.0},
    "Kelas 2": {"Semester 1": 0.0, "Semester 2": 0.0},
    "Kelas 3": {"Semester 1": 0.0, "Semester 2": 0.0},
    "Kelas 4": {"Semester 1": 0.0, "Semester 2": 0.0},
    "Kelas 5": {"Semester 1": 0.0, "Semester 2": 0.0},
    "Kelas 6": {"Semester 1": 0.0, "Semester 2": 0.0},
  };

  final List<String> _daftarKelas = [
    'Kelas 1',
    'Kelas 2',
    'Kelas 3',
    'Kelas 4',
    'Kelas 5',
    'Kelas 6',
  ];

  @override
  void initState() {
    super.initState();
    print('🔥 STATISTIK SCREEN: initState()');
    _panggilDataStatistik();
  }

  Future<void> _panggilDataStatistik() async {
    print('🔥 STATISTIK SCREEN: _panggilDataStatistik() DIPANGGIL');

    setState(() {
      _isLoading = true;
    });

    try {
      final res = await ApiService.ambilStatistikAkademik(
        _angkatanTerpilih,
      );

      print('==============================');
      print('🔥 STATISTIK SCREEN: RESPONSE DITERIMA');
      print(res);
      print('HASIL STATISTIK = $res');
      print('ANGKATAN: $_angkatanTerpilih');
      print('RESPONSE API: $res');
      print('STATUS: ${res['status']}');
      print('DATA: ${res['data']}');
      print('KELAS 1: ${res['data']?['Kelas 1']}');
      print('SEMESTER 1: ${res['data']?['Kelas 1']?['Semester 1']}');
      print('SEMESTER 2: ${res['data']?['Kelas 1']?['Semester 2']}');
      print('==============================');

      if (!mounted) return;

      debugPrint('=== RESPONSE STATISTIK ===');
      debugPrint(res.toString());

      if (!mounted) return;

      if (res['status'] == 'success') {
        final dataApi = res['data'];

        if (dataApi is Map) {
          final Map<String, dynamic> dataBaru = {};

          for (final namaKelas in _daftarKelas) {
            final dataKelas = dataApi[namaKelas];

            if (dataKelas is Map) {
              dataBaru[namaKelas] = {
                'Semester 1': _ubahKeDouble(
                  dataKelas['Semester 1'],
                ),
                'Semester 2': _ubahKeDouble(
                  dataKelas['Semester 2'],
                ),
              };
            } else {
              dataBaru[namaKelas] = {
                'Semester 1': 0.0,
                'Semester 2': 0.0,
              };
            }
          }

          debugPrint('=== DATA STATISTIK FLUTTER ===');
          debugPrint(dataBaru.toString());

          setState(() {
            _dataStatistik = dataBaru;
          });
        }
      } else {
        debugPrint(
          'Gagal mengambil statistik: ${res['message']}',
        );
      }
    } catch (e) {
      debugPrint(
        "Gagal memuat statistik: $e",
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  double _ubahKeDouble(dynamic nilai) {
    if (nilai == null) {
      return 0.0;
    }

    if (nilai is num) {
      return nilai.toDouble();
    }

    return double.tryParse(
          nilai.toString(),
        ) ??
        0.0;
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = widget.statusTemaGelap;

    final Color warnaLatar = isDark
        ? const Color(0xFF0B141A)
        : Colors.grey.shade50;

    final Color warnaKartu = isDark
        ? const Color(0xFF1C2D35)
        : Colors.white;

    final Color warnaTeksUtama = isDark
        ? Colors.white
        : Colors.black87;

    final Color warnaTeksSub = isDark
        ? Colors.white70
        : Colors.black54;

    return Scaffold(
      backgroundColor: warnaLatar,

      appBar: AppBar(
        title: const Text(
          'Statistik Akademik',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
      ),

      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            )
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _panggilDataStatistik,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  30,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ==================================================
                    // HEADER
                    // ==================================================

                    Text(
                      'Track Record Nilai',
                      style: TextStyle(
                        color: warnaTeksUtama,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      'Perkembangan rata-rata nilai setiap kelas berdasarkan angkatan.',
                      style: TextStyle(
                        color: warnaTeksSub,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 18),

                    // ==================================================
                    // PILIH ANGKATAN
                    // ==================================================

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: warnaKartu,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: warnaTeksSub.withOpacity(0.15),
                        ),
                      ),
                      child: Row(
                        children: [

                          Icon(
                            Icons.groups_rounded,
                            size: 20,
                            color: AppColors.primary,
                          ),

                          const SizedBox(width: 10),

                          Expanded(
                            child: Text(
                              'Angkatan',
                              style: TextStyle(
                                color: warnaTeksUtama,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),

                          DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _angkatanTerpilih,
                              dropdownColor: warnaKartu,
                              icon: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: warnaTeksSub,
                              ),
                              style: TextStyle(
                                color: warnaTeksUtama,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              items: [
                                '2024',
                                '2025',
                                '2026',
                                '2027',
                              ].map(
                                (tahun) {
                                  return DropdownMenuItem<String>(
                                    value: tahun,
                                    child: Text(tahun),
                                  );
                                },
                              ).toList(),
                              onChanged: (value) {
                                if (value == null) return;

                                setState(() {
                                  _angkatanTerpilih = value;
                                });

                                _panggilDataStatistik();
                                
                              },
                              
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 22),

                    // ==================================================
                    // LEGENDA
                    // ==================================================

                    Row(
                      children: [

                        Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: Colors.orange.shade400,
                            shape: BoxShape.circle,
                          ),
                        ),

                        const SizedBox(width: 6),

                        Text(
                          'Semester 1',
                          style: TextStyle(
                            color: warnaTeksSub,
                            fontSize: 11,
                          ),
                        ),

                        const SizedBox(width: 16),

                        Container(
                          width: 9,
                          height: 9,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),

                        const SizedBox(width: 6),

                        Text(
                          'Semester 2',
                          style: TextStyle(
                            color: warnaTeksSub,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // ==================================================
                    // GRAFIK KELAS
                    // ==================================================

                    Container(
                      padding: const EdgeInsets.fromLTRB(
                        16,
                        18,
                        16,
                        18,
                      ),
                      decoration: BoxDecoration(
                        color: warnaKartu,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: warnaTeksSub.withOpacity(0.12),
                        ),
                      ),
                      child: Column(
                        children: _daftarKelas.map(
                          (namaKelas) {
                            return _buildGrafikKelas(
                              namaKelas,
                              warnaTeksUtama,
                              warnaTeksSub,
                              warnaKartu,
                            );
                          },
                        ).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // ================================================================
  // GRAFIK SATU KELAS
  // ================================================================

  Widget _buildGrafikKelas(
    String namaKelas,
    Color warnaTeksUtama,
    Color warnaTeksSub,
    Color warnaKartu,
  ) {
    final bool isAdmin = widget.loginRole == 'admin';

    final bool isGuruKelasIni =
        widget.loginRole == 'guru' &&
        widget.kelasDiajarGuru == namaKelas;

    if (!isAdmin && !isGuruKelasIni) {
      return const SizedBox.shrink();
    }

    final Map<String, dynamic> dataKelas =
        Map<String, dynamic>.from(
      _dataStatistik[namaKelas] ?? {},
    );

    final double sem1 =
        double.tryParse(
          dataKelas['Semester 1']?.toString() ?? '0',
        ) ??
        0.0;

    final double sem2 =
        double.tryParse(
          dataKelas['Semester 2']?.toString() ?? '0',
        ) ??
        0.0;

    final bool adaSem1 = sem1 > 0;
    final bool adaSem2 = sem2 > 0;

    final double? nilaiAwal =
        adaSem1 ? sem1 : null;

    final double? nilaiAkhir =
        adaSem2 ? sem2 : null;

    final double selisih =
        nilaiAwal != null && nilaiAkhir != null
            ? nilaiAkhir - nilaiAwal
            : 0;

    return Padding(
      padding: const EdgeInsets.only(
        bottom: 22,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),

        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PantauDataScreen(
                filterKelasOtomatis: namaKelas,
                filterAngkatanOtomatis:
                    _angkatanTerpilih,
                statusTemaGelap:
                    widget.statusTemaGelap,
              ),
            ),
          );
        },

        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 3,
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [

              // ======================================================
              // JUDUL KELAS + TREND
              // ======================================================

              Row(
                children: [

                  Text(
                    namaKelas,
                    style: TextStyle(
                      color: warnaTeksUtama,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),

                  const Spacer(),

                  if (nilaiAwal != null &&
                      nilaiAkhir != null)
                    Row(
                      children: [

                        Icon(
                          selisih >= 0
                              ? Icons.trending_up_rounded
                              : Icons.trending_down_rounded,
                          size: 15,
                          color: selisih >= 0
                              ? Colors.green
                              : Colors.red,
                        ),

                        const SizedBox(width: 3),

                        Text(
                          '${selisih >= 0 ? '+' : ''}${selisih.toStringAsFixed(1)}',
                          style: TextStyle(
                            color: selisih >= 0
                                ? Colors.green
                                : Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(width: 4),

                  Icon(
                    Icons.chevron_right_rounded,
                    color: warnaTeksSub,
                    size: 18,
                  ),
                ],
              ),

              const SizedBox(height: 9),

              // ======================================================
              // SEMESTER 1
              // ======================================================

              _buildBatangHorizontal(
                label: 'S1',
                nilai: sem1,
                warnaBatang:
                    Colors.orange.shade400,
                warnaTeks: warnaTeksSub,
                adaData: adaSem1,
              ),

              const SizedBox(height: 6),

              // ======================================================
              // SEMESTER 2
              // ======================================================

              _buildBatangHorizontal(
                label: 'S2',
                nilai: sem2,
                warnaBatang:
                    AppColors.primary,
                warnaTeks: warnaTeksSub,
                adaData: adaSem2,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================================================================
  // BATANG HORIZONTAL
  // ================================================================

  Widget _buildBatangHorizontal({
    required String label,
    required double nilai,
    required Color warnaBatang,
    required Color warnaTeks,
    required bool adaData,
  }) {
    final double persentase =
        (nilai / 100).clamp(0.0, 1.0);

    return Row(
      children: [

        SizedBox(
          width: 25,
          child: Text(
            label,
            style: TextStyle(
              color: warnaTeks,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        const SizedBox(width: 7),

        Expanded(
          child: LayoutBuilder(
            builder: (
              context,
              constraints,
            ) {
              return Container(
                height: 9,
                decoration: BoxDecoration(
                  color: warnaTeks.withOpacity(0.08),
                  borderRadius:
                      BorderRadius.circular(5),
                ),
                child: adaData
                    ? Align(
                        alignment:
                            Alignment.centerLeft,
                        child: AnimatedContainer(
                          duration:
                              const Duration(
                            milliseconds: 500,
                          ),
                          width:
                              constraints.maxWidth *
                              persentase,
                          height: 9,
                          decoration:
                              BoxDecoration(
                            color: warnaBatang,
                            borderRadius:
                                BorderRadius.circular(
                              5,
                            ),
                          ),
                        ),
                      )
                    : null,
              );
            },
          ),
        ),

        const SizedBox(width: 8),

        SizedBox(
          width: 32,
          child: Text(
            adaData
                ? nilai.toStringAsFixed(1)
                : '-',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: adaData
                  ? warnaTeks
                  : warnaTeks.withOpacity(0.45),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}