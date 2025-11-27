<?php
require_once '../config/db_connect.php';
session_start();

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $board_id = $_POST['board_id'] ?? null;
    $content = $_POST['content'] ?? null;
    $staff_id = $_SESSION['staff_id'];

    if ($board_id && $content) {
        try {
            $stmt = $db->prepare('INSERT INTO Comment (board_id, staff_id, content) VALUES (?, ?, ?)');
            $stmt->bind_param('iis', $board_id, $staff_id, $content);
            $result = $stmt->execute();
            
            echo json_encode(['success' => $result]);
        } catch (Exception $e) {
            echo json_encode(['success' => false, 'message' => $e->getMessage()]);
        }
    } else {
        echo json_encode(['success' => false, 'message' => '필수 정보가 누락되었습니다.']);
    }
    exit;
}

header('Location: board_list.php');
exit; 