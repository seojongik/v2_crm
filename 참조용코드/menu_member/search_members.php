<?php
header('Content-Type: application/json; charset=utf-8');
require_once '../config/db_connect.php';
session_start();

// 로그인 확인
if (!isset($_SESSION['staff_id'])) {
    echo json_encode(['success' => false, 'message' => '로그인이 필요합니다.']);
    exit;
}

// 검색어 및 페이지 파라미터 받기
$term = $_POST['search'] ?? '';
$page = isset($_POST['page']) ? (int)$_POST['page'] : 1;
$limit = 10; // 페이지당 결과 수
$offset = ($page - 1) * $limit;

// 유효성 검사
if (empty($term)) {
    $empty_response = [
        'success' => true,
        'members' => [],
        'total_pages' => 0,
        'current_page' => $page
    ];
    echo json_encode($empty_response);
    exit;
}

try {
    // 검색어에 따른 조건 작성
    $search_term = '%' . $term . '%';
    
    // 전체 결과 수 조회
    $count_query = "
        SELECT COUNT(*) as total 
        FROM members 
        WHERE member_id LIKE ? 
           OR member_name LIKE ? 
           OR member_phone LIKE ? 
           OR member_nickname LIKE ?
    ";
    $count_stmt = $db->prepare($count_query);
    $count_stmt->bind_param('ssss', $search_term, $search_term, $search_term, $search_term);
    $count_stmt->execute();
    $total_result = $count_stmt->get_result();
    $total_row = $total_result->fetch_assoc();
    $total_items = $total_row['total'];
    $total_pages = ceil($total_items / $limit);
    
    // 회원 정보 조회
    $query = "
        SELECT member_id, member_name, member_phone, member_nickname
        FROM members 
        WHERE member_id LIKE ? 
           OR member_name LIKE ? 
           OR member_phone LIKE ? 
           OR member_nickname LIKE ?
        ORDER BY member_id DESC
        LIMIT ? OFFSET ?
    ";
    
    $stmt = $db->prepare($query);
    $stmt->bind_param('ssssii', $search_term, $search_term, $search_term, $search_term, $limit, $offset);
    $stmt->execute();
    $result = $stmt->get_result();
    
    $members = [];
    while ($member = $result->fetch_assoc()) {
        $members[] = [
            'member_id' => $member['member_id'],
            'member_name' => htmlspecialchars($member['member_name']),
            'member_phone' => htmlspecialchars($member['member_phone']),
            'member_nickname' => htmlspecialchars($member['member_nickname'] ?? '')
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