import 'package:flutter/material.dart';
import 'package:aplikasi_sekolah/core/constants/app_colors.dart';
import 'package:aplikasi_sekolah/core/services/nilai_service.dart';

class KelasScreen extends StatefulWidget {
  final String kelasSiswa;

  const KelasScreen({super.key, required this.kelasSiswa});

  @override
  State<KelasScreen> createState() => _KelasScreenState();
}

class _KelasScreenState extends State<KelasScreen> {
  List<dynamic> _listSiswaGlobal = [];
  bool _isLoadingSiswa = true;

  @override
  void initState() {
    super.initState();
    _panggilDataMuridSistem();
  }

  Future<void> _panggilDataMuridSistem() async {
    // 🌟 JIKA PARAMETER KOSONG (AKSES DARI ADMIN), KITA DEFAULT KE 'Kelas 1' ATAU MEMANGGIL SEMUA DATA
    String filterKelas = widget.kelasSiswa.isEmpty ? 'Kelas 1' : widget.kelasSiswa;
    
    final res = await NilaiService.ambilSiswa(filterKelas);
    if (mounted) {
      setState(() {
        if (res['status'] == 'success') {
          _listSiswaGlobal = res['data'] ?? [];
        }
        _isLoadingSiswa = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    String judulHeader = widget.kelasSiswa.isEmpty ? 'Data Seluruh Siswa' : 'Daftar Siswa ${widget.kelasSiswa}';

    return Scaffold(
      appBar: AppBar(
        // 🌟 MENAMBAHKAN FITUR BUTTON KEMBALI SECARA MANUAL & LEGAL
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '$judulHeader (Total: ${_listSiswaGlobal.length} Anak)',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: AppColors.primary,
      ),
      body: _isLoadingSiswa
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _listSiswaGlobal.isEmpty
              ? const Center(
                  child: Text(
                    'Belum ada data siswa terdaftar di tingkat kelas ini.',
                    style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _listSiswaGlobal.length,
                  itemBuilder: (context, index) {
                    final murid = _listSiswaGlobal[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: AppColors.primary,
                          child: Icon(Icons.person, color: Colors.white),
                        ),
                        title: Text(murid['nama_lengkap'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('NISN: ${murid['nomor_induk'] ?? '-'} | Angkatan: ${murid['tahun_angkatan'] ?? '-'}'),
                      ),
                    );
                  },
                ),
    );
  }
}
