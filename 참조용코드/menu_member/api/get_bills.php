<?php
date_default_timezone_set('Asia/Seoul');
require_once '../../config/db_connect.php';
header('Content-Type: application/json');

// 디버깅을 위한 로그 파일 생성
$log_file = 'bills_debug.log';
$timestamp = date('Y-m-d H:i:s');
file_put_contents($log_file, "$timestamp - 요청 시작\n", FILE_APPEND);

// 모든 GET 파라미터 로깅
file_put_contents($log_file, "$timestamp - 모든 GET 파라미터: " . json_encode($_GET) . "\n", FILE_APPEND);

// 요청 파라미터 검증
if (isset($_GET['member_id']) && isset($_GET['start_date']) && isset($_GET['end_date'])) {
    $member_id = $_GET['member_id'];
    $start_date = $_GET['start_date'];
    $end_date = $_GET['end_date'];
    
    // 미래 날짜 체크 및 조정
    $current_date = date('Y-m-d');
    $original_end_date = $end_date;
    $date_adjusted = false;
    
    if ($end_date > $current_date) {
        $end_date = $current_date;
        $date_adjusted = true;
    }

    // 데이터 조회
    $stmt = $db->prepare("
        SELECT 
            bill_id,
            bill_date,
            bill_type,
            bill_text,
            bill_totalamt,
            bill_deduction,
            bill_netamt,
            bill_balance_after,
            bill_status
        FROM bills 
        WHERE member_id = ? 
        AND DATE(bill_date) BETWEEN ? AND ?
        ORDER BY bill_date DESC, bill_id DESC
    ");
    
    $stmt->bind_param('iss', $member_id, $start_date, $end_date);
    $stmt->execute();
    $result = $stmt->get_result();
    
    $bills = [];
    while ($row = $result->fetch_assoc()) {
        $row['bill_date'] = date('Y-m-d', strtotime($row['bill_date']));
        $row['bill_totalamt'] = (int)$row['bill_totalamt'];
        $row['bill_deduction'] = (int)$row['bill_deduction'];
        $row['bill_netamt'] = (int)$row['bill_netamt'];
        $row['bill_balance_after'] = (int)$row['bill_balance_after'];
        $bills[] = $row;
    }
    
    // 메타 정보 추가
    $response = [
        'success' => true,
        'bills' => $bills,
        'meta' => [
            'count' => count($bills),
            'period' => [
                'start' => $start_date,
                'end' => $end_date,
                'original_end' => $original_end_date,
                'date_adjusted' => $date_adjusted
            ],
            'server_time' => date('Y-m-d H:i:s')
        ]
    ];
    
    echo json_encode($response);
} else {
    echo json_encode([
        'success' => false,
        'error' => 'Required parameters are missing'
    ]);
}

file_put_contents($log_file, "$timestamp - 요청 종료\n\n", FILE_APPEND); 