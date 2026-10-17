import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class NilaiService {
  static const String baseUrl = ApiConfig.baseUrl;
  static final Map<String, List<Map<String, dynamic>>>
      _penugasanCacheByGuru = {};

  static Map<String, dynamic> _decodeResponse(
    http.Response response, {
    required String fallbackMessage,
  }) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic> &&
          response.statusCode >= 200 &&
          response.statusCode < 300) {
        return decoded;
      }
      if (decoded is Map<String, dynamic>) {
        return {
          ...decoded,
          'status': 'error',
          'message':
              decoded['message'] ??
              '$fallbackMessage (HTTP ${response.statusCode}).',
        };
      }
      return {'status': 'error', 'message': fallbackMessage};
    } on FormatException {
      return {'status': 'error', 'message': fallbackMessage};
    }
  }

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
      final uri = Uri.parse(
        '$baseUrl/get_kelas_mapel.php',
      ).replace(queryParameters: {'guru_id': guruId});
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      final result = _decodeResponse(
        response,
        fallbackMessage:
            'Gagal memuat penugasan mapel (HTTP ${response.statusCode}).',
      );
      final assignments = result['data'];
      if (result['status'] == 'success' && assignments is List) {
        final parsedAssignments = assignments
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        _penugasanCacheByGuru[guruId] = parsedAssignments;
        return {
          ...result,
          'data': parsedAssignments
              .map((assignment) => Map<String, dynamic>.from(assignment))
              .toList(),
        };
      }
      return result;
    } catch (e) {
      return {'status': 'error', 'message': 'Terjadi kesalahan koneksi: $e'};
    }
  }

  static Future<Map<String, dynamic>> ambilSiswa(int kelasId) async {
    try {
      final uri = Uri.parse(
        '$baseUrl/get_siswa_by_kelas.php',
      ).replace(queryParameters: {'kelas_id': kelasId.toString()});
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      return _decodeResponse(
        response,
        fallbackMessage:
            'Gagal memuat daftar siswa (HTTP ${response.statusCode}).',
      );
    } catch (e) {
      return {'status': 'error', 'message': 'Terjadi kesalahan koneksi: $e'};
    }
  }

  static Future<Map<String, dynamic>> simpanNilai(
    Map<String, dynamic> dataNilai,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/add_nilai.php'),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode(dataNilai),
          )
          .timeout(const Duration(seconds: 15));
      return _decodeResponse(
        response,
        fallbackMessage: 'Gagal menyimpan nilai (HTTP ${response.statusCode}).',
      );
    } catch (e) {
      return {'status': 'error', 'message': 'Terjadi kesalahan koneksi: $e'};
    }
  }

  static Future<Map<String, dynamic>> ambilRaporSiswa(String idSiswa) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/get_rapor_siswa.php?siswa_id=$idSiswa'),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {
        'status': 'error',
        'message': 'Gagal memuat lembar rapor dari server',
      };
    } catch (e) {
      return {'status': 'error', 'message': 'Terjadi kesalahan koneksi: $e'};
    }
  }
}
