import 'dart:convert';
import 'package:http/http.dart' as http;

class KelasService {
  static const String baseUrl = 'http://localhost:8000';

  // Fungsi khusus untuk mengambil daftar teman sekelas dari backend PHP
  static Future<Map<String, dynamic>> ambilTemanSekelas(String kelas) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/get_teman_sekelas.php?kelas=$kelas'),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'status': 'error', 'message': 'Gagal memuat data kelas dari server'};
    } catch (e) {
      return {'status': 'error', 'message': 'Terjadi kesalahan koneksi: $e'};
    }
  }
}
