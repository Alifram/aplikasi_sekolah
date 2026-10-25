
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

function kirimRespons($status, $message, $httpCode = 200) {
    http_response_code($httpCode);
    echo json_encode([
        "status" => $status,
        "message" => $message
    ]);
    exit();
}

$input = json_decode(file_get_contents('php://input'), true);

if (!is_array($input)) {
    kirimRespons("error", "Format JSON tidak valid.", 400);
}

$userId = filter_var($input['user_id'] ?? null, FILTER_VALIDATE_INT);
$id = filter_var($input['id'] ?? null, FILTER_VALIDATE_INT);
$kelasId = filter_var($input['kelas_id'] ?? null, FILTER_VALIDATE_INT);
$mapelId = filter_var($input['mata_pelajaran_id'] ?? null, FILTER_VALIDATE_INT);
$guruId = filter_var($input['guru_id'] ?? null, FILTER_VALIDATE_INT);
$tahunAjaran = isset($input['tahun_ajaran']) && is_scalar($input['tahun_ajaran'])
    ? trim((string) $input['tahun_ajaran'])
    : '';

if (!$userId || !jadwal_require_admin($koneksi, $userId)) {
    exit();
}

if (
    !$id ||
    !$kelasId ||
    !$mapelId ||
    !$guruId ||
    !preg_match('/^\d{4}\/\d{4}$/', $tahunAjaran)
) {
    kirimRespons("error", "Data penugasan tidak valid.", 400);
}

$stmt = mysqli_prepare(
    $koneksi,
    "SELECT id FROM kelas_mapel WHERE id = ? AND aktif = 1 LIMIT 1"
);
mysqli_stmt_bind_param($stmt, "i", $id);
mysqli_stmt_execute($stmt);
$existing = mysqli_stmt_get_result($stmt);
$found = mysqli_num_rows($existing) === 1;
mysqli_stmt_close($stmt);

if (!$found) {
    kirimRespons("error", "Penugasan tidak ditemukan atau sudah tidak aktif.", 404);
}

$stmt = mysqli_prepare(
    $koneksi,
    "SELECT k.id
     FROM kelas k
     JOIN mata_pelajaran mp
       ON mp.id = ? AND mp.aktif = 1
     JOIN users u
       ON u.id = ? AND u.role = 'guru'
      AND u.is_deleted = 0 AND u.kelas_id = k.id
     WHERE k.id = ? AND k.aktif = 1
     LIMIT 1"
);
mysqli_stmt_bind_param($stmt, "iii", $mapelId, $guruId, $kelasId);
mysqli_stmt_execute($stmt);
$valid = mysqli_num_rows(mysqli_stmt_get_result($stmt)) === 1;
mysqli_stmt_close($stmt);

if (!$valid) {
    kirimRespons(
        "error",
        "Kelas atau mapel tidak aktif, atau guru bukan guru dari kelas yang dipilih.",
        400
    );
}

$stmt = mysqli_prepare(
    $koneksi,
    "SELECT id
     FROM kelas_mapel
     WHERE kelas_id = ?
       AND mata_pelajaran_id = ?
       AND tahun_ajaran = ?
       AND id <> ?
     LIMIT 1"
);
mysqli_stmt_bind_param($stmt, "iisi", $kelasId, $mapelId, $tahunAjaran, $id);
mysqli_stmt_execute($stmt);
$duplicate = mysqli_num_rows(mysqli_stmt_get_result($stmt)) > 0;
mysqli_stmt_close($stmt);

if ($duplicate) {
    kirimRespons(
        "error",
        "Penugasan untuk kelas, mapel, dan tahun ajaran tersebut sudah ada.",
        409
    );
}

$stmt = mysqli_prepare(
    $koneksi,
    "SELECT
       (SELECT COUNT(*) FROM jadwal_pelajaran WHERE kelas_mapel_id = ?) AS jumlah_jadwal,
       (SELECT COUNT(*) FROM nilai_raport WHERE kelas_mapel_id = ?) AS jumlah_nilai"
);
mysqli_stmt_bind_param($stmt, "ii", $id, $id);
mysqli_stmt_execute($stmt);
$usage = mysqli_fetch_assoc(mysqli_stmt_get_result($stmt));
mysqli_stmt_close($stmt);

$hasUsage = ((int) $usage['jumlah_jadwal'] > 0) ||
            ((int) $usage['jumlah_nilai'] > 0);

if ($hasUsage) {
    $stmt = mysqli_prepare(
        $koneksi,
        "SELECT kelas_id, mata_pelajaran_id, tahun_ajaran
         FROM kelas_mapel
         WHERE id = ? LIMIT 1"
    );
    mysqli_stmt_bind_param($stmt, "i", $id);
    mysqli_stmt_execute($stmt);
    $old = mysqli_fetch_assoc(mysqli_stmt_get_result($stmt));
    mysqli_stmt_close($stmt);

    if (
        (int) $old['kelas_id'] !== $kelasId ||
        (int) $old['mata_pelajaran_id'] !== $mapelId ||
        $old['tahun_ajaran'] !== $tahunAjaran
    ) {
        kirimRespons(
            "error",
            "Penugasan sudah memiliki jadwal atau nilai. Kelas, mapel, dan tahun ajaran tidak boleh diubah. Buat penugasan baru untuk perubahan tersebut.",
            409
        );
    }
}

$stmt = mysqli_prepare(
    $koneksi,
    "UPDATE kelas_mapel
     SET kelas_id = ?, mata_pelajaran_id = ?, guru_id = ?, tahun_ajaran = ?
     WHERE id = ? AND aktif = 1"
);

if (!$stmt) {
    kirimRespons("error", "Gagal menyiapkan perubahan penugasan.", 500);
}

mysqli_stmt_bind_param(
    $stmt,
    "iiisi",
    $kelasId,
    $mapelId,
    $guruId,
    $tahunAjaran,
    $id
);

if (!mysqli_stmt_execute($stmt)) {
    mysqli_stmt_close($stmt);
    kirimRespons("error", "Gagal memperbarui penugasan.", 500);
}

mysqli_stmt_close($stmt);
mysqli_close($koneksi);

kirimRespons("success", "Penugasan mapel berhasil diperbarui.");
?>
