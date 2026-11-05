import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_error_message.dart';

class NilaiService {
  static final Map<String, List<Map<String, dynamic>>> _penugasanCacheByGuru =
      {};

  static Future<Map<String, dynamic>> ambilPenugasanMapel({
    required String guruId,
    bool forceRefresh = false,
  }) async {
    final cachedAssignments = _penugasanCacheByGuru[guruId];
    if (!forceRefresh && cachedAssignments != null) {
      return {
        'status': 'success',
        'data': cachedAssignments
            .map((assignment) => Map<String, dynamic>.from(assignment))
            .toList(),
      };
    }

    try {
      final response = await Supabase.instance.client.rpc(
        'get_teacher_grade_assignments',
      );
      final result = _asResult(
        response,
        'Respons penugasan mapel tidak valid.',
      );
      final assignments = result['data'];
      if (result['status'] == 'success' && assignments is List) {
        final parsedAssignments = assignments
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        _penugasanCacheByGuru[guruId] = parsedAssignments;
        return {...result, 'data': parsedAssignments};
      }
      return result;
    } on PostgrestException catch (error) {
      return {
        'status': 'error',
        'message': AppErrorMessage.fromPostgrest(
          error,
          fallback: 'Penugasan mata pelajaran belum dapat dimuat. Silakan coba lagi.',
        ),
      };
    } catch (error) {
      return {
        'status': 'error',
        'message': AppErrorMessage.from(
          error,
          fallback: 'Penugasan mata pelajaran belum dapat dimuat. Silakan coba lagi.',
        ),
      };
    }
  }

  static Future<Map<String, dynamic>> ambilSiswa(int kelasId) async {
    try {
      final response = await Supabase.instance.client.rpc(
        'get_grade_students',
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

  static Future<Map<String, dynamic>> simpanNilai(
    Map<String, dynamic> dataNilai,
  ) async {
    try {
      final score = num.tryParse(dataNilai['skor_nilai']?.toString() ?? '');
      final response = await Supabase.instance.client.rpc(
        'save_legacy_grade',
        params: {
          'p_siswa_id': int.tryParse(dataNilai['siswa_id']?.toString() ?? ''),
          'p_kelas_mapel_id': int.tryParse(
            dataNilai['kelas_mapel_id']?.toString() ?? '',
          ),
          'p_semester': dataNilai['semester']?.toString(),
          'p_jenis_nilai': dataNilai['jenis_nilai']?.toString(),
          'p_skor_nilai': score,
          'p_keterangan': dataNilai['keterangan']?.toString(),
        },
      );
      if (response is! Map || response['status'] != 'success') {
        return {
          'status': 'error',
          'message': 'Respons penyimpanan nilai tidak valid.',
        };
      }
      return Map<String, dynamic>.from(response);
    } on PostgrestException catch (error) {
      return {
        'status': 'error',
        'message': AppErrorMessage.fromPostgrest(
          error,
          fallback: 'Nilai belum berhasil disimpan. Silakan coba lagi.',
        ),
      };
    } catch (error) {
      return {
        'status': 'error',
        'message': AppErrorMessage.from(
          error,
          fallback: 'Nilai belum berhasil disimpan. Silakan coba lagi.',
        ),
      };
    }
  }

  static Future<Map<String, dynamic>> ambilRaporSiswa() async {
    try {
      final response = await Supabase.instance.client.rpc(
        'get_my_student_report',
      );
      return _asResult(response, 'Respons rapor siswa tidak valid.');
    } on PostgrestException catch (error) {
      return {
        'status': 'error',
        'message': AppErrorMessage.fromPostgrest(
          error,
          fallback: 'Rapor belum dapat dimuat. Silakan coba lagi.',
        ),
      };
    } catch (error) {
      return {
        'status': 'error',
        'message': AppErrorMessage.from(
          error,
          fallback: 'Rapor belum dapat dimuat. Silakan coba lagi.',
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
