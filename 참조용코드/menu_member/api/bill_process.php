<?php
require_once '../../config/db_connect.php';
session_start();

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $member_id = $_POST['member_id'] ?? null;
    $bill_type = $_POST['bill_type'] ?? null;
    $bill_text = $_POST['bill_text'] ?? null;
    $bill_totalamt = $_POST['bill_totalamt'] ?? 0;
    $bill_deduction = $_POST['bill_deduction'] ?? 0;
    $bill_netamt = $_POST['bill_netamt'] ?? 0;
    $bill_balance_before = $_POST['bill_balance_before'] ?? 0;
    $bill_balance_after = $_POST['bill_balance_after'] ?? 0;
    $bill_date = date('Y-m-d');  // 오늘 날짜

    // 디버그: POST 데이터 확인
    error_log('Bill Type: ' . $bill_type);

    // 필수 값 체크
    if (!$member_id || !$bill_type || !$bill_text || !$bill_totalamt || !$bill_netamt) {
        $_SESSION['error'] = '필수 정보가 누락되었습니다.';
        header('Location: ' . $_SERVER['HTTP_REFERER']);
        exit;
    }

    try {
        // bills 테이블에 데이터 삽입
        $stmt = $db->prepare("
            INSERT INTO bills (
                member_id, 
                bill_date,
                bill_type, 
                bill_text, 
                bill_totalamt, 
                bill_deduction, 
                bill_netamt,
                bill_timestamp,
                bill_balance_before,
                bill_balance_after
            ) VALUES (
                ?, 
                ?, 
                ?, 
                ?, 
                ?, 
                ?, 
                ?,
                NOW(),
                ?,
                ?
            )
        ");

        $stmt->bind_param('isssiiiii', 
            $member_id,
            $bill_date,
            $bill_type,
            $bill_text,
            $bill_totalamt,
            $bill_deduction,
            $bill_netamt,
            $bill_balance_before,
            $bill_balance_after
        );

        if ($stmt->execute()) {
            $_SESSION['success'] = '차감이 정상적으로 처리되었습니다.';
        } else {
            $_SESSION['error'] = '처리 중 오류가 발생했습니다.';
        }

        // 현재 잔액 조회
        $stmt = $db->prepare("
            SELECT bill_balance_after 
            FROM bills 
            WHERE member_id = ? 
            ORDER BY bill_id DESC 
            LIMIT 1
        ");
        $stmt->bind_param('i', $member_id);
        $stmt->execute();
        $result = $stmt->get_result();
        $current_balance = $result->fetch_assoc()['bill_balance_after'] ?? 0;

        // 새로운 잔액 계산
        $new_balance = $current_balance - $bill_netamt;

    } catch (Exception $e) {
        $_SESSION['error'] = '데이터베이스 오류: ' . $e->getMessage();
    }

    // 크레딧 탭이 선택된 상태로 리다이렉트
    header('Location: ../../member/ui/member_form.php?id=' . $member_id . '&tab=checkin');
    exit;
}

// POST 요청이 아닌 경우 목록 페이지로 리다이렉트
header('Location: ../../../member/member_list.php');
exit; 