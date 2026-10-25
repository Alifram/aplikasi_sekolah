<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");
header("Content-Type: application/json; charset=UTF-8");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

include "koneksi.php";

$query = "SELECT u.id, u.nomor_induk, u.nama_lengkap, u.email, u.role,
                 u.kelas_id, k.nama AS kelas_nama, k.nama AS kelas_diajar,
                 u.tahun_angkatan, u.is_deleted
          FROM users u
          LEFT JOIN kelas k ON k.id = u.kelas_id
          WHERE u.is_deleted = 0
          ORDER BY u.role ASC, u.nama_lengkap ASC";
$result = mysqli_query($koneksi, $query);
if ($result === false) {
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Gagal mengambil data pengguna."]);
    exit();
}

$users = [];
while ($row = mysqli_fetch_assoc($result)) {
    $row['id'] = (int)$row['id'];
    $row['kelas_id'] = $row['kelas_id'] === null ? null : (int)$row['kelas_id'];
    $row['tahun_angkatan'] = $row['tahun_angkatan'] === null
        ? null
        : (int)$row['tahun_angkatan'];
    $users[] = $row;
}
echo json_encode(["status" => "success", "data" => $users]);
mysqli_close($koneksi);
?>
