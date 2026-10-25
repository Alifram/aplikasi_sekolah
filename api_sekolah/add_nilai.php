<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");
header("Content-Type: application/json; charset=UTF-8");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

include "koneksi.php";

$input = json_decode(file_get_contents('php://input'), true);
$required = ['siswa_id', 'guru_id', 'semester', 'kelas_mapel_id', 'jenis_nilai', 'skor_nilai'];
if (!is_array($input)) {
    http_response_code(400);
    echo json_encode(["status" => "error", "message" => "Format JSON tidak valid."]);
    exit();
}
foreach ($required as $field) {
    if (!isset($input[$field]) || !is_scalar($input[$field]) || trim((string)$input[$field]) === '') {
        http_response_code(400);
        echo json_encode(["status" => "error", "message" => "Data input nilai belum lengkap."]);
        exit();
    }
}

$studentId = filter_var($input['siswa_id'], FILTER_VALIDATE_INT);
$teacherId = filter_var($input['guru_id'], FILTER_VALIDATE_INT);
$assignmentId = filter_var($input['kelas_mapel_id'], FILTER_VALIDATE_INT);
$semesterLabel = trim((string)$input['semester']);
$gradeType = (string)$input['jenis_nilai'];
$score = filter_var($input['skor_nilai'], FILTER_VALIDATE_FLOAT);
$note = isset($input['keterangan']) ? trim((string)$input['keterangan']) : '';
$gradeColumns = ['tugas' => 'nilai_tugas', 'uts' => 'nilai_uts', 'uas' => 'nilai_uas'];

if ($studentId === false || $studentId <= 0 ||
    $teacherId === false || $teacherId <= 0 ||
    $assignmentId === false || $assignmentId <= 0 ||
    !in_array($semesterLabel, ['Semester 1', 'Semester 2'], true) ||
    !isset($gradeColumns[$gradeType]) ||
    $score === false || $score < 0 || $score > 100) {
    http_response_code(400);
    echo json_encode(["status" => "error", "message" => "Semester, penugasan, atau skor nilai tidak valid."]);
    exit();
}
$semester = $semesterLabel === 'Semester 1' ? 1 : 2;
$gradeColumn = $gradeColumns[$gradeType];

mysqli_begin_transaction($koneksi);


$assignment = mysqli_prepare(
    $koneksi,
    "SELECT km.kelas_id, km.guru_id, km.tahun_ajaran,
            k.nama AS kelas, mp.nama AS mata_pelajaran
     FROM kelas_mapel km
     JOIN kelas k
       ON k.id = km.kelas_id
      AND k.aktif = 1
     JOIN mata_pelajaran mp
       ON mp.id = km.mata_pelajaran_id
      AND mp.aktif = 1
     JOIN users g
       ON g.id = km.guru_id
      AND g.role = 'guru'
      AND g.is_deleted = 0
      AND (
          g.jenis_guru = 'guru_mapel'
          OR (
              g.jenis_guru = 'guru_kelas'
              AND g.kelas_id = km.kelas_id
          )
      )
     WHERE km.id = ?
       AND km.guru_id = ?
       AND km.aktif = 1
     LIMIT 1
     FOR UPDATE"
);
if ($assignment === false) {
    mysqli_rollback($koneksi);
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Gagal menyiapkan pemeriksaan penugasan mapel."]);
    exit();
}
mysqli_stmt_bind_param($assignment, "ii", $assignmentId, $teacherId);
if (!mysqli_stmt_execute($assignment)) {
    mysqli_stmt_close($assignment);
    mysqli_rollback($koneksi);
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Gagal memeriksa penugasan mapel."]);
    exit();
}
$assignmentData = mysqli_fetch_assoc(mysqli_stmt_get_result($assignment));
mysqli_stmt_close($assignment);
if ($assignmentData === null) {
    mysqli_rollback($koneksi);
    http_response_code(403);
    echo json_encode(["status" => "error", "message" => "Guru tidak terdaftar sebagai pengampu penugasan mapel ini."]);
    exit();
}

