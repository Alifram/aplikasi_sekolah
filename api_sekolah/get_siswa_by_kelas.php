<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");
header("Content-Type: application/json; charset=UTF-8");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

include "koneksi.php";

$classId = isset($_GET['kelas_id']) ? filter_var($_GET['kelas_id'], FILTER_VALIDATE_INT) : false;
if ($classId === false || $classId <= 0) {
    http_response_code(400);
    echo json_encode(["status" => "error", "message" => "ID kelas tidak valid."]);
    exit();
}

$stmt = mysqli_prepare(
    $koneksi,
    "SELECT u.id, u.nomor_induk, u.nama_lengkap, u.kelas_id,
            k.nama AS kelas_nama, k.nama AS kelas_diajar, u.tahun_angkatan
     FROM users u
     JOIN kelas k ON k.id = u.kelas_id
     WHERE u.role = 'siswa' AND u.kelas_id = ? AND u.is_deleted = 0
     ORDER BY u.nama_lengkap ASC"
);
if ($stmt === false) {
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Gagal menyiapkan daftar siswa."]);
    exit();
}
mysqli_stmt_bind_param($stmt, "i", $classId);
if (!mysqli_stmt_execute($stmt)) {
    mysqli_stmt_close($stmt);
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Gagal mengambil daftar siswa."]);
    exit();
}

$result = mysqli_stmt_get_result($stmt);
$students = [];
while ($row = mysqli_fetch_assoc($result)) {
    $row['id'] = (int)$row['id'];
    $row['kelas_id'] = (int)$row['kelas_id'];
    $row['tahun_angkatan'] = $row['tahun_angkatan'] === null
        ? null
        : (int)$row['tahun_angkatan'];
    $students[] = $row;
}
mysqli_stmt_close($stmt);
echo json_encode(["status" => "success", "data" => $students]);
mysqli_close($koneksi);
?>
