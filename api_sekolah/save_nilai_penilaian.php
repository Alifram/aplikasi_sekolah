
<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");
header("Content-Type: application/json; charset=UTF-8");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode([
        "status" => "error",
        "message" => "Gunakan metode POST."
    ]);
    exit();
}

include "koneksi.php";

$input = json_decode(file_get_contents('php://input'), true);

if (!is_array($input)) {
    http_response_code(400);
    echo json_encode([
        "status" => "error",
        "message" => "Format JSON tidak valid."
    ]);
    exit();
}

$required = ['guru_id', 'penilaian_id', 'siswa_id', 'skor_nilai'];

foreach ($required as $field) {
    if (
        !isset($input[$field]) ||
        !is_scalar($input[$field]) ||
        trim((string)$input[$field]) === ''
    ) {
        http_response_code(400);
        echo json_encode([
            "status" => "error",
            "message" => "Data nilai belum lengkap."
        ]);
        exit();
    }
}

$guruId = filter_var($input['guru_id'], FILTER_VALIDATE_INT);
$penilaianId = filter_var($input['penilaian_id'], FILTER_VALIDATE_INT);
$siswaId = filter_var($input['siswa_id'], FILTER_VALIDATE_INT);
$skor = filter_var($input['skor_nilai'], FILTER_VALIDATE_FLOAT);
$keterangan = isset($input['keterangan'])
    ? trim((string)$input['keterangan'])
    : '';

if (
    $guruId === false || $guruId <= 0 ||
    $penilaianId === false || $penilaianId <= 0 ||
    $siswaId === false || $siswaId <= 0 ||
    $skor === false || $skor < 0 || $skor > 100
) {
    http_response_code(400);
    echo json_encode([
        "status" => "error",
        "message" => "ID atau skor nilai tidak valid."
    ]);
    exit();
}

mysqli_begin_transaction($koneksi);

try {
    // Pastikan penilaian aktif dan dimiliki guru yang mengirim data.
    $stmt = mysqli_prepare(
        $koneksi,
        "SELECT
             p.id,
             km.kelas_id
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
         JOIN users g
           ON g.id = p.guru_id
          AND g.role = 'guru'
          AND g.is_deleted = 0
         WHERE p.id = ?
           AND p.guru_id = ?
           AND p.aktif = 1
           AND km.guru_id = ?
         LIMIT 1
         FOR UPDATE"
    );

    if (!$stmt) {
        throw new Exception("Gagal menyiapkan pemeriksaan penilaian.");
    }

    mysqli_stmt_bind_param(
        $stmt,
        "iii",
        $penilaianId,
        $guruId,
        $guruId
    );

    if (!mysqli_stmt_execute($stmt)) {
        mysqli_stmt_close($stmt);
        throw new Exception("Gagal memeriksa penilaian.");
    }

    $penilaian = mysqli_fetch_assoc(mysqli_stmt_get_result($stmt));
    mysqli_stmt_close($stmt);

    if (!$penilaian) {
        mysqli_rollback($koneksi);
        http_response_code(403);
        echo json_encode([
            "status" => "error",
            "message" => "Penilaian tidak ditemukan atau bukan milik guru ini."
        ]);
        exit();
    }

    // Pastikan siswa aktif dan terdaftar di kelas penugasan.
    $stmt = mysqli_prepare(
        $koneksi,
        "SELECT id
         FROM users
         WHERE id = ?
           AND role = 'siswa'
           AND is_deleted = 0
           AND kelas_id = ?
         LIMIT 1"
    );

    if (!$stmt) {
        throw new Exception("Gagal menyiapkan pemeriksaan siswa.");
    }

    $classId = (int)$penilaian['kelas_id'];

    mysqli_stmt_bind_param($stmt, "ii", $siswaId, $classId);

    if (!mysqli_stmt_execute($stmt)) {
        mysqli_stmt_close($stmt);
        throw new Exception("Gagal memeriksa data siswa.");
    }

    $siswa = mysqli_fetch_assoc(mysqli_stmt_get_result($stmt));
    mysqli_stmt_close($stmt);

    if (!$siswa) {
        mysqli_rollback($koneksi);
        http_response_code(403);
        echo json_encode([
            "status" => "error",
            "message" => "Siswa tidak aktif atau bukan anggota kelas penilaian."
        ]);
        exit();
    }

    // UNIQUE(penilaian_id, siswa_id) membuat nilai siswa tidak berduplikasi.
    // Jika sudah ada, nilai diperbarui, bukan membuat baris baru.
    $stmt = mysqli_prepare(
        $koneksi,
        "INSERT INTO nilai_penilaian
            (penilaian_id, siswa_id, skor_nilai, keterangan)
         VALUES (?, ?, ?, ?)
         ON DUPLICATE KEY UPDATE
            skor_nilai = VALUES(skor_nilai),
            keterangan = VALUES(keterangan)"
    );

    if (!$stmt) {
        throw new Exception("Gagal menyiapkan penyimpanan nilai.");
    }

    mysqli_stmt_bind_param(
        $stmt,
        "iids",
        $penilaianId,
        $siswaId,
        $skor,
        $keterangan
    );

    if (!mysqli_stmt_execute($stmt)) {
        mysqli_stmt_close($stmt);
        throw new Exception("Gagal menyimpan nilai siswa.");
    }

    mysqli_stmt_close($stmt);

    if (!mysqli_commit($koneksi)) {
        throw new Exception("Gagal menyelesaikan penyimpanan nilai.");
    }

    echo json_encode([
        "status" => "success",
        "message" => "Nilai siswa berhasil disimpan.",
        "data" => [
            "penilaian_id" => $penilaianId,
            "siswa_id" => $siswaId,
            "skor_nilai" => $skor
        ]
    ]);
} catch (Throwable $e) {
    mysqli_rollback($koneksi);
    error_log("save_nilai_penilaian.php: " . $e->getMessage());

    http_response_code(500);
    echo json_encode([
        "status" => "error",
        "message" => "Terjadi kesalahan saat menyimpan nilai."
    ]);
}

mysqli_close($koneksi);
?>