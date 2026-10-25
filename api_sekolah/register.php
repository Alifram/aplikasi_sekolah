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
$required = ['nomor_induk', 'nama_lengkap', 'email', 'password', 'role'];
if (!is_array($input)) {
    http_response_code(400);
    echo json_encode(["status" => "error", "message" => "Format JSON tidak valid."]);
    exit();
}
foreach ($required as $field) {
    if (!isset($input[$field]) || !is_string($input[$field]) || trim($input[$field]) === '') {
        http_response_code(400);
        echo json_encode(["status" => "error", "message" => "Data pendaftaran belum lengkap."]);
        exit();
    }
}

$studentNumber = trim($input['nomor_induk']);
$fullName = trim($input['nama_lengkap']);
$email = trim($input['email']);
$password = $input['password'];
$role = trim($input['role']);
$classId = null;
$admissionYear = null;
$jenisGuru = null;

if ($role === 'guru') {
    $jenisGuru = isset($input['jenis_guru'])
        ? trim((string)$input['jenis_guru'])
        : '';

    if (!in_array($jenisGuru, ['guru_kelas', 'guru_mapel'], true)) {
        http_response_code(400);
        echo json_encode([
            "status" => "error",
            "message" => "Jenis guru wajib dipilih dengan benar."
        ]);
        exit();
    }
}

if (!in_array($role, ['siswa', 'guru', 'admin'], true) ||
    strlen($password) < 6 ||
    !filter_var($email, FILTER_VALIDATE_EMAIL)) {
    http_response_code(400);
    echo json_encode(["status" => "error", "message" => "Role, email, atau password tidak valid."]);
    exit();
}

if (in_array($role, ['siswa', 'guru'], true)) {
    $classId = isset($input['kelas_id']) ? filter_var($input['kelas_id'], FILTER_VALIDATE_INT) : false;
    if ($classId === false || $classId <= 0) {
        http_response_code(400);
        echo json_encode(["status" => "error", "message" => "Kelas wajib dipilih dari daftar kelas aktif."]);
        exit();
    }
}
if ($role === 'siswa') {
    $admissionYear = isset($input['tahun_angkatan'])
        ? filter_var($input['tahun_angkatan'], FILTER_VALIDATE_INT)
        : false;
    if ($admissionYear === false || $admissionYear < 2000 || $admissionYear > ((int)date('Y') + 5)) {
        http_response_code(400);
        echo json_encode(["status" => "error", "message" => "Tahun angkatan siswa tidak valid."]);
        exit();
    }
}

if ($classId !== null) {
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
    $classExists = mysqli_num_rows(mysqli_stmt_get_result($classStmt)) === 1;
    mysqli_stmt_close($classStmt);
    if (!$classExists) {
        http_response_code(400);
        echo json_encode(["status" => "error", "message" => "Kelas tidak ditemukan atau tidak aktif."]);
        exit();
    }
}

$duplicate = mysqli_prepare(
    $koneksi,
    "SELECT id FROM users WHERE nomor_induk = ? OR email = ? LIMIT 1"
);
if ($duplicate === false) {
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Gagal memeriksa data akun."]);
    exit();
}
mysqli_stmt_bind_param($duplicate, "ss", $studentNumber, $email);
if (!mysqli_stmt_execute($duplicate)) {
    mysqli_stmt_close($duplicate);
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Gagal memeriksa data akun."]);
    exit();
}
$alreadyExists = mysqli_num_rows(mysqli_stmt_get_result($duplicate)) > 0;
mysqli_stmt_close($duplicate);
if ($alreadyExists) {
    http_response_code(409);
    echo json_encode(["status" => "error", "message" => "Nomor induk atau email sudah terdaftar."]);
    exit();
}

$passwordHash = password_hash($password, PASSWORD_DEFAULT);
$insert = mysqli_prepare(
    $koneksi,
    "INSERT INTO users
     (
         nomor_induk,
         nama_lengkap,
         email,
         password,
         role,
         jenis_guru,
         kelas_id,
         tahun_angkatan,
         is_deleted
     )
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0)"
);
if ($insert === false) {
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Gagal menyiapkan pendaftaran akun."]);
    exit();
}
mysqli_stmt_bind_param(
    $insert,
    "ssssssii",
    $studentNumber,
    $fullName,
    $email,
    $passwordHash,
    $role,
    $jenisGuru,
    $classId,
    $admissionYear
);
if (!mysqli_stmt_execute($insert)) {
    mysqli_stmt_close($insert);
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Gagal menyimpan akun."]);
    exit();
}
mysqli_stmt_close($insert);

echo json_encode(["status" => "success", "message" => "Akun baru berhasil didaftarkan."]);
mysqli_close($koneksi);
?>
