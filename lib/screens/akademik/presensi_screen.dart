import 'package:flutter/material.dart';
import 'package:aplikasi_sekolah/core/constants/app_colors.dart';
import 'package:aplikasi_sekolah/core/services/presensi_service.dart';

class PresensiScreen extends StatefulWidget {
  final String userId;
  final String role;
  final String kelasUser;
  final bool statusTemaGelap;

  const PresensiScreen({
    super.key,
    required this.userId,
    required this.role,
    required this.kelasUser,
    required this.statusTemaGelap,
  });

  @override
  State<PresensiScreen> createState() => _PresensiScreenState();
}

class _PresensiScreenState extends State<PresensiScreen> {
  static const List<String> _kelas = [
    'Kelas 1',
    'Kelas 2',
    'Kelas 3',
    'Kelas 4',
    'Kelas 5',
    'Kelas 6',
  ];
  static const List<String> _statusPresensi = [
    'Hadir',
    'Sakit',
    'Izin',
    'Alpa',
  ];

  late DateTime _tanggalDipilih;
  late String _kelasDipilih;
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
    final kelasGuru = _normalisasiKelas(widget.kelasUser);
    _kelasDipilih = _isAdmin ? '' : kelasGuru ?? '';
    _muatData();
  }

  String? _normalisasiKelas(String value) {
    final normalized = value.trim().toLowerCase();
    for (final kelas in _kelas) {
      if (normalized == kelas.toLowerCase() ||
          normalized == kelas.replaceFirst('Kelas ', '')) {
        return kelas;
      }
    }
    return null;
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

    if (_isGuru && !_kelas.contains(_kelasDipilih)) {
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
    final response = await PresensiService.ambilSiswa(_kelasDipilih);
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
      kelas: _kelasDipilih,
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
      kelas: _isAdmin ? _kelasDipilih : null,
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
      kelas: _kelasDipilih,
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
        _buildFilterPanel(allowClassSelection: false),
        Expanded(
          child: _siswa.isEmpty
              ? Center(
                  child: Text(
                    'Belum ada siswa aktif di $_kelasDipilih.',
                    style: TextStyle(color: _mutedColor),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: _siswa.length,
                  itemBuilder: (context, index) {
                    final student = _siswa[index];
                    final studentId = student['id'].toString();
                    return Card(
                      color: _cardColor,
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              student['nama_lengkap']?.toString() ?? 'Siswa',
                              style: TextStyle(
                                color: _textColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'NIS: ${student['nomor_induk'] ?? '-'}',
                              style: TextStyle(
                                color: _mutedColor,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              initialValue: _statusSiswa[studentId] ?? 'Hadir',
                              decoration: const InputDecoration(
                                labelText: 'Status kehadiran',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              items: _statusPresensi
                                  .map(
                                    (status) => DropdownMenuItem(
                                      value: status,
                                      child: Text(status),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(
                                    () => _statusSiswa[studentId] = value,
                                  );
                                }
                              },
                            ),
                            if (_statusSiswa[studentId] == 'Sakit' ||
                                _statusSiswa[studentId] == 'Izin') ...[
                              const SizedBox(height: 8),
                              TextField(
                                controller: _controllerCatatan(studentId),
                                maxLength: 200,
                                decoration: const InputDecoration(
                                  labelText: 'Catatan (opsional)',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
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
                    : const Icon(Icons.save_outlined),
                label: Text(_isSaving ? 'Menyimpan...' : 'Simpan Presensi'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterPanel({required bool allowClassSelection}) {
    return Card(
      color: _cardColor,
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (allowClassSelection) ...[
              DropdownButtonFormField<String>(
                initialValue: _kelasDipilih,
                decoration: const InputDecoration(
                  labelText: 'Filter kelas',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem(value: '', child: Text('Semua kelas')),
                  ..._kelas.map(
                    (kelas) =>
                        DropdownMenuItem(value: kelas, child: Text(kelas)),
                  ),
                ].toList(),
                onChanged: (value) async {
                  if (value == null) return;
                  setState(() => _kelasDipilih = value);
                  await _muatData();
                },
              ),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                Icon(Icons.calendar_today, color: AppColors.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _tanggalLabel,
                    style: TextStyle(
                      color: _textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                OutlinedButton(
                  onPressed: _pilihTanggal,
                  child: const Text('Pilih tanggal'),
                ),
              ],
            ),
            if (_isPengisi) ...[
              const SizedBox(height: 6),
              Text(
                '$_kelasDipilih • ${_siswa.length} siswa',
                style: TextStyle(color: _mutedColor, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHistory() {
    final filtered = _riwayat;

    return Column(
      children: [
        _buildFilterPanel(allowClassSelection: _isAdmin),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    'Belum ada riwayat presensi.',
                    style: TextStyle(color: _mutedColor),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final row = filtered[index];
                    final status = row['status']?.toString() ?? '-';
                    return Card(
                      color: _cardColor,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
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
                        subtitle: Text(
                          '${row['tanggal'] ?? '-'} • ${row['kelas'] ?? '-'}'
                          '${row['catatan'] == null || row['catatan'].toString().isEmpty ? '' : '\nCatatan: ${row['catatan']}'}',
                          style: TextStyle(color: _mutedColor),
                        ),
                        isThreeLine:
                            row['catatan'] != null &&
                            row['catatan'].toString().isNotEmpty,
                        trailing: Text(
                          status,
                          style: TextStyle(
                            color: _warnaStatus(status),
                            fontWeight: FontWeight.bold,
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
