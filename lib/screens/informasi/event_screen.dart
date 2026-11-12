import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:aplikasi_sekolah/core/constants/app_colors.dart';
import 'package:aplikasi_sekolah/core/services/informasi_service.dart';
import 'package:aplikasi_sekolah/core/services/dashboard_service.dart';
import 'package:aplikasi_sekolah/core/services/kelas_service.dart';

class EventScreen extends StatefulWidget {
  final String userId;
  final String namaUser;
  final String roleUser;
  final String? kelasIdUser;
  final ValueChanged<List<dynamic>>? onEventsChanged;

  const EventScreen({
    super.key,
    required this.userId,
    required this.namaUser,
    required this.roleUser,
    this.kelasIdUser,
    this.onEventsChanged,
  });

  @override
  State<EventScreen> createState() => _EventScreenState();
}

class _EventScreenState extends State<EventScreen> {
  List<dynamic> _listEvents = [];
  bool _isLoading = true;
  String? _eventError;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _judulController = TextEditingController();
  final TextEditingController _deskripsiController = TextEditingController();
  List<Map<String, dynamic>> _kelas = [];
  final Set<int> _selectedTargetKelasIds = {};
  bool _targetSemuaKelas = true;

  XFile? _imageFile;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _muatKelas();
    _panggilDataAcara();
  }

  Future<void> _muatKelas() async {
    final response = await KelasService.ambilDaftarKelas();
    if (!mounted) return;
    if (response['status'] == 'success' && response['data'] is List) {
      setState(() {
        _kelas = (response['data'] as List)
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            response['message']?.toString() ?? 'Gagal memuat daftar kelas.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
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
    if (mounted) {
      setState(() {
        _isLoading = true;
        _eventError = null;
      });
    }
    final res = await DashboardService.ambilAcaraTerbaru();
    if (!mounted) return;
    final rawEvents = res['data'];
    if (res['status'] == 'success' && rawEvents is List) {
      setState(() {
        _jalankanFilterBeritaSekolah(rawEvents);
        _eventError = null;
        _isLoading = false;
      });
      widget.onEventsChanged?.call(rawEvents);
      return;
    }
    setState(() {
      _eventError =
          res['message']?.toString() ?? 'Gagal memuat daftar kegiatan.';
      _isLoading = false;
    });
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

  // Upload the image separately so event metadata stays within the RPC payload.
  Future<void> _tambahAcaraBaru() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_targetSemuaKelas && _selectedTargetKelasIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih minimal satu kelas atau aktifkan semua kelas.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    String? gambarPath;
    if (_imageFile != null) {
      final fileName = _imageFile!.name.toLowerCase();
      final mimeType =
          _imageFile!.mimeType ??
          (fileName.endsWith('.png')
              ? 'image/png'
              : fileName.endsWith('.webp')
              ? 'image/webp'
              : 'image/jpeg');
      final extension = switch (mimeType) {
        'image/png' => 'png',
        'image/webp' => 'webp',
        'image/jpeg' => 'jpg',
        _ => null,
      };
      if (extension == null) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Format gambar harus JPEG, PNG, atau WebP.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final bytes = await _imageFile!.readAsBytes();
      final upload = await InformasiService.unggahGambarAcara(
        bytes: bytes,
        extension: extension,
        contentType: mimeType,
      );
      if (upload['status'] != 'success') {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              upload['message']?.toString() ?? 'Gagal mengunggah gambar.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      gambarPath = upload['path']?.toString();
    }

    final dataInput = {
      "judul_acara": _judulController.text.trim(),
      "deskripsi": _deskripsiController.text.trim(),
      "semua_kelas": _targetSemuaKelas,
      "kelas_ids": _selectedTargetKelasIds.toList(),
      "tanggal_acara": DateTime.now().toString().substring(0, 10),
      "gambar_path": gambarPath,
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
      await _panggilDataAcara();
    } else {
      String? cleanupError;
      if (gambarPath != null) {
        cleanupError = await InformasiService.hapusGambarAcara(gambarPath);
      }
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            [
              res['message']?.toString() ?? 'Gagal menambahkan acara',
              if (cleanupError != null)
                'Gagal membersihkan gambar: $cleanupError',
            ].join(' '),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // LOGIKA BARU: Mengirim request hapus postingan via InformasiService
  Future<void> _hapusPostinganAcara(String eventId) async {
    setState(() => _isLoading = true);

    final event = _listEvents.cast<Map>().firstWhere(
      (item) => item['id'].toString() == eventId,
      orElse: () => const {},
    );
    final imagePath = event['gambar_url']?.toString();
    final res = await InformasiService.hapusAcara(
      eventId: eventId,
      imagePath: imagePath,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res['message'] ?? 'Proses selesai'),
        backgroundColor: res['status'] == 'success'
            ? AppColors.primary
            : Colors.red,
      ),
    );

    if (res['status'] == 'success') {
      await _panggilDataAcara();
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
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
                      validator: (value) =>
                          value!.isEmpty ? 'Wajib diisi' : null,
                    ),
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Tampilkan untuk semua kelas'),
                      value: _targetSemuaKelas,
                      onChanged: (value) => setModalState(() {
                        _targetSemuaKelas = value ?? false;
                        if (_targetSemuaKelas) _selectedTargetKelasIds.clear();
                      }),
                    ),
                    if (!_targetSemuaKelas)
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 180),
                        child: ListView(
                          shrinkWrap: true,
                          children: _kelas.map((kelas) {
                            final id = int.tryParse(kelas['id'].toString());
                            if (id == null) return const SizedBox.shrink();
                            return CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(kelas['nama'].toString()),
                              value: _selectedTargetKelasIds.contains(id),
                              onChanged: (selected) => setModalState(() {
                                if (selected == true) {
                                  _selectedTargetKelasIds.add(id);
                                } else {
                                  _selectedTargetKelasIds.remove(id);
                                }
                              }),
                            );
                          }).toList(),
                        ),
                      ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _deskripsiController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Deskripsi Suasana & Informasi',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value!.isEmpty ? 'Wajib diisi' : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Kamera'),
                          onPressed: () async {
                            await _pilihSumberFoto(ImageSource.camera);
                            if (!context.mounted) return;
                            setModalState(() {});
                          },
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.photo_library),
                          label: const Text('Galeri'),
                          onPressed: () async {
                            await _pilihSumberFoto(ImageSource.gallery);
                            if (!context.mounted) return;
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
                                : FileImage(File(_imageFile!.path))
                                      as ImageProvider,
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
    // Jika yang login adalah ADMIN, bypass saringan agar bisa memantau semua berita
    if (widget.roleUser.toLowerCase().trim() == 'admin') {
      _listEvents = semuaBerita;
      return;
    }

    final currentClassId = int.tryParse(widget.kelasIdUser ?? '');
    _listEvents = semuaBerita.where((ev) {
      if (ev is! Map) return false;
      if (ev['target_semua_kelas'] == true) return true;
      if (currentClassId == null) return false;
      final rawIds = ev['target_kelas_ids'];
      if (rawIds is! List) return false;
      return rawIds.any((id) => int.tryParse(id.toString()) == currentClassId);
    }).toList();
  }

  String _labelTargetKelas(dynamic event) {
    if (event is! Map) return 'Semua Kelas';
    if (event['target_semua_kelas'] == true) return 'Semua Kelas';

    final activeClassIds = _kelas
        .map((kelas) => int.tryParse(kelas['id']?.toString() ?? ''))
        .whereType<int>()
        .toSet();
    final rawTargetIds = event['target_kelas_ids'];
    if (activeClassIds.isNotEmpty && rawTargetIds is List) {
      final targetIds = rawTargetIds
          .map((id) => int.tryParse(id.toString()))
          .whereType<int>()
          .toSet();
      if (targetIds.containsAll(activeClassIds)) return 'Semua Kelas';
    }

    final label = event['target_kelas']?.toString().trim() ?? '';
    return label.isEmpty ? 'Semua Kelas' : label;
  }

  void _bukaKolomKomentar(String eventId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _KolomKomentarSheet(
        eventId: eventId,
        userId: widget.userId,
        namaUser: widget.namaUser,
        roleUser: widget.roleUser,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool bolehTambahAcara =
        widget.roleUser == 'admin' || widget.roleUser == 'guru';

    return Scaffold(
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _eventError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_off_rounded,
                      size: 48,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(height: 12),
                    Text(_eventError!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _panggilDataAcara,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Coba lagi'),
                    ),
                  ],
                ),
              ),
            )
          : _listEvents.isEmpty
          ? const Center(child: Text('Belum ada postingan kegiatan sekolah.'))
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _listEvents.length,
              itemBuilder: (context, index) {
                final item = _listEvents[index];
                bool bolehHapus =
                    widget.roleUser == 'admin' ||
                    (widget.roleUser == 'guru' &&
                        item['dibuat_oleh'] == widget.namaUser);

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 1.5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (item['gambar_signed_url'] != null)
                        Image.network(
                          item['gambar_signed_url'].toString(),
                          height: 220,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const SizedBox(),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        _labelTargetKelas(item),
                                        style: TextStyle(
                                          color: Colors.blue.shade800,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.calendar_month,
                                          size: 14,
                                          color: Colors.grey,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          item['tanggal_acara'] ?? '-',
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                if (bolehHapus)
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_sweep,
                                      color: Colors.red,
                                      size: 20,
                                    ),
                                    onPressed: () => _hapusPostinganAcara(
                                      item['id'].toString(),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              item['judul_acara'] ?? '-',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item['deskripsi'] ?? '-',
                              style: const TextStyle(
                                color: Colors.black87,
                                height: 1.4,
                              ),
                            ),
                            const Divider(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    'Oleh: ${item['dibuat_oleh'] ?? '-'}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                TextButton.icon(
                                  icon: const Icon(
                                    Icons.mode_comment_outlined,
                                    size: 18,
                                    color: AppColors.primary,
                                  ),
                                  label: const Text(
                                    'Diskusi / Komentar',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  onPressed: () =>
                                      _bukaKolomKomentar(item['id'].toString()),
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

class _KolomKomentarSheet extends StatefulWidget {
  final String eventId;
  final String userId;
  final String namaUser;
  final String roleUser;

  const _KolomKomentarSheet({
    required this.eventId,
    required this.userId,
    required this.namaUser,
    required this.roleUser,
  });

  @override
  State<_KolomKomentarSheet> createState() => _KolomKomentarSheetState();
}

class _KolomKomentarSheetState extends State<_KolomKomentarSheet> {
  final TextEditingController _komentarController = TextEditingController();
  List<dynamic> _komentar = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _muatKomentar();
  }

  @override
  void dispose() {
    _komentarController.dispose();
    super.dispose();
  }

  Future<void> _muatKomentar() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final response = await InformasiService.ambilKomentar(widget.eventId);
    if (!mounted) return;
    if (response['status'] == 'success' && response['data'] is List) {
      setState(() {
        _komentar = response['data'] as List;
        _isLoading = false;
      });
    } else {
      setState(() {
        _errorMessage =
            response['message']?.toString() ?? 'Gagal memuat komentar.';
        _isLoading = false;
      });
    }
  }

  Future<void> _kirimKomentar() async {
    final isiKomentar = _komentarController.text.trim();
    if (isiKomentar.isEmpty || _isSubmitting) return;
    setState(() => _isSubmitting = true);

    final response = await InformasiService.kirimKomentar({
      'event_id': widget.eventId,
      'user_id': widget.userId,
      'nama_pengirim': widget.namaUser,
      'role_pengirim': widget.roleUser,
      'isi_komentar': isiKomentar,
    });
    if (!mounted) return;

    setState(() => _isSubmitting = false);
    if (response['status'] == 'success') {
      _komentarController.clear();
      await _muatKomentar();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            response['message']?.toString() ?? 'Gagal mengirim komentar.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
    final availableHeight = screenHeight - keyboardHeight - 40;
    final maxSheetHeight = availableHeight
        .clamp(0.0, screenHeight * 0.75)
        .toDouble();
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxSheetHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Kolom Diskusi & Komentar',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      )
                    : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_errorMessage!, textAlign: TextAlign.center),
                            TextButton.icon(
                              onPressed: _muatKomentar,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Coba lagi'),
                            ),
                          ],
                        ),
                      )
                    : _komentar.isEmpty
                    ? const Center(
                        child: Text(
                          'Belum ada opini. Jadilah yang pertama berkomentar!',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: _komentar.length,
                        itemBuilder: (context, index) {
                          final item = Map<String, dynamic>.from(
                            _komentar[index] as Map,
                          );
                          final role = item['role_pengirim']?.toString() ?? '';
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: role == 'admin'
                                  ? Colors.purple.shade50
                                  : Colors.green.shade50,
                              child: Text(
                                role.isEmpty ? '?' : role[0].toUpperCase(),
                              ),
                            ),
                            title: Text(
                              item['nama_pengirim']?.toString() ?? 'Anonim',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              item['isi_komentar']?.toString() ?? '',
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
                      controller: _komentarController,
                      enabled: !_isSubmitting,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _kirimKomentar(),
                      decoration: const InputDecoration(
                        hintText: 'Tulis komentar Anda...',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Kirim komentar',
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send, color: AppColors.primary),
                    onPressed: _isSubmitting ? null : _kirimKomentar,
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
