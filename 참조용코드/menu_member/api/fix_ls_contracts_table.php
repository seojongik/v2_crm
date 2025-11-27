<?php
require_once '../../config/db_connect.php';

// 에러 표시 설정
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

echo "<h1>LS_contracts 테이블 수정</h1>";

try {
    // 테이블에 contract_history_id 컬럼이 있는지 확인
    $check_query = "SHOW COLUMNS FROM LS_contracts LIKE 'contract_history_id'";
    $result = $db->query($check_query);
    
    if ($result->num_rows > 0) {
        echo "<p>contract_history_id 컬럼이 이미 존재합니다.</p>";
    } else {
        // contract_history_id 컬럼 추가
        $alter_query = "ALTER TABLE LS_contracts ADD COLUMN contract_history_id INT NULL, ADD INDEX idx_contract_history_id (contract_history_id)";
        
        if ($db->query($alter_query)) {
            echo "<p>LS_contracts 테이블에 contract_history_id 컬럼과 인덱스가 성공적으로 추가되었습니다.</p>";
        } else {
            echo "<p>테이블 수정 중 오류가 발생했습니다: " . $db->error . "</p>";
        }
    }
    
    // 테이블 구조 표시
    echo "<h2>LS_contracts 테이블 구조</h2>";
    $result = $db->query("DESCRIBE LS_contracts");
    
    if ($result) {
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
    } else {
        echo "<p>테이블 구조를 가져오는 중 오류가 발생했습니다: " . $db->error . "</p>";
    }
    
} catch (Exception $e) {
    echo "<p>오류 발생: " . $e->getMessage() . "</p>";
}
?> 