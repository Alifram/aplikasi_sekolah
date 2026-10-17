import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class KelasService {
  static const String baseUrl = ApiConfig.baseUrl;

  // Fungsi khusus untuk mengambil daftar teman sekelas dari backend PHP
  static Future<Map<String, dynamic>> ambilTemanSekelas(int kelasId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/get_teman_sekelas.php?kelas_id=$kelasId'),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'status': 'error', 'message': 'Gagal memuat data kelas dari server'};
    } catch (e) {
      return {'status': 'error', 'message': 'Terjadi kesalahan koneksi: $e'};
    }
  }

  static Future<Map<String, dynamic>> ambilDaftarKelas() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/get_kelas.php'));
      if (response.statusCode == 200) return jsonDecode(response.body);
      return {'status': 'error', 'message': 'Gagal memuat daftar kelas.'};
    } catch (e) {
      return {'status': 'error', 'message': 'Terjadi kesalahan koneksi: $e'};
    }
  }
}
