<?php
// 레슨 탭 컨텐츠 - member_form.php에서 불러와서 사용

// 단독 실행인지 확인 - 독립 실행 시 필요한 헤더 추가
$is_standalone = !isset($in_parent_page);
if ($is_standalone) {
    echo '<!DOCTYPE html>
    <html lang="ko">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>회원 레슨 정보</title>
        <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/5.15.3/css/all.min.css">
    </head>
    <body>
    <div class="container">
        <div class="page-actions">
            <h2 class="page-title">회원 레슨 관리</h2>
        </div>
    ';
}

// 데이터베이스 연결
require_once dirname(__FILE__) . '/../../config/db_connect.php';

// member_id가 GET으로 전달됐는지 확인
if (!isset($_GET['id'])) {
    echo '<div class="error-message">회원 ID가 전달되지 않았습니다.</div>';
    if ($is_standalone) echo '</div></body></html>';
    exit;
}

$member_id = intval($_GET['id']);

// 회원 정보 조회
$stmt = $db->prepare("SELECT member_id, member_name FROM members WHERE member_id = ?");
$stmt->bind_param('i', $member_id);
$stmt->execute();
$result = $stmt->get_result();

if ($result->num_rows === 0) {
    echo '<div class="error-message">회원 정보를 찾을 수 없습니다.</div>';
    if ($is_standalone) echo '</div></body></html>';
    exit;
}

$member = $result->fetch_assoc();

if ($is_standalone) {
    echo '<h3>' . htmlspecialchars($member['member_name']) . ' 회원의 레슨 정보</h3>';
}

