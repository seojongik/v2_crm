<?php
// CORS 헤더 추가 - 모든 도메인 허용
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With, Accept, Origin, User-Agent');
header('Access-Control-Max-Age: 86400');

// OPTIONS 요청 처리 (프리플라이트)
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

// ========== 기본 설정 및 유틸리티 함수 ==========

// 데이터베이스 연결 설정
$db_config = [
    'host' => '222.122.198.185',
    'user' => 'autofms',
    'password' => 'a131150*',
    'db' => 'autofms',
    'charset' => 'utf8mb4'
];

// 허용된 테이블 목록 (보안을 위한 화이트리스트)
$allowedTables = [
    'Board',
    'CHN_batch',
    'CHN_message',
    'Comment',
    'Event_log',
    'FMS_LS',
    'FMS_TS',
    'Junior',
    'Junior_relation',
    'LS_availability',
    'LS_availability_register',
    'LS_confirm',
    'LS_contracts',
    'LS_countings',
    'LS_feedback',
    'LS_history',
    'LS_orders',
    'LS_search_fail',
    'LS_total_history',
    'Locker_bill',
    'Locker_status',
    'Price_table',
    'Priced_FMS',
    'Revisit_discount',
    'Staff',
    'Staff_payment',
    'TS_usage',
    'Term_hold',
    'Term_member',
    'bills',
    'v2_bill_times',
    'v2_bill_games',
    'v2_bill_games_group',
    'contract_history',
    'contract_history_view',
    'v2_contracts',
    'member_pro_match',
    'members',
    'schedule_adjusted',
    'schedule_weekly_base',
    'v2_wol_settings',
    'v2_LS_contracts',
    'v2_LS_countings',
    'v3_LS_countings',
    'v2_LS_orders',
    'v2_Price_table',
    'v2_Term_hold',
    'v2_Term_member',
    'v2_bills',
    'v2_bill_term',
    'v2_bill_term_hold',
    'v2_eventhandicap_TS',
    'v2_eventhandicap_LS',
    'v2_group',
    'v2_ts_pricing_policy',
    'v2_contract_history',
    'v3_contract_history',
    'v2_junior_relation',
    'v3_members',
    'v2_discount_coupon',
    'v2_priced_TS',
    'v2_branch',
    'v2_base_option_setting',
    'v2_member_pro_match',
    'v2_staff_pro',
    'v2_salary_pro',
    'v2_staff_access_setting',
    'v2_weekly_schedule_ts',
    'v2_board_by_member',
    'v2_board_by_member_replies',
    'v2_weekly_schedule_pro',
    'v2_schedule_adjusted_pro',
    'v2_schedule_adjusted_ts',
    'v2_discount_coupon_setting',
    'v2_discount_coupon_auto_triggers',
    'v2_routine_discount',
    'v2_board',
    'v2_board_comment',
    'v2_Locker_status',
    'v2_Locker_bill',
    'v2_message',
    'v2_message_agreement',
    'v2_cancellation_policy',
    'v2_schedule_adjusted_manager',
    'v2_staff_manager',
    'v2_salary_manager',
    'v2_weekly_schedule_manager',
    'v2_ts_info',
    'v2_program_settings',
    'v2_portone_payments',
    'v3_priced_TS'
];

// 허용된 작업 목록
$allowedOperations = ['get', 'add', 'update', 'delete'];

// 데이터베이스 연결 함수
function getConnection() {
    global $db_config;
    
    try {
        $pdo = new PDO(
            "mysql:host={$db_config['host']};dbname={$db_config['db']};charset={$db_config['charset']}",
            $db_config['user'],
            $db_config['password'],
            [
                PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                PDO::ATTR_EMULATE_PREPARES => false
            ]
        );
        return $pdo;
    } catch (PDOException $e) {
        // 오류 처리
        header('Content-Type: application/json');
        http_response_code(500);
        echo json_encode(['error' => '데이터베이스 연결 오류: ' . $e->getMessage()]);
        exit;
    }
}

// 응답 함수
function sendResponse($data, $statusCode = 200) {
    header('Content-Type: application/json');
    http_response_code($statusCode);
    echo json_encode($data);
    exit;
}

// 전화번호 포맷 함수 (010-1234-5678 형식으로 변환)
function formatPhoneNumber($phoneNumber) {
    $cleaned = preg_replace('/[^0-9]/', '', $phoneNumber);
    
    if(strlen($cleaned) === 11) {
        return substr($cleaned, 0, 3) . '-' . substr($cleaned, 3, 4) . '-' . substr($cleaned, 7);
    }
    
    return $phoneNumber;
}

