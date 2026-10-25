<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");
header("Content-Type: application/json; charset=UTF-8");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

include "koneksi.php";

$input = json_decode(file_get_contents('php://input'), true);
$adminId = is_array($input) && isset($input['admin_id'])
    ? filter_var($input['admin_id'], FILTER_VALIDATE_INT)
    : false;
$userId = is_array($input) && isset($input['user_id'])
    ? filter_var($input['user_id'], FILTER_VALIDATE_INT)
    : false;
$classId = is_array($input) && isset($input['kelas_id_baru'])
    ? filter_var($input['kelas_id_baru'], FILTER_VALIDATE_INT)
    : false;

if ($adminId === false || $adminId <= 0 ||
    $userId === false || $userId <= 0 ||
    $classId === false || $classId <= 0) {
    http_response_code(400);
    echo json_encode(["status" => "error", "message" => "ID admin, pengguna, atau kelas tidak valid."]);
    exit();
}

$validation = mysqli_prepare(
    $koneksi,
    "SELECT target.id
     FROM users target
     JOIN users admin ON admin.id = ? AND admin.role = 'admin' AND admin.is_deleted = 0
     JOIN kelas k ON k.id = ? AND k.aktif = 1
     WHERE target.id = ? AND target.role IN ('guru', 'siswa') AND target.is_deleted = 0"
);
if ($validation === false) {
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Gagal menyiapkan validasi pemindahan kelas."]);
    exit();
}
mysqli_stmt_bind_param($validation, "iii", $adminId, $classId, $userId);
if (!mysqli_stmt_execute($validation)) {
    mysqli_stmt_close($validation);
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Gagal memvalidasi pemindahan kelas."]);
    exit();
}
if (mysqli_num_rows(mysqli_stmt_get_result($validation)) !== 1) {
    mysqli_stmt_close($validation);
    http_response_code(404);
    echo json_encode(["status" => "error", "message" => "Admin, pengguna, atau kelas tidak ditemukan/tidak valid."]);
    exit();
}
mysqli_stmt_close($validation);

$stmt = mysqli_prepare($koneksi, "UPDATE users SET kelas_id = ? WHERE id = ?");
if ($stmt === false) {
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Gagal menyiapkan pemindahan kelas."]);
    exit();
}
mysqli_stmt_bind_param($stmt, "ii", $classId, $userId);
if (!mysqli_stmt_execute($stmt)) {
    mysqli_stmt_close($stmt);
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Gagal memindahkan pengguna ke kelas."]);
    exit();
}
mysqli_stmt_close($stmt);

echo json_encode(["status" => "success", "message" => "Pemindahan kelas berhasil."]);
mysqli_close($koneksi);
?>
