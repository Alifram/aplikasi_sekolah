<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");
header("Content-Type: application/json; charset=UTF-8");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

include "koneksi.php";
include "jadwal_helpers.php";

$userId = isset($_GET['user_id']) ? $_GET['user_id'] : null;
$classId = isset($_GET['kelas_id']) ? filter_var($_GET['kelas_id'], FILTER_VALIDATE_INT) : null;
if ($userId === null || !jadwal_require_admin($koneksi, $userId)) {
    if ($userId === null) {
        http_response_code(401);
        echo json_encode(["status" => "error", "message" => "Akun admin tidak valid."]);
    }
    exit();
}
if (isset($_GET['kelas_id']) && ($classId === false || $classId <= 0)) {
    http_response_code(400);
    echo json_encode(["status" => "error", "message" => "ID kelas tidak valid."]);
    exit();
}


$queries = [
    'kelas' => "SELECT id, nama
                FROM kelas
                WHERE aktif = 1
                ORDER BY nama",

    'mata_pelajaran' => "SELECT id, kode, nama
                         FROM mata_pelajaran
                         WHERE aktif = 1
                         ORDER BY nama",

    'guru' => "SELECT id, nama_lengkap, kelas_id, jenis_guru
           FROM users
           WHERE role = 'guru'
             AND is_deleted = 0
             AND (
                 jenis_guru = 'guru_mapel'
                 OR (
                     jenis_guru = 'guru_kelas'
                     AND " . (
                         $classId !== null
                             ? "kelas_id = " . (int)$classId
                             : "kelas_id IS NOT NULL"
                     ) . "
                 )
             )
           ORDER BY nama_lengkap"
];

$data = [];
foreach ($queries as $key => $query) {
    $result = mysqli_query($koneksi, $query);
    if ($result === false) {
        http_response_code(500);
        echo json_encode(["status" => "error", "message" => "Gagal mengambil referensi $key."]);
        exit();
    }
    $data[$key] = [];
    while ($row = mysqli_fetch_assoc($result)) {
        $row['id'] = (int)$row['id'];
        $data[$key][] = $row;
    }
}

echo json_encode(["status" => "success", "data" => $data]);
mysqli_close($koneksi);
?>