// ========== API 기능 구현 ==========

// 요청 처리 함수
function processRequest() {
    global $allowedTables, $allowedOperations;
    
    // JSON 요청 데이터 파싱
    $requestData = json_decode(file_get_contents('php://input'), true);
    
    // 기본 입력 검증
    if (!$requestData) {
        sendResponse(['error' => '유효하지 않은 요청 데이터입니다.'], 400);
    }
    
    // 특별한 액션 처리
    if (isset($requestData['action'])) {
        switch ($requestData['action']) {
            case 'update_schedule_adjusted_pro':
                return handleScheduleUpdate($requestData);
            case 'getMemberProPurchaseCount':
                // 필수 파라미터 확인
                if (!isset($requestData['member_id']) || !isset($requestData['branch_id'])) {
                    return ['error' => 'member_id와 branch_id가 필요합니다.'];
                }
                return getMemberProPurchaseCount($requestData['member_id'], $requestData['branch_id']);
            default:
                // 일반적인 처리로 계속
                break;
        }
    }
    
    // 필수 파라미터 확인
    if (!isset($requestData['operation']) || !in_array($requestData['operation'], $allowedOperations)) {
        sendResponse(['error' => '유효하지 않은 작업입니다.'], 400);
    }
    
    // 디버그: 요청된 테이블과 허용된 테이블 목록 확인
    error_log("요청된 테이블: " . (isset($requestData['table']) ? $requestData['table'] : 'NULL'));
    error_log("v2_group이 허용 목록에 있는가: " . (in_array('v2_group', $allowedTables) ? 'YES' : 'NO'));
    error_log("요청된 테이블이 허용 목록에 있는가: " . (isset($requestData['table']) && in_array($requestData['table'], $allowedTables) ? 'YES' : 'NO'));
    
    if (!isset($requestData['table']) || !in_array($requestData['table'], $allowedTables)) {
        sendResponse(['error' => '유효하지 않은 테이블입니다. 요청: ' . (isset($requestData['table']) ? $requestData['table'] : 'NULL')], 400);
    }
    
    $operation = $requestData['operation'];
    $table = $requestData['table'];
    
    try {
        // 작업 유형에 따른 처리
        switch ($operation) {
            case 'get':
                return handleGetOperation($table, $requestData);
            case 'add':
                return handleAddOperation($table, $requestData);
            case 'update':
                return handleUpdateOperation($table, $requestData);
            case 'delete':
                return handleDeleteOperation($table, $requestData);
            default:
                throw new Exception('지원하지 않는 작업입니다.');
        }
    } catch (Exception $e) {
        sendResponse(['error' => $e->getMessage()], 500);
    }
}

