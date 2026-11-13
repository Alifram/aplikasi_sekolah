import 'package:flutter/material.dart';
import 'package:aplikasi_sekolah/core/constants/app_colors.dart';
import 'package:aplikasi_sekolah/core/services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _identifierController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  // LOGIKA BARU: UI murni hanya memicu panggilan ke AuthService
  Future<void> _prosesLogin() async {
    final String identifier = _identifierController.text.trim();
    final String password = _passwordController.text;

    if (identifier.isEmpty || password.isEmpty) {
      _tampilkanPesanError("Nomor Induk / Email dan Password tidak boleh kosong.");
      return;
    }

    setState(() => _isLoading = true);

    final res = await AuthService.login(identifier, password);

    if (res['status'] == 'success') {
      final String namaLengkap = res['user']['nama_lengkap'] ?? 'Pengguna';

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Selamat datang kembali, $namaLengkap!'),
          backgroundColor: AppColors.primary,
        ),
      );

      _navigasiBerdasarkanRole(res['user']);
    } else {
      _tampilkanPesanError(res['message'] ?? 'Kombinasi login salah.');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _navigasiBerdasarkanRole(Map<String, dynamic> dataUser) {
    Navigator.pushReplacementNamed(
      context, 
      '/dashboard', 
      arguments: dataUser,
    );
  }

  void _tampilkanPesanError(String pesan) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(pesan), backgroundColor: Colors.red.shade700),
    );
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color warnaTeksUtama = isDark ? Colors.white : Colors.black87;
    final Color warnaTeksSub = isDark ? Colors.white70 : Colors.grey;
    final Color warnaIkon = isDark ? Colors.amber.shade300 : AppColors.primary;
    final Color warnaAksen = isDark ? Colors.green.shade400 : AppColors.primary;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 50.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  height: 112,
                  width: 112,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark
                          ? Colors.amber.shade300
                          : AppColors.primary.withValues(alpha: 0.15),
                      width: isDark ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.3)
                            : AppColors.primary.withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Image.asset(
                      'assets/logo_mim.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.school,
                        size: 56,
                        color: warnaIkon,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),

              Text(
                'Portal Academic',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: warnaTeksUtama,
                ),
              ),
              Text(
                'Silakan masuk ke akun MIM Pasir Lor Anda',
                style: TextStyle(fontSize: 14, color: warnaTeksSub),
              ),
              const SizedBox(height: 35),

              TextField(
                controller: _identifierController,
                decoration: InputDecoration(
                  labelText: 'Nomor Induk (NIS/NIP) atau Email',
                  prefixIcon: Icon(Icons.person_outline, color: warnaIkon),
                  labelStyle: TextStyle(color: warnaTeksSub),
                  hintStyle: TextStyle(color: warnaTeksSub),
                  filled: isDark,
                  fillColor: isDark ? const Color(0xFF202C33) : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: warnaAksen,
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Input Kata Sandi
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock_outline, color: warnaIkon),
                  labelStyle: TextStyle(color: warnaTeksSub),
                  filled: isDark,
                  fillColor: isDark ? const Color(0xFF202C33) : null,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: warnaIkon,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: warnaAksen,
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 35),

              // Tombol Proses Masuk Utama
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: warnaAksen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isLoading ? null : _prosesLogin,
                  child: _isLoading
                      ? const Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                        )
                      : const Text(
                          'MASUK',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
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
