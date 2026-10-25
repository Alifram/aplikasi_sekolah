<?php
function presensi_send_json($status, $message, $httpCode = 200, $data = null)
{
    http_response_code($httpCode);
    $response = ["status" => $status, "message" => $message];
    if ($data !== null) {
        $response["data"] = $data;
    }
    echo json_encode($response);
}

function presensi_get_actor($koneksi, $userId)
{
    $userId = filter_var($userId, FILTER_VALIDATE_INT);
    if ($userId === false || $userId <= 0) {
        return null;
    }

    $stmt = mysqli_prepare(
        $koneksi,
        "SELECT id, role, kelas_id
         FROM users
         WHERE id = ? AND is_deleted = 0
         LIMIT 1"
    );
    if ($stmt === false) {
        return false;
    }

    mysqli_stmt_bind_param($stmt, "i", $userId);
    if (!mysqli_stmt_execute($stmt)) {
        mysqli_stmt_close($stmt);
        return false;
    }
    $result = mysqli_stmt_get_result($stmt);
    $actor = mysqli_fetch_assoc($result);
    mysqli_stmt_close($stmt);
    return $actor ?: null;
}

function presensi_valid_date($value)
{
    if (!is_string($value)) {
        return false;
    }
    $date = DateTime::createFromFormat('!Y-m-d', $value);
    return $date !== false && $date->format('Y-m-d') === $value;
}

function presensi_valid_class_id($value)
{
    return filter_var($value, FILTER_VALIDATE_INT) !== false &&
        (int)$value > 0;
}
