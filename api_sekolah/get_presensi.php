<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");
header("Content-Type: application/json; charset=UTF-8");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

include "koneksi.php";
include "presensi_helpers.php";

$actorId = $_GET['user_id'] ?? null;
$actor = presensi_get_actor($koneksi, $actorId);
if ($actor === false) {
    presensi_send_json("error", "Gagal memeriksa akun.", 500);
    exit();
}
if ($actor === null) {
    presensi_send_json("error", "Akun tidak valid atau tidak aktif.", 401);
    exit();
}

$requestedClassId = isset($_GET['kelas_id'])
    ? filter_var($_GET['kelas_id'], FILTER_VALIDATE_INT)
    : null;
$date = $_GET['tanggal'] ?? '';
$filters = ["1 = 1"];
$types = '';
$values = [];

if ($date !== '' && !presensi_valid_date($date)) {
    presensi_send_json("error", "Format tanggal harus YYYY-MM-DD.", 400);
    exit();
}
if (isset($_GET['kelas_id']) &&
    ($requestedClassId === false || $requestedClassId <= 0)) {
    presensi_send_json("error", "ID kelas tidak valid.", 400);
    exit();
}

if ($actor['role'] === 'siswa') {
    $filters[] = "d.siswa_id = ?";
    $types .= 'i';
    $values[] = (int)$actor['id'];
} elseif ($actor['role'] === 'guru') {
    $teacherClassId = (int)$actor['kelas_id'];
    if ($teacherClassId <= 0) {
        presensi_send_json("error", "Kelas akun guru belum diatur.", 403);
        exit();
    }
    if ($requestedClassId !== null && $requestedClassId !== $teacherClassId) {
        presensi_send_json("error", "Guru hanya dapat melihat presensi kelasnya.", 403);
        exit();
    }
    $filters[] = "s.kelas_id = ?";
    $types .= 'i';
    $values[] = $teacherClassId;
} elseif ($actor['role'] === 'admin') {
    if ($requestedClassId !== null) {
        $filters[] = "s.kelas_id = ?";
        $types .= 'i';
        $values[] = $requestedClassId;
    }
} else {
    presensi_send_json("error", "Role akun tidak diizinkan melihat presensi.", 403);
    exit();
}

if ($date !== '') {
    $filters[] = "s.tanggal = ?";
    $types .= 's';
    $values[] = $date;
}

$query = "SELECT s.id AS sesi_id, s.tanggal, s.kelas_id,
                 k.nama AS kelas, s.guru_id,
                 guru.nama_lengkap AS nama_guru,
                 siswa.id AS siswa_id, siswa.nomor_induk, siswa.nama_lengkap AS nama_siswa,
                 d.status, d.catatan
          FROM presensi_sesi s
          JOIN presensi_detail d ON d.sesi_id = s.id
          JOIN users siswa ON siswa.id = d.siswa_id
          JOIN users guru ON guru.id = s.guru_id
          JOIN kelas k ON k.id = s.kelas_id
          WHERE " . implode(" AND ", $filters) . "
          ORDER BY s.tanggal DESC, k.nama ASC, siswa.nama_lengkap ASC
          LIMIT 501";
$stmt = mysqli_prepare($koneksi, $query);
if ($stmt === false) {
    presensi_send_json("error", "Gagal menyiapkan pencarian presensi.", 500);
    exit();
}

if (!mysqli_stmt_execute($stmt, $values)) {
    mysqli_stmt_close($stmt);
    presensi_send_json("error", "Gagal mengambil data presensi.", 500);
    exit();
}

$result = mysqli_stmt_get_result($stmt);
$attendance = [];
while ($row = mysqli_fetch_assoc($result)) {
    $attendance[] = $row;
}
mysqli_stmt_close($stmt);

$hasMore = count($attendance) > 500;
if ($hasMore) {
    array_pop($attendance);
}
echo json_encode([
    "status" => "success",
    "data" => $attendance,
    "has_more" => $hasMore
]);
mysqli_close($koneksi);
