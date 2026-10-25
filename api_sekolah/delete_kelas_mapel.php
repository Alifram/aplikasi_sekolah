
<?php
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode([
        'success' => false,
        'message' => 'Metode request tidak diizinkan.'
    ]);
    exit();
}

require_once __DIR__ . '/koneksi.php';
require_once __DIR__ . '/jadwal_helpers.php';

function kirimRespons($status, $message)
{
    http_response_code($status);
    echo json_encode([
        'success' => $status >= 200 && $status < 300,
        'message' => $message
    ]);
    exit();
}

$data = json_decode(file_get_contents('php://input'), true);

if (!is_array($data)) {
    kirimRespons(400, 'Data request tidak valid.');
}

$userId = isset($data['user_id']) ? (int) $data['user_id'] : 0;
$id = isset($data['id']) ? (int) $data['id'] : 0;

if ($userId <= 0 || !jadwal_require_admin($koneksi, $userId)) {
    exit();
}

if ($id <= 0) {
    kirimRespons(400, 'ID penugasan tidak valid.');
}

// Pastikan penugasan masih aktif.
$stmt = mysqli_prepare(
    $koneksi,
    "SELECT id FROM kelas_mapel WHERE id = ? AND aktif = 1 LIMIT 1"
);
mysqli_stmt_bind_param($stmt, 'i', $id);
mysqli_stmt_execute($stmt);
$result = mysqli_stmt_get_result($stmt);
$assignment = mysqli_fetch_assoc($result);
mysqli_stmt_close($stmt);

if (!$assignment) {
    kirimRespons(404, 'Penugasan tidak ditemukan atau sudah dihapus.');
}

// Periksa apakah penugasan telah digunakan pada jadwal.
$stmt = mysqli_prepare(
    $koneksi,
    "SELECT COUNT(*) AS total
     FROM jadwal_pelajaran
     WHERE kelas_mapel_id = ?"
);
mysqli_stmt_bind_param($stmt, 'i', $id);
mysqli_stmt_execute($stmt);
$result = mysqli_stmt_get_result($stmt);
$row = mysqli_fetch_assoc($result);
$totalJadwal = (int) $row['total'];
mysqli_stmt_close($stmt);

// Periksa apakah penugasan telah digunakan pada nilai rapor.
$stmt = mysqli_prepare(
    $koneksi,
    "SELECT COUNT(*) AS total
     FROM nilai_raport
     WHERE kelas_mapel_id = ?"
);
mysqli_stmt_bind_param($stmt, 'i', $id);
mysqli_stmt_execute($stmt);
$result = mysqli_stmt_get_result($stmt);
$row = mysqli_fetch_assoc($result);
$totalNilai = (int) $row['total'];
mysqli_stmt_close($stmt);

// Jangan menghapus penugasan yang masih digunakan.
if ($totalJadwal > 0 || $totalNilai > 0) {
    kirimRespons(
        409,
        'Penugasan tidak dapat dihapus karena sudah digunakan pada ' .
        $totalJadwal . ' jadwal dan ' . $totalNilai .
        ' data nilai. Pertahankan penugasan ini agar data akademik tetap aman.'
    );
}

// Hapus hanya jika belum digunakan oleh jadwal maupun nilai.
$stmt = mysqli_prepare(
    $koneksi,
    "DELETE FROM kelas_mapel WHERE id = ? AND aktif = 1"
);
mysqli_stmt_bind_param($stmt, 'i', $id);
$executed = mysqli_stmt_execute($stmt);
$affectedRows = mysqli_stmt_affected_rows($stmt);
mysqli_stmt_close($stmt);

if (!$executed) {
    kirimRespons(500, 'Gagal menghapus penugasan.');
}

if ($affectedRows !== 1) {
    kirimRespons(409, 'Penugasan berubah atau sudah tidak tersedia.');
}

kirimRespons(200, 'Penugasan berhasil dihapus.');
