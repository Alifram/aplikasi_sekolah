<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");
header("Content-Type: application/json; charset=UTF-8");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

include "koneksi.php";

$classId = isset($_GET['kelas_id']) ? filter_var($_GET['kelas_id'], FILTER_VALIDATE_INT) : null;
$hari = isset($_GET['hari']) ? trim($_GET['hari']) : '';
$guru = isset($_GET['guru']) ? trim($_GET['guru']) : '';
$guruId = isset($_GET['guru_id']) ? filter_var($_GET['guru_id'], FILTER_VALIDATE_INT) : null;
$hariValid = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];

if ((isset($_GET['kelas_id']) && ($classId === false || $classId <= 0)) ||
    ($hari !== '' && !in_array($hari, $hariValid, true)) ||
    (isset($_GET['guru_id']) && ($guruId === false || $guruId <= 0))) {
    http_response_code(400);
    echo json_encode(["status" => "error", "message" => "Filter kelas, hari, atau guru tidak valid."]);
    exit();
}

$filters = [];
$types = '';
$values = [];
if ($classId !== null) {
    $filters[] = "km.kelas_id = ?";
    $types .= 'i';
    $values[] = $classId;
}
if ($hari !== '') {
    $filters[] = "j.hari = ?";
    $types .= 's';
    $values[] = $hari;
}
if ($guru !== '') {
    $filters[] = "u.nama_lengkap = ?";
    $types .= 's';
    $values[] = $guru;
}
if ($guruId !== null) {
    $filters[] = "km.guru_id = ?";
    $types .= 'i';
    $values[] = $guruId;
}

$where = count($filters) > 0 ? "WHERE " . implode(" AND ", $filters) : "";
$query = "SELECT j.id, km.kelas_id, k.nama AS kelas,
                 j.hari, j.jam_mulai, j.jam_selesai,
                 TIME_FORMAT(j.jam_mulai, '%H:%i') AS jam_mulai_format,
                 TIME_FORMAT(j.jam_selesai, '%H:%i') AS jam_selesai_format,
                 mp.nama AS mata_pelajaran,
                 u.nama_lengkap AS guru_pengampu,
                 j.ruangan, j.kelas_mapel_id, km.tahun_ajaran
          FROM jadwal_pelajaran j
          JOIN kelas_mapel km ON km.id = j.kelas_mapel_id
          JOIN kelas k ON k.id = km.kelas_id
          JOIN mata_pelajaran mp ON mp.id = km.mata_pelajaran_id
          JOIN users u ON u.id = km.guru_id
          $where
          ORDER BY FIELD(j.hari, 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'), j.jam_mulai ASC";
$stmt = mysqli_prepare($koneksi, $query);

if ($stmt === false) {
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Gagal menyiapkan pengambilan jadwal pelajaran."]);
    exit();
}
if ($types !== '') {
    mysqli_stmt_bind_param($stmt, $types, ...$values);
}
if (!mysqli_stmt_execute($stmt)) {
    mysqli_stmt_close($stmt);
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Gagal mengambil jadwal pelajaran."]);
    exit();
}

$result = mysqli_stmt_get_result($stmt);
$jadwal = [];
while ($row = mysqli_fetch_assoc($result)) {
    $jadwal[] = $row;
}
mysqli_stmt_close($stmt);

echo json_encode(["status" => "success", "data" => $jadwal]);
mysqli_close($koneksi);
