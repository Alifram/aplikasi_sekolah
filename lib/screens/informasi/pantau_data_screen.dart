import 'package:flutter/material.dart';
import '../user/detail_user_screen.dart'; 
import 'package:aplikasi_sekolah/core/constants/app_colors.dart';
import 'package:aplikasi_sekolah/core/services/admin_service.dart';

class PantauDataScreen extends StatefulWidget {
  final String? filterKelasOtomatis;
  final String? filterAngkatanOtomatis;

  const PantauDataScreen({
    super.key, 
    this.filterKelasOtomatis, 
    this.filterAngkatanOtomatis,
  });

  @override
  State<PantauDataScreen> createState() => _PantauDataScreenState();
}

class _PantauDataScreenState extends State<PantauDataScreen> {
  List<dynamic> _allUsers = [];
  List<dynamic> _filteredUsers = [];
  bool _isLoading = true;
  String _pesanError = '';

  String _searchQuery = '';
  String _selectedFilterRole = 'semua'; 
  
  String _selectedFilterAngkatan = 'Semua Angkatan';
  final List<String> _opsiFilterAngkatan = ['Semua Angkatan', '2023', '2024', '2025', '2026'];

  @override
  void initState() {
    super.initState();
    if (widget.filterAngkatanOtomatis != null) {
      _selectedFilterAngkatan = widget.filterAngkatanOtomatis!;
    }
    _panggilDataPengguna();
  }

  Future<void> _panggilDataPengguna() async {
    final res = await AdminService.ambilSemuaPengguna();
    if (mounted) {
      setState(() {
        if (res['status'] == 'success') {
          _allUsers = res['data'] ?? [];
          _filteredUsers = res['data'] ?? [];
        } else {
          _pesanError = res['message'] ?? 'Gagal mengambil database pengguna.';
        }
        _isLoading = false;
      });
      _jalankanFilterPencarian();
    }
  }
      void _jalankanFilterPencarian() {
    setState(() {
      _filteredUsers = _allUsers.where((user) {
        final nama = user['nama_lengkap'].toString().toLowerCase();
        final nomorInduk = user['nomor_induk'].toString().toLowerCase();
        final role = user['role'].toString().toLowerCase();
        final kelasUser = user['kelas_diajar']?.toString().trim().toLowerCase() ?? '';
        final angkatanUser = user['tahun_angkatan']?.toString().trim() ?? '';
        final cocokKeyword = nama.contains(_searchQuery.toLowerCase()) ||
            nomorInduk.contains(_searchQuery.toLowerCase());
        bool cocokRole = (_selectedFilterRole == 'semua') ? true : (role == _selectedFilterRole);
        bool cocokAngkatan = true;
        if (_selectedFilterAngkatan != 'Semua Angkatan') {
          if (role == 'siswa') {
            cocokAngkatan = (angkatanUser == _selectedFilterAngkatan);
          } else {
            cocokAngkatan = true; 
          }
        }
        bool cocokKelasOtomatis = true;
        if (widget.filterKelasOtomatis != null) {
          final String targetKelas = widget.filterKelasOtomatis!.trim().toLowerCase();
          
          if (role == 'admin') {
            cocokKelasOtomatis = false; 
          } else if (role == 'guru') {
            cocokKelasOtomatis = kelasUser.contains(targetKelas);
          } else if (role == 'siswa') {
            cocokKelasOtomatis = (kelasUser == targetKelas);
          }
        }

        return cocokKeyword && cocokRole && cocokAngkatan && cocokKelasOtomatis;
      }).toList();
    });
  }

