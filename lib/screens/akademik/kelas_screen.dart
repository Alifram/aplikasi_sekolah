import 'package:flutter/material.dart';
import 'package:aplikasi_sekolah/core/constants/app_colors.dart';
import 'package:aplikasi_sekolah/core/services/kelas_service.dart'; // <-- IMPORT SERVICE BARU

class KelasScreen extends StatefulWidget {
  final String kelasSiswa; 

  const KelasScreen({super.key, required this.kelasSiswa});

  @override
  State<KelasScreen> createState() => _KelasScreenState();
}

class _KelasScreenState extends State<KelasScreen> {
  List<dynamic> _listTeman = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _panggilDataTeman();
  }

  // LOGIKA BARU: UI kini murni hanya memicu panggilan ke KelasService
  Future<void> _panggilDataTeman() async {
    final res = await KelasService.ambilTemanSekelas(widget.kelasSiswa);
    
    if (mounted) {
      setState(() {
        if (res['status'] == 'success') {
          _listTeman = res['data'];
        }
        _isLoading = false;
      });
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: AppColors.primary.withValues(alpha: 0.05),
                  child: Text(
                    'Daftar Siswa di ${widget.kelasSiswa} (Total: ${_listTeman.length} Anak)',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                Expanded(
                  child: _listTeman.isEmpty
                      ? const Center(
                          child: Text('Belum ada data siswa di kelas ini.'),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _listTeman.length,
                          itemBuilder: (context, index) {
                            final siswa = _listTeman[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                  child: const Icon(
                                    Icons.face,
                                    color: AppColors.primary,
                                  ),
                                ),
                                title: Text(
                                  siswa['nama_lengkap'] ?? '-',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text('NIS: ${siswa['nomor_induk'] ?? '-'}'),
                                trailing: const Icon(
                                  Icons.contact_mail_outlined,
                                  color: Colors.grey,
                                  size: 18,
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}