import 'package:flutter/material.dart';
import 'package:aplikasi_sekolah/core/constants/app_colors.dart';
import 'package:aplikasi_sekolah/core/services/nilai_service.dart';
import 'package:flutter/services.dart';

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
  String? _selectedSemesterFormat;
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
    _selectedSemesterFormat = _formatSemester(widget.kelasGuru, 'Semester 1');
    _panggilDaftarSiswa();
  }

  String? _normalisasiKelas(dynamic value) {
    final kelas = value?.toString().trim() ?? '';
    final match = RegExp(r'^(?:Kelas\s*)?([1-6])$', caseSensitive: false)
        .firstMatch(kelas);
    return match == null ? null : 'Kelas ${match.group(1)}';
  }

  String? _formatSemester(dynamic kelas, String semester) {
    final kelasNormal = _normalisasiKelas(kelas);
    if (kelasNormal == null) return null;
    return '$kelasNormal - $semester';
  }

  Map<String, dynamic>? get _siswaTerpilih {
    for (final siswa in _listSiswa) {
      if (siswa['id'].toString() == _selectedSiswaId) return siswa;
    }
    return null;
  }

  String? get _kelasSiswaSaatIni =>
      _normalisasiKelas(_siswaTerpilih?['kelas_diajar']);

  void _pilihSiswa(String? siswaId) {
    final siswa = _listSiswa.cast<Map<String, dynamic>?>().firstWhere(
      (item) => item?['id'].toString() == siswaId,
      orElse: () => null,
    );
    final semester = _selectedSemesterFormat?.split(' - ').last ?? 'Semester 1';
    final kelasSiswa = _normalisasiKelas(siswa?['kelas_diajar']);

    setState(() {
      _selectedSiswaId = siswaId;
      if (kelasSiswa != null) {
        _selectedSemesterFormat = _formatSemester(kelasSiswa, semester);
      }
    });
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

  // Mengirimkan data inputan guru ke NilaiService yang sudah diotomatisasi secara nyata
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

    final siswaTerpilih = _siswaTerpilih;
    final kelasSiswa = _normalisasiKelas(siswaTerpilih?['kelas_diajar']);
    final kelasOtomatis = _selectedSemesterFormat?.split(' - ').first;
    if (kelasSiswa == null || kelasOtomatis == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kelas siswa belum diatur. Periksa data siswa terlebih dahulu.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final angkatanOtomatis = int.tryParse(
      siswaTerpilih?['tahun_angkatan']?.toString() ?? '',
    );
    if (angkatanOtomatis == null || angkatanOtomatis <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tahun angkatan siswa belum valid. Lengkapi data siswa terlebih dahulu.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (kelasOtomatis != kelasSiswa) {
      final lanjutSimpan = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Konfirmasi kelas nilai'),
          content: Text(
            'Kelas siswa saat ini $kelasSiswa, tetapi nilai akan disimpan sebagai $kelasOtomatis. '
            'Lanjutkan hanya jika ini memang nilai untuk riwayat kelas tersebut.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('BATAL'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('LANJUTKAN'),
            ),
          ],
        ),
      );
      if (!mounted || lanjutSimpan != true) return;
    }

    setState(() => _isSubmitting = true);

    final semesterOtomatis = _selectedSemesterFormat!.split(' - ').last;

    // 🌟 4. Paket kiriman JSON lengkap dengan data Snapshot riwayat abadi
    final dataInput = {
      "siswa_id": _selectedSiswaId,
      "guru_id": widget.idGuru,
      "semester": semesterOtomatis,
      "kelas": kelasOtomatis,
      "tahun_angkatan": angkatanOtomatis.toString(),
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
      _selectedSemesterFormat = _formatSemester(widget.kelasGuru, 'Semester 1');
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
                      onChanged: _pilihSiswa,
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
                      validator: (value) =>
                          value == null ? 'Pilih kelas dan semester' : null,
                      onChanged: (v) =>
                          setState(() => _selectedSemesterFormat = v),
                    ),
                    if (_selectedSiswaId != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _kelasSiswaSaatIni == null
                            ? 'Kelas saat ini siswa belum diatur.'
                            : 'Kelas saat ini siswa: $_kelasSiswaSaatIni. '
                                'Kelas berbeda akan diminta konfirmasi sebelum disimpan.',
                        style: TextStyle(
                          color: _kelasSiswaSaatIni == null
                              ? Colors.red.shade700
                              : Colors.grey.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ],
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
                    TextFormField(
                      controller: _skorNilaiController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
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

                    TextFormField(
                      controller: _keteranganController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Catatan Perkembangan Siswa / Catatan Tambahan',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Tombol Simpan Nilai Rapor Terintegrasi State
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
