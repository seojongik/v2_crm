<?php
header('Content-Type: application/json; charset=utf-8');
require_once '../config/db_connect.php';
session_start();

// 로그인 확인
if (!isset($_SESSION['staff_id'])) {
    echo json_encode(['success' => false, 'message' => '로그인이 필요합니다.']);
    exit;
}

// 페이지 파라미터 받기
$page = isset($_GET['page']) ? (int)$_GET['page'] : 1;
$limit = 10; // 페이지당 결과 수
$offset = ($page - 1) * $limit;

try {
    // 전체 회원 수 조회
    $count_query = "SELECT COUNT(*) as total FROM members";
    $count_result = $db->query($count_query);
    
    if (!$count_result) {
        throw new Exception('회원 정보 조회 중 오류가 발생했습니다.');
    }
    
    $total_row = $count_result->fetch_assoc();
    $total_items = $total_row['total'];
    $total_pages = ceil($total_items / $limit);
    
    // 회원 목록 조회
    $query = "
        SELECT member_id, member_name, member_phone
        FROM members
        ORDER BY member_id DESC
        LIMIT ? OFFSET ?
    ";
    
    $stmt = $db->prepare($query);
    $stmt->bind_param('ii', $limit, $offset);
    $stmt->execute();
    $result = $stmt->get_result();
    
    if (!$result) {
        throw new Exception('회원 정보 조회 중 오류가 발생했습니다.');
    }
    
    $members = [];
    while ($row = $result->fetch_assoc()) {
        $members[] = [
            'member_id' => $row['member_id'],
            'member_name' => htmlspecialchars($row['member_name']),
            'member_phone' => htmlspecialchars($row['member_phone'])
        ];
    }
    
    echo json_encode([
        'success' => true,
        'members' => $members,
        'total_pages' => $total_pages,
        'current_page' => $page
    ]);
    
} catch (Exception $e) {
    echo json_encode(['success' => false, 'message' => $e->getMessage()]);
}
?> 