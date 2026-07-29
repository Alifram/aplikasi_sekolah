import 'package:flutter/material.dart';
import 'package:aplikasi_sekolah/core/constants/app_colors.dart';
import 'package:aplikasi_sekolah/core/services/auth_service.dart'; // <-- IMPORT SERVICE BARU

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
  final TextEditingController _kelasController = TextEditingController();

  String _selectedRole = 'siswa'; 
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.pembuatRole == 'guru') {
      _selectedRole = 'siswa';
    }
  }

  // LOGIKA BARU: UI murni mengirimkan paket data ke AuthService
  Future<void> _kirimDataPendaftaran() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final dataInput = {
      "nomor_induk": _nomorIndukController.text.trim(),
      "nama_lengkap": _namaLengkapController.text.trim(),
      "email": _emailController.text.trim(),
      "password": _passwordController.text.trim(),
      "role": _selectedRole,
      "kelas_diajar": _selectedRole == 'guru' ? _kelasController.text.trim() : null,
    };

    final res = await AuthService.register(dataInput);

    if (!mounted) return; // Pengaman Context untuk TA

    if (res['status'] == 'success') {
      _tampilkanNotifikasi(res['message'] ?? 'Pendaftaran berhasil!', AppColors.primary);
      _bersihkanFormulir();
    } else {
      _tampilkanNotifikasi(res['message'] ?? 'Pendaftaran gagal.', Colors.red);
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _bersihkanFormulir() {
    _nomorIndukController.clear();
    _namaLengkapController.clear();
    _emailController.clear();
    _passwordController.clear();
    _kelasController.clear();
  }

  void _tampilkanNotifikasi(String pesan, Color warna) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(pesan), backgroundColor: warna),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Buat Akun Baru',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primary, // Tema Global
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Formulir Registrasi Internal',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary, // Tema Global
                ),
              ),
              const Text(
                'Daftarkan pengguna baru ke dalam sistem database sekolah',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),

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
              // INPUT EMAIL
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

              // INPUT PASSWORD BAWAAN
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

              // INPUT KHUSUS KELAS (Hanya muncul jika admin memilih membuat akun 'guru')
              if (_selectedRole == 'guru') ...[
                TextFormField(
                  controller: _kelasController,
                  decoration: InputDecoration(
                    labelText: 'Kelas Yang Diajar (Contoh: Kelas 3A)',
                    prefixIcon: const Icon(Icons.meeting_room_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) =>
                      _selectedRole == 'guru' && value!.isEmpty
                      ? 'Kelas wajib ditentukan'
                      : null,
                ),
                const SizedBox(height: 20),
              ],

              const SizedBox(height: 15),

              // TOMBOL SUBMIT SIMPAN DATA
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary, // Integrasi warna tema global
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
