<?php
header("Content-Type: application/json");
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST");
header("Access-Control-Allow-Headers: Content-Type");

include 'koneksi.php';

$input = json_decode(file_get_contents('php://input'), true);

if (isset($input['user_id']) && filter_var($input['user_id'], FILTER_VALIDATE_INT)) {
    $userId = mysqli_real_escape_string($koneksi, $input['user_id']);

    $query = "UPDATE users SET is_deleted = 1 WHERE id = '$userId' AND is_deleted = 0";

    if (mysqli_query($koneksi, $query) && mysqli_affected_rows($koneksi) > 0) {
        echo json_encode([
            "status" => "success",
            "message" => "Akun berhasil dinonaktifkan permanen dari aplikasi. Seluruh histori nilai tersimpan dengan aman."
        ]);
    } else {
        echo json_encode([
            "status" => "error",
            "message" => mysqli_error($koneksi) ?: "Akun tidak ditemukan atau sudah dinonaktifkan."
        ]);
    }
} else {
    echo json_encode(["status" => "error", "message" => "Parameter ID tidak lengkap."]);
}
?>