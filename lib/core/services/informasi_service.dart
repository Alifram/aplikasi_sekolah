import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class InformasiService {
  static const String baseUrl = ApiConfig.baseUrl;

  // 1. Ambil data lini masa berita acara (GET)
  static Future<Map<String, dynamic>> ambilAcara() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/get_events.php'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'status': 'error', 'message': 'Gagal mengambil berita dari server.'};
    } catch (e) {
      return {'status': 'error', 'message': 'Kesalahan jaringan: $e'};
    }
  }

  // 2. Tambah berita acara baru beserta string foto base64 (POST)
  static Future<Map<String, dynamic>> tambahAcara(Map<String, dynamic> dataAcara) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/add_event.php'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(dataAcara),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'status': 'error', 'message': 'Gagal mengirim pengumuman.'};
    } catch (e) {
      return {'status': 'error', 'message': 'Kesalahan jaringan: $e'};
    }
  }

  // 3. Hapus postingan berita acara (POST)
  static Future<Map<String, dynamic>> hapusAcara(Map<String, dynamic> dataHapus) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/delete_event.php'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(dataHapus),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'status': 'error', 'message': 'Gagal menghapus postingan.'};
    } catch (e) {
      return {'status': 'error', 'message': 'Kesalahan jaringan: $e'};
    }
  }

  // 4. Ambil daftar diskusi komentar berdasarkan ID Berita (GET)
  static Future<Map<String, dynamic>> ambilKomentar(String eventId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/get_comments.php?event_id=$eventId'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'status': 'error', 'message': 'Gagal memuat diskusi komentar.'};
    } catch (e) {
      return {'status': 'error', 'message': 'Kesalahan jaringan: $e'};
    }
  }

  // 5. Kirim data komentar baru ke server (POST)
  static Future<Map<String, dynamic>> kirimKomentar(Map<String, dynamic> dataKomentar) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/add_comment.php'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(dataKomentar),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'status': 'error', 'message': 'Gagal mengirimkan komentar Anda.'};
    } catch (e) {
      return {'status': 'error', 'message': 'Kesalahan jaringan: $e'};
    }
  }
}
