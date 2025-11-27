<?php
header('Content-Type: application/json; charset=utf-8');
require_once '../config/db_connect.php';
session_start();

// 로그인 확인
if (!isset($_SESSION['staff_id'])) {
    echo json_encode(['success' => false, 'message' => '로그인이 필요합니다.']);
    exit;
}

// POST 요청 확인
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    echo json_encode(['success' => false, 'message' => '잘못된 요청 방식입니다.']);
    exit;
}

// 파라미터 받기
$board_id = isset($_POST['board_id']) ? (int)$_POST['board_id'] : 0;
$member_id = isset($_POST['member_id']) ? (int)$_POST['member_id'] : 0;

// 유효성 검사
if ($board_id <= 0 || $member_id <= 0) {
    echo json_encode(['success' => false, 'message' => '유효하지 않은 파라미터입니다.']);
    exit;
}

try {
    // 트랜잭션 시작
    $db->begin_transaction();
    
    // 원본 게시글 조회
    $query = "
        SELECT title, content, staff_id, created_at, member_id
        FROM Board 
        WHERE board_id = ? AND board_type = '상담기록'
    ";
    
    $stmt = $db->prepare($query);
    $stmt->bind_param('i', $board_id);
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($result->num_rows === 0) {
        // 롤백
        $db->rollback();
        echo json_encode(['success' => false, 'message' => '상담기록을 찾을 수 없습니다.']);
        exit;
    }
    
    $post = $result->fetch_assoc();
    
    // 이미 회원이 등록되었는지 확인
    if (!is_null($post['member_id']) && $post['member_id'] > 0) {
        // 롤백
        $db->rollback();
        echo json_encode(['success' => false, 'message' => '이미 회원이 등록된 상담기록입니다.']);
        exit;
    }
    
    // 회원 정보 확인
    $member_query = "SELECT member_name FROM members WHERE member_id = ?";
    $member_stmt = $db->prepare($member_query);
    $member_stmt->bind_param('i', $member_id);
    $member_stmt->execute();
    $member_result = $member_stmt->get_result();
    
    if ($member_result->num_rows === 0) {
        // 롤백
        $db->rollback();
        echo json_encode(['success' => false, 'message' => '회원 정보를 찾을 수 없습니다.']);
        exit;
    }
    
    $member = $member_result->fetch_assoc();
    
    // 상담기록의 member_id 업데이트
    $update_query = "
        UPDATE Board 
        SET member_id = ?, updated_at = NOW()
        WHERE board_id = ?
    ";
    
    $update_stmt = $db->prepare($update_query);
    $update_stmt->bind_param('ii', $member_id, $board_id);
    $update_success = $update_stmt->execute();
    
    if (!$update_success) {
        // 롤백
        $db->rollback();
        throw new Exception('상담기록 업데이트에 실패했습니다.');
    }
    
    // 트랜잭션 커밋
    $db->commit();
    
    echo json_encode([
        'success' => true,
        'message' => '성공적으로 회원이 등록되었습니다.',
        'board_id' => $board_id,
        'member_name' => $member['member_name']
    ]);
    
} catch (Exception $e) {
    // 롤백
    $db->rollback();
    echo json_encode(['success' => false, 'message' => $e->getMessage()]);
}
?> 