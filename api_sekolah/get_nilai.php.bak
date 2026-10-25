<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");
header("Content-Type: application/json; charset=UTF-8");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

include "koneksi.php";

$userId = isset($_GET['user_id']) ? filter_var($_GET['user_id'], FILTER_VALIDATE_INT) : false;
$role = isset($_GET['role']) ? trim($_GET['role']) : '';
if ($userId === false || $userId <= 0 || !in_array($role, ['siswa', 'guru', 'admin'], true)) {
    http_response_code(400);
    echo json_encode(["status" => "error", "message" => "Parameter pengguna tidak valid."]);
    exit();
}

if ($role === 'admin') {
    echo json_encode(["status" => "success", "type" => "admin", "data" => []]);
    mysqli_close($koneksi);
    exit();
}

$personColumn = $role === 'siswa' ? 'n.siswa_id' : 'n.guru_id';
$personName = $role === 'siswa' ? 'guru' : 'siswa';
$sql = "SELECT n.id, n.siswa_id, n.guru_id, n.semester,
               k.nama AS kelas,
               n.tahun_angkatan,
               mp.nama AS mata_pelajaran,
               n.kelas_mapel_id, n.nilai_tugas, n.nilai_uts, n.nilai_uas,
               n.keterangan, n.created_at,
               u.nama_lengkap AS nama_$personName
        FROM nilai_raport n
        LEFT JOIN kelas_mapel km ON km.id = n.kelas_mapel_id
        LEFT JOIN kelas k ON k.id = km.kelas_id
        LEFT JOIN mata_pelajaran mp ON mp.id = km.mata_pelajaran_id
        JOIN users u ON u.id = " . ($role === 'siswa' ? 'n.guru_id' : 'n.siswa_id') . "
        WHERE $personColumn = ?
        ORDER BY n.semester ASC, mp.nama ASC, k.nama ASC";
$stmt = mysqli_prepare($koneksi, $sql);
if ($stmt === false) {
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Gagal menyiapkan pengambilan nilai."]);
    exit();
}
mysqli_stmt_bind_param($stmt, "i", $userId);
if (!mysqli_stmt_execute($stmt)) {
    mysqli_stmt_close($stmt);
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Gagal mengambil data nilai."]);
    exit();
}

$result = mysqli_stmt_get_result($stmt);
$grades = [];
while ($row = mysqli_fetch_assoc($result)) {
    $grades[] = $row;
}
mysqli_stmt_close($stmt);

echo json_encode(["status" => "success", "type" => $role, "data" => $grades]);
mysqli_close($koneksi);
?>
