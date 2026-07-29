import 'dart:convert';
import 'package:http/http.dart' as http;

class DashboardService {
  static const String baseUrl = 'http://localhost:8000';

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

  static Future<Map<String, dynamic>> ambilStatistik() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/get_statistik.php'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'status': 'error', 'message': 'Gagal memuat data statistik.'};
    } catch (e) {
      return {'status': 'error', 'message': 'Kesalahan jaringan: $e'};
    }
  }
}
