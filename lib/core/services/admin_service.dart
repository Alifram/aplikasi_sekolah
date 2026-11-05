import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_error_message.dart';

class AdminService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  static Future<Map<String, dynamic>> ambilSemuaPengguna() async {
    try {
      final response = await _supabase.rpc('get_admin_users');
      if (response is! Map ||
          response['status'] != 'success' ||
          response['data'] is! List) {
        return {
          'status': 'error',
          'message': 'Data pengguna belum dapat dimuat. Silakan coba lagi.',
        };
      }
      return Map<String, dynamic>.from(response);
    } on PostgrestException catch (error) {
      return {
        'status': 'error',
        'message': AppErrorMessage.fromPostgrest(
          error,
          fallback: 'Data pengguna belum dapat dimuat. Silakan coba lagi.',
        ),
      };
    } catch (error) {
      return {
        'status': 'error',
        'message': AppErrorMessage.from(
          error,
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
      final response = await _supabase.rpc(
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
    } catch (error) {
      return {
        'status': 'error',
        'message': AppErrorMessage.from(
          error,
          fallback: 'Riwayat nilai belum dapat dimuat. Silakan coba lagi.',
        ),
      };
    }
  }

  static Future<Map<String, dynamic>> perbaruiDataPengguna(
    Map<String, dynamic> dataInput,
  ) {
    final payload = <String, dynamic>{
      'action': 'update',
      'user_id': int.tryParse(dataInput['id_user']?.toString() ?? ''),
      'nama_lengkap': dataInput['nama_lengkap'],
      'email': dataInput['email'],
      'kelas_id': dataInput['kelas_id'],
      'password_baru': dataInput['password_baru'],
    };
    if (dataInput['role'] == 'siswa') {
      payload['tahun_angkatan'] = dataInput['tahun_angkatan'];
    }
    return _kelolaAkun(payload);
  }

  static Future<Map<String, dynamic>> hapusAkunUser(String idUser) =>
      _kelolaAkun({
        'action': 'delete',
        'user_id': int.tryParse(idUser),
      });

  static Future<Map<String, dynamic>> ubahStatusAksesAkun(
    String idUser,
    int statusBaru,
  ) => _kelolaAkun({
    'action': 'set_status',
    'user_id': int.tryParse(idUser),
    'status': statusBaru,
  });

  static Future<Map<String, dynamic>> _kelolaAkun(
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _supabase.functions.invoke(
        'admin-manage-user',
        body: body,
      );
      final data = response.data;
      if (data is Map) {
        final result = Map<String, dynamic>.from(data);
        if (response.status >= 200 && response.status < 300) {
          return {...result, 'status': 'success'};
        }
        return {
          ...result,
          'status': 'error',
          'message': result['message']?.toString() ??
              'Perubahan akun belum berhasil. Silakan coba lagi.',
        };
      }
      return {
        'status': 'error',
        'message': 'Respons layanan akun tidak valid. Silakan coba lagi.',
      };
    } on FunctionException catch (error) {
      final details = error.details;
      final message = details is Map
          ? details['message']?.toString()
          : null;
      return {
        'status': 'error',
        'message': message ??
            'Layanan akun belum dapat dihubungi. Silakan coba lagi.',
      };
    } catch (error) {
      return {
        'status': 'error',
        'message': AppErrorMessage.from(
          error,
          fallback: 'Layanan akun belum dapat dihubungi. Silakan coba lagi.',
        ),
      };
    }
  }

  static Future<Map<String, dynamic>> prosesPindahKelas(
    String userId,
    int kelasId,
  ) async {
    try {
      final response = await _supabase.rpc(
        'admin_move_user_class',
        params: {
          'p_user_id': int.tryParse(userId),
          'p_kelas_id': kelasId,
        },
      );
      if (response is Map) return Map<String, dynamic>.from(response);
      return {
        'status': 'error',
        'message': 'Respons pemindahan kelas tidak valid.',
      };
    } on PostgrestException catch (error) {
      return {
        'status': 'error',
        'message': AppErrorMessage.fromPostgrest(
          error,
          fallback: 'Pemindahan kelas belum berhasil. Silakan coba lagi.',
        ),
      };
    } catch (error) {
      return {
        'status': 'error',
        'message': AppErrorMessage.from(
          error,
          fallback: 'Pemindahan kelas belum berhasil. Silakan coba lagi.',
        ),
      };
    }
  }

  static Future<Map<String, dynamic>> prosesKenaikanKelasMassal() async {
    try {
      final response = await _supabase.rpc('admin_promote_students');
      if (response is Map) return Map<String, dynamic>.from(response);
      return {
        'status': 'error',
        'message': 'Respons kenaikan kelas tidak valid.',
      };
    } on PostgrestException catch (error) {
      return {
        'status': 'error',
        'message': AppErrorMessage.fromPostgrest(
          error,
          fallback: 'Kenaikan kelas belum berhasil. Silakan coba lagi.',
        ),
      };
    } catch (error) {
      return {
        'status': 'error',
        'message': AppErrorMessage.from(
          error,
          fallback: 'Kenaikan kelas belum berhasil. Silakan coba lagi.',
        ),
      };
    }
  }
}
