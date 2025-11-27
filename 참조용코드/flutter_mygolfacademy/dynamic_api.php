<?php
// CORS 헤더 추가 - 모든 도메인 허용
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, User-Agent');

// OPTIONS 요청 처리 (프리플라이트)
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
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
    'contract_history',
    'contract_history_view',
    'v2_contracts',
    'member_pro_match',
    'members',
    'schedule_adjusted',
    'schedule_weekly_base',
    'v2_LS_contracts',
    'v3_LS_countings',
    'v2_LS_orders',
    'v2_Price_table',
    'v2_Term_hold',
    'v2_Term_member',
    'v2_bills',
    'v2_ts_pricing_policy',
    'v3_contract_history',
    'v2_junior_relation',
    'v3_members',
    'v2_discount_coupon',
    'v2_priced_TS',
    'v2_branch',
    'v2_base_option_setting',
    'v2_member_pro_match',
    'v2_staff_pro',
    'v2_weekly_schedule_ts',
    'v2_weekly_schedule_pro',
    'v2_schedule_adjusted_pro',
    'v2_schedule_adjusted_ts',
    'v2_routine_discount',
    'v2_ts_info'
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
    
    // 필수 파라미터 확인
    if (!isset($requestData['operation']) || !in_array($requestData['operation'], $allowedOperations)) {
        sendResponse(['error' => '유효하지 않은 작업입니다.'], 400);
    }
    
    if (!isset($requestData['table']) || !in_array($requestData['table'], $allowedTables)) {
        sendResponse(['error' => '유효하지 않은 테이블입니다.'], 400);
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

// ========== API 엔드포인트 처리 ==========

// API 호출 처리
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $response = processRequest();
    sendResponse($response);
} else {
    sendResponse(['error' => '허용되지 않은 요청 메서드입니다.'], 405);
}
?>