<?php
header("Content-Type: application/json");
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST");
header("Access-Control-Allow-Headers: Content-Type");

include 'koneksi.php';

$input = json_decode(file_get_contents('php://input'), true);

if (isset($input['user_id']) && isset($input['status_baru'])) {
    $userId = mysqli_real_escape_string($koneksi, $input['user_id']);
    
    // status_baru bernilai 1 untuk memblokir, bernilai 0 untuk mengaktifkan kembali
    $statusBaru = (int)$input['status_baru']; 

    $query = "UPDATE users SET is_deleted = '$statusBaru' WHERE id = '$userId'";

    if (mysqli_query($koneksi, $query)) {
        $pesanSukses = ($statusBaru == 1) 
            ? "Hak akses akun berhasil dinonaktifkan secara aman!" 
            : "Akun berhasil diaktifkan kembali! Orang tua kini bisa login dan mencetak rapor.";

        echo json_encode([
            "status" => "success",
            "message" => $pesanSukses
        ]);
    } else {
        echo json_encode([
            "status" => "error",
            "message" => "Gagal memperbarui status akun: " . mysqli_error($koneksi)
        ]);
    }
} else {
    echo json_encode(["status" => "error", "message" => "Parameter data tidak lengkap."]);
}
?>