  void _konfirmasiKenaikanMassal(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 28),
            SizedBox(width: 8),
            Text('Otomatisasi Massal', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Apakah Anda yakin ingin menaikkan jenjang seluruh kelas siswa secara otomatis?\n\n'
          '⚠️ CATATAN:\n'
          '• Siswa Kelas 6 otomatis lulus menjadi Alumni.\n'
          '• Siswa Kelas 1-5 otomatis naik ke tingkat berikutnya.\n'
          '• Proses ini tidak dapat dibatalkan secara manual.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isLoading = true);

              final res = await AdminService.prosesKenaikanKelasMassal();
              
              if (!mounted) return;

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(res['message'] ?? 'Proses selesai'),
                  backgroundColor: res['status'] == 'success' ? AppColors.primary : Colors.red,
                  duration: const Duration(seconds: 4),
                ),
              );

              _panggilDataPengguna();
            },
            child: const Text('Ya, Eksekusi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
  Color _getRoleColor(String role) {
    if (role == 'admin') return Colors.purple;
    if (role == 'guru') return Colors.blue.shade700;
    return Colors.green.shade700;
  }

  Widget _buildAreaFilterDanPencarian() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.primary.withValues(alpha: 0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.filterKelasOtomatis != null) ...[
            Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  'Mengunci Penghuni: ${widget.filterKelasOtomatis} (${_selectedFilterAngkatan})',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          TextField(
            onChanged: (value) {
              _searchQuery = value;
              _jalankanFilterPencarian();
            },
            decoration: InputDecoration(
              hintText: 'Cari berdasarkan nama atau nomor induk...',
              prefixIcon: const Icon(Icons.search, color: AppColors.primary),
              fillColor: Colors.white,
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _buildFilterChip('semua', 'Semua'),
                  const SizedBox(width: 6),
                  _buildFilterChip('guru', 'Guru'),
                  const SizedBox(width: 6),
                  _buildFilterChip('siswa', 'Siswa'),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButton<String>(
                  value: _selectedFilterAngkatan,
                  underline: const SizedBox(),
                  icon: const Icon(Icons.filter_list_alt, size: 16, color: AppColors.primary),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                  items: _opsiFilterAngkatan.map((String val) {
                    return DropdownMenuItem<String>(
                      value: val,
                      child: Text(val == 'Semua Angkatan' ? val : 'Angkatan $val'),
                    );
                  }).toList(),
                  onChanged: (String? newVal) {
                    if (newVal != null) {
                      setState(() {
                        _selectedFilterAngkatan = newVal;
                      });
                      _jalankanFilterPencarian();
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String roleType, String label) {
    final bool isSelected = _selectedFilterRole == roleType;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (bool selected) {
        if (selected) {
          setState(() {
            _selectedFilterRole = roleType;
          });
          _jalankanFilterPencarian();
        }
      },
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Pantau Semua Data',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.bolt_rounded, color: Colors.amber, size: 26),
            tooltip: 'Otomatisasi Kenaikan Kelas Massal',
            onPressed: () => _konfirmasiKenaikanMassal(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _pesanError.isNotEmpty
              ? Center(child: Text(_pesanError, style: const TextStyle(color: Colors.red, fontSize: 16)))
              : Column(
                  children: [
                    _buildAreaFilterDanPencarian(),
                    Expanded(
                      child: _filteredUsers.isEmpty
                          ? const Center(child: Text('Data tidak ditemukan.', style: TextStyle(color: Colors.grey)))
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _filteredUsers.length,
                              itemBuilder: (context, index) {
                                final user = _filteredUsers[index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  elevation: 1,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => DetailUserScreen(
                                            userData: user,
                                            loginRole: 'admin',
                                          ),
                                        ),
                                      );
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            backgroundColor: _getRoleColor(user['role']).withValues(alpha: 0.1),
                                            child: Icon(
                                              user['role'] == 'siswa' ? Icons.face : Icons.person,
                                              color: _getRoleColor(user['role']),
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  user['nama_lengkap'] ?? '-',
                                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'No. Induk: ${user['nomor_induk'] ?? '-'}',
                                                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                                                ),
                                                if (user['role'] == 'siswa' && user['tahun_angkatan'] != null)
                                                  Text(
                                                    'Tahun Angkatan: ${user['tahun_angkatan']} • Kelas: ${user['kelas_diajar']}',
                                                    style: const TextStyle(color: Colors.blueGrey, fontSize: 12, fontWeight: FontWeight.w500),
                                                  ),
                                                if (user['role'] == 'guru' && user['kelas_diajar'] != null)
                                                  Text(
                                                    'Mengajar: ${user['kelas_diajar']}',
                                                    style: const TextStyle(color: Colors.deepOrange, fontSize: 13, fontWeight: FontWeight.w500),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: _getRoleColor(user['role']).withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              user['role'].toString().toUpperCase(),
                                              style: TextStyle(color: _getRoleColor(user['role']), fontSize: 11, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                      ),
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
