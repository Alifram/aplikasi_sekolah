import 'package:flutter/material.dart';
import 'package:aplikasi_sekolah/core/constants/app_colors.dart';
import 'package:aplikasi_sekolah/core/services/admin_service.dart';
import '../../core/services/api_service.dart';

class DetailUserScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String loginRole;
  
  // 🌟 SELIPKAN SATU BARIS BARU INI DI SINI:
  final bool statusTemaGelap; 

  const DetailUserScreen({
    super.key,
    required this.userData,
    required this.loginRole,
    required this.statusTemaGelap,
  });

  @override
  State<DetailUserScreen> createState() => _DetailUserScreenState();
}

class _DetailUserScreenState extends State<DetailUserScreen> {
  List<dynamic> _listNilai = [];
  bool _isLoading = true;
  String _pesanError = '';
  late String _currentKelas;
  late int _isDeletedStatus;

  @override
    @override
  void initState() {
    super.initState();
    _currentKelas = widget.userData['kelas_diajar'] ?? 'Belum Diatur';
    _isDeletedStatus = int.tryParse(widget.userData['is_deleted'].toString()) ?? 0; 
    _panggilDataNilai();
  }

  Future<void> _eksekusiHapusAkunPengguna() async {
    setState(() => _isLoading = true);
    try {
      // Mengirimkan paket data ID target ke server MySQL
      final res = await ApiService.hapusAkunUser(widget.userData['id'].toString());
      
      if (!mounted) return;
      
      if (res['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Akun berhasil dihapus dari sistem.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context); // Otomatis kembali ke halaman daftar siswa setelah sukses hapus
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Gagal menghapus akun.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint("Gagal mengeksekusi perintah hapus: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // DIALOG KONFIRMASI BAHAYA: Mencegah admin menekan tombol hapus secara tidak sengaja
  void _tampilkanDialogKonfirmasiHapus() {
    final bool isDark = widget.statusTemaGelap;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1C2D35) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: Colors.red, size: 26),
            SizedBox(width: 8),
            Text('Hapus Akun Permanen', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus akun ${widget.userData['nama_lengkap']}?\n\nTindakan ini tidak dapat dibatalkan dan akan membersihkan hak akses masuk sistem.',
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('BATAL', style: TextStyle(color: isDark ? Colors.white60 : Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () {
              Navigator.pop(ctx); // Tutup jendela dialog konfirmasi
              _eksekusiHapusAkunPengguna(); // Jalankan fungsi hapus di atas
            },
            child: const Text('YA, HAPUS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
  
  void _tampilkanDialogEditUserMasaDepan() {
    final user = widget.userData;
    final _formKeyEditGlobal = GlobalKey<FormState>();
    
    // Inisialisasi controller data riil dari database MySQL
    final TextEditingController _namaController = TextEditingController(text: user['nama_lengkap']);
    final TextEditingController _emailController = TextEditingController(text: user['email']);
    final TextEditingController _passBaruController = TextEditingController();
    
    String _kelasTerpilihDinamis = _currentKelas ?? user['kelas_diajar'] ?? 'Kelas 1';
    final bool isDark = widget.statusTemaGelap;
    
    // Palet Warna Kontras Tinggi Adaptif (WhatsApp Dark Mode style)
    final Color warnaLatarDialog = isDark ? const Color(0xFF1C2D35) : Colors.white;
    final Color warnaTeksUtama = isDark ? Colors.white : Colors.black87;
    final Color warnaTeksSub = isDark ? Colors.white70 : Colors.black54;
    final Color warnaInputBackground = isDark ? const Color(0xFF202C33) : Colors.grey.shade50;
    final Color warnaBorderActive = isDark ? Colors.amber.shade400 : AppColors.primary;
    final Color warnaIkonSeksi = isDark ? Colors.amber.shade400 : AppColors.primary;

    Future<void> _prosesKirimKeDatabase() async {
      final paketUpdateGlobal = {
        "id_user": user['id'].toString(),
        "nama_lengkap": _namaController.text.trim(),
        "email": _emailController.text.trim(),
        "kelas_diajar": _kelasTerpilihDinamis, 
        "password_baru": _passBaruController.text.trim(),
      };

      final res = await ApiService.perbaruiDataPengguna(paketUpdateGlobal);
      
      if (!mounted) return;
      Navigator.pop(context); // Tutup dialog utama edit informasi akun

      if (res['status'] == 'success') {
        setState(() {
          _currentKelas = _kelasTerpilihDinamis;
          user['nama_lengkap'] = _namaController.text.trim();
          user['email'] = _emailController.text.trim();
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(res['status'] == 'success' ? Icons.check_circle : Icons.error, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(child: Text(res['message'] ?? 'Proses selesai.')),
            ],
          ),
          backgroundColor: res['status'] == 'success' ? Colors.green : Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return AlertDialog(
              backgroundColor: warnaLatarDialog,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: isDark ? Colors.grey.shade700 : Colors.transparent, width: 1.5),
              ),
              title: Row(
                children: [
                  Icon(Icons.manage_accounts_rounded, color: warnaIkonSeksi, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Kelola Data Akun', style: TextStyle(fontWeight: FontWeight.bold, color: warnaTeksUtama, fontSize: 18)),
                        Text('Perbarui informasi internal tata usaha sekolah', style: TextStyle(color: warnaTeksSub, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: _formKeyEditGlobal,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 8),
                      // 1. INPUT FIELD NAMA LENGKAP
                      TextFormField(
                        controller: _namaController,
                        style: TextStyle(color: warnaTeksUtama),
                        decoration: InputDecoration(
                          labelText: 'Nama Lengkap Pengguna',
                          labelStyle: TextStyle(color: warnaTeksSub),
                          prefixIcon: Icon(Icons.person_outline_rounded, color: warnaIkonSeksi),
                          fillColor: warnaInputBackground,
                          filled: true,
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: warnaBorderActive, width: 2)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) => v!.isEmpty ? 'Nama tidak boleh kosong' : null,
                      ),
                      const SizedBox(height: 18),
                      // 2. INPUT FIELD EMAIL RESMI
                      TextFormField(
                        controller: _emailController,
                        style: TextStyle(color: warnaTeksUtama),
                        decoration: InputDecoration(
                          labelText: 'Alamat Email Akun',
                          labelStyle: TextStyle(color: warnaTeksSub),
                          prefixIcon: Icon(Icons.mail_outline_rounded, color: warnaIkonSeksi),
                          fillColor: warnaInputBackground,
                          filled: true,
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: warnaBorderActive, width: 2)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) => v!.isEmpty ? 'Email tidak boleh kosong' : null,
                      ),
                      const SizedBox(height: 18),
                      // 3. DROPDOWN PINDAH TINGKAT KELAS TERINTEGRASI
                      DropdownButtonFormField<String>(
                        value: _kelasTerpilihDinamis,
                        dropdownColor: warnaLatarDialog,
                        style: TextStyle(color: warnaTeksUtama, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          labelText: user['role'] == 'guru' ? 'Mengampu Tingkat Kelas' : 'Penempatan Kelas Siswa',
                          labelStyle: TextStyle(color: warnaTeksSub),
                          prefixIcon: Icon(Icons.school_outlined, color: warnaIkonSeksi),
                          fillColor: warnaInputBackground,
                          filled: true,
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: warnaBorderActive, width: 2)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        items: ['Kelas 1', 'Kelas 2', 'Kelas 3', 'Kelas 4', 'Kelas 5', 'Kelas 6'].map((k) => DropdownMenuItem(value: k, child: Text(k))).toList(),
                        onChanged: (v) => setModalState(() => _kelasTerpilihDinamis = v!),
                      ),
                      
                      // 🌟 4. FITUR TAMBAHAN: DROPDOWN TAHUN ANGKATAN (HANYA MUNCUL JIKA USER = SISWA)
                      if (user['role'] == 'siswa') ...[
                        const SizedBox(height: 18),
                        DropdownButtonFormField<String>(
                          value: (user['tahun_angkatan'] ?? '2026').toString(),
                          dropdownColor: warnaLatarDialog,
                          style: TextStyle(color: warnaTeksUtama, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            labelText: 'Tahun Angkatan Masuk Murid',
                            labelStyle: TextStyle(color: warnaTeksSub),
                            prefixIcon: Icon(Icons.date_range_rounded, color: warnaIkonSeksi),
                            fillColor: warnaInputBackground,
                            filled: true,
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: warnaBorderActive, width: 2)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          items: ['2024', '2025', '2026', '2027'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                          onChanged: (v) {
                            setModalState(() {
                              user['tahun_angkatan'] = int.tryParse(v!);
                            });
                          },
                        ),
                      ],
                      const SizedBox(height: 18),
                      
                      // 5. RESET PASSWORD BARU (OPSIONAL)
                      TextFormField(
                        controller: _passBaruController,
                        obscureText: true,
                        style: TextStyle(color: warnaTeksUtama),
                        decoration: InputDecoration(
                          labelText: 'Password Baru (Kosongkan jika tak diubah)',
                          labelStyle: TextStyle(color: warnaTeksSub),
                          hintText: 'Isi hanya jika ingin mereset sandi user',
                          hintStyle: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.grey),
                          prefixIcon: Icon(Icons.lock_reset_rounded, color: warnaIkonSeksi),
                          fillColor: warnaInputBackground,
                          filled: true,
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: warnaBorderActive, width: 2)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      
                      // 🌟 6. FITUR TAMBAHAN DANGER ZONE: TOMBOL HAPUS AKUN PERMANEN DARI APLIKASI
                      const SizedBox(height: 24),
                      const Divider(color: Colors.redAccent, thickness: 1),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 45,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red, width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            backgroundColor: Colors.red.withOpacity(0.05),
                          ),
                          icon: const Icon(Icons.delete_forever_rounded, color: Colors.red),
                          label: const Text(
                            'HAPUS AKUN PENGGUNA', 
                            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          onPressed: () {
                            Navigator.pop(context); // Tutup dialog edit utama terlebih dahulu
                            _tampilkanDialogKonfirmasiHapus(); // Panggil fungsi peringatan bahaya di Part 1
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('BATAL', style: TextStyle(color: isDark ? Colors.white60 : Colors.grey, fontWeight: FontWeight.bold)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    if (!_formKeyEditGlobal.currentState!.validate()) return;
                    
                    // VALIDASI KEAMANAN KETAT: Jika admin mereset password, interupsi dengan dialog konfirmasi
                    if (_passBaruController.text.trim().isNotEmpty) {
                      showDialog(
                        context: context,
                        builder: (BuildContext contextAlert) {
                          return AlertDialog(
                            backgroundColor: warnaLatarDialog,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            title: const Row(
                              children: [
                                Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 26),
                                SizedBox(width: 8),
                                Text('Konfirmasi Sandi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              ],
                            ),
                            content: Text(
                              'Anda akan mereset password untuk akun ini.\nApakah Anda yakin tindakan ini sudah benar?',
                              style: TextStyle(color: warnaTeksUtama, fontSize: 13),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(contextAlert),
                                child: Text('BATAL', style: TextStyle(color: warnaTeksSub)),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade700),
                                onPressed: () {
                                  Navigator.pop(contextAlert); // Tutup alert dialog konfirmasi
                                  _prosesKirimKeDatabase(); // Jalankan fungsi pengiriman database dari Part 1
                                },
                                child: const Text('YA, RESET', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          );
                        },
                      );
                    } else {
                      // Jika kolom password kosong (hanya edit nama/email biasa), langsung kirim ke server XAMPP
                      _prosesKirimKeDatabase();
                    }
                  },
                  child: const Text('SIMPAN PERUBAHAN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _konfirmasiUbahStatusAkses(BuildContext context) {
    final int targetStatus = _isDeletedStatus == 0 ? 1 : 0;
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(targetStatus == 1 ? 'Nonaktifkan Akses Akun?' : 'Aktifkan Kembali Akun?'),
        content: Text(
          targetStatus == 1
              ? 'Apakah Anda yakin ingin memblokir hak login akun ini?\n\n🔒 Seluruh histori nilai rapor tetap tersimpan aman di database sekolah.'
              : 'Apakah Anda yakin ingin membuka blokir akun ini?\n\n🔓 Orang tua murid akan bisa kembali login ke aplikasi untuk mencetak dokumen PDF rapor.'
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: targetStatus == 1 ? Colors.red : Colors.green.shade700,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isLoading = true);

              final res = await AdminService.ubahStatusAksesAkun(
                widget.userData['id'].toString(), 
                targetStatus
              );

              if (!mounted) return;
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(res['message'] ?? 'Proses selesai'),
                  backgroundColor: res['status'] == 'success' ? AppColors.primary : Colors.red,
                ),
              );

              if (res['status'] == 'success') {
                setState(() {
                  _isDeletedStatus = targetStatus; // Mengubah state UI secara real-time
                  _isLoading = false;
                });
              } else {
                setState(() => _isLoading = false);
              }
            },
            child: Text(targetStatus == 1 ? 'Ya, Blokir' : 'Ya, Aktifkan', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // LOGIKA BARU: Menjembatani panggilan data ke AdminService
  Future<void> _panggilDataNilai() async {
    final String userId = widget.userData['id'].toString();
    final String role = widget.userData['role'];

    final res = await AdminService.ambilDataNilai(userId, role);
    if (mounted) {
      setState(() {
        if (res['status'] == 'success') {
          _listNilai = res['data'] ?? [];
        } else {
          _pesanError = res['message'] ?? 'Gagal memuat rekam jejak nilai.';
        }
        _isLoading = false;
      });
    }
  }

  // LOGIKA BARU: Mengirim data kelas baru ke database MySQL via AdminService
  Future<void> _prosesPindahKelas(String kelasBaru) async {
    final String userId = widget.userData['id'].toString();

    final res = await AdminService.prosesPindahKelas(userId, kelasBaru);
    
    if (!mounted) return; // Pengaman context untuk TA

    if (res['status'] == 'success') {
      setState(() {
        _currentKelas = kelasBaru;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Kelas berhasil diperbarui'),
          backgroundColor: AppColors.primary,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Gagal memperbarui kelas'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.userData;
    final bool isDark = widget.statusTemaGelap;
    final Color warnaLatarLayar = isDark ? const Color(0xFF0B141A) : Colors.white;
    final Color warnaKotakKartu = isDark ? const Color(0xFF1C2D35) : Colors.white;
    final Color warnaBorderKartu = isDark ? Colors.grey.shade700 : Colors.grey.shade200;
    final Color warnaTeksUtama = isDark ? Colors.white : Colors.black87;
    final Color warnaTeksSub = isDark ? Colors.white70 : Colors.black54;
    final Color warnaJudulSeksi = isDark ? Colors.amber.shade300 : AppColors.primary;
    bool isAdmin = widget.loginRole == 'admin';

    return Scaffold(
      backgroundColor: warnaLatarLayar,
      appBar: AppBar(
        title: Text(
          'Profil ${user['role'].toString().toUpperCase()}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: warnaKotakKartu,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: warnaBorderKartu, width: 1.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1), // Perbaikan .withOpacity standar TA
                      child: Icon(
                        user['role'] == 'siswa' ? Icons.face : Icons.person,
                        size: 36,
                        color: AppColors.primary, // Menggunakan tema global
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user['nama_lengkap'] ?? '-',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: warnaTeksUtama),
                          ),
                          Text(
                            'Nomor Induk: ${user['nomor_induk'] ?? '-'}',
                            style: TextStyle(fontSize: 13, color: warnaTeksSub),
                          ),
                          Text(
                            'Email: ${user['email'] ?? '-'}',
                            style: TextStyle(color: warnaTeksSub),
                          ),

                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Text('Status Akses: ', style: TextStyle(color: Colors.grey, fontSize: 13)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _isDeletedStatus == 0 ? Colors.green.shade50 : Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _isDeletedStatus == 0 ? '● AKTIF BISA LOGIN' : '🔒 TERBLOKIR / NONAKTIF',
                                  style: TextStyle(
                                    color: _isDeletedStatus == 0 ? Colors.green.shade800 : Colors.red.shade800,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  user['role'] == 'guru'
                                      ? 'Mengajar: $_currentKelas'
                                      : 'Tingkat Saat Ini: $_currentKelas',
                                  style: const TextStyle(
                                    color: Colors.deepOrange,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 12),

                              if (isAdmin)
                                InkWell(
                                  onTap: _tampilkanDialogEditUserMasaDepan, // Memanggil dialog gabungan baru Part 1-6
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.edit_note_rounded, color: Colors.blue, size: 20),
                                        SizedBox(width: 4),
                                        Text(
                                          'EDIT AKUN & KELAS', 
                                          style: TextStyle(color: Colors.blue, fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
            // Logika Bagian Pengisian Rapor Angka
            if (user['role'] == 'admin') ...[
              const Center(
                child: Text(
                  'Akun tingkat administrator tidak memiliki log data nilai akademik.',
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
            ] else ...[
              Text(
                user['role'] == 'guru'
                    ? 'Daftar Nilai Yang Dimasukkan Guru:'
                    : 'Riwayat Nilai Pembelajaran Rapor Siswa:',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary, // Menggunakan tema global
                ),
              ),
              const SizedBox(height: 16),
              _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _pesanError.isNotEmpty
                      ? Text(_pesanError, style: const TextStyle(color: Colors.red))
                      : _listNilai.isEmpty
                          ? const Center(
                              child: Text(
                                'Belum ada rekaman entri nilai akademik.',
                                style: TextStyle(fontStyle: FontStyle.italic),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _listNilai.length,
                              itemBuilder: (context, index) {
                                final nilai = _listNilai[index];
                                // AMAN BUG: Mengantisipasi eror data kosong dari database MySQL
                                double rataRata = ((int.tryParse(nilai['nilai_tugas'].toString()) ?? 0) +
                                        (int.tryParse(nilai['nilai_uts'].toString()) ?? 0) +
                                        (int.tryParse(nilai['nilai_uas'].toString()) ?? 0)) /
                                    3;
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(color: Colors.grey.shade200),
                                  ),
                                  child: ExpansionTile(
                                    title: Text(
                                      '${nilai['mata_pelajaran'] ?? '-'}',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Text(
                                      'Kategori: ${nilai['semester'] ?? '-'}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    trailing: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: rataRata >= 75 ? Colors.green.shade50 : Colors.red.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'Rata: ${rataRata.toStringAsFixed(1)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: rataRata >= 75 ? Colors.green.shade800 : Colors.red.shade800,
                                        ),
                                      ),
                                    ),
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Column(
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                                              children: [
                                                _buildSubNilai('Tugas', nilai['nilai_tugas'].toString()),
                                                _buildSubNilai('UTS', nilai['nilai_uts'].toString()),
                                                _buildSubNilai('UAS', nilai['nilai_uas'].toString()),
                                              ],
                                            ),
                                            if (nilai['keterangan'] != null && nilai['keterangan'].toString().isNotEmpty) ...[
                                              const Divider(height: 24),
                                              Align(
                                                alignment: Alignment.centerLeft,
                                                child: Text(
                                                  'Catatan Guru: "${nilai['keterangan']}"',
                                                  style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                if (isAdmin && user['role'] != 'admin') ...[
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: _isDeletedStatus == 0 ? Colors.red : Colors.green.shade700, 
                          width: 1.5
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: Icon(
                        _isDeletedStatus == 0 ? Icons.lock_person_rounded : Icons.lock_open_rounded, 
                        color: _isDeletedStatus == 0 ? Colors.red : Colors.green.shade700
                      ),
                      label: Text(
                        _isDeletedStatus == 0 ? 'BLOKIR HAK AKSES LOGIN' : 'AKTIFKAN KEMBALI HAK LOGIN AKUN', 
                        style: TextStyle(
                          color: _isDeletedStatus == 0 ? Colors.red : Colors.green.shade700, 
                          fontWeight: FontWeight.bold, 
                          fontSize: 14
                        ),
                      ),
                      onPressed: () => _konfirmasiUbahStatusAkses(context),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSubNilai(String label, String skor) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        const SizedBox(height: 4),
        Text(
          skor,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
