<?php
session_start();
require_once '../config/db_connect.php';

// 응답 형식 설정
header('Content-Type: application/json');

// 로그인 체크
if (!isset($_SESSION['staff_id'])) {
    echo json_encode(['success' => false, 'message' => '로그인이 필요합니다.']);
    exit;
}

// POST 요청 확인
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    echo json_encode(['success' => false, 'message' => '잘못된 요청 방식입니다.']);
    exit;
}

// 필수 파라미터 확인
if (!isset($_POST['source_locker_id']) || !isset($_POST['target_locker_id']) || !isset($_POST['member_id'])) {
    echo json_encode(['success' => false, 'message' => '필수 정보가 누락되었습니다.']);
    exit;
}

$source_locker_id = intval($_POST['source_locker_id']);
$target_locker_id = intval($_POST['target_locker_id']);
$member_id = intval($_POST['member_id']);
$staff_id = $_SESSION['staff_id'];
$current_time = date('Y-m-d H:i:s');
$current_date = date('Y-m-d');

try {
    // 트랜잭션 시작
    $db->begin_transaction();

    // 1. 소스 락커에서 회원 정보 조회
    $select_query = "
        SELECT 
            ls.locker_discount_condition_min,
            ls.locker_discount_ratio,
            ls.locker_start_date,
            ls.locker_remark,
            ls.locker_price AS source_price,
            m.member_name
        FROM 
            Locker_status ls
        JOIN
            members m ON ls.member_id = m.member_id
        WHERE 
            ls.locker_id = ? AND ls.member_id = ?
    ";
    
    $stmt = $db->prepare($select_query);
    $stmt->bind_param('ii', $source_locker_id, $member_id);
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($result->num_rows === 0) {
        throw new Exception('소스 락커에서 회원 정보를 찾을 수 없습니다.');
    }
    
    $locker_info = $result->fetch_assoc();
    
    // 2. 타겟 락커 정보 및 가격 조회
    $target_query = "
        SELECT locker_price, locker_type, locker_zone
        FROM Locker_status
        WHERE locker_id = ?
    ";
    
    $stmt = $db->prepare($target_query);
    $stmt->bind_param('i', $target_locker_id);
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($result->num_rows === 0) {
        throw new Exception('대상 락커 정보를 찾을 수 없습니다.');
    }
    
    $target_info = $result->fetch_assoc();
    
    // 3. 타겟 락커에 회원이 배정되어 있는지 확인
    $check_query = "
        SELECT member_id
        FROM Locker_status
        WHERE locker_id = ? AND member_id IS NOT NULL
    ";
    
    $stmt = $db->prepare($check_query);
    $stmt->bind_param('i', $target_locker_id);
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($result->num_rows > 0) {
        throw new Exception('대상 락커에 이미 회원이 배정되어 있습니다.');
    }
    
    // 4. 소스 락커 회원 정보 삭제
    $update_source_query = "
        UPDATE Locker_status 
        SET 
            member_id = NULL,
            locker_discount_condition_min = NULL,
            locker_discount_ratio = NULL,
            registered_at = ?,
            locker_start_date = NULL,
            locker_remark = NULL,
            staff_id = ?
        WHERE locker_id = ?
    ";
    
    $stmt = $db->prepare($update_source_query);
    $stmt->bind_param('sis', $current_time, $staff_id, $source_locker_id);
    $stmt->execute();
    
    if ($stmt->affected_rows === 0) {
        throw new Exception('소스 락커 정보 업데이트에 실패했습니다.');
    }
    
    // 5. 타겟 락커에 회원 정보 이동
    $update_target_query = "
        UPDATE Locker_status 
        SET 
            member_id = ?,
            locker_discount_condition_min = ?,
            locker_discount_ratio = ?,
            registered_at = ?,
            locker_start_date = ?,
            locker_remark = ?,
            staff_id = ?
        WHERE locker_id = ?
    ";
    
    $stmt = $db->prepare($update_target_query);
    $stmt->bind_param(
        'iidsssii', 
        $member_id, 
        $locker_info['locker_discount_condition_min'], 
        $locker_info['locker_discount_ratio'],
        $current_time,
        $locker_info['locker_start_date'],
        $locker_info['locker_remark'],
        $staff_id,
        $target_locker_id
    );
    $stmt->execute();
    
    if ($stmt->affected_rows === 0) {
        throw new Exception('타겟 락커 정보 업데이트에 실패했습니다.');
    }
    
    // 6. 가격 차액이 있는 경우 과금 처리
    $source_price = floatval($locker_info['source_price']);
    $target_price = floatval($target_info['locker_price']);
    
    if ($target_price > $source_price) {
        // 가격 차액 계산
        $price_diff = $target_price - $source_price;
        
        // 현재 월의 총 일수 계산
        $days_in_month = cal_days_in_month(CAL_GREGORIAN, date('m'), date('Y'));
        
        // 현재 일부터 월말까지 남은 일수 계산
        $days_remaining = $days_in_month - date('j') + 1;
        
        // 차액의 일할 계산 (남은 일수에 대한 금액)
        $prorated_amount = round($price_diff * ($days_remaining / $days_in_month));
        
        // 할인 조건 확인 및 할인 적용
        $discount_ratio = floatval($locker_info['locker_discount_ratio']);
        $discount_amount = 0;
        $final_amount = -$prorated_amount; // 과금은 음수로 저장
        
        // 할인이 적용되는 경우
        if ($discount_ratio > 0) {
            $discount_amount = round($prorated_amount * $discount_ratio);
            $final_amount = -($prorated_amount - $discount_amount);
        }

        // Locker_bill 테이블에 과금 기록 추가
        $bill_remark = "락커 이동: #{$source_locker_id}({$source_price}c) → #{$target_locker_id}({$target_price}c), 차액: {$price_diff}c, 일할계산: {$days_remaining}/{$days_in_month}일";
        
        $insert_locker_bill = "
            INSERT INTO Locker_bill (
                locker_id, 
                member_id, 
                locker_bill_amount, 
                locker_discount_amount, 
                locker_bill_type, 
                locker_bill_month,
                bill_date,
                staff_id,
                bill_remark
            ) VALUES (?, ?, ?, ?, '수시', DATE_FORMAT(NOW(), '%Y-%m'), ?, ?, ?)
        ";
        
        $stmt = $db->prepare($insert_locker_bill);
        $bill_type = '수시';
        $stmt->bind_param(
            'iiiisss',
            $target_locker_id,
            $member_id,
            $final_amount,
            $discount_amount,
            $current_date,
            $staff_id,
            $bill_remark
        );
        $stmt->execute();
        
        if ($stmt->affected_rows === 0) {
            throw new Exception('락커 과금 기록 추가에 실패했습니다.');
        }
        
        $locker_bill_id = $db->insert_id;
        
        // bills 테이블에 과금 기록 추가
        $insert_bill = "
            INSERT INTO bills (
                member_id,
                bill_category,
                bill_amount,
                bill_date,
                staff_id,
                bill_remark,
                locker_bill_id
            ) VALUES (?, 'LOCKER', ?, ?, ?, ?, ?)
        ";
        
        $stmt = $db->prepare($insert_bill);
        $stmt->bind_param(
            'iissis',
            $member_id,
            $final_amount,
            $current_date,
            $staff_id,
            $bill_remark,
            $locker_bill_id
        );
        $stmt->execute();
        
        if ($stmt->affected_rows === 0) {
            throw new Exception('과금 기록 추가에 실패했습니다.');
        }
    }
    
    // 커밋
    $db->commit();
    
    echo json_encode(['success' => true]);
} catch (Exception $e) {
    // 롤백
    $db->rollback();
    echo json_encode(['success' => false, 'message' => $e->getMessage()]);
}
?> 