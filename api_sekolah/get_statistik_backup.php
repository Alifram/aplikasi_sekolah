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
if ($admissionYear === false || $admissionYear < 2000 || $admissionYear > (int)date('Y') + 5) {
    http_response_code(400);
    echo json_encode(["status" => "error", "message" => "Tahun angkatan tidak valid."]);
    exit();
}

$classesResult = mysqli_query($koneksi, "SELECT nama FROM kelas WHERE aktif = 1 ORDER BY nama");
if ($classesResult === false) {
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Gagal mengambil daftar kelas."]);
    exit();
}
$data = [];
while ($class = mysqli_fetch_assoc($classesResult)) {
    $data[$class['nama']] = ["semester_1" => 0.0, "semester_2" => 0.0];
}

$stmt = mysqli_prepare(
    $koneksi,
    "SELECT k.nama AS nama_kelas, n.semester AS nomor_semester,
            SUM(COALESCE(n.nilai_tugas, 0) + COALESCE(n.nilai_uts, 0) + COALESCE(n.nilai_uas, 0)) /
            NULLIF(SUM((n.nilai_tugas IS NOT NULL) + (n.nilai_uts IS NOT NULL) + (n.nilai_uas IS NOT NULL)), 0)
              AS rerata_nilai
     FROM nilai_raport n
     JOIN kelas_mapel km ON km.id = n.kelas_mapel_id
     JOIN kelas k ON k.id = km.kelas_id
     WHERE n.tahun_angkatan = ?
     GROUP BY k.id, k.nama, n.semester"
);
if ($stmt === false) {
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Gagal menyiapkan statistik nilai."]);
    exit();
}
mysqli_stmt_bind_param($stmt, "i", $admissionYear);
if (!mysqli_stmt_execute($stmt)) {
    mysqli_stmt_close($stmt);
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Gagal menghitung statistik nilai."]);
    exit();
}

$result = mysqli_stmt_get_result($stmt);
while ($row = mysqli_fetch_assoc($result)) {
    $className = $row['nama_kelas'];
    if (!isset($data[$className])) {
        continue;
    }
    $semesterKey = (int)$row['nomor_semester'] === 1 ? 'semester_1' : 'semester_2';
    $data[$className][$semesterKey] = round((float)$row['rerata_nilai'], 1);
}
mysqli_stmt_close($stmt);

echo json_encode(["status" => "success", "data" => $data]);
mysqli_close($koneksi);
?>
