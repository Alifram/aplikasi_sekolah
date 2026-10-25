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
$required = ['id_user', 'nama_lengkap', 'email', 'kelas_id'];
if (!is_array($input)) {
    http_response_code(400);
    echo json_encode(["status" => "error", "message" => "Format JSON tidak valid."]);
    exit();
}
foreach ($required as $field) {
    if (!array_key_exists($field, $input)) {
        http_response_code(400);
        echo json_encode(["status" => "error", "message" => "Data pembaruan akun belum lengkap."]);
        exit();
    }
}

$userId = filter_var($input['id_user'], FILTER_VALIDATE_INT);
$classId = $input['kelas_id'] === null || $input['kelas_id'] === ''
    ? null
    : filter_var($input['kelas_id'], FILTER_VALIDATE_INT);
$name = is_string($input['nama_lengkap']) ? trim($input['nama_lengkap']) : '';
$email = is_string($input['email']) ? trim($input['email']) : '';
$newPassword = isset($input['password_baru']) && is_string($input['password_baru'])
    ? trim($input['password_baru'])
    : '';

if ($userId === false || $userId <= 0 ||
    $name === '' ||
    !filter_var($email, FILTER_VALIDATE_EMAIL) ||
    ($classId !== null && ($classId === false || $classId <= 0))) {
    http_response_code(400);
    echo json_encode(["status" => "error", "message" => "Data akun atau kelas tidak valid."]);
    exit();
}
if ($newPassword !== '' && strlen($newPassword) < 6) {
    http_response_code(400);
    echo json_encode(["status" => "error", "message" => "Password baru minimal 6 karakter."]);
    exit();
}

$userStmt = mysqli_prepare($koneksi, "SELECT role FROM users WHERE id = ? AND is_deleted = 0 LIMIT 1");
if ($userStmt === false) {
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Gagal menyiapkan pemeriksaan akun."]);
    exit();
}
mysqli_stmt_bind_param($userStmt, "i", $userId);
if (!mysqli_stmt_execute($userStmt)) {
    mysqli_stmt_close($userStmt);
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Gagal memeriksa akun."]);
    exit();
}
$user = mysqli_fetch_assoc(mysqli_stmt_get_result($userStmt));
mysqli_stmt_close($userStmt);
if ($user === null) {
    http_response_code(404);
    echo json_encode(["status" => "error", "message" => "Akun tidak ditemukan."]);
    exit();
}

if (in_array($user['role'], ['guru', 'siswa'], true)) {
    if ($classId === null) {
        http_response_code(400);
        echo json_encode(["status" => "error", "message" => "Kelas wajib dipilih untuk akun guru atau siswa."]);
        exit();
    }
    $classStmt = mysqli_prepare($koneksi, "SELECT id FROM kelas WHERE id = ? AND aktif = 1 LIMIT 1");
    if ($classStmt === false) {
        http_response_code(500);
        echo json_encode(["status" => "error", "message" => "Gagal menyiapkan validasi kelas."]);
        exit();
    }
    mysqli_stmt_bind_param($classStmt, "i", $classId);
    if (!mysqli_stmt_execute($classStmt)) {
        mysqli_stmt_close($classStmt);
        http_response_code(500);
        echo json_encode(["status" => "error", "message" => "Gagal memvalidasi kelas."]);
        exit();
    }
    $validClass = mysqli_num_rows(mysqli_stmt_get_result($classStmt)) === 1;
    mysqli_stmt_close($classStmt);
    if (!$validClass) {
        http_response_code(400);
        echo json_encode(["status" => "error", "message" => "Kelas tidak ditemukan atau tidak aktif."]);
        exit();
    }
}

$sql = $newPassword === ''
    ? "UPDATE users SET nama_lengkap = ?, email = ?, kelas_id = ? WHERE id = ?"
    : "UPDATE users SET nama_lengkap = ?, email = ?, kelas_id = ?, password = ? WHERE id = ?";
$stmt = mysqli_prepare($koneksi, $sql);
if ($stmt === false) {
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Gagal menyiapkan pembaruan akun."]);
    exit();
}
if ($newPassword === '') {
    mysqli_stmt_bind_param($stmt, "ssii", $name, $email, $classId, $userId);
} else {
    $passwordHash = password_hash($newPassword, PASSWORD_DEFAULT);
    mysqli_stmt_bind_param($stmt, "ssisi", $name, $email, $classId, $passwordHash, $userId);
}
if (!mysqli_stmt_execute($stmt)) {
    $errno = mysqli_stmt_errno($stmt);
    mysqli_stmt_close($stmt);
    http_response_code($errno === 1062 ? 409 : 500);
    echo json_encode([
        "status" => "error",
        "message" => $errno === 1062
            ? "Email tersebut sudah digunakan akun lain."
            : "Gagal menyimpan pembaruan akun."
    ]);
    exit();
}
mysqli_stmt_close($stmt);

echo json_encode(["status" => "success", "message" => "Data akun berhasil diperbarui."]);
mysqli_close($koneksi);
?>
