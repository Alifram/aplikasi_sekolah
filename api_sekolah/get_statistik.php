
<?php
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

include "koneksi.php";

$admissionYear = isset($_GET['angkatan'])
    ? filter_var($_GET['angkatan'], FILTER_VALIDATE_INT)
    : (int)date('Y');

if (
    $admissionYear === false ||
    $admissionYear < 2000 ||
    $admissionYear > (int)date('Y') + 5
) {
    http_response_code(400);
    echo json_encode([
        "status" => "error",
        "message" => "Tahun angkatan tidak valid."
    ]);
    exit();
}

// Siapkan semua kelas aktif agar format respons tetap sama.
$classesResult = mysqli_query(
    $koneksi,
    "SELECT id, nama FROM kelas WHERE aktif = 1 ORDER BY nama"
);

if ($classesResult === false) {
    http_response_code(500);
    echo json_encode([
        "status" => "error",
        "message" => "Gagal mengambil daftar kelas."
    ]);
    exit();
}

$data = [];
$classIds = [];

while ($class = mysqli_fetch_assoc($classesResult)) {
    $classId = (int)$class['id'];
    $className = $class['nama'];

    $classIds[$classId] = $className;
    $data[$className] = [
        "semester_1" => 0.0,
        "semester_2" => 0.0
    ];
}

/*
 * Ambil nilai lama berdasarkan angkatan siswa.
 * Nilai per komponen dirata-ratakan, bukan menjumlahkan
 * komponen yang kosong sebagai nilai nol.
 */
$sqlLama = "
    SELECT
        n.siswa_id,
        n.kelas_mapel_id,
        n.semester,
        km.kelas_id,
        n.mata_pelajaran,
        AVG(n.nilai_tugas) AS nilai_tugas,
        AVG(n.nilai_uts) AS nilai_uts,
        AVG(n.nilai_uas) AS nilai_uas
    FROM nilai_raport n
    JOIN kelas_mapel km ON km.id = n.kelas_mapel_id
    JOIN kelas k ON k.id = km.kelas_id
    WHERE n.tahun_angkatan = ?
      AND k.aktif = 1
    GROUP BY
        n.siswa_id,
        n.kelas_mapel_id,
        n.semester,
        km.kelas_id,
        n.mata_pelajaran
";

$stmtLama = mysqli_prepare($koneksi, $sqlLama);

if ($stmtLama === false) {
    http_response_code(500);
    echo json_encode([
        "status" => "error",
        "message" => "Gagal menyiapkan nilai lama."
    ]);
    exit();
}

mysqli_stmt_bind_param($stmtLama, "i", $admissionYear);

if (!mysqli_stmt_execute($stmtLama)) {
    mysqli_stmt_close($stmtLama);
    http_response_code(500);
    echo json_encode([
        "status" => "error",
        "message" => "Gagal mengambil nilai lama."
    ]);
    exit();
}

$nilaiLama = [];
$resultLama = mysqli_stmt_get_result($stmtLama);

while ($row = mysqli_fetch_assoc($resultLama)) {
    $key = implode('|', [
        $row['siswa_id'],
        $row['kelas_mapel_id'],
        $row['semester']
    ]);

    $nilaiLama[$key] = [
        'siswa_id' => (int)$row['siswa_id'],
        'kelas_id' => (int)$row['kelas_id'],
        'semester' => (int)$row['semester'],
        'nilai_tugas' => $row['nilai_tugas'] !== null
            ? (float)$row['nilai_tugas'] : null,
        'nilai_uts' => $row['nilai_uts'] !== null
            ? (float)$row['nilai_uts'] : null,
        'nilai_uas' => $row['nilai_uas'] !== null
            ? (float)$row['nilai_uas'] : null
    ];
}

mysqli_stmt_close($stmtLama);

/*
 * Ambil nilai baru per siswa, penugasan, dan semester.
 * Harian dan tugas digabung menjadi satu komponen.
 */
