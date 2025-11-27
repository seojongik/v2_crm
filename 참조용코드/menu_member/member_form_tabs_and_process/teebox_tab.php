<?php
// 티박스 탭 컨텐츠 - member_form.php에서 불러와서 사용

// 파일이 직접 실행되는지 include되는지 확인
$is_standalone = !isset($in_parent_page);

// 직접 실행된 경우, 필요한 파일 포함 및 초기화
if ($is_standalone) {
    // 데이터베이스 연결
    require_once '../../config/db_connect.php';
    
    // member_id가 GET으로 전달됐는지 확인
    if (!isset($_GET['id'])) {
        echo '<div class="error-message">회원 ID가 전달되지 않았습니다.</div>';
        exit;
    }
    
    $member_id = intval($_GET['id']);
} else {
    // 부모 페이지에서 include된 경우 (member_form.php에서 호출)
    // 데이터베이스 연결은 이미 되어 있고, member_id도 부모 페이지에서 설정됨
    if (!isset($member_id) || !isset($db)) {
        echo '<div class="error-message">필요한 변수가 전달되지 않았습니다.</div>';
        exit;
    }
}

// 회원 정보 조회
$stmt = $db->prepare("SELECT member_id, member_name FROM members WHERE member_id = ?");
$stmt->bind_param('i', $member_id);
$stmt->execute();
$result = $stmt->get_result();

if ($result->num_rows === 0) {
    echo '<div class="error-message">회원 정보를 찾을 수 없습니다.</div>';
    exit;
}

$member = $result->fetch_assoc();

// Priced_FMS 테이블에서 해당 회원의 티박스 이용 내역 조회
$usage_query = "
    SELECT 
        reservation_id,
        ts_id,
        ts_date,
        ts_start,
        ts_end,
        ts_type,
        total_amt,
        term_discount,
        junior_discount,
        overtime_discount,
        revisit_discount_today,
        emergency_discount,
        total_discount,
        net_amt,
        revisit_date,
        revisit_discount,
        morning,
        normal,
        peak,
        night,
        ts_min,
        time_stamp
    FROM Priced_FMS
    WHERE member_id = ? AND ts_type = '결제완료'
    ORDER BY ts_date DESC, ts_start DESC
    LIMIT 50
";

$stmt = $db->prepare($usage_query);
$stmt->bind_param('i', $member_id);
$stmt->execute();
$usage_result = $stmt->get_result();
?>

<div class="teebox-tab">
    <div class="tab-header">
        <div class="header-flex">
            <div class="title-and-info">
                <h3 class="inline-title"></h3>
                <span class="member-info"><span class="member-name"><?php echo htmlspecialchars($member['member_name']); ?></span> 회원님의 타석 이용 기록입니다.</span>
            </div>
            <div class="action-buttons">
                <button type="button" class="emergency-discount-btn" onclick="showEmergencyDiscountList()">긴급할인등록</button>
            </div>
        </div>
    </div>
    
    <div class="usage-history">
        <div class="table-container">
            <table class="usage-table" style="width:100%; border-collapse:collapse; table-layout:fixed;">
                <colgroup>
                    <col style="width:15%"> <!-- 예약번호 -->
                    <col style="width:5%">  <!-- 타석 -->
                    <col style="width:12%"> <!-- 이용일자 -->
                    <col style="width:8%">  <!-- 시작시간 -->
                    <col style="width:8%">  <!-- 종료시간 -->
                    <col style="width:14%"> <!-- 총 금액 -->
                    <col style="width:14%"> <!-- 총 할인 -->
                    <col style="width:14%"> <!-- 순액 -->
                    <col style="width:10%"> <!-- 조회 -->
                </colgroup>
                <thead>
                    <tr>
                        <th>예약번호</th>
                        <th>타석</th>
                        <th>이용일자</th>
                        <th>시작시간</th>
                        <th>종료시간</th>
                        <th>총 금액</th>
                        <th>총 할인</th>
                        <th>순액</th>
                        <th>조회</th>
                    </tr>
                </thead>
                <tbody>
                    <?php
                    if ($usage_result->num_rows === 0) {
                        echo '<tr><td colspan="9" class="no-data">이용 내역이 없습니다.</td></tr>';
                    } else {
                        while ($usage = $usage_result->fetch_assoc()) : 
                    ?>
                    <tr>
                        <td><?php echo htmlspecialchars($usage['reservation_id']); ?></td>
                        <td class="text-center"><?php echo htmlspecialchars($usage['ts_id'] ?: '-'); ?></td>
                        <td class="text-center"><?php echo date('Y-m-d', strtotime($usage['ts_date'])); ?></td>
                        <td class="text-center"><?php echo date('H:i', strtotime($usage['ts_start'])); ?></td>
                        <td class="text-center"><?php echo date('H:i', strtotime($usage['ts_end'])); ?></td>
                        <td class="text-right"><?php echo number_format($usage['total_amt']); ?>원</td>
                        <td class="text-right"><?php echo number_format($usage['total_discount']); ?>원</td>
                        <td class="text-right"><?php echo number_format($usage['net_amt']); ?>원</td>
                        <td class="text-center">
                            <button type="button" class="detail-btn" onclick="showTeeboxDetail(<?php echo htmlspecialchars(json_encode($usage)); ?>)">조회</button>
                        </td>
                    </tr>
                    <?php 
                        endwhile;
                    } 
                    ?>
                </tbody>
            </table>
        </div>
    </div>
</div>

