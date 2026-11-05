import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';
import 'app_error_message.dart';

class AdminService {
  static const String baseUrl = ApiConfig.baseUrl;

  // Fungsi khusus untuk menarik seluruh data pengguna sekolah (Admin, Guru, Siswa)
  static Future<Map<String, dynamic>> ambilSemuaPengguna() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/get_users.php'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'status': 'error', 'message': 'Gagal memuat database pengguna.'};
    } catch (e) {
      return {
        'status': 'error',
        'message': AppErrorMessage.from(
          e,
          fallback: 'Data pengguna belum dapat dimuat. Silakan coba lagi.',
        ),
      };
    }
  }

  static Future<Map<String, dynamic>> ambilDataNilai(
    String userId,
    String role,
  ) async {
    try {
      final response = await Supabase.instance.client.rpc(
        'get_admin_grade_history',
        params: {'p_target_user_id': int.tryParse(userId)},
      );
      if (response is! Map ||
          response['status'] != 'success' ||
          response['data'] is! List ||
          response['type']?.toString() != role) {
        return {
          'status': 'error',
          'message': 'Respons riwayat nilai Supabase tidak valid.',
        };
      }
      return Map<String, dynamic>.from(response);
    } on PostgrestException catch (error) {
      return {
        'status': 'error',
        'message': AppErrorMessage.fromPostgrest(
          error,
          fallback: 'Riwayat nilai belum dapat dimuat. Silakan coba lagi.',
        ),
      };
    } catch (e) {
      return {
        'status': 'error',
        'message': AppErrorMessage.from(
          e,
          fallback: 'Riwayat nilai belum dapat dimuat. Silakan coba lagi.',
        ),
      };
    }
  }

  static Future<Map<String, dynamic>> prosesPindahKelas(
    String adminId,
    String userId,
    int kelasId,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/pindah_kelas.php'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "user_id": userId,
          "admin_id": adminId,
          "kelas_id_baru": kelasId,
        }),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'status': 'error', 'message': 'Gagal memperbarui data kelas.'};
    } catch (e) {
      return {
        'status': 'error',
        'message': AppErrorMessage.from(
          e,
          fallback: 'Perubahan kelas belum berhasil. Silakan coba lagi.',
        ),
      };
    }
  }

  static Future<Map<String, dynamic>> ubahStatusAksesAkun(
    String idUser,
    int statusBaru,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/ubah_status_akses.php'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"user_id": idUser, "status_baru": statusBaru}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {
        'status': 'error',
        'message': 'Gagal merespons server (${response.statusCode})',
      };
    } catch (e) {
      return {
        'status': 'error',
        'message': AppErrorMessage.from(
          e,
          fallback: 'Status akun belum berhasil diperbarui. Silakan coba lagi.',
        ),
      };
    }
  }

  static Future<Map<String, dynamic>> prosesKenaikanKelasMassal() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final userId = preferences.getString('user_id');
      if (userId == null || userId.isEmpty) {
        return {'status': 'error', 'message': 'Sesi admin tidak ditemukan.'};
      }
      final response = await http.post(
        Uri.parse('$baseUrl/naik_kelas_massal.php'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({'user_id': userId}),
      );

      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return decoded;
        }
        return {
          ...decoded,
          'status': 'error',
          'message':
              decoded['message'] ??
              'Gagal memproses kenaikan kelas (${response.statusCode}).',
        };
      }
      return {
        'status': 'error',
        'message':
            'Respons kenaikan kelas tidak valid (${response.statusCode}).',
      };
    } on FormatException {
      return {
        'status': 'error',
        'message': 'Server mengirim respons kenaikan kelas yang tidak valid.',
      };
    } catch (e) {
      return {
        'status': 'error',
        'message': AppErrorMessage.from(
          e,
          fallback: 'Kenaikan kelas belum berhasil diproses. Silakan coba lagi.',
        ),
      };
    }
  }
}
