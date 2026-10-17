import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:aplikasi_sekolah/core/constants/app_colors.dart';
import 'package:aplikasi_sekolah/core/services/api_config.dart';
import 'manajemen_penugasan_mapel_screen.dart';

class ManajemenJadwalScreen extends StatefulWidget {
  final bool statusTemaGelap;
  final String userId;
  const ManajemenJadwalScreen({
    super.key,
    required this.statusTemaGelap,
    required this.userId,
  });

  @override
  State<ManajemenJadwalScreen> createState() => _ManajemenJadwalScreenState();
}

class _BaseTimePickerTheme extends StatelessWidget {
  final Widget? child;
  const _BaseTimePickerTheme({this.child});
  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(
        context,
      ).copyWith(materialTapTargetSize: MaterialTapTargetSize.padded),
      child: child!,
    );
  }
}

class _ManajemenJadwalScreenState extends State<ManajemenJadwalScreen> {
  final _formKeyJadwal = GlobalKey<FormState>();
  final _pageController = ScrollController();
  final TextEditingController _ruanganController = TextEditingController(
    text: 'Ruang Kelas',
  );
  int? _kelasMapelTerpilihId;
  int? _jadwalEditId;
  List<Map<String, dynamic>> _listPenugasan = [];
  bool _isPenugasanLoading = true;

  TimeOfDay _jamMulai = const TimeOfDay(hour: 07, minute: 00);
  TimeOfDay _jamSelesai = const TimeOfDay(hour: 08, minute: 30);

  int? _kelasIdTerpilih;
  String _kelasTerpilih = '';
  String _hariTerpilih = 'Senin';
  List<dynamic> _listJadwalAktif = [];
  bool _isJadwalLoading = false;
  String _jadwalError = '';

