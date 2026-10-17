import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:aplikasi_sekolah/core/constants/app_colors.dart';
import 'package:aplikasi_sekolah/core/services/presensi_service.dart';
import 'package:aplikasi_sekolah/core/services/api_config.dart';

class PresensiScreen extends StatefulWidget {
  final String userId;
  final String role;
  final String? kelasIdUser;
  final bool statusTemaGelap;

  const PresensiScreen({
    super.key,
    required this.userId,
    required this.role,
    required this.kelasIdUser,
    required this.statusTemaGelap,
  });

  @override
  State<PresensiScreen> createState() => _PresensiScreenState();
}

class _PresensiScreenState extends State<PresensiScreen> {
  static const List<String> _statusPresensi = [
    'Hadir',
    'Sakit',
    'Izin',
    'Alpa',
  ];

  late DateTime _tanggalDipilih;
  int? _kelasDipilih;
  List<Map<String, dynamic>> _kelas = [];
  List<Map<String, dynamic>> _siswa = [];
  List<Map<String, dynamic>> _riwayat = [];
  final Map<String, String> _statusSiswa = {};
  final Map<String, TextEditingController> _catatanSiswa = {};
  bool _isLoading = true;
  bool _isSaving = false;
  String _error = '';

  bool get _isGuru => widget.role == 'guru';
  bool get _isAdmin => widget.role == 'admin';
  bool get _isPengisi => _isGuru;
  bool get _isDark => widget.statusTemaGelap;
  Color get _textColor => _isDark ? Colors.white : Colors.black87;
  Color get _mutedColor => _isDark ? Colors.white70 : Colors.black54;
  Color get _cardColor => _isDark ? const Color(0xFF1C2D35) : Colors.white;

  @override
  void initState() {
    super.initState();
    _tanggalDipilih = DateUtils.dateOnly(DateTime.now());
    _kelasDipilih = _isAdmin ? null : int.tryParse(widget.kelasIdUser ?? '');
    _muatKelas();
    _muatData();
  }

  String get _kelasNama {
    for (final kelas in _kelas) {
      if (int.tryParse(kelas['id'].toString()) == _kelasDipilih) {
        return kelas['nama'].toString();
      }
    }
    return '';
  }

