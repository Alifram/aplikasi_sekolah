import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:aplikasi_sekolah/core/constants/app_colors.dart';

class ManajemenJadwalScreen extends StatefulWidget {
  final bool statusTemaGelap;

  const ManajemenJadwalScreen({super.key, required this.statusTemaGelap});

  @override
  State<ManajemenJadwalScreen> createState() => _ManajemenJadwalScreenState();
}

class _BaseTimePickerTheme extends StatelessWidget {
  final Widget? child;
  const _BaseTimePickerTheme({this.child});
  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        materialTapTargetSize: MaterialTapTargetSize.padded,
      ),
      child: child!,
    );
  }
}

class _ManajemenJadwalScreenState extends State<ManajemenJadwalScreen> {
  final _formKeyJadwal = GlobalKey<FormState>();
  
  // Controller Form Input Bebas (Wild & Anti-Macet)
  final TextEditingController _guruController = TextEditingController();
  final TextEditingController _ruanganController = TextEditingController(text: 'Ruang Kelas');
  
  String? _mapelTerpilih;
  
  TimeOfDay _jamMulai = const TimeOfDay(hour: 07, minute: 00);
  TimeOfDay _jamSelesai = const TimeOfDay(hour: 08, minute: 30);

  // Status State Manajemen
  String _kelasTerpilih = 'Kelas 1';
  String _hariTerpilih = 'Senin';
  List<dynamic> _listJadwalAktif = [];
  bool _isJadwalLoading = false;

  // DAFTAR LIST MATA PELAJARAN MADRASAH RESMI TERKONTROL
  final List<String> _daftarMapelMadrasah = [
    'Al-Qur\'an Hadis',
    'Akidah Akhlak',
    'Fikih',
    'Sejarah Kebudayaan Islam (SKI)',
    'Bahasa Arab',
    'Bahasa Indonesia',
    'Matematika',
    'Ilmu Pengetahuan Alam dan Sosial (IPAS)',
    'Pendidikan Pancasila (PPKn)',
    'Pendidikan Jasmani Olahraga & Kesehatan (PJOK)',
    'Seni Budaya & Prakarya',
    'Bahasa Jawa (Muatan Lokal)'
  ];

