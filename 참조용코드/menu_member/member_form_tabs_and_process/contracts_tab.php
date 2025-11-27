<?php
// 회원권 탭 컨텐츠 - member_form.php에서 불러와서 사용

// 단독 실행인지 확인 - 독립 실행 시와 부모 페이지에서 포함되는 경우 구분
$is_standalone = !isset($in_parent_page);

// 디버깅을 위한 코드 추가
error_log("====== 회원권 탭 로딩 시작 ======");
echo "<!-- 회원권 탭 디버깅 시작 -->";
echo "<!-- 독립실행모드: " . ($is_standalone ? 'true' : 'false') . " -->";
echo "<!-- member_id 확인: " . (isset($_GET['id']) ? $_GET['id'] : (isset($member_id) ? $member_id : '없음')) . " -->";

// $db 변수가 전달되지 않는 문제를 해결하기 위해 DB 연결 직접 수행
if (isset($db_copy) && $db_copy) {
    echo "<!-- 전달된 DB 연결 사용 -->";
    error_log("전달된 DB 연결 사용");
    $db = $db_copy;
} else if (!isset($db) || !$db) {
    echo "<!-- DB 연결 새로 수행 -->";
    error_log("DB 연결 새로 수행");
    require_once dirname(__FILE__) . '/../../config/db_connect.php';
    // DB 연결 확인
    if ($db) {
        echo "<!-- DB 연결 성공 -->";
        error_log("DB 연결 성공");
    } else {
        echo "<!-- DB 연결 실패 -->";
        error_log("DB 연결 실패");
    }
}

// member_id가 GET으로 전달됐는지 확인
if (!isset($_GET['id'])) {
    echo '<div class="error-message">회원 ID가 전달되지 않았습니다.</div>';
    error_log("회원 ID가 전달되지 않음");
    exit;
}

$member_id = intval($_GET['id']);
echo "<!-- member_id 변환 후: " . $member_id . " -->";
error_log("member_id 변환 후: " . $member_id);

// 회원 정보 조회
echo "<!-- 회원 정보 조회 쿼리 실행 전 -->";
error_log("회원 정보 조회 쿼리 실행 전");
$stmt = $db->prepare("SELECT member_id, member_name FROM members WHERE member_id = ?");
$stmt->bind_param('i', $member_id);
$stmt->execute();
$result = $stmt->get_result();
echo "<!-- 회원 정보 조회 쿼리 실행 후, 결과 행 수: " . $result->num_rows . " -->";
error_log("회원 정보 조회 쿼리 실행 후, 결과 행 수: " . $result->num_rows);

if ($result->num_rows === 0) {
    echo '<div class="error-message">회원 정보를 찾을 수 없습니다.</div>';
    error_log("회원 정보를 찾을 수 없음");
    exit;
}

$member = $result->fetch_assoc();
echo "<!-- 회원 정보: " . json_encode($member) . " -->";
error_log("회원 정보: " . json_encode($member));

// 계약 통계 데이터 조회
echo "<!-- 계약 통계 쿼리 실행 전 -->";
error_log("계약 통계 쿼리 실행 전");
$stats_query = "
    SELECT 
        COUNT(*) as contract_count,
        SUM(CASE WHEN COALESCE(ch.contract_history_status, '') != '삭제' THEN ch.actual_price ELSE 0 END) as total_price,
        SUM(CASE WHEN COALESCE(ch.contract_history_status, '') != '삭제' THEN ch.actual_credit ELSE 0 END) as total_credit,
        SUM(CASE WHEN COALESCE(ch.contract_history_status, '') != '삭제' THEN c.contract_LS ELSE 0 END) as total_ls
    FROM contract_history ch
    JOIN contracts c ON ch.contract_id = c.contract_id
    WHERE ch.member_id = ?
";
$stmt = $db->prepare($stats_query);
$stmt->bind_param('i', $member_id);
$stmt->execute();
$stats_result = $stmt->get_result();
$stats = $stats_result->fetch_assoc();
echo "<!-- 계약 통계 쿼리 실행 후, 결과: " . json_encode($stats) . " -->";
error_log("계약 통계 쿼리 실행 후, 결과: " . json_encode($stats));
?>
<!-- 독립 실행 시 jQuery 로드 -->
<script src="https://code.jquery.com/jquery-3.6.0.min.js"></script>

