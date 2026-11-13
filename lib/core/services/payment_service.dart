import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_error_message.dart';

class PaymentService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  static Future<Map<String, dynamic>> _call(
    String function, {
    Map<String, dynamic>? params,
  }) async {
    try {
      final response = await _supabase.rpc(function, params: params);
      if (response is Map && response['status'] == 'success') {
        return Map<String, dynamic>.from(response);
      }
      return {
        'status': 'error',
        'message': 'Respons layanan pembayaran tidak valid.',
      };
    } on PostgrestException catch (error) {
      return {
        'status': 'error',
        'message': AppErrorMessage.fromPostgrest(
          error,
          fallback: 'Layanan pembayaran belum dapat digunakan.',
        ),
      };
    } catch (error) {
      return {
        'status': 'error',
        'message': AppErrorMessage.from(
          error,
          fallback: 'Layanan pembayaran belum dapat digunakan.',
        ),
      };
    }
  }

  static Future<Map<String, dynamic>> getMyLinkedStudents() =>
      _call('get_my_linked_students');

  static Future<Map<String, dynamic>> getPaymentStudents() =>
      _call('get_payment_students');

  static Future<Map<String, dynamic>> getMyCategories() =>
      _call('get_my_payment_categories');

  static Future<Map<String, dynamic>> getMonthlyReport({
    required int year,
    required int month,
    int? studentUserId,
  }) => _call(
    'get_monthly_payment_report',
    params: {
      'p_year': year,
      'p_month': month,
      'p_student_user_id': studentUserId,
    },
  );

  static Future<Map<String, dynamic>> recordTransaction({
    required int studentUserId,
    required String categoryCode,
    required num amount,
    required DateTime paidAt,
    String? note,
  }) => _call(
    'record_payment_transaction',
    params: {
      'p_student_user_id': studentUserId,
      'p_category_code': categoryCode,
      'p_amount': amount,
      'p_paid_at':
          '${paidAt.year.toString().padLeft(4, '0')}-'
          '${paidAt.month.toString().padLeft(2, '0')}-'
          '${paidAt.day.toString().padLeft(2, '0')}',
      'p_note': note,
    },
  );
}
