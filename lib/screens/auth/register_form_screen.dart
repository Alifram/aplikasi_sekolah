import 'package:flutter/material.dart';
import 'package:aplikasi_sekolah/core/constants/app_colors.dart';
import 'package:aplikasi_sekolah/core/services/auth_service.dart';
import 'package:aplikasi_sekolah/core/services/admin_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aplikasi_sekolah/core/services/app_error_message.dart';

class RegisterFormScreen extends StatefulWidget {
  final String pembuatRole;
  final Future<void> Function()? onRegistrationSuccess;

  const RegisterFormScreen({
    super.key,
    required this.pembuatRole,
    this.onRegistrationSuccess,
  });

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
  String? _selectedJenisGuru;
  bool _isLoading = false;
  bool _isLoadingKelas = true;
  String? _kelasError;
  List<Map<String, dynamic>> _kelas = [];
  bool _isLoadingSiswa = false;
  String? _siswaError;
  List<Map<String, dynamic>> _siswa = [];
  final Set<int> _selectedStudentIds = {};
  final Set<String> _selectedPaymentCategories = {};

  static const _paymentCategories = {
    'infaq': 'Infaq',
    'wakaf': 'Wakaf',
    'buku': 'Buku',
    'pramuka': 'Pramuka',
    'hw': 'HW',
    'koperasi': 'Koperasi',
  };

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
    if (widget.pembuatRole == 'admin') _muatSiswa();
  }

  @override
  void dispose() {
    _nomorIndukController.dispose();
    _namaLengkapController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _muatKelas() async {
    try {
      final rows = await Supabase.instance.client
          .from('kelas')
          .select('id, nama')
          .eq('aktif', true)
          .order('nama');
      if (!mounted) return;
      setState(() {
        _kelas = (rows as List)
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        _selectedKelasId = _kelas.isEmpty
            ? null
            : int.tryParse(_kelas.first['id'].toString());
        _kelasError = _kelas.isEmpty ? 'Belum ada kelas aktif.' : null;
      });
    } on PostgrestException catch (error) {
      if (mounted) {
        setState(
          () => _kelasError = AppErrorMessage.fromPostgrest(
            error,
            fallback: 'Daftar kelas belum dapat dimuat. Silakan coba lagi.',
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _kelasError = AppErrorMessage.from(
            e,
            fallback: 'Daftar kelas belum dapat dimuat. Silakan coba lagi.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingKelas = false);
    }
  }

  Future<void> _muatSiswa() async {
    setState(() {
      _isLoadingSiswa = true;
      _siswaError = null;
    });
    final response = await AdminService.ambilSemuaPengguna();
    if (!mounted) return;
    if (response['status'] != 'success' || response['data'] is! List) {
      setState(() {
        _isLoadingSiswa = false;
        _siswaError =
            response['message']?.toString() ??
            'Daftar siswa belum dapat dimuat.';
      });
      return;
    }

    setState(() {
      _siswa = (response['data'] as List)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .where(
            (item) =>
                item['role'] == 'siswa' &&
                (int.tryParse(item['is_deleted']?.toString() ?? '0') ?? 0) == 0,
          )
          .toList();
      _isLoadingSiswa = false;
      if (_siswa.isEmpty) _siswaError = 'Belum ada siswa aktif.';
    });
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
      _selectedJenisGuru = null;
      _selectedStudentIds.clear();
      _selectedPaymentCategories.clear();
    });
  }

  void _tampilkanNotifikasi(String pesan, Color warna) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(pesan), backgroundColor: warna));
  }

  Future<void> _kirimDataPendaftaran() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRole == 'orang_tua' && _selectedStudentIds.isEmpty) {
      _tampilkanNotifikasi(
        'Pilih setidaknya satu anak untuk akun orang tua.',
        Colors.red,
      );
      return;
    }
    if (_selectedRole == 'petugas_keuangan' &&
        _selectedPaymentCategories.isEmpty) {
      _tampilkanNotifikasi(
        'Pilih setidaknya satu jenis pembayaran untuk petugas.',
        Colors.red,
      );
      return;
    }

    setState(() => _isLoading = true);

    final dataInput = {
      "nomor_induk": _nomorIndukController.text.trim(),
      "nama_lengkap": _namaLengkapController.text.trim(),
      "email": _emailController.text.trim(),
      "password": _passwordController.text,
      "role": _selectedRole,
      "jenis_guru": _selectedRole == 'guru' ? _selectedJenisGuru : null,
      "kelas_id":
          _selectedRole == 'siswa' ||
              (_selectedRole == 'guru' && _selectedJenisGuru == 'guru_kelas')
          ? _selectedKelasId
          : null,
      "tahun_angkatan": _selectedRole == 'siswa'
          ? int.tryParse(_selectedAngkatanSiswa)
          : null,
    };

    final res = await AuthService.register(dataInput);

    if (!mounted) return;

    if (res['status'] == 'success') {
      var message =
          res['message']?.toString() ?? 'Pendaftaran akun berhasil disimpan!';
      var messageColor = AppColors.primary;
      if (_selectedRole == 'orang_tua' || _selectedRole == 'petugas_keuangan') {
        final userId = int.tryParse(res['profile_id']?.toString() ?? '');
        if (userId == null) {
          message =
              'Akun berhasil dibuat, tetapi ID profil tidak tersedia. '
              'Periksa akun sebelum mencoba mendaftarkannya kembali.';
          messageColor = Colors.orange.shade800;
        } else {
          final setup = await AdminService.konfigurasiAkunPembayaran(
            userId: userId,
            studentUserIds: _selectedRole == 'orang_tua'
                ? _selectedStudentIds.toList()
                : const [],
            categoryCodes: _selectedRole == 'petugas_keuangan'
                ? _selectedPaymentCategories.toList()
                : const [],
          );
          if (setup['status'] != 'success') {
            message =
                'Akun berhasil dibuat, tetapi pengaturan akses belum selesai: '
                '${setup['message'] ?? 'hubungi admin sistem.'}';
            messageColor = Colors.orange.shade800;
          }
        }
      }
      _tampilkanNotifikasi(message, messageColor);
      if (_selectedRole == 'siswa') await _muatSiswa();
      _bersihkanFormulir();
      await widget.onRegistrationSuccess?.call();
    } else {
      _tampilkanNotifikasi(
        res['message'] ?? 'Pendaftaran akun gagal dilakukan.',
        Colors.red,
      );
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Color warnaLatarLayar = isDark
        ? const Color(0xFF0B141A)
        : Colors.white;
    final Color warnaTeksUtama = isDark
        ? Colors.amber.shade300
        : AppColors.primary;
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
                    DropdownMenuItem(value: 'siswa', child: Text('Siswa')),
                    DropdownMenuItem(value: 'guru', child: Text('Guru')),
                    DropdownMenuItem(
                      value: 'orang_tua',
                      child: Text('Orang Tua'),
                    ),
                    DropdownMenuItem(
                      value: 'petugas_keuangan',
                      child: Text('Petugas Keuangan'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedRole = value!;
                      _selectedJenisGuru = null;
                      _selectedStudentIds.clear();
                      _selectedPaymentCategories.clear();
                    });
                  },
                ),
                const SizedBox(height: 20),
              ],

              if (_selectedRole == 'guru') ...[
                DropdownButtonFormField<String>(
                  initialValue: _selectedJenisGuru,
                  decoration: InputDecoration(
                    labelText: 'Jenis Guru',
                    prefixIcon: const Icon(Icons.work_outline_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'guru_kelas',
                      child: Text('Guru Kelas'),
                    ),
                    DropdownMenuItem(
                      value: 'guru_mapel',
                      child: Text('Guru Mata Pelajaran'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => _selectedJenisGuru = value);
                  },
                  validator: (value) =>
                      value == null ? 'Pilih jenis guru' : null,
                ),
                const SizedBox(height: 20),
              ],

              TextFormField(
                controller: _nomorIndukController,
                decoration: InputDecoration(
                  labelText: switch (_selectedRole) {
                    'guru' => 'NIP (Nomor Induk Pegawai)',
                    'siswa' => 'NIS (Nomor Induk Siswa)',
                    'orang_tua' => 'Nomor Identitas Orang Tua',
                    _ => 'Nomor Identitas Petugas',
                  },
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

              if (_selectedRole == 'orang_tua') ...[
                Text(
                  'Anak yang dapat dilihat',
                  style: TextStyle(
                    color: warnaTeksUtama,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (_isLoadingSiswa) const LinearProgressIndicator(),
                if (_siswaError != null)
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _siswaError!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                      TextButton(
                        onPressed: _isLoadingSiswa ? null : _muatSiswa,
                        child: const Text('Muat ulang'),
                      ),
                    ],
                  ),
                ..._siswa.map((student) {
                  final id = int.tryParse(student['id']?.toString() ?? '');
                  if (id == null) return const SizedBox.shrink();
                  final className = student['kelas_nama']?.toString() ?? '';
                  return CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _selectedStudentIds.contains(id),
                    title: Text(student['nama_lengkap']?.toString() ?? '-'),
                    subtitle: className.isEmpty ? null : Text(className),
                    onChanged: (selected) {
                      setState(() {
                        if (selected == true) {
                          _selectedStudentIds.add(id);
                        } else {
                          _selectedStudentIds.remove(id);
                        }
                      });
                    },
                  );
                }),
                const SizedBox(height: 12),
              ],

              if (_selectedRole == 'petugas_keuangan') ...[
                Text(
                  'Jenis pembayaran yang boleh dikelola',
                  style: TextStyle(
                    color: warnaTeksUtama,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: _paymentCategories.entries
                      .map(
                        (category) => FilterChip(
                          label: Text(category.value),
                          selected: _selectedPaymentCategories.contains(
                            category.key,
                          ),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedPaymentCategories.add(category.key);
                              } else {
                                _selectedPaymentCategories.remove(category.key);
                              }
                            });
                          },
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 12),
              ],

              if (_selectedRole == 'siswa' ||
                  (_selectedRole == 'guru' &&
                      _selectedJenisGuru == 'guru_kelas')) ...[
                Column(
                  children: [
                    DropdownButtonFormField<int>(
                      value: _selectedKelasId,
                      isExpanded: true,
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
                      validator: (value) =>
                          value == null ? 'Pilih kelas' : null,
                    ),
                    if (_selectedRole == 'siswa') ...[
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedAngkatanSiswa,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Tahun Angkatan',
                          prefixIcon: const Icon(Icons.calendar_month_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: _daftarTahunAngkatanOpsi.map((String t) {
                          return DropdownMenuItem<String>(
                            value: t,
                            child: Text('Angkatan $t'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedAngkatanSiswa = value!;
                          });
                        },
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
                    child: Text(
                      _kelasError!,
                      style: const TextStyle(color: Colors.red),
                    ),
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