<!-- 스타일시트 로딩 관련 스크립트 -->
<script>
// DOM 로드 후 초기화
document.addEventListener('DOMContentLoaded', function() {
    console.log('contracts_tab.php 초기화');
    
    // FontAwesome 아이콘 라이브러리 추가 (CDN)
    if (!document.getElementById('fontawesome-css')) {
        const link = document.createElement('link');
        link.id = 'fontawesome-css';
        link.rel = 'stylesheet';
        link.href = 'https://cdnjs.cloudflare.com/ajax/libs/font-awesome/4.7.0/css/font-awesome.min.css';
        document.head.appendChild(link);
        console.log('FontAwesome 추가됨');
    }

    // Google Noto Sans KR 폰트 추가
    if (!document.getElementById('noto-sans-kr')) {
        const link = document.createElement('link');
        link.id = 'noto-sans-kr';
        link.rel = 'stylesheet';
        link.href = 'https://fonts.googleapis.com/css2?family=Noto+Sans+KR:wght@400;500;700&display=swap';
        document.head.appendChild(link);
        console.log('Noto Sans KR 폰트 추가됨');
    }
});
</script>

<div class="contracts-tab-content">
    <div class="tab-actions">
        <button type="button" class="btn" onclick="openContractForm()">회원권 등록</button>
    </div>
    
    <div class="summary-container">
        <div class="summary-item">
            <label>구매횟수</label>
            <span><?php echo $stats['contract_count']; ?>회</span>
        </div>
        <div class="summary-item">
            <label>총 결제액</label>
            <span><?php echo number_format($stats['total_price']); ?>원</span>
        </div>
        <div class="summary-item">
            <label>총 크레딧</label>
            <span><?php echo number_format($stats['total_credit']); ?>c </span>
        </div>
        <div class="summary-item">
            <label>레슨권 구매</label>
            <span><?php echo number_format($stats['total_ls']); ?>회</span>
        </div>
    </div>
    
    <div class="contract-history">
        <h3>계약 내역</h3>
        <div class="table-container">
            <table class="contract-table">
                <thead>
                    <tr>
                        <th>계약일자</th>
                        <th>유형</th>
                        <th>결제</th>
                        <th>상품명</th>
                        <th>결제액</th>
                        <th>크레딧</th>
                        <th>레슨</th>
                        <th>관리</th>
                    </tr>
                </thead>
                <tbody>
                    <?php
                    echo "<!-- 계약 목록 쿼리 실행 전 -->";
                    error_log("계약 목록 쿼리 실행 전");
                    $contract_query = "
                        SELECT 
                            ch.contract_history_id,
                            ch.contract_date,
                            ch.actual_price,
                            ch.actual_credit,
                            ch.payment_type,
                            c.contract_type,
                            c.contract_name,
                            c.contract_LS,
                            ch.contract_history_status
                        FROM contract_history ch
                        JOIN contracts c ON ch.contract_id = c.contract_id
                        WHERE ch.member_id = ?
                        ORDER BY ch.contract_date DESC
                    ";
                    $stmt = $db->prepare($contract_query);
                    $stmt->bind_param('i', $member_id);
                    $stmt->execute();
                    $contracts = $stmt->get_result();
                    echo "<!-- 계약 목록 쿼리 실행 후, 결과 행 수: " . $contracts->num_rows . " -->";
                    error_log("계약 목록 쿼리 실행 후, 결과 행 수: " . $contracts->num_rows);
                    
                    $contract_count = 0;
                    while ($contract = $contracts->fetch_assoc()) : 
                        $contract_count++;
                        // 결제 방법 텍스트 변환
                        $payment_text = str_replace('결제', '', $contract['payment_type']);
                        $row_class = $contract['contract_history_status'] === '삭제' ? 'deleted-contract' : '';
                        echo "<!-- 계약 #" . $contract_count . ": " . json_encode($contract) . " -->";
                        error_log("계약 #" . $contract_count . ": " . json_encode($contract));
                    ?>
                    <tr data-contract-id="<?php echo $contract['contract_history_id']; ?>" class="<?php echo $row_class; ?>">
                        <td><?php echo date('Y-m-d', strtotime($contract['contract_date'])); ?></td>
                        <td><?php echo htmlspecialchars($contract['contract_type']); ?></td>
                        <td class="payment-col"><?php echo htmlspecialchars($payment_text); ?></td>
                        <td class="contract-name-col"><?php echo htmlspecialchars($contract['contract_name']); ?></td>
                        <td class="text-right"><?php echo number_format($contract['actual_price']); ?>원</td>
                        <td class="text-right"><?php echo number_format($contract['actual_credit']); ?>c</td>
                        <td class="text-right lesson-col"><?php echo $contract['contract_LS']; ?>회</td>
                        <td>
                            <button type="button" class="btn btn-small btn-delete" 
                                onclick="deleteContract(<?php echo $contract['contract_history_id']; ?>)">삭제</button>
                        </td>
                    </tr>
                    <?php endwhile; ?>
                    
                    <?php if ($contract_count === 0): ?>
                    <tr>
                        <td colspan="8" style="text-align: center; padding: 20px;">등록된 계약 내역이 없습니다.</td>
                    </tr>
                    <?php endif; ?>
                </tbody>
            </table>
        </div>
    </div>