$sqlBaru = "
    SELECT
        u.id AS siswa_id,
        u.tahun_angkatan,
        km.id AS kelas_mapel_id,
        km.kelas_id,
        p.semester,
        AVG(
            CASE
                WHEN p.jenis_penilaian IN ('harian', 'tugas')
                THEN np.skor_nilai
            END
        ) AS nilai_tugas,
        MAX(
            CASE
                WHEN p.jenis_penilaian = 'uts'
                THEN np.skor_nilai
            END
        ) AS nilai_uts,
        MAX(
            CASE
                WHEN p.jenis_penilaian = 'uas'
                THEN np.skor_nilai
            END
        ) AS nilai_uas
    FROM users u
    JOIN kelas k ON k.id = u.kelas_id AND k.aktif = 1
    JOIN kelas_mapel km ON km.kelas_id = k.id AND km.aktif = 1
    JOIN penilaian p
        ON p.kelas_mapel_id = km.id
       AND p.aktif = 1
       AND p.tahun_ajaran = km.tahun_ajaran
    JOIN nilai_penilaian np
        ON np.penilaian_id = p.id
       AND np.siswa_id = u.id
    WHERE u.role = 'siswa'
      AND u.is_deleted = 0
      AND u.tahun_angkatan = ?
    GROUP BY
        u.id,
        u.tahun_angkatan,
        km.id,
        km.kelas_id,
        p.semester
";

$stmtBaru = mysqli_prepare($koneksi, $sqlBaru);

if ($stmtBaru === false) {
    http_response_code(500);
    echo json_encode([
        "status" => "error",
        "message" => "Gagal menyiapkan nilai baru."
    ]);
    exit();
}

mysqli_stmt_bind_param($stmtBaru, "i", $admissionYear);

if (!mysqli_stmt_execute($stmtBaru)) {
    mysqli_stmt_close($stmtBaru);
    http_response_code(500);
    echo json_encode([
        "status" => "error",
        "message" => "Gagal mengambil nilai baru."
    ]);
    exit();
}

$nilaiBaru = [];
$resultBaru = mysqli_stmt_get_result($stmtBaru);

while ($row = mysqli_fetch_assoc($resultBaru)) {
    $key = implode('|', [
        $row['siswa_id'],
        $row['kelas_mapel_id'],
        $row['semester']
    ]);

    $nilaiBaru[$key] = [
        'siswa_id' => (int)$row['siswa_id'],
        'kelas_id' => (int)$row['kelas_id'],
        'semester' => (int)$row['semester'],
        'nilai_tugas' => $row['nilai_tugas'] !== null
            ? (float)$row['nilai_tugas'] : null,
        'nilai_uts' => $row['nilai_uts'] !== null
            ? (float)$row['nilai_uts'] : null,
        'nilai_uas' => $row['nilai_uas'] !== null
            ? (float)$row['nilai_uas'] : null
    ];
}

mysqli_stmt_close($stmtBaru);

/*
 * Gabungkan komponen:
 * - nilai baru dipakai jika tersedia;
 * - jika belum tersedia, gunakan nilai lama;
 * - setiap komponen hanya dihitung satu kali.
 */
$gabungan = $nilaiLama;

foreach ($nilaiBaru as $key => $baru) {
    if (!isset($gabungan[$key])) {
        $gabungan[$key] = $baru;
        continue;
    }

    foreach (['nilai_tugas', 'nilai_uts', 'nilai_uas'] as $komponen) {
        if ($baru[$komponen] !== null) {
            $gabungan[$key][$komponen] = $baru[$komponen];
        }
    }
}

/*
 * Hitung rata-rata seluruh komponen yang tersedia,
 * lalu rata-ratakan hasil per siswa/penugasan dalam kelas
 * dan semester yang sesuai.
 */
$akumulasi = [];

foreach ($gabungan as $nilai) {
    $kelasId = $nilai['kelas_id'];
    $semester = $nilai['semester'];

    if (!isset($classIds[$kelasId]) || !in_array($semester, [1, 2], true)) {
        continue;
    }

    $komponenTersedia = [];

    foreach (['nilai_tugas', 'nilai_uts', 'nilai_uas'] as $komponen) {
        if ($nilai[$komponen] !== null) {
            $komponenTersedia[] = $nilai[$komponen];
        }
    }

    if (count($komponenTersedia) === 0) {
        continue;
    }

    $rataSiswa = array_sum($komponenTersedia) / count($komponenTersedia);
    $key = $kelasId . '|' . $semester;

    if (!isset($akumulasi[$key])) {
        $akumulasi[$key] = [
            'kelas_id' => $kelasId,
            'semester' => $semester,
            'total' => 0.0,
            'jumlah' => 0
        ];
    }

    $akumulasi[$key]['total'] += $rataSiswa;
    $akumulasi[$key]['jumlah']++;
}

foreach ($akumulasi as $hasil) {
    $namaKelas = $classIds[$hasil['kelas_id']];
    $semesterKey = $hasil['semester'] === 1
        ? 'semester_1'
        : 'semester_2';

    $data[$namaKelas][$semesterKey] = round(
        $hasil['total'] / $hasil['jumlah'],
        1
    );
}

echo json_encode([
    "status" => "success",
    "data" => $data
]);

mysqli_close($koneksi);
?>