<!-- 타석이용 상세정보 모달 -->
<div id="teeboxDetailModal" class="modal">
    <div class="modal-content">
        <div class="modal-header">
            <h2>타석이용 상세정보</h2>
            <span class="close" onclick="closeTeeboxDetailModal()">&times;</span>
        </div>
        <div class="detail-grid">
            <div class="detail-section">
                <h3>예약 정보</h3>
                <table class="detail-table">
                    <tbody>
                        <tr>
                            <th width="150">예약번호</th>
                            <td id="detail-reservation-id"></td>
                        </tr>
                        <tr>
                            <th width="150">이용일자</th>
                            <td id="detail-ts-date"></td>
                        </tr>
                        <tr>
                            <th width="150">타석번호</th>
                            <td id="detail-ts-id"></td>
                        </tr>
                        <tr>
                            <th width="150">시작시간</th>
                            <td id="detail-ts-start"></td>
                        </tr>
                        <tr>
                            <th width="150">종료시간</th>
                            <td id="detail-ts-end"></td>
                        </tr>
                        <tr>
                            <th width="150">상태</th>
                            <td id="detail-ts-type"></td>
                        </tr>
                        <tr>
                            <th width="150">기록 일시</th>
                            <td id="detail-time-stamp"></td>
                        </tr>
                    </tbody>
                </table>
            </div>
            
            <div class="detail-section">
                <h3>요금 정보</h3>
                <table class="detail-table">
                    <tbody>
                        <tr>
                            <th width="150">총금액</th>
                            <td id="detail-total-amt"></td>
                        </tr>
                        <tr>
                            <th width="150">총 할인</th>
                            <td id="detail-total-discount"></td>
                        </tr>
                        <tr>
                            <th width="150">결제금액</th>
                            <td id="detail-net-amt"></td>
                        </tr>
                    </tbody>
                </table>
            </div>
            
            <div class="detail-section">
                <h3>할인 내역</h3>
                <table class="detail-table">
                    <tbody>
                        <tr>
                            <th width="150">기간권 할인</th>
                            <td id="detail-term-discount"></td>
                        </tr>
                        <tr>
                            <th width="150">주니어 할인</th>
                            <td id="detail-junior-discount"></td>
                        </tr>
                        <tr>
                            <th width="150">집중연습할인</th>
                            <td id="detail-overtime-discount"></td>
                        </tr>
                        <tr>
                            <th width="150">재방문 할인</th>
                            <td id="detail-revisit-discount"></td>
                        </tr>
                        <tr>
                            <th width="150">긴급 할인</th>
                            <td id="detail-emergency-discount"></td>
                        </tr>
                        <tr>
                            <th width="150">긴급할인 사유</th>
                            <td id="detail-emergency-reason"></td>
                        </tr>
                        <tr class="total-row">
                            <th width="150">할인 합계</th>
                            <td id="detail-discount-total"></td>
                        </tr>
                    </tbody>
                </table>
            </div>
            
            <div class="detail-section">
                <h3>시간대별 이용 (분)</h3>
                <table class="detail-table">
                    <tbody>
                        <tr>
                            <th width="150">총 이용시간</th>
                            <td id="detail-ts-min"></td>
                        </tr>
                        <tr>
                            <th width="150">조조</th>
                            <td id="detail-morning"></td>
                        </tr>
                        <tr>
                            <th width="150">일반</th>
                            <td id="detail-normal"></td>
                        </tr>
                        <tr>
                            <th width="150">피크</th>
                            <td id="detail-peak"></td>
                        </tr>
                        <tr>
                            <th width="150">심야</th>
                            <td id="detail-night"></td>
                        </tr>
                    </tbody>
                </table>
            </div>
        </div>
        <div class="modal-actions">
            <button type="button" class="btn-cancel" onclick="closeTeeboxDetailModal()">닫기</button>
        </div>
    </div>
</div>

<!-- 긴급할인 모달 -->
<div id="emergencyDiscountListModal" class="modal">
    <div class="modal-content">
        <div class="modal-header">
            <h2>오늘자 타석이용 목록</h2>
            <span class="close" onclick="closeEmergencyDiscountListModal()">&times;</span>
        </div>
        <div class="table-responsive">
            <table class="table table-striped usage-table" id="todayUsageTable" style="width:100%; border-collapse:collapse; table-layout:fixed;">
                <colgroup>
                    <col style="width:12%"> <!-- 예약번호 -->
                    <col style="width:5%">  <!-- 타석 -->
                    <col style="width:10%"> <!-- 이용일자 -->
                    <col style="width:8%">  <!-- 시작시간 -->
                    <col style="width:8%">  <!-- 종료시간 -->
                    <col style="width:12%"> <!-- 총금액 -->
                    <col style="width:12%"> <!-- 총 할인 -->
                    <col style="width:12%"> <!-- 순액 -->
                    <col style="width:7%">  <!-- 긴급할인 -->
                    <col style="width:10%"> <!-- 선택 -->
                </colgroup>
                <thead>
                    <tr>
                        <th>예약번호</th>
                        <th>타석</th>
                        <th>이용일자</th>
                        <th>시작시간</th>
                        <th>종료시간</th>
                        <th>총금액</th>
                        <th>총 할인</th>
                        <th>순액</th>
                        <th>긴급할인</th>
                        <th>선택</th>
                    </tr>
                </thead>
                <tbody id="todayUsageList">
                    <!-- 실시간으로 로드됨 -->
                </tbody>
            </table>
        </div>
    </div>
</div>

<!-- 긴급할인 등록 모달 -->
<div id="emergencyDiscountModal" class="modal">
    <div class="modal-content">
        <div class="emergency-modal-header">
            <h2>긴급할인 등록</h2>
            <button type="button" class="close-btn" onclick="closeEmergencyDiscountModal()">
                <svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                    <path d="M18 6L6 18" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                    <path d="M6 6L18 18" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                </svg>
            </button>
        </div>
        <div class="emergency-modal-body">
            <div class="emergency-form">
                <div class="emergency-form-group">
                    <label for="selected-reservation-id">선택된 예약번호</label>
                    <div class="emergency-input-wrap readonly">
                        <input type="text" id="selected-reservation-id" readonly>
                    </div>
                </div>
                <div class="emergency-form-group">
                    <label for="emergency-discount-amount">긴급할인 금액(원)</label>
                    <div class="emergency-input-wrap">
                        <input type="number" id="emergency-discount-amount" min="0" placeholder="0">
                    </div>
                </div>
                <div class="emergency-form-group">
                    <label for="emergency-discount-reason">할인 사유</label>
                    <div class="emergency-input-wrap">
                        <textarea id="emergency-discount-reason" placeholder="할인 사유를 입력하세요" rows="3"></textarea>
                    </div>
                </div>
            </div>
        </div>
        <div class="emergency-modal-footer">
            <div class="emergency-modal-actions">
                <button type="button" class="btn-cancel" onclick="closeEmergencyDiscountModal()">취소</button>
                <button type="button" class="btn-save" onclick="saveEmergencyDiscount()">등록</button>
            </div>
        </div>
    </div>
</div>

<style>
/* 티박스 탭 전체 스타일 */
.teebox-tab {
    padding: 20px;
    font-family: 'Noto Sans KR', sans-serif;
}

/* 폰트 통일 */
* {
    font-family: 'Noto Sans KR', sans-serif;
}

.tab-header {
    margin-bottom: 20px;
}

.header-flex {
    display: flex;
    justify-content: space-between;
    align-items: center;
    background-color: #f8f9fa;
    padding: 12px 20px;
    border-radius: 8px;
    box-shadow: 0 1px 3px rgba(0,0,0,0.1);
}

