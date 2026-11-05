import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

class AppErrorMessage {
  static String from(
    Object error, {
    required String fallback,
  }) {
    if (error is PostgrestException) {
      return fromPostgrest(error, fallback: fallback);
    }
    if (error is StorageException) {
      return 'Gambar belum dapat diproses. Silakan coba lagi.';
    }
    if (error is AuthException) {
      final message = error.message.toLowerCase();
      if (message.contains('invalid login credentials') ||
          message.contains('invalid_credentials')) {
        return 'Nomor induk/email atau kata sandi tidak sesuai.';
      }
      if (message.contains('already registered') ||
          message.contains('user already registered')) {
        return 'Email tersebut sudah terdaftar.';
      }
      if (message.contains('password') && message.contains('characters')) {
        return 'Kata sandi belum memenuhi ketentuan.';
      }
      return fallback;
    }
    if (error is TimeoutException) {
      return 'Koneksi terlalu lama. Periksa jaringan lalu coba lagi.';
    }
    return fallback;
  }

  static String fromPostgrest(
    PostgrestException error, {
    required String fallback,
  }) {
    switch (error.code) {
      case '23P01':
        return 'Jadwal berbenturan dengan jadwal lain. Pilih hari atau jam yang berbeda.';
      case '23505':
        return 'Data tersebut sudah terdaftar. Periksa kembali lalu coba lagi.';
      case '23503':
        return 'Data masih digunakan dan tidak dapat diproses.';
      case '42501':
        return 'Anda tidak memiliki izin untuk melakukan tindakan ini.';
      case '22023':
        return 'Data belum valid. Periksa kembali isian Anda.';
      case 'P0002':
        return 'Data yang diminta tidak ditemukan. Muat ulang lalu coba lagi.';
      case '57014':
        return 'Permintaan memerlukan waktu terlalu lama. Silakan coba lagi.';
      default:
        return fallback;
    }
  }
}
