# Ringkasan Migrasi Kelas, Mapel, Jadwal, dan Nilai

Dokumen ini merangkum perubahan agar referensi kelas memakai `kelas.id`, sedangkan jadwal dan nilai memakai relasi `kelas_mapel_id`. Endpoint dan aplikasi mengasumsikan skema database telah dimigrasikan ke relasi tersebut.

## Perubahan API

- `get_kelas.php`: menyediakan kelas aktif (`id`, `nama`) untuk formulir aplikasi.
- `register.php`, `login.php`, `get_users.php`, dan `update_user.php`: membaca/menyimpan kelas melalui `users.kelas_id`.
- `get_siswa_by_kelas.php`, `get_teman_sekelas.php`, `save_presensi.php`, dan `get_presensi.php`: menerima serta memfilter data dengan `kelas_id`.
- `get_kelas_mapel.php`, `get_referensi_penugasan.php`, dan `get_jadwal_by_kelas.php`: memakai ID kelas untuk memfilter penugasan dan jadwal.
- `save_kelas_mapel.php`: memvalidasi admin, kelas, mapel, guru yang terdaftar pada kelas pilihan, tahun ajaran, dan duplikasi penugasan.
- `save_mata_pelajaran.php`: menambahkan mata pelajaran dengan validasi admin dan pemeriksaan kode/nama duplikat.
- `add_nilai.php`, `get_nilai.php`, `get_rapor_siswa.php`, dan `get_statistik.php`: menjadikan `kelas_mapel_id` sebagai sumber kelas/mapel; query nilai tidak lagi mengandalkan kolom `nilai_raport.kelas`.
- `add_event.php` dan `get_events.php`: menargetkan satu/beberapa kelas lewat `event_kelas` atau seluruh kelas lewat `events.target_semua_kelas`.
- `pindah_kelas.php` dan `naik_kelas_massal.php`: memperbarui `users.kelas_id`, bukan nama kelas pada kolom teks.

## Perubahan Flutter

- Registrasi, login, edit akun, dashboard, dan halaman data memakai ID serta nama kelas yang dikembalikan API.
- Presensi, jadwal, input nilai, dan daftar siswa mengirim `kelas_id`; nilai/jadwal memakai `kelas_mapel_id`.
- Form admin penugasan memfilter guru menurut kelas yang dipilih. Validasi kecocokan kelas juga dilakukan di server.
- Menu admin menyediakan akses terpisah ke penugasan mapel dan manajemen mata pelajaran.
- Setelah nilai berhasil disimpan, dashboard langsung memuat ulang statistik untuk angkatan siswa yang nilainya baru dimasukkan.
- Event mendukung pilihan beberapa kelas atau semua kelas dan difilter berdasarkan ID kelas akun.
- Daftar statistik kelas dibangun dinamis dari tabel `kelas`, bukan enam nama kelas yang ditulis di aplikasi.

## Prasyarat dan catatan migrasi

1. Database harus memiliki `users.kelas_id`, `presensi_sesi.kelas_id`, `jadwal_pelajaran.kelas_mapel_id`, dan `nilai_raport.kelas_mapel_id` dengan foreign key yang sesuai.
2. Jalankan `migrations/20261017_migrate_event_targets.sql` satu kali pada database yang sudah ada sebelum menggunakan CRUD event. Migrasi menambahkan `events.target_semua_kelas`, membuat `event_kelas`, memindahkan target kelas lama, dan membuat `target_kelas` nullable agar kompatibel selama transisi.
3. Backfill seluruh ID kelas/penugasan sebelum menghapus kolom teks lama. Pastikan setiap nilai lama mempunyai `kelas_mapel_id` valid agar rapor/statistik tetap tampil.
4. Kenaikan kelas massal memerlukan kelas aktif bernama `Kelas 1` sampai `Kelas 6` dan `Alumni`.
5. Guru untuk penugasan harus memiliki `users.kelas_id` yang sama dengan kelas penugasan.

## Validasi yang dijalankan

- `php -l` pada endpoint PHP yang diubah: berhasil tanpa syntax error.
- `git diff --check`: berhasil.
- `flutter analyze`: tidak ada error compile; analyzer masih melaporkan sejumlah info/warning proyek.
- `flutter build web --no-pub`: berhasil.
- Belum dilakukan pengujian API terhadap database live.