</div>

<!-- 계약 삭제 확인 모달 추가 -->
<div id="deleteContractModal" class="modal">
    <div class="modal-content">
        <div class="modal-header">
            <h2>계약 삭제 확인</h2>
            <span class="close">&times;</span>
        </div>
        <div class="modal-body">
            <p>선택한 계약을 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.</p>
            <div class="form-group">
                <label for="deletePassword">관리자 비밀번호</label>
                <input type="password" id="deletePassword" placeholder="비밀번호 입력">
            </div>
            <input type="hidden" id="deleteContractId">
        </div>
        <div class="modal-footer">
            <button type="button" class="btn btn-danger" onclick="confirmDeleteContract()">삭제</button>
            <button type="button" class="btn" onclick="closeDeleteModal()">취소</button>
        </div>
    </div>
</div>

<?php 
echo "<!-- 회원권 탭 디버깅 종료 -->"; 
error_log("====== 회원권 탭 로딩 종료 ======");
?>

<style>
.contracts-tab-content {
    padding: 15px;
}

.tab-actions {
    margin-bottom: 20px;
    text-align: right;
}

.summary-container {
    display: flex;
    gap: 15px;
    margin-bottom: 20px;
    flex-wrap: wrap;
}

.summary-item {
    background-color: #f8f9fa;
    padding: 15px;
    border-radius: 5px;
    box-shadow: 0 1px 3px rgba(0,0,0,0.1);
    min-width: 150px;
    flex: 1;
}

.summary-item label {
    display: block;
    font-weight: bold;
    margin-bottom: 5px;
    color: #555;
    font-size: 14px;
}

.summary-item span {
    font-size: 18px;
    color: #333;
    font-weight: 600;
}

.contract-history h3 {
    font-size: 18px;
    margin-bottom: 10px;
    border-bottom: 1px solid #eee;
    padding-bottom: 10px;
}

.table-container {
    overflow-x: auto;
}

.contract-table {
    width: 100%;
    border-collapse: collapse;
    font-size: 14px;
}

.contract-table th, 
.contract-table td {
    padding: 10px;
    text-align: left;
    border-bottom: 1px solid #eee;
}

.contract-table th {
    background-color: #f8f9fa;
    font-weight: bold;
    text-align: center;
}

.contract-table .text-right {
    text-align: right;
}

/* 컬럼 너비 조정 */
.contract-table th:nth-child(1) { width: 90px; } /* 계약일자 */
.contract-table th:nth-child(2) { width: 70px; } /* 유형 */
.contract-table th:nth-child(3) { width: 60px; } /* 결제 */
.contract-table th:nth-child(4) { width: 120px; } /* 상품명 */
.contract-table th:nth-child(5) { width: 100px; } /* 결제액 */
.contract-table th:nth-child(6) { width: 100px; } /* 크레딧 */
.contract-table th:nth-child(7) { width: 50px; } /* 레슨 */
.contract-table th:nth-child(8) { width: 50px; } /* 관리 - 버튼이 안짤리도록 너비 증가 */

.deleted-contract {
    color: #999;
    text-decoration: line-through;
    background-color: #f9f9f9;
}

.btn-small {
    padding: 3px 8px;
    font-size: 12px;
}

