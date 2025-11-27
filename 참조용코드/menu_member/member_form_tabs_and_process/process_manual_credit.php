<?php
require_once '../../config/db_connect.php';

header('Content-Type: application/json');

try {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        throw new Exception('Invalid request method');
    }

    $member_id = $_POST['member_id'] ?? null;
    $amount = $_POST['amount'] ?? null;
    $type = $_POST['type'] ?? null;
    $text = $_POST['text'] ?? null;

    if (!$member_id || !$amount || !$type || !$text) {
        throw new Exception('Missing required parameters');
    }

    // 현재 잔액 조회
    $stmt = $db->prepare('SELECT bill_balance_after FROM bills WHERE member_id = ? ORDER BY bill_id DESC LIMIT 1');
    $stmt->bind_param('i', $member_id);
    $stmt->execute();
    $result = $stmt->get_result();
    $current_balance = $result->fetch_assoc()['bill_balance_after'] ?? 0;

    // 새로운 잔액 계산
    $new_balance = $current_balance + $amount;

    // bills 테이블에 기록
    $stmt = $db->prepare('
        INSERT INTO bills (
            member_id,
            bill_type,
            bill_date,
            bill_text,
            bill_totalamt,
            bill_deduction,
            bill_netamt,
            bill_balance_before,
            bill_balance_after
        ) VALUES (?, ?, NOW(), ?, ?, 0, ?, ?, ?)
    ');

    $abs_amount = abs($amount);
    $stmt->bind_param('issdddd', 
        $member_id,
        $type,
        $text,
        $abs_amount,
        $amount,
        $current_balance,
        $new_balance
    );

    if (!$stmt->execute()) {
        throw new Exception('Failed to process credit adjustment');
    }

    echo json_encode([
        'success' => true,
        'message' => '처리가 완료되었습니다.',
        'new_balance' => $new_balance
    ]);

} catch (Exception $e) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
} 