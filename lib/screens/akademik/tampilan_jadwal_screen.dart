import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:aplikasi_sekolah/core/constants/app_colors.dart';
import 'package:aplikasi_sekolah/core/services/api_config.dart';

class TampilanJadwalScreen extends StatefulWidget {
  final String roleUser;       // 'guru' atau 'siswa'
  final String namaLengkapUser; // Nama guru atau nama siswa
  final String kelasSiswa;     // Kelas siswa (jika role siswa)
  final bool statusTemaGelap;

  const TampilanJadwalScreen({
    super.key,
    required this.roleUser,
    required this.namaLengkapUser,
    this.kelasSiswa = '',
    required this.statusTemaGelap,
  });

  @override
  State<TampilanJadwalScreen> createState() => _TampilanJadwalScreenState();
}

class _TampilanJadwalScreenState extends State<TampilanJadwalScreen> {
  String _hariAktif = 'Senin';
  List<dynamic> _jadwalHariIni = [];
  bool _isLoadingJadwal = false;
  String _jadwalError = '';

  final List<String> _daftarHari = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];

  @override
  void initState() {
    super.initState();
    _ambilDataJadwalMatriks();
  }

  // 🌍 FUNGSI AMBIL DATA JADWAL BERDASARKAN ROLE & HARI
  Future<void> _ambilDataJadwalMatriks() async {
    setState(() => _isLoadingJadwal = true);
    _jadwalError = '';
    try {
      // Menggunakan file get_jadwal_by_kelas.php yang fleksibel
      final queryParameters = <String, String>{'hari': _hariAktif};
      if (widget.roleUser == 'siswa') {
        queryParameters['kelas'] =
            widget.kelasSiswa.isNotEmpty ? widget.kelasSiswa : 'Kelas 1';
      } else {
        queryParameters['guru'] = widget.namaLengkapUser;
      }

      final uri = Uri.parse(
        '${ApiConfig.baseUrl}/get_jadwal_by_kelas.php',
      ).replace(queryParameters: queryParameters);
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final dataRespon = json.decode(response.body);
        if (dataRespon['status'] == 'success') {
          List<dynamic> mentah = dataRespon['data'] ?? [];
          if (!mounted) return;
          setState(() {
            if (widget.roleUser == 'guru') {
              // Jika role GURU: Hanya tampilkan jadwal yang nama pengampunya cocok dengan user login
              _jadwalHariIni = mentah.where((j) => 
                j['guru_pengampu'].toString().toLowerCase().contains(widget.namaLengkapUser.toLowerCase())
              ).toList();
            } else {
              _jadwalHariIni = mentah;
            }
          });
        } else {
          _jadwalError = dataRespon['message'] ?? 'Gagal memuat jadwal.';
        }
      } else {
        _jadwalError = 'Server gagal memuat jadwal (${response.statusCode}).';
      }
    } catch (e) {
      debugPrint('Gagal memuat matriks jadwal MyTel-U: $e');
      _jadwalError = 'Tidak dapat terhubung ke server jadwal.';
    } finally {
      if (mounted) {
        setState(() => _isLoadingJadwal = false);
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    final bool isDark = widget.statusTemaGelap;
    final Color warnaLatarHalaman = isDark ? const Color(0xFF0B141A) : const Color(0xFFF8FAFC);
    final Color warnaKotakKartu = isDark ? const Color(0xFF1C2D35) : Colors.white;
    final Color warnaTeksUtama = isDark ? Colors.white : Colors.black87;
    final Color warnaTeksSub = isDark ? Colors.white70 : Colors.grey.shade700;
    final Color warnaTeksMuted = isDark ? Colors.white60 : Colors.grey;
    final Color warnaGarisPinggir = isDark ? Colors.grey.shade700 : Colors.grey.shade200;

    return Scaffold(
      backgroundColor: warnaLatarHalaman,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.roleUser == 'guru' ? 'Jadwal Mengajar Anda' : 'Jadwal Pelajaran Kelas',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. HORIZONTAL CAPSULE DAY FILTER MENEKAN ALA MYTEL-U
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(vertical: 10),
            color: isDark ? const Color(0xFF1C2D35) : Colors.white,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _daftarHari.length,
              itemBuilder: (context, index) {
                final hari = _daftarHari[index];
                final bool isSelected = _hariAktif == hari;
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: ChoiceChip(
                    label: Text(hari),
                    selected: isSelected,
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    backgroundColor: isDark ? const Color(0xFF0B141A) : Colors.grey.shade100,
                    side: BorderSide(color: isSelected ? AppColors.primary : warnaGarisPinggir),
                    onSelected: (bool selected) {
                      if (selected) {
                        setState(() => _hariAktif = hari);
                        _ambilDataJadwalMatriks();
                      }
                    },
                  ),
                );
              },
            ),
          ),
          
          // SUB-JUDUL IDENTITAS AGENDA KARTU
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 16, right: 16),
            child: Text(
              'Agenda Hari $_hariAktif',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: warnaTeksUtama),
            ),
          ),
          // 2. TIMETABLE LIST VIEW CONTAINER DENGAN KONDISIONAL AMAN
          Expanded(
            child: _isLoadingJadwal
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _jadwalError.isNotEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _jadwalError,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: warnaTeksSub),
                          ),
                        ),
                      )
                : _jadwalHariIni.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.calendar_month_rounded, size: 48, color: warnaTeksMuted),
                            const SizedBox(height: 12),
                            Text(
                              'Tidak ada jadwal pelajaran hari ini.',
                              style: TextStyle(fontStyle: FontStyle.italic, color: warnaTeksSub, fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _jadwalHariIni.length,
                        itemBuilder: (context, index) {
                          final jd = _jadwalHariIni[index];
                          String jamMulai = jd['jam_mulai_format'] ?? (jd['jam_mulai'] ?? '-').toString().substring(0, 5);
                          String jamSelesai = jd['jam_selesai_format'] ?? (jd['jam_selesai'] ?? '-').toString().substring(0, 5);

                          return Card(
                            color: warnaKotakKartu,
                            elevation: 0.5,
                            margin: const EdgeInsets.only(bottom: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(color: warnaGarisPinggir),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // LEFT PANEL INDIKATOR SLOT WAKTU DUA LINE
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        jamMulai,
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: warnaTeksUtama),
                                      ),
                                      Text(
                                        's/d $jamSelesai',
                                        style: TextStyle(fontSize: 11, color: warnaTeksMuted, fontWeight: FontWeight.w500),
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.teal.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          jd['ruangan'] ?? 'Kelas',
                                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.teal),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 16),
                                  
                                  // VERTICAL ACCENT LINER PEMBATAS ALA MYTEL-U
                                  Container(
                                    height: 70,
                                    width: 3,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.6),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  // RIGHT PANEL DETAIL DATA AKADEMIK INTEL
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          jd['mata_pelajaran'] ?? '-',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: warnaTeksUtama),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Icon(Icons.person_outline_rounded, size: 14, color: warnaTeksMuted),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                widget.roleUser == 'guru'
                                                    ? 'Tingkat: ${jd['kelas'] ?? '-'}'
                                                    : 'Guru: ${jd['guru_pengampu'] ?? '-'}',
                                                style: TextStyle(color: warnaTeksSub, fontSize: 12),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(Icons.bookmark_border_rounded, size: 14, color: warnaTeksMuted),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Status: Terjadwal Aktif',
                                              style: TextStyle(color: isDark ? Colors.amber.shade200 : Colors.blueGrey, fontSize: 11, fontWeight: FontWeight.w600),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}