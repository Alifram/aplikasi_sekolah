import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'api_config.dart';

class DashboardService {
  static const String baseUrl = ApiConfig.baseUrl;

  static Future<Map<String, dynamic>> ambilRingkasanAdmin() async {
    try {
      final response = await Supabase.instance.client.rpc(
        'get_admin_dashboard_summary',
      );
      if (response is! Map) {
        return {
          'status': 'error',
          'message': 'Format ringkasan dashboard Supabase tidak valid.',
        };
      }

      final summary = Map<String, dynamic>.from(response);
      const requiredCounts = [
        'total_siswa',
        'total_guru',
        'total_kelas',
        'total_pengumuman',
      ];
      if (requiredCounts.any((key) => summary[key] is! num)) {
        return {
          'status': 'error',
          'message': 'Data ringkasan dashboard Supabase tidak lengkap.',
        };
      }

      return {'status': 'success', ...summary};
    } on PostgrestException catch (error) {
      return {'status': 'error', 'message': error.message};
    }
  }

  static Future<Map<String, dynamic>> ambilAcaraTerbaru() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/get_events.php'));
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return decoded;
        }
        return {
          ...decoded,
          'status': 'error',
          'message': decoded['message'] ?? 'Gagal memuat info acara.',
        };
      }
      return {
        'status': 'error',
        'message': 'Format respons event tidak valid.',
      };
    } on FormatException {
      return {'status': 'error', 'message': 'Gagal memuat info acara.'};
    } catch (e) {
      return {'status': 'error', 'message': 'Kesalahan jaringan: $e'};
    }
  }

  static Future<Map<String, dynamic>> ambilStatistikBerdasarkanAngkatan(
    String angkatan,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/get_statistik.php?angkatan=$angkatan'),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {
        'status': 'error',
        'message': 'Gagal memuat data statistik angkatan.',
      };
    } catch (e) {
      return {'status': 'error', 'message': 'Kesalahan jaringan: $e'};
    }
  }
}
