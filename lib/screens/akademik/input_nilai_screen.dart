import 'package:flutter/material.dart';
import 'package:aplikasi_sekolah/core/constants/app_colors.dart';
import 'package:aplikasi_sekolah/core/services/nilai_service.dart';
import 'package:flutter/services.dart';

class InputNilaiScreen extends StatefulWidget {
  final String kelasGuru;
  final String idGuru;
  final ValueChanged<int>? onNilaiTersimpan;

  const InputNilaiScreen({
    super.key,
    required this.kelasGuru,
    required this.idGuru,
    this.onNilaiTersimpan,
  });

  @override
  State<InputNilaiScreen> createState() => _InputNilaiScreenState();
}

class _InputNilaiScreenState extends State<InputNilaiScreen> {
  final _formKey = GlobalKey<FormState>();

  List<dynamic> _listSiswa = [];
  List<Map<String, dynamic>> _listPenugasan = [];
  bool _isSiswaLoading = true;
  bool _isPenugasanLoading = true;
  bool _isSubmitting = false;
  String? _siswaError;
  String? _penugasanError;

  String? _selectedSiswaId;
  int? _kelasMapelTerpilihId;
  String? _selectedSemesterFormat;
  String _jenisNilaiTerpilih = 'tugas';

  final TextEditingController _skorNilaiController = TextEditingController();
  final TextEditingController _keteranganController = TextEditingController();
  final String _tanggalHariIni = DateTime.now().toString().substring(0, 10);

  List<String> get _daftarSemesterFormat {
    final kelas = _listPenugasan
        .map((item) => item['kelas']?.toString())
        .whereType<String>()
        .toSet()
        .toList();
    kelas.sort((a, b) {
      final numberA = int.tryParse(a.replaceAll(RegExp(r'\D'), '')) ?? 0;
      final numberB = int.tryParse(b.replaceAll(RegExp(r'\D'), '')) ?? 0;
      return numberA.compareTo(numberB);
    });
    return [
      for (final namaKelas in kelas) ...[
        '$namaKelas - Semester 1',
        '$namaKelas - Semester 2',
      ],
    ];
  }

  @override
  void initState() {
    super.initState();
    _panggilPenugasanMapel();
  }

  @override
  void dispose() {
    _skorNilaiController.dispose();
    _keteranganController.dispose();
    super.dispose();
  }

  Map<String, dynamic>? get _siswaTerpilih {
    for (final siswa in _listSiswa) {
      if (siswa['id'].toString() == _selectedSiswaId) return siswa;
    }
    return null;
  }

  void _pilihSiswa(String? siswaId) {
    setState(() => _selectedSiswaId = siswaId);
  }

  Future<void> _pilihSemesterFormat(String? value) async {
    if (value == null) return;
    final selectedClass = value.split(' - ').first;
    final currentClass = _selectedSemesterFormat?.split(' - ').first;
    setState(() {
      _selectedSemesterFormat = value;
      _kelasMapelTerpilihId = null;
      if (selectedClass != currentClass) {
        _selectedSiswaId = null;
      }
    });
    if (selectedClass != currentClass) {
      await _panggilDaftarSiswa(selectedClass);
    }
  }

  Future<void> _panggilDaftarSiswa(String kelas) async {
    setState(() {
      _isSiswaLoading = true;
      _siswaError = null;
      _selectedSiswaId = null;
    });
    final assignment = _listPenugasan.firstWhere(
      (item) => item['kelas']?.toString() == kelas,
      orElse: () => <String, dynamic>{},
    );
    final classId = int.tryParse(assignment['kelas_id']?.toString() ?? '');
    if (classId == null) {
      if (mounted) {
        setState(() {
          _listSiswa = [];
          _siswaError = 'ID kelas untuk penugasan ini tidak valid.';
          _isSiswaLoading = false;
        });
      }
      return;
    }
    final response = await NilaiService.ambilSiswa(classId);
    if (!mounted) return;
    final rawStudents = response['data'];
    setState(() {
      if (response['status'] == 'success' && rawStudents is List) {
        _listSiswa = rawStudents
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        if (_listSiswa.isEmpty) {
          _siswaError = 'Belum ada siswa aktif di $kelas.';
        }
      } else {
        _listSiswa = [];
        _siswaError =
            response['message']?.toString() ?? 'Gagal memuat daftar siswa.';
      }
      _isSiswaLoading = false;
    });
  }

  List<Map<String, dynamic>> get _penugasanUntukKelas {
    final targetClass = _selectedSemesterFormat?.split(' - ').first;
    return _listPenugasan
        .where((item) => item['kelas']?.toString() == targetClass)
        .toList();
  }