$studentStmt = mysqli_prepare(
    $koneksi,
    "SELECT tahun_angkatan, kelas_id FROM users
     WHERE id = ? AND role = 'siswa' AND is_deleted = 0 LIMIT 1"
);
if ($studentStmt === false) {
    mysqli_rollback($koneksi);
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Gagal menyiapkan pemeriksaan siswa."]);
    exit();
}
mysqli_stmt_bind_param($studentStmt, "i", $studentId);
if (!mysqli_stmt_execute($studentStmt)) {
    mysqli_stmt_close($studentStmt);
    mysqli_rollback($koneksi);
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Gagal memeriksa data siswa."]);
    exit();
}
$student = mysqli_fetch_assoc(mysqli_stmt_get_result($studentStmt));
mysqli_stmt_close($studentStmt);
if ($student === null || (int)$student['tahun_angkatan'] <= 0) {
    mysqli_rollback($koneksi);
    http_response_code(400);
    echo json_encode(["status" => "error", "message" => "Siswa tidak ditemukan atau tahun angkatannya belum diatur."]);
    exit();
}
if ((int)$student['kelas_id'] !== (int)$assignmentData['kelas_id']) {
    mysqli_rollback($koneksi);
    http_response_code(403);
    echo json_encode([
        "status" => "error",
        "message" => "Siswa tidak terdaftar di kelas untuk penugasan mapel yang dipilih."
    ]);
    exit();
}
$admissionYear = (int)$student['tahun_angkatan'];

$find = mysqli_prepare(
    $koneksi,
    "SELECT id FROM nilai_raport
     WHERE siswa_id = ? AND semester = ? AND kelas_mapel_id = ? AND tahun_angkatan = ?
     ORDER BY id DESC LIMIT 1 FOR UPDATE"
);
if ($find === false) {
    mysqli_rollback($koneksi);
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Gagal menyiapkan pencarian nilai."]);
    exit();
}
mysqli_stmt_bind_param($find, "iiii", $studentId, $semester, $assignmentId, $admissionYear);
if (!mysqli_stmt_execute($find)) {
    mysqli_stmt_close($find);
    mysqli_rollback($koneksi);
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Gagal mencari data nilai."]);
    exit();
}
$existing = mysqli_fetch_assoc(mysqli_stmt_get_result($find));
mysqli_stmt_close($find);

if ($existing !== null) {
    $recordId = (int)$existing['id'];
    $updateSql = $note === ''
        ? "UPDATE nilai_raport SET $gradeColumn = ?, guru_id = ? WHERE id = ?"
        : "UPDATE nilai_raport SET $gradeColumn = ?, guru_id = ?, keterangan = ? WHERE id = ?";
    $update = mysqli_prepare($koneksi, $updateSql);
    if ($update === false) {
        mysqli_rollback($koneksi);
        http_response_code(500);
        echo json_encode(["status" => "error", "message" => "Gagal menyiapkan pembaruan nilai."]);
        exit();
    }
    if ($note === '') {
        mysqli_stmt_bind_param($update, "dii", $score, $teacherId, $recordId);
    } else {
        mysqli_stmt_bind_param($update, "disi", $score, $teacherId, $note, $recordId);
    }
    $saved = mysqli_stmt_execute($update);
    mysqli_stmt_close($update);
} else {
    $homework = $gradeType === 'tugas' ? $score : null;
    $midterm = $gradeType === 'uts' ? $score : null;
    $final = $gradeType === 'uas' ? $score : null;
    $insert = mysqli_prepare(
        $koneksi,
        "INSERT INTO nilai_raport
         (siswa_id, guru_id, semester, tahun_angkatan, mata_pelajaran,
          nilai_tugas, nilai_uts, nilai_uas, keterangan, kelas_mapel_id)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
    );
    if ($insert === false) {
        mysqli_rollback($koneksi);
        http_response_code(500);
        echo json_encode(["status" => "error", "message" => "Gagal menyiapkan penyimpanan nilai."]);
        exit();
    }
    mysqli_stmt_bind_param(
        $insert,
        "iiiisdddsi",
        $studentId,
        $teacherId,
        $semester,
        $admissionYear,
        $assignmentData['mata_pelajaran'],
        $homework,
        $midterm,
        $final,
        $note,
        $assignmentId
    );
    $saved = mysqli_stmt_execute($insert);
    mysqli_stmt_close($insert);
}

if (!$saved) {
    mysqli_rollback($koneksi);
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Gagal menyimpan nilai ke database."]);
    exit();
}
if (!mysqli_commit($koneksi)) {
    mysqli_rollback($koneksi);
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Gagal menyelesaikan penyimpanan nilai."]);
    exit();
}

echo json_encode([
    "status" => "success",
    "message" => "Nilai " . strtoupper($gradeType) . " berhasil disimpan ke rapor digital."
]);
mysqli_close($koneksi);
?>
