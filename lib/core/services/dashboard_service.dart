import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class DashboardService {
  static const String baseUrl = ApiConfig.baseUrl;

  static Future<Map<String, dynamic>> ambilAcaraTerbaru() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/get_events.php'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'status': 'error', 'message': 'Gagal memuat info acara.'};
    } catch (e) {
      return {'status': 'error', 'message': 'Kesalahan jaringan: $e'};
    }
  }

  static Future<Map<String, dynamic>> ambilStatistikBerdasarkanAngkatan(String angkatan) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/get_statistik.php?angkatan=$angkatan'),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'status': 'error', 'message': 'Gagal memuat data statistik angkatan.'};
    } catch (e) {
      return {'status': 'error', 'message': 'Kesalahan jaringan: $e'};
    }
  }
}
