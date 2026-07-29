import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService {
  // Base URL server lokal XAMPP Anda
  static const String baseUrl = 'http://localhost:8000';

  // Fungsi khusus untuk menangani request masuk akun (Login)
  static Future<Map<String, dynamic>> login(String identifier, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login.php'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "identifier": identifier,
          "password": password,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'status': 'error', 'message': 'Gagal terhubung ke server (${response.statusCode})'};
    } catch (e) {
      return {'status': 'error', 'message': 'Terjadi kesalahan jaringan: $e'};
    }
  }

  static Future<Map<String, dynamic>> register(Map<String, dynamic> dataRegistrasi) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register.php'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(dataRegistrasi),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'status': 'error', 'message': 'Gagal terhubung ke server (${response.statusCode})'};
    } catch (e) {
      return {'status': 'error', 'message': 'Terjadi kesalahan jaringan: $e'};
    }
  }
}
