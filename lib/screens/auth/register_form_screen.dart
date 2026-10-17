import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:aplikasi_sekolah/core/constants/app_colors.dart';
import 'package:aplikasi_sekolah/core/services/auth_service.dart';
import 'package:aplikasi_sekolah/core/services/api_config.dart';

class RegisterFormScreen extends StatefulWidget {
  final String pembuatRole; 

  const RegisterFormScreen({super.key, required this.pembuatRole});

  @override
  State<RegisterFormScreen> createState() => _RegisterFormScreenState();
}

class _RegisterFormScreenState extends State<RegisterFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nomorIndukController = TextEditingController();
  final TextEditingController _namaLengkapController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String _selectedRole = 'siswa'; 
  bool _isLoading = false;
  bool _isLoadingKelas = true;
  String? _kelasError;
  List<Map<String, dynamic>> _kelas = [];

  // ===========================================================================
  // WIDGET STATE BARU: Pilihan awal Dropdown penempatan khusus Akun Siswa
  // ===========================================================================
  int? _selectedKelasId;
  String _selectedAngkatanSiswa = DateTime.now().year.toString();

  List<String> get _daftarTahunAngkatanOpsi {
    int tahunSekarang = DateTime.now().year;
    List<String> opsi = [];
    for (int i = 2023; i <= tahunSekarang + 5; i++) {
      opsi.add(i.toString());
    }
    return opsi;
  }

  @override
  void initState() {
    super.initState();
    if (widget.pembuatRole == 'guru') {
      _selectedRole = 'siswa';
    }
    _muatKelas();
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
        throw Exception(
          decoded is Map ? decoded['message'] ?? 'Gagal memuat kelas.' : 'Respons kelas tidak valid.',
        );
      }
      if (!mounted) return;
      setState(() {
        _kelas = (decoded['data'] as List)
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        _selectedKelasId = _kelas.isEmpty
            ? null
            : int.tryParse(_kelas.first['id'].toString());
        _kelasError = _kelas.isEmpty ? 'Belum ada kelas aktif.' : null;
      });
    } catch (e) {
      if (mounted) setState(() => _kelasError = 'Gagal memuat kelas: $e');
    } finally {
      if (mounted) setState(() => _isLoadingKelas = false);
    }
  }

  void _bersihkanFormulir() {
    _nomorIndukController.clear();
    _namaLengkapController.clear();
    _emailController.clear();
    _passwordController.clear();
    setState(() {
      _selectedKelasId = _kelas.isEmpty
          ? null
          : int.tryParse(_kelas.first['id'].toString());
      _selectedAngkatanSiswa = DateTime.now().year.toString();
    });
  }

  void _tampilkanNotifikasi(String pesan, Color warna) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(pesan), backgroundColor: warna),
    );
  }
  Future<void> _kirimDataPendaftaran() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final dataInput = {
      "nomor_induk": _nomorIndukController.text.trim(),
      "nama_lengkap": _namaLengkapController.text.trim(),
      "email": _emailController.text.trim(),
      "password": _passwordController.text.trim(),
      "role": _selectedRole,
      "kelas_id": _selectedKelasId,
      "tahun_angkatan": _selectedRole == 'siswa' ? int.tryParse(_selectedAngkatanSiswa) : null,
    };

    final res = await AuthService.register(dataInput);

    if (!mounted) return;

    if (res['status'] == 'success') {
      _tampilkanNotifikasi(res['message'] ?? 'Pendaftaran akun berhasil disimpan!', AppColors.primary);
      _bersihkanFormulir();
    } else {
      _tampilkanNotifikasi(res['message'] ?? 'Pendaftaran akun gagal dilakukan.', Colors.red);
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    final Color warnaLatarLayar = isDark ? const Color(0xFF0B141A) : Colors.white;
    final Color warnaTeksUtama = isDark ? Colors.amber.shade300 : AppColors.primary;
    final Color warnaTeksSub = isDark ? Colors.white70 : Colors.black54;

    return Container(
      color: warnaLatarLayar,
      height: double.infinity,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Formulir Registrasi Internal',
                style: TextStyle(
                  fontSize: 20, 
                  fontWeight: FontWeight.bold, 
                  color: warnaTeksUtama,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Daftarkan pengguna baru ke dalam sistem database sekolah',
                style: TextStyle(color: warnaTeksSub, fontSize: 13),
              ),
              const SizedBox(height: 28),

              if (widget.pembuatRole == 'admin') ...[
                const Text(
                  'Jenis Akun Yang Dibuat:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedRole,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.people_outline),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'siswa',
                      child: Text('Siswa / Orang Tua'),
                    ),
                    DropdownMenuItem(value: 'guru', child: Text('Guru Kelas')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedRole = value!;
                    });
                  },
                ),
                const SizedBox(height: 20),
              ],

              TextFormField(
                controller: _nomorIndukController,
                decoration: InputDecoration(
                  labelText: _selectedRole == 'guru'
                      ? 'NIP (Nomor Induk Pegawai)'
                      : 'NIS (Nomor Induk Siswa)',
                  prefixIcon: const Icon(Icons.pin_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) =>
                    value!.isEmpty ? 'Bagian ini tidak boleh kosong' : null,
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _namaLengkapController,
                decoration: InputDecoration(
                  labelText: 'Nama Lengkap',
                  prefixIcon: const Icon(Icons.badge_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) =>
                    value!.isEmpty ? 'Nama lengkap wajib diisi' : null,
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Alamat Email',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) =>
                    value!.isEmpty ? 'Email wajib diisi' : null,
              ),
              const SizedBox(height: 20),

              if (_selectedRole == 'siswa' || _selectedRole == 'guru') ...[
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _selectedKelasId,
                        decoration: InputDecoration(
                          labelText: 'Kelas',
                          prefixIcon: const Icon(Icons.school_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: _kelas.map((kelas) {
                          return DropdownMenuItem<int>(
                            value: int.tryParse(kelas['id'].toString()),
                            child: Text(kelas['nama'].toString()),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedKelasId = value;
                          });
                        },
                        validator: (value) => value == null ? 'Pilih kelas' : null,
                      ),
                    ),
                    if (_selectedRole == 'siswa') ...[
                      const SizedBox(width: 16),
                      Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedAngkatanSiswa,
                        decoration: InputDecoration(
                          labelText: 'Tahun Angkatan',
                          prefixIcon: const Icon(Icons.calendar_month_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: _daftarTahunAngkatanOpsi.map((String t) {
                          return DropdownMenuItem<String>(value: t, child: Text('Angkatan $t'));
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedAngkatanSiswa = value!;
                          });
                        },
                      ),
                      ),
                    ],
                  ],
                ),
                if (_isLoadingKelas)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: LinearProgressIndicator(),
                  ),
                if (_kelasError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_kelasError!, style: const TextStyle(color: Colors.red)),
                  ),
                const SizedBox(height: 20),
              ],

              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Password Acuan Awal',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) =>
                    value!.length < 6 ? 'Password minimal 6 karakter' : null,
              ),
              const SizedBox(height: 20),

              const SizedBox(height: 15),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isLoading ? null : _kirimDataPendaftaran,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'SIMPAN & DAFTARKAN AKUN',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