// GET 작업 처리
function handleGetOperation($table, $requestData) {
    // 테이블 구조 확인
    $columns = getTableColumns($table);
    
    // 1. 조회할 필드 설정
    $selectFields = isset($requestData['fields']) && is_array($requestData['fields']) 
                    ? $requestData['fields'] : ['*'];
    
    // 필드 검증 (*, 또는 실제 존재하는 컬럼명만 허용)
    if ($selectFields[0] !== '*') {
        foreach ($selectFields as $field) {
            if (!in_array($field, $columns)) {
                throw new Exception("유효하지 않은 필드입니다: $field");
            }
        }
    }
    
    // 2. WHERE 조건 처리
    $whereClause = '';
    $params = [];
    
    if (isset($requestData['where']) && is_array($requestData['where'])) {
        $conditions = [];
        
        foreach ($requestData['where'] as $condition) {
            if (!isset($condition['field']) || !isset($condition['operator']) || !isset($condition['value'])) {
                continue; // 잘못된 조건 형식은 건너뜀
            }
            
            $field = $condition['field'];
            $operator = $condition['operator'];
            $value = $condition['value'];
            
            // 필드 검증
            if (!in_array($field, $columns)) {
                throw new Exception("유효하지 않은 조건 필드입니다: $field");
            }
            
            // 연산자 검증
            $allowedOperators = ['=', '>', '<', '>=', '<=', '<>', 'LIKE', 'IN'];
            if (!in_array($operator, $allowedOperators)) {
                throw new Exception("유효하지 않은 연산자입니다: $operator");
            }
            
            // 특수 연산자 처리
            if ($operator === 'IN' && is_array($value)) {
                $placeholders = implode(',', array_fill(0, count($value), '?'));
                $conditions[] = "$field IN ($placeholders)";
                $params = array_merge($params, $value);
            } else {
                $conditions[] = "$field $operator ?";
                $params[] = $value;
            }
        }
        
        if (!empty($conditions)) {
            $whereClause = " WHERE " . implode(' AND ', $conditions);
        }
    }
    
    // 3. ORDER BY 처리
    $orderClause = '';
    
    if (isset($requestData['orderBy']) && is_array($requestData['orderBy'])) {
        $orderParts = [];
        
        foreach ($requestData['orderBy'] as $order) {
            if (!isset($order['field']) || !in_array($order['field'], $columns)) {
                continue;
            }
            
            $direction = (isset($order['direction']) && strtoupper($order['direction']) === 'DESC') 
                        ? 'DESC' : 'ASC';
            $orderParts[] = "{$order['field']} $direction";
        }
        
        if (!empty($orderParts)) {
            $orderClause = " ORDER BY " . implode(', ', $orderParts);
        }
    }
    
    // 4. LIMIT 및 OFFSET 처리
    $limitClause = '';
    
    if (isset($requestData['limit']) && is_numeric($requestData['limit'])) {
        $limit = (int)$requestData['limit'];
        $limitClause = " LIMIT $limit";
        
        if (isset($requestData['offset']) && is_numeric($requestData['offset'])) {
            $offset = (int)$requestData['offset'];
            $limitClause .= " OFFSET $offset";
        }
    }
    
    // 쿼리 실행
    $db = getConnection();
    $selectFieldsStr = $selectFields[0] === '*' ? '*' : implode(', ', $selectFields);
    $query = "SELECT $selectFieldsStr FROM $table$whereClause$orderClause$limitClause";
    
    $stmt = $db->prepare($query);
    $stmt->execute($params);
    $results = $stmt->fetchAll();
    
    // 후처리 - 필요한 경우 전화번호 포맷 변환 등
    if (!empty($results) && (in_array('phone', $columns) || in_array('mobile', $columns))) {
        foreach ($results as &$row) {
            if (isset($row['phone'])) {
                $row['phone'] = formatPhoneNumber($row['phone']);
            }
            if (isset($row['mobile'])) {
                $row['mobile'] = formatPhoneNumber($row['mobile']);
            }
        }
    }
    
    return [
        'success' => true,
        'data' => $results,
        'count' => count($results)
    ];
}

// ADD 작업 처리
function handleAddOperation($table, $requestData) {
    // 테이블 구조 확인
    $columns = getTableColumns($table);
    
    if (!isset($requestData['data']) || !is_array($requestData['data'])) {
        throw new Exception('추가할 데이터가 제공되지 않았습니다.');
    }
    
    $data = $requestData['data'];
    $fields = [];
    $placeholders = [];
    $values = [];
    
    foreach ($data as $field => $value) {
        // 필드 검증
        if (!in_array($field, $columns)) {
            continue; // 테이블에 없는 필드는 무시
        }
        
        $fields[] = $field;
        $placeholders[] = '?';
        $values[] = $value;
    }
    
    if (empty($fields)) {
        throw new Exception('유효한 필드가 없습니다.');
    }
    
    // 쿼리 실행
    $db = getConnection();
    $query = "INSERT INTO $table (" . implode(', ', $fields) . ") VALUES (" . implode(', ', $placeholders) . ")";
    
    $stmt = $db->prepare($query);
    $stmt->execute($values);
    
    $insertId = $db->lastInsertId();
    
    return [
        'success' => true,
        'message' => '데이터가 성공적으로 추가되었습니다.',
        'insertId' => $insertId
    ];
}

