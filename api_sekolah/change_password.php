<?php
header("Content-Type: application/json");
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST");
header("Access-Control-Allow-Headers: Content-Type");

include 'koneksi.php';
include 'password_utils.php';

$input = json_decode(file_get_contents('php://input'), true);

if (is_array($input) &&
    isset($input['id_user'], $input['password_lama'], $input['password_baru'])) {
    if (!is_scalar($input['id_user']) ||
        !is_scalar($input['password_lama']) ||
        !is_scalar($input['password_baru']) ||
        !filter_var($input['id_user'], FILTER_VALIDATE_INT) ||
        strlen($input['password_lama']) === 0 ||
        strlen($input['password_baru']) < 6) {
        echo json_encode(["status" => "error", "message" => "ID akun tidak valid atau password baru kurang dari 6 karakter."]);
        exit();
    }
    $id_user = mysqli_real_escape_string($koneksi, (string)$input['id_user']);

    // 1. CEK VALIDITAS: Pastikan password lama cocok dengan yang tersimpan di MySQL
    $queryCek = "SELECT password FROM users WHERE id = '$id_user' AND is_deleted = 0";
    $hasilCek = mysqli_query($koneksi, $queryCek);

    if ($hasilCek && mysqli_num_rows($hasilCek) > 0) {
        $row = mysqli_fetch_assoc($hasilCek);
        
        if (!verify_school_password($input['password_lama'], (string)$row['password'])) {
            echo json_encode([
                "status"  => "error",
                "message" => "Gagal! Password saat ini yang Anda masukkan salah."
            ]);
            exit();
        }

        // 2. EKSEKUSI UPDATE: Ganti dengan password baru pilihan admin
        $password_baru = mysqli_real_escape_string(
            $koneksi,
            password_hash($input['password_baru'], PASSWORD_DEFAULT)
        );
        $queryUpdate = "UPDATE users SET password = '$password_baru' WHERE id = '$id_user'";
        if (mysqli_query($koneksi, $queryUpdate)) {
            echo json_encode([
                "status"  => "success",
                "message" => "Selamat! Password akun resmi berhasil diperbarui secara permanen."
            ]);
        } else {
            echo json_encode([
                "status"  => "error",
                "message" => "Gagal menyimpan ke database: " . mysqli_error($koneksi)
            ]);
        }
    } else {
        echo json_encode([
            "status"  => "error",
            "message" => "Akun tidak ditemukan di dalam sistem."
        ]);
    }
} else {
    echo json_encode([
        "status"  => "error",
        "message" => "Parameter input perubahan sandi tidak lengkap."
    ]);
}

mysqli_close($koneksi);
?>