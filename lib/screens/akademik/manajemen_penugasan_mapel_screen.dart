import 'package:flutter/material.dart';
import 'package:aplikasi_sekolah/core/constants/app_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ManajemenPenugasanMapelScreen extends StatefulWidget {
  const ManajemenPenugasanMapelScreen({super.key});

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
  bool _isLoadingGuru = false;
  bool _isSaving = false;
  String? _error;
  int _teacherLoadRequest = 0;

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

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await Supabase.instance.client.rpc(
        'get_admin_assignment_data',
        params: {'p_kelas_id': _kelasId},
      );
      if (response is! Map ||
          response['kelas'] is! List ||
          response['mata_pelajaran'] is! List ||
          response['guru'] is! List ||
          response['penugasan'] is! List) {
        throw const FormatException('Data referensi penugasan tidak lengkap.');
      }
      if (!mounted) return;
      setState(() {
        _kelas = _maps(response['kelas']);
        _mapel = _maps(response['mata_pelajaran']);
        _guru = _maps(response['guru']);
        _penugasan = _maps(response['penugasan']);
        _error = null;
      });
    } on PostgrestException catch (error) {
      if (mounted) {
        setState(
          () => _error = 'Gagal memuat data penugasan: ${error.message}',
        );
      }
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
    final requestId = ++_teacherLoadRequest;
    setState(() {
      _guru = [];
      _guruId = null;
      _isLoadingGuru = classId != null;
    });
    if (classId == null) {
      if (mounted) setState(() => _isLoadingGuru = false);
      return;
    }
    try {
      final response = await Supabase.instance.client.rpc(
        'get_admin_assignment_data',
        params: {'p_kelas_id': classId},
      );
      if (response is! Map || response['guru'] is! List) {
        throw const FormatException('Daftar guru kelas tidak valid.');
      }
      final teachers = _maps(response['guru']).where((teacher) {
        final jenisGuru = teacher['jenis_guru']?.toString();
        if (jenisGuru == 'guru_mapel') return true;
        if (jenisGuru != 'guru_kelas') return false;
        return int.tryParse(teacher['kelas_id'].toString()) == classId;
      }).toList();
      if (mounted && requestId == _teacherLoadRequest && _kelasId == classId) {
        setState(() => _guru = teachers);
      }
    } on PostgrestException catch (error) {
      if (mounted && requestId == _teacherLoadRequest) {
        _showMessage('Gagal memuat guru kelas: ${error.message}', error: true);
      }
    } catch (e) {
      if (mounted && requestId == _teacherLoadRequest) {
        _showMessage('Gagal memuat guru kelas: $e', error: true);
      }
    } finally {
      if (mounted && requestId == _teacherLoadRequest) {
        setState(() => _isLoadingGuru = false);
      }
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
      final response = await Supabase.instance.client.rpc(
        'admin_create_class_subject_assignment',
        params: {
          'p_kelas_id': _kelasId,
          'p_mata_pelajaran_id': _mapelId,
          'p_guru_id': _guruId,
          'p_tahun_ajaran': _tahunAjaranController.text.trim(),
        },
      );
      if (response is! Map || response['status'] != 'success') {
        throw const FormatException(
          'Respons penyimpanan penugasan tidak valid.',
        );
      }
      if (!mounted) return;
      setState(() {
        _kelasId = null;
        _mapelId = null;
        _guruId = null;
      });
      _showMessage(response['message']?.toString() ?? 'Penugasan disimpan.');
      await _loadData();
    } on PostgrestException catch (error) {
      if (!mounted) return;
      final message = error.code == '23505'
          ? 'Penugasan kelas dan mata pelajaran untuk tahun ajaran tersebut sudah ada.'
          : error.message;
      _showMessage('Gagal menyimpan penugasan: $message', error: true);
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
                            hint: Text(
                              _isLoadingGuru
                                  ? 'Memuat guru...'
                                  : _kelasId == null
                                  ? 'Pilih kelas terlebih dahulu'
                                  : 'Tidak ada guru',
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
                            onChanged: _isLoadingGuru || _guru.isEmpty
                                ? null
                                : (value) => setState(() => _guruId = value),
                            validator: (value) =>
                                value == null ? 'Pilih guru pengampu' : null,
                          ),
                          if (_kelasId != null &&
                              !_isLoadingGuru &&
                              _guru.isEmpty)
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text(
                                'Tidak ada guru.',
                                style: TextStyle(color: Colors.red),
                              ),
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
                            onPressed:
                                _isSaving ||
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
