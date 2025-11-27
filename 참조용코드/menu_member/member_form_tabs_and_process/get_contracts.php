<?php
// 에러 보고 설정
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

// 디버깅용 로그
error_log("get_contracts.php 실행 시작");

// 데이터베이스 연결
require_once '../../config/db_connect.php';

// 헤더 설정
header('Content-Type: application/json');

// POST 요청 확인
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    error_log("잘못된 요청 방식: " . $_SERVER['REQUEST_METHOD']);
    echo json_encode(['success' => false, 'message' => '잘못된 요청 방식입니다.']);
    exit;
}

// member_id 확인
if (!isset($_POST['member_id']) || empty($_POST['member_id'])) {
    error_log("member_id가 누락됨");
    echo json_encode(['success' => false, 'message' => '회원 ID가 필요합니다.']);
    exit;
}

// member_id 가져오기
$member_id = intval($_POST['member_id']);
error_log("member_id: " . $member_id);

try {
    // 계약 내역 조회
    $contracts_query = "
        SELECT 
            ch.contract_history_id,
            ch.contract_date,
            ch.actual_price,
            ch.actual_credit,
            ch.payment_type,
            c.contract_type,
            c.contract_name,
            c.contract_LS,
            ch.contract_history_status
        FROM contract_history ch
        JOIN contracts c ON ch.contract_id = c.contract_id
        WHERE ch.member_id = ?
        ORDER BY ch.contract_date DESC
    ";
    
    $stmt = $db->prepare($contracts_query);
    $stmt->bind_param('i', $member_id);
    $stmt->execute();
    $contracts_result = $stmt->get_result();
    
    // 계약 요약 정보 조회
    $summary_query = "
        SELECT 
            COUNT(*) as contract_count,
            SUM(CASE WHEN COALESCE(ch.contract_history_status, '') != '삭제' THEN ch.actual_price ELSE 0 END) as total_price,
            SUM(CASE WHEN COALESCE(ch.contract_history_status, '') != '삭제' THEN ch.actual_credit ELSE 0 END) as total_credit,
            SUM(CASE WHEN COALESCE(ch.contract_history_status, '') != '삭제' THEN c.contract_LS ELSE 0 END) as total_ls
        FROM contract_history ch
        JOIN contracts c ON ch.contract_id = c.contract_id
        WHERE ch.member_id = ?
    ";
    
    $stmt = $db->prepare($summary_query);
    $stmt->bind_param('i', $member_id);
    $stmt->execute();
    $summary_result = $stmt->get_result();
    $summary = $summary_result->fetch_assoc();
    
    // 계약 내역 데이터 변환
    $contracts = [];
    while ($contract = $contracts_result->fetch_assoc()) {
        // 계약 상태 확인 (삭제 여부)
        $is_deleted = $contract['contract_history_status'] === '삭제';
        
        // 결제 방법 텍스트 변환
        $payment_method = str_replace('결제', '', $contract['payment_type']);
        
        // 날짜 형식 변환
        $contract_date = date('Y-m-d', strtotime($contract['contract_date']));
        
        // 계약 종료일 (계약일 + 1년)
        $end_date = date('Y-m-d', strtotime($contract_date . ' + 1 year'));
        
        $contracts[] = [
            'id' => $contract['contract_history_id'],
            'contract_name' => $contract['contract_name'],
            'contract_type' => $contract['contract_type'],
            'start_date' => $contract_date,
            'end_date' => $end_date,
            'total_amount' => (int)$contract['actual_price'],
            'credit_amount' => (int)$contract['actual_credit'],
            'payment_method' => $payment_method,
            'is_deleted' => $is_deleted
        ];
    }
    
    // 요약 정보 변환
    $summary_data = [
        'total_contracts' => (int)$summary['contract_count'],
        'total_revenue' => (int)$summary['total_price'],
        'total_credit' => (int)$summary['total_credit'],
        'active_contracts' => 0,  // 삭제되지 않은 계약 수 계산
        'total_ls' => (int)$summary['total_ls']
    ];
    
    // 활성 계약 수 계산
    foreach ($contracts as $contract) {
        if (!$contract['is_deleted']) {
            $summary_data['active_contracts']++;
        }
    }
    
    // 성공 응답
    $response = [
        'success' => true,
        'contracts' => $contracts,
        'summary' => $summary_data
    ];
    
    error_log("응답 데이터: " . json_encode($response));
    echo json_encode($response);
    
} catch (Exception $e) {
    error_log("오류 발생: " . $e->getMessage());
    echo json_encode([
        'success' => false,
        'message' => '계약 정보를 불러오는 중 오류가 발생했습니다: ' . $e->getMessage()
    ]);
}

error_log("get_contracts.php 실행 종료");
?> 