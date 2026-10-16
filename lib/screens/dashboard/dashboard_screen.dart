import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aplikasi_sekolah/core/constants/app_colors.dart';
import 'package:aplikasi_sekolah/core/services/auth_service.dart';
import 'package:aplikasi_sekolah/core/services/dashboard_service.dart';
import 'package:aplikasi_sekolah/core/services/api_service.dart';
import 'package:aplikasi_sekolah/core/services/api_config.dart';
import '../akademik/manajemen_jadwal_screen.dart';
import '../akademik/tampilan_jadwal_screen.dart';
import '../akademik/kelas_screen.dart';
import '../akademik/input_nilai_screen.dart';
import '../akademik/rapor_siswa_screen.dart';
import '../akademik/presensi_screen.dart';
import '../informasi/event_screen.dart';
import '../informasi/pantau_data_screen.dart';
import '../auth/register_form_screen.dart';

class DashboardScreen extends StatefulWidget {
  final String role;
  final String namaUser;
  final Map<String, dynamic> extraData;
  final bool statusTemaGelap;
  final ValueChanged<bool> padaPerubahanTema;

  const DashboardScreen({
    super.key,
    required this.role,
    required this.namaUser,
    required this.extraData,
    required this.statusTemaGelap,
    required this.padaPerubahanTema,
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
  String _angkatanTerpilih = DateTime.now().year.toString();

  int _totalSiswa = 0;
  int _totalGuru = 0;
  int _totalPengumuman = 0;

  List<String> get _daftarOpsiAngkatan {
    int tahunSekarang = DateTime.now().year;
    List<String> listTahun = [];
    for (int i = 2023; i <= tahunSekarang + 5; i++) {
      listTahun.add(i.toString());
    }
    return listTahun;
  }

  @override
  void initState() {
    super.initState();
    _panggilDataAwal();
  }

  Future<void> _panggilDataAwal() async {
    try {
      final resStat = await DashboardService.ambilStatistikBerdasarkanAngkatan(
        _angkatanTerpilih,
      );
      final resEvent = await DashboardService.ambilAcaraTerbaru();
      final resRingkasan = await ApiService.ambilRingkasanDashboard();

      if (mounted) {
        setState(() {
          if (resStat['status'] == 'success')
            _dataStatistik = resStat['data'] ?? {};
          if (resEvent['status'] == 'success')
            _listEvents = resEvent['data'] ?? [];
          if (resRingkasan['status'] == 'success') {
            _totalSiswa =
                int.tryParse(resRingkasan['total_siswa'].toString()) ?? 0;
            _totalGuru =
                int.tryParse(resRingkasan['total_guru'].toString()) ?? 0;
            _totalPengumuman =
                int.tryParse(resRingkasan['total_pengumuman'].toString()) ?? 0;
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

  void _bukaPresensi() {
    final userId = widget.extraData['id']?.toString();
    if (userId == null || userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ID akun tidak ditemukan. Silakan login ulang.'),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PresensiScreen(
          userId: userId,
          role: widget.role,
          kelasUser: widget.extraData['kelas_diajar']?.toString() ?? '',
          statusTemaGelap: widget.statusTemaGelap,
        ),
      ),
    );
  }

  void _tampilkanDialogGantiPassword() {
    final TextEditingController _passLamaController = TextEditingController();
    final TextEditingController _passBaruController = TextEditingController();
    final _formKeyPassword = GlobalKey<FormState>();

    final bool isDark = widget.statusTemaGelap;
    final Color warnaLatarDialog = isDark
        ? const Color(0xFF1C2D35)
        : Colors.white;
    final Color warnaTeksUtama = isDark ? Colors.white : Colors.black87;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: warnaLatarDialog,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Ganti Password Akun',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: warnaTeksUtama,
              fontSize: 18,
            ),
          ),
          content: Form(
            key: _formKeyPassword,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _passLamaController,
                  obscureText: true,
                  style: TextStyle(color: warnaTeksUtama),
                  decoration: InputDecoration(
                    labelText: 'Password Saat Ini',
                    labelStyle: TextStyle(
                      color: isDark ? Colors.white70 : Colors.grey,
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      v!.isEmpty ? 'Password lama wajib diisi' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passBaruController,
                  obscureText: true,
                  style: TextStyle(color: warnaTeksUtama),
                  decoration: InputDecoration(
                    labelText: 'Password Baru Anda',
                    labelStyle: TextStyle(
                      color: isDark ? Colors.white70 : Colors.grey,
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v!.isEmpty) return 'Password baru wajib diisi';
                    if (v.length < 6) return 'Minimal terdiri dari 6 karakter';
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'BATAL',
                style: TextStyle(color: isDark ? Colors.white70 : Colors.grey),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              onPressed: () async {
                if (!_formKeyPassword.currentState!.validate()) return;

                final dataKunci = {
                  "id_user": widget.extraData['id'].toString(),
                  "password_lama": _passLamaController.text.trim(),
                  "password_baru": _passBaruController.text.trim(),
                };

                final res = await AuthService.gantiPassword(dataKunci);
                if (!mounted) return;
                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(res['message'] ?? 'Proses selesai.'),
                    backgroundColor: res['status'] == 'success'
                        ? Colors.green
                        : Colors.red,
                  ),
                );
              },
              child: const Text(
                'PERBARUI',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHalamanHomeUtama() {
    final Color warnaLatarBelakang = widget.statusTemaGelap
        ? const Color(0xFF0B141A)
        : Colors.white;
    final Color warnaKotakKartu = widget.statusTemaGelap
        ? const Color(0xFF1C2D35)
        : Colors.white;
    final Color warnaTeksUtama = widget.statusTemaGelap
        ? Colors.white
        : Colors.black87;
    final Color warnaTeksSub = widget.statusTemaGelap
        ? Colors.white70
        : Colors.black54;
    final Color warnaPinggiran = widget.statusTemaGelap
        ? Colors.grey.shade800
        : Colors.grey.shade200;

    return Container(
      color: warnaLatarBelakang,
      child: RefreshIndicator(
        onRefresh: _panggilDataAwal,
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER AKUN USER GRADIENT PREMIUM
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: widget.statusTemaGelap
                        ? [const Color(0xFF128C7E), const Color(0xFF075E54)]
                        : [
                            AppColors.primary,
                            AppColors.primary.withOpacity(0.85),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Selamat Datang,',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.namaUser,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        widget.role.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Text(
                'Menu Utama',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: warnaTeksUtama,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Akses cepat ke layanan sekolah',
                style: TextStyle(fontSize: 12, color: warnaTeksSub),
              ),
              const SizedBox(height: 14),
              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 16,
                crossAxisSpacing: 10,
                childAspectRatio: 0.85,
                children: [
                  // --- KONTROL GRID MENU KHUSUS ADMIN ---
                  if (widget.role == 'admin') ...[
                    _buildItemMenuBulat(
                      'Registrasi',
                      Icons.person_add_alt_1_rounded,
                      Colors.red,
                      () {
                        setState(() => _currentIndex = 2);
                      },
                      warnaKotakKartu,
                      warnaTeksUtama,
                    ),
                    _buildItemMenuBulat(
                      'Data Kelas',
                      Icons.grid_view_rounded,
                      Colors.blue,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const KelasScreen(kelasSiswa: ''),
                          ),
                        );
                      },
                      warnaKotakKartu,
                      warnaTeksUtama,
                    ),
                    _buildItemMenuBulat(
                      'Statistik',
                      Icons.bar_chart_rounded,
                      Colors.green,
                      () {
                        setState(() => _currentIndex = 1);
                      },
                      warnaKotakKartu,
                      warnaTeksUtama,
                    ),
                    _buildItemMenuBulat(
                      'Buat Event',
                      Icons.campaign_rounded,
                      Colors.amber.shade800,
                      () {
                        setState(() => _currentIndex = 3);
                      },
                      warnaKotakKartu,
                      warnaTeksUtama,
                    ),
                    // 🌟 TOMBOL MENU JADWAL BARU: Menggantikan Profil & Sandi lama di halaman utama Admin
                    _buildItemMenuBulat(
                      'Jadwal',
                      Icons.edit_calendar_rounded,
                      Colors.teal,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ManajemenJadwalScreen(
                              statusTemaGelap: widget.statusTemaGelap,
                              userId: widget.extraData['id'].toString(),
                            ),
                          ),
                        );
                      },
                      warnaKotakKartu,
                      warnaTeksUtama,
                    ),
                    _buildItemMenuBulat(
                      'Presensi',
                      Icons.fact_check_rounded,
                      Colors.blue,
                      _bukaPresensi,
                      warnaKotakKartu,
                      warnaTeksUtama,
                    ),
                  ],

                  // --- KONTROL GRID MENU KHUSUS GURU ---
                  if (widget.role == 'guru') ...[
                    _buildItemMenuBulat(
                      'Input Nilai',
                      Icons.assignment_rounded,
                      Colors.red,
                      () {
                        setState(() => _currentIndex = 2);
                      },
                      warnaKotakKartu,
                      warnaTeksUtama,
                    ),
                    _buildItemMenuBulat(
                      'Presensi',
                      Icons.fact_check_rounded,
                      Colors.blue,
                      _bukaPresensi,
                      warnaKotakKartu,
                      warnaTeksUtama,
                    ),
                    _buildItemMenuBulat(
                      'Statistik',
                      Icons.analytics_rounded,
                      Colors.green,
                      () {
                        setState(() => _currentIndex = 1);
                      },
                      warnaKotakKartu,
                      warnaTeksUtama,
                    ),
                    _buildItemMenuBulat(
                      'Jadwal Guru',
                      Icons.calendar_month_rounded,
                      Colors.teal,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TampilanJadwalScreen(
                              roleUser: widget.role,
                              namaLengkapUser: widget.namaUser,
                              kelasSiswa:
                                  widget.extraData['kelas_diajar']
                                      ?.toString() ??
                                  '',
                              statusTemaGelap: widget.statusTemaGelap,
                            ),
                          ),
                        );
                      },
                      warnaKotakKartu,
                      warnaTeksUtama,
                    ),
                  ],

                  // --- KONTROL GRID MENU KHUSUS SISWA ---
                  if (widget.role == 'siswa') ...[
                    _buildItemMenuBulat(
                      'Rapor Saya',
                      Icons.menu_book_rounded,
                      Colors.red,
                      () {
                        setState(() => _currentIndex = 1);
                      },
                      warnaKotakKartu,
                      warnaTeksUtama,
                    ),
                    _buildItemMenuBulat(
                      'Presensi',
                      Icons.co_present_rounded,
                      Colors.blue,
                      _bukaPresensi,
                      warnaKotakKartu,
                      warnaTeksUtama,
                    ),
                    _buildItemMenuBulat(
                      'Info MIM',
                      Icons.notifications_active_rounded,
                      Colors.amber.shade800,
                      () {
                        setState(() => _currentIndex = 3);
                      },
                      warnaKotakKartu,
                      warnaTeksUtama,
                    ),
                    _buildItemMenuBulat(
                      'Jadwal Pelajaran',
                      Icons.calendar_today_rounded,
                      Colors.teal,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TampilanJadwalScreen(
                              roleUser: widget.role,
                              namaLengkapUser: widget.namaUser,
                              kelasSiswa:
                                  widget.extraData['kelas_diajar']
                                      ?.toString() ??
                                  '',
                              statusTemaGelap: widget.statusTemaGelap,
                            ),
                          ),
                        );
                      },
                      warnaKotakKartu,
                      warnaTeksUtama,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 32),
              // =========================================================================
              // SEKSI BERITA MADRASAH BANNER HORIZONTAL SLIDER BANNER (SINKRON DATA LIVE)
              // =========================================================================
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Informasi & Berita Madrasah',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: warnaTeksUtama,
                      letterSpacing: 0.5,
                    ),
                  ),
                  InkWell(
                    onTap: () => setState(() => _currentIndex = 3),
                    child: const Text(
                      'Lihat Semua',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (_isEventsLoading)
                const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              else if (_listEvents.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: warnaKotakKartu,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: warnaPinggiran),
                  ),
                  child: Center(
                    child: Text(
                      'Belum ada data berita atau pengumuman aktif.',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: warnaTeksSub,
                        fontSize: 13,
                      ),
                    ),
                  ),
                )
              else
                // 🌟 HORIZONTAL EVENT BANNER SLIDER BERGAMBAR UTUH
                SizedBox(
                  height: 220,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _listEvents.length,
                    itemBuilder: (context, index) {
                      final ev = _listEvents[index];
                      return Container(
                        width: MediaQuery.of(context).size.width * 0.82,
                        margin: const EdgeInsets.only(right: 16),
                        decoration: BoxDecoration(
                          color: warnaKotakKartu,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: warnaPinggiran, width: 1.2),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => setState(() => _currentIndex = 3),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // FOTO COVER SPANDUK BERITA VISUAL
                              Expanded(
                                flex: 5,
                                child: Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade300,
                                    image:
                                        ev['gambar_url'] != null &&
                                            ev['gambar_url']
                                                .toString()
                                                .isNotEmpty
                                        ? DecorationImage(
                                            image: NetworkImage(
                                              ev['gambar_url']
                                                      .toString()
                                                      .startsWith('http')
                                                  ? ev['gambar_url'].toString()
                                                  : '${ApiConfig.baseUrl}/view_image.php?file=${Uri.encodeQueryComponent(ev['gambar_url'].toString())}',
                                            ),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    alignment: Alignment.topLeft,
                                    color: Colors.black.withOpacity(0.2),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.shade800,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'Target: ${ev['target_kelas'] ?? 'Semua Kelas'}',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // ISI KONTEN TEKS JUDUL & KETERANGAN BERITA
                              Expanded(
                                flex: 4,
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        ev['judul_event'] ?? ev['judul'] ?? '-',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: warnaTeksUtama,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        ev['deskripsi_event'] ??
                                            ev['deskripsi'] ??
                                            ev['isi'] ??
                                            '-',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: warnaTeksSub,
                                          fontSize: 11,
                                          height: 1.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // Halaman Seksi Pelacakan Diagram Batang Rerata Lintas Kelas
  Widget _buildSeksiStatistikAdmin() {
    final Color warnaLatarBelakang = widget.statusTemaGelap
        ? const Color(0xFF0B141A)
        : Colors.white;
    final Color warnaKotakKartu = widget.statusTemaGelap
        ? const Color(0xFF1C2D35)
        : Colors.white;
    final Color warnaTeksUtama = widget.statusTemaGelap
        ? Colors.white
        : Colors.black87;
    final Color warnaTeksSub = widget.statusTemaGelap
        ? Colors.white70
        : Colors.black54;
    final Color warnaTeksMuted = widget.statusTemaGelap
        ? Colors.grey.shade400
        : Colors.grey;
    final Color warnaPinggiran = widget.statusTemaGelap
        ? Colors.grey.shade800
        : Colors.grey.shade200;
    final Color warnaLatarDropdown = widget.statusTemaGelap
        ? const Color(0xFF182229)
        : Colors.white;

    return Container(
      color: warnaLatarBelakang,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Perkembangan Nilai Sekolah',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: warnaTeksUtama,
            ),
          ),
          Text(
            'Diagram pantauan akumulasi rerata antar semester kelas 1-6',
            style: TextStyle(color: warnaTeksSub, fontSize: 13),
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Data Angkatan: $_angkatanTerpilih',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: widget.statusTemaGelap
                      ? Colors.amber.shade200
                      : Colors.blueGrey,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 0,
                ),
                decoration: BoxDecoration(
                  color: warnaLatarDropdown,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: warnaPinggiran),
                ),
                child: DropdownButton<String>(
                  value: _angkatanTerpilih,
                  underline: const SizedBox(),
                  dropdownColor: warnaLatarDropdown,
                  icon: Icon(
                    Icons.filter_alt_rounded,
                    size: 16,
                    color: widget.statusTemaGelap
                        ? Colors.amber
                        : AppColors.primary,
                  ),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: widget.statusTemaGelap
                        ? Colors.amber
                        : AppColors.primary,
                    fontSize: 13,
                  ),
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
                      DashboardService.ambilStatistikBerdasarkanAngkatan(
                        _angkatanTerpilih,
                      ).then((res) {
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
          if (_isStatistikLoading)
            const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 6,
              itemBuilder: (context, index) {
                String namaKelas = "Kelas ${index + 1}";
                var dataKelas =
                    _dataStatistik[namaKelas] ??
                    {"semester_1": 0.0, "semester_2": 0.0};
                double sem1 =
                    double.tryParse(dataKelas['semester_1'].toString()) ?? 0.0;
                double sem2 =
                    double.tryParse(dataKelas['semester_2'].toString()) ?? 0.0;
                bool isNaik = sem2 >= sem1;
                double selisih = (sem2 - sem1).abs();

                return Card(
                  color: warnaKotakKartu,
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 0.5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: warnaPinggiran),
                  ),
                  clipBehavior: Clip.antiAlias,
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
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                namaKelas,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: warnaTeksUtama,
                                  fontSize: 15,
                                ),
                              ),
                              if (sem1 > 0 && sem2 > 0)
                                Row(
                                  children: [
                                    Icon(
                                      isNaik
                                          ? Icons.trending_up
                                          : Icons.trending_down,
                                      color: isNaik ? Colors.green : Colors.red,
                                      size: 16,
                                    ),
                                    Text(
                                      ' ${isNaik ? 'Naik' : 'Turun'} ${selisih.toStringAsFixed(1)}',
                                      style: TextStyle(
                                        color: isNaik
                                            ? Colors.green
                                            : Colors.red,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.chevron_right_rounded,
                                      size: 16,
                                      color: Colors.grey,
                                    ),
                                  ],
                                )
                              else
                                Row(
                                  children: [
                                    Text(
                                      'Belum ada log nilai lengkap',
                                      style: TextStyle(
                                        color: warnaTeksMuted,
                                        fontSize: 11,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.chevron_right_rounded,
                                      size: 16,
                                      color: Colors.grey,
                                    ),
                                  ],
                                ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _buildGrafikBarDinamis(
                            "Semester 1",
                            sem1,
                            Colors.orange.shade400,
                            warnaTeksSub,
                          ),
                          const SizedBox(height: 10),
                          _buildGrafikBarDinamis(
                            "Semester 2",
                            sem2,
                            AppColors.primary,
                            warnaTeksSub,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildGrafikBarDinamis(
    String label,
    double nilai,
    Color warnaBatang,
    Color warnaTeks,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: warnaTeks)),
            Text(
              nilai.toStringAsFixed(1),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: warnaTeks,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Stack(
          children: [
            Container(
              height: 12,
              width: double.infinity,
              decoration: BoxDecoration(
                color: widget.statusTemaGelap
                    ? const Color(0xFF202C33)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            FractionallySizedBox(
              widthFactor: (nilai / 100).clamp(0.0, 1.0),
              child: Container(
                height: 12,
                decoration: BoxDecoration(
                  color: warnaBatang,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGrafikBar(String label, double nilai, Color warna) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            Text(
              nilai.toStringAsFixed(1),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Stack(
          children: [
            Container(
              height: 12,
              width: double.infinity,
              decoration: BoxDecoration(
                color: widget.statusTemaGelap
                    ? const Color(0xFF202C33)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            FractionallySizedBox(
              widthFactor: (nilai / 100).clamp(0.0, 1.0),
              child: Container(
                height: 12,
                decoration: BoxDecoration(
                  color: warna,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHalamanProfilLengkap() {
    final user = widget.extraData;
    final Color warnaLatarBelakang = widget.statusTemaGelap
        ? const Color(0xFF0B141A)
        : Colors.white;
    final Color warnaKotakKartu = widget.statusTemaGelap
        ? const Color(0xFF1C2D35)
        : Colors.white;
    final Color warnaGarisPinggir = widget.statusTemaGelap
        ? Colors.grey.shade700
        : Colors.grey.shade200;

    final Color warnaTeksNama = widget.statusTemaGelap
        ? Colors.white
        : Colors.black87;
    final Color warnaTeksLabel = widget.statusTemaGelap
        ? Colors.white
        : Colors.black87;
    final Color warnaTeksIsiKanan = widget.statusTemaGelap
        ? Colors.amber.shade300
        : Colors.black;
    final Color warnaJudulSeksi = widget.statusTemaGelap
        ? Colors.amber.shade400
        : Colors.grey.shade700;
    final Color warnaIcon = widget.statusTemaGelap
        ? Colors.amber.shade400
        : AppColors.primary;

    return Container(
      color: warnaLatarBelakang,
      height: double.infinity,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. KARTU IDENTITAS VISUAL USER PREMIUM (FRAME ADAPTIF)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: warnaKotakKartu,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: warnaGarisPinggir, width: 1.5),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: AppColors.primary,
                    child: Text(
                      widget.namaUser.isNotEmpty
                          ? widget.namaUser.substring(0, 1).toUpperCase()
                          : 'A',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.namaUser,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: warnaTeksNama,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            widget.role.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            // 2. SEKSI INFORMASI AKUN RESMI
            Text(
              'Informasi Akun Resmi',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: warnaJudulSeksi,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              color: warnaKotakKartu,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: warnaGarisPinggir, width: 1.2),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.badge_outlined, color: warnaIcon),
                    title: Text(
                      'Nomor Induk Resmi',
                      style: TextStyle(
                        fontSize: 14,
                        color: warnaTeksLabel,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: Text(
                      user['nomor_induk'] ?? '-',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: warnaTeksIsiKanan,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Divider(height: 1, indent: 50, color: warnaGarisPinggir),
                  ListTile(
                    leading: Icon(Icons.email_outlined, color: warnaIcon),
                    title: Text(
                      'Alamat Email Sistem',
                      style: TextStyle(
                        fontSize: 14,
                        color: warnaTeksLabel,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: Text(
                      user['email'] ?? '-',
                      style: TextStyle(
                        color: widget.statusTemaGelap
                            ? Colors.white70
                            : Colors.black87,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 3. SEKSI SWITCH LIGHT/DARK MODE & PRIVASI
            Text(
              'Pengaturan & Kustomisasi',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: warnaJudulSeksi,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              color: warnaKotakKartu,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: warnaGarisPinggir, width: 1.2),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: Icon(
                      widget.statusTemaGelap
                          ? Icons.dark_mode_rounded
                          : Icons.light_mode_rounded,
                      color: widget.statusTemaGelap
                          ? Colors.amber.shade400
                          : Colors.orange,
                    ),
                    title: Text(
                      'Mode Gelap (Dark Mode)',
                      style: TextStyle(
                        fontSize: 14,
                        color: warnaTeksLabel,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      widget.statusTemaGelap
                          ? 'Tema malam aktif'
                          : 'Tema siang aktif',
                      style: TextStyle(
                        fontSize: 12,
                        color: widget.statusTemaGelap
                            ? Colors.white60
                            : Colors.black54,
                      ),
                    ),
                    value: widget.statusTemaGelap,
                    activeColor: Colors.amber.shade400,
                    activeTrackColor: AppColors.primary.withOpacity(0.5),
                    onChanged: (bool value) {
                      widget.padaPerubahanTema(value);
                    },
                  ),
                  Divider(height: 1, indent: 50, color: warnaGarisPinggir),
                  ListTile(
                    leading: Icon(Icons.lock_outline_rounded, color: warnaIcon),
                    title: Text(
                      'Keamanan & Ganti Password',
                      style: TextStyle(
                        fontSize: 14,
                        color: warnaTeksLabel,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: widget.statusTemaGelap
                          ? Colors.white60
                          : Colors.grey,
                    ),
                    onTap: _tampilkanDialogGantiPassword,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),

            // 4. TOMBOL KELUAR APLIKASI (LOGOUT)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  backgroundColor: widget.statusTemaGelap
                      ? Colors.red.withOpacity(0.05)
                      : Colors.transparent,
                ),
                icon: const Icon(
                  Icons.power_settings_new_rounded,
                  color: Colors.red,
                ),
                label: const Text(
                  'KELUAR APLIKASI (LOGOUT)',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                onPressed: () async {
                  await AuthService.logout();
                  if (!mounted) return;
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/login',
                    (route) => false,
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                'Sistem Rapor Digital MIM Pasir Lor\nVersi 2.0.0 (Production Release)',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: widget.statusTemaGelap ? Colors.white38 : Colors.grey,
                  fontSize: 11,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dapatkanKontenHalaman() {
    switch (_currentIndex) {
      case 0:
        return _buildHalamanHomeUtama();
      case 1:
        return (widget.role == 'admin' || widget.role == 'guru')
            ? SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: _buildSeksiStatistikAdmin(),
              )
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
          userId: widget.extraData['id'].toString(),
          namaUser: widget.namaUser,
          roleUser: widget.role,
          kelasUser: widget.extraData['kelas_diajar']?.toString(),
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
      backgroundColor: widget.statusTemaGelap
          ? const Color(0xFF0B141A)
          : Colors.white,
      appBar: _currentIndex == 0
          ? null
          : AppBar(
              title: Text(
                _currentIndex == 1
                    ? 'Statistik Akademik'
                    : _currentIndex == 2
                    ? (widget.role == 'admin'
                          ? 'Buat Akun Baru'
                          : 'Input Nilai Rapor')
                    : _currentIndex == 3
                    ? 'Informasi & Kegiatan'
                    : 'Profil Pengguna',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: AppColors.primary,
              iconTheme: const IconThemeData(color: Colors.white),
              elevation: 0,
            ),
      body: SafeArea(child: _dapatkanKontenHalaman()),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: widget.statusTemaGelap
            ? const Color(0xFF1C2D35)
            : Colors.white,
        selectedItemColor: widget.statusTemaGelap
            ? Colors.amber.shade400
            : AppColors.primary,
        unselectedItemColor: widget.statusTemaGelap
            ? Colors.white38
            : Colors.grey,
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_rounded),
            label: 'Statistik',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              widget.role == 'admin'
                  ? Icons.person_add_rounded
                  : Icons.assignment_rounded,
            ),
            label: widget.role == 'admin' ? 'Registrasi' : 'Akademik',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.notifications_rounded),
            label: 'Info',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.account_circle_rounded),
            label: 'Profil',
          ),
        ],
      ),
    );
  }

  // 🌟 HELPER WIDGET A: Merender tombol bulat premium khas visual menu ikon MyTel-U
  Widget _buildItemMenuBulat(
    String label,
    IconData ikon,
    Color warnaLingkaran,
    VoidCallback aksiKetuk,
    Color bgKartu,
    Color txtUtama,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        InkWell(
          onTap: aksiKetuk,
          borderRadius: BorderRadius.circular(30),
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: widget.statusTemaGelap
                  ? warnaLingkaran.withOpacity(0.18)
                  : warnaLingkaran.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: warnaLingkaran.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Icon(ikon, color: warnaLingkaran, size: 26),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: txtUtama,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  // 🌟 HELPER WIDGET B: Merender komponen metrik cadangan dasar sekolah
  Widget _buildItemMetrikDasar(
    String judul,
    String nilai,
    IconData ikon,
    Color warnaIkon,
    Color bgKartu,
    Color warnaBorder,
    Color txtUtama,
    Color txtSub,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgKartu,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: warnaBorder),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: warnaIkon.withOpacity(0.12),
            child: Icon(ikon, color: warnaIkon, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            nilai,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: txtUtama,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            judul,
            style: TextStyle(
              fontSize: 11,
              color: txtSub,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
