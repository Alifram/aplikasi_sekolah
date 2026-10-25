<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");
header("Content-Type: application/json; charset=UTF-8");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

include "koneksi.php";
include "presensi_helpers.php";

$input = json_decode(file_get_contents('php://input'), true);
if (!is_array($input) ||
    !isset($input['user_id'], $input['kelas_id'], $input['tanggal'], $input['presensi']) ||
    !is_array($input['presensi'])) {
    presensi_send_json("error", "Data presensi tidak lengkap atau format JSON tidak valid.", 400);
    exit();
}

$actor = presensi_get_actor($koneksi, $input['user_id']);
if ($actor === false) {
    presensi_send_json("error", "Gagal memeriksa akun.", 500);
    exit();
}
if ($actor === null) {
    presensi_send_json("error", "Akun tidak valid atau tidak aktif.", 401);
    exit();
}
if (!in_array($actor['role'], ['guru', 'admin'], true)) {
    presensi_send_json("error", "Hanya guru atau admin yang dapat mengisi presensi.", 403);
    exit();
}

$classId = filter_var($input['kelas_id'], FILTER_VALIDATE_INT);
$date = $input['tanggal'];
if (!presensi_valid_class_id($classId) || !presensi_valid_date($date)) {
    presensi_send_json("error", "Kelas atau tanggal presensi tidak valid.", 400);
    exit();
}
if ($actor['role'] === 'guru' &&
    $date !== (new DateTimeImmutable('now', new DateTimeZone('Asia/Jakarta')))->format('Y-m-d')) {
    presensi_send_json("error", "Guru hanya dapat mengisi presensi untuk hari ini.", 400);
    exit();
}
if ($actor['role'] === 'guru' && (int)$actor['kelas_id'] !== (int)$classId) {
    presensi_send_json("error", "Guru hanya dapat mengisi presensi kelasnya.", 403);
    exit();
}

$classStmt = mysqli_prepare($koneksi, "SELECT id FROM kelas WHERE id = ? AND aktif = 1 LIMIT 1");
if ($classStmt === false) {
    presensi_send_json("error", "Gagal menyiapkan validasi kelas.", 500);
    exit();
}
mysqli_stmt_bind_param($classStmt, "i", $classId);
if (!mysqli_stmt_execute($classStmt)) {
    mysqli_stmt_close($classStmt);
    presensi_send_json("error", "Gagal memvalidasi kelas.", 500);
    exit();
}
$validClass = mysqli_num_rows(mysqli_stmt_get_result($classStmt)) === 1;
mysqli_stmt_close($classStmt);
if (!$validClass) {
    presensi_send_json("error", "Kelas tidak ditemukan atau tidak aktif.", 400);
    exit();
}

$entries = $input['presensi'];
if (count($entries) === 0) {
    presensi_send_json("error", "Daftar presensi siswa masih kosong.", 400);
    exit();
}

$allowedStatuses = ['Hadir', 'Sakit', 'Izin', 'Alpa'];
$seenStudents = [];
foreach ($entries as $entry) {
    if (!is_array($entry) ||
        !isset($entry['siswa_id'], $entry['status']) ||
        !is_scalar($entry['siswa_id']) ||
        !is_string($entry['status'])) {
        presensi_send_json("error", "Format data presensi siswa tidak valid.", 400);
        exit();
    }

    $studentId = filter_var($entry['siswa_id'], FILTER_VALIDATE_INT);
    if ($studentId === false || $studentId <= 0 ||
        !in_array($entry['status'], $allowedStatuses, true) ||
        isset($seenStudents[$studentId])) {
        presensi_send_json("error", "ID siswa ganda atau status presensi tidak valid.", 400);
        exit();
    }
    $note = $entry['catatan'] ?? '';
    if (!is_scalar($note)) {
        presensi_send_json("error", "Catatan presensi tidak valid.", 400);
        exit();
    }
    $seenStudents[$studentId] = true;
}

