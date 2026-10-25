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
$required = ['judul_acara', 'deskripsi', 'tanggal_acara', 'dibuat_oleh', 'semua_kelas', 'kelas_ids'];
if (!is_array($input)) {
    http_response_code(400);
    echo json_encode(["status" => "error", "message" => "Format JSON tidak valid."]);
    exit();
}
foreach ($required as $field) {
    if (!array_key_exists($field, $input)) {
        http_response_code(400);
        echo json_encode(["status" => "error", "message" => "Data event belum lengkap."]);
        exit();
    }
}

$title = is_string($input['judul_acara']) ? trim($input['judul_acara']) : '';
$description = is_string($input['deskripsi']) ? trim($input['deskripsi']) : '';
$createdBy = is_string($input['dibuat_oleh']) ? trim($input['dibuat_oleh']) : '';
$date = is_string($input['tanggal_acara']) ? $input['tanggal_acara'] : '';
$allClasses = filter_var($input['semua_kelas'], FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE);
$rawClassIds = $input['kelas_ids'];
$imageName = null;

if ($title === '' || $description === '' || $createdBy === '' ||
    !preg_match('/^\d{4}-\d{2}-\d{2}$/', $date) ||
    $allClasses === null || !is_array($rawClassIds)) {
    http_response_code(400);
    echo json_encode(["status" => "error", "message" => "Judul, deskripsi, tanggal, atau target kelas tidak valid."]);
    exit();
}

$classIds = [];
foreach ($rawClassIds as $rawId) {
    $classId = filter_var($rawId, FILTER_VALIDATE_INT);
    if ($classId === false || $classId <= 0) {
        http_response_code(400);
        echo json_encode(["status" => "error", "message" => "Daftar target kelas tidak valid."]);
        exit();
    }
    $classIds[$classId] = $classId;
}
if (!$allClasses && count($classIds) === 0) {
    http_response_code(400);
    echo json_encode(["status" => "error", "message" => "Pilih minimal satu kelas atau targetkan semua kelas."]);
    exit();
}

if (!empty($input['gambar_base64'])) {
    if (!is_string($input['gambar_base64'])) {
        http_response_code(400);
        echo json_encode(["status" => "error", "message" => "Format gambar tidak valid."]);
        exit();
    }
    $imageData = base64_decode($input['gambar_base64'], true);
    if ($imageData === false) {
        http_response_code(400);
        echo json_encode(["status" => "error", "message" => "Data gambar tidak valid."]);
        exit();
    }
    $uploadDirectory = __DIR__ . DIRECTORY_SEPARATOR . 'uploads';
    if (!is_dir($uploadDirectory) || !is_writable($uploadDirectory)) {
        http_response_code(500);
        echo json_encode(["status" => "error", "message" => "Folder unggahan gambar belum siap."]);
        exit();
    }
    $imageName = "img_" . bin2hex(random_bytes(12)) . ".jpg";
    if (file_put_contents($uploadDirectory . DIRECTORY_SEPARATOR . $imageName, $imageData) === false) {
        http_response_code(500);
        echo json_encode(["status" => "error", "message" => "Gagal menyimpan gambar event."]);
        exit();
    }
}

mysqli_begin_transaction($koneksi);
$insertEvent = mysqli_prepare(
    $koneksi,
    "INSERT INTO events
     (judul_acara, deskripsi, target_semua_kelas, gambar_url, tanggal_acara, dibuat_oleh)
     VALUES (?, ?, ?, ?, ?, ?)"
);
if ($insertEvent === false) {
    mysqli_rollback($koneksi);
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Gagal menyiapkan penyimpanan event."]);
    exit();
}
mysqli_stmt_bind_param($insertEvent, "ssisss", $title, $description, $allClasses, $imageName, $date, $createdBy);
if (!mysqli_stmt_execute($insertEvent)) {
    mysqli_stmt_close($insertEvent);
    mysqli_rollback($koneksi);
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Gagal menyimpan event."]);
    exit();
}
$eventId = (int)mysqli_insert_id($koneksi);
mysqli_stmt_close($insertEvent);

if (!$allClasses) {
    $checkClass = mysqli_prepare($koneksi, "SELECT id FROM kelas WHERE id = ? AND aktif = 1 LIMIT 1");
    $insertTarget = mysqli_prepare(
        $koneksi,
        "INSERT INTO event_kelas (event_id, kelas_id) VALUES (?, ?)"
    );
    if ($checkClass === false || $insertTarget === false) {
        if ($checkClass !== false) mysqli_stmt_close($checkClass);
        if ($insertTarget !== false) mysqli_stmt_close($insertTarget);
        mysqli_rollback($koneksi);
        http_response_code(500);
        echo json_encode(["status" => "error", "message" => "Gagal menyiapkan target kelas event."]);
        exit();
    }
    foreach ($classIds as $classId) {
        mysqli_stmt_bind_param($checkClass, "i", $classId);
        if (!mysqli_stmt_execute($checkClass) ||
            mysqli_num_rows(mysqli_stmt_get_result($checkClass)) !== 1) {
            mysqli_stmt_close($checkClass);
            mysqli_stmt_close($insertTarget);
            mysqli_rollback($koneksi);
            http_response_code(400);
            echo json_encode(["status" => "error", "message" => "Target kelas tidak ditemukan atau tidak aktif."]);
            exit();
        }
        mysqli_stmt_bind_param($insertTarget, "ii", $eventId, $classId);
        if (!mysqli_stmt_execute($insertTarget)) {
            mysqli_stmt_close($checkClass);
            mysqli_stmt_close($insertTarget);
            mysqli_rollback($koneksi);
            http_response_code(500);
            echo json_encode(["status" => "error", "message" => "Gagal menyimpan target kelas event."]);
            exit();
        }
    }
    mysqli_stmt_close($checkClass);
    mysqli_stmt_close($insertTarget);
}

if (!mysqli_commit($koneksi)) {
    mysqli_rollback($koneksi);
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Gagal menyelesaikan penyimpanan event."]);
    exit();
}
echo json_encode(["status" => "success", "message" => "Berita acara berhasil dipublikasikan."]);
mysqli_close($koneksi);
?>
