import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';

class AuthService {
  static const String baseUrl = 'http://localhost:8000';

  static String _konversiKeMd5(String text) {
    return md5.convert(utf8.encode(text)).toString();
  }

  static Future<Map<String, dynamic>> login(String identifier, String password) async {
    try {
      final String passwordTerenkripsi = _konversiKeMd5(password);

      final response = await http.post(
        Uri.parse('$baseUrl/login.php'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "identifier": identifier,
          "password": passwordTerenkripsi, 
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> dataRespon = jsonDecode(response.body);
        
        if (dataRespon['status'] == 'success' && dataRespon['user'] != null) {
          final prefs = await SharedPreferences.getInstance();
          final user = dataRespon['user'];
          
          await prefs.setBool('is_login', true);
          await prefs.setString('user_id', user['id'].toString());
          await prefs.setString('nomor_induk', user['nomor_induk'] ?? '');
          await prefs.setString('nama_lengkap', user['nama_lengkap'] ?? '');
          await prefs.setString('role', user['role'] ?? 'siswa');
          await prefs.setString('kelas_diajar', user['kelas_diajar'] ?? 'Belum Diatur');
        }

        return dataRespon;
      }
      return {'status': 'error', 'message': 'Gagal terhubung ke server (${response.statusCode})'};
    } catch (e) {
      return {'status': 'error', 'message': 'Terjadi kesalahan jaringan: $e'};
    }
  }

  static Future<Map<String, dynamic>> register(Map<String, dynamic> dataRegistrasi) async {
    try {
      if (dataRegistrasi.containsKey('password')) {
        dataRegistrasi['password'] = _konversiKeMd5(dataRegistrasi['password']);
      }

      final response = await http.post(
        Uri.parse('$baseUrl/register.php'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(dataRegistrasi),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'status': 'error', 'message': 'Gagal terhubung ke server (${response.statusCode})'};
    } catch (e) {
      return {'status': 'error', 'message': 'Terjadi kesalahan jaringan: $e'};
    }
  }

  static Future<bool> logout() async {
    final prefs = await SharedPreferences.getInstance();
    return await prefs.clear();
  }
}