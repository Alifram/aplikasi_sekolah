```php
<?php
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");

date_default_timezone_set('Asia/Jakarta');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

require_once 'koneksi.php';

mysqli_set_charset($koneksi, "utf8mb4");

// Hari mengikuti waktu Indonesia Barat.

$hariInggris = date('l');

$pemetaanHari = [
    'Monday'    => 'Senin',
    'Tuesday'   => 'Selasa',
    'Wednesday' => 'Rabu',
    'Thursday'  => 'Kamis',
    'Friday'    => 'Jumat',
    'Saturday'  => 'Sabtu',
    'Sunday'    => 'Minggu'
];

$hariSekarang = $pemetaanHari[$hariInggris];

// Jika parameter hari dikirim, gunakan untuk filter.
// Jika tidak, gunakan hari WIB saat ini.
$hariDiminta = isset($_GET['hari'])
    ? trim($_GET['hari'])
    : $hariSekarang;

if (!in_array($hariDiminta, array_values($pemetaanHari), true)) {
    http_response_code(400);
    echo json_encode([
        "status" => "error",
        "message" => "Nama hari tidak valid."
    ]);
    mysqli_close($koneksi);
    exit;
}

$hariIni = $hariDiminta;

// Filter opsional untuk guru atau kelas.
$guru = isset($_GET['guru'])
    ? trim($_GET['guru'])
    : '';

$kelas = isset($_GET['kelas'])
    ? trim($_GET['kelas'])
    : '';

$sql = "
    SELECT
        id,
        kelas,
        hari,
        jam_mulai,
        jam_selesai,
        mata_pelajaran,
        guru_pengampu,
        COALESCE(NULLIF(ruangan, ''), 'Ruang Kelas') AS ruangan
    FROM jadwal_pelajaran
    WHERE hari = ?
";

$types = "s";
$params = [$hariIni];

if ($guru !== '') {
    $sql .= " AND guru_pengampu = ?";
    $types .= "s";
    $params[] = $guru;
}

if ($kelas !== '') {
    $sql .= " AND kelas = ?";
    $types .= "s";
    $params[] = $kelas;
}

$sql .= " ORDER BY jam_mulai ASC";

$stmt = mysqli_prepare($koneksi, $sql);

if (!$stmt) {
    http_response_code(500);
    echo json_encode([
        "status" => "error",
        "message" => "Gagal menyiapkan query jadwal."
    ]);
    exit;
}

mysqli_stmt_bind_param($stmt, $types, ...$params);
mysqli_stmt_execute($stmt);

$result = mysqli_stmt_get_result($stmt);
$jadwal = [];

while ($row = mysqli_fetch_assoc($result)) {
    $jadwal[] = $row;
}

echo json_encode([
    "status" => "success",
    "hari" => $hariIni,
    "tanggal" => date('Y-m-d'),
    "zona_waktu" => "Asia/Jakarta",
    "data" => $jadwal
], JSON_UNESCAPED_UNICODE);

mysqli_stmt_close($stmt);
mysqli_close($koneksi);
?>
```
