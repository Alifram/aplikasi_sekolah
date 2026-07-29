import 'dart:convert';
import 'package:http/http.dart' as http;

class AdminService {
  // Base URL server lokal XAMPP Anda
  static const String baseUrl = 'http://localhost:8000';

  // Fungsi khusus untuk menarik seluruh data pengguna sekolah (Admin, Guru, Siswa)
  static Future<Map<String, dynamic>> ambilSemuaPengguna() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/get_users.php'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'status': 'error', 'message': 'Gagal memuat database pengguna.'};
    } catch (e) {
      return {'status': 'error', 'message': 'Kesalahan jaringan: $e'};
    }
  }

  static Future<Map<String, dynamic>> ambilDataNilai(String userId, String role) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/get_nilai.php?user_id=$userId&role=$role'),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'status': 'error', 'message': 'Gagal memuat rekam jejak nilai.'};
    } catch (e) {
      return {'status': 'error', 'message': 'Kesalahan jaringan: $e'};
    }
  }

  static Future<Map<String, dynamic>> prosesPindahKelas(String userId, String kelasBaru) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/pindah_kelas.php'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "user_id": userId,
          "kelas_baru": kelasBaru,
        }),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'status': 'error', 'message': 'Gagal memperbarui data kelas.'};
    } catch (e) {
      return {'status': 'error', 'message': 'Kesalahan jaringan: $e'};
    }
  }
}
