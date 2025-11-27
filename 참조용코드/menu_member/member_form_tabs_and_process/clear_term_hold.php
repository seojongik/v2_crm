<?php
require_once '../../config/db_connect.php';

header('Content-Type: application/json');

if (!isset($_POST['term_id'])) {
    echo json_encode(['success' => false, 'message' => '필수 파라미터가 누락되었습니다.']);
    exit;
}

$term_id = $_POST['term_id'];

// 쿼리 준비
$query = "UPDATE Term_member SET term_holdstart = NULL, term_holdend = NULL WHERE term_id = ?";
$stmt = $db->prepare($query);
$stmt->bind_param('i', $term_id);

// 쿼리 실행
if ($stmt->execute()) {
    echo json_encode(['success' => true]);
} else {
    echo json_encode(['success' => false, 'message' => '데이터베이스 업데이트 중 오류가 발생했습니다.']);
} 