.title-and-info {
    display: flex;
    align-items: center;
    gap: 15px;
}

.inline-title {
    margin: 0;
    font-size: 18px;
    color: #2c3e50;
    white-space: nowrap;
}

.member-info {
    font-size: 14px;
    color: #555;
}

.member-name {
    font-weight: 600;
    color: #3498db;
}

.action-buttons {
    display: flex;
    gap: 10px;
}

.emergency-discount-btn {
    background-color: #e74c3c;
    color: white;
    border: none;
    padding: 8px 16px;
    border-radius: 4px;
    cursor: pointer;
    font-weight: 600;
    font-size: 13px;
    transition: background-color 0.2s;
}

.emergency-discount-btn:hover {
    background-color: #c0392b;
}

/* 반응형 스타일 */
@media (max-width: 768px) {
    .header-flex {
        flex-direction: column;
        align-items: flex-start;
        gap: 10px;
    }
    
    .title-and-info {
        flex-direction: column;
        align-items: flex-start;
        gap: 5px;
    }
    
    .action-buttons {
        width: 100%;
        justify-content: flex-end;
    }
}

/* 테이블 스타일 */
.table-container {
    overflow-x: auto;
    margin-bottom: 20px;
    border-radius: 5px;
    box-shadow: 0 2px 5px rgba(0,0,0,0.1);
}

.teebox-tab .usage-table {
    width: 100%;
    border-collapse: collapse;
    font-size: 13px;
    background-color: white;
    table-layout: fixed;
}

.teebox-tab .usage-table th:nth-child(1) {
    width: 15%;
}

.teebox-tab .usage-table th:nth-child(2) {
    width: 5%;
}

.teebox-tab .usage-table th:nth-child(3) {
    width: 12%;
}

.teebox-tab .usage-table th:nth-child(4),
.teebox-tab .usage-table th:nth-child(5) {
    width: 8%;
}

.teebox-tab .usage-table th:nth-child(6),
.teebox-tab .usage-table th:nth-child(7),
.teebox-tab .usage-table th:nth-child(8) {
    width: 14%;
}

.teebox-tab .usage-table th:nth-child(9) {
    width: 10%;
}

.usage-table th, 
.usage-table td {
    padding: 10px 12px;
    border: 1px solid #e0e0e0;
}

.usage-table th {
    background-color: #f0f8ff;
    font-weight: 700;
    text-align: center;
    color: #333;
    position: sticky;
    top: 0;
}

.usage-table tr:hover {
    background-color: #f5f9ff;
}

.usage-table tbody tr:nth-child(even) {
    background-color: #f9f9f9;
}

.text-center {
    text-align: center;
}

.text-right {
    text-align: right;
}

.no-data {
    text-align: center;
    font-style: italic;
    color: #777;
    padding: 20px 0;
}

