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
    "SELECT nomor_induk, nama_lengkap, email
     FROM users
     WHERE role = 'siswa' AND kelas_id = ? AND is_deleted = 0
     ORDER BY nama_lengkap ASC"
);
if ($stmt === false) {
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Gagal menyiapkan daftar teman sekelas."]);
    exit();
}
mysqli_stmt_bind_param($stmt, "i", $classId);
if (!mysqli_stmt_execute($stmt)) {
    mysqli_stmt_close($stmt);
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Gagal mengambil daftar teman sekelas."]);
    exit();
}
$result = mysqli_stmt_get_result($stmt);
$classmates = [];
while ($row = mysqli_fetch_assoc($result)) {
    $classmates[] = $row;
}
mysqli_stmt_close($stmt);
echo json_encode(["status" => "success", "data" => $classmates]);
mysqli_close($koneksi);
?>
