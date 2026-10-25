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
$adminId = is_array($input) && isset($input['user_id'])
    ? filter_var($input['user_id'], FILTER_VALIDATE_INT)
    : false;
if ($adminId === false || $adminId <= 0) {
    http_response_code(401);
    echo json_encode(["status" => "error", "message" => "Akun admin tidak valid."]);
    exit();
}

$admin = mysqli_prepare(
    $koneksi,
    "SELECT id FROM users WHERE id = ? AND role = 'admin' AND is_deleted = 0 LIMIT 1"
);
if ($admin === false) {
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Gagal memeriksa akun admin."]);
    exit();
}
mysqli_stmt_bind_param($admin, "i", $adminId);
if (!mysqli_stmt_execute($admin)) {
    mysqli_stmt_close($admin);
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Gagal memeriksa akun admin."]);
    exit();
}
$isAdmin = mysqli_num_rows(mysqli_stmt_get_result($admin)) === 1;
mysqli_stmt_close($admin);
if (!$isAdmin) {
    http_response_code(403);
    echo json_encode(["status" => "error", "message" => "Hanya admin yang dapat menaikkan kelas."]);
    exit();
}

// Alumni is the destination for graduating students; create/reactivate it as needed.
$alumniQuery = mysqli_prepare(
    $koneksi,
    "SELECT id, aktif FROM kelas WHERE LOWER(TRIM(nama)) = 'alumni' LIMIT 1"
);
if ($alumniQuery === false || !mysqli_stmt_execute($alumniQuery)) {
    if ($alumniQuery !== false) mysqli_stmt_close($alumniQuery);
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Gagal memeriksa kelas Alumni."]);
    exit();
}
$alumni = mysqli_fetch_assoc(mysqli_stmt_get_result($alumniQuery));
mysqli_stmt_close($alumniQuery);

if ($alumni === null) {
    $createAlumni = mysqli_prepare(
        $koneksi,
        "INSERT INTO kelas (nama, aktif) VALUES ('Alumni', 1)"
    );
    if ($createAlumni === false || !mysqli_stmt_execute($createAlumni)) {
        if ($createAlumni !== false) mysqli_stmt_close($createAlumni);
        http_response_code(500);
        echo json_encode(["status" => "error", "message" => "Gagal menyiapkan kelas Alumni."]);
        exit();
    }
    mysqli_stmt_close($createAlumni);
} elseif ((int)$alumni['aktif'] !== 1) {
    $activateAlumni = mysqli_prepare(
        $koneksi,
        "UPDATE kelas SET aktif = 1 WHERE id = ?"
    );
    if ($activateAlumni === false) {
        http_response_code(500);
        echo json_encode(["status" => "error", "message" => "Gagal mengaktifkan kelas Alumni."]);
        exit();
    }
    $alumniId = (int)$alumni['id'];
    mysqli_stmt_bind_param($activateAlumni, "i", $alumniId);
    if (!mysqli_stmt_execute($activateAlumni)) {
        mysqli_stmt_close($activateAlumni);
        http_response_code(500);
        echo json_encode(["status" => "error", "message" => "Gagal mengaktifkan kelas Alumni."]);
        exit();
    }
    mysqli_stmt_close($activateAlumni);
}

$classesResult = mysqli_query(
    $koneksi,
    "SELECT id, nama FROM kelas WHERE aktif = 1"
);
if ($classesResult === false) {
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Gagal mengambil daftar kelas."]);
    exit();
}
$normalizeClassName = static function (string $name): string {
    return strtolower((string)preg_replace('/[^a-z0-9]/i', '', trim($name)));
};
$classIds = [];
while ($class = mysqli_fetch_assoc($classesResult)) {
    $normalizedName = $normalizeClassName($class['nama']);
    if ($normalizedName === 'alumni') {
        $classIds['Alumni'] = (int)$class['id'];
        continue;
    }

    $number = null;
    if (preg_match('/^(?:kelas)?([1-6])$/i', $normalizedName, $matches)) {
        $number = (int)$matches[1];
    }
    if ($number !== null) {
        $classIds["Kelas $number"] = (int)$class['id'];
    }
}

$missingClasses = [];
foreach (['Kelas 1', 'Kelas 2', 'Kelas 3', 'Kelas 4', 'Kelas 5', 'Kelas 6', 'Alumni'] as $name) {
    if (!isset($classIds[$name])) $missingClasses[] = $name;
}
if ($missingClasses !== []) {
    http_response_code(400);
    echo json_encode([
        "status" => "error",
        "message" => "Kelas aktif berikut belum tersedia: " . implode(', ', $missingClasses) . ". Periksa daftar kelas sebelum mencoba lagi."
    ]);
    exit();
}

mysqli_begin_transaction($koneksi);
$update = mysqli_prepare(
    $koneksi,
    "UPDATE users SET kelas_id = ? WHERE role = 'siswa' AND kelas_id = ? AND is_deleted = 0"
);
if ($update === false) {
    mysqli_rollback($koneksi);
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Gagal menyiapkan kenaikan kelas."]);
    exit();
}
$changes = [
    ['Kelas 6', 'Alumni'],
    ['Kelas 5', 'Kelas 6'],
    ['Kelas 4', 'Kelas 5'],
    ['Kelas 3', 'Kelas 4'],
    ['Kelas 2', 'Kelas 3'],
    ['Kelas 1', 'Kelas 2']
];
foreach ($changes as [$from, $to]) {
    $targetId = $classIds[$to];
    $sourceId = $classIds[$from];
    mysqli_stmt_bind_param($update, "ii", $targetId, $sourceId);
    if (!mysqli_stmt_execute($update)) {
        mysqli_stmt_close($update);
        mysqli_rollback($koneksi);
        http_response_code(500);
        echo json_encode(["status" => "error", "message" => "Gagal menaikkan siswa dari $from ke $to."]);
        exit();
    }
}
mysqli_stmt_close($update);
if (!mysqli_commit($koneksi)) {
    mysqli_rollback($koneksi);
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Gagal menyelesaikan kenaikan kelas."]);
    exit();
}

echo json_encode(["status" => "success", "message" => "Kenaikan kelas massal berhasil."]);
mysqli_close($koneksi);
?>
