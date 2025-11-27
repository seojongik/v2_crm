<?php
require_once '../config/db_connect.php';

// 응답 헤더 설정 - JSON 형식으로 반환
header('Content-Type: application/json');

// 응답 데이터 초기화
$response = [
    'success' => false,
    'message' => '처리 중 오류가 발생했습니다.',
    'member_id' => null
];

// 전화번호에서 하이픈 제거
function stripPhoneNumber($number) {
    return preg_replace('/[^0-9]/', '', $number);
}

// 전화번호 중복 체크 함수
function isPhoneNumberExists($db, $phone, $current_id = null) {
    $stripped_phone = stripPhoneNumber($phone);
    
    $query = 'SELECT member_id, member_phone FROM members';
    if ($current_id) {
        $query .= ' WHERE member_id != ?';
    }
    
    $stmt = $db->prepare($query);
    if ($current_id) {
        $stmt->bind_param('i', $current_id);
    }
    
    $stmt->execute();
    $result = $stmt->get_result();
    
    while ($row = $result->fetch_assoc()) {
        if (stripPhoneNumber($row['member_phone']) === $stripped_phone) {
            return true;
        }
    }
    
    return false;
}

// 전화번호 형식 통일화
function formatPhoneNumber($number) {
    $number = preg_replace('/[^0-9]/', '', $number);
    if (strlen($number) === 11) {
        return preg_replace('/(\d{3})(\d{4})(\d{4})/', '$1-$2-$3', $number);
    } else if (strlen($number) === 10) {
        return preg_replace('/(\d{3})(\d{3})(\d{4})/', '$1-$2-$3', $number);
    }
    return $number;
}

// Ajax 요청 여부 확인
function isAjaxRequest() {
    return (!empty($_SERVER['HTTP_X_REQUESTED_WITH']) && 
            strtolower($_SERVER['HTTP_X_REQUESTED_WITH']) == 'xmlhttprequest') || 
           isset($_SERVER['HTTP_ACCEPT']) && strpos($_SERVER['HTTP_ACCEPT'], 'application/json') !== false;
}

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $id = $_POST['id'] ?? null;
    $phone = $_POST['member_phone'] ?? '';
    
    if (isPhoneNumberExists($db, $phone, $id)) {
        if (isAjaxRequest()) {
            $response['message'] = '이미 등록된 전화번호입니다.';
            echo json_encode($response);
            exit;
        } else {
            echo "<script>
                alert('이미 등록된 전화번호입니다.');
                history.back();
            </script>";
            exit;
        }
    }

    $formatted_phone = formatPhoneNumber($phone);
    $birthday = !empty($_POST['member_birthday']) ? $_POST['member_birthday'] : null;

    if (isset($_POST['id'])) {
        $stmt = $db->prepare('UPDATE members SET 
            member_name = ?,
            member_phone = ?,
            member_nickname = ?,
            member_gender = ?,
            member_address = ?,
            member_birthday = ?,
            member_chn_keyword = ?
            WHERE member_id = ?');
        $stmt->bind_param('sssssssi', 
            $_POST['member_name'],
            $formatted_phone,
            $_POST['member_nickname'],
            $_POST['member_gender'],
            $_POST['member_address'],
            $birthday,
            $_POST['member_chn_keyword'],
            $id
        );
    } else {  // 신규 등록
        $stmt = $db->prepare('INSERT INTO members 
            (member_name, member_phone, member_nickname, member_gender, 
             member_address, member_birthday, member_chn_keyword, member_register) 
            VALUES (?, ?, ?, ?, ?, ?, ?, NOW())');
        $stmt->bind_param('sssssss', 
            $_POST['member_name'],
            $formatted_phone,
            $_POST['member_nickname'],
            $_POST['member_gender'],
            $_POST['member_address'],
            $birthday,
            $_POST['member_chn_keyword']
        );
    }

    try {
        $stmt->execute();
        
        if (!$id) {
            // 신규 등록인 경우 생성된 ID 가져오기
            $new_id = $db->insert_id;
            $response['member_id'] = $new_id;
        } else {
            $response['member_id'] = $id;
        }
        
        $response['success'] = true;
        $response['message'] = '회원 정보가 성공적으로 저장되었습니다.';
        
        // 항상 JSON 응답만 반환
        echo json_encode($response);
        exit;
    } catch (Exception $e) {
        $response['message'] = '오류가 발생했습니다: ' . $e->getMessage();
        
        // 항상 JSON 응답만 반환
        echo json_encode($response);
        exit;
    }
} 