<?php
require_once '../config/db_connect.php';

if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['id']) && isset($_POST['password'])) {
    if ($_POST['password'] !== '0102') {
        echo json_encode(['success' => false, 'message' => '비밀번호가 올바르지 않습니다.']);
        exit;
    }

    $stmt = $db->prepare('DELETE FROM members WHERE member_id = ?');
    $stmt->bind_param('i', $_POST['id']);
    $result = $stmt->execute();
    
    if ($result) {
        echo json_encode(['success' => true]);
    } else {
        echo json_encode(['success' => false, 'message' => '삭제 실패']);
    }
    exit;
}

header('Location: member_list.php');
exit; 