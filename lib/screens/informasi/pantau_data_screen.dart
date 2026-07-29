import 'package:flutter/material.dart';
import '../user/detail_user_screen.dart'; 
import 'package:aplikasi_sekolah/core/constants/app_colors.dart';
import 'package:aplikasi_sekolah/core/services/admin_service.dart'; // <-- IMPORT SERVICE BARU

class PantauDataScreen extends StatefulWidget {
  const PantauDataScreen({super.key});

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

  @override
  void initState() {
    super.initState();
    _panggilDataPengguna();
  }

  // LOGIKA BARU: UI murni hanya memicu penarikan data via AdminService
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
    }
  }

  void _jalankanFilterPencarian() {
    setState(() {
      _filteredUsers = _allUsers.where((user) {
        final nama = user['nama_lengkap'].toString().toLowerCase();
        final nomorInduk = user['nomor_induk'].toString().toLowerCase();
        final role = user['role'].toString().toLowerCase();
        final cocokKeyword =
            nama.contains(_searchQuery.toLowerCase()) ||
            nomorInduk.contains(_searchQuery.toLowerCase());

        if (_selectedFilterRole == 'semua') {
          return cocokKeyword;
        } else {
          return cocokKeyword && role == _selectedFilterRole;
        }
      }).toList();
    });
  }

  Color _getRoleColor(String role) {
    if (role == 'admin') return Colors.purple;
    if (role == 'guru') return Colors.blue.shade700;
    return Colors.green.shade700;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Pantau Semua Data',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primary, // Tema Global
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
                    style: const TextStyle(color: Colors.red, fontSize: 16),
                  ),
                )
              : Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: AppColors.primary.withValues(alpha: 0.05), // Tema Global Moderen
                      child: Column(
                        children: [
                          TextField(
                            onChanged: (value) {
                              _searchQuery = value;
                              _jalankanFilterPencarian();
                            },
                            decoration: InputDecoration(
                              hintText: 'Cari berdasarkan nama atau nomor induk...',
                              prefixIcon: const Icon(
                                Icons.search,
                                color: AppColors.primary, // Tema Global
                              ),
                              fillColor: Colors.white,
                              filled: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 0,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              _buildFilterChip('semua', 'Semua'),
                              const SizedBox(width: 8),
                              _buildFilterChip('guru', 'Guru'),
                              const SizedBox(width: 8),
                              _buildFilterChip('siswa', 'Siswa'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // LIST DATA HASIL FILTER
                    Expanded(
                      child: _filteredUsers.isEmpty
                          ? const Center(
                              child: Text(
                                'Data tidak ditemukan.',
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _filteredUsers.length,
                              itemBuilder: (context, index) {
                                final user = _filteredUsers[index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  elevation: 1,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    // Klik kartu untuk melompat ke halaman detail rekam akademik
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
                                            backgroundColor: _getRoleColor(user['role']).withValues(alpha: 0.1), // Perbaikan .withOpacity
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
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'No. Induk: ${user['nomor_induk'] ?? '-'}',
                                                  style: const TextStyle(
                                                    color: Colors.grey,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                                if (user['role'] == 'guru' && user['kelas_diajar'] != null)
                                                  Text(
                                                    'Mengajar: ${user['kelas_diajar']}',
                                                    style: const TextStyle(
                                                      color: Colors.deepOrange,
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _getRoleColor(user['role']).withValues(alpha: 0.15), // Perbaikan .withOpacity
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              user['role'].toString().toUpperCase(),
                                              style: TextStyle(
                                                color: _getRoleColor(user['role']),
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
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

  Widget _buildFilterChip(String roleType, String label) {
    final bool isSelected = _selectedFilterRole == roleType;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primary, // Menggunakan tema global sekolah
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (bool selected) {
        if (selected) {
          setState(() {
            _selectedFilterRole = roleType;
            _jalankanFilterPencarian();
          });
        }
      },
    );
  }
}
