<?php
require_once '../../config/db_connect.php';

// LS_contracts 테이블 생성 쿼리
$sql = "
CREATE TABLE IF NOT EXISTS LS_contracts (
    LS_contract_id INT AUTO_INCREMENT PRIMARY KEY,
    member_id INT NOT NULL,
    member_name VARCHAR(100) NOT NULL,
    LS_contract_qty DECIMAL(10,2) NOT NULL DEFAULT 0,
    LS_contract_source VARCHAR(50) NOT NULL,
    LS_contract_date DATE NOT NULL,
    LS_contract_enddate DATE NOT NULL,
    LS_expiry_date DATE NOT NULL,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    staff_id VARCHAR(50) NOT NULL,
    LS_type VARCHAR(10) NOT NULL DEFAULT '일반',
    junior_id INT NULL,
    contract_history_id INT NULL,
    INDEX idx_member_id (member_id),
    INDEX idx_junior_id (junior_id),
    INDEX idx_contract_history_id (contract_history_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
";

// 테이블 생성 실행
try {
    if ($db->query($sql)) {
        echo "LS_contracts 테이블이 성공적으로 생성되었습니다.<br>";
    } else {
        echo "LS_contracts 테이블 생성 중 오류 발생: " . $db->error . "<br>";
    }
} catch (Exception $e) {
    echo "LS_contracts 테이블 생성 중 예외 발생: " . $e->getMessage() . "<br>";
}
?> 