  Future<void> _muatKelas() async {
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
        _kelas = (decoded['data'] as List)
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Gagal memuat kelas: $e');
    }
  }

  String get _tanggalApi {
    final year = _tanggalDipilih.year.toString().padLeft(4, '0');
    final month = _tanggalDipilih.month.toString().padLeft(2, '0');
    final day = _tanggalDipilih.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  String get _tanggalLabel =>
      '${_tanggalDipilih.day.toString().padLeft(2, '0')}/'
      '${_tanggalDipilih.month.toString().padLeft(2, '0')}/'
      '${_tanggalDipilih.year}';

  Future<void> _muatData() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    _bersihkanCatatan();

    if (_isGuru && (_kelasDipilih == null || _kelasDipilih! <= 0)) {
      setState(() {
        _error =
            'Kelas akun guru belum diatur. Hubungi admin untuk memperbarui kelas.';
        _isLoading = false;
      });
      return;
    }

    if (_isPengisi) {
      await _muatDaftarSiswa();
    }
    if (!_isGuru) {
      await _muatRiwayat();
    }
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  Future<void> _muatDaftarSiswa() async {
    final classId = _kelasDipilih;
    if (classId == null) return;
    final response = await PresensiService.ambilSiswa(classId);
    if (!mounted) return;
    if (response['status'] != 'success') {
      _error = response['message'] ?? 'Gagal memuat daftar siswa.';
      return;
    }

    final rawStudents = response['data'];
    if (rawStudents is! List) {
      _error = 'Format daftar siswa dari server tidak sesuai.';
      return;
    }

    _siswa = rawStudents
        .whereType<Map>()
        .map((student) => Map<String, dynamic>.from(student))
        .toList();
    _statusSiswa
      ..clear()
      ..addEntries(
        _siswa.map((student) => MapEntry(student['id'].toString(), 'Hadir')),
      );

    final previous = await PresensiService.ambilPresensi(
      userId: widget.userId,
      kelasId: _kelasDipilih,
      tanggal: _tanggalApi,
    );
    if (!mounted) return;
    if (previous['status'] == 'success' && previous['data'] is List) {
      for (final item in previous['data'] as List) {
        if (item is! Map) continue;
        final studentId = item['siswa_id']?.toString();
        final status = item['status']?.toString();
        if (studentId != null &&
            _statusSiswa.containsKey(studentId) &&
            _statusPresensi.contains(status)) {
          _statusSiswa[studentId] = status!;
          final note = item['catatan']?.toString() ?? '';
          if (note.isNotEmpty) {
            _controllerCatatan(studentId).text = note;
          }
        }
      }
    } else if (previous['status'] != 'success') {
      _error = previous['message'] ?? 'Gagal memeriksa presensi sebelumnya.';
    }
  }

  Future<void> _muatRiwayat() async {
    final response = await PresensiService.ambilPresensi(
      userId: widget.userId,
      kelasId: _isAdmin ? _kelasDipilih : null,
      tanggal: _tanggalApi,
    );
    if (!mounted) return;
    if (response['status'] != 'success') {
      _error = response['message'] ?? 'Gagal memuat riwayat presensi.';
      return;
    }
    final raw = response['data'];
    if (raw is! List) {
      _error = 'Format riwayat presensi dari server tidak sesuai.';
      return;
    }
    _riwayat = raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  TextEditingController _controllerCatatan(String studentId) =>
      _catatanSiswa.putIfAbsent(studentId, TextEditingController.new);

  void _bersihkanCatatan() {
    for (final controller in _catatanSiswa.values) {
      controller.dispose();
    }
    _catatanSiswa.clear();
  }

  @override
  void dispose() {
    _bersihkanCatatan();
    super.dispose();
  }

  Future<void> _pilihTanggal() async {
    final hariIni = DateUtils.dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _isGuru ? hariIni : _tanggalDipilih,
      firstDate: _isGuru ? hariIni : DateTime(2020),
      lastDate: _isGuru
          ? hariIni
          : DateTime.now().add(const Duration(days: 365)),
      selectableDayPredicate: _isGuru
          ? (date) => DateUtils.isSameDay(date, hariIni)
          : null,
    );
    if (picked == null || !mounted) return;
    setState(() => _tanggalDipilih = DateUtils.dateOnly(picked));
    await _muatData();
  }

  Future<void> _simpan() async {
    if (_siswa.isEmpty) {
      _tampilkanPesan('Tidak ada siswa yang dapat dicatat.', error: true);
      return;
    }
    if (_kelasDipilih == null) {
      _tampilkanPesan('Kelas belum dipilih.', error: true);
      return;
    }
    setState(() => _isSaving = true);
    final rows = _siswa.map((student) {
      final studentId = student['id'].toString();
      return <String, dynamic>{
        'siswa_id': studentId,
        'status': _statusSiswa[studentId] ?? 'Hadir',
        'catatan': _controllerCatatan(studentId).text.trim(),
      };
    }).toList();

    final response = await PresensiService.simpanPresensi(
      userId: widget.userId,
      kelasId: _kelasDipilih!,
      tanggal: _tanggalApi,
      presensi: rows,
    );
    if (!mounted) return;
    setState(() => _isSaving = false);
    _tampilkanPesan(
      response['message'] ?? 'Permintaan presensi selesai.',
      error: response['status'] != 'success',
    );
    if (response['status'] == 'success') {
      await _muatData();
    }
  }

  void _tampilkanPesan(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red.shade700 : AppColors.primary,
      ),
    );
  }

  int _jumlahStatus(String status) {
    if (_isPengisi) {
      return _statusSiswa.values.where((value) => value == status).length;
    }
    return _riwayat.where((row) => row['status']?.toString() == status).length;
  }

  Widget _buildBanner({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFF23865B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSummary() {
    const statuses = ['Hadir', 'Sakit', 'Izin', 'Alpa'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: statuses.map((status) {
          final color = _warnaStatus(status);
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: status == statuses.last ? 0 : 8),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: color.withValues(alpha: 0.22)),
              ),
              child: Column(
                children: [
                  Text(
                    '${_jumlahStatus(status)}',
                    style: TextStyle(
                      color: color,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    status,
                    style: TextStyle(color: _mutedColor, fontSize: 10),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDark
          ? const Color(0xFF0B141A)
          : const Color(0xFFF6F8FA),
      appBar: AppBar(
        title: Text(_isPengisi ? 'Input Presensi' : 'Riwayat Presensi'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _isLoading ? null : _muatData,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
          ? _buildError()
          : _isPengisi
          ? _buildFormPresensi()
          : _buildHistory(),
    );
  }

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700, size: 42),
          const SizedBox(height: 12),
          Text(
            _error,
            textAlign: TextAlign.center,
            style: TextStyle(color: _textColor),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _muatData,
            icon: const Icon(Icons.refresh),
            label: const Text('Coba lagi'),
          ),
        ],
      ),
    ),
  );

  Widget _buildFormPresensi() {
    return Column(
      children: [
        _buildBanner(
          title: 'Presensi Kelas',
          subtitle: '$_kelasNama • Catat kehadiran hari ini',
          icon: Icons.fact_check_rounded,
        ),
        _buildFilterPanel(allowClassSelection: false),
        _buildStatusSummary(),
        Expanded(
          child: _siswa.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.groups_2_outlined,
                        color: _mutedColor,
                        size: 48,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Belum ada siswa aktif di $_kelasNama.',
                        style: TextStyle(color: _mutedColor),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  itemCount: _siswa.length,
                  itemBuilder: (context, index) {
                    final student = _siswa[index];
                    final studentId = student['id'].toString();
                    final name = student['nama_lengkap']?.toString() ?? 'Siswa';
                    final status = _statusSiswa[studentId] ?? 'Hadir';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _cardColor,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: _isDark
                              ? Colors.white.withValues(alpha: 0.07)
                              : const Color(0xFFE9EEF0),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: _isDark ? 0.08 : 0.035,
                            ),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: AppColors.primary.withValues(
                                  alpha: 0.10,
                                ),
                                child: Text(
                                  name.trim().isEmpty
                                      ? 'S'
                                      : name.trim()[0].toUpperCase(),
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: TextStyle(
                                        color: _textColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'NIS ${student['nomor_induk'] ?? '-'}',
                                      style: TextStyle(
                                        color: _mutedColor,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: _warnaStatus(
                                    status,
                                  ).withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    color: _warnaStatus(status),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'STATUS KEHADIRAN',
                            style: TextStyle(
                              color: _mutedColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 7,
                            runSpacing: 4,
                            children: _statusPresensi.map((option) {
                              final selected = status == option;
                              final color = _warnaStatus(option);
                              return ChoiceChip(
                                label: Text(option),
                                selected: selected,
                                showCheckmark: false,
                                avatar: Icon(
                                  _ikonStatus(option),
                                  size: 15,
                                  color: selected ? color : _mutedColor,
                                ),
                                labelStyle: TextStyle(
                                  color: selected ? color : _mutedColor,
                                  fontWeight: selected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  fontSize: 12,
                                ),
                                backgroundColor: _isDark
                                    ? const Color(0xFF263942)
                                    : const Color(0xFFF4F7F6),
                                selectedColor: color.withValues(alpha: 0.13),
                                side: BorderSide(
                                  color: selected
                                      ? color.withValues(alpha: 0.45)
                                      : Colors.transparent,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 2,
                                ),
                                onSelected: (_) {
                                  setState(
                                    () => _statusSiswa[studentId] = option,
                                  );
                                },
                              );
                            }).toList(),
                          ),
                          if (status == 'Sakit' || status == 'Izin') ...[
                            const SizedBox(height: 10),
                            TextField(
                              controller: _controllerCatatan(studentId),
                              maxLength: 200,
                              decoration: InputDecoration(
                                labelText: 'Catatan (opsional)',
                                prefixIcon: const Icon(Icons.notes_rounded),
                                isDense: true,
                                filled: true,
                                fillColor: _isDark
                                    ? const Color(0xFF263942)
                                    : const Color(0xFFF8FAF9),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(13),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
        ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            decoration: BoxDecoration(
              color: _cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _simpan,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(_isSaving ? 'Menyimpan...' : 'Simpan Presensi'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterPanel({required bool allowClassSelection}) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: _isDark
              ? Colors.white.withValues(alpha: 0.07)
              : const Color(0xFFE9EEF0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (allowClassSelection) ...[
            DropdownButtonFormField<int>(
              initialValue: _kelasDipilih ?? -1,
              decoration: InputDecoration(
                labelText: 'Filter kelas',
                prefixIcon: const Icon(Icons.meeting_room_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem(value: -1, child: Text('Semua kelas')),
                ..._kelas.map(
                  (kelas) => DropdownMenuItem(
                    value: int.tryParse(kelas['id'].toString()),
                    child: Text(kelas['nama'].toString()),
                  ),
                ),
              ],
              onChanged: (value) async {
                if (value == null) return;
                setState(() => _kelasDipilih = value == -1 ? null : value);
                await _muatData();
              },
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isGuru ? 'Tanggal presensi' : 'Tanggal riwayat',
                      style: TextStyle(color: _mutedColor, fontSize: 11),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isGuru ? 'Hari ini • $_tanggalLabel' : _tanggalLabel,
                      style: TextStyle(
                        color: _textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton(
                onPressed: _pilihTanggal,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.3),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(_isGuru ? 'Hari ini' : 'Pilih'),
              ),
            ],
          ),
          if (_isPengisi) ...[
            const SizedBox(height: 10),
            Divider(height: 1, color: _mutedColor.withValues(alpha: 0.15)),
            const SizedBox(height: 9),
            Row(
              children: [
                Icon(Icons.groups_outlined, size: 17, color: _mutedColor),
                const SizedBox(width: 7),
                Text(
                  _kelasNama,
                  style: TextStyle(
                    color: _textColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_siswa.length} siswa',
                  style: TextStyle(color: _mutedColor, fontSize: 12),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHistory() {
    final filtered = _riwayat;
    return Column(
      children: [
        _buildBanner(
          title: 'Riwayat Presensi',
          subtitle: _isAdmin
              ? 'Pantau kehadiran seluruh kelas'
              : 'Catatan kehadiran Anda',
          icon: Icons.fact_check_outlined,
        ),
        _buildFilterPanel(allowClassSelection: _isAdmin),
        _buildStatusSummary(),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.event_note_rounded,
                        color: _mutedColor,
                        size: 48,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Belum ada riwayat presensi.',
                        style: TextStyle(color: _mutedColor),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final row = filtered[index];
                    final status = row['status']?.toString() ?? '-';
                    final note = row['catatan']?.toString() ?? '';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 9),
                      decoration: BoxDecoration(
                        color: _cardColor,
                        borderRadius: BorderRadius.circular(17),
                        border: Border.all(
                          color: _isDark
                              ? Colors.white.withValues(alpha: 0.07)
                              : const Color(0xFFE9EEF0),
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 5,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: _warnaStatus(
                            status,
                          ).withValues(alpha: 0.12),
                          child: Icon(
                            _ikonStatus(status),
                            color: _warnaStatus(status),
                          ),
                        ),
                        title: Text(
                          row['nama_siswa']?.toString() ?? 'Siswa',
                          style: TextStyle(
                            color: _textColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '${row['tanggal'] ?? '-'} • ${row['kelas'] ?? '-'}'
                            '${note.isEmpty ? '' : '\nCatatan: $note'}',
                            style: TextStyle(color: _mutedColor, height: 1.4),
                          ),
                        ),
                        isThreeLine: note.isNotEmpty,
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _warnaStatus(status).withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              color: _warnaStatus(status),
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Color _warnaStatus(String status) {
    switch (status) {
      case 'Hadir':
        return Colors.green;
      case 'Sakit':
        return Colors.orange;
      case 'Izin':
        return Colors.blue;
      case 'Alpa':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _ikonStatus(String status) {
    switch (status) {
      case 'Hadir':
        return Icons.check;
      case 'Sakit':
        return Icons.sick_outlined;
      case 'Izin':
        return Icons.event_note_outlined;
      case 'Alpa':
        return Icons.close;
      default:
        return Icons.help_outline;
    }
  }
}
