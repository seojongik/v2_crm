<?php
require_once '../../config/db_connect.php';

// 에러 표시 설정
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

echo "<h1>contract_history 테이블 수정</h1>";

// 현재 테이블 구조 확인
$check_query = "SHOW COLUMNS FROM contract_history";
$columns = [];

try {
    $result = $db->query($check_query);
    if ($result) {
        while ($row = $result->fetch_assoc()) {
            $columns[] = $row['Field'];
        }
    }
    
    // contract_history_id 컬럼이 이미 존재하는지 확인
    if (in_array('contract_history_id', $columns)) {
        echo "<p>contract_history_id 컬럼이 이미 존재합니다. 수정이 필요하지 않습니다.</p>";
    } else {
        // 기본 키가 있는지 확인
        $primary_key_query = "SHOW KEYS FROM contract_history WHERE Key_name = 'PRIMARY'";
        $result = $db->query($primary_key_query);
        $has_primary_key = $result && $result->num_rows > 0;
        
        if ($has_primary_key) {
            // 기존 기본 키 제거
            $result_pk = $db->query("SHOW KEYS FROM contract_history WHERE Key_name = 'PRIMARY'");
            $pk_column = null;
            if ($result_pk && $row = $result_pk->fetch_assoc()) {
                $pk_column = $row['Column_name'];
                echo "<p>기존 기본 키 '{$pk_column}'을 제거합니다.</p>";
                $db->query("ALTER TABLE contract_history DROP PRIMARY KEY");
            }
        }
        
        // contract_history_id 컬럼 추가
        echo "<p>contract_history_id 컬럼을 추가합니다.</p>";
        $alter_query = "ALTER TABLE contract_history ADD COLUMN contract_history_id INT AUTO_INCREMENT PRIMARY KEY FIRST";
        
        if ($db->query($alter_query)) {
            echo "<p>테이블 수정에 성공했습니다. contract_history_id 컬럼이 추가되었습니다.</p>";
        } else {
            echo "<p>테이블 수정 중 오류가 발생했습니다: " . $db->error . "</p>";
        }
    }
    
    // 현재 테이블 구조 표시
    echo "<h2>현재 테이블 구조</h2>";
    $result = $db->query("DESCRIBE contract_history");
    
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