/* 버튼 기본 스타일 */
.btn, .btn-save, .detail-btn, .emergency-discount-btn, .select-btn {
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

/* 긴급할인 버튼 (빨간색 계열 그라데이션) */
.emergency-discount-btn {
    background: linear-gradient(to right, #ff6b6b, #ee5253);
    color: white;
    font-size: 13px;
}

.emergency-discount-btn:hover {
    background: linear-gradient(to right, #ee5253, #ff6b6b);
    transform: translateY(-2px);
    box-shadow: 0 5px 15px rgba(238, 82, 83, 0.4);
}

/* 상세보기 버튼 (작은 버튼) */
.detail-btn {
    padding: 4px 10px;
    font-size: 11px;
    background: linear-gradient(to right, #74b9ff, #0984e3);
    color: white;
}

.detail-btn:hover {
    background: linear-gradient(to right, #0984e3, #74b9ff);
    transform: translateY(-2px);
    box-shadow: 0 3px 10px rgba(9, 132, 227, 0.4);
}

/* 선택 버튼 */
.select-btn {
    padding: 5px 10px;
    font-size: 12px;
    background: linear-gradient(to right, #55efc4, #00b894);
    color: white;
}

.select-btn:hover {
    background: linear-gradient(to right, #00b894, #55efc4);
    transform: translateY(-2px);
    box-shadow: 0 3px 10px rgba(0, 184, 148, 0.4);
}

/* 취소 버튼 */
.btn-cancel {
    background: linear-gradient(to right, #b2bec3, #636e72);
    color: white;
    margin-left: 10px;
}

.btn-cancel:hover {
    background: linear-gradient(to right, #636e72, #b2bec3);
    transform: translateY(-2px);
    box-shadow: 0 3px 10px rgba(99, 110, 114, 0.4);
}

.detail-table .total-row {
    border-top: 2px solid #ddd;
    font-weight: 700;
}

.detail-table .total-row th,
.detail-table .total-row td {
    color: #3498db;
    background-color: #f9f9f9;
}

/* 모달 스타일 */
.modal {
    display: none; 
    position: fixed;
    z-index: 1000;
    left: 0;
    top: 0;
    width: 100%;
    height: 100%;
    overflow: auto;
    background-color: rgba(0,0,0,0.5);
    opacity: 0;
    transition: opacity 0.3s ease;
}

.modal.show {
    opacity: 1;
}

.modal-content {
    position: relative;
    background-color: #fefefe;
    margin: 3% auto;
    padding: 25px;
    border: 1px solid #ddd;
    border-radius: 12px;
    box-shadow: 0 4px 20px rgba(0,0,0,0.15);
    width: 90%;
    max-width: 1200px;
    max-height: 90vh;
    overflow-y: auto;
    transform: translateY(20px);
    opacity: 0;
    transition: all 0.3s ease;
}

.modal.show .modal-content {
    transform: translateY(0);
    opacity: 1;
}

.modal-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    border-bottom: 2px solid #e6edf5;
    padding-bottom: 15px;
    margin-bottom: 20px;
}

.modal-header h2 {
    font-size: 20px;
    font-weight: 700;
    margin: 0;
    color: #2c3e50;
    letter-spacing: -0.5px;
}

.close {
    color: #777;
    font-size: 28px;
    font-weight: 700;
    cursor: pointer;
    transition: all 0.3s ease;
    margin-left: 20px;
    line-height: 1;
    opacity: 0.7;
}

.close:hover {
    color: #e74c3c;
    opacity: 1;
    transform: scale(1.1);
}

.detail-grid {
    display: grid;
    grid-template-columns: repeat(2, 1fr);
    gap: 25px;
    padding: 20px;
}

.detail-section {
    background: #fff;
    padding: 20px;
    border-radius: 8px;
    box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    margin-bottom: 20px;
}

.detail-section h3 {
    font-size: 16px;
    font-weight: 700;
    color: #2c3e50;
    margin: 0 0 15px 0;
    padding: 10px 15px;
    background: #f8f9fa;
    border-left: 4px solid #3498db;
    border-radius: 4px;
}

.detail-table {
    width: 100%;
    border-collapse: separate;
    border-spacing: 0;
    border: 1px solid #e0e0e0;
    margin-bottom: 20px;
}

.detail-table th {
    width: 150px !important;
    min-width: 150px !important;
    background-color: #f8f9fa;
    color: #333;
    font-weight: 600;
    text-align: left;
    padding: 12px 15px;
    border-bottom: 1px solid #e0e0e0;
    border-right: 1px solid #e0e0e0;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
}

.detail-table td {
    padding: 12px 15px;
    border-bottom: 1px solid #e0e0e0;
    background: #fff;
    text-align: right;
}

.detail-table tr:last-child th,
.detail-table tr:last-child td {
    border-bottom: none;
}

.detail-table td[id^="detail-"] {
    font-weight: 600;
    color: #2c3e50;
}

.detail-table .total-row {
    background-color: #f8f9fa;
}

.detail-table .total-row th,
.detail-table .total-row td {
    font-weight: 700;
    color: #3498db;
    border-top: 2px solid #3498db;
}

.modal-actions {
    text-align: center;
    margin-top: 20px;
    padding-top: 15px;
    border-top: 1px solid #eee;
}

/* 모달 폼 스타일 */
.form-group {
    margin-bottom: 22px;
    position: relative;
}

.form-group label {
    display: block;
    margin-bottom: 10px;
    font-weight: 600;
    color: #2c3e50;
    font-size: 15px;
    letter-spacing: -0.5px;
}

.form-group input,
.form-group textarea {
    width: 100%;
    padding: 14px 16px;
    border: 1px solid #ddd;
    border-radius: 10px;
    font-size: 15px;
    font-family: 'Noto Sans KR', sans-serif;
    transition: all 0.3s ease;
    background-color: #f8f9fa;
    color: #333;
    box-shadow: 0 2px 5px rgba(0,0,0,0.05) inset;
}

.form-group input:focus,
.form-group textarea:focus {
    border-color: #36d1dc;
    box-shadow: 0 0 0 3px rgba(54, 209, 220, 0.2);
    outline: none;
    background-color: #fff;
}

.form-group input[readonly] {
    background-color: #e9ecef;
    cursor: not-allowed;
    font-weight: 600;
    color: #495057;
}

.form-group input::placeholder,
.form-group textarea::placeholder {
    color: #adb5bd;
    font-weight: 400;
}

/* 특정 입력 필드 스타일 조정 */
#emergency-discount-amount {
    font-size: 16px;
    font-weight: 700;
    color: #e74c3c;
    text-align: right;
    padding-right: 20px;
}

.teebox-tab .form-group::after, #emergencyDiscountModal .form-group::after {
    content: "원";
    position: absolute;
    right: 15px;
    bottom: 18px;
    font-size: 15px;
    color: #e74c3c;
    font-weight: 700;
    pointer-events: none;
    display: none;
}

.teebox-tab .form-group:nth-child(2)::after, #emergencyDiscountModal .emergency-form-group:nth-child(2)::after {
    display: block;
}

#emergency-discount-reason {
    min-height: 100px;
    resize: vertical;
}

/* ----- 긴급할인 등록 모달 스타일 ----- */
#emergencyDiscountModal .modal-content {
    background: #fff;
    max-width: 500px;
    padding: 0;
    border-radius: 16px;
    box-shadow: 0 15px 50px rgba(0, 0, 0, 0.25);
    overflow: hidden;
    border: none;
}

.emergency-modal-header {
    background: #2c3e50;
    color: white;
    padding: 20px 24px;
    display: flex;
    justify-content: space-between;
    align-items: center;
    position: relative;
}

.emergency-modal-header h2 {
    margin: 0;
    font-size: 18px;
    font-weight: 600;
    color: white;
}

.close-btn {
    background: transparent;
    border: none;
    cursor: pointer;
    color: white;
    padding: 0;
    display: flex;
    align-items: center;
    justify-content: center;
    opacity: 0.7;
    transition: opacity 0.2s;
}

.close-btn:hover {
    opacity: 1;
}

.emergency-modal-body {
    padding: 24px 24px 8px;
}

.emergency-form {
    display: flex;
    flex-direction: column;
    gap: 20px;
}

.emergency-form-group {
    display: flex;
    flex-direction: column;
    gap: 8px;
}

.emergency-form-group label {
    font-size: 15px;
    font-weight: 600;
    color: #4a5568;
    letter-spacing: -0.3px;
}

.emergency-input-wrap {
    position: relative;
    width: 100%;
}

.emergency-input-wrap input,
.emergency-input-wrap textarea {
    width: 100%;
    padding: 12px 16px;
    font-size: 15px;
    border: 1px solid #e2e8f0;
    border-radius: 8px;
    background-color: #f8fafc;
    color: #1a202c;
    transition: all 0.2s ease;
}

.emergency-input-wrap input:focus,
.emergency-input-wrap textarea:focus {
    border-color: #3b82f6;
    box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
    outline: none;
    background-color: #fff;
}

.emergency-input-wrap input::placeholder,
.emergency-input-wrap textarea::placeholder {
    color: #a0aec0;
}

.emergency-input-wrap input:focus::placeholder,
.emergency-input-wrap textarea:focus::placeholder {
    opacity: 0.5;
}

.emergency-input-wrap input[type="number"] {
    text-align: right;
    padding-right: 16px;
}

.emergency-input-wrap input[type="number"]::-webkit-outer-spin-button,
.emergency-input-wrap input[type="number"]::-webkit-inner-spin-button {
    -webkit-appearance: none;
    margin: 0;
}

/* 앱 전체 폼 요소 포커스 시 하이라이트 제거 */
*:focus {
    outline: none;
}

.currency-unit {
    display: none;
}

.emergency-modal-footer {
    padding: 16px 24px 24px;
}

.emergency-modal-actions {
    display: flex;
    justify-content: flex-end;
    gap: 12px;
}

#emergencyDiscountModal .btn-save,
#emergencyDiscountModal .btn-cancel {
    padding: 10px 20px;
    border-radius: 8px;
    font-size: 14px;
    font-weight: 600;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    cursor: pointer;
    transition: all 0.2s ease;
    border: none;
    min-width: 100px;
}

#emergencyDiscountModal .btn-save {
    background: #3b82f6;
    color: white;
    box-shadow: 0 4px 6px rgba(59, 130, 246, 0.2);
}

#emergencyDiscountModal .btn-save:hover {
    background: #2563eb;
    transform: translateY(-1px);
    box-shadow: 0 6px 10px rgba(59, 130, 246, 0.3);
}

