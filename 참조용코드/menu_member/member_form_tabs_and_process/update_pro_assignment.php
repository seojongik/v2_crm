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
        'success' => ($status === 'success')
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

// POST 데이터 확인
$json_data = file_get_contents('php://input');
$data = json_decode($json_data, true);

if (!$data || !isset($data['member_id']) || empty($data['member_id'])) {
    respond('error', '회원 ID가 필요합니다.');
}

$member_id = intval($data['member_id']);
$selected_pros = isset($data['pros']) ? $data['pros'] : [];

// 트랜잭션 시작
$db->begin_transaction();

try {
    // 1. 현재 회원의 유효한 프로 관계 가져오기
    $query = "
        SELECT 
            member_pro_relation_id,
            staff_nickname
        FROM member_pro_match 
        WHERE member_id = ? 
        AND relation_status = '유효'
    ";
    
    $stmt = $db->prepare($query);
    $stmt->bind_param('i', $member_id);
    $stmt->execute();
    
    $result = $stmt->get_result();
    $current_relations = [];
    
    while ($row = $result->fetch_assoc()) {
        $current_relations[$row['staff_nickname']] = $row['member_pro_relation_id'];
    }
    
    // 2. 기존 관계에서 선택되지 않은 프로는 만료로 변경
    foreach ($current_relations as $nickname => $relation_id) {
        if (!in_array($nickname, $selected_pros)) {
            $update_query = "
                UPDATE member_pro_match 
                SET relation_status = '만료' 
                WHERE member_pro_relation_id = ?
            ";
            
            $update_stmt = $db->prepare($update_query);
            $update_stmt->bind_param('i', $relation_id);
            $update_stmt->execute();
        }
    }
    
    // 3. 새로 선택된 프로는 새 관계 생성
    foreach ($selected_pros as $nickname) {
        if (!isset($current_relations[$nickname])) {
            $insert_query = "
                INSERT INTO member_pro_match 
                (member_id, staff_nickname, registered_at, relation_status) 
                VALUES (?, ?, NOW(), '유효')
            ";
            
            $insert_stmt = $db->prepare($insert_query);
            $insert_stmt->bind_param('is', $member_id, $nickname);
            $insert_stmt->execute();
        }
    }
    
    // 트랜잭션 커밋
    $db->commit();
    
    // 4. 응답 반환
    respond('success', '담당 프로가 성공적으로 업데이트되었습니다.');
    
} catch (Exception $e) {
    // 트랜잭션 롤백
    $db->rollback();
    respond('error', '담당 프로 업데이트 중 오류가 발생했습니다: ' . $e->getMessage());
} 