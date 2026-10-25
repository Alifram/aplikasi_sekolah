<?php
// Mengizinkan aplikasi Flutter (perangkat luar) untuk mengakses API ini
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Headers: *");
header("Content-Type: application/json; charset=UTF-8");

$host = getenv('DB_HOST') ?: '127.0.0.1';
$username = getenv('DB_USER') ?: 'root';
$password = getenv('DB_PASSWORD') ?: '';
$database = getenv('DB_NAME') ?: 'db_mim_pasir_lor2';

$koneksi = mysqli_connect($host, $username, $password, $database);

if (!$koneksi) {
    echo json_encode([
        "status" => "error", 
        "message" => "Koneksi database gagal: " . mysqli_connect_error()
    ]);
    exit();
}

mysqli_set_charset($koneksi, "utf8mb4");