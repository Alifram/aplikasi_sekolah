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
if (!is_array($input)) {
    http_response_code(400);
    echo json_encode(["status" => "error", "message" => "Format JSON tidak valid."]);
    exit();
}

$eventId = filter_var($input['event_id'] ?? null, FILTER_VALIDATE_INT);
$role = is_string($input['role_user'] ?? null) ? trim($input['role_user']) : '';
$name = is_string($input['nama_user'] ?? null) ? trim($input['nama_user']) : '';
if ($eventId === false || $eventId <= 0 || $role === '' || $name === '') {
    http_response_code(400);
    echo json_encode(["status" => "error", "message" => "Identitas event atau pengguna tidak valid."]);
    exit();
}

mysqli_begin_transaction($koneksi);
$findEvent = mysqli_prepare(
    $koneksi,
    "SELECT dibuat_oleh, gambar_url FROM events WHERE id = ? FOR UPDATE"
);
if ($findEvent === false) {
    mysqli_rollback($koneksi);
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Gagal menyiapkan penghapusan event."]);
    exit();
}
mysqli_stmt_bind_param($findEvent, "i", $eventId);
if (!mysqli_stmt_execute($findEvent)) {
    mysqli_stmt_close($findEvent);
    mysqli_rollback($koneksi);
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Gagal mencari event yang akan dihapus."]);
    exit();
}
$eventResult = mysqli_stmt_get_result($findEvent);
$event = mysqli_fetch_assoc($eventResult);
mysqli_stmt_close($findEvent);

if ($event === null) {
    mysqli_rollback($koneksi);
    http_response_code(404);
    echo json_encode(["status" => "error", "message" => "Postingan tidak ditemukan."]);
    exit();
}

if ($role !== 'admin' && $event['dibuat_oleh'] !== $name) {
    mysqli_rollback($koneksi);
    http_response_code(403);
    echo json_encode([
        "status" => "error",
        "message" => "Anda tidak diperbolehkan menghapus postingan milik orang lain."
    ]);
    exit();
}

foreach (["event_comments", "event_kelas"] as $childTable) {
    $deleteChildren = mysqli_prepare(
        $koneksi,
        "DELETE FROM `$childTable` WHERE event_id = ?"
    );
    if ($deleteChildren === false) {
        mysqli_rollback($koneksi);
        http_response_code(500);
        echo json_encode(["status" => "error", "message" => "Gagal menyiapkan penghapusan data terkait event."]);
        exit();
    }
    mysqli_stmt_bind_param($deleteChildren, "i", $eventId);
    if (!mysqli_stmt_execute($deleteChildren)) {
        mysqli_stmt_close($deleteChildren);
        mysqli_rollback($koneksi);
        http_response_code(500);
        echo json_encode(["status" => "error", "message" => "Gagal menghapus data terkait event."]);
        exit();
    }
    mysqli_stmt_close($deleteChildren);
}

$deleteEvent = mysqli_prepare($koneksi, "DELETE FROM events WHERE id = ?");
if ($deleteEvent === false) {
    mysqli_rollback($koneksi);
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Gagal menyiapkan penghapusan event."]);
    exit();
}
mysqli_stmt_bind_param($deleteEvent, "i", $eventId);
if (!mysqli_stmt_execute($deleteEvent) || mysqli_stmt_affected_rows($deleteEvent) !== 1) {
    mysqli_stmt_close($deleteEvent);
    mysqli_rollback($koneksi);
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Gagal menghapus event dari database."]);
    exit();
}
mysqli_stmt_close($deleteEvent);

if (!mysqli_commit($koneksi)) {
    mysqli_rollback($koneksi);
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Gagal menyelesaikan penghapusan event."]);
    exit();
}

$imageName = basename((string)($event['gambar_url'] ?? ''));
if ($imageName !== '' && $imageName === $event['gambar_url']) {
    $imagePath = __DIR__ . DIRECTORY_SEPARATOR . 'uploads' . DIRECTORY_SEPARATOR . $imageName;
    if (is_file($imagePath) && !unlink($imagePath)) {
        error_log("Event {$eventId} was deleted, but its image could not be removed.");
    }
}

echo json_encode(["status" => "success", "message" => "Postingan berita kegiatan berhasil dihapus."]);
mysqli_close($koneksi);
?>
