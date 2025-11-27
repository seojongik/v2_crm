<?php
require_once '../../config/db_connect.php';
error_reporting(E_ALL);
ini_set('display_errors', 1);

header('Content-Type: application/json');

try {
    $month = isset($_POST['month']) ? $_POST['month'] : date('Y-m');
    // 입력받은 달의 이전 달을 계산
    $target_month = date('Y-m', strtotime($month . '-01 -1 month'));
    // 대상 기간 설정 (이전 달의 첫날부터 마지막 날까지)
    $start_date = date('Y-m-01', strtotime($target_month));
    $end_date = date('Y-m-t', strtotime($target_month));
    
    // 크레딧 부족 체크 여부
    $check_balance = isset($_POST['check_balance']) && $_POST['check_balance'] == 1;
    
    // 해당 월의 수시 정산에 포함된 락커 ID들을 가져옴
    $temp_bill_query = "
        SELECT DISTINCT locker_id 
        FROM Locker_bill 
        WHERE locker_bill_month = ? 
        AND locker_bill_type = '수시'
    ";
    
    $temp_stmt = $db->prepare($temp_bill_query);
    if (!$temp_stmt) {
        throw new Exception("Failed to prepare temporary bills query: " . $db->error);
    }
    
    $temp_stmt->bind_param('s', $month);
    $temp_stmt->execute();
    $temp_result = $temp_stmt->get_result();
    
    $excluded_lockers = [];
    while ($row = $temp_result->fetch_assoc()) {
        $excluded_lockers[] = $row['locker_id'];
    }
    
    // 수시 정산에 포함되지 않은 락커들의 정보와 지난 달 이용시간 합계를 가져옴
    $query = "
        SELECT 
            l.*,
            m.member_name,
            IFNULL(p.total_usage_minutes, 0) as last_month_usage
        FROM Locker_status l
        LEFT JOIN members m ON l.member_id = m.member_id
        LEFT JOIN (
            SELECT 
                member_id,
                SUM(ts_min) as total_usage_minutes
            FROM Priced_FMS
            WHERE ts_date BETWEEN ? AND ?
            AND net_amt != -1
            GROUP BY member_id
        ) p ON l.member_id = p.member_id
        WHERE l.member_id IS NOT NULL " .
        (count($excluded_lockers) > 0 ? "AND l.locker_id NOT IN (" . implode(',', $excluded_lockers) . ")" : "") . "
        ORDER BY l.locker_id ASC
    ";
    
    $stmt = $db->prepare($query);
    if (!$stmt) {
        throw new Exception("Failed to prepare main query: " . $db->error);
    }
    
    $stmt->bind_param('ss', $start_date, $end_date);
    $stmt->execute();
    $result = $stmt->get_result();
    
    $lockers = [];
    while ($row = $result->fetch_assoc()) {
        // 할인 적용 여부 확인
        $usageMinutes = intval($row['last_month_usage']);
        $discountCondition = intval($row['locker_discount_condition_min']);
        $meetsDiscountCondition = $usageMinutes >= $discountCondition;
        
        $locker_data = [
            'locker_id' => $row['locker_id'],
            'member_id' => $row['member_id'],
            'member_name' => $row['member_name'],
            'locker_usage_minutes' => $usageMinutes,
            'locker_discount_condition_min' => $discountCondition,
            'locker_discount_ratio' => $meetsDiscountCondition ? $row['locker_discount_ratio'] : 0,
            'locker_price' => $row['locker_price'],
            'locker_remark' => $row['locker_remark']
        ];
        
        // 최신 bill_balance_after 조회 (check_balance=1 일 경우에만)
        if ($check_balance && $row['member_id']) {
            $balance_query = "
                SELECT bill_balance_after 
                FROM bills 
                WHERE member_id = ? 
                ORDER BY bill_id DESC 
                LIMIT 1
            ";
            $balance_stmt = $db->prepare($balance_query);
            if ($balance_stmt) {
                $member_id = $row['member_id'];
                $balance_stmt->bind_param('i', $member_id);
                $balance_stmt->execute();
                $balance_result = $balance_stmt->get_result();
                if ($balance_row = $balance_result->fetch_assoc()) {
                    $locker_data['bill_balance_after'] = $balance_row['bill_balance_after'];
                }
                $balance_stmt->close();
            }
        }
        
        $lockers[] = $locker_data;
    }
    
    echo json_encode([
        'success' => true,
        'lockers' => $lockers,
        'month' => $month,
        'period' => [
            'start' => $start_date,
            'end' => $end_date
        ]
    ]);
    
} catch (Exception $e) {
    error_log("Error in get_regular_bill_candidates.php: " . $e->getMessage());
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}
?> 