import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'app_error_message.dart';

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
        "message": AppErrorMessage.from(
          e,
          fallback: "Perubahan data akun belum berhasil. Silakan coba lagi.",
        )
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
      return {
        "status": "error",
        "message": AppErrorMessage.from(
          e,
          fallback: "Akun belum berhasil dihapus. Silakan coba lagi.",
        ),
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
      return {
        "status": "error",
        "message": AppErrorMessage.from(
          e,
          fallback: "Ringkasan belum dapat dimuat. Silakan coba lagi.",
        ),
      };
    }
  }

}