#emergencyDiscountModal .btn-cancel {
    background: #e2e8f0;
    color: #4a5568;
    box-shadow: 0 4px 6px rgba(0, 0, 0, 0.05);
}

#emergencyDiscountModal .btn-cancel:hover {
    background: #cbd5e1;
    transform: translateY(-1px);
    box-shadow: 0 6px 10px rgba(0, 0, 0, 0.08);
}

/* 애니메이션 효과 추가 */
@keyframes slideIn {
    from {
        transform: translateY(50px);
        opacity: 0;
    }
    to {
        transform: translateY(0);
        opacity: 1;
    }
}

#emergencyDiscountModal.show .modal-content {
    animation: slideIn 0.3s forwards;
}

/* 긴급할인 목록 모달 전용 스타일 */
#emergencyDiscountListModal .modal-content {
    width: 95%;
    max-width: 1400px;
    padding: 30px;
}

#emergencyDiscountListModal .table-responsive {
    overflow-x: visible;
    width: 100%;
    padding: 5px;
    border-radius: 8px;
    background-color: #f8f9fa;
}

#emergencyDiscountListModal .usage-table {
    table-layout: fixed;
    width: 100%;
    margin-bottom: 0;
    border: 1px solid #e0e0e0;
    box-shadow: 0 1px 5px rgba(0,0,0,0.05);
}

#emergencyDiscountListModal .usage-table thead tr {
    background: linear-gradient(to right, #a1c4fd, #c2e9fb);
}

#emergencyDiscountListModal .usage-table th {
    color: #2c3e50;
    font-weight: 700;
    padding: 12px 8px;
    text-shadow: 0 1px 1px rgba(255,255,255,0.7);
    border-bottom: 2px solid #3498db;
}

#emergencyDiscountListModal .usage-table th,
#emergencyDiscountListModal .usage-table td {
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    vertical-align: middle;
}

/* 컬럼별 너비 조정 */
#emergencyDiscountListModal .usage-table th:nth-child(1),
#emergencyDiscountListModal .usage-table td:nth-child(1) {
    width: 15%;
}

#emergencyDiscountListModal .usage-table th:nth-child(2),
#emergencyDiscountListModal .usage-table td:nth-child(2) {
    width: 5%;
}

#emergencyDiscountListModal .usage-table th:nth-child(3),
#emergencyDiscountListModal .usage-table td:nth-child(3) {
    width: 12%;
}

#emergencyDiscountListModal .usage-table th:nth-child(4),
#emergencyDiscountListModal .usage-table td:nth-child(4),
#emergencyDiscountListModal .usage-table th:nth-child(5),
#emergencyDiscountListModal .usage-table td:nth-child(5) {
    width: 8%;
}

#emergencyDiscountListModal .usage-table th:nth-child(6),
#emergencyDiscountListModal .usage-table td:nth-child(6),
#emergencyDiscountListModal .usage-table th:nth-child(7),
#emergencyDiscountListModal .usage-table td:nth-child(7),
#emergencyDiscountListModal .usage-table th:nth-child(8),
#emergencyDiscountListModal .usage-table td:nth-child(8) {
    width: 14%;
}

#emergencyDiscountListModal .usage-table th:nth-child(9),
#emergencyDiscountListModal .usage-table td:nth-child(9) {
    width: 10%;
}

/* 선택 버튼 센터 정렬 */
#emergencyDiscountListModal .usage-table td:nth-child(10) {
    text-align: center;
}

#emergencyDiscountListModal .modal-header h2 {
    font-size: 20px;
    font-weight: 700;
    color: #2c3e50;
    border-left: 4px solid #3498db;
    padding-left: 10px;
}

/* 선택 버튼 스타일 개선 */
#emergencyDiscountListModal .select-btn {
    min-width: 70px;
    padding: 6px 12px;
    font-size: 13px;
    background: linear-gradient(to right, #00b894, #38d39f);
    box-shadow: 0 3px 8px rgba(0, 184, 148, 0.3);
}

#emergencyDiscountListModal .select-btn:hover {
    background: linear-gradient(to right, #38d39f, #00b894);
    transform: translateY(-2px);
    box-shadow: 0 5px 15px rgba(0, 184, 148, 0.5);
}

/* 로딩 스피너 및 빈 상태 스타일 */
.loading-message {
    padding: 30px !important;
}

.loading-spinner {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: 20px;
}

.loading-spinner p {
    margin-top: 15px;
    color: #555;
    font-size: 14px;
}

.spinner {
    width: 40px;
    height: 40px;
    border: 4px solid rgba(0, 0, 0, 0.1);
    border-radius: 50%;
    border-left-color: #3498db;
    animation: spin 1s linear infinite;
}

@keyframes spin {
    0% {
        transform: rotate(0deg);
    }
    100% {
        transform: rotate(360deg);
    }
}

.empty-state {
    text-align: center;
    padding: 40px 20px;
}

.empty-icon {
    font-size: 48px;
    color: #d1d8e0;
    margin-bottom: 20px;
}

.empty-state h3 {
    font-size: 20px;
    color: #4b6584;
    margin-bottom: 10px;
}

.empty-state p {
    color: #778ca3;
    margin-bottom: 20px;
}

.modal-body {
    margin-bottom: 25px;
}

#emergencyDiscountModal .modal-body {
    padding: 0 10px;
}

/* 토스트 알림 스타일 */
.toast-container {
    position: fixed;
    bottom: 30px;
    right: 30px;
    z-index: 1100;
    display: flex;
    flex-direction: column;
    gap: 10px;
}

.toast {
    background: white;
    color: #2d3748;
    padding: 16px 20px;
    border-radius: 12px;
    box-shadow: 0 10px 25px rgba(0, 0, 0, 0.1), 0 5px 10px rgba(0, 0, 0, 0.05);
    display: flex;
    align-items: center;
    justify-content: space-between;
    min-width: 300px;
    max-width: 450px;
    transform: translateX(120%);
    transition: transform 0.4s cubic-bezier(0.175, 0.885, 0.32, 1.275);
    opacity: 0;
    border-left: 5px solid;
}

.toast.show {
    transform: translateX(0);
    opacity: 1;
}

