<?php
require_once '../config/db_connect.php';
session_start();

if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['id'])) {
    try {
        $stmt = $db->prepare('DELETE FROM Board WHERE board_id = ? AND staff_id = ?');
        $stmt->bind_param('ii', $_POST['id'], $_SESSION['staff_id']);
        $result = $stmt->execute();
        
        if ($result) {
            $stmt = $db->prepare('DELETE FROM Posts WHERE board_id = ?');
            $stmt->bind_param('i', $_POST['id']);
            $result = $stmt->execute();
        }

        echo json_encode(['success' => $result]);
    } catch (Exception $e) {
        echo json_encode(['success' => false, 'message' => $e->getMessage()]);
    }
    exit;
}

header('Location: board_list.php');
exit;