.btn-delete {
    background: linear-gradient(to right, #ff9a9e, #fad0c4);
    color: #c23616;
    border-radius: 50px;
    font-weight: 600;
    box-shadow: 0 3px 6px rgba(0,0,0,0.1);
}

/* 삭제 버튼 크기 줄이기 */
.contract-table .btn-delete {
    padding: 2px 6px;
    font-size: 13px;
    min-width: 40px;
}

.btn-delete:hover {
    background: linear-gradient(to right, #ff9a9e, #ff6b6b);
    transform: translateY(-2px);
    box-shadow: 0 5px 15px rgba(255, 154, 158, 0.4);
}

/* 버튼 기본 스타일 */
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

.payment-col {
    white-space: nowrap;
    max-width: 60px;
    overflow: hidden;
    text-overflow: ellipsis;
}

.contract-name-col {
    white-space: normal;
    min-width: 150px;
}

.lesson-col {
    white-space: nowrap;
    width: 50px;
    text-align: center;
}

/* 모달 기본 스타일 */
.modal {
    display: none;
    position: fixed;
    z-index: 1000;
    left: 0;
    top: 0;
    width: 100%;
    height: 100%;
    overflow: auto;
    background-color: rgba(0, 0, 0, 0.4);
}

.modal-content {
    background-color: #fefefe;
    margin: 15% auto;
    padding: 0;
    border: 1px solid #888;
    border-radius: 5px;
    width: 400px;
    box-shadow: 0 4px 8px rgba(0, 0, 0, 0.1);
}

.modal-header {
    padding: 15px;
    border-bottom: 1px solid #eee;
    position: relative;
}

.modal-header h2 {
    margin: 0;
    font-size: 18px;
}

.close {
    position: absolute;
    right: 15px;
    top: 15px;
    font-size: 24px;
    font-weight: bold;
    cursor: pointer;
}

.modal-body {
    padding: 15px;
}

.modal-footer {
    padding: 15px;
    border-top: 1px solid #eee;
    text-align: right;
}

/* 삭제 모달 관련 스타일 */
#deleteContractModal .form-group {
    margin-bottom: 15px;
}

#deleteContractModal label {
    display: block;
    margin-bottom: 8px;
    font-weight: bold;
}

#deleteContractModal input {
    width: 100%;
    padding: 10px;
    border: 1px solid #ddd;
    border-radius: 4px;
    font-size: 14px;
}

#deleteContractModal .btn-danger {
    background-color: #dc3545;
    color: white;
    border: none;
    padding: 8px 15px;
    border-radius: 4px;
    cursor: pointer;
}

#deleteContractModal .btn-danger:hover {
    background-color: #c82333;
}
</style>

<script>
// 실행 환경에 따라 API 경로를 결정하는 함수
const isStandalone = <?php echo json_encode($is_standalone); ?>;
const memberId = <?php echo $member_id; ?>;

function getApiPath(endpoint) {
    // 직접 실행인 경우는 상대 경로, 포함된 경우는 폴더 경로 포함
    return isStandalone ? endpoint : `member_form_tabs_and_process/${endpoint}`;
}

// 계약 탭 초기화 함수
function initContractTab() {
    console.log("계약 탭 초기화");
    loadContracts();
}

// 계약 정보 로딩
function loadContracts() {
    console.log("계약 정보 로딩 시작");
    var memberId = $("#member_id").val();
    console.log("회원 ID: " + memberId);
    
    $.ajax({
        url: getApiPath('get_contracts.php'),
        type: 'POST',
        data: {
            member_id: memberId
        },
        dataType: 'json',
        success: function(response) {
            console.log("계약 데이터 응답:", response);
            if (response.success) {
                displayContracts(response.contracts);
                updateContractSummary(response.summary);
            } else {
                console.error("계약 정보 로딩 실패:", response.message);
                $("#contract-list").html('<tr><td colspan="7" class="text-center">계약 정보를 불러오는데 실패했습니다: ' + response.message + '</td></tr>');
            }
        },
        error: function(xhr, status, error) {
            console.error("AJAX 오류:", error);
            console.error("상태:", status);
            console.error("응답:", xhr.responseText);
            $("#contract-list").html('<tr><td colspan="7" class="text-center">서버 오류가 발생했습니다.</td></tr>');
        }
    });
}

// 계약 정보 표시
function displayContracts(contracts) {
    console.log("계약 정보 표시:", contracts);
    var html = '';
    
    if (contracts.length === 0) {
        html = '<tr><td colspan="7" class="text-center">등록된 계약이 없습니다.</td></tr>';
    } else {
        contracts.forEach(function(contract) {
            var rowClass = contract.is_deleted ? 'deleted-contract' : '';
            var deleteButton = contract.is_deleted ? '' : '<button type="button" class="btn btn-small btn-delete" onclick="deleteContract(' + contract.id + ')">삭제</button>';
            
            html += '<tr class="' + rowClass + '">' +
                '<td>' + contract.contract_name + '</td>' +
                '<td>' + contract.contract_type + '</td>' +
                '<td>' + contract.start_date + '</td>' +
                '<td>' + contract.end_date + '</td>' +
                '<td class="text-right">' + contract.total_amount.toLocaleString() + '원</td>' +
                '<td>' + contract.payment_method + '</td>' +
                '<td>' + deleteButton + '</td>' +
                '</tr>';
        });
    }
    
    $("#contract-list").html(html);
}