.toast-content {
    display: flex;
    align-items: center;
    flex: 1;
}

.toast-icon {
    margin-right: 12px;
    font-size: 20px;
    width: 24px;
    height: 24px;
    display: flex;
    align-items: center;
    justify-content: center;
    border-radius: 50%;
    color: white;
    flex-shrink: 0;
}

.toast-message {
    font-weight: 500;
    font-size: 14px;
    flex: 1;
    word-break: break-word;
}

.toast-close {
    cursor: pointer;
    font-size: 20px;
    margin-left: 15px;
    opacity: 0.7;
    transition: opacity 0.2s;
    display: flex;
    align-items: center;
    color: #4a5568;
}

.toast-close:hover {
    opacity: 1;
}

/* 성공 토스트 */
.toast.success {
    border-left-color: #38a169;
}

.toast.success .toast-icon {
    background-color: #38a169;
}

/* 경고 토스트 */
.toast.warning {
    border-left-color: #dd6b20;
}

.toast.warning .toast-icon {
    background-color: #dd6b20;
}

/* 에러 토스트 */
.toast.error {
    border-left-color: #e53e3e;
}

.toast.error .toast-icon {
    background-color: #e53e3e;
}

/* 로딩 스피너 - 버튼 내부용 */
.spinner-border-sm {
    display: inline-block;
    width: 14px;
    height: 14px;
    border: 2px solid #fff;
    border-right-color: transparent;
    border-radius: 50%;
    animation: spinner-border 0.75s linear infinite;
    margin-right: 8px;
    vertical-align: middle;
    position: relative;
    top: -1px;
}

@keyframes spinner-border {
    to { transform: rotate(360deg); }
}

.emergency-input-wrap.readonly input {
    background-color: #f1f5f9;
    color: #64748b;
    font-weight: 500;
}

.emergency-input-wrap textarea {
    min-height: 100px;
    resize: vertical;
}

.emergency-input-wrap input[type="number"] {
    text-align: right;
    padding-right: 16px;
}

/* 불투명도 애니메이션 추가 */
.emergency-input-wrap input, 
.emergency-input-wrap textarea,
.btn-save, 
.btn-cancel {
    transition: all 0.2s ease;
}

/* 불필요한 스타일 제거 */
.required {
    display: none;
}
</style>

<script>
// 상세정보 모달 표시 함수
function showTeeboxDetail(usage) {
    // 각 섹션의 데이터 업데이트
    const titles = {
        'reservation-id': '예약번호',
        'ts-date': '이용일자',
        'ts-id': '타석번호',
        'ts-start': '시작시간',
        'ts-end': '종료시간',
        'ts-type': '상태',
        'time-stamp': '기록 일시',
        'total-amt': '총금액',
        'total-discount': '총 할인',
        'net-amt': '결제금액',
        'term-discount': '기간권 할인',
        'junior-discount': '주니어 할인',
        'overtime-discount': '집중연습할인',
        'revisit-discount': '재방문 할인',
        'emergency-discount': '긴급 할인',
        'emergency-reason': '긴급할인 사유',
        'discount-total': '할인 합계',
        'ts-min': '총 이용시간',
        'morning': '조조',
        'normal': '일반',
        'peak': '피크',
        'night': '심야'
    };

    // 각 필드에 대해 제목과 값을 설정
    Object.keys(titles).forEach(key => {
        const element = document.getElementById(`detail-${key}`);
        if (element) {
            // 제목 부분 찾기
            const titleCell = element.parentElement.querySelector('th');
            if (titleCell) {
                titleCell.textContent = titles[key];
            }
            
            // 값 설정
            let value = usage[key.replace(/-/g, '_')] || '-';
            
            // 특별한 포맷팅이 필요한 경우
            if (key === 'ts-date') value = formatDate(usage.ts_date);
            else if (key === 'ts-start') value = formatTime(usage.ts_start);
            else if (key === 'ts-end') value = formatTime(usage.ts_end);
            else if (key === 'time-stamp') value = formatDateTime(usage.time_stamp);
            else if (key.includes('discount') || key.includes('amt')) value = formatCurrency(value);
            else if (key === 'ts-min' || ['morning', 'normal', 'peak', 'night'].includes(key)) value = value + '분';
            
            element.textContent = value;
        }
    });

    // 모달 표시
    const modal = document.getElementById('teeboxDetailModal');
    modal.style.display = 'block';
    setTimeout(() => {
        modal.classList.add('show');
    }, 10);
}

// 티박스 상세정보 모달 닫기 함수
function closeTeeboxDetailModal() {
    const modal = document.getElementById('teeboxDetailModal');
    modal.classList.remove('show');
    setTimeout(() => {
        modal.style.display = 'none';
    }, 300);
}

// 날짜 포맷팅 함수
function formatDate(dateStr) {
    if (!dateStr) return '-';
    const date = new Date(dateStr);
    return date.getFullYear() + '-' + 
           String(date.getMonth() + 1).padStart(2, '0') + '-' + 
           String(date.getDate()).padStart(2, '0');
}

// 시간 포맷팅 함수
function formatTime(timeStr) {
    if (!timeStr || timeStr === 'NaN:NaN') return '-';
    
    // SQL 시간 형식(HH:MM:SS)인 경우
    if (typeof timeStr === 'string' && timeStr.includes(':')) {
        return timeStr.substr(0, 5); // HH:MM 만 표시
    }
    
    // Date 객체로 변환 가능한 경우
    try {
        const date = new Date(timeStr);
        if (isNaN(date.getTime())) return '-';
        return String(date.getHours()).padStart(2, '0') + ':' + 
               String(date.getMinutes()).padStart(2, '0');
    } catch (e) {
        return '-';
    }
}

// 날짜시간 포맷팅 함수
function formatDateTime(dateTimeStr) {
    if (!dateTimeStr) return '-';
    const date = new Date(dateTimeStr);
    return date.getFullYear() + '-' + 
           String(date.getMonth() + 1).padStart(2, '0') + '-' + 
           String(date.getDate()).padStart(2, '0') + ' ' +
           String(date.getHours()).padStart(2, '0') + ':' + 
           String(date.getMinutes()).padStart(2, '0') + ':' + 
           String(date.getSeconds()).padStart(2, '0');
}

// 금액 포맷팅 함수
function formatCurrency(amount) {
    return (Number(amount) || 0).toLocaleString() + '원';
}

