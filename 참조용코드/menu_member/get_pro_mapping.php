<?php
// 에러 표시 설정
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

require_once '../config/db_connect.php';

header('Content-Type: application/json');

// 요청 정보 로깅
error_log("GET 요청: " . print_r($_GET, true));

$response = ['success' => false];

if (isset($_GET['member_id'])) {
    $member_id = $_GET['member_id'];
    $junior_id = isset($_GET['junior_id']) ? $_GET['junior_id'] : null;
    
    error_log("프로 매핑 정보 조회 - member_id: $member_id, junior_id: " . ($junior_id ?? 'NULL'));
    
    // 주어진 회원 또는 주니어의 모든 유효한 프로 매핑 조회
    $query = "SELECT * FROM member_pro_match WHERE member_id = ? AND relation_status = '유효'";
    $params = [$member_id];
    
    if ($junior_id) {
        $query .= " AND junior_id = ?";
        $params[] = $junior_id;
    } else {
        $query .= " AND (junior_id IS NULL OR junior_id = 0)";
    }
    
    error_log("SQL 쿼리: $query");
    error_log("파라미터: " . print_r($params, true));
    
    try {
        $stmt = $db->prepare($query);
        if (count($params) > 1) {
            $stmt->bind_param('ii', $params[0], $params[1]);
        } else {
            $stmt->bind_param('i', $params[0]);
        }
        $stmt->execute();
        $result = $stmt->get_result();
        
        $mappings = $result->fetch_all(MYSQLI_ASSOC);
        error_log("조회된 매핑 수: " . count($mappings));
        error_log("매핑 데이터: " . print_r($mappings, true));
        
        $has_multiple_pros = count($mappings) > 1;
        
        if (!empty($mappings)) {
            $response['success'] = true;
            $response['current_mapping'] = $mappings[0]; // 첫 번째 매핑을 기본으로 반환
            $response['all_mappings'] = $mappings; // 모든 매핑 정보 반환
            $response['has_multiple_pros'] = $has_multiple_pros; // 복수 프로 여부
        } else {
            $response['success'] = true;
            $response['current_mapping'] = null;
            $response['all_mappings'] = [];
            $response['has_multiple_pros'] = false;
        }
    } catch (Exception $e) {
        error_log("데이터베이스 오류: " . $e->getMessage());
        $response['error'] = $e->getMessage();
    }
}

error_log("응답 데이터: " . json_encode($response));
echo json_encode($response);
?> 