  Map<String, dynamic>? get _penugasanTerpilih {
    for (final item in _listPenugasan) {
      if (int.tryParse(item['id']?.toString() ?? '') == _kelasMapelTerpilihId) {
        return item;
      }
    }
    return null;
  }

  Future<void> _panggilPenugasanMapel({bool forceRefresh = false}) async {
    setState(() {
      _isPenugasanLoading = true;
      _isSiswaLoading = true;
      _penugasanError = null;
    });
    final response = await NilaiService.ambilPenugasanMapel(
      guruId: widget.idGuru,
      forceRefresh: forceRefresh,
    );
    if (!mounted) return;
    final rawAssignments = response['data'];
    if (response['status'] == 'success' && rawAssignments is List) {
      final assignments = rawAssignments
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .where(
            (item) =>
                int.tryParse(item['id']?.toString() ?? '') != null &&
                item['kelas']?.toString().isNotEmpty == true &&
                item['mata_pelajaran']?.toString().isNotEmpty == true &&
                item['tahun_ajaran']?.toString().isNotEmpty == true,
          )
          .toList();
      final defaultClass = widget.kelasGuru.trim();
      final targetClass =
          assignments.any((item) => item['kelas'] == defaultClass)
          ? defaultClass
          : assignments.isEmpty
          ? null
          : assignments.first['kelas']?.toString();
      setState(() {
        _listPenugasan = assignments;
        _selectedSemesterFormat = targetClass == null
            ? null
            : '$targetClass - Semester 1';
        _penugasanError = null;
        _isPenugasanLoading = false;
        _isSiswaLoading = targetClass != null;
      });
      if (targetClass != null) {
        await _panggilDaftarSiswa(targetClass);
      }
    } else {
      setState(() {
        _listPenugasan = [];
        _penugasanError =
            response['message']?.toString() ??
            'Gagal memuat penugasan mapel guru.';
        _isPenugasanLoading = false;
        _isSiswaLoading = false;
      });
    }
  }

