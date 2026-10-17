import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';

class PresensiService {
  static const String _baseUrl = ApiConfig.baseUrl;
  static const Duration _timeout = Duration(seconds: 20);

  static Future<Map<String, dynamic>> ambilSiswa(int kelasId) async {
    try {
      final uri = Uri.parse('$_baseUrl/get_siswa_by_kelas.php')
          .replace(queryParameters: {'kelas_id': kelasId.toString()});
      final response = await http.get(uri).timeout(_timeout);
      return _decodeResponse(response);
    } catch (error) {
      return {
        'status': 'error',
        'message': 'Gagal memuat daftar siswa: $error',
      };
    }
  }

  static Future<Map<String, dynamic>> ambilPresensi({
    required String userId,
    int? kelasId,
    String? tanggal,
  }) async {
    try {
      final query = <String, String>{'user_id': userId};
      if (kelasId != null) query['kelas_id'] = kelasId.toString();
      if (tanggal != null && tanggal.isNotEmpty) query['tanggal'] = tanggal;
      final uri = Uri.parse('$_baseUrl/get_presensi.php')
          .replace(queryParameters: query);
      final response = await http.get(uri).timeout(_timeout);
      return _decodeResponse(response);
    } catch (error) {
      return {
        'status': 'error',
        'message': 'Gagal memuat data presensi: $error',
      };
    }
  }

  static Future<Map<String, dynamic>> simpanPresensi({
    required String userId,
    required int kelasId,
    required String tanggal,
    required List<Map<String, dynamic>> presensi,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/save_presensi.php'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'user_id': userId,
              'kelas_id': kelasId,
              'tanggal': tanggal,
              'presensi': presensi,
            }),
          )
          .timeout(_timeout);
      return _decodeResponse(response);
    } catch (error) {
      return {
        'status': 'error',
        'message': 'Gagal menyimpan presensi: $error',
      };
    }
  }

  static Map<String, dynamic> _decodeResponse(http.Response response) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      return {
        'status': 'error',
        'message': 'Server mengirim respons yang tidak valid '
            '(HTTP ${response.statusCode}).',
      };
    }

    if (decoded is! Map<String, dynamic>) {
      return {
        'status': 'error',
        'message': 'Format respons server tidak dikenali.',
      };
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return {
        ...decoded,
        'status': 'error',
        'message': decoded['message'] ??
            'Permintaan gagal (HTTP ${response.statusCode}).',
      };
    }
    return decoded;
  }
}
