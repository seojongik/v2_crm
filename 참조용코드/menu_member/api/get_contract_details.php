<?php
require_once '../../config/db_connect.php';

if (isset($_GET['contract_id'])) {
    $stmt = $db->prepare('SELECT * FROM contracts WHERE contract_id = ?');
    $stmt->bind_param('i', $_GET['contract_id']);
    $stmt->execute();
    $result = $stmt->get_result();
    $contract = $result->fetch_assoc();

    header('Content-Type: application/json');
    echo json_encode($contract);
} 