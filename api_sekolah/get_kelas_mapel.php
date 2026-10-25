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
$guruId = isset($_GET['guru_id']) ? filter_var($_GET['guru_id'], FILTER_VALIDATE_INT) : null;

if ((isset($_GET['kelas_id']) && ($classId === false || $classId <= 0)) ||
    (isset($_GET['guru_id']) && ($guruId === false || $guruId <= 0))) {
    http_response_code(400);
    echo json_encode(["status" => "error", "message" => "ID guru tidak valid."]);
    exit();
}

$sql = "SELECT km.id, km.kelas_id, k.nama AS kelas,
               km.mata_pelajaran_id, mp.nama AS mata_pelajaran,
               km.guru_id, u.nama_lengkap AS guru_pengampu,
               km.tahun_ajaran
        FROM kelas_mapel km
        JOIN kelas k ON k.id = km.kelas_id AND k.aktif = 1
        JOIN mata_pelajaran mp
          ON mp.id = km.mata_pelajaran_id AND mp.aktif = 1
        JOIN users u
          ON u.id = km.guru_id AND u.role = 'guru' AND u.is_deleted = 0
        WHERE km.aktif = 1";

if ($classId !== null) {
    $sql .= " AND km.kelas_id = ?";
}
if ($guruId !== null) {
    $sql .= " AND km.guru_id = ?";
}
$sql .= " ORDER BY k.nama, mp.nama, km.tahun_ajaran DESC";

$stmt = mysqli_prepare($koneksi, $sql);
if ($stmt === false) {
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Gagal menyiapkan daftar penugasan mapel."]);
    exit();
}
if ($classId !== null && $guruId !== null) {
    mysqli_stmt_bind_param($stmt, "ii", $classId, $guruId);
} elseif ($classId !== null) {
    mysqli_stmt_bind_param($stmt, "i", $classId);
} elseif ($guruId !== null) {
    mysqli_stmt_bind_param($stmt, "i", $guruId);
}
if (!mysqli_stmt_execute($stmt)) {
    mysqli_stmt_close($stmt);
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Gagal mengambil daftar penugasan mapel."]);
    exit();
}

$result = mysqli_stmt_get_result($stmt);
$assignments = [];
while ($row = mysqli_fetch_assoc($result)) {
    $assignments[] = $row;
}
mysqli_stmt_close($stmt);

echo json_encode(["status" => "success", "data" => $assignments]);
mysqli_close($koneksi);
?>
