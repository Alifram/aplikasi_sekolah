
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

$required = [
    'guru_id',
    'kelas_mapel_id',
    'semester',
    'nama_penilaian',
    'jenis_penilaian'
];

foreach ($required as $field) {
    if (
        !isset($input[$field]) ||
        !is_scalar($input[$field]) ||
        trim((string)$input[$field]) === ''
    ) {
        http_response_code(400);
        echo json_encode([
            "status" => "error",
            "message" => "Data penilaian belum lengkap."
        ]);
        exit();
    }
}

$guruId = filter_var($input['guru_id'], FILTER_VALIDATE_INT);
$assignmentId = filter_var(
    $input['kelas_mapel_id'],
    FILTER_VALIDATE_INT
);
$semester = filter_var($input['semester'], FILTER_VALIDATE_INT);

$nama = trim((string)$input['nama_penilaian']);
$jenis = trim((string)$input['jenis_penilaian']);

$tanggal = isset($input['tanggal_penilaian'])
    && trim((string)$input['tanggal_penilaian']) !== ''
    ? trim((string)$input['tanggal_penilaian'])
    : null;

$jenisValid = ['harian', 'tugas', 'uts', 'uas'];

if (
    $guruId === false || $guruId <= 0 ||
    $assignmentId === false || $assignmentId <= 0 ||
    !in_array($semester, [1, 2], true) ||
    !in_array($jenis, $jenisValid, true) ||
    $nama === '' ||
    mb_strlen($nama) > 100
) {
    http_response_code(400);
    echo json_encode([
        "status" => "error",
        "message" => "Data penilaian tidak valid."
    ]);
    exit();
}

if ($tanggal !== null) {
    $date = DateTime::createFromFormat('!Y-m-d', $tanggal);

    if (
        !$date ||
        $date->format('Y-m-d') !== $tanggal
    ) {
        http_response_code(400);
        echo json_encode([
            "status" => "error",
            "message" => "Format tanggal harus YYYY-MM-DD."
        ]);
        exit();
    }
}

mysqli_begin_transaction($koneksi);

try {
    $stmt = mysqli_prepare(
        $koneksi,
        "SELECT km.id, km.tahun_ajaran
         FROM kelas_mapel km
         JOIN kelas k
           ON k.id = km.kelas_id
          AND k.aktif = 1
         JOIN mata_pelajaran mp
           ON mp.id = km.mata_pelajaran_id
          AND mp.aktif = 1
         JOIN users u
           ON u.id = km.guru_id
          AND u.role = 'guru'
          AND u.is_deleted = 0
         WHERE km.id = ?
           AND km.guru_id = ?
           AND km.aktif = 1
         LIMIT 1
         FOR UPDATE"
    );

    if (!$stmt) {
        throw new Exception("Gagal menyiapkan pemeriksaan penugasan.");
    }

    mysqli_stmt_bind_param(
        $stmt,
        "ii",
        $assignmentId,
        $guruId
    );

    if (!mysqli_stmt_execute($stmt)) {
        mysqli_stmt_close($stmt);
        throw new Exception("Gagal memeriksa penugasan guru.");
    }

    $assignment = mysqli_fetch_assoc(
        mysqli_stmt_get_result($stmt)
    );

    mysqli_stmt_close($stmt);

    if (!$assignment) {
        mysqli_rollback($koneksi);
        http_response_code(403);
        echo json_encode([
            "status" => "error",
            "message" => "Penugasan tidak ditemukan atau bukan milik guru ini."
        ]);
        exit();
    }

    if (in_array($jenis, ['uts', 'uas'], true)) {
        $check = mysqli_prepare(
            $koneksi,
            "SELECT id
             FROM penilaian
             WHERE kelas_mapel_id = ?
               AND semester = ?
               AND tahun_ajaran = ?
               AND jenis_penilaian = ?
               AND aktif = 1
             LIMIT 1"
        );

        if (!$check) {
            throw new Exception("Gagal menyiapkan pemeriksaan penilaian.");
        }

        $year = $assignment['tahun_ajaran'];

        mysqli_stmt_bind_param(
            $check,
            "iiss",
            $assignmentId,
            $semester,
            $year,
            $jenis
        );

        if (!mysqli_stmt_execute($check)) {
            mysqli_stmt_close($check);
            throw new Exception("Gagal memeriksa penilaian yang sudah ada.");
        }

        $duplicate = mysqli_fetch_assoc(
            mysqli_stmt_get_result($check)
        );

        mysqli_stmt_close($check);

        if ($duplicate) {
            mysqli_rollback($koneksi);
            http_response_code(409);
            echo json_encode([
                "status" => "error",
                "message" => strtoupper($jenis) .
                    " aktif sudah dibuat untuk semester ini."
            ]);
            exit();
        }
    }

    $year = $assignment['tahun_ajaran'];

    $insert = mysqli_prepare(
        $koneksi,
        "INSERT INTO penilaian
         (
             kelas_mapel_id,
             guru_id,
             semester,
             tahun_ajaran,
             nama_penilaian,
             jenis_penilaian,
             tanggal_penilaian
         )
         VALUES (?, ?, ?, ?, ?, ?, ?)"
    );

    if (!$insert) {
        throw new Exception("Gagal menyiapkan penyimpanan penilaian.");
    }

    mysqli_stmt_bind_param(
        $insert,
        "iiissss",
        $assignmentId,
        $guruId,
        $semester,
        $year,
        $nama,
        $jenis,
        $tanggal
    );

    if (!mysqli_stmt_execute($insert)) {
        mysqli_stmt_close($insert);
        throw new Exception("Gagal menyimpan penilaian.");
    }

    $newId = mysqli_insert_id($koneksi);
    mysqli_stmt_close($insert);

    if (!mysqli_commit($koneksi)) {
        throw new Exception("Gagal menyelesaikan transaksi.");
    }

    echo json_encode([
        "status" => "success",
        "message" => "Penilaian berhasil dibuat.",
        "data" => [
            "id" => $newId,
            "kelas_mapel_id" => $assignmentId,
            "guru_id" => $guruId,
            "semester" => $semester,
            "tahun_ajaran" => $year,
            "nama_penilaian" => $nama,
            "jenis_penilaian" => $jenis,
            "tanggal_penilaian" => $tanggal
        ]
    ]);
} catch (Throwable $e) {
    mysqli_rollback($koneksi);
    http_response_code(500);

    error_log("save_penilaian.php: " . $e->getMessage());

    echo json_encode([
        "status" => "error",
        "message" => "Terjadi kesalahan saat menyimpan penilaian."
    ]);
}

mysqli_close($koneksi);
?>
