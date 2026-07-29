import 'package:flutter/material.dart';
import '../akademik/input_nilai_screen.dart';
import '../akademik/kelas_screen.dart';
import '../akademik/rapor_siswa_screen.dart';
import '../auth/register_form_screen.dart';
import '../informasi/event_screen.dart';
import '../informasi/pantau_data_screen.dart';
import 'package:aplikasi_sekolah/core/constants/app_colors.dart';
import 'package:aplikasi_sekolah/core/services/dashboard_service.dart';

import './widgets/home_banner_widget.dart';
import './widgets/quick_action_banner.dart';

class DashboardScreen extends StatefulWidget {
  final String role;
  final String namaUser;
  final Map<String, dynamic> extraData;

  const DashboardScreen({
    super.key,
    required this.role,
    required this.namaUser,
    required this.extraData,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  Map<String, dynamic> _dataStatistik = {};
  List<dynamic> _listEventsSingkat = [];
  bool _isStatistikLoading = true;
  bool _isEventsLoading = true;

  @override
  void initState() {
    super.initState();
    _muatSemuaDataHome();
  }

  void _muatSemuaDataHome() {
    if (widget.role == 'admin' || widget.role == 'guru') {
      _panggilStatistik();
    } else {
      setState(() => _isStatistikLoading = false);
    }
    _panggilAcaraTerbaru();
  }

  Future<void> _panggilAcaraTerbaru() async {
    final res = await DashboardService.ambilAcaraTerbaru();
    if (mounted) {
      setState(() {
        if (res['status'] == 'success') {
          List<dynamic> semuaData = res['data'];
          _listEventsSingkat = semuaData.take(2).toList();
        }
        _isEventsLoading = false;
      });
    }
  }

  Future<void> _panggilStatistik() async {
    final res = await DashboardService.ambilStatistik();
    if (mounted) {
      setState(() {
        if (res['status'] == 'success') {
          _dataStatistik = res['data'];
        }
        _isStatistikLoading = false;
      });
    }
  }
  @override
  Widget build(BuildContext context) {
    bool isAdmin = widget.role == 'admin';
    bool isGuru = widget.role == 'guru';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'MIM Pasir Lor',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _dapatkanKontenHalaman(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        onTap: (index) => setState(() => _currentIndex = index),
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(isAdmin || isGuru ? Icons.bar_chart_outlined : Icons.groups_outlined),
            activeIcon: Icon(isAdmin || isGuru ? Icons.bar_chart : Icons.groups),
            label: isAdmin || isGuru ? 'Statistik' : 'Kelas',
          ),
          BottomNavigationBarItem(
            icon: const CircleAvatar(
              backgroundColor: AppColors.primary,
              radius: 22,
              child: Icon(Icons.add_task, color: Colors.white, size: 20),
            ),
            label: isAdmin ? 'Tambah Akun' : isGuru ? 'Input Nilai' : 'History Nilai',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.campaign_outlined),
            activeIcon: Icon(Icons.campaign),
            label: 'Acara',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.account_circle_outlined),
            activeIcon: Icon(Icons.account_circle),
            label: 'Profil',
          ),
        ],
      ),
    );
  }

  Widget _buildHalamanHomeUtama() {
    String keteranganKelas = widget.extraData['kelas_diajar'] ?? 'Belum Diatur';

    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          _isStatistikLoading = true;
          _isEventsLoading = true;
        });
        _muatSemuaDataHome();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // MEMANGGIL EKSTRAKSI SUB-WIDGET 1 (Sangat Bersih)
            HomeBannerWidget(
              namaUser: widget.namaUser,
              role: widget.role,
              extraData: widget.extraData,
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSubJudulSeksiHome(
                    judul: '📢 Berita & Kegiatan Terbaru',
                    onDetailTap: () => setState(() => _currentIndex = 3),
                  ),
                  const SizedBox(height: 12),
                  _isEventsLoading
                      ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                      : _listEventsSingkat.isEmpty
                          ? _buildKartuKosong('Belum ada info kegiatan hari ini.')
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _listEventsSingkat.length,
                              itemBuilder: (context, index) {
                                final item = _listEventsSingkat[index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(color: Colors.grey.shade200),
                                  ),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.red.shade50,
                                      child: const Icon(Icons.campaign, color: Colors.red, size: 20),
                                    ),
                                    title: Text(
                                      item['judul_acara'] ?? '-',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Text(
                                      item['deskripsi'] ?? '-',
                                      style: const TextStyle(fontSize: 12),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    trailing: Text(
                                      item['target_kelas'] ?? '-',
                                      style: const TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                );
                              },
                            ),
                  const SizedBox(height: 24),
                  if (widget.role == 'admin' || widget.role == 'guru') ...[
                    _buildSubJudulSeksiHome(
                      judul: '📈 Cuplikan Tren Nilai Kelas 1 & 6',
                      onDetailTap: () => setState(() => _currentIndex = 1),
                    ),
                    const SizedBox(height: 12),
                    _isStatistikLoading
                        ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                        : Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              children: [
                                _buildBarStatistikHome(
                                  "Kelas 1",
                                  _dataStatistik['Kelas 1'] ?? {"semester_1": 0.0, "semester_2": 0.0},
                                ),
                                const Divider(height: 24),
                                _buildBarStatistikHome(
                                  "Kelas 6",
                                  _dataStatistik['Kelas 6'] ?? {"semester_1": 0.0, "semester_2": 0.0},
                                ),
                              ],
                            ),
                          ),
                  ] else ...[
                    _buildSubJudulSeksiHome(
                      judul: '👥 Teman Sekelas Anak Anda',
                      onDetailTap: () => setState(() => _currentIndex = 1),
                    ),
                    const SizedBox(height: 12),
                    _buildKartuInformasiKelasSiswaHome(keteranganKelas),
                  ],
                  const SizedBox(height: 28),
                  _buildSubJudulSeksiHome(
                    judul: widget.role == 'admin'
                        ? '👥 Manajemen Pengguna'
                        : widget.role == 'guru'
                        ? '📝 Pengisian Rapor Angka'
                        : '📜 Hasil Belajar Akumulasi',
                    onDetailTap: () {
                      if (widget.role == 'admin') {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const PantauDataScreen()));
                      } else {
                        setState(() => _currentIndex = 2);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  
                  // MEMANGGIL EKSTRAKSI SUB-WIDGET 2 (Gradasi Banner)
                  QuickActionBanner(
                    role: widget.role,
                    onNavigateToTab: (index) => setState(() => _currentIndex = index),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarStatistikHome(String namaKelas, Map<String, dynamic> data) {
    double s1 = double.parse(data['semester_1'].toString());
    double s2 = double.parse(data['semester_2'].toString());
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(namaKelas, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        Row(
          children: [
            Text('Sem 1: ${s1 > 0 ? s1 : "-"}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(width: 14),
            Text('Sem 2: ${s2 > 0 ? s2 : "-"}', style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold)),
            const SizedBox(width: 10),
            Icon(s2 >= s1 ? Icons.trending_up : Icons.trending_down, color: s2 >= s1 ? Colors.green : Colors.red, size: 16),
          ],
        ),
      ],
    );
  }

  Widget _buildGrafikBar(String labelSemester, double nilai, Color warnaBalok) {
    double ukuranLebarPersen = nilai > 0 ? (nilai / 100) : 0.02;
    return Row(
      children: [
        SizedBox(width: 80, child: Text(labelSemester, style: const TextStyle(fontSize: 11, color: Colors.grey))),
        Expanded(
          child: Stack(
            children: [
              Container(height: 12, decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4))),
              FractionallySizedBox(
                widthFactor: ukuranLebarPersen,
                child: Container(height: 12, decoration: BoxDecoration(color: warnaBalok, borderRadius: BorderRadius.circular(4))),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(nilai > 0 ? nilai.toString() : '0', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      ],
    );
  }

  Widget _buildHalamanProfilLengkap() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Center(
            child: CircleAvatar(
              radius: 50,
              backgroundColor: const Color(0xFFE8F5E9),
              child: Icon(
                widget.role == 'admin' ? Icons.admin_panel_settings : widget.role == 'guru' ? Icons.assignment_ind : Icons.face,
                size: 50,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(widget.namaUser, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text('ID Sistem: ${widget.extraData['nomor_induk']} • Peran ${widget.role.toUpperCase()}', style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 30),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline, color: AppColors.primary),
            title: const Text('Informasi Lembaga Sekolah MIM Pasir Lor'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.power_settings_new, color: Colors.red),
            title: const Text('Keluar Aplikasi (Logout)', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            onTap: () => Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false),
          ),
        ],
      ),
    );
  }
  Widget _buildKartuInformasiKelasSiswaHome(String kelas) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: Colors.green.shade50, child: const Icon(Icons.groups, color: AppColors.primary)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ruang Kelas Buah Hati: $kelas', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const Text('Lihat siapa saja wali murid & teman belajar di kelas anak Anda', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKartuKosong(String teks) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: Center(child: Text(teks, style: const TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic))),
    );
  }

  Widget _buildSeksiStatistikAdmin() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Perkembangan Nilai Sekolah', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary)),
        const Text('Diagram pantauan akumulasi rerata antar semester kelas 1-6', style: TextStyle(color: Colors.grey, fontSize: 13)),
        const SizedBox(height: 24),
        if (_isStatistikLoading)
          const Center(child: CircularProgressIndicator(color: AppColors.primary))
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 6,
            itemBuilder: (context, index) {
              String namaKelas = "Kelas ${index + 1}";
              var dataKelas = _dataStatistik[namaKelas] ?? {"semester_1": 0.0, "semester_2": 0.0};
              double sem1 = double.parse(dataKelas['semester_1'].toString());
              double sem2 = double.parse(dataKelas['semester_2'].toString());
              bool isNaik = sem2 >= sem1;
              double selisih = (sem2 - sem1).abs();

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(namaKelas, style: const TextStyle(fontWeight: FontWeight.bold)),
                        if (sem1 > 0 && sem2 > 0)
                          Row(
                            children: [
                              Icon(isNaik ? Icons.trending_up : Icons.trending_down, color: isNaik ? Colors.green : Colors.red, size: 16),
                              Text(' ${isNaik ? 'Naik' : 'Turun'} ${selisih.toStringAsFixed(1)}', style: TextStyle(color: isNaik ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          )
                        else
                          const Text('Belum ada log nilai lengkap', style: TextStyle(color: Colors.grey, fontSize: 11, fontStyle: FontStyle.italic)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildGrafikBar("Semester 1", sem1, Colors.orange.shade400),
                    const SizedBox(height: 8),
                    _buildGrafikBar("Semester 2", sem2, AppColors.primary),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildSubJudulSeksiHome({required String judul, required VoidCallback onDetailTap}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(judul, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
        InkWell(
          onTap: onDetailTap,
          borderRadius: BorderRadius.circular(6),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                Text('Detail', style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.bold)),
                SizedBox(width: 2),
                Icon(Icons.arrow_forward_ios, size: 10, color: AppColors.primary),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _dapatkanKontenHalaman() {
    switch (_currentIndex) {
      case 0:
        return _buildHalamanHomeUtama();
      case 1:
        return (widget.role == 'admin' || widget.role == 'guru')
            ? SingleChildScrollView(padding: const EdgeInsets.all(24), child: _buildSeksiStatistikAdmin())
            : KelasScreen(kelasSiswa: widget.extraData['kelas_diajar'] ?? 'Kelas 1');
      case 2:
        return (widget.role == 'admin')
            ? RegisterFormScreen(pembuatRole: widget.role)
            : (widget.role == 'guru')
                ? InputNilaiScreen(kelasGuru: widget.extraData['kelas_diajar'] ?? 'Kelas 1', idGuru: widget.extraData['id'].toString())
                : RaporSiswaScreen(idSiswa: widget.extraData['id'].toString());
      case 3:
        return EventScreen(namaUser: widget.namaUser, roleUser: widget.role);
      case 4:
        return _buildHalamanProfilLengkap();
      default:
        return _buildHalamanHomeUtama();
    }
  }
}
