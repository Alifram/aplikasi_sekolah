import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aplikasi_sekolah/core/constants/app_colors.dart';
import 'package:aplikasi_sekolah/core/services/auth_service.dart';
import 'package:aplikasi_sekolah/core/services/dashboard_service.dart';

// Import Screens Akademik Terkait
import '../akademik/kelas_screen.dart';
import '../akademik/input_nilai_screen.dart';
import '../akademik/rapor_siswa_screen.dart';
import '../informasi/event_screen.dart';
import '../informasi/pantau_data_screen.dart';
import '../auth/register_form_screen.dart';

// Import Widgets Internal Dashboard
import 'widgets/home_banner_widget.dart';
import 'widgets/quick_action_banner.dart';

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
  bool _isStatistikLoading = true;
  bool _isEventsLoading = true;
  
  Map<String, dynamic> _dataStatistik = {};
  List<dynamic> _listEvents = [];

  // Logika Penanggalan Dinamis Otomatis Mengikuti Waktu Asli Gawai
  String _angkatanTerpilih = DateTime.now().year.toString(); 
  
  List<String> get _daftarOpsiAngkatan {
    int tahunSekarang = DateTime.now().year;
    List<String> listTahun = [];
    for (int i = 2023; i <= tahunSekarang + 1; i++) {
      listTahun.add(i.toString());
    }
    return listTahun;
  }

  @override
  void initState() {
    super.initState();
    _panggilDataAwal();
  }

  // Mengunduh paket statistik dan berita sekolah secara asinkronus
  Future<void> _panggilDataAwal() async {
    try {
      final resStat = await DashboardService.ambilStatistikBerdasarkanAngkatan(_angkatanTerpilih);
      final resEvent = await DashboardService.ambilAcaraTerbaru();
      
      if (mounted) {
        setState(() {
          if (resStat['status'] == 'success') {
            _dataStatistik = resStat['data'] ?? {};
          }
          if (resEvent['status'] == 'success') {
            _listEvents = resEvent['data'] ?? [];
          }
          _isStatistikLoading = false;
          _isEventsLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isStatistikLoading = false;
          _isEventsLoading = false;
        });
      }
    }
  }
  // TAB HOME: Menampilkan rangkuman selamat datang dan berita sekolah
  Widget _buildHalamanHomeUtama() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Selamat Datang,', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14)),
                const SizedBox(height: 4),
                Text(widget.namaUser, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                Text(widget.role.toUpperCase(), style: TextStyle(color: Colors.amber.shade300, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: const Row(
              children: [
                Icon(Icons.stars_rounded, color: Colors.amber, size: 30),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Sistem Akademik MIM Pasir Lor Aktif & Terintegrasi Cloud Server',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amber != null ? Colors.brown : Colors.black),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // SEKSI PENGUMUMAN / BERITA SEKOLAH TERBARU
          const Text(
            'Pengumuman & Berita',
            style: TextStyle(
              fontSize: 20, 
              fontWeight: FontWeight.bold, 
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 14),
          
          if (_isEventsLoading)
            const Center(child: CircularProgressIndicator(color: AppColors.primary))
          else if (_listEvents.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Belum ada pengumuman terbaru minggu ini.',
                  style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _listEvents.length,
              itemBuilder: (context, index) {
                final ev = _listEvents[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.amber,
                      child: Icon(Icons.campaign_rounded, color: Colors.white),
                    ),
                    title: Text(
                      ev['judul_event'] ?? '-',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Target: ${ev['target_kelas'] ?? 'Semua'} \n${ev['deskripsi_event'] ?? '-'}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    isThreeLine: true,
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
  // TAB STATISTIK: Menampilkan rekam jejak longitudinal nilai per generasi angkatan
  Widget _buildSeksiStatistikAdmin() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Perkembangan Nilai Sekolah', 
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary),
        ),
        const Text(
          'Diagram pantauan akumulasi rerata antar semester kelas 1-6', 
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 16),
        
        // Baris Pengatur Dropdown Pilihan Angkatan Cohort
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Data Angkatan: $_angkatanTerpilih',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.blueGrey),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: DropdownButton<String>(
                value: _angkatanTerpilih,
                underline: const SizedBox(),
                icon: const Icon(Icons.filter_alt_rounded, size: 16, color: AppColors.primary),
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 13),
                items: _daftarOpsiAngkatan.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text('Angkatan $value'),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _angkatanTerpilih = newValue;
                      _isStatistikLoading = true;
                    });
                    
                    DashboardService.ambilStatistikBerdasarkanAngkatan(_angkatanTerpilih).then((res) {
                      if (mounted) {
                        setState(() {
                          if (res['status'] == 'success') {
                            _dataStatistik = res['data'];
                          }
                          _isStatistikLoading = false;
                        });
                      }
                    });
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        
        // Render List Balok Grafik Kelas 1 sampai Kelas 6
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
              
              double sem1 = double.tryParse(dataKelas['semester_1'].toString()) ?? 0.0;
              double sem2 = double.tryParse(dataKelas['semester_2'].toString()) ?? 0.0;
              bool isNaik = sem2 >= sem1;
              double selisih = (sem2 - sem1).abs();

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 0.5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () {
                    // SINKRONISASI AKTIF: Mengunci saringan nama siswa & guru kelas secara otomatis
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PantauDataScreen(
                          filterKelasOtomatis: namaKelas, 
                          filterAngkatanOtomatis: _angkatanTerpilih,
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
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
                                  Text(
                                    ' ${isNaik ? 'Naik' : 'Turun'} ${selisih.toStringAsFixed(1)}', 
                                    style: TextStyle(color: isNaik ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.chevron_right_rounded, size: 16, color: Colors.grey),
                                ],
                              )
                            else
                              const Row(
                                children: [
                                  Text('Belum ada log nilai lengkap', style: TextStyle(color: Colors.grey, fontSize: 11, fontStyle: FontStyle.italic)),
                                  SizedBox(width: 4),
                                  Icon(Icons.chevron_right_rounded, size: 16, color: Colors.grey),
                                ],
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildGrafikBar("Semester 1", sem1, Colors.orange.shade400),
                        const SizedBox(height: 8),
                        _buildGrafikBar("Semester 2", sem2, AppColors.primary),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
  // Fungsi Pembantu Render Batang Diagram Nilai Rapor
  Widget _buildGrafikBar(String label, double nilai, Color warna) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            Text(nilai.toStringAsFixed(1), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        Stack(
          children: [
            Container(
              height: 12,
              width: double.infinity,
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
            ),
            FractionallySizedBox(
              widthFactor: (nilai / 100).clamp(0.0, 1.0),
              child: Container(
                height: 12,
                decoration: BoxDecoration(color: warna, borderRadius: BorderRadius.circular(6)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // TAB PROFIL: Menampilkan ringkasan identitas dan kontrol privasi akun
  Widget _buildHalamanProfilLengkap() {
    final user = widget.extraData;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          const CircleAvatar(
            radius: 50,
            backgroundColor: AppColors.primary,
            child: Icon(Icons.account_circle_rounded, size: 80, color: Colors.white),
          ),
          const SizedBox(height: 16),
          Text(widget.namaUser, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text(widget.role.toUpperCase(), style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
          const Divider(height: 40),
          
          ListTile(
            leading: const Icon(Icons.badge_outlined, color: AppColors.primary),
            title: const Text('Nomor Induk Resmi'),
            subtitle: Text(user['nomor_induk'] ?? '-'),
          ),
          ListTile(
            leading: const Icon(Icons.meeting_room_outlined, color: AppColors.primary),
            title: Text(widget.role == 'guru' ? 'Kelas Yang Diajar' : 'Tingkat Kelas'),
            subtitle: Text(widget.role == 'guru' ? (user['kelas_diajar'] ?? '-') : (user['kelas_diajar'] ?? 'Kelas 1')),
          ),
          if (widget.role == 'siswa' && user['tahun_angkatan'] != null)
            ListTile(
              leading: const Icon(Icons.calendar_today_outlined, color: AppColors.primary),
              title: const Text('Tahun Angkatan Masuk'),
              subtitle: Text('Generasi Tahun ${user['tahun_angkatan']}'),
            ),
          const Divider(height: 20),
          
          // TOMBOL LOGOUT AMAN: Membersihkan sesi lokal HP
          ListTile(
            leading: const Icon(Icons.power_settings_new, color: Colors.red),
            title: const Text('Keluar Aplikasi (Logout)', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            onTap: () async {
              await AuthService.logout();
              if (!mounted) return;
              Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
            },
          ),
        ],
      ),
    );
  }
  // Fungsi penyeleksi konten halaman berdasarkan indeks menu bawah yang aktif
  Widget _dapatkanKontenHalaman() {
    switch (_currentIndex) {
      case 0:
        return _buildHalamanHomeUtama();
      case 1:
        // JIKA ADMIN ATAU GURU, AKAN DIARAHKAN KE TAMPILAN GRAFIK STATISTIK ANGKATAN DI PART 4
        return (widget.role == 'admin' || widget.role == 'guru')
            ? SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: _buildSeksiStatistikAdmin(),
              )
            // JIKA SISWA/ORTU, LANGSUNG LEMPAR KE DETAIL RAPOR BAWAAN MEREKA SENDIRI
            : RaporSiswaScreen(idSiswa: widget.extraData['id'].toString());
      case 2:
        return (widget.role == 'admin')
            ? RegisterFormScreen(pembuatRole: widget.role)
            : (widget.role == 'guru')
                ? InputNilaiScreen(
                kelasGuru: widget.extraData['kelas_diajar'] ?? 'Belum Diatur', 
                idGuru: widget.extraData['id'].toString(),
                )
                : RaporSiswaScreen(idSiswa: widget.extraData['id'].toString());
      case 3:
        return EventScreen(
          namaUser: widget.namaUser,
          roleUser: widget.role,
        );
      case 4:
        return _buildHalamanProfilLengkap();
      default:
        return _buildHalamanHomeUtama();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _currentIndex == 0
          ? null // Sembunyikan appBar bawaan pada halaman Home karena sudah memakai kustom banner
          : AppBar(
              title: Text(
                _currentIndex == 1
                    ? 'Statistik Akademik'
                    : _currentIndex == 2
                        ? (widget.role == 'admin' ? 'Buat Akun Baru' : 'Input Nilai Rapor')
                        : _currentIndex == 3
                            ? 'Informasi & Kegiatan'
                            : 'Profil Pengguna',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              backgroundColor: AppColors.primary,
              iconTheme: const IconThemeData(color: Colors.white),
              elevation: 0,
            ),
      body: SafeArea(
        child: _dapatkanKontenHalaman(),
      ),
      // BARRIS TOMBOL NAVIGASI DI BAGIAN BAWAH LAYAR
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
          const BottomNavigationBarItem(icon: Icon(Icons.bar_chart_rounded), label: 'Statistik'),
          BottomNavigationBarItem(
            icon: Icon(widget.role == 'admin' ? Icons.person_add_rounded : Icons.assignment_rounded),
            label: widget.role == 'admin' ? 'Registrasi' : 'Akademik',
          ),
          const BottomNavigationBarItem(icon: Icon(Icons.notifications_rounded), label: 'Info'),
          const BottomNavigationBarItem(icon: Icon(Icons.account_circle_rounded), label: 'Profil'),
        ],
      ),
    );
  }
}