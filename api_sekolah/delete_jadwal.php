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
$isAdmin = is_array($input) && isset($input['user_id'])
    ? jadwal_require_admin($koneksi, $input['user_id'])
    : false;
if (!$isAdmin) {
    if (!is_array($input) || !isset($input['user_id'])) {
        http_response_code(401);
        echo json_encode(["status" => "error", "message" => "Akun admin tidak valid."]);
    }
    exit();
}
$scheduleId = is_array($input) && isset($input['id'])
    ? filter_var($input['id'], FILTER_VALIDATE_INT)
    : false;

if ($scheduleId === false || $scheduleId <= 0) {
    http_response_code(400);
    echo json_encode(["status" => "error", "message" => "ID jadwal tidak valid."]);
    exit();
}

$stmt = mysqli_prepare($koneksi, "DELETE FROM jadwal_pelajaran WHERE id = ?");
if ($stmt === false) {
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Gagal menyiapkan penghapusan jadwal."]);
    exit();
}

mysqli_stmt_bind_param($stmt, "i", $scheduleId);
if (!mysqli_stmt_execute($stmt)) {
    mysqli_stmt_close($stmt);
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Gagal menghapus jadwal."]);
    exit();
}

$deleted = mysqli_stmt_affected_rows($stmt) > 0;
mysqli_stmt_close($stmt);
if (!$deleted) {
    http_response_code(404);
    echo json_encode(["status" => "error", "message" => "Jadwal tidak ditemukan."]);
    exit();
}

echo json_encode(["status" => "success", "message" => "Jadwal berhasil dihapus."]);
mysqli_close($koneksi);