try {
    // 레슨권 구매 정보 조회
    $lesson_query = "
        SELECT 
            LS_contract_id,
            LS_contract_qty,
            LS_contract_source,
            DATE(LS_contract_date) as contract_date,
            DATE(LS_expiry_date) as expiry_date,
            LS_type
        FROM LS_contracts 
        WHERE member_id = ?
        ORDER BY LS_contract_date DESC
    ";
    $stmt = $db->prepare($lesson_query);
    $stmt->bind_param('i', $member['member_id']);
    $stmt->execute();
    $lesson_contracts = $stmt->get_result();
    
    // 구매 레슨권 합계 계산
    $total_purchased = 0;
    if ($lesson_contracts->num_rows > 0) {
        $lesson_contracts_data = [];
        while ($contract = $lesson_contracts->fetch_assoc()) {
            $total_purchased += $contract['LS_contract_qty'];
            $lesson_contracts_data[] = $contract;
        }
        // 결과셋 처음으로 되돌리기
        $lesson_contracts->data_seek(0);
    }
    
    // 진행된 레슨 수 조회 (음수 값이므로 -1을 곱해 양수로 변환)
    $lesson_used_query = "
        SELECT 
            SUM(CASE WHEN LS_net_qty < 0 THEN LS_net_qty * -1 ELSE 0 END) as total_used
        FROM LS_countings 
        WHERE member_id = ? 
        AND (LS_counting_source = 'LS_orders' OR LS_counting_source = 'FMS_LS')
    ";
    $stmt = $db->prepare($lesson_used_query);
    $stmt->bind_param('i', $member['member_id']);
    $stmt->execute();
    $lesson_used_result = $stmt->get_result()->fetch_assoc();
    $total_used = $lesson_used_result['total_used'] ?: 0;
    
    // 첫번째 계약 후 잔여량 가져오기 (초기값)
    $initial_balance_query = "
        SELECT 
            LS_balance_after as initial_balance
        FROM LS_countings 
        WHERE member_id = ?
        AND LS_counting_source = 'LS_contracts'
        ORDER BY updated_at ASC 
        LIMIT 1
    ";
    $stmt = $db->prepare($initial_balance_query);
    $stmt->bind_param('i', $member['member_id']);
    $stmt->execute();
    $initial_balance_result = $stmt->get_result()->fetch_assoc();
    $initial_balance = $initial_balance_result ? $initial_balance_result['initial_balance'] : 0;
    
    // 계산된 잔여 레슨 수 (초기 잔여량에서 사용량 차감)
    $calculated_balance = $initial_balance - $total_used;
    
    // 실제 잔여 레슨 수 조회 (마지막 카운팅 레코드 기준)
    $actual_balance_query = "
        SELECT 
            LS_balance_after as actual_balance,
            updated_at,
            LS_id
        FROM LS_countings 
        WHERE member_id = ?
        ORDER BY LS_id DESC 
        LIMIT 1
    ";
    $stmt = $db->prepare($actual_balance_query);
    $stmt->bind_param('i', $member['member_id']);
    $stmt->execute();
    $actual_balance_result = $stmt->get_result()->fetch_assoc();
    $actual_balance = $actual_balance_result ? $actual_balance_result['actual_balance'] : 0;
    
    // 유효기간 조회 (가장 늦은 만료일자)
    $expiry_date_query = "
        SELECT 
            MAX(LS_expiry_date) as max_expiry_date,
            COUNT(*) as contract_count
        FROM LS_contracts 
        WHERE member_id = ?
    ";
    $stmt = $db->prepare($expiry_date_query);
    $stmt->bind_param('i', $member['member_id']);
    $stmt->execute();
    $expiry_date_result = $stmt->get_result()->fetch_assoc();
    $max_expiry_date = $expiry_date_result['max_expiry_date'] ? date('Y-m-d', strtotime($expiry_date_result['max_expiry_date'])) : '-';
    $has_lesson_contracts = $expiry_date_result['contract_count'] > 0;
    
    // 레슨권 만료 여부 확인 (잔여량이 0이거나 유효기간이 지난 경우)
    $is_expired = ($actual_balance <= 0 || ($max_expiry_date != '-' && strtotime($max_expiry_date) < strtotime('today')));
    
    // 불일치 확인
    $is_mismatch = ($calculated_balance != $actual_balance);
?>

<div class="lesson-list">
    <div class="lesson-stats">
        <div class="lesson-summary-grid">
            <div class="lesson-summary-item">
                <h4>구매 레슨권</h4>
                <span class="lesson-count <?php echo $is_expired ? 'expired' : ''; ?>"><?php echo number_format($total_purchased); ?>회</span>
            </div>
            <div class="lesson-summary-item">
                <h4>진행 레슨</h4>
                <span class="lesson-count <?php echo $is_expired ? 'expired' : ''; ?>"><?php echo number_format($total_used); ?>회</span>
            </div>
            <div class="lesson-summary-item <?php echo $is_mismatch ? 'mismatch' : ''; ?>">
                <h4>잔여 레슨</h4>
                <span class="lesson-count <?php echo $is_expired ? 'expired' : ''; ?>"><?php echo number_format($actual_balance); ?>회</span>
                <?php if ($is_mismatch): ?>
                <div class="mismatch-warning">
                    <i class="fa fa-exclamation-triangle"></i>
                    <span>데이터 불일치 (계산값: <?php echo number_format($calculated_balance); ?>회)</span>
                </div>
                <?php endif; ?>
            </div>
            <div class="lesson-summary-item">
                <h4>유효기간</h4>
                <span class="lesson-count <?php echo $is_expired ? 'expired' : ''; ?>"><?php echo $max_expiry_date; ?></span>
            </div>
        </div>
        
        <?php if (!$has_lesson_contracts): ?>
        <div class="alert alert-warning">
            <strong>알림:</strong> 레슨권 구매내역이 없습니다. 회원권 탭에서 레슨권이 포함된 회원권을 등록해주세요.
        </div>
        <?php endif; ?>
        
        <?php if ($is_mismatch): ?>
        <div class="alert alert-warning">
            <strong>경고:</strong> 레슨권 정보 불일치가 발견되었습니다. 구매(<?php echo number_format($total_purchased); ?>회) - 진행(<?php echo number_format($total_used); ?>회) = <?php echo number_format($calculated_balance); ?>회이나, 
            현재 잔여 레슨은 <?php echo number_format($actual_balance); ?>회로 기록되어 있습니다.
            <br>
            <strong>참고:</strong> 이 불일치는 일반적으로 레슨권 만료, 시스템 업데이트, 또는 수동 조정으로 인해 발생할 수 있습니다.
        </div>
        <?php endif; ?>
        
        <div class="lesson-actions">
            <button type="button" class="btn" onclick="openProChangeModal()"><i class="fas fa-user-edit"></i> 담당프로 변경</button>
            <button type="button" class="btn" onclick="openLessonDeductModal()"><i class="fas fa-minus-circle"></i> 레슨 차감</button>
            <button type="button" class="btn" onclick="viewLessonHistory()"><i class="fas fa-history"></i> 레슨 내역</button>
            <button type="button" class="btn" onclick="openExpiryDateModal()" <?php echo !$has_lesson_contracts ? 'disabled style="opacity: 0.6; cursor: not-allowed;"' : ''; ?>><i class="fas fa-calendar-alt"></i> 유효기간 변경</button>
        </div>
    </div>
</div>

<?php
} catch (mysqli_sql_exception $e) {
    // 에러 처리
    echo '<div class="under-construction">';
    echo '<h3>오류 발생</h3>';
    echo '<p>레슨권 정보를 불러오는 중 오류가 발생했습니다.</p>';
    echo '<p>테이블이 존재하지 않거나 데이터베이스 구조 변경으로 일시적으로 서비스가 중단되었습니다.</p>';
    echo '<p>시스템 관리자에게 문의하시기 바랍니다.</p>';
    echo '<p><small>오류 정보: ' . preg_replace('/Table \'[^\']*\'\./', 'Table ', $e->getMessage()) . '</small></p>';
    echo '</div>';
}
?>

