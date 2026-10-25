<?php
function jadwal_require_admin($koneksi, $userId)
{
    $userId = filter_var($userId, FILTER_VALIDATE_INT);
    if ($userId === false || $userId <= 0) {
        http_response_code(401);
        echo json_encode(["status" => "error", "message" => "Akun admin tidak valid."]);
        return false;
    }

    $stmt = mysqli_prepare(
        $koneksi,
        "SELECT id FROM users WHERE id = ? AND role = 'admin' AND is_deleted = 0 LIMIT 1"
    );
    if ($stmt === false) {
        http_response_code(500);
        echo json_encode(["status" => "error", "message" => "Gagal memeriksa hak akses admin."]);
        return false;
    }

    mysqli_stmt_bind_param($stmt, "i", $userId);
    if (!mysqli_stmt_execute($stmt)) {
        mysqli_stmt_close($stmt);
        http_response_code(500);
        echo json_encode(["status" => "error", "message" => "Gagal memeriksa hak akses admin."]);
        return false;
    }
    $result = mysqli_stmt_get_result($stmt);
    $isAdmin = mysqli_num_rows($result) === 1;
    mysqli_stmt_close($stmt);
    if (!$isAdmin) {
        http_response_code(403);
        echo json_encode(["status" => "error", "message" => "Hanya admin yang dapat mengelola jadwal."]);
        return false;
    }
    return true;
}