// UPDATE 작업 처리
function handleUpdateOperation($table, $requestData) {
    // 테이블 구조 확인
    $columns = getTableColumns($table);
    
    if (!isset($requestData['data']) || !is_array($requestData['data'])) {
        throw new Exception('업데이트할 데이터가 제공되지 않았습니다.');
    }
    
    if (!isset($requestData['where']) || !is_array($requestData['where']) || empty($requestData['where'])) {
        throw new Exception('업데이트 조건이 지정되지 않았습니다.');
    }
    
    // 1. SET 절 처리
    $data = $requestData['data'];
    $setFields = [];
    $values = [];
    
    foreach ($data as $field => $value) {
        // 필드 검증
        if (!in_array($field, $columns)) {
            continue; // 테이블에 없는 필드는 무시
        }
        
        $setFields[] = "$field = ?";
        $values[] = $value;
    }
    
    if (empty($setFields)) {
        throw new Exception('유효한 업데이트 필드가 없습니다.');
    }
    
    // 2. WHERE 조건 처리
    $whereClause = '';
    $whereValues = [];
    
    if (isset($requestData['where']) && is_array($requestData['where'])) {
        $conditions = [];
        
        foreach ($requestData['where'] as $condition) {
            if (!isset($condition['field']) || !isset($condition['operator']) || !isset($condition['value'])) {
                continue;
            }
            
            $field = $condition['field'];
            $operator = $condition['operator'];
            $value = $condition['value'];
            
            // 필드 검증
            if (!in_array($field, $columns)) {
                throw new Exception("유효하지 않은 조건 필드입니다: $field");
            }
            
            // 연산자 검증
            $allowedOperators = ['=', '>', '<', '>=', '<=', '<>', 'LIKE'];
            if (!in_array($operator, $allowedOperators)) {
                throw new Exception("유효하지 않은 연산자입니다: $operator");
            }
            
            $conditions[] = "$field $operator ?";
            $whereValues[] = $value;
        }
        
        if (empty($conditions)) {
            throw new Exception('유효한 업데이트 조건이 없습니다.');
        }
        
        $whereClause = " WHERE " . implode(' AND ', $conditions);
    }
    
    // 쿼리 실행
    $db = getConnection();
    $query = "UPDATE $table SET " . implode(', ', $setFields) . $whereClause;
    
    $stmt = $db->prepare($query);
    $stmt->execute(array_merge($values, $whereValues));
    
    $rowCount = $stmt->rowCount();
    
    return [
        'success' => true,
        'message' => '데이터가 성공적으로 업데이트되었습니다.',
        'affectedRows' => $rowCount
    ];
}

// DELETE 작업 처리
function handleDeleteOperation($table, $requestData) {
    // 테이블 구조 확인
    $columns = getTableColumns($table);
    
    if (!isset($requestData['where']) || !is_array($requestData['where']) || empty($requestData['where'])) {
        throw new Exception('삭제 조건이 지정되지 않았습니다.');
    }
    
    // WHERE 조건 처리
    $whereClause = '';
    $params = [];
    
    $conditions = [];
    
    foreach ($requestData['where'] as $condition) {
        if (!isset($condition['field']) || !isset($condition['operator']) || !isset($condition['value'])) {
            continue;
        }
        
        $field = $condition['field'];
        $operator = $condition['operator'];
        $value = $condition['value'];
        
        // 필드 검증
        if (!in_array($field, $columns)) {
            throw new Exception("유효하지 않은 조건 필드입니다: $field");
        }
        
        // 연산자 검증
        $allowedOperators = ['=', '>', '<', '>=', '<=', '<>', 'LIKE'];
        if (!in_array($operator, $allowedOperators)) {
            throw new Exception("유효하지 않은 연산자입니다: $operator");
        }
        
        $conditions[] = "$field $operator ?";
        $params[] = $value;
    }
    
    if (empty($conditions)) {
        throw new Exception('유효한 삭제 조건이 없습니다.');
    }
    
    $whereClause = " WHERE " . implode(' AND ', $conditions);
    
    // 쿼리 실행
    $db = getConnection();
    $query = "DELETE FROM $table" . $whereClause;
    
    $stmt = $db->prepare($query);
    $stmt->execute($params);
    
    $rowCount = $stmt->rowCount();
    
    return [
        'success' => true,
        'message' => '데이터가 성공적으로 삭제되었습니다.',
        'affectedRows' => $rowCount
    ];
}


// 테이블 컬럼 정보 가져오기
function getTableColumns($table) {
    $db = getConnection();
    $stmt = $db->prepare("DESCRIBE $table");
    $stmt->execute();
    $result = $stmt->fetchAll();
    
    $columns = [];
    foreach ($result as $row) {
        $columns[] = $row['Field'];
    }
    
    return $columns;
}

