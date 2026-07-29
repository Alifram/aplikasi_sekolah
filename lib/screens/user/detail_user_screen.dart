import 'package:flutter/material.dart';
import 'package:aplikasi_sekolah/core/constants/app_colors.dart';
import 'package:aplikasi_sekolah/core/services/admin_service.dart'; // <-- IMPORT SERVICE BARU

class DetailUserScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String loginRole; 

  const DetailUserScreen({
    super.key,
    required this.userData,
    required this.loginRole,
  });

  @override
  State<DetailUserScreen> createState() => _DetailUserScreenState();
}

class _DetailUserScreenState extends State<DetailUserScreen> {
  List<dynamic> _listNilai = [];
  bool _isLoading = true;
  String _pesanError = '';
  late String _currentKelas;

  @override
  void initState() {
    super.initState();
    _currentKelas = widget.userData['kelas_diajar'] ?? 'Belum Diatur';
    _panggilDataNilai();
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

  void _bukaDialogUbahKelas() {
    final List<String> daftarOpsiKelas = [
      'Kelas 1',
      'Kelas 2',
      'Kelas 3',
      'Kelas 4',
      'Kelas 5',
      'Kelas 6',
    ];
    String tempKelas = daftarOpsiKelas.contains(_currentKelas)
        ? _currentKelas
        : 'Kelas 1';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Pindahkan Tingkat Kelas'),
          content: DropdownButtonFormField<String>(
            value: tempKelas, 
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.school_outlined),
            ),
            items: daftarOpsiKelas.map((k) {
              return DropdownMenuItem<String>(value: k, child: Text(k));
            }).toList(),
            onChanged: (v) {
              tempKelas = v!;
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary, // Menggunakan tema global
              ),
              onPressed: () {
                Navigator.pop(context);
                _prosesPindahKelas(tempKelas); 
              },
              child: const Text(
                'Simpan',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
  @override
  Widget build(BuildContext context) {
    final user = widget.userData;
    // Deteksi apakah yang membuka halaman ini adalah Admin
    bool isAdmin = widget.loginRole == 'admin';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Profil ${user['role'].toString().toUpperCase()}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.primary, // Menggunakan tema global
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Detail Informasi Perangkat Akun Utama
            Card(
              color: const Color(0xFFF8F9FA),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
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
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Nomor Induk: ${user['nomor_induk'] ?? '-'}',
                            style: const TextStyle(color: Colors.grey),
                          ),
                          Text(
                            'Email: ${user['email'] ?? '-'}',
                            style: const TextStyle(color: Colors.grey),
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
                              const SizedBox(width: 8),
                              // Menampilkan tombol ubah/pindah kelas khusus untuk Admin
                              if (isAdmin)
                                InkWell(
                                  onTap: _bukaDialogUbahKelas,
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 4),
                                    child: Icon(
                                      Icons.edit_note,
                                      color: Colors.blue,
                                      size: 26,
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
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary, // Menggunakan tema global
                      ),
                    )
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
                                double rataRata = (int.parse(nilai['nilai_tugas'].toString()) +
                                        int.parse(nilai['nilai_uts'].toString()) +
                                        int.parse(nilai['nilai_uas'].toString())) /
                                    3;
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(color: Colors.grey.shade200),
                                  ),
                                  child: ExpansionTile(
                                    title: Text(
                                      '${nilai['mata_pelajaran']}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Text(
                                      'Kategori: ${nilai['semester']}',
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
                                                _buildSubNilai(
                                                  'Tugas',
                                                  nilai['nilai_tugas'].toString(),
                                                ),
                                                _buildSubNilai(
                                                  'UTS',
                                                  nilai['nilai_uts'].toString(),
                                                ),
                                                _buildSubNilai(
                                                  'UAS',
                                                  nilai['nilai_uas'].toString(),
                                                ),
                                              ],
                                            ),
                                            if (nilai['keterangan'] != null) ...[
                                              const Divider(height: 24),
                                              Align(
                                                alignment: Alignment.centerLeft,
                                                child: Text(
                                                  'Catatan Guru: "${nilai['keterangan']}"',
                                                  style: const TextStyle(
                                                    fontStyle: FontStyle.italic,
                                                    color: Colors.grey,
                                                  ),
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
