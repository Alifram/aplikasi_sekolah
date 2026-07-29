import 'package:flutter/material.dart';
import 'package:aplikasi_sekolah/core/constants/app_colors.dart';
import 'package:aplikasi_sekolah/core/services/nilai_service.dart';

class RaporSiswaScreen extends StatefulWidget {
  final String idSiswa; 

  const RaporSiswaScreen({super.key, required this.idSiswa});

  @override
  State<RaporSiswaScreen> createState() => _RaporSiswaScreenState();
}

class _RaporSiswaScreenState extends State<RaporSiswaScreen> {
  List<dynamic> _listRapor = [];
  bool _isLoading = true;
  String _pesanError = '';

  @override
  void initState() {
    super.initState();
    _panggilDataRapor();
  }

  // LOGIKA BARU: UI murni hanya memicu panggilan ke NilaiService
  Future<void> _panggilDataRapor() async {
    final res = await NilaiService.ambilRaporSiswa(widget.idSiswa);
    
    if (mounted) {
      setState(() {
        if (res['status'] == 'success') {
          _listRapor = res['data'];
        } else {
          _pesanError = res['message'] ?? 'Gagal mengambil data rapor.';
        }
        _isLoading = false;
      });
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Lembar Rapor Digital',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _pesanError.isNotEmpty
              ? Center(
                  child: Text(
                    _pesanError,
                    style: const TextStyle(color: Colors.red),
                  ),
                )
              : _listRapor.isEmpty
                  ? const Center(
                      child: Text(
                        'Data nilai rapor Anda belum dimasukkan oleh Guru Kelas.',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Colors.grey,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(24),
                      itemCount: _listRapor.length,
                      itemBuilder: (context, index) {
                        final nilai = _listRapor[index];
                        
                        // Menghitung angka rata-rata raport otomatis secara aman
                        double rataRata = (int.parse(nilai['nilai_tugas'].toString()) +
                                int.parse(nilai['nilai_uts'].toString()) +
                                int.parse(nilai['nilai_uas'].toString())) /
                            3;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          child: ExpansionTile(
                            leading: CircleAvatar(
                              backgroundColor: rataRata >= 75
                                  ? Colors.green.shade50
                                  : Colors.red.shade50,
                              child: Icon(
                                Icons.menu_book,
                                color: rataRata >= 75
                                    ? Colors.green.shade800
                                    : Colors.red.shade800,
                              ),
                            ),
                            title: Text(
                              nilai['mata_pelajaran'] ?? '-',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Text(
                              'Semester ${nilai['semester'] ?? '-'} • Oleh: ${nilai['nama_guru'] ?? '-'}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: rataRata >= 75
                                    ? Colors.green.withValues(alpha: 0.1)
                                    : Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Rerata: ${rataRata.toStringAsFixed(1)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: rataRata >= 75
                                      ? Colors.green.shade800
                                      : Colors.red.shade800,
                                ),
                              ),
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                                      children: [
                                        _buildItemNilai(
                                          'Tugas',
                                          nilai['nilai_tugas'].toString(),
                                        ),
                                        _buildItemNilai(
                                          'UTS',
                                          nilai['nilai_uts'].toString(),
                                        ),
                                        _buildItemNilai(
                                          'UAS',
                                          nilai['nilai_uas'].toString(),
                                        ),
                                      ],
                                    ),
                                    if (nilai['keterangan'] != null &&
                                        nilai['keterangan'].toString().isNotEmpty) ...[
                                      const Divider(height: 24),
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          'Pesan Guru: "${nilai['keterangan']}"',
                                          style: const TextStyle(
                                            fontStyle: FontStyle.italic,
                                            color: Colors.grey,
                                            fontSize: 13,
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
    );
  }

  Widget _buildItemNilai(String label, String skor) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          skor,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}