<?php
// 에러 보고 설정
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

// 디버깅용 로그
error_log("contract_delete.php 실행 시작");

// 데이터베이스 연결
require_once '../../config/db_connect.php';

// 응답 헤더 설정
header('Content-Type: application/json');

// POST 요청 확인
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    error_log("잘못된 요청 방식: " . $_SERVER['REQUEST_METHOD']);
    echo json_encode(['success' => false, 'message' => '잘못된 요청 방식입니다.']);
    exit;
}

// 필수 데이터 확인
if (!isset($_POST['contract_id']) || empty($_POST['contract_id'])) {
    error_log("계약 ID가 누락됨");
    echo json_encode(['success' => false, 'message' => '계약 ID가 필요합니다.']);
    exit;
}

// 비밀번호 확인
if (!isset($_POST['password']) || empty($_POST['password'])) {
    error_log("비밀번호가 누락됨");
    echo json_encode(['success' => false, 'message' => '관리자 비밀번호가 필요합니다.']);
    exit;
}

// 데이터 가져오기
$contract_id = intval($_POST['contract_id']);
$password = $_POST['password'];

error_log("계약 ID: " . $contract_id);

try {
    // 트랜잭션 시작
    $db->begin_transaction();

    // 비밀번호 검증 - verify_staff_delete.php에서 이미 검증했겠지만 한번 더 확인
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
        // 트랜잭션 롤백
        $db->rollback();
        
        error_log("삭제 권한 인증 실패");
        echo json_encode(['success' => false, 'message' => '삭제 권한이 없습니다. 비밀번호를 확인해주세요.']);
        exit;
    }

    $staff = $auth_result->fetch_assoc();
    $staff_id = $staff['staff_id'];

    // 계약 정보 조회
    $contract_stmt = $db->prepare('
        SELECT ch.*, m.member_name
        FROM contract_history ch
        JOIN members m ON ch.member_id = m.member_id
        WHERE ch.contract_history_id = ?
    ');
    $contract_stmt->bind_param('i', $contract_id);
    $contract_stmt->execute();
    $contract_result = $contract_stmt->get_result();

    if ($contract_result->num_rows === 0) {
        // 트랜잭션 롤백
        $db->rollback();
        
        error_log("계약 정보를 찾을 수 없음");
        echo json_encode(['success' => false, 'message' => '해당 계약 정보를 찾을 수 없습니다.']);
        exit;
    }

    $contract = $contract_result->fetch_assoc();
    $member_id = $contract['member_id'];
    $member_name = $contract['member_name'];

    // 계약 상태 변경 (실제 삭제가 아닌 상태 변경)
    $update_stmt = $db->prepare('
        UPDATE contract_history 
        SET contract_history_status = "삭제",
            updated_at = NOW(),
            updated_by = ?
        WHERE contract_history_id = ?
    ');
    $update_stmt->bind_param('si', $staff_id, $contract_id);
    $update_stmt->execute();

    if ($update_stmt->affected_rows === 0) {
        // 트랜잭션 롤백
        $db->rollback();
        
        error_log("계약 상태 변경 실패");
        echo json_encode(['success' => false, 'message' => '계약 상태 변경에 실패했습니다.']);
        exit;
    }

    // 삭제 로그 기록
    $log_stmt = $db->prepare('
        INSERT INTO activity_logs (
            activity_type,
            activity_description,
            affected_table,
            record_id,
            member_id,
            member_name,
            staff_id,
            activity_timestamp
        ) VALUES (
            "계약 삭제",
            CONCAT("계약 ID: ", ?, " 삭제됨"),
            "contract_history",
            ?,
            ?,
            ?,
            ?,
            NOW()
        )
    ');
    $log_stmt->bind_param('iiiss', $contract_id, $contract_id, $member_id, $member_name, $staff_id);
    $log_stmt->execute();

    // 트랜잭션 커밋
    $db->commit();

    // 성공 응답
    error_log("계약 삭제 성공: 계약 ID " . $contract_id);
    echo json_encode([
        'success' => true,
        'message' => '계약이 성공적으로 삭제되었습니다.',
        'contract_id' => $contract_id
    ]);

} catch (Exception $e) {
    // 오류 발생 시 롤백
    $db->rollback();
    
    error_log("오류 발생: " . $e->getMessage());
    echo json_encode([
        'success' => false,
        'message' => '계약 삭제 중 오류가 발생했습니다: ' . $e->getMessage()
    ]);
}

error_log("contract_delete.php 실행 종료");
?> 