
<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");
header("Content-Type: application/json; charset=UTF-8");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405);
    echo json_encode([
        "status" => "error",
        "message" => "Gunakan metode GET."
    ]);
    exit();
}

include "koneksi.php";

$guruId = isset($_GET['guru_id'])
    ? filter_var($_GET['guru_id'], FILTER_VALIDATE_INT)
    : false;

$penilaianId = isset($_GET['penilaian_id'])
    ? filter_var($_GET['penilaian_id'], FILTER_VALIDATE_INT)
    : false;

if (
    $guruId === false || $guruId <= 0 ||
    $penilaianId === false || $penilaianId <= 0
) {
    http_response_code(400);
    echo json_encode([
        "status" => "error",
        "message" => "guru_id dan penilaian_id wajib valid."
    ]);
    exit();
}

// Validasi kepemilikan penilaian oleh guru.
$check = mysqli_prepare(
    $koneksi,
    "SELECT p.id
     FROM penilaian p
     JOIN kelas_mapel km
       ON km.id = p.kelas_mapel_id
      AND km.aktif = 1
     JOIN kelas k
       ON k.id = km.kelas_id
      AND k.aktif = 1
     JOIN mata_pelajaran mp
       ON mp.id = km.mata_pelajaran_id
      AND mp.aktif = 1
     WHERE p.id = ?
       AND p.guru_id = ?
       AND km.guru_id = ?
       AND p.aktif = 1
     LIMIT 1"
);

if (!$check) {
    http_response_code(500);
    echo json_encode([
        "status" => "error",
        "message" => "Gagal menyiapkan pemeriksaan penilaian."
    ]);
    exit();
}

mysqli_stmt_bind_param(
    $check,
    "iii",
    $penilaianId,
    $guruId,
    $guruId
);

if (!mysqli_stmt_execute($check)) {
    mysqli_stmt_close($check);
    http_response_code(500);
    echo json_encode([
        "status" => "error",
        "message" => "Gagal memeriksa penilaian."
    ]);
    exit();
}

$valid = mysqli_fetch_assoc(mysqli_stmt_get_result($check));
mysqli_stmt_close($check);

if (!$valid) {
    http_response_code(403);
    echo json_encode([
        "status" => "error",
        "message" => "Penilaian tidak ditemukan atau bukan milik guru ini."
    ]);
    exit();
}

// Ambil semua siswa aktif dalam kelas penilaian.
// LEFT JOIN memastikan siswa tanpa nilai tetap muncul.
$stmt = mysqli_prepare(
    $koneksi,
    "SELECT
         s.id AS siswa_id,
         s.nomor_induk,
         s.nama_lengkap,
         np.id AS nilai_id,
         np.skor_nilai,
         np.keterangan
     FROM penilaian p
     JOIN kelas_mapel km
       ON km.id = p.kelas_mapel_id
     JOIN users s
       ON s.kelas_id = km.kelas_id
      AND s.role = 'siswa'
      AND s.is_deleted = 0
     LEFT JOIN nilai_penilaian np
       ON np.penilaian_id = p.id
      AND np.siswa_id = s.id
     WHERE p.id = ?
     ORDER BY s.nama_lengkap"
);

if (!$stmt) {
    http_response_code(500);
    echo json_encode([
        "status" => "error",
        "message" => "Gagal menyiapkan daftar nilai."
    ]);
    exit();
}

mysqli_stmt_bind_param($stmt, "i", $penilaianId);

if (!mysqli_stmt_execute($stmt)) {
    mysqli_stmt_close($stmt);
    http_response_code(500);
    echo json_encode([
        "status" => "error",
        "message" => "Gagal mengambil daftar nilai."
    ]);
    exit();
}

$result = mysqli_stmt_get_result($stmt);
$data = [];

while ($row = mysqli_fetch_assoc($result)) {
    $row['siswa_id'] = (int)$row['siswa_id'];
    $row['nilai_id'] = $row['nilai_id'] !== null
        ? (int)$row['nilai_id']
        : null;

    $row['skor_nilai'] = $row['skor_nilai'] !== null
        ? (float)$row['skor_nilai']
        : null;

    $data[] = $row;
}

mysqli_stmt_close($stmt);

echo json_encode([
    "status" => "success",
    "data" => $data
]);

mysqli_close($koneksi);
?>