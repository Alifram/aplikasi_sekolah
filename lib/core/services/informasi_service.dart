import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_error_message.dart';

class InformasiService {
  static const String _imageBucket = 'school-events';
  static final SupabaseClient _supabase = Supabase.instance.client;

  static Map<String, dynamic> _asResponse(dynamic response) {
    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }
    return {
      'status': 'error',
      'message': 'Format respons Supabase tidak valid.',
    };
  }

  static Map<String, dynamic> _errorResponse(
    PostgrestException error, {
    required String fallback,
  }) => {
    'status': 'error',
    'message': AppErrorMessage.fromPostgrest(error, fallback: fallback),
  };

  static Future<Map<String, dynamic>> ambilAcara() async {
    try {
      final response = _asResponse(await _supabase.rpc('get_events'));
      final rawEvents = response['data'];
      if (response['status'] != 'success' || rawEvents is! List) {
        return response;
      }

      final events = <dynamic>[];
      for (final rawEvent in rawEvents) {
        if (rawEvent is! Map) {
          events.add(rawEvent);
          continue;
        }

        final event = Map<String, dynamic>.from(rawEvent);
        final imagePath = event['gambar_url']?.toString();
        if (imagePath != null && imagePath.isNotEmpty) {
          event['gambar_signed_url'] = await _supabase.storage
              .from(_imageBucket)
              .createSignedUrl(imagePath, 3600);
        }
        events.add(event);
      }
      return {...response, 'data': events};
    } on PostgrestException catch (error) {
      return _errorResponse(
        error,
        fallback: 'Informasi kegiatan belum dapat dimuat. Silakan coba lagi.',
      );
    } on StorageException catch (error) {
      return {
        'status': 'error',
        'message': AppErrorMessage.from(
          error,
          fallback: 'Gambar kegiatan belum dapat dimuat. Silakan coba lagi.',
        ),
      };
    }
  }

  static Future<Map<String, dynamic>> unggahGambarAcara({
    required Uint8List bytes,
    required String extension,
    required String contentType,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      return {'status': 'error', 'message': 'Sesi pengguna tidak ditemukan.'};
    }

    final path = '$userId/${DateTime.now().microsecondsSinceEpoch}.$extension';
    try {
      await _supabase.storage.from(_imageBucket).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: contentType, upsert: false),
          );
      return {'status': 'success', 'path': path};
    } on StorageException catch (error) {
      return {
        'status': 'error',
        'message': AppErrorMessage.from(
          error,
          fallback: 'Gambar belum berhasil diunggah. Silakan coba lagi.',
        ),
      };
    }
  }

  static Future<String?> hapusGambarAcara(String path) async {
    try {
      await _supabase.storage.from(_imageBucket).remove([path]);
      return null;
    } on StorageException catch (error) {
      return AppErrorMessage.from(
        error,
        fallback: 'Gambar belum dapat dihapus. Silakan coba lagi.',
      );
    }
  }

  static Future<Map<String, dynamic>> tambahAcara(
    Map<String, dynamic> dataAcara,
  ) async {
    try {
      return _asResponse(
        await _supabase.rpc(
          'create_event',
          params: {
            'p_title': dataAcara['judul_acara'],
            'p_description': dataAcara['deskripsi'],
            'p_all_classes': dataAcara['semua_kelas'],
            'p_class_ids': dataAcara['kelas_ids'],
            'p_event_date': dataAcara['tanggal_acara'],
            'p_image_path': dataAcara['gambar_path'],
          },
        ),
      );
    } on PostgrestException catch (error) {
      return _errorResponse(
        error,
        fallback: 'Informasi kegiatan belum berhasil disimpan. Silakan coba lagi.',
      );
    }
  }

  static Future<Map<String, dynamic>> hapusAcara({
    required String eventId,
    String? imagePath,
  }) async {
    try {
      final response = _asResponse(
        await _supabase.rpc(
          'delete_event',
          params: {'p_event_id': int.parse(eventId)},
        ),
      );
      if (response['status'] != 'success' || imagePath == null) {
        return response;
      }

      final cleanupError = await hapusGambarAcara(imagePath);
      if (cleanupError != null) {
        return {
          ...response,
          'message': '${response['message']} Gambar tidak dapat dihapus: $cleanupError',
        };
      }
      return response;
    } on FormatException {
      return {'status': 'error', 'message': 'ID event tidak valid.'};
    } on PostgrestException catch (error) {
      return _errorResponse(
        error,
        fallback: 'Kegiatan belum dapat dihapus. Silakan coba lagi.',
      );
    }
  }

  static Future<Map<String, dynamic>> ambilKomentar(String eventId) async {
    try {
      return _asResponse(
        await _supabase.rpc(
          'get_event_comments',
          params: {'p_event_id': int.parse(eventId)},
        ),
      );
    } on FormatException {
      return {'status': 'error', 'message': 'ID event tidak valid.'};
    } on PostgrestException catch (error) {
      return _errorResponse(
        error,
        fallback: 'Komentar belum dapat dimuat. Silakan coba lagi.',
      );
    }
  }

  static Future<Map<String, dynamic>> kirimKomentar(
    Map<String, dynamic> dataKomentar,
  ) async {
    try {
      return _asResponse(
        await _supabase.rpc(
          'add_event_comment',
          params: {
            'p_event_id': int.parse(dataKomentar['event_id'].toString()),
            'p_comment': dataKomentar['isi_komentar'],
          },
        ),
      );
    } on FormatException {
      return {'status': 'error', 'message': 'ID event tidak valid.'};
    } on PostgrestException catch (error) {
      return _errorResponse(
        error,
        fallback: 'Komentar belum berhasil dikirim. Silakan coba lagi.',
      );
    }
  }
}
