<?php
// 에러 보고 설정
ini_set('display_errors', 1);
error_reporting(E_ALL);

// PHP 타임존 설정
date_default_timezone_set('Asia/Seoul');

header('Content-Type: application/json; charset=utf-8');

// DB 연결
require_once dirname(__FILE__) . '/../../config/db_connect.php';

// 응답 함수
function respond($status, $message = '', $data = []) {
    $response = [
        'status' => $status,
        'message' => $message,
        'data' => $data
    ];
    
    if ($status === 'error') {
        $response['error'] = true;
    }
    
    echo json_encode($response, JSON_UNESCAPED_UNICODE);
    exit;
}

// 회원 ID 필수 체크
if (!isset($_GET['member_id']) || empty($_GET['member_id'])) {
    respond('error', '회원 ID가 필요합니다.');
}

$member_id = intval($_GET['member_id']);

try {
    // 레슨 내역 조회 쿼리 - LS_countings 테이블만 사용하도록 수정
    $query = "
        SELECT 
            c.LS_id,
            c.LS_counting_source,
            c.LS_balance_before,
            c.LS_net_qty,
            c.LS_balance_after,
            c.updated_at,
            o.LS_date as lesson_date,
            TIME_FORMAT(o.LS_start_time, '%H:%i') as start_time,
            TIME_FORMAT(o.LS_end_time, '%H:%i') as end_time,
            o.LS_duration as duration,
            o.LS_category as category,
            o.LS_order_type as status,
            s.staff_name
        FROM LS_countings c
        LEFT JOIN LS_orders o ON c.LS_id = o.LS_id
        LEFT JOIN Staff s ON o.staff_nickname = s.staff_nickname
        WHERE c.member_id = ? 
        ORDER BY c.LS_id DESC
    ";
    
    $stmt = $db->prepare($query);
    $stmt->bind_param('i', $member_id);
    $stmt->execute();
    
    $result = $stmt->get_result();
    $lesson_history = [];
    
    while ($row = $result->fetch_assoc()) {
        // LS_id에서 날짜 정보 추출 (첫 6자리가 yymmdd 형식)
        $ls_id = $row['LS_id'];
        $date_from_id = '';
        
        if (preg_match('/^(\d{6})/', $ls_id, $matches)) {
            $yymmdd = $matches[1];
            $year = '20' . substr($yymmdd, 0, 2); // 20 붙여서 4자리 연도로
            $month = substr($yymmdd, 2, 2);
            $day = substr($yymmdd, 4, 2);
            $date_from_id = "$year-$month-$day";
        }
        
        // 날짜와 시간 형식 처리
        $lesson_date = $date_from_id ?: ($row['lesson_date'] ?: '');
        $start_time = $row['start_time'] ?: '';
        $end_time = $row['end_time'] ?: '';
        
        $lesson_history[] = [
            'lesson_id' => $row['LS_id'],
            'source' => $row['LS_counting_source'],
            'balance_before' => $row['LS_balance_before'],
            'net_qty' => $row['LS_net_qty'],
            'balance_after' => $row['LS_balance_after'],
            'staff_name' => $row['staff_name'],
            'lesson_date' => $lesson_date,
            'start_time' => $start_time,
            'end_time' => $end_time,
            'duration' => $row['duration'],
            'category' => $row['category'],
            'status' => $row['status'],
            'updated_at' => $row['updated_at']
        ];
    }
    
    echo json_encode($lesson_history, JSON_UNESCAPED_UNICODE);
    
} catch (Exception $e) {
    // 에러 응답
    respond('error', '레슨 내역을 불러오는 중 오류가 발생했습니다: ' . $e->getMessage());
} 