// 계약 요약 정보 업데이트
function updateContractSummary(summary) {
    console.log("계약 요약 정보 업데이트:", summary);
    $("#total-contract-count").text(summary.total_contracts);
    $("#active-contract-count").text(summary.active_contracts);
    $("#total-revenue").text(summary.total_revenue.toLocaleString() + '원');
}

// 계약 삭제 함수
function deleteContract(contractId) {
    console.log("계약 삭제 시작: 계약 ID = " + contractId);
    
    // 새 창에서 삭제 페이지 열기
    var memberId = <?php echo $member_id; ?>;
    var deleteUrl = getApiPath('contract_delete_form.php') + '?contract_id=' + contractId + '&member_id=' + memberId;
    window.open(deleteUrl, 'contract_delete_window', 'width=500,height=400,resizable=yes,scrollbars=yes');
}

// 모달 닫기 - 기존 모달 관련 함수는 새 창 방식으로 변경되어도 일단 유지
function closeDeleteModal() {
    console.log("삭제 모달 닫기");
    var modal = document.getElementById("deleteContractModal");
    if (!modal) {
        console.error("삭제 모달을 찾을 수 없습니다.");
        return;
    }
    
    modal.style.display = "none";
}

// 삭제 확인
function confirmDeleteContract() {
    console.log("계약 삭제 확인");
    var contractId = $("#deleteContractId").val();
    var password = $("#deletePassword").val();
    
    console.log("삭제할 계약 ID: " + contractId);
    
    if (!password) {
        alert("관리자 비밀번호를 입력해주세요.");
        return;
    }
    
    // 먼저 서버에 비밀번호 검증 요청
    verifyStaffPassword(contractId, password);
}

// 관리자 비밀번호 검증
function verifyStaffPassword(contractId, password) {
    console.log("관리자 비밀번호 검증 요청");
    
    $.ajax({
        url: getApiPath('verify_staff_delete.php'),
        type: 'POST',
        data: {
            contract_id: contractId,
            password: password
        },
        dataType: 'json',
        success: function(response) {
            console.log("비밀번호 검증 응답:", response);
            
            if (response.success) {
                // 비밀번호 검증 성공, 계약 삭제 요청
                deleteContractConfirmed(contractId, password);
            } else {
                alert("권한 검증 실패: " + response.message);
            }
        },
        error: function(xhr, status, error) {
            console.error("AJAX 오류:", error);
            console.error("상태:", status);
            console.error("응답:", xhr.responseText);
            alert("서버 오류가 발생했습니다. 관리자에게 문의하세요.");
        }
    });
}

// 서버에 삭제 요청 보내기
function deleteContractConfirmed(contractId, password) {
    console.log("계약 삭제 요청 전송");
    
    $.ajax({
        url: getApiPath('contract_delete.php'),
        type: 'POST',
        data: {
            contract_id: contractId,
            password: password
        },
        dataType: 'json',
        success: function(response) {
            console.log("삭제 응답:", response);
            
            if (response.success) {
                alert("계약이 성공적으로 삭제되었습니다.");
                closeDeleteModal();
                // 현재 페이지 새로고침
                location.reload();
            } else {
                alert("계약 삭제 실패: " + response.message);
                console.error("삭제 실패 상세:", response);
            }
        },
        error: function(xhr, status, error) {
            console.error("AJAX 오류:", error);
            console.error("상태:", status);
            console.error("응답:", xhr.responseText);
            alert("서버 오류가 발생했습니다. 관리자에게 문의하세요.");
        }
    });
}

// DOM 로드 후 이벤트 핸들러 등록
$(document).ready(function() {
    // 모달 닫기 버튼 이벤트
    $(".close").click(function() {
        closeDeleteModal();
    });
    
    // 모달 외부 클릭 시 닫기
    $(window).click(function(event) {
        var modal = document.getElementById("deleteContractModal");
        if (event.target == modal) {
            closeDeleteModal();
        }
    });
    
    // 디버깅 정보 출력
    console.log("contracts_tab.php 로드 완료");
    console.log("isStandalone:", isStandalone);
    console.log("Member ID:", memberId);
});

// 계약 등록 폼 열기
function openContractForm() {
    // 새 창에서 계약 등록 폼 열기
    var memberId = <?php echo $member_id; ?>;
    var contractFormUrl = getApiPath("contract_form.php?member_id=" + memberId);
    window.open(contractFormUrl, 'contract_form_window', 'width=700,height=800,resizable=yes,scrollbars=yes');
}
</script>

<!-- End of contracts_tab.php with debugging info -->
<?php echo "<!-- 회원권 탭 로딩 완료 -->"; ?> 