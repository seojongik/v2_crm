<?php
// 데이터베이스 연결
require_once '../../config/db_connect.php';

// 헤더 설정
header('Content-Type: text/html; charset=utf-8');

echo '<h1>테이블 확인</h1>';

// 데이터베이스의 모든 테이블 목록 확인
echo '<h2>데이터베이스 테이블 목록</h2>';
try {
    $result = $db->query("SHOW TABLES");
    
    echo '<ul>';
    while ($row = $result->fetch_row()) {
        echo '<li>' . htmlspecialchars($row[0]) . '</li>';
    }
    echo '</ul>';
    
    // member_pro_match 테이블 존재 여부 확인
    $result = $db->query("SHOW TABLES LIKE 'member_pro_match'");
    if ($result->num_rows > 0) {
        echo '<p style="color:green">member_pro_match 테이블이 존재합니다.</p>';
        
        // 테이블 구조 확인
        echo '<h2>member_pro_match 테이블 구조</h2>';
        $result = $db->query("DESCRIBE member_pro_match");
        echo '<table border="1">';
        echo '<tr><th>필드</th><th>타입</th><th>Null</th><th>키</th><th>기본값</th><th>추가</th></tr>';
        while ($row = $result->fetch_assoc()) {
            echo '<tr>';
            echo '<td>' . htmlspecialchars($row['Field']) . '</td>';
            echo '<td>' . htmlspecialchars($row['Type']) . '</td>';
            echo '<td>' . htmlspecialchars($row['Null']) . '</td>';
            echo '<td>' . htmlspecialchars($row['Key']) . '</td>';
            echo '<td>' . htmlspecialchars($row['Default']) . '</td>';
            echo '<td>' . htmlspecialchars($row['Extra']) . '</td>';
            echo '</tr>';
        }
        echo '</table>';
        
        // 데이터 샘플 확인
        echo '<h2>member_pro_match 데이터 샘플 (최근 10개)</h2>';
        $result = $db->query("SELECT * FROM member_pro_match ORDER BY registered_at DESC LIMIT 10");
        
        if ($result->num_rows > 0) {
            echo '<table border="1">';
            // 헤더 출력
            $first_row = $result->fetch_assoc();
            $result->data_seek(0);
            echo '<tr>';
            foreach (array_keys($first_row) as $key) {
                echo '<th>' . htmlspecialchars($key) . '</th>';
            }
            echo '</tr>';
            
            // 데이터 출력
            while ($row = $result->fetch_assoc()) {
                echo '<tr>';
                foreach ($row as $key => $value) {
                    echo '<td>' . htmlspecialchars($value ?: 'NULL') . '</td>';
                }
                echo '</tr>';
            }
            echo '</table>';
        } else {
            echo '<p>member_pro_match 테이블에 데이터가 없습니다.</p>';
        }
    } else {
        echo '<p style="color:red">member_pro_match 테이블이 존재하지 않습니다!</p>';
        
        // 비슷한 이름의 테이블 찾기
        echo '<h2>유사한 테이블 찾기</h2>';
        $result = $db->query("SHOW TABLES LIKE '%pro%'");
        if ($result->num_rows > 0) {
            echo '<p>이름에 "pro"가 포함된 테이블 목록:</p>';
            echo '<ul>';
            while ($row = $result->fetch_row()) {
                echo '<li>' . htmlspecialchars($row[0]) . '</li>';
            }
            echo '</ul>';
        } else {
            echo '<p>이름에 "pro"가 포함된 테이블이 없습니다.</p>';
        }
        
        $result = $db->query("SHOW TABLES LIKE '%match%'");
        if ($result->num_rows > 0) {
            echo '<p>이름에 "match"가 포함된 테이블 목록:</p>';
            echo '<ul>';
            while ($row = $result->fetch_row()) {
                echo '<li>' . htmlspecialchars($row[0]) . '</li>';
            }
            echo '</ul>';
        } else {
            echo '<p>이름에 "match"가 포함된 테이블이 없습니다.</p>';
        }
        
        // 실제 테이블 이름이 뭔지 찾아보자
        echo '<h2>레슨 프로 관련 테이블 찾기</h2>';
        echo '<p>컬럼 이름에 pro 또는 staff와 member가 포함된 테이블 검색:</p>';
        
        $result = $db->query("
            SELECT TABLE_NAME, COLUMN_NAME
            FROM INFORMATION_SCHEMA.COLUMNS
            WHERE (COLUMN_NAME LIKE '%pro%' OR COLUMN_NAME LIKE '%staff%')
            AND TABLE_SCHEMA = DATABASE()
            ORDER BY TABLE_NAME, COLUMN_NAME
        ");
        
        if ($result->num_rows > 0) {
            echo '<table border="1">';
            echo '<tr><th>테이블</th><th>컬럼</th></tr>';
            while ($row = $result->fetch_assoc()) {
                echo '<tr>';
                echo '<td>' . htmlspecialchars($row['TABLE_NAME']) . '</td>';
                echo '<td>' . htmlspecialchars($row['COLUMN_NAME']) . '</td>';
                echo '</tr>';
            }
            echo '</table>';
        } else {
            echo '<p>해당 조건의 컬럼이 없습니다.</p>';
        }
    }
} catch (Exception $e) {
    echo '<p style="color:red">데이터베이스 테이블 조회 중 오류 발생: ' . htmlspecialchars($e->getMessage()) . '</p>';
}

$db->close();
?> 