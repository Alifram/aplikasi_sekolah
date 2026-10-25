<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");
header("Content-Type: application/json; charset=UTF-8");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

include "koneksi.php";
include "jadwal_helpers.php";

$input = json_decode(file_get_contents('php://input'), true);
if (!is_array($input)) {
    http_response_code(400);
    echo json_encode(["status" => "error", "message" => "Format JSON tidak valid."]);
    exit();
}
if (!isset($input['user_id']) || !jadwal_require_admin($koneksi, $input['user_id'])) {
    if (!isset($input['user_id'])) {
        http_response_code(401);
        echo json_encode(["status" => "error", "message" => "Akun admin tidak valid."]);
    }
    exit();
}

$required = ['kelas_mapel_id', 'hari', 'jam_mulai', 'jam_selesai', 'ruangan'];
foreach ($required as $field) {
    if (!isset($input[$field]) || !is_scalar($input[$field]) || trim((string)$input[$field]) === '') {
        http_response_code(400);
        echo json_encode(["status" => "error", "message" => "Data jadwal belum lengkap."]);
        exit();
    }
}

$assignmentId = filter_var($input['kelas_mapel_id'], FILTER_VALIDATE_INT);
$scheduleId = null;
if (isset($input['id'])) {
    $scheduleId = filter_var($input['id'], FILTER_VALIDATE_INT);
    if ($scheduleId === false || $scheduleId <= 0) {
        http_response_code(400);
        echo json_encode(["status" => "error", "message" => "ID jadwal tidak valid."]);
        exit();
    }
}
$hari = trim((string)$input['hari']);
$mulai = trim((string)$input['jam_mulai']);
$selesai = trim((string)$input['jam_selesai']);
$ruangan = trim((string)$input['ruangan']);
$mulai = strlen($mulai) === 5 ? $mulai . ':00' : $mulai;
$selesai = strlen($selesai) === 5 ? $selesai . ':00' : $selesai;
$hariValid = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];
$timePattern = '/^(?:[01]\d|2[0-3]):[0-5]\d(?::[0-5]\d)?$/';

if ($assignmentId === false || $assignmentId <= 0 ||
    !in_array($hari, $hariValid, true) ||
    !preg_match($timePattern, $mulai) ||
    !preg_match($timePattern, $selesai) ||
    $mulai >= $selesai ||
    $ruangan === '') {
    http_response_code(400);
    echo json_encode(["status" => "error", "message" => "Penugasan, hari, atau rentang waktu jadwal tidak valid."]);
    exit();
}

mysqli_begin_transaction($koneksi);

$assignment = mysqli_prepare(
    $koneksi,
    "SELECT km.kelas_id, km.guru_id, km.tahun_ajaran
     FROM kelas_mapel km
     JOIN kelas k ON k.id = km.kelas_id AND k.aktif = 1
     JOIN mata_pelajaran mp ON mp.id = km.mata_pelajaran_id AND mp.aktif = 1
     JOIN users u ON u.id = km.guru_id AND u.role = 'guru' AND u.is_deleted = 0
     WHERE km.id = ? AND km.aktif = 1
     LIMIT 1 FOR UPDATE"
);
if ($assignment === false) {
    mysqli_rollback($koneksi);
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Gagal memeriksa penugasan mapel."]);
    exit();
}
mysqli_stmt_bind_param($assignment, "i", $assignmentId);
if (!mysqli_stmt_execute($assignment)) {
    mysqli_stmt_close($assignment);
    mysqli_rollback($koneksi);
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Gagal memeriksa penugasan mapel."]);
    exit();
}
$assignmentResult = mysqli_stmt_get_result($assignment);
$assignmentData = mysqli_fetch_assoc($assignmentResult);
mysqli_stmt_close($assignment);
if ($assignmentData === null) {
    mysqli_rollback($koneksi);
    http_response_code(400);
    echo json_encode(["status" => "error", "message" => "Penugasan kelas, mapel, atau guru tidak aktif/tidak ditemukan."]);
    exit();
}

