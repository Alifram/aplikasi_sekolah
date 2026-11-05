import 'package:supabase_flutter/supabase_flutter.dart';
import 'informasi_service.dart';
import 'app_error_message.dart';

class DashboardService {
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
      return {
        'status': 'error',
        'message': AppErrorMessage.fromPostgrest(
          error,
          fallback: 'Ringkasan beranda belum dapat dimuat. Silakan coba lagi.',
        ),
      };
    }
  }

  static Future<Map<String, dynamic>> ambilAcaraTerbaru() async {
    return InformasiService.ambilAcara();
  }

  static Future<Map<String, dynamic>> ambilStatistikBerdasarkanAngkatan(
    String angkatan,
  ) async {
    final admissionYear = int.tryParse(angkatan);
    if (admissionYear == null) {
      return {'status': 'error', 'message': 'Tahun angkatan tidak valid.'};
    }

    try {
      final response = await Supabase.instance.client.rpc(
        'get_academic_statistics',
        params: {'p_admission_year': admissionYear},
      );
      if (response is! Map ||
          response['status'] != 'success' ||
          response['data'] is! Map) {
        return {
          'status': 'error',
          'message': 'Format statistik akademik Supabase tidak valid.',
        };
      }
      return Map<String, dynamic>.from(response);
    } on PostgrestException catch (error) {
      return {
        'status': 'error',
        'message': AppErrorMessage.fromPostgrest(
          error,
          fallback: 'Statistik belum dapat dimuat. Silakan coba lagi.',
        ),
      };
    }
  }
}
