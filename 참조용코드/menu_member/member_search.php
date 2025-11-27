<?php
session_start();

// 로그인 체크
if (!isset($_SESSION['staff_id'])) {
    header('Content-Type: application/json');
    echo json_encode(['error' => 'Unauthorized']);
    exit;
}

require_once '../config/db_connect.php';

// 검색어가 없으면 빈 배열 반환
if (!isset($_GET['search']) || strlen($_GET['search']) < 2) {
    header('Content-Type: application/json');
    echo json_encode([]);
    exit;
}

$search = '%' . $_GET['search'] . '%';
$query = "
    SELECT member_id, member_name, member_phone
    FROM members
    WHERE member_name LIKE ? OR member_phone LIKE ?
    ORDER BY member_name ASC
    LIMIT 10
";

$stmt = $db->prepare($query);
$stmt->bind_param('ss', $search, $search);
$stmt->execute();
$result = $stmt->get_result();

$members = [];
while ($row = $result->fetch_assoc()) {
    $members[] = $row;
}

header('Content-Type: application/json');
echo json_encode($members); 