<style>
/* 폰트 및 기본 스타일 */
@import url('https://fonts.googleapis.com/css2?family=Noto+Sans+KR:wght@300;400;500;700&display=swap');

:root {
    --primary-color: #3498db;
    --primary-dark: #2980b9;
    --danger-color: #e74c3c;
    --warning-color: #f8d7da;
    --warning-background: #fff8f8;
    --alert-warning-bg: #fff3cd;
    --alert-warning-color: #856404;
    --alert-warning-border: #ffeeba;
    --text-dark: #333;
    --text-muted: #666;
    --text-light: #999;
    --border-color: #eee;
    --background-light: #f8f9fa;
    --shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
}

.lesson-list, .modal, .form-group, .form-actions {
    font-family: 'Noto Sans KR', sans-serif;
    color: var(--text-dark);
}

/* 컨테이너 및 기본 레이아웃 */
.container {
    max-width: 1200px;
    margin: 0 auto;
    padding: 20px;
}

.page-actions {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 20px;
    padding-bottom: 10px;
    border-bottom: 1px solid var(--border-color);
}

.page-title {
    font-size: 24px;
    margin: 0;
    color: var(--text-dark);
    font-weight: 700;
}

/* 버튼 스타일 */
.btn, .btn-save {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    padding: 8px 16px;
    border-radius: 50px;
    cursor: pointer;
    font-size: 14px;
    font-weight: 700;
    text-decoration: none;
    text-align: center;
    border: none;
    transition: all 0.3s ease;
    box-shadow: 0 3px 6px rgba(0,0,0,0.1);
    gap: 6px;
    flex: 1;
    max-width: 180px;
    min-width: 140px;
}

