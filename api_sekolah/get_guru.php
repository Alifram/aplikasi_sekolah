<?php

header('Content-Type: application/json; charset=utf-8');

$host = 'localhost';
$user = 'root';
$password = '';
$database = 'db_mim_pasir_lor';

$conn = new mysqli($host, $user, $password, $database);

if ($conn->connect_error) {
    echo json_encode([
        'status' => 'error',
        'message' => 'Koneksi database gagal: ' . $conn->connect_error
    ]);
    exit;
}

$conn->set_charset('utf8mb4');

$sql = "
    SELECT
        id,
        nomor_induk,
        nama_lengkap,
        email,
        role,
        kelas_diajar,
        tahun_angkatan
    FROM users
    WHERE role = 'guru'
      AND (is_deleted = 0 OR is_deleted IS NULL)
    ORDER BY nama_lengkap ASC
";

$result = $conn->query($sql);

if (!$result) {
    echo json_encode([
        'status' => 'error',
        'message' => 'Gagal mengambil data guru: ' . $conn->error
    ]);
    exit;
}

$dataGuru = [];

while ($row = $result->fetch_assoc()) {
    $dataGuru[] = $row;
}

echo json_encode([
    'status' => 'success',
    'message' => 'Data guru berhasil diambil',
    'data' => $dataGuru
]);

$conn->close();