// 스케줄 업데이트 처리 함수
function handleScheduleUpdate($requestData) {
    if (!isset($requestData['data']) || !is_array($requestData['data'])) {
        sendResponse(['error' => '업데이트할 데이터가 없습니다.'], 400);
    }
    
    $data = $requestData['data'];
    
    // 필수 필드 확인
    $requiredFields = ['branch_id', 'pro_id', 'scheduled_date'];
    foreach ($requiredFields as $field) {
        if (!isset($data[$field]) || empty($data[$field])) {
            sendResponse(['error' => "필수 필드가 누락되었습니다: $field"], 400);
        }
    }
    
    try {
        $pdo = getConnection();
        
        // 기존 데이터 확인
        $checkSql = "SELECT COUNT(*) FROM v2_schedule_adjusted_pro 
                     WHERE branch_id = ? AND pro_id = ? AND scheduled_date = ?";
        $checkStmt = $pdo->prepare($checkSql);
        $checkStmt->execute([$data['branch_id'], $data['pro_id'], $data['scheduled_date']]);
        $exists = $checkStmt->fetchColumn() > 0;
        
        if ($exists) {
            // 업데이트
            $updateSql = "UPDATE v2_schedule_adjusted_pro SET 
                          scheduled_staff_id = ?,
                          pro_name = ?,
                          work_start = ?,
                          work_end = ?,
                          is_day_off = ?,
                          updated_at = ?,
                          is_manually_set = ?
                          WHERE branch_id = ? AND pro_id = ? AND scheduled_date = ?";
            
            $updateStmt = $pdo->prepare($updateSql);
            $updateResult = $updateStmt->execute([
                $data['scheduled_staff_id'] ?? '',
                $data['pro_name'] ?? '',
                $data['work_start'] ?? '00:00',
                $data['work_end'] ?? '00:00',
                $data['is_day_off'] ?? 'N',
                $data['updated_at'] ?? date('Y-m-d H:i:s'),
                $data['is_manually_set'] ?? '수동조정',
                $data['branch_id'],
                $data['pro_id'],
                $data['scheduled_date']
            ]);
            
            if ($updateResult) {
                sendResponse(['success' => true, 'message' => '스케줄이 성공적으로 업데이트되었습니다.']);
            } else {
                sendResponse(['success' => false, 'message' => '스케줄 업데이트에 실패했습니다.'], 500);
            }
        } else {
            // 삽입
            $insertSql = "INSERT INTO v2_schedule_adjusted_pro 
                          (scheduled_staff_id, branch_id, pro_id, pro_name, scheduled_date, 
                           work_start, work_end, is_day_off, updated_at, is_manually_set) 
                          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
            
            $insertStmt = $pdo->prepare($insertSql);
            $insertResult = $insertStmt->execute([
                $data['scheduled_staff_id'] ?? '',
                $data['branch_id'],
                $data['pro_id'],
                $data['pro_name'] ?? '',
                $data['scheduled_date'],
                $data['work_start'] ?? '00:00',
                $data['work_end'] ?? '00:00',
                $data['is_day_off'] ?? 'N',
                $data['updated_at'] ?? date('Y-m-d H:i:s'),
                $data['is_manually_set'] ?? '수동조정'
            ]);
            
            if ($insertResult) {
                sendResponse(['success' => true, 'message' => '스케줄이 성공적으로 생성되었습니다.']);
            } else {
                sendResponse(['success' => false, 'message' => '스케줄 생성에 실패했습니다.'], 500);
            }
        }
        
    } catch (Exception $e) {
        sendResponse(['success' => false, 'message' => '데이터베이스 오류: ' . $e->getMessage()], 500);
    }
}

// ========== 회원별 프로 구매횟수 조회 ==========

/**
 * 특정 회원의 프로별 구매횟수를 조회합니다.
 * v3_contract_history 테이블에서 유효한 계약의 프로별 구매횟수를 집계합니다.
 */
function getMemberProPurchaseCount($memberId, $branchId) {
    try {
        $db = getConnection();
        
        // 프로별 구매횟수 조회 쿼리
        $sql = "SELECT 
                    pro_id,
                    pro_name,
                    COUNT(*) as purchase_count
                FROM v3_contract_history 
                WHERE member_id = ? 
                    AND branch_id = ? 
                    AND contract_history_status = '유효'
                    AND pro_id IS NOT NULL
                    AND pro_name IS NOT NULL
                GROUP BY pro_id, pro_name
                ORDER BY purchase_count DESC, pro_name ASC";
        
        $stmt = $db->prepare($sql);
        $stmt->execute([$memberId, $branchId]);
        $result = $stmt->fetchAll();
        
        $purchaseCounts = [];
        foreach ($result as $row) {
            $purchaseCounts[] = [
                'pro_id' => $row['pro_id'],
                'pro_name' => $row['pro_name'],
                'purchase_count' => (int)$row['purchase_count']
            ];
        }
        
        return [
            'success' => true,
            'data' => $purchaseCounts,
            'total_count' => count($purchaseCounts)
        ];
        
    } catch (Exception $e) {
        return [
            'success' => false,
            'message' => '프로 구매횟수 조회 실패: ' . $e->getMessage()
        ];
    }
}