/* 저장 버튼 (파란색 계열 그라데이션) */
.btn-save {
    background: linear-gradient(to right, #36d1dc, #5b86e5);
    color: white;
}

.btn-save:hover {
    background: linear-gradient(to right, #5b86e5, #36d1dc);
    transform: translateY(-2px);
    box-shadow: 0 5px 15px rgba(91, 134, 229, 0.4);
}

/* 일반 버튼 (하늘색 계열 그라데이션) */
.btn {
    background: linear-gradient(to right, #a1c4fd, #c2e9fb);
    color: #2c3e50;
}

.btn:hover {
    background: linear-gradient(to right, #c2e9fb, #a1c4fd);
    transform: translateY(-2px);
    box-shadow: 0 5px 15px rgba(161, 196, 253, 0.4);
}

.btn:disabled {
    opacity: 0.6;
    cursor: not-allowed;
    transform: none;
    box-shadow: none;
}

/* 레슨 요약 정보 스타일 */
.lesson-stats {
    background-color: #fff;
    border-radius: 8px;
    box-shadow: var(--shadow);
    padding: 20px;
    margin-bottom: 20px;
}

.lesson-summary-grid {
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: 20px;
    margin-bottom: 20px;
}

.lesson-summary-item {
    background-color: var(--background-light);
    border: 1px solid var(--border-color);
    border-radius: 6px;
    padding: 15px;
    text-align: center;
    transition: transform 0.2s, box-shadow 0.2s;
}

.lesson-summary-item:hover {
    transform: translateY(-2px);
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
}

.lesson-summary-item h4 {
    margin: 0 0 10px 0;
    color: var(--text-muted);
    font-size: 14px;
    font-weight: 600;
}

.lesson-count {
    display: block;
    font-size: 22px;
    font-weight: 700;
    color: var(--primary-color);
}

.lesson-count.expired {
    color: var(--danger-color);
}

.mismatch {
    position: relative;
    border: 1px solid var(--warning-color);
    background-color: var(--warning-background);
}

.mismatch-warning {
    font-size: 12px;
    color: var(--danger-color);
    margin-top: 8px;
}

.mismatch-warning i {
    margin-right: 5px;
}

.alert {
    padding: 15px;
    margin-bottom: 20px;
    border: 1px solid transparent;
    border-radius: 4px;
}

.alert-warning {
    color: var(--alert-warning-color);
    background-color: var(--alert-warning-bg);
    border-color: var(--alert-warning-border);
}

.lesson-actions {
    display: flex;
    flex-wrap: wrap;
    gap: 10px;
    margin-top: 20px;
    justify-content: space-between;
}

.under-construction {
    background-color: var(--background-light);
    border: 1px solid var(--border-color);
    border-radius: 6px;
    padding: 30px;
    text-align: center;
    margin-top: 20px;
}

.under-construction h3 {
    color: var(--danger-color);
    margin-bottom: 15px;
}

.under-construction p {
    color: var(--text-muted);
    margin-bottom: 10px;
}

.under-construction p small {
    font-size: 12px;
    color: var(--text-light);
}

/* 반응형 스타일 */
@media (max-width: 768px) {
    .lesson-summary-grid {
        grid-template-columns: repeat(2, 1fr);
    }
    
    .modal-content {
        width: 95%;
        margin: 10% auto;
    }
    
    .lesson-actions {
        flex-direction: column;
        align-items: stretch;
    }
    
    .btn, .btn-save {
        max-width: none;
    }
}

@media (max-width: 480px) {
    .lesson-summary-grid {
        grid-template-columns: 1fr;
    }
}

/* 프로 모달 스타일 - 새 버전 */
#proChangeModal {
    display: none;
    position: fixed;
    z-index: 1000;
    left: 0;
    top: 0;
    width: 100%;
    height: 100%;
    overflow: auto;
    background-color: rgba(0,0,0,0.4);
}

#proChangeModal .modal-content {
    position: relative;
    background-color: #fefefe;
    margin: 5% auto;
    padding: 20px;
    border: 1px solid #888;
    width: 80%;
    max-width: 600px;
    border-radius: 5px;
    box-shadow: 0 4px 8px rgba(0,0,0,0.1);
}

#proChangeModal h2 {
    margin-top: 0;
    margin-bottom: 20px;
    color: #333;
    border-bottom: 1px solid #eee;
    padding-bottom: 10px;
}

#proList {
    max-height: 350px;
    overflow-y: auto;
    border: 1px solid #eee;
    border-radius: 5px;
    padding: 10px;
    margin-bottom: 20px;
}

.pro-item {
    display: flex;
    align-items: center;
    padding: 10px;
    border-bottom: 1px solid #eee;
}

.pro-item:last-child {
    border-bottom: none;
}

.pro-item label {
    display: flex;
    align-items: center;
    cursor: pointer;
    margin: 0;
    font-weight: normal;
}

.pro-item input[type="checkbox"] {
    margin-right: 10px;
}