// ESC 키 이벤트 리스너 추가
document.addEventListener('keydown', function(event) {
    if (event.key === 'Escape') {
        const teeboxModal = document.getElementById('teeboxDetailModal');
        const emergencyListModal = document.getElementById('emergencyDiscountListModal');
        const emergencyFormModal = document.getElementById('emergencyDiscountModal');
        
        if (teeboxModal.style.display === 'block') {
            closeTeeboxDetailModal();
        }
        
        if (emergencyListModal.style.display === 'block') {
            closeEmergencyDiscountListModal();
        }
        
        if (emergencyFormModal.style.display === 'block') {
            closeEmergencyDiscountModal();
        }
    }
});

// 모달 영역 외 클릭 시 닫기
window.onclick = function(event) {
    const teeboxModal = document.getElementById('teeboxDetailModal');
    const emergencyListModal = document.getElementById('emergencyDiscountListModal');
    const emergencyFormModal = document.getElementById('emergencyDiscountModal');
    
    if (event.target === teeboxModal) {
        closeTeeboxDetailModal();
    }
    
    if (event.target === emergencyListModal) {
        closeEmergencyDiscountListModal();
    }
    
    if (event.target === emergencyFormModal) {
        closeEmergencyDiscountModal();
    }
}

// 긴급할인 관련 함수 추가
// 오늘자 타석이용 목록 모달 표시
function showEmergencyDiscountList() {
    // AJAX로 오늘 날짜의 타석 이용 내역 가져오기
    const member_id = <?php echo $member_id; ?>;
    
    // 한국 시간대 기준으로 오늘 날짜 가져오기 (단순화된 방법)
    const now = new Date();
    // 강제로 한국 날짜 설정 - 현재 시각에 9시간 추가하고 날짜만 추출
    const koreaDate = new Date(now.getTime() + (9 * 60 * 60 * 1000));
    const today = koreaDate.toISOString().split('T')[0];
    console.log('클라이언트 현재 시각:', now.toString());
    console.log('한국 시간 기준 오늘 날짜:', today);
    
    // 실행 모드에 따른 API 경로 설정
    const basePath = <?php echo $is_standalone ? "'./'" : "'member_form_tabs_and_process/'"; ?>;
    const apiUrl = `${basePath}get_today_teebox_usage.php?member_id=${member_id}&date=${today}`;
    console.log('API 호출 URL:', apiUrl);
    
    // 모달 표시 (데이터 로딩 전에 표시)
    const modal = document.getElementById('emergencyDiscountListModal');
    modal.style.display = 'block';
    setTimeout(() => {
        modal.classList.add('show');
    }, 10);
    
    // 로딩 메시지 표시
    const tbody = document.getElementById('todayUsageList');
    tbody.innerHTML = `
        <tr>
            <td colspan="10" class="text-center loading-message">
                <div class="loading-spinner">
                    <div class="spinner"></div>
                    <p>데이터를 불러오는 중입니다...</p>
                </div>
            </td>
        </tr>`;
    
    fetch(apiUrl)
        .then(response => {
            console.log('서버 응답 상태:', response.status);
            if (!response.ok) {
                throw new Error(`서버 응답 오류: ${response.status} ${response.statusText}`);
            }
            return response.json();
        })
        .then(data => {
            console.log('서버 응답 데이터:', data);
            tbody.innerHTML = '';
            
            if (!data || data.error) {
                throw new Error(data.message || '서버에서 오류가 발생했습니다.');
            }
            
            // 디버깅 정보 출력
            if (data.debug) {
                console.log('서버 디버깅 정보:', data.debug);
            }
            
            // API 응답 구조 변경됨 - 데이터는 data 필드에 있음
            const records = data.data || [];
            
            if (records.length === 0) {
                // 오늘 이용 내역이 없는 경우 강조된 메시지와 닫기 버튼 표시
                tbody.innerHTML = `
                    <tr>
                        <td colspan="10" class="no-data">
                            <div class="empty-state">
                                <div class="empty-icon"><i class="far fa-calendar-alt"></i></div>
                                <h3>오늘 타석 이용 내역이 없습니다</h3>
                                <p>긴급할인은 당일 타석 이용 내역이 있을 때만 등록할 수 있습니다.</p>
                                <button type="button" class="btn" onclick="closeEmergencyDiscountListModal()">닫기</button>
                            </div>
                        </td>
                    </tr>`;
                return;
            }
            
            // records 배열을 사용하여 테이블 생성 (data.forEach 대신)
            records.forEach(item => {
                const row = document.createElement('tr');
                row.innerHTML = `
                    <td>${item.reservation_id}</td>
                    <td class="text-center">${item.ts_id || '-'}</td>
                    <td class="text-center">${formatDate(item.ts_date)}</td>
                    <td class="text-center">${item.ts_start}</td>
                    <td class="text-center">${item.ts_end}</td>
                    <td class="text-right">${formatCurrency(item.total_amt)}</td>
                    <td class="text-right">${formatCurrency(item.total_discount)}</td>
                    <td class="text-right">${formatCurrency(item.net_amt)}</td>
                    <td class="text-right">${formatCurrency(item.emergency_discount)}</td>
                    <td class="text-center">
                        <button type="button" class="select-btn" 
                                onclick="selectForEmergencyDiscount('${item.reservation_id}')">선택</button>
                    </td>
                `;
                tbody.appendChild(row);
            });
        })
        .catch(error => {
            console.error('데이터 로딩 오류:', error);
            
            // 오류 메시지 표시
            tbody.innerHTML = `
                <tr>
                    <td colspan="10" class="no-data">
                        <div class="error-state">
                            <div class="error-icon"><i class="fa fa-exclamation-triangle"></i></div>
                            <h3>데이터를 불러오는데 실패했습니다</h3>
                            <p>${error.message || '서버 연결 중 오류가 발생했습니다.'}</p>
                            <button type="button" class="close-btn" onclick="closeEmergencyDiscountListModal()">닫기</button>
                        </div>
                    </td>
                </tr>`;
                
            // 오류 스타일 추가
            const style = document.createElement('style');
            style.textContent = `
                .error-state {
                    text-align: center;
                    padding: 40px 20px;
                }
                .error-icon {
                    font-size: 48px;
                    color: #e74c3c;
                    margin-bottom: 20px;
                }
                .error-state h3 {
                    font-size: 20px;
                    color: #c0392b;
                    margin-bottom: 10px;
                }
                .error-state p {
                    color: #7f8c8d;
                    margin-bottom: 20px;
                }
            `;
            document.head.appendChild(style);
        });
}