  final List<String> _daftarKelas = ['Kelas 1', 'Kelas 2', 'Kelas 3', 'Kelas 4', 'Kelas 5', 'Kelas 6'];
  final List<String> _daftarHari = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];

  @override
  void initState() {
    super.initState();
    _ambilJadwalDariDatabase();
  }
  // 🌍 FUNGSI AMBIL DATA JADWAL (GET)
  Future<void> _ambilJadwalDariDatabase() async {
    setState(() => _isJadwalLoading = true);
    try {
      final url = Uri.parse('http://localhost/api_sekolah/get_jadwal_by_kelas.php?kelas=$_kelasTerpilih');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final dataRespon = json.decode(response.body);
        if (dataRespon['status'] == 'success') {
          setState(() {
            _listJadwalAktif = dataRespon['data'] ?? [];
          });
        }
      }
    } catch (e) {
      debugPrint('Gagal memuat jadwal: $e');
    } finally {
      setState(() => _isJadwalLoading = false);
    }
  }

  // 🚀 FUNGSI SIMPAN JADWAL BARU (POST)
  Future<void> _simpanJadwalKeDatabase() async {
    if (!_formKeyJadwal.currentState!.validate()) return;
    if (_mapelTerpilih == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mohon pilih Mata Pelajaran terlebih dahulu!'), backgroundColor: Colors.amber),
      );
      return;
    }

    final String formatMulai = '${_jamMulai.hour.toString().padLeft(2, '0')}:${_jamMulai.minute.toString().padLeft(2, '0')}:00';
    final String formatSelesai = '${_jamSelesai.hour.toString().padLeft(2, '0')}:${_jamSelesai.minute.toString().padLeft(2, '0')}:00';

    final dataPayload = {
      'kelas': _kelasTerpilih,
      'hari': _hariTerpilih,
      'jam_mulai': formatMulai,
      'jam_selesai': formatSelesai,
      'mata_pelajaran': _mapelTerpilih,
      'guru_pengampu': _guruController.text.trim(),
      'ruangan': _ruanganController.text.trim(),
    };

    try {
      final url = Uri.parse('http://localhost/api_sekolah/save_jadwal.php');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(dataPayload),
      );

      final dataRespon = json.decode(response.body);
      if (dataRespon['status'] == 'success') {
        setState(() {
          _mapelTerpilih = null;
          _guruController.clear();
          _ruanganController.text = 'Ruang Kelas';
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(dataRespon['message']), backgroundColor: Colors.green),
        );
        _ambilJadwalDariDatabase(); // Refresh daftar setelah sukses
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(dataRespon['message'] ?? 'Gagal menyimpan'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Terjadi kesalahan koneksi server: $e'), backgroundColor: Colors.red),
      );
    }
  }
  // 🕒 FITUR PEMILIH JAM DIGITAL TERPROTEKSI ANGKA (INT ONLY)
  Future<void> _pilihWaktuJamMulai(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _jamMulai,
      initialEntryMode: TimePickerEntryMode.inputOnly,
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: _BaseTimePickerTheme(child: child),
        );
      },
    );
    if (picked != null && picked != _jamMulai) {
      setState(() {
        _jamMulai = picked;
      });
    }
  }

  Future<void> _pilihWaktuJamSelesai(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _jamSelesai,
      initialEntryMode: TimePickerEntryMode.inputOnly,
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: _BaseTimePickerTheme(child: child),
        );
      },
    );
    if (picked != null && picked != _jamSelesai) {
      setState(() {
        _jamSelesai = picked;
      });
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
    final Color warnaGarisPinggir = isDark ? Colors.grey.shade700 : Colors.grey.shade300;
    final Color warnaIconForm = isDark ? Colors.amber.shade400 : AppColors.primary;

    return Scaffold(
      backgroundColor: warnaLatarHalaman,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Atur Jadwal Pelajaran',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // CARD CONTAINER FORM PANEL PEMBUAT JADWAL
            Card(
              color: warnaKotakKartu,
              elevation: 0.5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: warnaGarisPinggir),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKeyJadwal,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.add_card_rounded, color: warnaIconForm, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Tambah Slot Jadwal Baru',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: warnaTeksUtama),
                          ),
                        ],
                      ),
                      Divider(height: 24, color: warnaGarisPinggir),

                      // DROPDOWN FILTER KELAS & HARI ADAPTIF
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _kelasTerpilih,
                              dropdownColor: warnaKotakKartu,
                              style: TextStyle(color: warnaTeksUtama),
                              decoration: InputDecoration(
                                labelText: 'Tingkat Kelas',
                                labelStyle: TextStyle(color: warnaTeksMuted),
                                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: warnaGarisPinggir)),
                                border: const OutlineInputBorder(),
                              ),
                              items: _daftarKelas.map((String k) {
                                return DropdownMenuItem(value: k, child: Text(k, style: TextStyle(color: warnaTeksUtama)));
                              }).toList(),
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() => _kelasTerpilih = v);
                                  _ambilJadwalDariDatabase();
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _hariTerpilih,
                              dropdownColor: warnaKotakKartu,
                              style: TextStyle(color: warnaTeksUtama),
                              decoration: InputDecoration(
                                labelText: 'Hari Belajar',
                                labelStyle: TextStyle(color: warnaTeksMuted),
                                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: warnaGarisPinggir)),
                                border: const OutlineInputBorder(),
                              ),
                              items: _daftarHari.map((String h) {
                                return DropdownMenuItem(value: h, child: Text(h, style: TextStyle(color: warnaTeksUtama)));
                              }).toList(),
                              onChanged: (v) {
                                if (v != null) setState(() => _hariTerpilih = v);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // PICKER TOMBOL JAM PELAJARAN DIGITAL ADAPTIF
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                side: BorderSide(color: warnaGarisPinggir),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: Icon(Icons.access_time_rounded, size: 18, color: warnaIconForm),
                              label: Text('Mulai: ${_jamMulai.format(context)}', style: TextStyle(color: warnaTeksSub)),
                              onPressed: () => _pilihWaktuJamMulai(context),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                side: BorderSide(color: warnaGarisPinggir),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: Icon(Icons.punch_clock_rounded, size: 18, color: warnaIconForm),
                              label: Text('Selesai: ${_jamSelesai.format(context)}', style: TextStyle(color: warnaTeksSub)),
                              onPressed: () => _pilihWaktuJamSelesai(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // DROPDOWN MATA PELAJARAN TERKONTROL (ANTI-TYPO)
                      DropdownButtonFormField<String>(
                        value: _mapelTerpilih,
                        dropdownColor: warnaKotakKartu,
                        style: TextStyle(color: warnaTeksUtama),
                        decoration: InputDecoration(
                          labelText: 'Pilih Mata Pelajaran',
                          labelStyle: TextStyle(color: warnaTeksMuted),
                          prefixIcon: Icon(Icons.book_rounded, color: warnaTeksMuted),
                          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: warnaGarisPinggir)),
                          border: const OutlineInputBorder(),
                        ),
                        items: _daftarMapelMadrasah.map((String mapel) {
                          return DropdownMenuItem(
                            value: mapel,
                            child: Text(mapel, style: TextStyle(color: warnaTeksUtama), overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (v) => setState(() => _mapelTerpilih = v),
                        validator: (v) => v == null ? 'Mata pelajaran wajib dipilih' : null,
                      ),
                      const SizedBox(height: 16),

                      // FIELD INPUT TEXT GURU BEBAS (WILD & 100% ANTI-GAGAL)
                      TextFormField(
                        controller: _guruController,
                        style: TextStyle(color: warnaTeksUtama),
                        decoration: InputDecoration(
                          labelText: 'Nama Guru Pengampu / Pengajar',
                          labelStyle: TextStyle(color: warnaTeksMuted),
                          prefixIcon: Icon(Icons.person_rounded, color: warnaTeksMuted),
                          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: warnaGarisPinggir)),
                          border: const OutlineInputBorder(),
                        ),
                        validator: (v) => v!.isEmpty ? 'Nama guru pengajar tidak boleh kosong' : null,
                      ),
                      const SizedBox(height: 16),

                      // FIELD INPUT TEXT LOKASI RUANGAN KELAS ADAPTIF
                      TextFormField(
                        controller: _ruanganController,
                        style: TextStyle(color: warnaTeksUtama),
                        decoration: InputDecoration(
                          labelText: 'Lokasi Ruangan / Kelas',
                          labelStyle: TextStyle(color: warnaTeksMuted),
                          prefixIcon: Icon(Icons.room_rounded, color: warnaTeksMuted),
                          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: warnaGarisPinggir)),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // TOMBOL EKSEKUTOR SUBMIT FORM SIMPAN JADWAL
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.save_rounded, color: Colors.white),
                          label: const Text('SIMPAN SLOT JADWAL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          onPressed: _simpanJadwalKeDatabase,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // PANEL SUB-JUDUL TAMPILAN MONITOR JADWAL AKTIF ADAPTIF
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tinjauan Jadwal $_kelasTerpilih',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: warnaTeksUtama),
                ),
                IconButton(
                  icon: Icon(Icons.sync_rounded, color: warnaIconForm, size: 20),
                  onPressed: _ambilJadwalDariDatabase,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // KONDISIONAL RENDER UTAMA DAFTAR SLOT AGENDAL
            if (_isJadwalLoading)
              const Center(child: Padding(padding: EdgeInsets.all(24.0), child: CircularProgressIndicator(color: AppColors.primary)))
            else if (_listJadwalAktif.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: warnaKotakKartu,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: warnaGarisPinggir),
                ),
                child: Center(
                  child: Text(
                    'Belum ada slot pelajaran diatur untuk $_kelasTerpilih.',
                    style: TextStyle(fontStyle: FontStyle.italic, color: warnaTeksMuted, fontSize: 13),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _listJadwalAktif.length,
                itemBuilder: (context, index) {
                  final jd = _listJadwalAktif[index];
                  String jamMulai = jd['jam_mulai_format'] ?? (jd['jam_mulai'] ?? '-').toString().substring(0, 5);
                  String jamSelesai = jd['jam_selesai_format'] ?? (jd['jam_selesai'] ?? '-').toString().substring(0, 5);

                  return Card(
                    color: warnaKotakKartu,
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 0.3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: warnaGarisPinggir),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.teal.withOpacity(0.2) : Colors.teal.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.calendar_today_rounded, color: Colors.teal, size: 20),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              jd['mata_pelajaran'] ?? '-',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: warnaTeksUtama),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              jd['hari'] ?? '-',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? Colors.blue.shade300 : Colors.blue),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.person_outline_rounded, size: 14, color: warnaTeksMuted),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Guru: ${jd['guru_pengampu'] ?? '-'}',
                                    style: TextStyle(color: warnaTeksSub, fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.schedule_rounded, size: 14, color: warnaTeksMuted),
                                const SizedBox(width: 4),
                                Text(
                                  '$jamMulai - $jamSelesai WIB',
                                  style: TextStyle(color: warnaTeksSub, fontSize: 12, fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(width: 12),
                                Icon(Icons.meeting_room_outlined, size: 14, color: warnaTeksMuted),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    jd['ruangan'] ?? 'Ruang Kelas',
                                    style: TextStyle(color: warnaTeksSub, fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
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
      ),
    );
  }
}
