<?php
// 오늘자 타석 이용 내역을 가져오는 API
date_default_timezone_set('Asia/Seoul');
require_once '../../config/db_connect.php';

header('Content-Type: application/json');

try {
    // 디버깅 정보 추가
    $server_time = new DateTime();
    $server_time_str = $server_time->format('Y-m-d H:i:s');
    $server_date = $server_time->format('Y-m-d');

    // 필수 파라미터 확인
    if (!isset($_GET['member_id']) || !isset($_GET['date'])) {
        throw new Exception('필수 파라미터가 누락되었습니다.');
    }
    
    // 파라미터 가져오기
    $member_id = intval($_GET['member_id']);
    $date = trim($_GET['date']);
    
    // 날짜 형식 검증
    if (!preg_match('/^\d{4}-\d{2}-\d{2}$/', $date)) {
        throw new Exception('올바른 날짜 형식이 아닙니다 (YYYY-MM-DD).');
    }
    
    // 오늘 날짜와 요청된 날짜 비교 로깅
    $today_kst = date('Y-m-d');
    $date_info = "요청된 날짜: $date, 서버 날짜(KST): $today_kst, 서버 시간: $server_time_str";
    error_log($date_info);
    
    // 디버깅 목적으로 두 날짜 모두 사용
    // 실제 쿼리에는 클라이언트에서 보낸 날짜를 사용
    $use_date = $date;
    
    // 데이터 쿼리
    $query = "
        SELECT 
            reservation_id,
            ts_id,
            ts_date,
            TIME_FORMAT(ts_start, '%H:%i') as ts_start,
            TIME_FORMAT(ts_end, '%H:%i') as ts_end,
            total_amt,
            total_discount,
            emergency_discount,
            net_amt
        FROM Priced_FMS
        WHERE member_id = ? AND DATE(ts_date) = ? AND ts_type = '결제완료'
        ORDER BY ts_start DESC
    ";
    
    $stmt = $db->prepare($query);
    if (!$stmt) {
        throw new Exception('데이터베이스 쿼리 준비 오류: ' . $db->error);
    }
    
    $stmt->bind_param('is', $member_id, $use_date);
    if (!$stmt->execute()) {
        throw new Exception('데이터베이스 쿼리 실행 오류: ' . $stmt->error);
    }
    
    $result = $stmt->get_result();
    $records = [];
    
    while ($row = $result->fetch_assoc()) {
        $records[] = $row;
    }
    
    // 디버깅 정보 추가
    $debug_info = [
        'debug' => [
            'server_date' => $server_date,
            'server_time' => $server_time_str,
            'requested_date' => $date,
            'query_date' => $use_date,
            'row_count' => count($records),
        ]
    ];
    
    // 결과에 디버깅 정보 포함
    $response = array_merge($debug_info, ['data' => $records]);
    
    // 결과 반환
    echo json_encode($response);
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'error' => true, 
        'message' => $e->getMessage(),
        'debug' => [
            'server_date' => $server_date ?? date('Y-m-d'),
            'server_time' => $server_time_str ?? date('Y-m-d H:i:s'),
            'requested_date' => $date ?? 'unknown',
        ]
    ]);
} finally {
    if (isset($db)) {
        $db->close();
    }
}
?> 