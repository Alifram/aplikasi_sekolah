import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static const String baseUrl = ApiConfig.baseUrl;

  static Future<Map<String, dynamic>> login(String identifier, String password) async {
    try {
      final normalizedIdentifier = identifier.trim();
      if (normalizedIdentifier.isEmpty || password.isEmpty) {
        return {
          'status': 'error',
          'message': 'Nomor induk/email dan password wajib diisi.',
        };
      }

      final client = Supabase.instance.client;
      User? authenticatedUser;
      if (normalizedIdentifier.contains('@')) {
        final authResponse = await client.auth.signInWithPassword(
          email: normalizedIdentifier.toLowerCase(),
          password: password,
        );
        authenticatedUser = authResponse.user;
      } else {
        final response = await client.functions.invoke(
          'login-by-identifier',
          body: {
            'identifier': normalizedIdentifier,
            'password': password,
          },
        );
        final authData = response.data;
        if (authData is! Map ||
            authData['refresh_token'] is! String ||
            (response.status < 200 || response.status >= 300)) {
          final message = authData is Map
              ? authData['message']?.toString()
              : null;
          return {
            'status': 'error',
            'message': message ?? 'Login dengan nomor induk gagal.',
          };
        }
        final session = await client.auth.setSession(
          authData['refresh_token'] as String,
        );
        authenticatedUser = session.user;
      }

      if (authenticatedUser == null) {
        return {'status': 'error', 'message': 'Sesi login tidak berhasil dibuat.'};
      }

      Map<String, dynamic>? profile;
      try {
        profile = await _loadProfile(authenticatedUser.id);
      } catch (_) {
        await client.auth.signOut();
        rethrow;
      }
      if (profile == null) {
        await client.auth.signOut();
        return {
          'status': 'error',
          'message':
              'Profil akun belum terhubung. Hubungi admin untuk memeriksa profil Supabase.',
        };
      }

      await _saveProfileLocally(profile);
      return {'status': 'success', 'user': profile};
    } on AuthException catch (error) {
      return {
        'status': 'error',
        'message': error.message,
      };
    } on PostgrestException catch (error) {
      return {
        'status': 'error',
        'message': 'Gagal memuat profil akun: ${error.message}',
      };
    } on FunctionException catch (error) {
      final details = error.details;
      final message = details is Map
          ? details['message']?.toString()
          : null;
      return {
        'status': 'error',
        'message': message ?? 'Login dengan nomor induk gagal. Periksa deployment Edge Function.',
      };
    } catch (e) {
      return {'status': 'error', 'message': 'Gagal login ke Supabase: $e'};
    }
  }

  static Future<Map<String, dynamic>?> _loadProfile(String authUserId) async {
    final client = Supabase.instance.client;
    final profile = await client
        .from('users')
        .select(
          'id, auth_user_id, nomor_induk, nama_lengkap, email, role, '
          'jenis_guru, kelas_id, tahun_angkatan, is_deleted',
        )
        .eq('auth_user_id', authUserId)
        .maybeSingle();
    if (profile == null || profile['is_deleted'] == 1) return null;

    final classId = profile['kelas_id'];
    String className = 'Belum Diatur';
    if (classId != null) {
      final classRow = await client
          .from('kelas')
          .select('nama')
          .eq('id', classId)
          .maybeSingle();
      className = classRow?['nama']?.toString() ?? className;
    }

    return {
      ...profile,
      'id': profile['id'].toString(),
      'kelas_id': classId?.toString(),
      'kelas_nama': className,
      'kelas_diajar': className,
    };
  }

  static Future<void> _saveProfileLocally(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_login', true);
    await prefs.setString('user_id', user['id'].toString());
    await prefs.setString('auth_user_id', user['auth_user_id'].toString());
    await prefs.setString('nomor_induk', user['nomor_induk']?.toString() ?? '');
    await prefs.setString('nama_lengkap', user['nama_lengkap']?.toString() ?? '');
    await prefs.setString('role', user['role']?.toString() ?? 'siswa');
    final classId = user['kelas_id'];
    if (classId == null) {
      await prefs.remove('kelas_id');
    } else {
      await prefs.setString('kelas_id', classId.toString());
    }
    await prefs.setString(
      'kelas_nama',
      user['kelas_nama']?.toString() ?? 'Belum Diatur',
    );
  }

  static Future<Map<String, dynamic>?> currentUserProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;
    final profile = await _loadProfile(user.id);
    if (profile != null) await _saveProfileLocally(profile);
    return profile;
  }

  static Future<Map<String, dynamic>> register(Map<String, dynamic> dataRegistrasi) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register.php'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(dataRegistrasi),
      );

      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        if (response.statusCode >= 200 &&
            response.statusCode < 300) {
          return decoded;
        }
        return {
          ...decoded,
          'status': 'error',
          'message': decoded['message'] ??
              'Pendaftaran gagal (HTTP ${response.statusCode}).',
        };
      }
      return {
        'status': 'error',
        'message': 'Respons pendaftaran tidak valid (HTTP ${response.statusCode}).',
      };
    } catch (e) {
      return {'status': 'error', 'message': 'Terjadi kesalahan jaringan: $e'};
    }
  }

  static Future<Map<String, dynamic>> gantiPassword(Map<String, dynamic> dataInput) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/change_password.php'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(dataInput),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {"status": "error", "message": "Kesalahan koneksi sistem: $e"};
    }
  }

  static Future<bool> logout() async {
    await Supabase.instance.client.auth.signOut();
    final prefs = await SharedPreferences.getInstance();
    return await prefs.clear();
  }
}