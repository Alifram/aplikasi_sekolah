
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

$assignmentId = isset($_GET['kelas_mapel_id'])
    ? filter_var($_GET['kelas_mapel_id'], FILTER_VALIDATE_INT)
    : false;

$semester = isset($_GET['semester'])
    ? filter_var($_GET['semester'], FILTER_VALIDATE_INT)
    : false;

if (
    $guruId === false || $guruId <= 0 ||
    $assignmentId === false || $assignmentId <= 0 ||
    !in_array($semester, [1, 2], true)
) {
    http_response_code(400);
    echo json_encode([
        "status" => "error",
        "message" => "guru_id, kelas_mapel_id, dan semester wajib valid."
    ]);
    exit();
}

// Pastikan guru memiliki penugasan aktif.
$check = mysqli_prepare(
    $koneksi,
    "SELECT id
     FROM kelas_mapel
     WHERE id = ?
       AND guru_id = ?
       AND aktif = 1
     LIMIT 1"
);

if (!$check) {
    http_response_code(500);
    echo json_encode([
        "status" => "error",
        "message" => "Gagal menyiapkan pemeriksaan penugasan."
    ]);
    exit();
}

mysqli_stmt_bind_param(
    $check,
    "ii",
    $assignmentId,
    $guruId
);

if (!mysqli_stmt_execute($check)) {
    mysqli_stmt_close($check);
    http_response_code(500);
    echo json_encode([
        "status" => "error",
        "message" => "Gagal memeriksa penugasan."
    ]);
    exit();
}

$assignment = mysqli_fetch_assoc(
    mysqli_stmt_get_result($check)
);

mysqli_stmt_close($check);

if (!$assignment) {
    http_response_code(403);
    echo json_encode([
        "status" => "error",
        "message" => "Penugasan tidak ditemukan atau bukan milik guru ini."
    ]);
    exit();
}

$stmt = mysqli_prepare(
    $koneksi,
    "SELECT
         p.id,
         p.kelas_mapel_id,
         p.guru_id,
         p.semester,
         p.tahun_ajaran,
         p.nama_penilaian,
         p.jenis_penilaian,
         p.tanggal_penilaian,
         p.aktif,
         p.created_at
     FROM penilaian p
     WHERE p.kelas_mapel_id = ?
       AND p.guru_id = ?
       AND p.semester = ?
       AND p.aktif = 1
     ORDER BY
         FIELD(p.jenis_penilaian, 'harian', 'tugas', 'uts', 'uas'),
         p.tanggal_penilaian,
         p.id"
);

if (!$stmt) {
    http_response_code(500);
    echo json_encode([
        "status" => "error",
        "message" => "Gagal menyiapkan daftar penilaian."
    ]);
    exit();
}

mysqli_stmt_bind_param(
    $stmt,
    "iii",
    $assignmentId,
    $guruId,
    $semester
);

if (!mysqli_stmt_execute($stmt)) {
    mysqli_stmt_close($stmt);
    http_response_code(500);
    echo json_encode([
        "status" => "error",
        "message" => "Gagal mengambil daftar penilaian."
    ]);
    exit();
}

$result = mysqli_stmt_get_result($stmt);
$data = [];

while ($row = mysqli_fetch_assoc($result)) {
    $data[] = $row;
}

mysqli_stmt_close($stmt);

echo json_encode([
    "status" => "success",
    "data" => $data
]);

mysqli_close($koneksi);
?>