.pro-status {
    margin-left: auto;
    padding: 3px 8px;
    border-radius: 4px;
    font-size: 12px;
}

.pro-status.active {
    background-color: #d4edda;
    color: #155724;
}

.pro-status.inactive {
    background-color: #f8d7da;
    color: #721c24;
}

.loading-message {
    text-align: center;
    padding: 20px;
    color: #6c757d;
}

.pro-modal-buttons {
    display: flex;
    justify-content: flex-end;
    gap: 10px;
    margin-top: 20px;
}

.pro-modal-buttons button {
    padding: 8px 16px;
    border: none;
    border-radius: 4px;
    cursor: pointer;
}

.pro-modal-buttons .cancel-btn {
    background-color: #f0f0f0;
    color: #333;
}

.pro-modal-buttons .save-btn {
    background-color: var(--primary-color);
    color: white;
}

.error-message {
    color: #721c24;
    background-color: #f8d7da;
    border: 1px solid #f5c6cb;
    padding: 10px;
    border-radius: 4px;
    margin-bottom: 15px;
}
</style>

<script>
document.addEventListener('DOMContentLoaded', function() {
    // 모달과 함수를 동적으로 추가
    addLessonHistoryModal();
    
    // 모달 닫기 버튼에 이벤트 리스너 추가
    const closeButtons = document.querySelectorAll('.modal .close');
    closeButtons.forEach((button) => {
        button.addEventListener('click', function() {
            const modal = this.closest('.modal');
            if (modal) {
                modal.style.display = 'none';
            }
        });
    });
    
    // 레슨 히스토리 모달 닫기 버튼
    const closeLessonHistoryBtn = document.getElementById('closeLessonHistoryModal');
    if (closeLessonHistoryBtn) {
        closeLessonHistoryBtn.addEventListener('click', function() {
            document.getElementById('lessonHistoryModal').style.display = 'none';
        });
    }
    
    // 유효기간 변경 취소 버튼
    const cancelExpiryBtn = document.getElementById('cancelExpiryBtn');
    if (cancelExpiryBtn) {
        cancelExpiryBtn.addEventListener('click', function() {
            closeModal('expiryDateModal');
        });
    }
    
    // 창 클릭 시 모달 닫기
    window.addEventListener('click', function(event) {
        const modals = document.querySelectorAll('.modal');
        modals.forEach(function(modal) {
            if (event.target === modal) {
                modal.style.display = 'none';
            }
        });
    });
});

