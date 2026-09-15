import 'package:flutter/material.dart';
import 'package:aplikasi_sekolah/core/constants/app_colors.dart';
import 'package:aplikasi_sekolah/core/services/auth_service.dart';

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
  final TextEditingController _kelasController = TextEditingController(); // Digunakan manual untuk akun Guru

  String _selectedRole = 'siswa'; 
  bool _isLoading = false;

  // ===========================================================================
  // WIDGET STATE BARU: Pilihan awal Dropdown penempatan khusus Akun Siswa
  // ===========================================================================
  String _selectedKelasSiswa = 'Kelas 1';
  String _selectedAngkatanSiswa = DateTime.now().year.toString();

  final List<String> _daftarKelasOpsi = [
    'Kelas 1',
    'Kelas 2',
    'Kelas 3',
    'Kelas 4',
    'Kelas 5',
    'Kelas 6',
  ];

  List<String> get _daftarTahunAngkatanOpsi {
    int tahunSekarang = DateTime.now().year;
    List<String> listTahun = [];
    for (int i = 2023; i <= tahunSekarang; i++) {
      listTahun.add(i.toString());
    }
    return listTahun;
  }

  @override
  void initState() {
    super.initState();
    if (widget.pembuatRole == 'guru') {
      _selectedRole = 'siswa';
    }
  }

  void _bersihkanFormulir() {
    _nomorIndukController.clear();
    _namaLengkapController.clear();
    _emailController.clear();
    _passwordController.clear();
    _kelasController.clear();
    setState(() {
      _selectedKelasSiswa = 'Kelas 1';
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
      "kelas_diajar": _selectedRole == 'siswa' ? _selectedKelasSiswa.trim() : _kelasController.text.trim(),
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

              // 1. INPUT NOMOR INDUK (NIS / NIP)
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

              // 2. INPUT NAMA LENGKAP
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

              // 3. INPUT EMAIL
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

              if (_selectedRole == 'siswa') ...[
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedKelasSiswa,
                        decoration: InputDecoration(
                          labelText: 'Tingkat Kelas',
                          prefixIcon: const Icon(Icons.school_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: _daftarKelasOpsi.map((String k) {
                          return DropdownMenuItem<String>(value: k, child: Text(k));
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedKelasSiswa = value!;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Dropdown Tahun Angkatan Masuk
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
                ),
                const SizedBox(height: 20),
              ],

              // 4. INPUT PASSWORD ACUAN AWAL
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

              // 5. INPUT KELAS GURU (HANYA MUNCUL JIKA PILIH GURU KELAS)
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

              // 6. TOMBOL SUBMIT PENDAFTARAN AKUN
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
