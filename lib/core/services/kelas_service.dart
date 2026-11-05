import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'api_config.dart';
import 'app_error_message.dart';

class KelasService {
  static const String baseUrl = ApiConfig.baseUrl;

  // Fungsi khusus untuk mengambil daftar teman sekelas dari backend PHP
  static Future<Map<String, dynamic>> ambilTemanSekelas(int kelasId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/get_teman_sekelas.php?kelas_id=$kelasId'),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {
        'status': 'error',
        'message': 'Gagal memuat data kelas dari server',
      };
    } catch (e) {
      return {
        'status': 'error',
        'message': AppErrorMessage.from(
          e,
          fallback: 'Data teman sekelas belum dapat dimuat. Silakan coba lagi.',
        ),
      };
    }
  }

  static Future<Map<String, dynamic>> ambilDaftarKelas() async {
    try {
      final response = await Supabase.instance.client
          .from('kelas')
          .select('id, nama')
          .eq('aktif', true)
          .order('nama');
      return {'status': 'success', 'data': response};
    } on PostgrestException catch (error) {
      return {
        'status': 'error',
        'message': AppErrorMessage.fromPostgrest(
          error,
          fallback: 'Daftar kelas belum dapat dimuat. Silakan coba lagi.',
        ),
      };
    } catch (e) {
      return {
        'status': 'error',
        'message': AppErrorMessage.from(
          e,
          fallback: 'Daftar kelas belum dapat dimuat. Silakan coba lagi.',
        ),
      };
    }
  }
}