// 레슨 내역 모달 HTML 추가
function addLessonHistoryModal() {
    const modalHtml = `
        <div id="lessonHistoryModal" class="modal">
            <div class="modal-content" style="width: 90%; max-width: 1000px;">
                <div class="modal-header">
                    <h2>레슨 내역</h2>
                    <span class="close" onclick="closeLessonHistoryModal()">&times;</span>
                </div>
                <div class="data-table-container">
                    <table class="data-table lesson-history-table">
                        <thead>
                            <tr>
                                <th style="width: 5%;">No</th>
                                <th style="width: 15%;">일자</th>
                                <th style="width: 12%;">프로명</th>
                                <th style="width: 10%;">시작시간</th>
                                <th style="width: 10%;">종료시간</th>
                                <th style="width: 8%;">유형</th>
                                <th style="width: 10%;">수량</th>
                                <th style="width: 10%;">잔여량</th>
                            </tr>
                        </thead>
                        <tbody id="lessonHistoryTableBody">
                        </tbody>
                    </table>
                </div>
                <div class="modal-actions">
                    <button type="button" class="btn" onclick="closeLessonHistoryModal()">닫기</button>
                </div>
            </div>
        </div>
        <style>
            .lesson-history-table {
                width: 100%;
                border-collapse: collapse;
                font-size: 14px;
            }
            
            .lesson-history-table th, 
            .lesson-history-table td {
                padding: 10px 8px;
                text-align: center;
                border: 1px solid #ddd;
            }
            
            .lesson-history-table th {
                background-color: #f8f9fa;
                font-weight: bold;
                position: sticky;
                top: 0;
                z-index: 10;
            }
            
            .lesson-history-table tr:nth-child(even) {
                background-color: #f9f9f9;
            }
            
            .lesson-history-table tr:hover {
                background-color: #f1f1f1;
            }
            
            #lessonHistoryModal .modal-header {
                display: flex;
                justify-content: space-between;
                align-items: center;
                margin-bottom: 15px;
                padding-bottom: 10px;
                border-bottom: 1px solid #ddd;
            }
            
            #lessonHistoryModal .modal-header h2 {
                margin: 0;
                font-size: 20px;
                color: #333;
            }
            
            #lessonHistoryModal .close {
                font-size: 24px;
                font-weight: bold;
                cursor: pointer;
                color: #888;
            }
            
            #lessonHistoryModal .close:hover {
                color: #333;
            }
            
            #lessonHistoryModal .modal-actions {
                text-align: center;
                margin-top: 15px;
                padding-top: 10px;
                border-top: 1px solid #ddd;
            }
            
            #lessonHistoryModal .data-table-container {
                max-height: 70vh;
                overflow-y: auto;
                overflow-x: hidden;
            }
        </style>`;

    document.body.insertAdjacentHTML('beforeend', modalHtml);
    
    // 유효기간 변경 모달 추가
    const expiryDateModalHtml = `
        <div id="expiryDateModal" class="modal">
            <div class="modal-content" style="width: 500px;">
                <div class="modal-header">
                    <h2>레슨권 유효기간 변경</h2>
                </div>
                <div class="modal-body" style="padding: 20px;">
                    <div class="form-group" style="margin-bottom: 20px;">
                        <label for="currentExpiryDate" style="display: block; font-size: 16px; margin-bottom: 8px; font-weight: bold;">현재 유효기간</label>
                        <input type="text" id="currentExpiryDate" class="form-control" value="<?php echo $max_expiry_date; ?>" readonly style="width: 100%; padding: 10px; font-size: 16px; background: #f8f9fa; border: 1px solid #ddd; border-radius: 4px;">
                    </div>
                    
                    <div class="form-group">
                        <label for="newExpiryDate" style="display: block; font-size: 16px; margin-bottom: 8px; font-weight: bold;">새 유효기간</label>
                        <input type="date" id="newExpiryDate" class="form-control" value="<?php echo $max_expiry_date; ?>" style="width: 100%; padding: 10px; font-size: 16px; border: 1px solid #ddd; border-radius: 4px;">
                        <p style="margin-top: 10px; font-size: 14px; color: #666;">
                            * 설정한 날짜는 해당 회원의 모든 레슨권에 적용됩니다.
                        </p>
                    </div>
                </div>
                <div class="modal-actions" style="padding: 15px; text-align: center; border-top: 1px solid #ddd; margin-top: 10px;">
                    <button type="button" class="btn" onclick="updateExpiryDate()" style="padding: 10px 20px; font-size: 16px; margin-right: 10px;">변경</button>
                    <button type="button" class="btn" onclick="closeExpiryDateModal()" style="padding: 10px 20px; font-size: 16px;">취소</button>
                </div>
            </div>
        </div>
        
        <style>
            #expiryDateModal .modal-content {
                border-radius: 8px;
                box-shadow: 0 5px 15px rgba(0,0,0,0.3);
            }
            
            #expiryDateModal .modal-header {
                padding: 15px 20px;
                border-bottom: 1px solid #ddd;
            }
            
            #expiryDateModal .modal-header h2 {
                margin: 0;
                font-size: 20px;
                color: #333;
            }
            
            #expiryDateModal .btn {
                background-color: #007bff;
                color: white;
                border: none;
                cursor: pointer;
                transition: background-color 0.3s;
            }
            
            #expiryDateModal .btn:hover {
                background-color: #0069d9;
            }
            
            #expiryDateModal .btn:last-child {
                background-color: #6c757d;
            }
            
            #expiryDateModal .btn:last-child:hover {
                background-color: #5a6268;
            }
        </style>`;
        
    document.body.insertAdjacentHTML('beforeend', expiryDateModalHtml);

    // 담당 프로 변경 모달 추가
    const proChangeModalHtml = `
        <div id="proChangeModal" class="modal">
            <div class="modal-content" style="width: 500px;">
                <div class="modal-header">
                    <h2>담당 프로 변경</h2>
                </div>
                <div class="modal-body" style="padding: 20px;">
                    <p style="margin-bottom: 15px; font-size: 14px; color: #666;">
                        * 체크된 프로가 담당 프로입니다. 변경하려면 체크를 해제하거나 다른 프로를 선택하세요.
                    </p>
                    <div id="proList" style="max-height: 300px; overflow-y: auto; border: 1px solid #ddd; border-radius: 4px; padding: 10px;">
                        <div class="loading-message">프로 목록을 불러오는 중...</div>
                    </div>
                </div>
                <div class="modal-actions" style="padding: 15px; text-align: center; border-top: 1px solid #ddd; margin-top: 10px;">
                    <button type="button" class="btn" onclick="saveProChanges()" style="padding: 10px 20px; font-size: 16px; margin-right: 10px;">저장</button>
                    <button type="button" class="btn" onclick="closeProChangeModal()" style="padding: 10px 20px; font-size: 16px;">취소</button>
                </div>
            </div>
        </div>
        
        <style>
            #proChangeModal .modal-content {
                border-radius: 8px;
                box-shadow: 0 5px 15px rgba(0,0,0,0.3);
            }
            
            #proChangeModal .modal-header {
                padding: 15px 20px;
                border-bottom: 1px solid #ddd;
            }
            
            #proChangeModal .modal-header h2 {
                margin: 0;
                font-size: 20px;
                color: #333;
            }
            
            #proChangeModal .btn {
                background-color: #007bff;
                color: white;
                border: none;
                cursor: pointer;
                transition: background-color 0.3s;
            }
            
            #proChangeModal .btn:hover {
                background-color: #0069d9;
            }
            
            #proChangeModal .btn:last-child {
                background-color: #6c757d;
            }
            
            #proChangeModal .btn:last-child:hover {
                background-color: #5a6268;
            }
            
            .pro-item {
                display: flex;
                align-items: center;
                padding: 12px;
                border-bottom: 1px solid #eee;
            }
            
            .pro-item:last-child {
                border-bottom: none;
            }
            
            .pro-item label {
                display: flex;
                align-items: center;
                cursor: pointer;
                margin: 0;
                font-weight: normal;
                font-size: 16px;
            }
            
            .pro-item input[type="checkbox"] {
                margin-right: 10px;
                width: 18px;
                height: 18px;
            }
            
            .pro-status {
                margin-left: auto;
                padding: 3px 8px;
                border-radius: 4px;
                font-size: 12px;
            }
            
            .pro-status.active {
                background-color: #d4edda;
                color: #155724;
            }
            
            .pro-status.inactive {
                background-color: #f8d7da;
                color: #721c24;
            }
            
            .loading-message {
                text-align: center;
                padding: 20px;
                color: #6c757d;
            }
        </style>`;
        
    document.body.insertAdjacentHTML('beforeend', proChangeModalHtml);
}