  List<Map<String, dynamic>> _daftarKelas = [];
  final List<String> _daftarHari = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
  ];

  @override
  void initState() {
    super.initState();
    _ambilDaftarKelas();
    _ambilDaftarPenugasan();
    _ambilJadwalDariDatabase();
  }

  Future<void> _ambilDaftarKelas() async {
    try {
      final response = await http
          .get(Uri.parse('${ApiConfig.baseUrl}/get_kelas.php'))
          .timeout(const Duration(seconds: 15));
      final decoded = jsonDecode(response.body);
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          decoded is! Map<String, dynamic> ||
          decoded['status'] != 'success' ||
          decoded['data'] is! List) {
        throw Exception('Gagal memuat daftar kelas.');
      }
      if (!mounted) return;
      setState(() {
        _daftarKelas = (decoded['data'] as List)
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        if (_daftarKelas.isNotEmpty) {
          _kelasIdTerpilih = int.tryParse(_daftarKelas.first['id'].toString());
          _kelasTerpilih = _daftarKelas.first['nama'].toString();
        }
      });
      await _ambilJadwalDariDatabase();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat kelas: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _ruanganController.dispose();
    super.dispose();
  }

  Future<void> _ambilDaftarPenugasan() async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/get_kelas_mapel.php');
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      final decoded = json.decode(response.body);
      if (response.statusCode != 200 ||
          decoded is! Map<String, dynamic> ||
          decoded['status'] != 'success' ||
          decoded['data'] is! List) {
        throw Exception(
          decoded is Map<String, dynamic>
              ? decoded['message'] ?? 'Gagal memuat penugasan mapel.'
              : 'Respons server penugasan mapel tidak valid.',
        );
      }
      final assignments = (decoded['data'] as List)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      if (mounted) setState(() => _listPenugasan = assignments);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat penugasan mapel: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPenugasanLoading = false);
    }
  }

  // 🌍 FUNGSI AMBIL DATA JADWAL (GET)
  Future<void> _ambilJadwalDariDatabase() async {
    setState(() => _isJadwalLoading = true);
    _jadwalError = '';
    try {
      final classId = _kelasIdTerpilih;
      if (classId == null) {
        setState(() => _listJadwalAktif = []);
        return;
      }
      final url = Uri.parse('${ApiConfig.baseUrl}/get_jadwal_by_kelas.php')
          .replace(queryParameters: {
            'kelas_id': classId.toString(),
            'hari': _hariTerpilih,
          });
      final response = await http.get(url).timeout(const Duration(seconds: 15));
      final decoded = json.decode(response.body);
      if (response.statusCode != 200 || decoded is! Map<String, dynamic>) {
        throw const FormatException('Respons server jadwal tidak valid.');
      }
      if (decoded['status'] != 'success' || decoded['data'] is! List) {
        throw Exception(decoded['message'] ?? 'Gagal memuat jadwal.');
      }
      if (mounted) {
        setState(() => _listJadwalAktif = decoded['data'] as List<dynamic>);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _jadwalError = 'Gagal memuat jadwal: $e';
          _listJadwalAktif = [];
        });
      }
    } finally {
      if (mounted) setState(() => _isJadwalLoading = false);
    }
  }

  TimeOfDay _parseTime(dynamic value, TimeOfDay fallback) {
    final parts = (value ?? '').toString().split(':');
    if (parts.length < 2) return fallback;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null || hour > 23 || minute > 59) {
      return fallback;
    }
    return TimeOfDay(hour: hour, minute: minute);
  }

  List<Map<String, dynamic>> get _penugasanKelasTerpilih => _listPenugasan
      .where((item) =>
          int.tryParse(item['kelas_id']?.toString() ?? '') ==
          _kelasIdTerpilih)
      .toList();

  Map<String, dynamic>? _penugasanById(int? id) {
    if (id == null) return null;
    for (final assignment in _listPenugasan) {
      if (int.tryParse(assignment['id']?.toString() ?? '') == id) {
        return assignment;
      }
    }
    return null;
  }

  Future<void> _bukaManajemenPenugasan() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ManajemenPenugasanMapelScreen(userId: widget.userId),
      ),
    );
    if (!mounted) return;
    await _ambilDaftarPenugasan();
    await _ambilJadwalDariDatabase();
  }

  void _mulaiEditJadwal(Map<String, dynamic> jadwal) {
    final id = int.tryParse(jadwal['id']?.toString() ?? '');
    final assignmentId = int.tryParse(
      jadwal['kelas_mapel_id']?.toString() ?? '',
    );
    final kelas = jadwal['kelas']?.toString() ?? '';
    final classId = int.tryParse(jadwal['kelas_id']?.toString() ?? '');
    final hari = jadwal['hari']?.toString() ?? '';
    if (id == null ||
        assignmentId == null ||
        _penugasanById(assignmentId) == null ||
        !_daftarKelas.any((item) =>
            int.tryParse(item['id'].toString()) == classId) ||
        !_daftarHari.contains(hari)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Jadwal lama belum terhubung ke penugasan kelas-mapel-guru.',
          ),
        ),
      );
      return;
    }
    setState(() {
      _jadwalEditId = id;
      _kelasIdTerpilih = classId;
      _kelasTerpilih = kelas;
      _hariTerpilih = hari;
      _jamMulai = _parseTime(jadwal['jam_mulai'], _jamMulai);
      _jamSelesai = _parseTime(jadwal['jam_selesai'], _jamSelesai);
      _kelasMapelTerpilihId = assignmentId;
      _ruanganController.text = jadwal['ruangan']?.toString() ?? '';
    });
    _pageController.animateTo(
      0,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
  }

  void _resetFormJadwal() {
    setState(() {
      _jadwalEditId = null;
      _kelasMapelTerpilihId = null;
      _ruanganController.text = 'Ruang Kelas';
      _jamMulai = const TimeOfDay(hour: 7, minute: 0);
      _jamSelesai = const TimeOfDay(hour: 8, minute: 30);
    });
  }

  Future<void> _hapusJadwal(Map<String, dynamic> jadwal) async {
    final id = int.tryParse(jadwal['id']?.toString() ?? '');
    if (id == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ID jadwal tidak valid.')));
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus jadwal?'),
        content: Text(
          'Jadwal ${jadwal['mata_pelajaran'] ?? ''} untuk $_kelasTerpilih akan dihapus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/delete_jadwal.php'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'id': id, 'user_id': widget.userId}),
          )
          .timeout(const Duration(seconds: 15));
      final decoded = json.decode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Respons server tidak valid.');
      }
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          decoded['status'] != 'success') {
        throw Exception(decoded['message'] ?? 'Gagal menghapus jadwal.');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(decoded['message'] ?? 'Jadwal dihapus.')),
      );
      if (_jadwalEditId == id) _resetFormJadwal();
      await _ambilJadwalDariDatabase();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menghapus jadwal: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 🚀 FUNGSI SIMPAN JADWAL BARU KE TABEL 'jadwal_pelajaran' (POST)
  Future<void> _simpanJadwalKeDatabase() async {
    if (!_formKeyJadwal.currentState!.validate()) return;
    final startMinutes = _jamMulai.hour * 60 + _jamMulai.minute;
    final endMinutes = _jamSelesai.hour * 60 + _jamSelesai.minute;
    if (endMinutes <= startMinutes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Jam selesai harus setelah jam mulai.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    final assignment = _penugasanById(_kelasMapelTerpilihId);
    if (assignment == null ||
        int.tryParse(assignment['kelas_id']?.toString() ?? '') !=
            _kelasIdTerpilih) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih penugasan mapel yang sesuai dengan kelas.'),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    final String formatMulai =
        '${_jamMulai.hour.toString().padLeft(2, '0')}:${_jamMulai.minute.toString().padLeft(2, '0')}:00';
    final String formatSelesai =
        '${_jamSelesai.hour.toString().padLeft(2, '0')}:${_jamSelesai.minute.toString().padLeft(2, '0')}:00';

    final dataPayload = {
      'user_id': widget.userId,
      if (_jadwalEditId != null) 'id': _jadwalEditId,
      'kelas_mapel_id': _kelasMapelTerpilihId,
      'hari': _hariTerpilih,
      'jam_mulai': formatMulai,
      'jam_selesai': formatSelesai,
      'ruangan': _ruanganController.text.trim(),
    };

    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/save_jadwal.php');
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: json.encode(dataPayload),
          )
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;
      final dataRespon = json.decode(response.body);
      if (dataRespon is Map<String, dynamic> &&
          response.statusCode >= 200 &&
          response.statusCode < 300 &&
          dataRespon['status'] == 'success') {
        final message =
            dataRespon['message']?.toString() ??
            (_jadwalEditId == null
                ? 'Jadwal berhasil disimpan.'
                : 'Jadwal berhasil diperbarui.');
        _resetFormJadwal();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.green),
        );
        await _ambilJadwalDariDatabase();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              dataRespon is Map<String, dynamic>
                  ? dataRespon['message']?.toString() ??
                        'Gagal menyimpan jadwal.'
                  : 'Respons server tidak valid.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Terjadi kesalahan koneksi server: $e'),
          backgroundColor: Colors.red,
        ),
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
    final Color warnaLatarHalaman = isDark
        ? const Color(0xFF0B141A)
        : const Color(0xFFF8FAFC);
    final Color warnaKotakKartu = isDark
        ? const Color(0xFF1C2D35)
        : Colors.white;
    final Color warnaTeksUtama = isDark ? Colors.white : Colors.black87;
    final Color warnaTeksSub = isDark ? Colors.white70 : Colors.grey.shade700;
    final Color warnaTeksMuted = isDark ? Colors.white60 : Colors.grey;
    final Color warnaGarisPinggir = isDark
        ? Colors.grey.shade700
        : Colors.grey.shade300;
    final Color warnaIconForm = isDark
        ? Colors.amber.shade400
        : AppColors.primary;

    return Scaffold(
      backgroundColor: warnaLatarHalaman,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Atur Jadwal Pelajaran',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: _bukaManajemenPenugasan,
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            icon: const Icon(Icons.assignment_ind_outlined),
            label: const Text('Penugasan'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                          Icon(
                            Icons.add_card_rounded,
                            color: warnaIconForm,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Tambah Slot Jadwal Baru',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: warnaTeksUtama,
                            ),
                          ),
                        ],
                      ),
                      Divider(height: 24, color: warnaGarisPinggir),

                      // DROPDOWN FILTER KELAS & HARI ADAPTIF
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: _kelasIdTerpilih,
                              dropdownColor: warnaKotakKartu,
                              style: TextStyle(color: warnaTeksUtama),
                              decoration: InputDecoration(
                                labelText: 'Tingkat Kelas',
                                labelStyle: TextStyle(color: warnaTeksMuted),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: warnaGarisPinggir,
                                  ),
                                ),
                                border: const OutlineInputBorder(),
                              ),
                              items: _daftarKelas.map((item) {
                                final classId =
                                    int.tryParse(item['id'].toString());
                                final name = item['nama'].toString();
                                return DropdownMenuItem<int>(
                                  value: classId,
                                  child: Text(
                                    name,
                                    style: TextStyle(color: warnaTeksUtama),
                                  ),
                                );
                              }).toList(),
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() {
                                    _kelasIdTerpilih = v;
                                    final matchingClass = _daftarKelas
                                        .where((item) =>
                                            int.tryParse(item['id'].toString()) == v)
                                        .toList();
                                    _kelasTerpilih = matchingClass.isEmpty
                                        ? ''
                                        : matchingClass.first['nama'].toString();
                                    _kelasMapelTerpilihId = null;
                                  });
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
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: warnaGarisPinggir,
                                  ),
                                ),
                                border: const OutlineInputBorder(),
                              ),
                              items: _daftarHari.map((String h) {
                                return DropdownMenuItem(
                                  value: h,
                                  child: Text(
                                    h,
                                    style: TextStyle(color: warnaTeksUtama),
                                  ),
                                );
                              }).toList(),
                              onChanged: (v) {
                                if (v != null)
                                  setState(() => _hariTerpilih = v);
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
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                side: BorderSide(color: warnaGarisPinggir),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              icon: Icon(
                                Icons.access_time_rounded,
                                size: 18,
                                color: warnaIconForm,
                              ),
                              label: Text(
                                'Mulai: ${_jamMulai.format(context)}',
                                style: TextStyle(color: warnaTeksSub),
                              ),
                              onPressed: () => _pilihWaktuJamMulai(context),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                side: BorderSide(color: warnaGarisPinggir),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              icon: Icon(
                                Icons.punch_clock_rounded,
                                size: 18,
                                color: warnaIconForm,
                              ),
                              label: Text(
                                'Selesai: ${_jamSelesai.format(context)}',
                                style: TextStyle(color: warnaTeksSub),
                              ),
                              onPressed: () => _pilihWaktuJamSelesai(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      if (_isPenugasanLoading)
                        const LinearProgressIndicator()
                      else
                        DropdownButtonFormField<int>(
                          value: _kelasMapelTerpilihId,
                          dropdownColor: warnaKotakKartu,
                          style: TextStyle(color: warnaTeksUtama),
                          decoration: InputDecoration(
                            labelText: 'Mapel dan Guru Pengampu',
                            labelStyle: TextStyle(color: warnaTeksMuted),
                            prefixIcon: Icon(
                              Icons.menu_book_rounded,
                              color: warnaTeksMuted,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: warnaGarisPinggir),
                            ),
                            border: const OutlineInputBorder(),
                          ),
                          items: _penugasanKelasTerpilih.map((item) {
                            final id = int.parse(item['id'].toString());
                            return DropdownMenuItem<int>(
                              value: id,
                              child: Text(
                                '${item['mata_pelajaran']} — ${item['guru_pengampu']} (${item['tahun_ajaran']})',
                                style: TextStyle(color: warnaTeksUtama),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: _penugasanKelasTerpilih.isEmpty
                              ? null
                              : (v) =>
                                    setState(() => _kelasMapelTerpilihId = v),
                          validator: (v) => v == null
                              ? 'Penugasan mapel kelas ini wajib dipilih'
                              : null,
                        ),
                      if (!_isPenugasanLoading &&
                          _penugasanKelasTerpilih.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Belum ada penugasan mapel aktif untuk $_kelasTerpilih. Tambahkan kelas, mapel, dan guru pengampu terlebih dahulu.',
                                style: TextStyle(
                                  color: warnaTeksMuted,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: _bukaManajemenPenugasan,
                                icon: const Icon(Icons.add),
                                label: const Text('Buat penugasan mapel'),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),

                      // FIELD INPUT TEXT LOKASI RUANGAN KELAS ADAPTIF
                      TextFormField(
                        controller: _ruanganController,
                        style: TextStyle(color: warnaTeksUtama),
                        decoration: InputDecoration(
                          labelText: 'Lokasi Ruangan / Kelas',
                          labelStyle: TextStyle(color: warnaTeksMuted),
                          prefixIcon: Icon(
                            Icons.room_rounded,
                            color: warnaTeksMuted,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: warnaGarisPinggir),
                          ),
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
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(
                            Icons.save_rounded,
                            color: Colors.white,
                          ),
                          label: const Text(
                            'SIMPAN SLOT JADWAL',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: warnaTeksUtama,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.sync_rounded,
                    color: warnaIconForm,
                    size: 20,
                  ),
                  onPressed: _ambilJadwalDariDatabase,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // KONDISIONAL RENDER UTAMA DAFTAR SLOT AGENDAL
            if (_isJadwalLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            else if (_jadwalError.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _jadwalError,
                        style: TextStyle(color: warnaTeksUtama),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Coba lagi',
                      onPressed: _ambilJadwalDariDatabase,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
              )
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
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: warnaTeksMuted,
                      fontSize: 13,
                    ),
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
                  String jamMulai =
                      jd['jam_mulai_format'] ??
                      (jd['jam_mulai'] ?? '-').toString().substring(0, 5);
                  String jamSelesai =
                      jd['jam_selesai_format'] ??
                      (jd['jam_selesai'] ?? '-').toString().substring(0, 5);

                  return Card(
                    color: warnaKotakKartu,
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 0.3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: warnaGarisPinggir),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      trailing: PopupMenuButton<String>(
                        tooltip: 'Aksi jadwal',
                        onSelected: (action) {
                          if (action == 'edit') {
                            _mulaiEditJadwal(
                              Map<String, dynamic>.from(jd as Map),
                            );
                          } else if (action == 'delete') {
                            _hapusJadwal(Map<String, dynamic>.from(jd as Map));
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: 'edit',
                            child: Text('Edit jadwal'),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text('Hapus jadwal'),
                          ),
                        ],
                      ),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.teal.withOpacity(0.2)
                              : Colors.teal.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.calendar_today_rounded,
                          color: Colors.teal,
                          size: 20,
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              jd['mata_pelajaran'] ?? '-',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: warnaTeksUtama,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              jd['hari'] ?? '-',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.blue.shade300
                                    : Colors.blue,
                              ),
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
                                Icon(
                                  Icons.person_outline_rounded,
                                  size: 14,
                                  color: warnaTeksMuted,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Guru: ${jd['guru_pengampu'] ?? '-'}',
                                    style: TextStyle(
                                      color: warnaTeksSub,
                                      fontSize: 12,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.schedule_rounded,
                                  size: 14,
                                  color: warnaTeksMuted,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$jamMulai - $jamSelesai WIB',
                                  style: TextStyle(
                                    color: warnaTeksSub,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Icon(
                                  Icons.meeting_room_outlined,
                                  size: 14,
                                  color: warnaTeksMuted,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    jd['ruangan'] ?? 'Ruang Kelas',
                                    style: TextStyle(
                                      color: warnaTeksSub,
                                      fontSize: 12,
                                    ),
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
