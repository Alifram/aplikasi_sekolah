<?php
include "koneksi.php";
include "password_utils.php";

// Menangkap data JSON yang dikirimkan oleh Flutter
$input = json_decode(file_get_contents('php://input'), true);

if (is_array($input) &&
    isset($input['identifier'], $input['password']) &&
    is_string($input['identifier']) && is_string($input['password'])) {
    $identifier = mysqli_real_escape_string($koneksi, trim($input['identifier']));
    $password = $input['password'];

    $query = "SELECT u.id, u.nomor_induk, u.nama_lengkap, u.email, u.role,
                     u.kelas_id, k.nama AS kelas_nama, k.nama AS kelas_diajar,
                     u.tahun_angkatan, u.password
              FROM users u
              LEFT JOIN kelas k ON k.id = u.kelas_id
              WHERE (u.email = '$identifier' OR u.nomor_induk = '$identifier')
                AND u.is_deleted = 0";
              
    $result = mysqli_query($koneksi, $query);

    if ($result === false) {
        http_response_code(500);
        echo json_encode(["status" => "error", "message" => "Gagal memeriksa akun pada database."]);
        exit();
    }

    if (mysqli_num_rows($result) > 0) {
        $user_data = mysqli_fetch_assoc($result);
        if (verify_school_password($password, (string)$user_data['password'])) {
            $isLegacyHashRequest = preg_match('/^[a-f0-9]{32}$/i', $password) === 1
                && hash_equals((string)$user_data['password'], $password);
            if (!$isLegacyHashRequest &&
                !password_get_info((string)$user_data['password'])['algo']) {
                $newHash = password_hash($password, PASSWORD_DEFAULT);
                $userId = (int)$user_data['id'];
                $stmt = mysqli_prepare($koneksi, "UPDATE users SET password = ? WHERE id = ?");
                if ($stmt === false) {
                    http_response_code(500);
                    echo json_encode(["status" => "error", "message" => "Gagal mengamankan password akun."]);
                    exit();
                }
                mysqli_stmt_bind_param($stmt, "si", $newHash, $userId);
                if (!mysqli_stmt_execute($stmt)) {
                    mysqli_stmt_close($stmt);
                    http_response_code(500);
                    echo json_encode(["status" => "error", "message" => "Gagal mengamankan password akun."]);
                    exit();
                }
                mysqli_stmt_close($stmt);
            }

            unset($user_data['password']);
            echo json_encode([
                "status"  => "success",
                "message" => "Login Berhasil",
                "user"    => $user_data
            ]);
        } else {
            echo json_encode([
                "status"  => "error",
                "message" => "Nomor Induk/Email atau Password Anda salah."
            ]);
        }
    } else {
        echo json_encode([
            "status"  => "error",
            "message" => "Nomor Induk/Email atau Password Anda salah."
        ]);
    }
} else {
    echo json_encode([
        "status"  => "error",
        "message" => "Data input tidak lengkap."
    ]);
}
?>