function viewLessonHistory() {
    const memberId = <?php echo isset($member['member_id']) ? $member['member_id'] : 0; ?>;
    
    // 실행 모드에 따른 기본 경로 설정
    const basePath = <?php echo $is_standalone ? "'./'" : "'member_form_tabs_and_process/'"; ?>;
    
    // 새 창으로 레슨 내역 페이지 열기
    const lessonHistoryUrl = `${basePath}lesson_history_popup.php?member_id=${memberId}`;
    window.open(lessonHistoryUrl, 'lessonHistory', 'width=1000,height=700,resizable=yes,scrollbars=yes');
}

function openExpiryDateModal() {
    const hasLessonContracts = <?php echo $has_lesson_contracts ? 'true' : 'false'; ?>;
    
    if (!hasLessonContracts) {
        alert('레슨권 구매내역이 없습니다. 회원권 탭에서 레슨권이 포함된 회원권을 등록해주세요.');
        return;
    }
    
    // 새 창으로 유효기간 변경 페이지 열기
    const memberId = <?php echo isset($member['member_id']) ? $member['member_id'] : 0; ?>;
    const currentExpiryDate = '<?php echo $max_expiry_date; ?>';
    
    // 실행 모드에 따른 기본 경로 설정
    const basePath = <?php echo $is_standalone ? "'./'" : "'member_form_tabs_and_process/'"; ?>;
    
    const expiryDateUrl = `${basePath}expiry_date_popup.php?member_id=${memberId}&current_expiry=${currentExpiryDate}`;
    window.open(expiryDateUrl, 'expiryDateChange', 'width=500,height=400,resizable=yes,scrollbars=yes');
}

