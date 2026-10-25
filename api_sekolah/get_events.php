<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");
header("Content-Type: application/json; charset=UTF-8");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

include "koneksi.php";

$query = "SELECT e.id, e.judul_acara, e.deskripsi, e.target_semua_kelas,
                 e.gambar_url, e.tanggal_acara, e.dibuat_oleh, e.created_at,
                 GROUP_CONCAT(DISTINCT k.id ORDER BY k.nama SEPARATOR ',') AS target_kelas_ids,
                 GROUP_CONCAT(DISTINCT k.nama ORDER BY k.nama SEPARATOR ', ') AS target_kelas
          FROM events e
          LEFT JOIN event_kelas ek ON ek.event_id = e.id
          LEFT JOIN kelas k ON k.id = ek.kelas_id
          GROUP BY e.id
          ORDER BY e.tanggal_acara DESC, e.id DESC";
$result = mysqli_query($koneksi, $query);
if ($result === false) {
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Gagal mengambil daftar event."]);
    exit();
}

$events = [];
while ($row = mysqli_fetch_assoc($result)) {
    $row['target_semua_kelas'] = (bool)$row['target_semua_kelas'];
    $row['target_kelas_ids'] = $row['target_kelas_ids'] === null ||
        $row['target_kelas_ids'] === ''
        ? []
        : array_map('intval', explode(',', $row['target_kelas_ids']));
    $row['target_kelas'] = $row['target_semua_kelas']
        ? 'Semua Kelas'
        : ($row['target_kelas'] ?? '');
    $events[] = $row;
}
echo json_encode(["status" => "success", "data" => $events]);
mysqli_close($koneksi);
?>
