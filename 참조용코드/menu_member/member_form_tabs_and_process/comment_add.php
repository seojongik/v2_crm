<?php
// 댓글 추가 API 엔드포인트
require_once '../../config/db_connect.php';
session_start();

// 응답 헤더 설정
header('Content-Type: application/json');

// 로그인 확인
if (!isset($_SESSION['staff_id'])) {
    echo json_encode([
        'success' => false,
        'message' => '로그인이 필요합니다.'
    ]);
    exit;
}

$staff_id = $_SESSION['staff_id'];

// POST 데이터 확인
if ($_SERVER['REQUEST_METHOD'] !== 'POST' || !isset($_POST['board_id']) || (!isset($_POST['comment_content']) && !isset($_POST['content']))) {
    echo json_encode([
        'success' => false,
        'message' => '필수 데이터가 누락되었습니다.'
    ]);
    exit;
}

$board_id = intval($_POST['board_id']);
// content 또는 comment_content 둘 중 하나를 사용할 수 있도록 함
$comment_content = trim(isset($_POST['comment_content']) ? $_POST['comment_content'] : $_POST['content']);

// 유효성 검증
if (empty($comment_content)) {
    echo json_encode([
        'success' => false,
        'message' => '댓글 내용을 입력해주세요.'
    ]);
    exit;
}

// 게시글 존재 여부 확인
$check_query = "SELECT board_id FROM Board WHERE board_id = ?";
$check_stmt = $db->prepare($check_query);
$check_stmt->bind_param('i', $board_id);
$check_stmt->execute();
$check_result = $check_stmt->get_result();

if ($check_result->num_rows === 0) {
    echo json_encode([
        'success' => false,
        'message' => '존재하지 않는 게시글입니다.'
    ]);
    exit;
}

// 댓글 저장
try {
    // content 컬럼과 comment_content 컬럼 모두 존재하는지 확인
    $check_column_query = "SHOW COLUMNS FROM Comment LIKE 'content'";
    $check_column_result = $db->query($check_column_query);
    $content_column_exists = $check_column_result->num_rows > 0;
    
    if ($content_column_exists) {
        $insert_query = "INSERT INTO Comment (board_id, staff_id, content, created_at) 
                        VALUES (?, ?, ?, NOW())";
    } else {
        $insert_query = "INSERT INTO Comment (board_id, staff_id, comment_content, created_at) 
                        VALUES (?, ?, ?, NOW())";
    }
    
    $insert_stmt = $db->prepare($insert_query);
    $insert_stmt->bind_param('iis', $board_id, $staff_id, $comment_content);
    $success = $insert_stmt->execute();
    
    if ($success) {
        $comment_id = $db->insert_id;
        
        // 직원 정보 조회
        $staff_query = "SELECT staff_name FROM Staff WHERE staff_id = ?";
        $staff_stmt = $db->prepare($staff_query);
        $staff_stmt->bind_param('i', $staff_id);
        $staff_stmt->execute();
        $staff_info = $staff_stmt->get_result()->fetch_assoc();
        
        echo json_encode([
            'success' => true,
            'message' => '댓글이 성공적으로 추가되었습니다.',
            'comment' => [
                'comment_id' => $comment_id,
                'staff_name' => $staff_info['staff_name'],
                'comment_content' => $comment_content,
                'content' => $comment_content, // 두 필드 모두 반환하여 호환성 유지
                'created_at' => date('Y-m-d H:i:s')
            ]
        ]);
    } else {
        echo json_encode([
            'success' => false,
            'message' => '댓글 추가 중 오류가 발생했습니다.'
        ]);
    }
} catch (Exception $e) {
    echo json_encode([
        'success' => false,
        'message' => '오류: ' . $e->getMessage()
    ]);
} 