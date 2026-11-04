import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_error_message.dart';

class PresensiService {
  static Future<Map<String, dynamic>> ambilSiswa(int kelasId) async {
    try {
      final response = await Supabase.instance.client.rpc(
        'get_attendance_students',
        params: {'p_kelas_id': kelasId},
      );
      return _asResult(response, 'Respons daftar siswa tidak valid.');
    } on PostgrestException catch (error) {
      return {
        'status': 'error',
        'message': AppErrorMessage.fromPostgrest(
          error,
          fallback: 'Daftar siswa belum dapat dimuat. Silakan coba lagi.',
        ),
      };
    } catch (error) {
      return {
        'status': 'error',
        'message': AppErrorMessage.from(
          error,
          fallback: 'Daftar siswa belum dapat dimuat. Silakan coba lagi.',
        ),
      };
    }
  }

  static Future<Map<String, dynamic>> ambilPresensi({
    int? kelasId,
    String? tanggal,
  }) async {
    try {
      final response = await Supabase.instance.client.rpc(
        'get_attendance',
        params: {'p_kelas_id': kelasId, 'p_tanggal': tanggal},
      );
      return _asResult(response, 'Respons data presensi tidak valid.');
    } on PostgrestException catch (error) {
      return {
        'status': 'error',
        'message': AppErrorMessage.fromPostgrest(
          error,
          fallback: 'Data presensi belum dapat dimuat. Silakan coba lagi.',
        ),
      };
    } catch (error) {
      return {
        'status': 'error',
        'message': AppErrorMessage.from(
          error,
          fallback: 'Data presensi belum dapat dimuat. Silakan coba lagi.',
        ),
      };
    }
  }

  static Future<Map<String, dynamic>> simpanPresensi({
    required int kelasId,
    required String tanggal,
    required List<Map<String, dynamic>> presensi,
  }) async {
    try {
      final response = await Supabase.instance.client.rpc(
        'save_attendance',
        params: {
          'p_kelas_id': kelasId,
          'p_tanggal': tanggal,
          'p_presensi': presensi,
        },
      );
      if (response is! Map) {
        return {
          'status': 'error',
          'message': 'Respons penyimpanan presensi tidak valid.',
        };
      }
      return Map<String, dynamic>.from(response);
    } on PostgrestException catch (error) {
      return {
        'status': 'error',
        'message': AppErrorMessage.fromPostgrest(
          error,
          fallback: 'Presensi belum berhasil disimpan. Silakan coba lagi.',
        ),
      };
    } catch (error) {
      return {
        'status': 'error',
        'message': AppErrorMessage.from(
          error,
          fallback: 'Presensi belum berhasil disimpan. Silakan coba lagi.',
        ),
      };
    }
  }

  static Map<String, dynamic> _asResult(dynamic response, String error) {
    if (response is! Map ||
        response['status'] != 'success' ||
        response['data'] is! List) {
      return {'status': 'error', 'message': error};
    }
    return Map<String, dynamic>.from(response);
  }
}
