import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class ApiService {
  static const String baseUrl = ApiConfig.baseUrl;
  static Future<Map<String, dynamic>> perbaruiDataPengguna(Map<String, dynamic> dataInput) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/update_user.php'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(dataInput),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {
        "status": "error", 
        "message": "Gagal terhubung ke server database: $e"
      };
    }
  }

  static Future<Map<String, dynamic>> hapusAkunUser(String idUser) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/hapus_user.php'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"user_id": idUser}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {"status": "error", "message": "Gagal terhubung ke server hapus data: $e"};
    }
  }

  static Future<Map<String, dynamic>> ambilStatistikAkademik(String angkatan) async {
    try {
      final uri = Uri.parse('$baseUrl/get_statistik.php').replace(
        queryParameters: {'angkatan': angkatan},
      );
      final response = await http.get(uri);
      return jsonDecode(response.body);
    } catch (e) {
      return {"status": "error", "message": "Gagal terhubung ke database statistik: $e"};
    }
  }

  static Future<Map<String, dynamic>> ambilRaporSiswa(String idSiswa) async {
    try {
      final uri = Uri.parse('$baseUrl/get_rapor_siswa.php').replace(
        queryParameters: {'siswa_id': idSiswa},
      );
      final response = await http.get(uri);
      return jsonDecode(response.body);
    } catch (e) {
      return {"status": "error", "message": "Gagal terhubung ke database rapor: $e"};
    }
  }

  static Future<Map<String, dynamic>> ambilRingkasanDashboard() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/get_dashboard_summary.php'),
        headers: {"Content-Type": "application/json"},
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {"status": "error", "message": "Gagal terhubung ke database ringkasan: $e"};
    }
  }

}