if ($scheduleId !== null) {
    $existing = mysqli_prepare($koneksi, "SELECT id FROM jadwal_pelajaran WHERE id = ? LIMIT 1 FOR UPDATE");
    if ($existing === false) {
        mysqli_rollback($koneksi);
        http_response_code(500);
        echo json_encode(["status" => "error", "message" => "Gagal memeriksa jadwal yang akan diubah."]);
        exit();
    }
    mysqli_stmt_bind_param($existing, "i", $scheduleId);
    if (!mysqli_stmt_execute($existing)) {
        mysqli_stmt_close($existing);
        mysqli_rollback($koneksi);
        http_response_code(500);
        echo json_encode(["status" => "error", "message" => "Gagal memeriksa jadwal yang akan diubah."]);
        exit();
    }
    $exists = mysqli_num_rows(mysqli_stmt_get_result($existing)) === 1;
    mysqli_stmt_close($existing);
    if (!$exists) {
        mysqli_rollback($koneksi);
        http_response_code(404);
        echo json_encode(["status" => "error", "message" => "Jadwal yang akan diubah tidak ditemukan."]);
        exit();
    }
}

$conflictSql = "SELECT j.id
                FROM jadwal_pelajaran j
                JOIN kelas_mapel km ON km.id = j.kelas_mapel_id
                WHERE j.hari = ?
                  AND (km.kelas_id = ? OR km.guru_id = ?)
                  AND km.tahun_ajaran = ?
                  AND j.jam_mulai < ? AND j.jam_selesai > ?";
if ($scheduleId !== null) {
    $conflictSql .= " AND id <> ?";
}
$conflictSql .= " LIMIT 1 FOR UPDATE";
$check = mysqli_prepare($koneksi, $conflictSql);
if ($check === false) {
    mysqli_rollback($koneksi);
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Gagal memeriksa bentrok jadwal."]);
    exit();
}
if ($scheduleId === null) {
    mysqli_stmt_bind_param(
        $check,
        "siisss",
        $hari,
        $assignmentData['kelas_id'],
        $assignmentData['guru_id'],
        $assignmentData['tahun_ajaran'],
        $selesai,
        $mulai
    );
} else {
    mysqli_stmt_bind_param(
        $check,
        "siisssi",
        $hari,
        $assignmentData['kelas_id'],
        $assignmentData['guru_id'],
        $assignmentData['tahun_ajaran'],
        $selesai,
        $mulai,
        $scheduleId
    );
}
if (!mysqli_stmt_execute($check)) {
    mysqli_stmt_close($check);
    mysqli_rollback($koneksi);
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Gagal memeriksa bentrok jadwal."]);
    exit();
}
$hasConflict = mysqli_num_rows(mysqli_stmt_get_result($check)) > 0;
mysqli_stmt_close($check);
if ($hasConflict) {
    mysqli_rollback($koneksi);
    http_response_code(409);
    echo json_encode(["status" => "error", "message" => "Jadwal bertabrakan dengan kelas atau jam mengajar guru yang sudah ada."]);
    exit();
}

$sql = $scheduleId === null
    ? "INSERT INTO jadwal_pelajaran
       (hari, jam_mulai, jam_selesai, ruangan, kelas_mapel_id)
       VALUES (?, ?, ?, ?, ?)"
    : "UPDATE jadwal_pelajaran
       SET hari = ?, jam_mulai = ?, jam_selesai = ?,
           ruangan = ?, kelas_mapel_id = ?
       WHERE id = ?";
$save = mysqli_prepare($koneksi, $sql);
if ($save === false) {
    mysqli_rollback($koneksi);
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Gagal menyiapkan penyimpanan jadwal."]);
    exit();
}
if ($scheduleId === null) {
    mysqli_stmt_bind_param(
        $save,
        "ssssi",
        $hari,
        $mulai,
        $selesai,
        $ruangan,
        $assignmentId
    );
} else {
    mysqli_stmt_bind_param(
        $save,
        "ssssii",
        $hari,
        $mulai,
        $selesai,
        $ruangan,
        $assignmentId,
        $scheduleId
    );
}
if (!mysqli_stmt_execute($save)) {
    mysqli_stmt_close($save);
    mysqli_rollback($koneksi);
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Gagal menyimpan jadwal ke database."]);
    exit();
}

mysqli_stmt_close($save);
if (!mysqli_commit($koneksi)) {
    mysqli_rollback($koneksi);
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Gagal menyelesaikan penyimpanan jadwal."]);
    exit();
}

echo json_encode([
    "status" => "success",
    "message" => $scheduleId === null ? "Jadwal berhasil disimpan." : "Jadwal berhasil diperbarui."
]);
mysqli_close($koneksi);
?>