// ========== API 엔드포인트 처리 ==========

// API 호출 처리
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    // JSON 요청 데이터 파싱
    $requestData = json_decode(file_get_contents('php://input'), true);
    
    // SMS 발송 처리
    if (isset($requestData['action']) && $requestData['action'] === 'send_sms') {
        $phone = $requestData['phone'] ?? '';
        $message = $requestData['message'] ?? '';

        if (empty($phone) || empty($message)) {
            sendResponse(['success' => false, 'error' => '전화번호와 메시지가 필요합니다'], 400);
        }

        // 알리고 SMS API 호출
        $aligo_url = 'https://apis.aligo.in/send/';
        $aligo_data = array(
            'key' => 'djcg4vyirxyswndxi1xjobnoa93h76jr',
            'userid' => 'enables',
            'sender' => '010-2364-3612',
            'receiver' => str_replace('-', '', $phone),
            'msg' => $message,
            'msg_type' => 'SMS'
        );

        $ch = curl_init();
        curl_setopt($ch, CURLOPT_URL, $aligo_url);
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_POSTFIELDS, http_build_query($aligo_data));
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);

        $response = curl_exec($ch);
        $http_code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);

        if ($http_code == 200) {
            $result = json_decode($response, true);
            if ($result['result_code'] == '1') {
                sendResponse(['success' => true, 'data' => $result]);
            } else {
                sendResponse(['success' => false, 'error' => $result['message']]);
            }
        } else {
            sendResponse(['success' => false, 'error' => 'SMS API 호출 실패']);
        }
    }
    
    // 포트원 결제 정보 조회 (서버에서 포트원 API 호출)
    if (isset($requestData['action']) && $requestData['action'] === 'portone_get_payment') {
        $paymentId = $requestData['paymentId'] ?? '';
        $branchId = $requestData['branchId'] ?? '';

        if (empty($paymentId) || empty($branchId)) {
            sendResponse(['success' => false, 'error' => 'paymentId와 branchId가 필요합니다.'], 400);
        }

        // 지점 정보에서 PortOne API Secret 조회
        try {
            $db = getConnection();
            $stmt = $db->prepare("SELECT portone_api_secret FROM v2_branch WHERE branch_id = ?");
            $stmt->execute([$branchId]);
            $branch = $stmt->fetch();
            
            if (!$branch || empty($branch['portone_api_secret'])) {
                sendResponse(['success' => false, 'error' => 'PortOne API Secret을 찾을 수 없습니다.'], 404);
            }
            
            $apiSecret = $branch['portone_api_secret'];
            
            // PortOne API 호출
            $portone_url = "https://api.portone.io/payments/$paymentId";
            
            $ch = curl_init();
            curl_setopt($ch, CURLOPT_URL, $portone_url);
            curl_setopt($ch, CURLOPT_HTTPHEADER, array(
                'Authorization: PortOne ' . $apiSecret,
                'Content-Type: application/json'
            ));
            curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
            curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, true);

            $response = curl_exec($ch);
            $http_code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
            $curl_error = curl_error($ch);
            curl_close($ch);

            if ($curl_error) {
                sendResponse(['success' => false, 'error' => 'PortOne API 호출 오류: ' . $curl_error]);
            } else if ($http_code == 200) {
                $result = json_decode($response, true);
                sendResponse(['success' => true, 'data' => $result]);
            } else {
                $error_data = json_decode($response, true);
                $error_message = isset($error_data['message']) ? $error_data['message'] : 'PortOne API 호출 실패';
                sendResponse(['success' => false, 'error' => $error_message, 'http_code' => $http_code]);
            }
        } catch (Exception $e) {
            sendResponse(['success' => false, 'error' => '서버 오류: ' . $e->getMessage()]);
        }
    }
    
    $response = processRequest();
    sendResponse($response);
} else {
    sendResponse(['error' => '허용되지 않은 요청 메서드입니다.'], 405);
}
?>