function closeEmergencyDiscountListModal() {
    const modal = document.getElementById('emergencyDiscountListModal');
    modal.classList.remove('show');
    setTimeout(() => {
        modal.style.display = 'none';
    }, 300);
}

function selectForEmergencyDiscount(reservationId) {
    // 긴급할인 등록 모달에 예약번호 설정
    document.getElementById('selected-reservation-id').value = reservationId;
    
    // 금액 필드 초기화 및 포커스
    const amountField = document.getElementById('emergency-discount-amount');
    amountField.value = '';
    
    // 사유 필드 초기화
    document.getElementById('emergency-discount-reason').value = '';
    
    // 목록 모달 닫고 등록 모달 열기
    closeEmergencyDiscountListModal();
    
    const modal = document.getElementById('emergencyDiscountModal');
    modal.style.display = 'block';
    setTimeout(() => {
        modal.classList.add('show');
        // 금액 필드에 포커스
        setTimeout(() => {
            amountField.focus();
        }, 300);
    }, 10);
}

function closeEmergencyDiscountModal() {
    const modal = document.getElementById('emergencyDiscountModal');
    modal.classList.remove('show');
    setTimeout(() => {
        modal.style.display = 'none';
        
        // 입력 필드 초기화
        document.getElementById('selected-reservation-id').value = '';
        document.getElementById('emergency-discount-amount').value = '';
        document.getElementById('emergency-discount-reason').value = '';
    }, 300);
}

function saveEmergencyDiscount() {
    const reservationId = document.getElementById('selected-reservation-id').value;
    const discountAmount = document.getElementById('emergency-discount-amount').value;
    const discountReason = document.getElementById('emergency-discount-reason').value;
    
    if (!reservationId) {
        showWarningToast('예약번호가 선택되지 않았습니다.');
        return;
    }
    
    if (!discountAmount) {
        document.getElementById('emergency-discount-amount').focus();
        showWarningToast('할인 금액을 입력해주세요.');
        return;
    }
    
    if (!discountReason) {
        document.getElementById('emergency-discount-reason').focus();
        showWarningToast('할인 사유를 입력해주세요.');
        return;
    }
    
    // 저장 버튼 비활성화 및 로딩 상태 표시
    const saveBtn = document.querySelector('#emergencyDiscountModal .btn-save');
    const originalText = saveBtn.innerHTML;
    saveBtn.disabled = true;
    saveBtn.innerHTML = '<span class="spinner-border-sm"></span>저장 중...';
    
    // 실행 모드에 따른 API 경로 설정
    const basePath = <?php echo $is_standalone ? "'./'" : "'member_form_tabs_and_process/'"; ?>;
    
    // AJAX로 데이터 저장
    const formData = new FormData();
    formData.append('reservation_id', reservationId);
    formData.append('discount_amount', discountAmount);
    formData.append('discount_reason', discountReason);
    
    fetch(`${basePath}update_emergency_discount.php`, {
        method: 'POST',
        body: formData
    })
    .then(response => response.json())
    .then(data => {
        if (data.success) {
            closeEmergencyDiscountModal();
            showSuccessToast(data.message || '할인이 성공적으로 등록되었습니다.');
            
            // 테이블 새로고침
            setTimeout(() => {
                location.reload();
            }, 1000);
        } else {
            showErrorToast(data.message || '저장에 실패했습니다.');
            saveBtn.disabled = false;
            saveBtn.innerHTML = originalText;
        }
    })
    .catch(error => {
        console.error('Error saving emergency discount:', error);
        showErrorToast('저장 중 오류가 발생했습니다.');
        saveBtn.disabled = false;
        saveBtn.innerHTML = originalText;
    });
}

// 토스트 알림 표시 함수
function showSuccessToast(message) {
    // 토스트 컨테이너가 없으면 생성
    let container = document.querySelector('.toast-container');
    if (!container) {
        container = document.createElement('div');
        container.className = 'toast-container';
        document.body.appendChild(container);
    }
    
    // 토스트 요소 생성
    const toast = document.createElement('div');
    toast.className = 'toast success';
    toast.innerHTML = `
        <div class="toast-content">
            <div class="toast-icon">✓</div>
            <div class="toast-message">${message}</div>
        </div>
        <div class="toast-close" onclick="this.parentElement.remove()">×</div>
    `;
    
    // 컨테이너에 추가
    container.appendChild(toast);
    
    // 애니메이션을 위한 지연
    setTimeout(() => {
        toast.classList.add('show');
    }, 10);
    
    // 5초 후 자동으로 사라짐
    setTimeout(() => {
        toast.classList.remove('show');
        setTimeout(() => {
            toast.remove();
        }, 400);
    }, 5000);
}

function showWarningToast(message) {
    // 토스트 컨테이너가 없으면 생성
    let container = document.querySelector('.toast-container');
    if (!container) {
        container = document.createElement('div');
        container.className = 'toast-container';
        document.body.appendChild(container);
    }
    
    // 토스트 요소 생성
    const toast = document.createElement('div');
    toast.className = 'toast warning';
    toast.innerHTML = `
        <div class="toast-content">
            <div class="toast-icon">⚠</div>
            <div class="toast-message">${message}</div>
        </div>
        <div class="toast-close" onclick="this.parentElement.remove()">×</div>
    `;
    
    // 컨테이너에 추가
    container.appendChild(toast);
    
    // 애니메이션을 위한 지연
    setTimeout(() => {
        toast.classList.add('show');
    }, 10);
    
    // 5초 후 자동으로 사라짐
    setTimeout(() => {
        toast.classList.remove('show');
        setTimeout(() => {
            toast.remove();
        }, 400);
    }, 5000);
}

function showErrorToast(message) {
    // 토스트 컨테이너가 없으면 생성
    let container = document.querySelector('.toast-container');
    if (!container) {
        container = document.createElement('div');
        container.className = 'toast-container';
        document.body.appendChild(container);
    }
    
    // 토스트 요소 생성
    const toast = document.createElement('div');
    toast.className = 'toast error';
    toast.innerHTML = `
        <div class="toast-content">
            <div class="toast-icon">✗</div>
            <div class="toast-message">${message}</div>
        </div>
        <div class="toast-close" onclick="this.parentElement.remove()">×</div>
    `;
    
    // 컨테이너에 추가
    container.appendChild(toast);
    
    // 애니메이션을 위한 지연
    setTimeout(() => {
        toast.classList.add('show');
    }, 10);
    
    // 5초 후 자동으로 사라짐
    setTimeout(() => {
        toast.classList.remove('show');
        setTimeout(() => {
            toast.remove();
        }, 400);
    }, 5000);
}
</script> 