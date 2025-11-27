<?php
// 에러 보고 설정
ini_set('display_errors', 1);
error_reporting(E_ALL);

// PHP 타임존 설정
date_default_timezone_set('Asia/Seoul');

header('Content-Type: application/json; charset=utf-8');

// DB 연결
require_once '../../config/db_connect.php';

// 응답 함수
function respond($status, $message = '', $data = []) {
    $response = [
        'status' => $status,
        'message' => $message,
        'data' => $data,
        'success' => ($status === 'success')
    ];
    
    echo json_encode($response, JSON_UNESCAPED_UNICODE);
    exit;
}

// 필수 파라미터 확인
if (!isset($_POST['member_id']) || empty($_POST['member_id'])) {
    respond('error', '회원 ID가 필요합니다.');
}

if (!isset($_POST['expiry_date']) || empty($_POST['expiry_date'])) {
    respond('error', '유효기간이 필요합니다.');
}

$member_id = intval($_POST['member_id']);
$expiry_date = $_POST['expiry_date'];

// 날짜 형식 검증
if (!preg_match('/^\d{4}-\d{2}-\d{2}$/', $expiry_date)) {
    respond('error', '유효기간 형식이 올바르지 않습니다. (YYYY-MM-DD)');
}

try {
    // 해당 회원의 모든 레슨권의 유효기간 업데이트
    $update_query = "
        UPDATE LS_contracts 
        SET LS_expiry_date = ?, 
            updated_at = NOW()
        WHERE member_id = ?
    ";
    
    $stmt = $db->prepare($update_query);
    $stmt->bind_param('si', $expiry_date, $member_id);
    $result = $stmt->execute();
    
    if ($result) {
        // 변경된 레코드 수 확인
        $affected_rows = $stmt->affected_rows;
        
        if ($affected_rows > 0) {
            respond('success', '유효기간이 변경되었습니다. ' . $affected_rows . '개의 레슨권이 업데이트 되었습니다.');
        } else {
            respond('success', '업데이트할 레슨권이 없습니다.');
        }
    } else {
        respond('error', '유효기간 변경 중 오류가 발생했습니다: ' . $stmt->error);
    }
    
} catch (Exception $e) {
    respond('error', '유효기간 변경 중 오류가 발생했습니다: ' . $e->getMessage());
} 