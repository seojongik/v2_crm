<?php
// 에러 표시 설정
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

require_once '../../config/db_connect.php';
// 문자셋 설정
$db->set_charset("utf8mb4");

// 디버깅 함수 추가
function debug_query($query, $params = null) {
    error_log("실행할 쿼리: " . $query);
    if ($params) {
        error_log("파라미터: " . print_r($params, true));
    }
}

session_start();

// PHP 시간대 설정
date_default_timezone_set('Asia/Seoul');

// 실제 데이터 기준으로 다음 ID 가져오기
function getNextId($db, $table, $id_column) {
    // contract_history와 bills 테이블은 상태와 관계없이 최대값 찾기
    if ($table === 'contract_history' || $table === 'bills') {
        $query = "SELECT MAX($id_column) as max_id FROM $table";
    }
    // 그 외의 테이블인 경우
    else {
        $query = "SELECT MAX($id_column) as max_id FROM $table";
    }
    
    $result = $db->query($query);
    $row = $result->fetch_assoc();
    return ($row['max_id'] ?? 0) + 1;
}

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    // 응답 헤더 설정
    header('Content-Type: application/json');

    $member_id = $_POST['member_id'];
    $contract_id = $_POST['contract_id'];
    $contract_date = $_POST['contract_date'];
    $payment_type = $_POST['payment_type'];

    // 자유적립 크레딧(c01)인 경우 최소 금액 검사
    if ($contract_id === 'c01' && isset($_POST['contract_credit'])) {
        $credit_amount = intval($_POST['contract_credit']);
        if ($credit_amount < 200000) {
            echo json_encode([
                'success' => false, 
                'message' => '자유적립 크레딧은 최소 200,000 이상 입력해야 합니다.'
            ]);
            exit;
        }
    }

    // contract_id 유효성 검사 및 계약 정보 조회
    $check_stmt = $db->prepare('SELECT * FROM contracts WHERE contract_id = ?');
    $check_stmt->bind_param('s', $contract_id);
    $check_stmt->execute();
    $result = $check_stmt->get_result();
    $contract = $result->fetch_assoc();
    
    if (!$contract) {
        echo json_encode(['success' => false, 'message' => '유효하지 않은 계약입니다.']);
        exit;
    }

    // 크레딧 결제인 경우 잔액 확인
    if ($payment_type === '크레딧결제') {
        // 현재 회원의 마지막 bill_balance_after 조회
        $balance_stmt = $db->prepare('
            SELECT bill_balance_after 
            FROM bills 
            WHERE member_id = ? 
            ORDER BY bill_id DESC 
            LIMIT 1
        ');
        $balance_stmt->bind_param('i', $member_id);
        $balance_stmt->execute();
        $balance_result = $balance_stmt->get_result();
        $last_balance = $balance_result->fetch_assoc();
        
        $current_balance = $last_balance ? $last_balance['bill_balance_after'] : 0;
        
        // 크레딧 잔액이 부족한 경우
        if ($current_balance < $contract['sell_by_credit_price']) {
            $formatted_balance = number_format($current_balance);
            $formatted_price = number_format($contract['sell_by_credit_price']);
            echo json_encode([
                'success' => false, 
                'message' => "크레딧 잔액이 부족합니다.",
                'currentBalance' => $formatted_balance,
                'requiredAmount' => $formatted_price
            ]);
            exit;
        }
    }

    // 트랜잭션 시작
    $db->begin_transaction();

    try {
        // 계약 정보 디버깅
        error_log('Contract Info: ' . print_r($contract, true));
        error_log('Contract Type: ' . $contract['contract_type']);
        
        // POST 데이터 로깅
        error_log('POST data: ' . print_r($_POST, true));
        
        // 다음 contract_history_id 가져오기
        $next_contract_id = getNextId($db, 'contract_history', 'contract_history_id');
        error_log("다음 contract_history_id: " . $next_contract_id);
        
        if (isset($_POST['id'])) {  // 수정
            $contract_history_id = $_POST['id'];
            error_log("수정 모드: contract_history_id = " . $contract_history_id);
            $stmt = $db->prepare('
                UPDATE contract_history 
                SET contract_id = ?,
                    contract_date = ?,
                    payment_type = ?,
                    actual_price = ?,
                    contract_register = NOW()
                WHERE contract_history_id = ?
            ');
            debug_query("UPDATE 쿼리", [
                'contract_id' => $contract_id,
                'contract_date' => $contract_date,
                'payment_type' => $payment_type,
                'actual_price' => $contract['price'],
                'contract_history_id' => $contract_history_id
            ]);
            
            $stmt->bind_param('sssis', 
                $contract_id,
                $contract_date,
                $payment_type,
                $contract['price'],
                $contract_history_id
            );
        } else {  // 신규 등록
            // contract_register를 contract_date의 23:59:59로 설정
            $register_date = date('Y-m-d H:i:s', strtotime($contract_date . ' 23:59:59'));
            error_log("신규 등록 모드: register_date = " . $register_date);
            
            $stmt = $db->prepare("
                INSERT INTO contract_history (
                    contract_history_id,
                    member_id, 
                    contract_id, 
                    contract_date, 
                    payment_type,
                    actual_price,
                    actual_credit,
                    junior_id
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ");
            
            // INSERT 쿼리 디버깅
            debug_query("INSERT 쿼리", [
                'contract_history_id' => $next_contract_id,
                'member_id' => $member_id,
                'contract_id' => $contract_id,
                'contract_date' => $contract_date,
                'payment_type' => $payment_type
            ]);

            // 자유적립 크레딧(c01)인 경우 사용자 입력값 사용
            if ($contract_id === 'c01' && isset($_POST['contract_credit'])) {
                $actual_credit = intval($_POST['contract_credit']);
                $actual_price = $actual_credit; // 자유적립 크레딧의 경우 actual_price도 입력한 크레딧 값과 동일하게 설정
            } else {
                // 그 외의 경우 contracts 테이블의 값을 사용
                $actual_credit = $contract['contract_credit'];
                $actual_price = $contract['price'];
            }
            $junior_id = isset($_POST['junior_id']) ? $_POST['junior_id'] : null;

            error_log("바인딩할 파라미터: actual_credit = " . $actual_credit . ", actual_price = " . $actual_price);
            
            $stmt->bind_param(
                'iisssiii',
                $next_contract_id,
                $member_id,
                $contract_id,
                $contract_date,
                $payment_type,
                $actual_price,
                $actual_credit,
                $junior_id
            );
            
            // contract_history_id 설정
            $contract_history_id = $next_contract_id;
        }

        try {
            $stmt->execute();
            error_log("쿼리 실행 성공: 영향받은 행 수 = " . $stmt->affected_rows);
        } catch (Exception $e) {
            error_log("쿼리 실행 실패: " . $e->getMessage());
            throw $e;
        }

        // 레슨권, 패키지 또는 주니어 상품인 경우 LS_contracts 테이블 업데이트
        if ($contract['contract_type'] === '레슨권' || $contract['contract_type'] === '패키지' || $contract['contract_type'] === '주니어') {
            // 계약 종료일 계산
            $effect_month = $contract['effect_month'];
            $ls_contract_enddate = date('Y-m-d', strtotime($contract_date . " + {$effect_month} months"));
            // LS_expiry_date는 LS_contract_enddate와 동일하게 설정
            $ls_expiry_date = $ls_contract_enddate;
            
            // 레슨 회수 가져오기 - 주니어 상품인 경우 contract_junior_lesson 사용
            if ($contract['contract_type'] === '주니어') {
                $ls_contract_qty = $contract['contract_junior_lesson'];
            } else {
                $ls_contract_qty = $contract['contract_LS'];
            }
            
            // LS_contracts 테이블에 데이터 삽입
            $ls_stmt = $db->prepare("
                INSERT INTO LS_contracts (
                    LS_contract_id,
                    member_id,
                    member_name,
                    LS_contract_qty,
                    LS_contract_source,
                    LS_contract_date,
                    LS_contract_enddate,
                    LS_expiry_date,
                    updated_at,
                    staff_id,
                    LS_type,
                    junior_id,
                    contract_history_id
                ) VALUES (
                    ?, ?, ?, ?, ?, ?, ?, ?, NOW(), ?, ?, ?, ?
                )
            ");
            
            // 다음 LS_contract_id 가져오기
            $next_ls_contract_id = getNextId($db, 'LS_contracts', 'LS_contract_id');
            
            // 회원 이름 가져오기
            $member_stmt = $db->prepare("SELECT member_name FROM members WHERE member_id = ?");
            $member_stmt->bind_param('i', $member_id);
            $member_stmt->execute();
            $member_result = $member_stmt->get_result();
            $member_data = $member_result->fetch_assoc();
            $member_name = $member_data['member_name'];
            
            // 로그인한 스태프 ID 또는 'admin' 기본값 사용
            $staff_id = isset($_SESSION['staff_id']) ? $_SESSION['staff_id'] : 'admin';
            
            // LS_type 설정 (주니어 상품인 경우 '주니어', 그렇지 않으면 '일반')
            $ls_type = $contract['contract_type'] === '주니어' ? '주니어' : '일반';
            
            // junior_id 설정 (주니어 상품인 경우 junior_id, 그렇지 않으면 null)
            $junior_id_value = isset($_POST['junior_id']) ? $_POST['junior_id'] : null;
            
            // 문자열 리터럴을 변수로 변경
            $ls_contract_source = '레슨권구매'; // 일본어에서 한국어로 변경
            
            // bind_param 타입 문자열 수정 (s: 문자열, i: 정수, d: 부동소수점)
            $ls_stmt->bind_param(
                'iisdssssssii',
                $next_ls_contract_id,
                $member_id,
                $member_name,
                $ls_contract_qty,
                $ls_contract_source,
                $contract_date,
                $ls_contract_enddate,
                $ls_expiry_date,
                $staff_id,
                $ls_type,            // 문자열(s)로 바인딩
                $junior_id_value,
                $contract_history_id
            );
            
            $ls_stmt->execute();
            
            // LS_countings 테이블 업데이트 추가
            
            // LS_balance_before 값을 가져오기 위해 해당 회원의 동일한 LS_type의 가장 최근 레코드 조회
            $balance_query = "
                SELECT LS_balance_after 
                FROM LS_countings 
                WHERE member_id = ? 
                AND LS_type = ?
            ";
            
            if ($junior_id_value) {
                $balance_query .= " AND junior_id = ?";
                $params = [$member_id, $ls_type, $junior_id_value];
            } else {
                $balance_query .= " AND (junior_id IS NULL OR junior_id = 0)";
                $params = [$member_id, $ls_type];
            }
            
            $balance_query .= " ORDER BY LS_id DESC LIMIT 1";
            
            $ls_balance_stmt = $db->prepare($balance_query);
            
            if (count($params) > 2) {
                $ls_balance_stmt->bind_param('isi', $params[0], $params[1], $params[2]);
            } else {
                $ls_balance_stmt->bind_param('is', $params[0], $params[1]);
            }
            
            $ls_balance_stmt->execute();
            $ls_balance_result = $ls_balance_stmt->get_result();
            $last_ls_balance = $ls_balance_result->fetch_assoc();
            $ls_balance_before = $last_ls_balance ? $last_ls_balance['LS_balance_after'] : 0;
            
            // LS_balance_after 계산
            $ls_balance_after = $ls_balance_before + $ls_contract_qty;
            
            // LS_countings 테이블에 데이터 삽입
            $ls_counting_stmt = $db->prepare("
                INSERT INTO LS_countings (
                    LS_id,
                    member_id,
                    LS_contract_id,
                    member_name,
                    LS_balance_before,
                    LS_net_qty,
                    LS_balance_after,
                    LS_counting_source,
                    updated_at,
                    LS_type,
                    junior_id
                ) VALUES (
                    ?, ?, ?, ?, ?, ?, ?, 'LS_contracts', NOW(), ?, ?
                )
            ");
            
            // LS_id 생성: yymmdd + member_id 4자리 + 당일 시퀀스 2자리
            $today = date('ymd');
            $member_id_padded = str_pad($member_id, 4, '0', STR_PAD_LEFT);
            
            // 당일 해당 member_id의 시퀀스 조회
            $seq_query = "
                SELECT COUNT(*) as seq_count 
                FROM LS_countings 
                WHERE member_id = ? 
                AND DATE(updated_at) = CURDATE()
            ";
            $seq_stmt = $db->prepare($seq_query);
            $seq_stmt->bind_param('i', $member_id);
            $seq_stmt->execute();
            $seq_result = $seq_stmt->get_result();
            $seq_data = $seq_result->fetch_assoc();
            $sequence = $seq_data['seq_count'] + 1;
            $sequence_padded = str_pad($sequence, 2, '0', STR_PAD_LEFT);
            
            // 최종 LS_id 생성
            $ls_id = $today . $member_id_padded . $sequence_padded;
            
            $ls_counting_stmt->bind_param(
                'siisiiisi',
                $ls_id,
                $member_id,
                $next_ls_contract_id,
                $member_name,
                $ls_balance_before,
                $ls_contract_qty,
                $ls_balance_after,
                $ls_type,
                $junior_id_value
            );
            
            $ls_counting_stmt->execute();
            
            // 삽입 로깅
            error_log("Inserting LS_countings record: member_id = $member_id, LS_contract_id = $next_ls_contract_id, LS_type = $ls_type");
            if ($ls_counting_stmt->affected_rows > 0) {
                error_log("LS_countings insert successful");
            } else {
                error_log("LS_countings insert failed. Error: " . $db->error);
            }
        }

        // Term_member 테이블 업데이트 (기간권인 경우에만)
        if ($contract['contract_type'] === '기간권') {
            // term_enddate 계산
            $term_startdate = $contract_date;
            $term_enddate = date('Y-m-d', strtotime($term_startdate . ' + ' . $contract['effect_month'] . ' months'));
            
            // 다음 term_id 가져오기 (Auto Increment이지만 안전하게 다음 ID 확인)
            $next_term_id = getNextId($db, 'Term_member', 'term_id');
            
            // term_register 값을 현재 시간으로 설정
            $term_register = date('Y-m-d H:i:s');

            // contract_id에 따라 term_type 설정
            $term_type = '';
            $contract_num = intval(substr($contract_id, 1));
            if ($contract_num >= 1 && $contract_num <= 3) {
                $term_type = '전일권';
            } else if ($contract_num >= 4 && $contract_num <= 6) {
                $term_type = '평일권';
            } else if ($contract_num >= 7 && $contract_num <= 9) {
                $term_type = '조조권';
            }
            
            $term_stmt = $db->prepare("
                INSERT INTO Term_member (
                    term_id,
                    term_type,
                    term_period_month,
                    term_startdate,
                    term_enddate,
                    term_expirydate,
                    member_id,
                    term_register,
                    contract_id,
                    term_holdstart,
                    term_holdend
                ) VALUES (
                    ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL, NULL
                )
            ");

            $term_stmt->bind_param(
                'isisssiss',  // i=int, s=string
                $next_term_id,         // term_id (i)
                $term_type,            // term_type (s) - changed to use the determined term_type
                $contract['effect_month'],   // term_period_month (i)
                $term_startdate,       // term_startdate (s)
                $term_enddate,         // term_enddate (s)
                $term_enddate,         // term_expirydate (s)
                $member_id,            // member_id (i)
                $term_register,        // term_register (s)
                $contract_id           // contract_id (s)
            );
            
            $term_stmt->execute();
        }

        // 프로 매핑 처리 (레슨권, 패키지 또는 주니어 상품인 경우)
        if (($contract['contract_type'] === '레슨권' || $contract['contract_type'] === '패키지' || substr($contract_id, 0, 1) === 'j') && isset($_POST['pro_nickname'])) {
            $pro_nickname = $_POST['pro_nickname'];
            $junior_id = isset($_POST['junior_id']) ? $_POST['junior_id'] : null;
            $pro_change_type = isset($_POST['pro_change_type']) ? $_POST['pro_change_type'] : null;
            
            // 현재 매핑 확인
            $query = "SELECT * FROM member_pro_match WHERE member_id = ? AND relation_status = '유효'";
            $params = [$member_id];
            
            if ($junior_id) {
                $query .= " AND junior_id = ?";
                $params[] = $junior_id;
            } else {
                $query .= " AND (junior_id IS NULL OR junior_id = 0)";
            }
            
            $check_stmt = $db->prepare($query);
            if (count($params) > 1) {
                $check_stmt->bind_param('ii', $params[0], $params[1]);
            } else {
                $check_stmt->bind_param('i', $params[0]);
            }
            $check_stmt->execute();
            $result = $check_stmt->get_result();
            $current_mapping = $result->fetch_assoc();
            
            // 다음 relation_id 가져오기
            $next_relation_id = getNextId($db, 'member_pro_match', 'member_pro_relation_id');
            
            if ($current_mapping && $pro_change_type === 'change') {
                // 모든 기존 매핑을 만료로 변경
                $update_stmt = $db->prepare("
                    UPDATE member_pro_match 
                    SET relation_status = '만료' 
                    WHERE member_id = ? AND relation_status = '유효'
                ");
                
                if ($junior_id) {
                    $update_stmt = $db->prepare("
                        UPDATE member_pro_match 
                        SET relation_status = '만료' 
                        WHERE member_id = ? AND junior_id = ? AND relation_status = '유효'
                    ");
                    $update_stmt->bind_param('ii', $member_id, $junior_id);
                } else {
                    $update_stmt = $db->prepare("
                        UPDATE member_pro_match 
                        SET relation_status = '만료' 
                        WHERE member_id = ? AND (junior_id IS NULL OR junior_id = 0) AND relation_status = '유효'
                    ");
                    $update_stmt->bind_param('i', $member_id);
                }
                
                $update_stmt->execute();
                
                // 업데이트가 실행되었는지 확인하고 로그 남기기
                error_log("Updating all mappings to '만료' for member_id = $member_id" . ($junior_id ? ", junior_id = $junior_id" : ""));
                if ($update_stmt->affected_rows > 0) {
                    error_log("Update successful, affected rows: " . $update_stmt->affected_rows);
                } else {
                    error_log("Update failed or no changes made. Error: " . $db->error);
                }
            }
            
            // 새 매핑 생성 (기존 매핑이 없거나, 기존 매핑을 만료했거나, 다른 프로와 추가 매핑하는 경우)
            if (!$current_mapping || $pro_change_type === 'change' || $pro_change_type === 'add' || $current_mapping['staff_nickname'] !== $pro_nickname) {
                // 중요: junior_id가 있는 경우와 없는 경우에 대한 처리를 명확히 구분
                $insert_stmt = $db->prepare("
                    INSERT INTO member_pro_match (
                        member_pro_relation_id,
                        member_id,
                        junior_id,
                        staff_nickname,
                        registered_at,
                        relation_status
                    ) VALUES (?, ?, ?, ?, NOW(), '유효')
                ");
                
                if ($junior_id) {
                    $insert_stmt->bind_param('iiis', $next_relation_id, $member_id, $junior_id, $pro_nickname);
                } else {
                    // null 값을 binding할 때는 변수를 명시적으로 null로 설정
                    $null_junior_id = null;
                    $insert_stmt->bind_param('iiis', $next_relation_id, $member_id, $null_junior_id, $pro_nickname);
                }
                
                $insert_stmt->execute();
                
                // 삽입이 실행되었는지 확인하고 로그 남기기
                error_log("Inserting new mapping: member_id = $member_id, junior_id = " . ($junior_id ?? 'NULL') . ", staff_nickname = $pro_nickname");
                if ($insert_stmt->affected_rows > 0) {
                    error_log("Insert successful");
                } else {
                    error_log("Insert failed. Error: " . $db->error);
                }
            }
        }

        // bills 테이블 업데이트
        // 현재 회원의 마지막 bill_balance_after 조회
        $balance_stmt = $db->prepare('
            SELECT bill_balance_after 
            FROM bills 
            WHERE member_id = ? 
            ORDER BY bill_id DESC 
            LIMIT 1
        ');
        $balance_stmt->bind_param('i', $member_id);
        $balance_stmt->execute();
        $balance_result = $balance_stmt->get_result();
        $last_balance = $balance_result->fetch_assoc();
        $current_balance = $last_balance ? $last_balance['bill_balance_after'] : 0;

        // bills 테이블에 기록할 내역들을 배열로 준비
        $bill_entries = [];

        if ($payment_type === '크레딧결제') {
            // 1. 크레딧 결제 차감 내역
            $bill_entries[] = [
                'bill_type' => "회원권구매",
                'bill_balance_before' => $current_balance,
                'bill_netamt' => -$contract['sell_by_credit_price'],
                'bill_balance_after' => $current_balance - $contract['sell_by_credit_price'],
                'contract_history_id' => $contract_history_id
            ];
            
            // 현재 잔액 업데이트
            $current_balance -= $contract['sell_by_credit_price'];

            // 2. 크레딧 적립 내역 추가
            // 자유적립 크레딧(c01)인 경우 사용자 입력값 사용
            if ($contract_id === 'c01' && isset($_POST['contract_credit'])) {
                $credit_to_add = intval($_POST['contract_credit']);
            } else {
                $credit_to_add = $contract['contract_credit'];
            }
            
            if ($credit_to_add > 0) {
                $bill_entries[] = [
                    'bill_type' => "회원권적립",
                    'bill_balance_before' => $current_balance,
                    'bill_netamt' => $credit_to_add,
                    'bill_balance_after' => $current_balance + $credit_to_add,
                    'contract_history_id' => $contract_history_id
                ];
            }
        } else {
            // 일반 결제인 경우 크레딧 적립만
            // 자유적립 크레딧(c01)인 경우 사용자 입력값 사용
            if ($contract_id === 'c01' && isset($_POST['contract_credit'])) {
                $credit_to_add = intval($_POST['contract_credit']);
            } else {
                $credit_to_add = $contract['contract_credit'];
            }
            
            $bill_entries[] = [
                'bill_type' => "회원권적립",
                'bill_balance_before' => $current_balance,
                'bill_netamt' => $credit_to_add,
                'bill_balance_after' => $current_balance + $credit_to_add,
                'contract_history_id' => $contract_history_id
            ];
        }

        // bills 테이블에 각 내역 기록
        $bill_stmt = $db->prepare('
            INSERT INTO bills (
                bill_id,
                member_id,
                bill_date,
                bill_type,
                bill_text,
                bill_totalamt,
                bill_deduction,
                bill_netamt,
                bill_timestamp,
                bill_balance_before,
                bill_balance_after,
                contract_history_id
            ) VALUES (
                ?, ?, ?, ?, ?, ?, ?, ?, NOW(), ?, ?, ?
            )
        ');

        foreach ($bill_entries as $entry) {
            // 다음 bill_id 가져오기
            $next_bill_id = getNextId($db, 'bills', 'bill_id');
            $bill_deduction = 0;
            $bill_text = $contract['contract_name'];
            
            // abs() 함수 결과를 변수에 저장
            $bill_totalamt = abs($entry['bill_netamt']);  // bill_totalamt에는 절대값 사용 (항상 양수)
            
            $bill_stmt->bind_param('iisssiiiiis',
                $next_bill_id,
                $member_id,
                $contract_date,
                $entry['bill_type'],
                $bill_text,
                $bill_totalamt,
                $bill_deduction,
                $entry['bill_netamt'],       // bill_netamt는 원래 값 그대로 (적립은 양수, 차감은 음수)
                $entry['bill_balance_before'],
                $entry['bill_balance_after'],
                $entry['contract_history_id']
            );
            $bill_stmt->execute();
        }

        // 모든 작업이 성공하면 커밋
        $db->commit();
        echo json_encode(['success' => true, 'member_id' => $member_id]);
        exit;
    } catch (Exception $e) {
        // 오류 발생 시 롤백
        $db->rollback();
        
        // 상세한 에러 로깅
        $error_message = sprintf(
            "Error: %s\nFile: %s\nLine: %d\nTrace:\n%s",
            $e->getMessage(),
            $e->getFile(),
            $e->getLine(),
            $e->getTraceAsString()
        );
        error_log($error_message);
        
        // 클라이언트에 전달할 응답
        $response = [
            'success' => false,
            'message' => '처리 중 오류가 발생했습니다: ' . $e->getMessage(),
            'file' => $e->getFile(),
            'line' => $e->getLine()
        ];
        
        if (isset($contract)) {
            $response['debug_info'] = [
                'contract_type' => $contract['contract_type'] ?? 'not set',
                'contract_id' => $contract_id ?? 'not set',
                'payment_type' => $payment_type ?? 'not set'
            ];
        }
        
        echo json_encode($response);
        exit;
    }
}

echo json_encode(['success' => false, 'message' => '잘못된 요청입니다.']);
exit;
?>