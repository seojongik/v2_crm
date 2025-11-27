<?php
// 응답을 JSON 형식으로 설정
header('Content-Type: application/json');

// 디버깅 로그 시작
error_log("verify_staff_delete.php 실행 시작");

require_once '../../config/db_connect.php';

// POST 데이터 로깅
error_log("POST 데이터: " . print_r($_POST, true));

// 요청 검증
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    error_log("잘못된 요청 방식: " . $_SERVER['REQUEST_METHOD']);
    echo json_encode(['success' => false, 'message' => '잘못된 요청 방식입니다.']);
    exit;
}

// 필수 데이터 확인
if (!isset($_POST['password']) || empty($_POST['password'])) {
    error_log("비밀번호가 누락됨");
    echo json_encode(['success' => false, 'message' => '비밀번호가 필요합니다.']);
    exit;
}

// 계약 ID가 전달되었는지 확인 (선택적)
$contract_id = isset($_POST['contract_id']) ? $_POST['contract_id'] : null;
error_log("계약 ID: " . $contract_id);

// 비밀번호
$password = $_POST['password'];

// 스태프 인증 - 공용 계정이나 시스템관리자의 비밀번호와 일치하는지 확인
$auth_stmt = $db->prepare('
    SELECT staff_id, staff_name
    FROM Staff 
    WHERE (staff_access_id = "famokdong9" OR staff_access_id = "famokdong") 
    AND staff_password = ?
');
$auth_stmt->bind_param('s', $password);
$auth_stmt->execute();
$auth_result = $auth_stmt->get_result();

if ($auth_result->num_rows === 0) {
    error_log("삭제 권한 인증 실패");
    echo json_encode(['success' => false, 'message' => '삭제 권한이 없습니다. 비밀번호를 확인해주세요.']);
    exit;
}

// 인증 성공한 스태프 정보
$staff = $auth_result->fetch_assoc();
error_log("삭제 권한 인증 성공: 스태프 " . $staff['staff_name']);

// 성공 응답
$response = [
    'success' => true,
    'message' => '삭제 권한이 확인되었습니다.',
    'staff_id' => $staff['staff_id'],
    'staff_name' => $staff['staff_name']
];

error_log('성공 응답: ' . json_encode($response));
echo json_encode($response);
exit;
?> 