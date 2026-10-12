import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Basis URL server lokal port 8000 sesuai konfigurasi proyek sekolah Anda
  static const String baseUrl = 'http://localhost:8000';
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
        body: jsonEncode({"id_user": idUser}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {"status": "error", "message": "Gagal terhubung ke server hapus data: $e"};
    }
  }

  static Future<Map<String, dynamic>> ambilStatistikAkademik(
    String angkatan,
  ) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$baseUrl/get_statistik.php?angkatan=$angkatan',
        ),
      );

      print("=== STATISTIK API ===");
      print("URL: ${response.request?.url}");
      print("Status Code: ${response.statusCode}");
      print("Response: ${response.body}");
      print("=====================");

      return jsonDecode(response.body);
    } catch (e) {
      print("=== ERROR STATISTIK ===");
      print(e);
      print("======================");

      return {
        "status": "error",
        "message": "Gagal terhubung ke database statistik: $e",
      };
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
