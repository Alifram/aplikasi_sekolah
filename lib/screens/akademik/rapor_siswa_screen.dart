import 'package:flutter/material.dart';
import 'package:aplikasi_sekolah/core/constants/app_colors.dart';
import 'package:aplikasi_sekolah/core/services/nilai_service.dart';
import 'package:pdf/pdf.dart'; // Pustaka dasar format PDF
import 'package:pdf/widgets.dart' as pw; // Komponen layout dokumen PDF
import 'package:printing/printing.dart'; // Antarmuka dialog cetak OS

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

  // Menarik log nilai dari NilaiService
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

  // FUNGSI GENERATE DOKUMEN PDF (Awal Struktur)
   Future<void> _cetakPdfRaporDigital() async {
    if (_listRapor.isEmpty) return;

    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start, // <-- PERBAIKAN 1: Nama properti lengkap & pakai titik dua
              children: [
                // KOP SURAT MADRASAH RESMI DI PDF
                pw.Center(
                  child: pw.Text(
                    'MADRASAH IBTIDAIYAH MUHAMMADIYAH PASIR LOR',
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.Center(
                  child: pw.Text(
                    'LEMBAR CAPAIAN HASIL BELAJAR PESERTA DIDIK (RAPOR DIGITAL)',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.Divider(thickness: 1.5),
                pw.SizedBox(height: 12),

                // DETAIL SISWA AKTIF
                pw.Text('ID Siswa / NIS : ${widget.idSiswa}', style: const pw.TextStyle(fontSize: 10)),
                pw.Text('Tanggal Cetak   : ${DateTime.now().toString().substring(0, 10)}', style: const pw.TextStyle(fontSize: 10)),
                pw.SizedBox(height: 14),

                // STRUKTUR TABEL REKAPITULASI NILAI DI PDF
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                  children: [
                    // Header Kolom Tabel
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Mata Pelajaran', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Tugas', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10), textAlign: pw.TextAlign.center)),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('UTS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10), textAlign: pw.TextAlign.center)),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('UAS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10), textAlign: pw.TextAlign.center)),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Rerata', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10), textAlign: pw.TextAlign.center)),
                      ],
                    ),
                    // Perulangan Data Nilai dari Server masuk ke Tabel PDF
                    ..._listRapor.map((nilai) {
                      double rataRata = ((int.tryParse(nilai['nilai_tugas'].toString()) ?? 0) +
                              (int.tryParse(nilai['nilai_uts'].toString()) ?? 0) +
                              (int.tryParse(nilai['nilai_uas'].toString()) ?? 0)) /
                          3;
                      return pw.TableRow(
                        children: [
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(nilai['mata_pelajaran'] ?? '-', style: const pw.TextStyle(fontSize: 10))),
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(nilai['nilai_tugas'].toString(), style: const pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.center)),
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(nilai['nilai_uts'].toString(), style: const pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.center)),
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(nilai['nilai_uas'].toString(), style: const pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.center)),
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(rataRata.toStringAsFixed(1), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10), textAlign: pw.TextAlign.center)),
                        ],
                      );
                    }),
                  ],
                ),
                pw.SizedBox(height: 35),
                // KOLOM TANDA TANGAN KEPALA SEKOLAH
                pw.Align(
                  alignment: pw.Alignment.topRight,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start, // <-- PERBAIKAN 2: Nama properti lengkap kolom PDF
                    children: [
                      pw.Text('Banyumas, ${DateTime.now().toString().substring(0, 10)}', style: const pw.TextStyle(fontSize: 10)),
                      pw.Text('Kepala Madrasah MIM Pasir Lor', style: const pw.TextStyle(fontSize: 10)),
                      pw.SizedBox(height: 45),
                      pw.Text('( __________________________ )', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    // Memicu jendela cetak dokumen bawaan sistem gawai
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Rapor_Siswa_${widget.idSiswa}.pdf',
    );
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
        // MENAMPILKAN TOMBOL IKON PRINTER DI BAR ATAS APABILA DATA SUKSES DIMUAT
        actions: [
          if (!_isLoading && _listRapor.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.print_rounded, color: Colors.white),
              tooltip: 'Cetak Dokumen PDF Rapor',
              onPressed: _cetakPdfRaporDigital,
            ),
        ],
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
                        
                        // Perbaikan total bug null-safety konversi nilai rapor
                        double rataRata = ((int.tryParse(nilai['nilai_tugas'].toString()) ?? 0) +
                                (int.tryParse(nilai['nilai_uts'].toString()) ?? 0) +
                                (int.tryParse(nilai['nilai_uas'].toString()) ?? 0)) /
                            3;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          child: ExpansionTile(
                            leading: CircleAvatar(
                              backgroundColor: rataRata >= 75 ? Colors.green.shade50 : Colors.red.shade50,
                              child: Icon(
                                Icons.menu_book,
                                color: rataRata >= 75 ? Colors.green.shade800 : Colors.red.shade800,
                              ),
                            ),
                            title: Text(
                              nilai['mata_pelajaran'] ?? '-',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            subtitle: Text(
                              'Semester ${nilai['semester'] ?? '-'} • Oleh: ${nilai['nama_guru'] ?? '-'}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: rataRata >= 75 ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Rerata: ${rataRata.toStringAsFixed(1)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: rataRata >= 75 ? Colors.green.shade800 : Colors.red.shade800,
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
                                        _buildItemNilai('Tugas', nilai['nilai_tugas'].toString()),
                                        _buildItemNilai('UTS', nilai['nilai_uts'].toString()),
                                        _buildItemNilai('UAS', nilai['nilai_uas'].toString()),
                                      ],
                                    ),
                                    if (nilai['keterangan'] != null && nilai['keterangan'].toString().isNotEmpty) ...[
                                      const Divider(height: 24),
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          'Pesan Guru: "${nilai['keterangan']}"',
                                          style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey, fontSize: 13),
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
} // Akhir Penutup Class _RaporSiswaScreenState