$classStudentsQuery = mysqli_prepare(
    $koneksi,
    "SELECT id FROM users
     WHERE role = 'siswa' AND kelas_id = ? AND is_deleted = 0
     ORDER BY id"
);
if ($classStudentsQuery === false) {
    presensi_send_json("error", "Gagal menyiapkan validasi daftar siswa.", 500);
    exit();
}
mysqli_stmt_bind_param($classStudentsQuery, "i", $classId);
if (!mysqli_stmt_execute($classStudentsQuery)) {
    mysqli_stmt_close($classStudentsQuery);
    presensi_send_json("error", "Gagal memvalidasi daftar siswa.", 500);
    exit();
}
$studentsResult = mysqli_stmt_get_result($classStudentsQuery);
$classStudentIds = [];
while ($student = mysqli_fetch_assoc($studentsResult)) {
    $classStudentIds[(int)$student['id']] = true;
}
mysqli_stmt_close($classStudentsQuery);

if (count($classStudentIds) === 0) {
    presensi_send_json("error", "Belum ada siswa aktif di kelas tersebut.", 400);
    exit();
}
if (count($seenStudents) !== count($classStudentIds) ||
    array_diff_key($classStudentIds, $seenStudents) !== []) {
    presensi_send_json("error", "Presensi harus mencakup seluruh siswa aktif di kelas.", 400);
    exit();
}

mysqli_begin_transaction($koneksi);
$teacherId = (int)$actor['id'];
$sessionStmt = mysqli_prepare(
    $koneksi,
    "INSERT INTO presensi_sesi (tanggal, kelas_id, guru_id)
     VALUES (?, ?, ?)
     ON DUPLICATE KEY UPDATE
       id = LAST_INSERT_ID(id),
       guru_id = VALUES(guru_id)"
);
if ($sessionStmt === false) {
    mysqli_rollback($koneksi);
    presensi_send_json("error", "Gagal menyiapkan sesi presensi.", 500);
    exit();
}
mysqli_stmt_bind_param($sessionStmt, "sii", $date, $classId, $teacherId);
if (!mysqli_stmt_execute($sessionStmt)) {
    mysqli_stmt_close($sessionStmt);
    mysqli_rollback($koneksi);
    presensi_send_json("error", "Gagal menyimpan sesi presensi.", 500);
    exit();
}
$sessionId = (int)mysqli_insert_id($koneksi);
mysqli_stmt_close($sessionStmt);

$detailStmt = mysqli_prepare(
    $koneksi,
    "INSERT INTO presensi_detail (sesi_id, siswa_id, status, catatan)
     VALUES (?, ?, ?, ?)
     ON DUPLICATE KEY UPDATE status = VALUES(status), catatan = VALUES(catatan)"
);
if ($detailStmt === false) {
    mysqli_rollback($koneksi);
    presensi_send_json("error", "Gagal menyiapkan data detail presensi.", 500);
    exit();
}

foreach ($entries as $entry) {
    $studentId = (int)$entry['siswa_id'];
    $status = $entry['status'];
    $note = trim((string)($entry['catatan'] ?? ''));
    mysqli_stmt_bind_param($detailStmt, "iiss", $sessionId, $studentId, $status, $note);
    if (!mysqli_stmt_execute($detailStmt)) {
        mysqli_stmt_close($detailStmt);
        mysqli_rollback($koneksi);
        presensi_send_json("error", "Gagal menyimpan presensi siswa.", 500);
        exit();
    }
}

mysqli_stmt_close($detailStmt);
if (!mysqli_commit($koneksi)) {
    mysqli_rollback($koneksi);
    presensi_send_json("error", "Gagal menyelesaikan transaksi presensi.", 500);
    exit();
}

echo json_encode([
    "status" => "success",
    "message" => "Presensi berhasil disimpan.",
    "data" => ["sesi_id" => $sessionId, "jumlah_siswa" => count($entries)]
]);
mysqli_close($koneksi);
