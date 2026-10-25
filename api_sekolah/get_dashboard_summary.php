<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");
header("Content-Type: application/json; charset=UTF-8");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

include "koneksi.php";

$query = "SELECT
            (SELECT COUNT(*) FROM users WHERE role = 'siswa' AND is_deleted = 0) AS total_siswa,
            (SELECT COUNT(*) FROM users WHERE role = 'guru' AND is_deleted = 0) AS total_guru,
            (SELECT COUNT(*) FROM events) AS total_pengumuman";
$result = mysqli_query($koneksi, $query);

if ($result === false) {
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Gagal mengambil ringkasan dashboard."]);
    exit();
}

$summary = mysqli_fetch_assoc($result);
echo json_encode([
    "status" => "success",
    "total_siswa" => (int)$summary['total_siswa'],
    "total_guru" => (int)$summary['total_guru'],
    "total_pengumuman" => (int)$summary['total_pengumuman']
]);

mysqli_close($koneksi);