  // Mengirimkan data inputan guru ke NilaiService yang sudah diotomatisasi secara nyata
  Future<void> _simpanNilaiKeDatabase() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Periksa kembali siswa, kelas, mapel, semester, dan skor.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final siswaTerpilih = _siswaTerpilih;
    final kelasOtomatis = _selectedSemesterFormat?.split(' - ').first;
    if (kelasOtomatis == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Kelas siswa belum diatur. Periksa data siswa terlebih dahulu.',
          ),
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
          content: Text(
            'Tahun angkatan siswa belum valid. Lengkapi data siswa terlebih dahulu.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final assignment = _penugasanTerpilih;
    if (assignment == null ||
        assignment['kelas']?.toString() != kelasOtomatis ||
        int.tryParse(siswaTerpilih?['kelas_id']?.toString() ?? '') !=
            int.tryParse(assignment['kelas_id']?.toString() ?? '')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih penugasan mapel untuk kelas yang dipilih.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final semesterOtomatis = _selectedSemesterFormat!.split(' - ').last;

    // 🌟 4. Paket kiriman JSON lengkap dengan data Snapshot riwayat abadi
    final dataInput = {
      "siswa_id": _selectedSiswaId,
      "guru_id": widget.idGuru,
      "semester": semesterOtomatis,
      "kelas_mapel_id": _kelasMapelTerpilihId,
      "jenis_nilai": _jenisNilaiTerpilih,
      "skor_nilai": _skorNilaiController.text.trim(),
      "keterangan": _keteranganController.text.trim(),
    };

    try {
      final res = await NilaiService.simpanNilai(dataInput);
      if (!mounted) return;
      if (res['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Data berhasil disimpan'),
            backgroundColor: AppColors.primary,
          ),
        );
        widget.onNilaiTersimpan?.call(angkatanOtomatis);
        _bersihkanForm();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Gagal menyimpan nilai'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _bersihkanForm() {
    _skorNilaiController.clear();
    _keteranganController.clear();
    setState(() {
      _selectedSiswaId = null;
      final defaultClass = widget.kelasGuru.trim();
      _selectedSemesterFormat =
          _daftarSemesterFormat.contains('$defaultClass - Semester 1')
          ? '$defaultClass - Semester 1'
          : _daftarSemesterFormat.isEmpty
          ? null
          : _daftarSemesterFormat.first;
      _kelasMapelTerpilihId = null;
      _jenisNilaiTerpilih = 'tugas';
    });
    final className = _selectedSemesterFormat?.split(' - ').first;
    if (className != null) _panggilDaftarSiswa(className);
  }

  @override
  Widget build(BuildContext context) {
    final noAssignments =
        !_isPenugasanLoading && _listPenugasan.isEmpty && _penugasanError == null;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Input Nilai',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              widget.kelasGuru,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.78),
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: _isPenugasanLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : noAssignments || (_penugasanError != null && _listPenugasan.isEmpty)
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      noAssignments
                          ? Icons.menu_book_outlined
                          : Icons.error_outline,
                      size: 48,
                      color: noAssignments ? Colors.grey : Colors.red,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _penugasanError ??
                          'Belum ada penugasan mapel aktif untuk akun guru ini. Hubungi admin.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () =>
                          _panggilPenugasanMapel(forceRefresh: true),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Coba muat ulang'),
                    ),
                  ],
                ),
              ),
            )
          : _isSiswaLoading
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
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0F5132), Color(0xFF218354)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.16),
                            blurRadius: 16,
                            offset: const Offset(0, 7),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.edit_note_rounded,
                                  color: Colors.white,
                                  size: 26,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _tanggalHariIni,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'Lembar Nilai Digital',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 21,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Pilih siswa dan mata pelajaran untuk mencatat hasil belajar.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.84),
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

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
                          child: Text(
                            '${s['nama_lengkap']} (${s['nomor_induk']})',
                          ),
                        );
                      }).toList(),
                      onChanged: _listSiswa.isEmpty ? null : _pilihSiswa,
                      validator: (value) =>
                          value == null ? 'Siswa wajib dipilih' : null,
                    ),
                    if (_siswaError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _siswaError!,
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Muat ulang siswa',
                              onPressed: _selectedSemesterFormat == null
                                  ? null
                                  : () => _panggilDaftarSiswa(
                                      _selectedSemesterFormat!
                                          .split(' - ')
                                          .first,
                                    ),
                              icon: const Icon(Icons.refresh),
                            ),
                          ],
                        ),
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
                      items: _daftarSemesterFormat
                          .map(
                            (option) => DropdownMenuItem<String>(
                              value: option,
                              child: Text(option),
                            ),
                          )
                          .toList(),
                      validator: (value) =>
                          value == null ? 'Pilih kelas dan semester' : null,
                      onChanged: _pilihSemesterFormat,
                    ),
                    const SizedBox(height: 16),

                    if (_penugasanError != null)
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _penugasanError!,
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Muat ulang penugasan',
                            onPressed: () =>
                                _panggilPenugasanMapel(forceRefresh: true),
                            icon: const Icon(Icons.refresh),
                          ),
                        ],
                      )
                    else
                      DropdownButtonFormField<int>(
                        key: ValueKey(
                          'kelas-mapel-${_selectedSemesterFormat ?? 'kosong'}',
                        ),
                        value: _kelasMapelTerpilihId,
                        decoration: const InputDecoration(
                          labelText: 'Mapel dan Tahun Ajaran',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.menu_book_outlined),
                        ),
                        items: _penugasanUntukKelas.map((item) {
                          final id = int.parse(item['id'].toString());
                          return DropdownMenuItem<int>(
                            value: id,
                            child: Text(
                              '${item['mata_pelajaran']} (${item['tahun_ajaran']})',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: _penugasanUntukKelas.isEmpty
                            ? null
                            : (value) =>
                                  setState(() => _kelasMapelTerpilihId = value),
                        validator: (value) => value == null
                            ? 'Pilih penugasan mapel yang sesuai'
                            : null,
                      ),
                    if (!_isPenugasanLoading && _penugasanUntukKelas.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Belum ada penugasan mapel aktif untuk kelas ini. Hubungi admin.',
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 12,
                          ),
                        ),
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
                      padding: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 8,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: CheckboxListTile(
                              title: const Text(
                                'Tugas',
                                style: TextStyle(fontSize: 14),
                              ),
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
                              title: const Text(
                                'UTS',
                                style: TextStyle(fontSize: 14),
                              ),
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
                              title: const Text(
                                'UAS',
                                style: TextStyle(fontSize: 14),
                              ),
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
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText:
                            'Masukkan Angka Skor Nilai ${_jenisNilaiTerpilih.toUpperCase()}',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.pin_outlined),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Skor tidak boleh kosong';
                        }
                        final n = int.tryParse(v.trim());
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
                        labelText:
                            'Catatan Perkembangan Siswa / Catatan Tambahan',
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
                        onPressed: _isSubmitting
                            ? null
                            : _simpanNilaiKeDatabase,
                        child: _isSubmitting
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
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
