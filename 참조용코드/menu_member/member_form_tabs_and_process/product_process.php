<?php
require_once dirname(__FILE__) . '/../../config/db_connect.php';

header('Content-Type: application/json');

try {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        throw new Exception('잘못된 요청 방식입니다.');
    }

    $member_id = $_POST['member_id'] ?? null;
    $product_id = $_POST['product_id'] ?? null;
    $quantity = intval($_POST['quantity'] ?? 1);
    $payment_type = $_POST['payment_type'] ?? null;
    $purchase_date = $_POST['purchase_date'] ?? date('Y-m-d');

    if (!$member_id || !$product_id || !$payment_type) {
        throw new Exception('필수 입력값이 누락되었습니다.');
    }

    // 상품 정보 조회
    $stmt = $db->prepare("
        SELECT * FROM contracts 
        WHERE contract_id = ? 
        AND contract_status = '유효'
        AND contract_category = '판매상품'
    ");
    $stmt->bind_param('s', $product_id);
    $stmt->execute();
    $product = $stmt->get_result()->fetch_assoc();

    if (!$product) {
        throw new Exception('유효하지 않은 상품입니다.');
    }

    // 회원의 최근 크레딧 잔액 조회
    $stmt = $db->prepare("
        SELECT b.bill_balance_after as credit_balance
        FROM bills b
        WHERE b.member_id = ?
        AND (b.bill_status IS NULL OR b.bill_status != '삭제')
        ORDER BY b.bill_id DESC
        LIMIT 1
    ");
    $stmt->bind_param('i', $member_id);
    $stmt->execute();
    $member = $stmt->get_result()->fetch_assoc();

    if (!$member) {
        // 거래 내역이 없는 경우 잔액을 0으로 설정
        $member = ['credit_balance' => 0];
    }

    $db->begin_transaction();

    try {
        // bills 테이블에 기록
        $stmt = $db->prepare("
            INSERT INTO bills (
                member_id,
                bill_date,
                bill_type,
                bill_text,
                bill_totalamt,
                bill_deduction,
                bill_netamt,
                bill_balance_before,
                bill_balance_after
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ");

        $bill_type = '상품구매';
        $bill_text = $product['contract_name'] . ' x ' . $quantity;
        $actual_price = $product['price'] * $quantity;
        
        if ($payment_type === '크레딧결제') {
            $actual_credit = $product['sell_by_credit_price'] * $quantity;
            
            // 크레딧 잔액 확인
            if ($member['credit_balance'] < $actual_credit) {
                throw new Exception('크레딧 잔액이 부족합니다.');
            }

            $bill_totalamt = $actual_credit;
            $bill_deduction = 0;
            $bill_netamt = -$actual_credit; // 음수로 저장 (차감)
            $bill_balance_before = $member['credit_balance'];
            $bill_balance_after = $member['credit_balance'] - $actual_credit;
        } else {
            // 카드결제나 현금결제의 경우
            $bill_totalamt = $actual_price;
            $bill_deduction = 0;
            $bill_netamt = 0; // 잔액 변동 없음
            $bill_balance_before = $member['credit_balance'];
            $bill_balance_after = $member['credit_balance']; // 잔액 유지
        }

        $stmt->bind_param(
            'isssddddd',
            $member_id,
            $purchase_date,
            $bill_type,
            $bill_text,
            $bill_totalamt,
            $bill_deduction,
            $bill_netamt,
            $bill_balance_before,
            $bill_balance_after
        );
        
        $stmt->execute();

        $db->commit();
        echo json_encode([
            'success' => true,
            'member_id' => $member_id,
            'message' => '상품 구매가 완료되었습니다.'
        ]);

    } catch (Exception $e) {
        $db->rollback();
        throw $e;
    }

} catch (Exception $e) {
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}
?> 