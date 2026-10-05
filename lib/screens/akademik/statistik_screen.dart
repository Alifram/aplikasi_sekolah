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
    "Kelas 6": {"Semester 1": 0.0, "Semester 2": 0.0}
  };

  @override
  void initState() {
    super.initState();
    _panggilDataStatistik();
  }

  Future<void> _panggilDataStatistik() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.ambilStatistikAkademik(_angkatanTerpilih);
      if (mounted && res['status'] == 'success') {
        setState(() {
          _dataStatistik = res['data'];
        });
      }
    } catch (e) {
      debugPrint("Gagal memuat statistik: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = widget.statusTemaGelap;
    final Color warnaLatar = isDark ? const Color(0xFF0B141A) : Colors.grey.shade50;
    final Color warnaKartu = isDark ? const Color(0xFF1C2D35) : Colors.white;
    final Color warnaTeksUtama = isDark ? Colors.white : Colors.black87;
    final Color warnaTeksSub = isDark ? Colors.white70 : Colors.black54;

    return Scaffold(
      backgroundColor: warnaLatar,
      appBar: AppBar(
        title: const Text('Statistik Akademik', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Tahun Angkatan Siswa:', style: TextStyle(color: warnaTeksUtama, fontWeight: FontWeight.w500)),
                      DropdownButton<String>(
                        value: _angkatanTerpilih,
                        dropdownColor: warnaKartu,
                        style: TextStyle(color: warnaTeksUtama, fontWeight: FontWeight.bold),
                        items: ['2024', '2025', '2026', '2027'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _angkatanTerpilih = v);
                            _panggilDataStatistik();
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  ListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildBarisStatistikKelas('Kelas 1', warnaKartu, warnaTeksUtama, warnaTeksSub),
                      _buildBarisStatistikKelas('Kelas 2', warnaKartu, warnaTeksUtama, warnaTeksSub),
                      _buildBarisStatistikKelas('Kelas 3', warnaKartu, warnaTeksUtama, warnaTeksSub),
                      _buildBarisStatistikKelas('Kelas 4', warnaKartu, warnaTeksUtama, warnaTeksSub),
                      _buildBarisStatistikKelas('Kelas 5', warnaKartu, warnaTeksUtama, warnaTeksSub),
                      _buildBarisStatistikKelas('Kelas 6', warnaKartu, warnaTeksUtama, warnaTeksSub),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildBarisStatistikKelas(String namaKelas, Color bgKartu, Color txtUtama, Color txtSub) {
    bool isAdmin = widget.loginRole == 'admin';
    bool isGuruKelasIni = widget.loginRole == 'guru' && widget.kelasDiajarGuru == namaKelas;

    if (!isAdmin && !isGuruKelasIni) return const SizedBox.shrink();

    double sem1 = double.tryParse(_dataStatistik[namaKelas]?['Semester 1']?.toString() ?? '0.0') ?? 0.0;
    double sem2 = double.tryParse(_dataStatistik[namaKelas]?['Semester 2']?.toString() ?? '0.0') ?? 0.0;
    
    double selisih = (sem2 - sem1).abs();
    bool isNaik = sem2 >= sem1;
    final Color warnaTeksMuted = txtSub.withOpacity(0.7);

    return Card(
      color: bgKartu,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PantauDataScreen(
                filterKelasOtomatis: namaKelas, 
                filterAngkatanOtomatis: _angkatanTerpilih,
                statusTemaGelap: widget.statusTemaGelap, 
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(namaKelas, style: TextStyle(fontWeight: FontWeight.bold, color: txtUtama, fontSize: 15)),
                  if (sem1 > 0 && sem2 > 0)
                    Row(
                      children: [
                        Icon(isNaik ? Icons.trending_up : Icons.trending_down, color: isNaik ? Colors.green : Colors.red, size: 16),
                        Text(
                          ' ${isNaik ? 'Naik' : 'Turun'} ${selisih.toStringAsFixed(1)}', 
                          style: TextStyle(color: isNaik ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right_rounded, size: 16, color: Colors.grey),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Text('Belum ada log nilai lengkap', style: TextStyle(color: warnaTeksMuted, fontSize: 11, fontStyle: FontStyle.italic)),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right_rounded, size: 16, color: Colors.grey),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 16),
              
              _buildGrafikBarDinamis("Semester 1", sem1, Colors.orange.shade400, txtSub),
              const SizedBox(height: 12),
              _buildGrafikBarDinamis("Semester 2", sem2, AppColors.primary, txtSub),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGrafikBarDinamis(String labelSemester, double skorNilai, Color warnaBatang, Color warnaTeks) {
    double lebarPersentase = (skorNilai / 100).clamp(0.0, 1.0);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(labelSemester, style: TextStyle(fontSize: 12, color: warnaTeks)),
            Text(
              skorNilai.toStringAsFixed(1), 
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: warnaTeks),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Container(
          width: double.infinity,
          height: 10,
          decoration: BoxDecoration(
            color: warnaTeks.withOpacity(0.1),
            borderRadius: BorderRadius.circular(5),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: lebarPersentase,
            child: Container(
              decoration: BoxDecoration(
                color: warnaBatang,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
