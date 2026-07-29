import 'package:flutter/material.dart';
import 'package:aplikasi_sekolah/core/constants/app_colors.dart';
import 'package:aplikasi_sekolah/core/services/nilai_service.dart';

class InputNilaiScreen extends StatefulWidget {
  final String kelasGuru;
  final String idGuru;

  const InputNilaiScreen({
    super.key,
    required this.kelasGuru,
    required this.idGuru,
  });

  @override
  State<InputNilaiScreen> createState() => _InputNilaiScreenState();
}

class _InputNilaiScreenState extends State<InputNilaiScreen> {
  final _formKey = GlobalKey<FormState>();

  List<dynamic> _listSiswa = [];
  bool _isSiswaLoading = true;
  bool _isSubmitting = false;

  String? _selectedSiswaId;
  String _selectedMapel = 'Al-Quran Hadist';
  String _selectedSemesterFormat = 'Kelas 1 - Semester 1';
  String _jenisNilaiTerpilih = 'tugas'; 

  final TextEditingController _skorNilaiController = TextEditingController();
  final TextEditingController _keteranganController = TextEditingController();
  final String _tanggalHariIni = DateTime.now().toString().substring(0, 10);

  final List<String> _daftarMapel = [
    'Al-Quran Hadist', 'Akidah Akhlak', 'Fikih', 'Sejarah Kebudayaan Islam',
    'Bahasa Arab', 'Matematika', 'Bahasa Indonesia', 'IPA', 'IPS', 'PPKn',
  ];

  final List<String> _daftarSemesterFormat = [
    'Kelas 1 - Semester 1', 'Kelas 1 - Semester 2', 'Kelas 2 - Semester 1',
    'Kelas 2 - Semester 2', 'Kelas 3 - Semester 1', 'Kelas 3 - Semester 2',
    'Kelas 4 - Semester 1', 'Kelas 4 - Semester 2', 'Kelas 5 - Semester 1',
    'Kelas 5 - Semester 2', 'Kelas 6 - Semester 1', 'Kelas 6 - Semester 2',
  ];
  @override
  void initState() {
    super.initState();
    _panggilDaftarSiswa();
  }

  // Menghubungkan UI dengan fungsi ambil data di NilaiService
  Future<void> _panggilDaftarSiswa() async {
    final res = await NilaiService.ambilSiswa(widget.kelasGuru);
    
    if (mounted) {
      setState(() {
        if (res['status'] == 'success') {
          _listSiswa = res['data'];
        }
        _isSiswaLoading = false;
      });
    }
  }

  // Mengirimkan data inputan guru ke NilaiService
  Future<void> _simpanNilaiKeDatabase() async {
    if (!_formKey.currentState!.validate() || _selectedSiswaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan lengkapi nama siswa dan skor angka!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final dataInput = {
      "siswa_id": _selectedSiswaId,
      "guru_id": widget.idGuru,
      "semester": _selectedSemesterFormat,
      "mata_pelajaran": _selectedMapel,
      "jenis_nilai": _jenisNilaiTerpilih,
      "skor_nilai": _skorNilaiController.text.trim(),
      "keterangan": _keteranganController.text.trim(),
    };

    final res = await NilaiService.simpanNilai(dataInput);

    if (!mounted) return;

    if (res['status'] == 'success') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Data berhasil disimpan'),
          backgroundColor: AppColors.primary,
        ),
      );
      _bersihkanForm();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Gagal menyimpan nilai'),
          backgroundColor: Colors.red,
        ),
      );
    }

    setState(() => _isSubmitting = false);
  }

  void _bersihkanForm() {
    _skorNilaiController.clear();
    _keteranganController.clear();
    setState(() {
      _selectedSiswaId = null;
      _jenisNilaiTerpilih = 'tugas';
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Input Nilai - ${widget.kelasGuru}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isSiswaLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Entry Rapor Digital Siswa',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '📅 Tanggal: $_tanggalHariIni',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Dropdown Pilih Siswa (Type-Safe & Bersih dari Warning)
                    DropdownButtonFormField<String>(
                      value: _selectedSiswaId,
                      hint: const Text('Pilih Nama Siswa'),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.face),
                      ),
                      items: _listSiswa.map<DropdownMenuItem<String>>((s) {
                        return DropdownMenuItem<String>(
                          value: s['id'].toString(),
                          child: Text('${s['nama_lengkap']} (${s['nomor_induk']})'),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() => _selectedSiswaId = v),
                    ),
                    const SizedBox(height: 16),
                    // Dropdown Kombinasi Format Kelas & Semester
                    DropdownButtonFormField<String>(
                      value: _selectedSemesterFormat,
                      decoration: const InputDecoration(
                        labelText: 'Tingkat Kelas & Kategori Semester',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.school_outlined),
                      ),
                      items: _daftarSemesterFormat.map<DropdownMenuItem<String>>((s) {
                        return DropdownMenuItem<String>(
                          value: s,
                          child: Text(s),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() => _selectedSemesterFormat = v!),
                    ),
                    const SizedBox(height: 16),

                    // Dropdown Mata Pelajaran
                    DropdownButtonFormField<String>(
                      value: _selectedMapel,
                      decoration: const InputDecoration(
                        labelText: 'Mata Pelajaran',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.menu_book_outlined),
                      ),
                      items: _daftarMapel.map<DropdownMenuItem<String>>((m) {
                        return DropdownMenuItem<String>(
                          value: m,
                          child: Text(m),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() => _selectedMapel = v!),
                    ),
                    const SizedBox(height: 20),

                    // FITUR CHECKBOX JENIS KATEGORI NILAI
                    const Text(
                      'Pilih Jenis Nilai Yang Diinput:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: CheckboxListTile(
                              title: const Text('Tugas', style: TextStyle(fontSize: 14)),
                              value: _jenisNilaiTerpilih == 'tugas',
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                              onChanged: (bool? checked) {
                                if (checked == true) {
                                  setState(() => _jenisNilaiTerpilih = 'tugas');
                                }
                              },
                            ),
                          ),
                          Expanded(
                            child: CheckboxListTile(
                              title: const Text('UTS', style: TextStyle(fontSize: 14)),
                              value: _jenisNilaiTerpilih == 'uts',
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                              onChanged: (bool? checked) {
                                if (checked == true) {
                                  setState(() => _jenisNilaiTerpilih = 'uts');
                                }
                              },
                            ),
                          ),
                          Expanded(
                            child: CheckboxListTile(
                              title: const Text('UAS', style: TextStyle(fontSize: 14)),
                              value: _jenisNilaiTerpilih == 'uas',
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                              onChanged: (bool? checked) {
                                if (checked == true) {
                                  setState(() => _jenisNilaiTerpilih = 'uas');
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Satu Kolom Angka Fleksibel Sesuai Checkbox Di Atas
                    TextFormField(
                      controller: _skorNilaiController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Masukkan Angka Skor Nilai ${_jenisNilaiTerpilih.toUpperCase()}',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.pin_outlined),
                      ),
                      validator: (v) {
                        if (v!.isEmpty) {
                          return 'Skor tidak boleh kosong';
                        }
                        int? n = int.tryParse(v);
                        if (n == null || n < 0 || n > 100) {
                          return 'Masukkan angka rentang 0 - 100';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Catatan Tambahan/Keterangan Guru
                    TextFormField(
                      controller: _keteranganController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Catatan Perkembangan Siswa / Catatan Tambahan',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Tombol Simpan Nilai Rapor
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
                        onPressed: _isSubmitting ? null : _simpanNilaiKeDatabase,
                        child: _isSubmitting
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                                'SIMPAN NILAI RAPOR',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
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