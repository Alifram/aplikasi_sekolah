import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:aplikasi_sekolah/core/constants/app_colors.dart';
import 'package:aplikasi_sekolah/core/services/api_config.dart';

class ManajemenMataPelajaranScreen extends StatefulWidget {
  final String userId;

  const ManajemenMataPelajaranScreen({
    super.key,
    required this.userId,
  });

  @override
  State<ManajemenMataPelajaranScreen> createState() =>
      _ManajemenMataPelajaranScreenState();
}

class _ManajemenMataPelajaranScreenState
    extends State<ManajemenMataPelajaranScreen> {
  final _formKey = GlobalKey<FormState>();
  final _kodeController = TextEditingController();
  final _namaController = TextEditingController();
  List<Map<String, dynamic>> _mataPelajaran = [];
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _muatMataPelajaran();
  }

  @override
  void dispose() {
    _kodeController.dispose();
    _namaController.dispose();
    super.dispose();
  }

  Future<void> _muatMataPelajaran() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final uri = Uri.parse(
        '${ApiConfig.baseUrl}/get_referensi_penugasan.php',
      ).replace(queryParameters: {'user_id': widget.userId});
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic> ||
          response.statusCode < 200 ||
          response.statusCode >= 300 ||
          decoded['status'] != 'success' ||
          decoded['data'] is! Map ||
          decoded['data']['mata_pelajaran'] is! List) {
        throw Exception(
          decoded is Map
              ? decoded['message'] ?? 'Respons daftar mata pelajaran tidak valid.'
              : 'Respons daftar mata pelajaran tidak valid.',
        );
      }
      if (!mounted) return;
      setState(() {
        _mataPelajaran = (decoded['data']['mata_pelajaran'] as List)
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      });
    } catch (error) {
      if (mounted) setState(() => _error = 'Gagal memuat mata pelajaran: $error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _simpanMataPelajaran() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/save_mata_pelajaran.php'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'user_id': widget.userId,
              'kode': _kodeController.text.trim(),
              'nama': _namaController.text.trim(),
            }),
          )
          .timeout(const Duration(seconds: 15));
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic> ||
          response.statusCode < 200 ||
          response.statusCode >= 300 ||
          decoded['status'] != 'success') {
        throw Exception(
          decoded is Map
              ? decoded['message'] ?? 'Gagal menyimpan mata pelajaran.'
              : 'Respons server tidak valid.',
        );
      }
      _kodeController.clear();
      _namaController.clear();
      _tampilkanPesan(decoded['message']?.toString() ?? 'Mata pelajaran disimpan.');
      await _muatMataPelajaran();
    } catch (error) {
      if (mounted) {
        _tampilkanPesan('Gagal menyimpan mata pelajaran: $error', error: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
      appBar: AppBar(
        title: const Text('Mata Pelajaran'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _isLoading ? null : _muatMataPelajaran,
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
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _muatMataPelajaran,
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
                                'Tambah mata pelajaran',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _kodeController,
                                maxLength: 30,
                                textCapitalization:
                                    TextCapitalization.characters,
                                decoration: const InputDecoration(
                                  labelText: 'Kode mapel',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) =>
                                    value == null || value.trim().isEmpty
                                        ? 'Kode mapel wajib diisi.'
                                        : null,
                              ),
                              TextFormField(
                                controller: _namaController,
                                maxLength: 100,
                                decoration: const InputDecoration(
                                  labelText: 'Nama mata pelajaran',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) =>
                                    value == null || value.trim().isEmpty
                                        ? 'Nama mata pelajaran wajib diisi.'
                                        : null,
                              ),
                              const SizedBox(height: 8),
                              FilledButton.icon(
                                onPressed: _isSaving
                                    ? null
                                    : _simpanMataPelajaran,
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
                                label: Text(
                                  _isSaving
                                      ? 'Menyimpan...'
                                      : 'Simpan mata pelajaran',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Mata pelajaran aktif',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    if (_mataPelajaran.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('Belum ada mata pelajaran aktif.'),
                        ),
                      )
                    else
                      ..._mataPelajaran.map(
                        (item) => Card(
                          child: ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.menu_book_outlined),
                            ),
                            title: Text(item['nama']?.toString() ?? '-'),
                            subtitle: Text('Kode: ${item['kode'] ?? '-'}'),
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }
}
