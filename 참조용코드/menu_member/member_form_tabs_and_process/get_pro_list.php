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
        'message' => $message
    ];
    
    if ($status === 'error') {
        $response['error'] = true;
    }
    
    if (!empty($data)) {
        $response = array_merge($response, $data);
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
    // 1. 모든 프로 목록 가져오기 (프로 타입만)
    $query = "
        SELECT 
            staff_id,
            staff_name,
            staff_nickname,
            staff_status
        FROM Staff 
        WHERE staff_type = '프로'
        AND staff_status = '재직'
        ORDER BY staff_name ASC
    ";
    
    $result = $db->query($query);
    
    if (!$result) {
        throw new Exception("프로 목록 조회 오류: " . $db->error);
    }
    
    $pros = [];
    while ($row = $result->fetch_assoc()) {
        $pros[] = $row;
    }
    
    // 2. 현재 회원의 유효한 프로 관계 가져오기
    $query = "
        SELECT 
            staff_nickname
        FROM member_pro_match 
        WHERE member_id = ? 
        AND relation_status = '유효'
    ";
    
    $stmt = $db->prepare($query);
    $stmt->bind_param('i', $member_id);
    $stmt->execute();
    
    $result = $stmt->get_result();
    $assigned_pros = [];
    
    while ($row = $result->fetch_assoc()) {
        $assigned_pros[] = $row['staff_nickname'];
    }
    
    // 3. 프로 목록에 할당 정보 추가
    foreach ($pros as &$pro) {
        $pro['is_assigned'] = in_array($pro['staff_nickname'], $assigned_pros);
    }
    
    // 4. 응답 반환
    respond('success', '프로 목록을 성공적으로 불러왔습니다.', ['pros' => $pros]);
    
} catch (Exception $e) {
    respond('error', '프로 목록을 불러오는 중 오류가 발생했습니다: ' . $e->getMessage());
} 