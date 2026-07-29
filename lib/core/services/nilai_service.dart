import 'dart:convert';
import 'package:http/http.dart' as http;

class NilaiService {
  static const String baseUrl = 'http://localhost:8000';

  static Future<Map<String, dynamic>> ambilSiswa(String kelas) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/get_siswa_by_kelas.php?kelas=$kelas'),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'status': 'error', 'message': 'Gagal memuat data dari server'};
    } catch (e) {
      return {'status': 'error', 'message': 'Terjadi kesalahan koneksi: $e'};
    }
  }

  static Future<Map<String, dynamic>> simpanNilai(Map<String, dynamic> dataNilai) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/add_nilai.php'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(dataNilai),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'status': 'error', 'message': 'Gagal menyimpan data ke server'};
    } catch (e) {
      return {'status': 'error', 'message': 'Terjadi kesalahan koneksi: $e'};
    }
  }

  static Future<Map<String, dynamic>> ambilRaporSiswa(String idSiswa) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/get_rapor_siswa.php?siswa_id=$idSiswa'),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'status': 'error', 'message': 'Gagal memuat lembar rapor dari server'};
    } catch (e) {
      return {'status': 'error', 'message': 'Terjadi kesalahan koneksi: $e'};
    }
  }
}