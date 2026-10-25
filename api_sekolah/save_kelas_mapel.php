
<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");
header("Content-Type: application/json; charset=UTF-8");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

include "koneksi.php";
include "jadwal_helpers.php";

$input = json_decode(file_get_contents('php://input'), true);

if (!is_array($input)) {
    http_response_code(400);
    echo json_encode([
        "status" => "error",
        "message" => "Format JSON tidak valid."
    ]);
    exit();
}

if (!isset($input['user_id']) ||
    !jadwal_require_admin($koneksi, $input['user_id'])) {
    if (!isset($input['user_id'])) {
        http_response_code(401);
        echo json_encode([
            "status" => "error",
            "message" => "Akun admin tidak valid."
        ]);
    }
    exit();
}

$kelasId = isset($input['kelas_id'])
    ? filter_var($input['kelas_id'], FILTER_VALIDATE_INT)
    : false;

$mapelId = isset($input['mata_pelajaran_id'])
    ? filter_var($input['mata_pelajaran_id'], FILTER_VALIDATE_INT)
    : false;

$guruId = isset($input['guru_id'])
    ? filter_var($input['guru_id'], FILTER_VALIDATE_INT)
    : false;

$tahunAjaran = isset($input['tahun_ajaran']) &&
    is_scalar($input['tahun_ajaran'])
    ? trim((string)$input['tahun_ajaran'])
    : '';

if ($kelasId === false || $kelasId <= 0 ||
    $mapelId === false || $mapelId <= 0 ||
    $guruId === false || $guruId <= 0 ||
    !preg_match('/^\d{4}\/\d{4}$/', $tahunAjaran) ||
    (int)substr($tahunAjaran, 5, 4) !==
        (int)substr($tahunAjaran, 0, 4) + 1) {
    http_response_code(400);
    echo json_encode([
        "status" => "error",
        "message" => "Pilih kelas, mapel, guru, dan tahun ajaran yang valid."
    ]);
    exit();
}

/* Validasi kelas, mata pelajaran, dan jenis guru */
$check = mysqli_prepare(
    $koneksi,
    "SELECT k.id
     FROM kelas k
     JOIN mata_pelajaran mp
       ON mp.id = ? AND mp.aktif = 1
     JOIN users u
       ON u.id = ?
      AND u.role = 'guru'
      AND u.is_deleted = 0
      AND (
          u.jenis_guru = 'guru_mapel'
          OR (
              u.jenis_guru = 'guru_kelas'
              AND u.kelas_id = k.id
          )
      )
     WHERE k.id = ?
       AND k.aktif = 1
     LIMIT 1"
);

if ($check === false) {
    http_response_code(500);
    echo json_encode([
        "status" => "error",
        "message" => "Gagal menyiapkan validasi data penugasan."
    ]);
    exit();
}

mysqli_stmt_bind_param(
    $check,
    "iii",
    $mapelId,
    $guruId,
    $kelasId
);

if (!mysqli_stmt_execute($check)) {
    mysqli_stmt_close($check);
    http_response_code(500);
    echo json_encode([
        "status" => "error",
        "message" => "Gagal memvalidasi kelas, mapel, dan guru."
    ]);
    exit();
}

$result = mysqli_stmt_get_result($check);
$valid = $result !== false &&
    mysqli_num_rows($result) === 1;

mysqli_stmt_close($check);

if (!$valid) {
    http_response_code(400);
    echo json_encode([
        "status" => "error",
        "message" => "Kelas atau mapel tidak aktif, akun guru tidak valid, atau penugasan tidak sesuai dengan jenis guru."
    ]);
    exit();
}

/* Simpan penugasan baru */
$insert = mysqli_prepare(
    $koneksi,
    "INSERT INTO kelas_mapel
        (kelas_id, mata_pelajaran_id, guru_id, tahun_ajaran, aktif)
     VALUES (?, ?, ?, ?, 1)"
);

if ($insert === false) {
    http_response_code(500);
    echo json_encode([
        "status" => "error",
        "message" => "Gagal menyiapkan penyimpanan penugasan."
    ]);
    exit();
}

mysqli_stmt_bind_param(
    $insert,
    "iiis",
    $kelasId,
    $mapelId,
    $guruId,
    $tahunAjaran
);

if (!mysqli_stmt_execute($insert)) {
    $errorCode = mysqli_stmt_errno($insert);
    mysqli_stmt_close($insert);

    if ($errorCode === 1062) {
        http_response_code(409);
        echo json_encode([
            "status" => "error",
            "message" => "Penugasan kelas dan mata pelajaran untuk tahun ajaran tersebut sudah ada."
        ]);
        exit();
    }

    http_response_code(500);
    echo json_encode([
        "status" => "error",
        "message" => "Gagal menyimpan penugasan kelas-mapel-guru."
    ]);
    exit();
}

mysqli_stmt_close($insert);

echo json_encode([
    "status" => "success",
    "message" => "Penugasan mapel berhasil ditambahkan."
]);

mysqli_close($koneksi);
?>
