-- 포트원 결제 정보 저장 테이블
CREATE TABLE IF NOT EXISTS `v2_portone_payments` (
  `portone_payment_id` INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY COMMENT '포트원 결제 ID (자동증가)',
  `contract_history_id` INT(11) DEFAULT NULL COMMENT '계약 히스토리 ID (v3_contract_history와 연결)',
  `member_id` INT(11) NOT NULL COMMENT '회원 ID',
  `branch_id` VARCHAR(50) DEFAULT NULL COMMENT '지점 ID',
  
  -- 포트원 결제 기본 정보
  `portone_payment_uid` VARCHAR(100) NOT NULL COMMENT '포트원 결제 고유 ID (paymentId)',
  `portone_tx_id` VARCHAR(100) DEFAULT NULL COMMENT '포트원 거래 ID (txId)',
  `portone_store_id` VARCHAR(100) DEFAULT NULL COMMENT '포트원 상점 ID',
  `portone_channel_key` VARCHAR(100) DEFAULT NULL COMMENT '포트원 채널 키',
  
  -- 결제 정보
  `payment_amount` INT(11) NOT NULL COMMENT '결제 금액',
  `payment_currency` VARCHAR(10) DEFAULT 'KRW' COMMENT '결제 통화',
  `payment_method` VARCHAR(50) DEFAULT NULL COMMENT '결제 수단 (CARD, EASY_PAY, VIRTUAL_ACCOUNT 등)',
  `payment_provider` VARCHAR(50) DEFAULT NULL COMMENT 'PG사 (TOSSPAYMENTS, KAKAOPAY, INICIS_V2 등)',
  `order_name` VARCHAR(200) DEFAULT NULL COMMENT '주문명',
  
  -- 결제 상태
  `payment_status` VARCHAR(50) NOT NULL DEFAULT 'READY' COMMENT '결제 상태 (READY, PENDING, PAID, FAILED, CANCELLED)',
  `payment_status_message` VARCHAR(500) DEFAULT NULL COMMENT '결제 상태 메시지',
  
  -- 결제 시간 정보
  `payment_requested_at` DATETIME DEFAULT NULL COMMENT '결제 요청 시간',
  `payment_paid_at` DATETIME DEFAULT NULL COMMENT '결제 완료 시간',
  `payment_failed_at` DATETIME DEFAULT NULL COMMENT '결제 실패 시간',
  `payment_cancelled_at` DATETIME DEFAULT NULL COMMENT '결제 취소 시간',
  
  -- 취소 정보
  `cancel_reason` VARCHAR(500) DEFAULT NULL COMMENT '취소 사유',
  `cancel_amount` INT(11) DEFAULT NULL COMMENT '취소 금액',
  
  -- 추가 정보
  `custom_data` TEXT DEFAULT NULL COMMENT '커스텀 데이터 (JSON 형식)',
  `metadata` TEXT DEFAULT NULL COMMENT '메타데이터 (JSON 형식)',
  
  -- 생성/수정 시간
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '생성 시간',
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '수정 시간'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='포트원 결제 정보 테이블';

-- 인덱스 생성 (별도 문으로 분리하여 MariaDB 호환성 향상)
-- 테이블이 생성된 후에 실행됩니다
CREATE UNIQUE INDEX `idx_portone_payment_uid` ON `v2_portone_payments` (`portone_payment_uid`);
CREATE INDEX `idx_contract_history_id` ON `v2_portone_payments` (`contract_history_id`);
CREATE INDEX `idx_member_id` ON `v2_portone_payments` (`member_id`);
CREATE INDEX `idx_payment_status` ON `v2_portone_payments` (`payment_status`);
CREATE INDEX `idx_payment_requested_at` ON `v2_portone_payments` (`payment_requested_at`);

-- v3_contract_history 테이블에 포트원 결제 ID 필드 추가
-- MariaDB 호환: 컬럼이 이미 존재하면 에러가 발생하지만, 무시하고 진행해도 됩니다

-- 컬럼 추가 (이미 있으면 에러 발생, 무시해도 됨)
ALTER TABLE `v3_contract_history` 
ADD COLUMN `portone_payment_id` INT(11) DEFAULT NULL COMMENT '포트원 결제 ID (v2_portone_payments와 연결)' AFTER `payment_type`;

-- 인덱스 추가 (이미 있으면 에러 발생, 무시해도 됨)
ALTER TABLE `v3_contract_history` 
ADD INDEX `idx_portone_payment_id` (`portone_payment_id`);

