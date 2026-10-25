<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");
header("Content-Type: application/json; charset=UTF-8");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

include "koneksi.php";

$result = mysqli_query(
    $koneksi,
    "SELECT id, nama FROM kelas WHERE aktif = 1 ORDER BY nama"
);
if ($result === false) {
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Gagal mengambil daftar kelas."]);
    exit();
}

$classes = [];
while ($row = mysqli_fetch_assoc($result)) {
    $classes[] = ["id" => (int)$row['id'], "nama" => $row['nama']];
}
echo json_encode(["status" => "success", "data" => $classes]);
mysqli_close($koneksi);
?>
