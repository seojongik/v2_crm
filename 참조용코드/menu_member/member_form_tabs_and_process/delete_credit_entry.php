<?php
// DB 연결
include '../../config/db_connect.php';

// 세션 확인 및 권한 체크
session_start();
if (!isset($_SESSION['staff_id'])) {
    echo json_encode([
        'success' => false,
        'message' => '로그인이 필요합니다.'
    ]);
    exit;
}

// 요청 데이터 확인
if (!isset($_POST['credit_id']) || empty($_POST['credit_id'])) {
    echo json_encode([
        'success' => false,
        'message' => '크레딧 ID가 전달되지 않았습니다.'
    ]);
    exit;
}

$credit_id = intval($_POST['credit_id']);
$staff_id = $_SESSION['staff_id'];

// 트랜잭션 시작
$db->begin_transaction();

try {
    // 크레딧 항목 정보 조회
    $query = "SELECT * FROM credit_history WHERE credit_id = ?";
    $stmt = $db->prepare($query);
    $stmt->bind_param('i', $credit_id);
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($result->num_rows === 0) {
        throw new Exception('크레딧 항목을 찾을 수 없습니다.');
    }
    
    $credit = $result->fetch_assoc();
    
    // 수동 항목인지 확인
    if (strpos($credit['credit_description'], '수동') === false) {
        throw new Exception('수동으로 등록된 크레딧 항목만 삭제할 수 있습니다.');
    }
    
    // 크레딧 항목 삭제
    $delete_query = "DELETE FROM credit_history WHERE credit_id = ?";
    $stmt = $db->prepare($delete_query);
    $stmt->bind_param('i', $credit_id);
    $stmt->execute();
    
    if ($stmt->affected_rows === 0) {
        throw new Exception('크레딧 항목 삭제에 실패했습니다.');
    }
    
    // 로그 기록
    $log_query = "
        INSERT INTO activity_logs 
        (log_type, log_action, log_description, staff_id, related_id, table_name)
        VALUES ('credit', 'delete', ?, ?, ?, 'credit_history')
    ";
    $log_description = "크레딧 항목 삭제: " . $credit['credit_description'] . " (" . $credit['credit_amount'] . "원)";
    $stmt = $db->prepare($log_query);
    $stmt->bind_param('siis', $log_description, $staff_id, $credit_id, $credit_id);
    $stmt->execute();
    
    // 트랜잭션 커밋
    $db->commit();
    
    echo json_encode([
        'success' => true,
        'message' => '크레딧 항목이 삭제되었습니다.'
    ]);
    
} catch (Exception $e) {
    // 오류 발생시 롤백
    $db->rollback();
    
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}

// DB 연결 종료
$db->close();
?> 