<?php
// Mengatasi masalah gambar tidak muncul di Flutter Web / Chrome
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, OPTIONS");
header("Access-Control-Allow-Headers: *");

if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') exit(0);

if (isset($_GET['file'])) {
    $filename = basename($_GET['file']);
    $filepath = "uploads/" . $filename;

    if (file_exists($filepath)) {
        // Mengatur tipe konten sesuai file gambar jpg asli
        header("Content-Type: image/jpeg");
        readfile($filepath);
        exit;
    }
}
// Jika file tidak ditemukan, kirim status kosong
http_response_code(404);
?>