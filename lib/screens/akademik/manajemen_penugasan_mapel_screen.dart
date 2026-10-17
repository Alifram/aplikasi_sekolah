import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:aplikasi_sekolah/core/constants/app_colors.dart';
import 'package:aplikasi_sekolah/core/services/api_config.dart';

class ManajemenPenugasanMapelScreen extends StatefulWidget {
  final String userId;

  const ManajemenPenugasanMapelScreen({super.key, required this.userId});

  @override
  State<ManajemenPenugasanMapelScreen> createState() =>
      _ManajemenPenugasanMapelScreenState();
}

class _ManajemenPenugasanMapelScreenState
    extends State<ManajemenPenugasanMapelScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tahunAjaranController = TextEditingController();
  List<Map<String, dynamic>> _kelas = [];
  List<Map<String, dynamic>> _mapel = [];
  List<Map<String, dynamic>> _guru = [];
  List<Map<String, dynamic>> _penugasan = [];
  int? _kelasId;
  int? _mapelId;
  int? _guruId;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final startYear = now.month >= 7 ? now.year : now.year - 1;
    _tahunAjaranController.text = '$startYear/${startYear + 1}';
    _loadData();
  }

  @override
  void dispose() {
    _tahunAjaranController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Respons server tidak valid.');
    }
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded['status'] != 'success') {
      throw Exception(decoded['message'] ?? 'Permintaan gagal.');
    }
    return decoded;
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final referenceQuery = <String, String>{'user_id': widget.userId};
      if (_kelasId != null) referenceQuery['kelas_id'] = _kelasId.toString();
      final referenceUri = Uri.parse(
        '${ApiConfig.baseUrl}/get_referensi_penugasan.php',
      ).replace(queryParameters: referenceQuery);
      final assignmentUri = Uri.parse(
        '${ApiConfig.baseUrl}/get_kelas_mapel.php',
      );
      final responses = await Future.wait([
        _getJson(referenceUri),
        _getJson(assignmentUri),
      ]);
      final referenceData = responses[0]['data'];
      final assignmentData = responses[1]['data'];
      if (referenceData is! Map ||
          referenceData['kelas'] is! List ||
          referenceData['mata_pelajaran'] is! List ||
          referenceData['guru'] is! List ||
          assignmentData is! List) {
        throw const FormatException('Data referensi penugasan tidak lengkap.');
      }
      if (!mounted) return;
      setState(() {
        _kelas = _maps(referenceData['kelas']);
        _mapel = _maps(referenceData['mata_pelajaran']);
        _guru = _maps(referenceData['guru']);
        _penugasan = _maps(assignmentData);
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Gagal memuat data penugasan: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _maps(dynamic raw) => (raw as List)
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();

  Future<void> _loadTeachersForClass(int? classId) async {
    setState(() {
      _guru = [];
      _guruId = null;
    });
    if (classId == null) return;
    try {
      final uri = Uri.parse(
        '${ApiConfig.baseUrl}/get_referensi_penugasan.php',
      ).replace(queryParameters: {
        'user_id': widget.userId,
        'kelas_id': classId.toString(),
      });
      final response = await _getJson(uri);
      final data = response['data'];
      if (data is! Map || data['guru'] is! List) {
        throw const FormatException('Daftar guru kelas tidak valid.');
      }
      if (mounted) setState(() => _guru = _maps(data['guru']));
    } catch (e) {
      if (mounted) _showMessage('Gagal memuat guru kelas: $e', error: true);
    }
  }

  Future<void> _saveAssignment() async {
    if (!_formKey.currentState!.validate()) return;
    if (_kelasId == null || _mapelId == null || _guruId == null) {
      _showMessage('Pilih kelas, mata pelajaran, dan guru.', error: true);
      return;
    }
    setState(() => _isSaving = true);
    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/save_kelas_mapel.php'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'user_id': widget.userId,
              'kelas_id': _kelasId,
              'mata_pelajaran_id': _mapelId,
              'guru_id': _guruId,
              'tahun_ajaran': _tahunAjaranController.text.trim(),
            }),
          )
          .timeout(const Duration(seconds: 15));
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Respons server tidak valid.');
      }
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          decoded['status'] != 'success') {
        throw Exception(decoded['message'] ?? 'Gagal menyimpan penugasan.');
      }
      if (!mounted) return;
      setState(() {
        _kelasId = null;
        _mapelId = null;
        _guruId = null;
      });
      _showMessage(decoded['message']?.toString() ?? 'Penugasan disimpan.');
      await _loadData();
    } catch (e) {
      if (mounted) _showMessage('Gagal menyimpan penugasan: $e', error: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showMessage(String message, {bool error = false}) {
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
      appBar: AppBar(
        title: const Text('Penugasan Mapel'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _isLoading ? null : _loadData,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.info_outline, size: 42),
                    const SizedBox(height: 12),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _loadData,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Coba lagi'),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Tambah penugasan',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          if (_kelas.isEmpty)
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text(
                                'Belum ada kelas aktif. Tambahkan kelas terlebih dahulu untuk membuat penugasan.',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<int>(
                            value: _kelasId,
                            decoration: const InputDecoration(
                              labelText: 'Kelas',
                              border: OutlineInputBorder(),
                            ),
                            items: _kelas
                                .map(
                                  (item) => DropdownMenuItem<int>(
                                    value: int.parse(item['id'].toString()),
                                    child: Text(item['nama'].toString()),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                _kelasId = value;
                                _guru = [];
                                _guruId = null;
                              });
                              _loadTeachersForClass(value);
                            },
                            validator: (value) =>
                                value == null ? 'Pilih kelas' : null,
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<int>(
                            value: _mapelId,
                            decoration: const InputDecoration(
                              labelText: 'Mata pelajaran',
                              border: OutlineInputBorder(),
                            ),
                            items: _mapel
                                .map(
                                  (item) => DropdownMenuItem<int>(
                                    value: int.parse(item['id'].toString()),
                                    child: Text(item['nama'].toString()),
                                  ),
                                )
                                .toList(),
                            onChanged: _mapel.isEmpty
                                ? null
                                : (value) => setState(() => _mapelId = value),
                            validator: (value) =>
                                value == null ? 'Pilih mata pelajaran' : null,
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<int>(
                            value: _guruId,
                            decoration: const InputDecoration(
                              labelText: 'Guru pengampu',
                              border: OutlineInputBorder(),
                            ),
                            items: _guru
                                .map(
                                  (item) => DropdownMenuItem<int>(
                                    value: int.parse(item['id'].toString()),
                                    child: Text(
                                      item['nama_lengkap'].toString(),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: _guru.isEmpty
                                ? null
                                : (value) => setState(() => _guruId = value),
                            validator: (value) =>
                                value == null ? 'Pilih guru pengampu' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _tahunAjaranController,
                            decoration: const InputDecoration(
                              labelText: 'Tahun ajaran',
                              hintText: 'Contoh: 2026/2027',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null ||
                                  !RegExp(
                                    r'^\d{4}/\d{4}$',
                                  ).hasMatch(value.trim())) {
                                return 'Gunakan format YYYY/YYYY, misalnya 2026/2027';
                              }
                              final years = value.split('/');
                              if (int.parse(years[1]) !=
                                  int.parse(years[0]) + 1) {
                                return 'Tahun akhir harus satu tahun setelah tahun awal';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _isSaving ||
                                    _kelas.isEmpty ||
                                    _mapel.isEmpty ||
                                    _guru.isEmpty
                                ? null
                                : _saveAssignment,
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.add),
                            label: const Text('Simpan penugasan'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Penugasan aktif',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (_penugasan.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Belum ada penugasan. Tambahkan satu di atas.',
                      ),
                    ),
                  )
                else
                  ..._penugasan.map(
                    (item) => Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.menu_book_outlined),
                        ),
                        title: Text(
                          '${item['kelas']} • ${item['mata_pelajaran']}',
                        ),
                        subtitle: Text(
                          '${item['guru_pengampu']} • ${item['tahun_ajaran']}',
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
