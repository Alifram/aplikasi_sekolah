<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");

if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') exit(0);
include "koneksi.php";

$event_id = isset($_GET['event_id']) ? mysqli_real_escape_string($koneksi, $_GET['event_id']) : '';

if (!empty($event_id)) {
    $query = "SELECT * FROM event_comments WHERE event_id = '$event_id' ORDER BY created_at ASC";
    $result = mysqli_query($koneksi, $query);
    $comments = [];
    
    while ($row = mysqli_fetch_assoc($result)) {
        $comments[] = $row;
    }
    echo json_encode(["status" => "success", "data" => $comments]);
} else {
    echo json_encode(["status" => "error", "message" => "Parameter ID kosong."]);
}
?>