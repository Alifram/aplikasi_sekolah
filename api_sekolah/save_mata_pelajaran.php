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
if (!is_array($input) || !isset($input['user_id'], $input['kode'], $input['nama'])) {
    http_response_code(400);
    echo json_encode(["status" => "error", "message" => "Data mata pelajaran belum lengkap."]);
    exit();
}
if (!jadwal_require_admin($koneksi, $input['user_id'])) {
    exit();
}

$code = is_string($input['kode']) ? strtoupper(trim($input['kode'])) : '';
$name = is_string($input['nama']) ? trim($input['nama']) : '';
if ($code === '' || strlen($code) > 30 || $name === '' || mb_strlen($name) > 100) {
    http_response_code(400);
    echo json_encode(["status" => "error", "message" => "Kode maksimal 30 karakter dan nama maksimal 100 karakter."]);
    exit();
}

$stmt = mysqli_prepare($koneksi, "INSERT INTO mata_pelajaran (kode, nama, aktif) VALUES (?, ?, 1)");
if ($stmt === false) {
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Gagal menyiapkan penyimpanan mata pelajaran."]);
    exit();
}
mysqli_stmt_bind_param($stmt, "ss", $code, $name);
if (!mysqli_stmt_execute($stmt)) {
    $errno = mysqli_stmt_errno($stmt);
    mysqli_stmt_close($stmt);
    http_response_code($errno === 1062 ? 409 : 500);
    echo json_encode([
        "status" => "error",
        "message" => $errno === 1062
            ? "Kode atau nama mata pelajaran sudah digunakan."
            : "Gagal menyimpan mata pelajaran."
    ]);
    exit();
}
mysqli_stmt_close($stmt);

echo json_encode(["status" => "success", "message" => "Mata pelajaran berhasil ditambahkan."]);
mysqli_close($koneksi);
?>
