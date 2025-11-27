<?php
require_once '../../config/db_connect.php';

if (isset($_GET['type'])) {
    $stmt = $db->prepare('
        SELECT contract_id, contract_name 
        FROM contracts 
        WHERE contract_type = ?
        ORDER BY contract_name
    ');
    $stmt->bind_param('s', $_GET['type']);
    $stmt->execute();
    $result = $stmt->get_result();
    
    $contracts = [];
    while ($row = $result->fetch_assoc()) {
        $contracts[] = [
            'id' => $row['contract_id'],
            'contract_name' => $row['contract_name']
        ];
    }
    
    header('Content-Type: application/json');
    echo json_encode($contracts);
} 