import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:aplikasi_sekolah/core/constants/app_colors.dart';
import 'package:aplikasi_sekolah/core/services/informasi_service.dart';
import 'package:aplikasi_sekolah/core/services/dashboard_service.dart';

class EventScreen extends StatefulWidget {
  final String namaUser;
  final String roleUser;
  final String? kelasUser;

  const EventScreen({
    super.key,
    required this.namaUser,
    required this.roleUser,
    this.kelasUser,
  });

  @override
  State<EventScreen> createState() => _EventScreenState();
}

class _EventScreenState extends State<EventScreen> {
  List<dynamic> _listEvents = [];
  bool _isLoading = true;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _judulController = TextEditingController();
  final TextEditingController _deskripsiController = TextEditingController();
  String _selectedTargetKelas = 'Semua Kelas';

  XFile? _imageFile;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _panggilDataAcara();
  }

  // AMAN UNTUK TA: Mencegah Memory Leak dengan membuang controller saat halaman ditutup
  @override
  void dispose() {
    _judulController.dispose();
    _deskripsiController.dispose();
    super.dispose();
  }

  // LOGIKA BARU: Menjembatani panggilan data ke InformasiService
  Future<void> _panggilDataAcara() async {
    final res = await DashboardService.ambilAcaraTerbaru();
    
    if (mounted) {
      setState(() {
        if (res['status'] == 'success') {
          // 1. Tampung data mentah dari server MySQL
          List<dynamic> dataMentah = res['data'] ?? [];
          
          // 2. 🌟 SINKRONISASI AKTIF: Panggil filter agar garis kuning hilang total
          _jalankanFilterBeritaSekolah(dataMentah); 
      } else {
        // BYPASS AMAN: Mencetak log error ke terminal debugging tanpa crash layar
        debugPrint(res['message'] ?? 'Gagal memuat info pengumuman.');
      }
        _isLoading = false;
      });
    }
  }


  // Fungsi kamera HP tetap berada di file UI karena urusan hardware tampilan
  Future<void> _pilihSumberFoto(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 70,
      );
      if (pickedFile != null) {
        setState(() {
          _imageFile = pickedFile;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print("Gagal membuka kamera/galeri: $e");
      }
    }
  }

  // LOGIKA BARU: Mengirim data form dan base64 melalui InformasiService
  Future<void> _tambahAcaraBaru() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    String? gambarBase64;
    if (_imageFile != null) {
      final bytes = await _imageFile!.readAsBytes();
      gambarBase64 = base64Encode(bytes);
    }

    final dataInput = {
      "judul_acara": _judulController.text.trim(),
      "deskripsi": _deskripsiController.text.trim(),
      "target_kelas": _selectedTargetKelas,
      "tanggal_acara": DateTime.now().toString().substring(0, 10),
      "dibuat_oleh": widget.namaUser,
      "gambar_base64": gambarBase64,
    };

    final res = await InformasiService.tambahAcara(dataInput);

    if (res['status'] == 'success') {
      if (!mounted) return;
      Navigator.pop(context);
      _judulController.clear();
      _deskripsiController.clear();
      setState(() {
        _imageFile = null;
      });
      _panggilDataAcara();
    } else {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] ?? 'Gagal menambahkan acara'), backgroundColor: Colors.red),
      );
    }
  }

  // LOGIKA BARU: Mengirim request hapus postingan via InformasiService
  Future<void> _hapusPostinganAcara(String eventId) async {
    setState(() => _isLoading = true);

    final dataHapus = {
      "event_id": eventId,
      "role_user": widget.roleUser,
      "nama_user": widget.namaUser,
    };

    final res = await InformasiService.hapusAcara(dataHapus);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res['message'] ?? 'Proses selesai'),
        backgroundColor: res['status'] == 'success' ? AppColors.primary : Colors.red,
      ),
    );

    _panggilDataAcara();
  }
  void _bukaDialogTambahAcara() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Publikasi Berita & Kegiatan',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _judulController,
                      decoration: const InputDecoration(
                        labelText: 'Judul Utama Kegiatan',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => value!.isEmpty ? 'Wajib diisi' : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedTargetKelas,
                      decoration: const InputDecoration(
                        labelText: 'Terjadi di / Untuk Kelas',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        'Semua Kelas',
                        'Kelas 1',
                        'Kelas 2',
                        'Kelas 3',
                        'Kelas 4',
                        'Kelas 5',
                        'Kelas 6',
                      ].map((k) => DropdownMenuItem(value: k, child: Text(k))).toList(),
                      onChanged: (v) => setModalState(() => _selectedTargetKelas = v!),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _deskripsiController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Deskripsi Suasana & Informasi',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => value!.isEmpty ? 'Wajib diisi' : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Kamera'),
                          onPressed: () async {
                            await _pilihSumberFoto(ImageSource.camera);
                            setModalState(() {});
                          },
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.photo_library),
                          label: const Text('Galeri'),
                          onPressed: () async {
                            await _pilihSumberFoto(ImageSource.gallery);
                            setModalState(() {});
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_imageFile != null)
                      Container(
                        height: 120,
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                            image: kIsWeb
                                ? NetworkImage(_imageFile!.path)
                                : FileImage(File(_imageFile!.path)) as ImageProvider,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                        ),
                        onPressed: _tambahAcaraBaru,
                        child: const Text(
                          'POSTING BERITA KEGIATAN',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

    // LOGIKA DINAMIS: Menyaring pengumuman agar otomatis melekat pada ruang kelas fiskal
  void _jalankanFilterBeritaSekolah(List<dynamic> semuaBerita) {
    setState(() {
      // Jika yang login adalah ADMIN, bypass saringan agar bisa memantau semua berita
      if (widget.roleUser.toLowerCase().trim() == 'admin') {
        _listEvents = semuaBerita;
        return;
      }

      // Jika yang login adalah GURU atau SISWA, lakukan penyaringan ketat
      _listEvents = semuaBerita.where((ev) {
        final targetBerita = ev['target_kelas'].toString().trim().toLowerCase();
        
        // Mengambil status kelas aktif terbaru dari data login pengguna
        final kelasAktifUser = (widget.kelasUser ?? 'Belum Diatur').toString().trim().toLowerCase();

        // Kondisi A: Jika pengumuman diset global, semua kelas wajib bisa melihat
        if (targetBerita == 'semua kelas' || targetBerita == 'semua') {
          return true;
        }

        // Kondisi B: Berita hanya muncul jika target_kelas cocok dengan kelas aktif pengguna saat ini
        return targetBerita == kelasAktifUser;
      }).toList();
    });
  }

  // LOGIKA TA AMAN: Panggilan HTTP dikontrol agar tidak memicu infinite loop saat modal di-rebuild
  void _bukaKolomKomentar(String eventId) {
    final TextEditingController komentarController = TextEditingController();
    List<dynamic> listKomentar = [];
    bool isKomentarLoading = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            
            // Mengambil komentar secara aman (Hanya berjalan saat status loading bernilai true)
            if (isKomentarLoading) {
              InformasiService.ambilKomentar(eventId).then((res) {
                if (res['status'] == 'success') {
                  setModalState(() {
                    listKomentar = res['data'] ?? [];
                    isKomentarLoading = false;
                  });
                } else {
                  setModalState(() => isKomentarLoading = false);
                }
              });
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Kolom Diskusi & Komentar',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.3,
                    ),
                    child: isKomentarLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                            ),
                          )
                        : listKomentar.isEmpty
                            ? const Center(
                                child: Text(
                                  'Belum ada opini. Jadilah yang pertama berkomentar!',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              )
                            : ListView.builder(
                                itemCount: listKomentar.length,
                                itemBuilder: (context, idx) {
                                  final item = listKomentar[idx];
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: CircleAvatar(
                                      backgroundColor: item['role_pengirim'] == 'admin'
                                          ? Colors.purple.shade50
                                          : Colors.green.shade50,
                                      child: Text(
                                        item['role_pengirim']
                                            .toString()
                                            .substring(0, 1)
                                            .toUpperCase(),
                                      ),
                                    ),
                                    title: Text(
                                      item['nama_pengirim'] ?? 'Anonim',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    subtitle: Text(
                                      item['isi_komentar'] ?? '',
                                      style: const TextStyle(
                                        color: Colors.black87,
                                        fontSize: 13,
                                      ),
                                    ),
                                  );
                                },
                              ),
                  ),
                  const Divider(),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: komentarController,
                          decoration: const InputDecoration(
                            hintText: 'Tulis komentar Anda...',
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send, color: AppColors.primary),
                        onPressed: () async {
                          if (komentarController.text.trim().isEmpty) return;
                          
                          final dataKomentar = {
                            "event_id": eventId,
                            "user_id": 1,
                            "nama_pengirim": widget.namaUser,
                            "role_pengirim": widget.roleUser,
                            "isi_komentar": komentarController.text.trim(),
                          };

                          await InformasiService.kirimKomentar(dataKomentar);
                          komentarController.clear();
                          setModalState(() {
                            isKomentarLoading = true; // Memicu pengambilan ulang daftar secara aman
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    ).then((_) => komentarController.dispose()); // Membersihkan kontroler memori saat modal ditutup
  }
  @override
  Widget build(BuildContext context) {
    bool bolehTambahAcara = widget.roleUser == 'admin' || widget.roleUser == 'guru';

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _listEvents.isEmpty
              ? const Center(child: Text('Belum ada postingan kegiatan sekolah.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _listEvents.length,
                  itemBuilder: (context, index) {
                    final item = _listEvents[index];
                    bool bolehHapus = widget.roleUser == 'admin' || 
                        (widget.roleUser == 'guru' && item['dibuat_oleh'] == widget.namaUser);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      elevation: 1.5,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Menarik gambar berita secara otomatis dari direktori server backend
                          if (item['gambar_url'] != null)
                            Image.network(
                              'http://localhost:8000/view_image.php?file=${item['gambar_url']}',
                              height: 220,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => const SizedBox(),
                            ),
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                                          child: Text(
                                            item['target_kelas'] ?? 'Semua Kelas',
                                            style: TextStyle(color: Colors.blue.shade800, fontWeight: FontWeight.bold, fontSize: 11),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Row(
                                          children: [
                                            const Icon(Icons.calendar_month, size: 14, color: Colors.grey),
                                            const SizedBox(width: 4),
                                            Text(item['tanggal_acara'] ?? '-', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                          ],
                                        ),
                                      ],
                                    ),
                                    if (bolehHapus)
                                      IconButton(
                                        icon: const Icon(Icons.delete_sweep, color: Colors.red, size: 20),
                                        onPressed: () => _hapusPostinganAcara(item['id'].toString()),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(item['judul_acara'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                const SizedBox(height: 6),
                                Text(item['deskripsi'] ?? '-', style: const TextStyle(color: Colors.black87, height: 1.4)),
                                const Divider(height: 24),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Oleh: ${item['dibuat_oleh'] ?? '-'}', style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500)),
                                    TextButton.icon(
                                      icon: const Icon(Icons.mode_comment_outlined, size: 18, color: AppColors.primary),
                                      label: const Text('Diskusi / Komentar', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13)),
                                      onPressed: () => _bukaKolomKomentar(item['id'].toString()),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
      floatingActionButton: bolehTambahAcara
          ? FloatingActionButton(
              backgroundColor: AppColors.primary,
              onPressed: _bukaDialogTambahAcara,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }
}