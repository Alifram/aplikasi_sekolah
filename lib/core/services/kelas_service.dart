import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_error_message.dart';

class KelasService {
  static Future<Map<String, dynamic>> ambilTemanSekelas(int kelasId) async {
    if (kelasId <= 0) {
      return {
        'status': 'error',
        'message': 'ID kelas tidak valid.',
      };
    }

    try {
      final response = await Supabase.instance.client.rpc(
        'get_classmates',
        params: {'p_kelas_id': kelasId},
      );
      if (response is Map &&
          response['status'] == 'success' &&
          response['data'] is List) {
        return Map<String, dynamic>.from(response);
      }
      return {
        'status': 'error',
        'message': 'Respons daftar teman sekelas tidak valid.',
      };
    } on PostgrestException catch (error) {
      return {
        'status': 'error',
        'message': AppErrorMessage.fromPostgrest(
          error,
          fallback: 'Data teman sekelas belum dapat dimuat. Silakan coba lagi.',
        ),
      };
    } catch (error) {
      return {
        'status': 'error',
        'message': AppErrorMessage.from(
          error,
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
