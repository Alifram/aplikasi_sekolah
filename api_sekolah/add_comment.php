<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");

if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') exit(0);
include "koneksi.php";

$input = json_decode(file_get_contents('php://input'), true);

if (isset($input['event_id']) && isset($input['user_id']) && isset($input['nama_pengirim']) && isset($input['role_pengirim']) && isset($input['isi_komentar'])) {
    
    $event_id = mysqli_real_escape_string($koneksi, $input['event_id']);
    $user_id  = mysqli_real_escape_string($koneksi, $input['user_id']);
    $nama     = mysqli_real_escape_string($koneksi, $input['nama_pengirim']);
    $role     = mysqli_real_escape_string($koneksi, $input['role_pengirim']);
    $isi      = mysqli_real_escape_string($koneksi, $input['isi_komentar']);

    $query = "INSERT INTO event_comments (event_id, user_id, nama_pengirim, role_pengirim, isi_komentar) 
              VALUES ('$event_id', '$user_id', '$nama', '$role', '$isi')";
              
    if (mysqli_query($koneksi, $query)) {
        echo json_encode(["status" => "success", "message" => "Komentar terkirim."]);
    } else {
        echo json_encode(["status" => "error", "message" => "Gagal mengirim komentar."]);
    }
} else {
    echo json_encode(["status" => "error", "message" => "Data komentar tidak lengkap."]);
}
?>