function openProChangeModal() {
    // 새 창으로 담당프로 변경 페이지 열기
    const memberId = <?php echo isset($member['member_id']) ? $member['member_id'] : 0; ?>;
    
    // 실행 모드에 따른 기본 경로 설정
    const basePath = <?php echo $is_standalone ? "'./'" : "'member_form_tabs_and_process/'"; ?>;
    
    const proChangeUrl = `${basePath}pro_change_popup.php?member_id=${memberId}`;
    window.open(proChangeUrl, 'proChange', 'width=500,height=600,resizable=yes,scrollbars=yes');
}

// 모달 관련 함수들은 더 이상 필요하지 않지만 JavaScript 오류 방지를 위해 빈 함수 유지
function closeLessonHistoryModal() {}
function closeExpiryDateModal() {}
function closeProChangeModal() {}
function addLessonHistoryModal() {}

// 레슨 차감 함수 추가
function openLessonDeductModal() {
    // 새 창 열기
    window.open('about:blank', 'underConstruction', 'width=400,height=300,resizable=yes,scrollbars=yes').document.write(`
        <!DOCTYPE html>
        <html lang="ko">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>공사 중</title>
            <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/5.15.3/css/all.min.css">
            <style>
                @import url('https://fonts.googleapis.com/css2?family=Noto+Sans+KR:wght@300;400;500;700&display=swap');
                
                body {
                    font-family: 'Noto Sans KR', sans-serif;
                    background-color: #f8f9fa;
                    color: #333;
                    padding: 20px;
                    margin: 0;
                    display: flex;
                    flex-direction: column;
                    align-items: center;
                    justify-content: center;
                    min-height: 100vh;
                    box-sizing: border-box;
                    text-align: center;
                }
                
                .construction-container {
                    background-color: white;
                    border-radius: 8px;
                    box-shadow: 0 4px 15px rgba(0,0,0,0.1);
                    padding: 25px;
                    max-width: 100%;
                    width: 100%;
                }
                
                .icon {
                    font-size: 48px;
                    color: #e74c3c;
                    margin-bottom: 20px;
                }
                
                h2 {
                    margin-top: 0;
                    margin-bottom: 15px;
                    color: #2c3e50;
                }
                
                p {
                    color: #7f8c8d;
                    line-height: 1.5;
                    margin-bottom: 20px;
                }
                
                .btn {
                    background: linear-gradient(to right, #a1c4fd, #c2e9fb);
                    color: #2c3e50;
                    border: none;
                    padding: 10px 20px;
                    border-radius: 50px;
                    cursor: pointer;
                    font-weight: 700;
                    transition: all 0.3s ease;
                }
                
                .btn:hover {
                    background: linear-gradient(to right, #c2e9fb, #a1c4fd);
                    transform: translateY(-2px);
                    box-shadow: 0 5px 15px rgba(161, 196, 253, 0.4);
                }
            </style>
        </head>
        <body>
            <div class="construction-container">
                <div class="icon">
                    <i class="fas fa-tools"></i>
                </div>
                <h2>기능 준비 중</h2>
                <p>레슨 차감 기능은 현재 개발 중입니다.</p>
                <p>빠른 시일 내에 서비스를 제공해 드리겠습니다.</p>
                <button class="btn" onclick="window.close()">닫기</button>
            </div>
        </body>
        </html>
    `);
}
</script>

<?php
// 독립 실행 시 HTML 닫기 태그 추가
if ($is_standalone) {
    echo '</div></body></html>';
}
?> 