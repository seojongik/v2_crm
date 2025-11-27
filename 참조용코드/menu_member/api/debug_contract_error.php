<?php
require_once '../../config/db_connect.php';

// 에러 표시 설정
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

echo "<h1>contract_history 테이블 디버깅</h1>";

// 테이블 구조 확인
echo "<h2>contract_history 테이블 구조</h2>";
try {
    $result = $db->query("DESCRIBE contract_history");
    
    if (!$result) {
        throw new Exception($db->error);
    }
    
    echo "<table border='1'>";
    echo "<tr><th>Field</th><th>Type</th><th>Null</th><th>Key</th><th>Default</th><th>Extra</th></tr>";
    
    while ($row = $result->fetch_assoc()) {
        echo "<tr>";
        echo "<td>" . $row["Field"] . "</td>";
        echo "<td>" . $row["Type"] . "</td>";
        echo "<td>" . $row["Null"] . "</td>";
        echo "<td>" . $row["Key"] . "</td>";
        echo "<td>" . $row["Default"] . "</td>";
        echo "<td>" . $row["Extra"] . "</td>";
        echo "</tr>";
    }
    
    echo "</table>";
} catch (Exception $e) {
    echo "<p>오류 발생: " . $e->getMessage() . "</p>";
}

// 최근 쿼리 로그 확인 (일부 시스템에서만 작동)
echo "<h2>최근 SQL 쿼리 로그</h2>";
echo "<p>MySQL 일반 로그가 활성화되어 있다면 확인할 수 있습니다.</p>";

// contract_history 테이블 처음 10개 레코드 확인
echo "<h2>contract_history 테이블 데이터 샘플</h2>";
try {
    $result = $db->query("SELECT * FROM contract_history LIMIT 10");
    
    if (!$result) {
        throw new Exception($db->error);
    }
    
    if ($result->num_rows > 0) {
        echo "<table border='1'>";
        
        // 컬럼 헤더 출력
        $first_row = $result->fetch_assoc();
        $result->data_seek(0);
        
        echo "<tr>";
        foreach ($first_row as $key => $value) {
            echo "<th>" . htmlspecialchars($key) . "</th>";
        }
        echo "</tr>";
        
        // 데이터 출력
        while ($row = $result->fetch_assoc()) {
            echo "<tr>";
            foreach ($row as $value) {
                echo "<td>" . htmlspecialchars($value ?? 'NULL') . "</td>";
            }
            echo "</tr>";
        }
        
        echo "</table>";
    } else {
        echo "<p>테이블에 데이터가 없습니다.</p>";
    }
} catch (Exception $e) {
    echo "<p>오류 발생: " . $e->getMessage() . "</p>";
}

// 관련 테이블 목록
echo "<h2>모든 테이블 목록</h2>";
try {
    $result = $db->query("SHOW TABLES");
    
    if (!$result) {
        throw new Exception($db->error);
    }
    
    echo "<ul>";
    while ($row = $result->fetch_row()) {
        echo "<li>" . $row[0] . "</li>";
    }
    echo "</ul>";
} catch (Exception $e) {
    echo "<p>오류 발생: " . $e->getMessage() . "</p>";
}
?> 