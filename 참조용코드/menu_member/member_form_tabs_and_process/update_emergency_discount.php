<?php
// 긴급할인 업데이트를 처리하는 API
date_default_timezone_set('Asia/Seoul');
require_once '../../config/db_connect.php';

header('Content-Type: application/json');

try {
    // POST 요청 확인
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        throw new Exception('잘못된 요청 방식입니다.');
    }
    
    // 필수 파라미터 검증
    $required_params = ['reservation_id', 'discount_amount', 'discount_reason'];
    foreach ($required_params as $param) {
        if (!isset($_POST[$param]) || trim($_POST[$param]) === '') {
            throw new Exception('필수 항목이 누락되었습니다: ' . $param);
        }
    }
    
    // 파라미터 가져오기
    $reservation_id = trim($_POST['reservation_id']);
    $discount_amount = intval($_POST['discount_amount']);
    $discount_reason = trim($_POST['discount_reason']);
    
    // 유효성 검사
    if ($discount_amount < 0) {
        throw new Exception('할인 금액은 0 이상이어야 합니다.');
    }
    
    // 테이블에서 기존 데이터 조회
    $query = "SELECT * FROM Priced_FMS WHERE reservation_id = ?";
    $stmt = $db->prepare($query);
    if (!$stmt) {
        throw new Exception('데이터베이스 쿼리 준비 오류: ' . $db->error);
    }
    
    $stmt->bind_param('s', $reservation_id);
    if (!$stmt->execute()) {
        throw new Exception('데이터베이스 쿼리 실행 오류: ' . $stmt->error);
    }
    
    $result = $stmt->get_result();
    if ($result->num_rows === 0) {
        throw new Exception('해당 예약번호의 데이터가 없습니다.');
    }
    
    $record = $result->fetch_assoc();
    
    // 값 업데이트 준비
    $old_emergency_discount = intval($record['emergency_discount']);
    $old_total_discount = intval($record['total_discount']);
    $old_net_amt = intval($record['net_amt']);
    
    // 새 값 계산
    $new_emergency_discount = $discount_amount;
    $new_total_discount = $old_total_discount - $old_emergency_discount + $new_emergency_discount;
    $new_net_amt = intval($record['total_amt']) - $new_total_discount;
    
    // 데이터 업데이트
    $update_query = "
        UPDATE Priced_FMS 
        SET 
            emergency_discount = ?,
            emergency_reason = ?
        WHERE reservation_id = ?
    ";
    
    $update_stmt = $db->prepare($update_query);
    if (!$update_stmt) {
        throw new Exception('데이터베이스 업데이트 쿼리 준비 오류: ' . $db->error);
    }
    
    $update_stmt->bind_param('iss', $new_emergency_discount, $discount_reason, $reservation_id);
    if (!$update_stmt->execute()) {
        throw new Exception('데이터베이스 업데이트 쿼리 실행 오류: ' . $update_stmt->error);
    }
    
    if ($update_stmt->affected_rows > 0) {
        echo json_encode(['success' => true, 'message' => '긴급할인이 등록되었습니다.']);
    } else {
        echo json_encode(['success' => false, 'message' => '데이터가 변경되지 않았습니다.']);
    }
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => $e->getMessage()]);
} finally {
    if (isset($db)) {
        $db->close();
    }
}
?> 