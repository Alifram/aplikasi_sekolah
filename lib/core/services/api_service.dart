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
}
