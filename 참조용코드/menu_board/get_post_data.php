<?php
header('Content-Type: application/json; charset=utf-8');
header('X-Content-Type-Options: nosniff');
header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');

require_once '../config/db_connect.php';
session_start();

// 로그인 상태가 아니면 오류 반환
if (!isset($_SESSION['staff_id'])) {
    echo json_encode(['success' => false, 'message' => 'Unauthorized']);
    exit;
}

$id = $_GET['id'] ?? null;
if (!$id) {
    echo json_encode(['success' => false, 'message' => '게시글 ID가 필요합니다.']);
    exit;
}

try {
    $stmt = $db->prepare('
        SELECT b.*, s.staff_name, s.staff_type, m.member_name,
               DATE_FORMAT(b.created_at, "%Y-%m-%d %H:%i") as created_at 
        FROM Board b
        JOIN Staff s ON b.staff_id = s.staff_id
        LEFT JOIN members m ON b.member_id = m.member_id
        WHERE b.board_id = ?
    ');
    $stmt->bind_param('i', $id);
    $stmt->execute();
    $result = $stmt->get_result();
    $post = $result->fetch_assoc();

    if (!$post) {
        echo json_encode(['success' => false, 'message' => '게시글을 찾을 수 없습니다.']);
        exit;
    }

    // 댓글 목록도 가져오기
    $stmt = $db->prepare('
        SELECT c.*, s.staff_name, s.staff_type,
               DATE_FORMAT(c.created_at, "%Y-%m-%d %H:%i") as created_at
        FROM Comment c
        JOIN Staff s ON c.staff_id = s.staff_id
        WHERE c.board_id = ?
        ORDER BY c.created_at ASC
    ');
    $stmt->bind_param('i', $id);
    $stmt->execute();
    $comments_result = $stmt->get_result();
    
    $comments = [];
    while ($comment = $comments_result->fetch_assoc()) {
        $comments[] = $comment;
    }

    echo json_encode([
        'success' => true, 
        'post' => $post,
        'comments' => $comments
    ]);
    
} catch (Exception $e) {
    echo json_encode(['success' => false, 'message' => $e->getMessage()]);
}
?> 