<?php
require_once '../config/db_connect.php';
session_start();

// 로그인 확인
if (!isset($_SESSION['staff_id'])) {
    header('Content-Type: application/json');
    echo json_encode(['success' => false, 'message' => '로그인이 필요합니다.']);
    exit;
}

// JSON 요청 데이터 받기
$input = json_decode(file_get_contents('php://input'), true);

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    header('Content-Type: application/json');
    echo json_encode(['success' => false, 'message' => '잘못된 요청 방식입니다.']);
    exit;
}

// 필수 항목 체크
if (!isset($input['title']) || !isset($input['content']) || !isset($input['board_type'])) {
    header('Content-Type: application/json');
    echo json_encode(['success' => false, 'message' => '필수 정보가 누락되었습니다.']);
    exit;
}

// 데이터 준비
$title = $input['title'];
$content = $input['content'];
$board_type = $input['board_type'];
$staff_id = $_SESSION['staff_id']; // 세션에서 직원 ID 가져오기
$member_id = isset($input['member_id']) ? intval($input['member_id']) : null;

try {
    // 게시글 저장 쿼리
    $query = "INSERT INTO Board (title, content, staff_id, board_type, member_id, created_at, updated_at) 
              VALUES (?, ?, ?, ?, ?, NOW(), NOW())";
    
    $stmt = $db->prepare($query);
    
    // member_id가 null이거나 0인 경우를 처리
    if ($member_id === null || $member_id === 0) {
        $stmt->bind_param('ssiss', $title, $content, $staff_id, $board_type, $member_id_nullable);
        $member_id_nullable = null;
    } else {
        $stmt->bind_param('ssisi', $title, $content, $staff_id, $board_type, $member_id);
    }
    
    $success = $stmt->execute();
    
    if ($success) {
        $board_id = $db->insert_id;
        header('Content-Type: application/json');
        echo json_encode(['success' => true, 'board_id' => $board_id]);
    } else {
        throw new Exception($stmt->error);
    }
} catch (Exception $e) {
    header('Content-Type: application/json');
    echo json_encode(['success' => false, 'message' => '저장 중 오류가 발생했습니다: ' . $e->getMessage()]);
}
?> 