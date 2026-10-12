import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:aplikasi_sekolah/core/constants/app_colors.dart';

class TampilanJadwalScreen extends StatefulWidget {
  final String roleUser;
  final String namaLengkapUser;
  final String kelasSiswa;
  final bool statusTemaGelap;

  const TampilanJadwalScreen({
    super.key,
    required this.roleUser,
    required this.namaLengkapUser,
    this.kelasSiswa = '',
    required this.statusTemaGelap,
  });

  @override
  State<TampilanJadwalScreen> createState() =>
      _TampilanJadwalScreenState();
}

class _TampilanJadwalScreenState extends State<TampilanJadwalScreen> {
  static const String _baseUrl = 'http://localhost:8000';

  static const List<String> _daftarHari = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];

  String _hariAktif = '';
  List<Map<String, dynamic>> _jadwalHariIni = [];

  bool _isLoadingJadwal = false;
  String? _pesanError;

  final PageController _pageController = PageController();
  Timer? _timerWaktu;

  // Menggunakan waktu WIB (UTC+7).
  DateTime get _waktuWIB =>
      DateTime.now().toUtc().add(const Duration(hours: 7));

  String get _hariSekarang =>
      _daftarHari[_waktuWIB.weekday - 1];

  bool get _isGuru =>
      widget.roleUser.trim().toLowerCase() == 'guru';

  int _nomorPermintaan = 0;

  @override
  void initState() {
    super.initState();

    _hariAktif = _hariSekarang;
    _ambilDataJadwal();

    // Memperbarui jadwal dan status setiap menit.
    _timerWaktu = Timer.periodic(
      const Duration(minutes: 1),
      (_) {
        if (!mounted) return;

        final String hariBaru = _hariSekarang;

        if (_hariAktif != hariBaru) {
          setState(() {
            _hariAktif = hariBaru;
            _jadwalHariIni = [];
            _pesanError = null;
          });

          _pageController.jumpToPage(0);
        }

        _ambilDataJadwal();
      },
    );
  }

  @override
  void dispose() {
    _timerWaktu?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _ambilDataJadwal() async {
    if (!mounted) return;

    final int nomorPermintaan = ++_nomorPermintaan;
    final String hariDiminta = _hariAktif;

    setState(() {
      _isLoadingJadwal = true;
      _pesanError = null;
    });

    try {
      final Map<String, String> parameter = {
        'hari': hariDiminta,
      };

      if (_isGuru) {
        final String namaGuru = widget.namaLengkapUser.trim();

        if (namaGuru.isEmpty) {
          throw Exception('Nama akun guru belum tersedia.');
        }

        parameter['guru'] = namaGuru;
      } else {
        final String kelas = widget.kelasSiswa.trim();

        if (kelas.isEmpty) {
          throw Exception(
            'Kelas siswa belum tersedia. Periksa data akun siswa.',
          );
        }

        parameter['kelas'] = kelas;
      }

      final Uri uri = Uri.parse(
        '$_baseUrl/get_jadwal_hari_ini.php',
      ).replace(queryParameters: parameter);

      debugPrint('Memuat jadwal dari: $uri');

      final http.Response response = await http
          .get(uri)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception(
          'Server mengembalikan kode ${response.statusCode}.',
        );
      }

      final dynamic hasil = jsonDecode(response.body);

      if (hasil is! Map || hasil['status'] != 'success') {
        throw Exception(
          hasil is Map
              ? (hasil['message'] ?? 'Respons API tidak berhasil.')
                  .toString()
              : 'Format respons API tidak valid.',
        );
      }

      final dynamic data = hasil['data'];

      if (data is! List) {
        throw Exception('Format data jadwal dari API tidak valid.');
      }

      final List<Map<String, dynamic>> daftarJadwal = [];

      for (final dynamic item in data) {
        if (item is Map) {
          daftarJadwal.add(
            Map<String, dynamic>.from(item),
          );
        }
      }

      // Abaikan respons lama jika pengguna sudah mengganti hari.
      if (!mounted || nomorPermintaan != _nomorPermintaan) {
        return;
      }

      setState(() {
        _jadwalHariIni = daftarJadwal;
        _pesanError = null;
      });

      debugPrint(
        'Jadwal $hariDiminta berhasil dimuat: '
        '${daftarJadwal.length} data.',
      );

      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
    } catch (e) {
      debugPrint('Gagal mengambil jadwal: $e');

      if (!mounted || nomorPermintaan != _nomorPermintaan) {
        return;
      }

      setState(() {
        _pesanError = e.toString().replaceFirst('Exception: ', '');
        _jadwalHariIni = [];
      });
    } finally {
      if (mounted && nomorPermintaan == _nomorPermintaan) {
        setState(() {
          _isLoadingJadwal = false;
        });
      }
    }
  }

  TimeOfDay? _bacaJam(dynamic nilai) {
    if (nilai == null) return null;

    final List<String> bagian = nilai.toString().split(':');
    if (bagian.length < 2) return null;

    final int? jam = int.tryParse(bagian[0]);
    final int? menit = int.tryParse(bagian[1]);

    if (jam == null ||
        menit == null ||
        jam < 0 ||
        jam > 23 ||
        menit < 0 ||
        menit > 59) {
      return null;
    }

    return TimeOfDay(hour: jam, minute: menit);
  }

  String _formatJam(dynamic nilai) {
    final TimeOfDay? jam = _bacaJam(nilai);
    if (jam == null) return '--:--';

    return '${jam.hour.toString().padLeft(2, '0')}:'
        '${jam.minute.toString().padLeft(2, '0')}';
  }

  int _menitHariIni(TimeOfDay jam) =>
      jam.hour * 60 + jam.minute;

  String _statusJadwal(Map<String, dynamic> jadwal) {
    final TimeOfDay? mulai = _bacaJam(jadwal['jam_mulai']);
    final TimeOfDay? selesai = _bacaJam(jadwal['jam_selesai']);

    if (mulai == null || selesai == null) {
      return 'Waktu belum valid';
    }

    final int sekarang = _waktuWIB.hour * 60 + _waktuWIB.minute;
    final int menitMulai = _menitHariIni(mulai);
    final int menitSelesai = _menitHariIni(selesai);

    if (sekarang < menitMulai) {
      return 'Akan datang';
    }

    if (sekarang < menitSelesai) {
      return 'Sedang berlangsung';
    }

    return 'Selesai';
  }

  Color _warnaStatus(String status, bool isDark) {
    switch (status) {
      case 'Sedang berlangsung':
        return isDark
            ? const Color(0xFF86EFAC)
            : const Color(0xFF147A50);
      case 'Akan datang':
        return isDark
            ? const Color(0xFFFCD34D)
            : const Color(0xFF946200);
      case 'Selesai':
        return isDark
            ? const Color(0xFFD1D5DB)
            : const Color(0xFF667085);
      default:
        return isDark
            ? const Color(0xFFFCA5A5)
            : const Color(0xFFB5122B);
    }
  }

  String _tanggalWIB() {
    const List<String> namaBulan = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];

    final DateTime sekarang = _waktuWIB;

    return '${sekarang.day} '
        '${namaBulan[sekarang.month - 1]} '
        '${sekarang.year}';
  }

  String _jamSekarangWIB() {
    final DateTime sekarang = _waktuWIB;
    final String jam = sekarang.hour.toString().padLeft(2, '0');
    final String menit = sekarang.minute.toString().padLeft(2, '0');

    return '$jam:$menit WIB';
  }

  void _pilihHari(String hari) {
    if (_hariAktif == hari) return;

    setState(() {
      _hariAktif = hari;
      _jadwalHariIni = [];
      _pesanError = null;
    });

    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }

    _ambilDataJadwal();
  }

  Widget _barisInformasi({
    required IconData ikon,
    required String label,
    required String nilai,
    required Color warnaTeks,
    required Color warnaTeksSekunder,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          ikon,
          size: 21,
          color: AppColors.primary,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: warnaTeksSekunder,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                nilai,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: warnaTeks,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKartuJadwal({
    required Map<String, dynamic> jadwal,
    required bool isDark,
    required Color warnaKartu,
    required Color warnaTeks,
    required Color warnaTeksSekunder,
    required Color warnaGaris,
  }) {
    final String mulai = _formatJam(jadwal['jam_mulai']);
    final String selesai = _formatJam(jadwal['jam_selesai']);
    final String status = _statusJadwal(jadwal);
    final Color warnaStatus = _warnaStatus(status, isDark);

    final String mataPelajaran =
        (jadwal['mata_pelajaran'] ?? '-').toString();

    final String namaGuru =
        (jadwal['guru_pengampu'] ?? '-').toString();

    final String kelas =
        (jadwal['kelas'] ?? '-').toString();

    final String ruangan =
        (jadwal['ruangan'] ?? 'Ruang Kelas').toString();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: warnaKartu,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: warnaGaris),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.12 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 5,
            color: AppColors.primary,
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mataPelajaran,
                  style: TextStyle(
                    color: warnaTeks,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: warnaStatus.withOpacity(isDark ? 0.16 : 0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: warnaStatus,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$mulai – $selesai WIB',
                            style: TextStyle(
                              color: warnaTeks,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Waktu pelajaran',
                            style: TextStyle(
                              color: warnaTeksSekunder,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(height: 1, color: warnaGaris),
                const SizedBox(height: 14),
                _barisInformasi(
                  ikon: Icons.person_outline_rounded,
                  label: _isGuru ? 'Kelas diajar' : 'Guru pengampu',
                  nilai: _isGuru ? kelas : namaGuru,
                  warnaTeks: warnaTeks,
                  warnaTeksSekunder: warnaTeksSekunder,
                ),
                const SizedBox(height: 12),
                _barisInformasi(
                  ikon: Icons.meeting_room_outlined,
                  label: 'Ruangan',
                  nilai: ruangan,
                  warnaTeks: warnaTeks,
                  warnaTeksSekunder: warnaTeksSekunder,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKontenJadwal({
    required bool isDark,
    required Color warnaKartu,
    required Color warnaTeks,
    required Color warnaTeksSekunder,
    required Color warnaGaris,
  }) {
    if (_isLoadingJadwal && _jadwalHariIni.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(50),
        child: Center(
          child: CircularProgressIndicator(
            color: AppColors.primary,
          ),
        ),
      );
    }

    if (_pesanError != null && _jadwalHariIni.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(28),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_rounded,
                size: 46,
                color: warnaTeksSekunder,
              ),
              const SizedBox(height: 12),
              Text(
                _pesanError!,
                textAlign: TextAlign.center,
                style: TextStyle(color: warnaTeksSekunder),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _ambilDataJadwal,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Coba lagi'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_jadwalHariIni.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(28),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.event_busy_rounded,
                size: 54,
                color: warnaTeksSekunder,
              ),
              const SizedBox(height: 12),
              Text(
                'Belum ada jadwal pada hari $_hariAktif.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: warnaTeks,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Pilih hari lain atau periksa data jadwal di database.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: warnaTeksSekunder,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _ambilDataJadwal,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Muat ulang'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Agenda Hari $_hariAktif',
                  style: TextStyle(
                    color: warnaTeks,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '${_jadwalHariIni.length} jadwal',
                style: TextStyle(
                  color: warnaTeksSekunder,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 320,
          child: PageView.builder(
            controller: _pageController,
            itemCount: _jadwalHariIni.length,
            padEnds: false,
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: index == _jadwalHariIni.length - 1 ? 20 : 10,
                  bottom: 8,
                ),
                child: _buildKartuJadwal(
                  jadwal: _jadwalHariIni[index],
                  isDark: isDark,
                  warnaKartu: warnaKartu,
                  warnaTeks: warnaTeks,
                  warnaTeksSekunder: warnaTeksSekunder,
                  warnaGaris: warnaGaris,
                ),
              );
            },
          ),
        ),
        if (_jadwalHariIni.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.swipe_rounded,
                    size: 16,
                    color: warnaTeksSekunder,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Geser kartu untuk melihat jadwal lainnya',
                    style: TextStyle(
                      color: warnaTeksSekunder,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (_isLoadingJadwal)
          const LinearProgressIndicator(
            color: AppColors.primary,
            minHeight: 2,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = widget.statusTemaGelap;

    final Color warnaLatarHalaman = isDark
        ? const Color(0xFF17191F)
        : const Color(0xFFF6F7FB);

    final Color warnaKartu =
        isDark ? const Color(0xFF23262E) : Colors.white;

    final Color warnaTeks =
        isDark ? const Color(0xFFF3F4F6) : const Color(0xFF172033);

    final Color warnaTeksSekunder =
        isDark ? const Color(0xFFB8BEC9) : const Color(0xFF667085);

    final Color warnaGaris =
        isDark ? const Color(0xFF3A3E48) : const Color(0xFFE4E7EC);

    return Scaffold(
      backgroundColor: warnaLatarHalaman,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _isGuru ? 'Jadwal Mengajar' : 'Jadwal Pelajaran',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Muat ulang jadwal',
            onPressed: _ambilDataJadwal,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _ambilDataJadwal,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(26),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isGuru
                        ? 'Halo, ${widget.namaLengkapUser}'
                        : 'Jadwal kelas ${widget.kelasSiswa}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    '$_hariSekarang, ${_tanggalWIB()}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time_rounded,
                        color: Colors.white,
                        size: 19,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Waktu sekarang: ${_jamSekarangWIB()}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.only(top: 16),
              height: 58,
              color: warnaKartu,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                itemCount: _daftarHari.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final String hari = _daftarHari[index];
                  final bool terpilih = _hariAktif == hari;

                  return ChoiceChip(
                    label: Text(hari),
                    selected: terpilih,
                    onSelected: (_) => _pilihHari(hari),
                    selectedColor: AppColors.primary,
                    backgroundColor: warnaLatarHalaman,
                    side: BorderSide(
                      color: terpilih
                          ? AppColors.primary
                          : warnaGaris,
                    ),
                    labelStyle: TextStyle(
                      color: terpilih ? Colors.white : warnaTeks,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    showCheckmark: false,
                  );
                },
              ),
            ),
            _buildKontenJadwal(
              isDark: isDark,
              warnaKartu: warnaKartu,
              warnaTeks: warnaTeks,
              warnaTeksSekunder: warnaTeksSekunder,
              warnaGaris: warnaGaris,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Text(
                'Waktu jadwal mengikuti WIB (UTC+7). '
                'Status diperbarui secara berkala.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: warnaTeksSekunder,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}