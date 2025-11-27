<?php
require_once '../../config/db_connect.php';
header('Content-Type: application/json');

if (isset($_GET['member_id'])) {
    $stmt = $db->prepare("
        SELECT 
            COUNT(*) as contract_count,
            SUM(c.contract_credit) as total_credit,
            SUM(c.contract_LS) as total_ls
        FROM contract_history ch
        JOIN contracts c ON ch.contract_id = c.contract_id
        WHERE ch.member_id = ?
    ");
    $stmt->bind_param('i', $_GET['member_id']);
    $stmt->execute();
    echo json_encode($stmt->get_result()->fetch_assoc());
} else {
    echo json_encode(['error' => 'member_id is required']);
} 