<?php
// 크레딧 탭 컨텐츠 - member_form.php에서 불러와서 사용

// 단독 실행인지 확인 - 독립 실행 시 필요한 헤더 추가
$is_standalone = !isset($in_parent_page);

// 디버깅을 위한 변수 출력
echo "<!-- 크레딧 탭 디버깅 시작 -->";
echo "<!-- 독립실행모드: " . ($is_standalone ? 'true' : 'false') . " -->";
echo "<!-- member_id 확인: " . (isset($member_id) ? $member_id : 'undefined') . " -->";

if ($is_standalone) {
    echo '<!DOCTYPE html>
    <html lang="ko">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>회원 크레딧 정보</title>
        <!-- FontAwesome 아이콘 라이브러리 추가 -->
        <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/4.7.0/css/font-awesome.min.css">
        <!-- Google Noto Sans KR 폰트 추가 -->
        <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Noto+Sans+KR:wght@400;500;700&display=swap">
        <script src="https://code.jquery.com/jquery-3.6.0.min.js"></script>
        <style>
            /* 기본 스타일 - style.css 대체 */
            body {
                font-family: \'Noto Sans KR\', sans-serif;
                line-height: 1.6;
                color: #333;
                background-color: #f0f7ff;
                margin: 0;
                padding: 0;
            }
            
            .container {
                max-width: 1200px;
                margin: 0 auto;
                padding: 20px;
                background-color: #fff;
                box-shadow: 0 8px 20px rgba(0, 123, 255, 0.1);
                border-radius: 12px;
                border: 1px solid #e1edff;
            }
            
            .page-actions {
                display: flex;
                justify-content: space-between;
                align-items: center;
                margin-bottom: 20px;
                padding-bottom: 10px;
                border-bottom: 1px solid #d1e6ff;
                background: linear-gradient(to right, #ffffff, #f0f7ff);
                padding: 15px;
                border-radius: 8px 8px 0 0;
            }
            
            .page-title {
                margin: 0;
                font-size: 24px;
                color: #2c3e50;
                font-weight: 700;
                text-shadow: 1px 1px 0 rgba(255,255,255,0.8);
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
            
            .btn-small {
                padding: 4px 8px;
                font-size: 12px;
            }
            
            .text-right {
                text-align: right;
            }
        </style>
    </head>
    <body>
    <div class="container">
    ';
} else {
    // 부모 페이지에서 포함될 때는 상대 경로 설정
    echo '';
}

// $db 변수가 전달되지 않는 문제를 해결하기 위해 DB 연결 직접 수행
if (!isset($db) || !$db) {
    echo "<!-- DB 연결 새로 수행 -->";
    require_once dirname(__FILE__) . '/../../config/db_connect.php';
} else {
    echo "<!-- 기존 DB 연결 사용 -->";
}

// member_id가 GET으로 전달됐는지 확인하고, 부모 페이지에서 가져올 수도 있음
if (!isset($_GET['id']) && !isset($member_id)) {
    echo '<div class="error-message">회원 ID가 전달되지 않았습니다.</div>';
    if ($is_standalone) echo '</div></body></html>';
    exit;
}

// member_id가 설정되지 않았다면 GET에서 가져옴
if (!isset($member_id)) {
    $member_id = intval($_GET['id']);
}

echo "<!-- member_id 처리 후: " . $member_id . " -->";

// 회원 정보 조회
$stmt = $db->prepare("SELECT member_id, member_name FROM members WHERE member_id = ?");
$stmt->bind_param('i', $member_id);
$stmt->execute();
$result = $stmt->get_result();
echo "<!-- 회원 정보 조회 결과: " . $result->num_rows . "행 -->";

if ($result->num_rows === 0) {
    echo '<div class="error-message">회원 정보를 찾을 수 없습니다.</div>';
    if ($is_standalone) echo '</div></body></html>';
    exit;
}

$member = $result->fetch_assoc();
echo "<!-- 회원 이름: " . $member['member_name'] . " -->";

// 현재 크레딧 잔액 조회 - bills 테이블 사용
$credit_query = "
    SELECT 
        bill_balance_after as current_balance
    FROM bills
    WHERE member_id = ?
    ORDER BY bill_id DESC
    LIMIT 1
";
$stmt = $db->prepare($credit_query);
$stmt->bind_param('i', $member_id);
$stmt->execute();
$credit_result = $stmt->get_result();
$credit_data = $credit_result->fetch_assoc();
$current_balance = $credit_data['current_balance'] ?? 0;
echo "<!-- 현재 잔액: " . $current_balance . " -->";
?>

<div class="credit-tab-content">
    <div class="tab-header">
        <div class="current-balance-container">
            <h3> 현재 크레딧 잔액</h3>
            <div class="current-balance <?php echo $current_balance < 0 ? 'negative' : ''; ?>">
                <?php echo number_format($current_balance); ?>원
            </div>
        </div>
      
        <div class="credit-actions">
            <button type="button" class="btn" id="deductionBtn"><strong>수동차감적립</strong></button>
            <button type="button" class="btn" id="purchaseBtn"><strong>상품구매</strong></button>
        </div>
    </div>
    
    <div class="credit-history">
        <div class="table-container">
            <table class="credit-table">
                <thead>
                    <tr>
                        <th width="100">날짜</th>
                        <th width="70">구분</th>
                        <th>내용</th>
                        <th width="100">총금액</th>
                        <th width="100">할인</th>
                        <th width="100">차감액</th>
                        <th width="100">잔액</th>
                    </tr>
                </thead>
                <tbody id="credit-history-body">
                    <?php
                    // 크레딧 내역 조회 - bills 테이블 사용
                    $history_query = "
                        SELECT 
                            bill_id as credit_id,
                            bill_date as credit_date,
                            CASE 
                                WHEN bill_netamt >= 0 THEN '적립'
                                ELSE '사용'
                            END as credit_type,
                            bill_text as credit_description,
                            bill_totalamt as total_amount,
                            bill_deduction as deduction,
                            bill_netamt as net_amount,
                            bill_balance_after as running_balance,
                            bill_status
                        FROM bills
                        WHERE member_id = ?
                        ORDER BY bill_date DESC, bill_id DESC
                    ";
                    echo "<!-- 크레딧 내역 쿼리 실행 전 -->";
                    $stmt = $db->prepare($history_query);
                    $stmt->bind_param('i', $member_id);
                    $stmt->execute();
                    $history_result = $stmt->get_result();
                    echo "<!-- 크레딧 내역 결과: " . $history_result->num_rows . "행 -->";
                    
                    $total_credit = 0;
                    $total_debit = 0;
                    
                    while ($credit = $history_result->fetch_assoc()) : 
                        // bill_status가 '삭제'인 경우 건너뛰기
                        if (isset($credit['bill_status']) && $credit['bill_status'] === '삭제') continue;
                        
                        $is_deposit = $credit['credit_type'] === '적립';
                        $amount_class = $is_deposit ? 'deposit' : 'withdraw';
                        
                        // 합계 계산
                        if ($is_deposit) {
                            $total_credit += abs($credit['net_amount']);
                        } else {
                            $total_debit += abs($credit['net_amount']);
                        }
                    ?>
                    <tr>
                        <td class="text-center"><?php echo date('Y-m-d', strtotime($credit['credit_date'])); ?></td>
                        <td class="text-center">
                            <span class="credit-type <?php echo $amount_class; ?>">
                                <?php echo $credit['credit_type']; ?>
                            </span>
                        </td>
                        <td class="text-left"><?php echo htmlspecialchars($credit['credit_description']); ?></td>
                        <td class="amount">
                            <?php 
                            if ($is_deposit) {
                                echo number_format(abs($credit['total_amount'])) . '원';
                            } else {
                                echo '-' . number_format(abs($credit['total_amount'])) . '원'; 
                            }
                            ?>
                        </td>
                        <td class="amount"><?php echo number_format($credit['deduction']); ?>원</td>
                        <td class="amount <?php echo $amount_class; ?>">
                            <?php echo ($is_deposit ? '+' : '-') . number_format(abs($credit['net_amount'])); ?>원
                        </td>
                        <td class="balance <?php echo $credit['running_balance'] < 0 ? 'negative' : ''; ?>">
                            <?php echo number_format($credit['running_balance']); ?>원
                        </td>
                    </tr>
                    <?php endwhile; ?>
                </tbody>
                <tfoot>
                    <tr>
                        <td colspan="7" class="text-right">
                            총적립액: <span id="total_credit"><?php echo number_format($total_credit); ?>원</span> | 
                            총차감액: <span id="total_debit"><?php echo number_format($total_debit); ?>원</span> | 
                            현잔액: <span id="current_balance"><?php echo number_format($current_balance); ?>원</span>
                        </td>
                    </tr>
                </tfoot>
            </table>
        </div>
    </div>
</div>

<!-- 수동 크레딧 입력 모달 -->
<div id="creditFormModal" class="modal">
    <div class="modal-content">
        <span class="close">&times;</span>
        <h2 id="creditFormTitle">크레딧 입금/사용</h2>
        <form id="creditForm">
            <input type="hidden" id="creditType" name="creditType" value="deposit">
            <input type="hidden" id="memberId" name="memberId" value="<?php echo $member_id; ?>">
            
            <div class="form-group">
                <label for="creditAmount">금액 (원)</label>
                <input type="number" id="creditAmount" name="creditAmount" required min="1">
            </div>
            
            <div class="form-group">
                <label for="creditDescription">내용</label>
                <input type="text" id="creditDescription" name="creditDescription" required>
            </div>
            
            <div class="form-actions">
                <button type="button" id="cancelCreditBtn" class="btn"><strong>취소</strong></button>
                <button type="button" id="submitCreditBtn" class="btn-save"><strong>확인</strong></button>
            </div>
        </form>
    </div>
</div>

<style>
    /* 크레딧 관련 스타일 */
    .credit-tab-content {
        margin-top: 20px;
        font-family: 'Noto Sans KR', sans-serif;
        width: 100%;
    }
    .tab-header {
        display: flex;
        justify-content: space-between;
        align-items: center;
        margin-bottom: 20px;
        padding-bottom: 15px;
        border-bottom: 1px solid #d1e6ff;
        background: linear-gradient(to right, #ffffff, #f0f7ff);
        padding: 15px;
        border-radius: 8px;
    }
    .current-balance-container {
        flex: 1;
    }
    .current-balance-container h3 {
        margin: 0 0 5px 0;
        font-size: 16px;
        color: #555;
    }
    .current-balance {
        font-size: 28px;
        font-weight: 700;
        color: #2980b9;
    }
    .current-balance.negative {
        color: #e74c3c;
    }
    .credit-actions {
        display: flex;
        gap: 10px;
    }
    .credit-table {
        width: 100%;
        border-collapse: collapse;
        font-size: 14px;
        box-shadow: 0 4px 8px rgba(0, 123, 255, 0.08);
        border-radius: 8px;
        overflow: hidden;
    }
    .credit-table th,
    .credit-table td {
        padding: 12px 15px;
        text-align: left;
        border-bottom: 1px solid #dee2e6;
        white-space: nowrap;
    }
    .credit-table th {
        background: linear-gradient(to right, #f8f9fa, #f0f7ff);
        color: #495057;
        font-weight: 600;
    }
    .credit-table tr:hover {
        background-color: #f1f9ff;
    }
    .text-center {
        text-align: center !important;
    }
    .text-right {
        text-align: right !important;
    }
    .credit-type {
        display: inline-block;
        padding: 3px 8px;
        border-radius: 12px;
        font-size: 12px;
        font-weight: 600;
    }
    .credit-type.deposit {
        background-color: #d4edda;
        color: #155724;
    }
    .credit-type.withdraw {
        background-color: #f8d7da;
        color: #721c24;
    }
    .credit-table tfoot {
        background-color: #f2f2f2;
        font-weight: bold;
    }
    .error-message {
        color: #e74c3c;
        padding: 15px;
        background-color: #fadbd8;
        border-radius: 8px;
        margin: 15px 0;
        box-shadow: 0 2px 4px rgba(231, 76, 60, 0.1);
        border: 1px solid #f5c6cb;
    }
    /* 테이블 컨테이너 스타일 */
    .table-container {
        overflow-x: auto;
        max-height: 500px;
        overflow-y: auto;
        border: 1px solid #d1e6ff;
        border-radius: 8px;
        background-color: #ffffff;
        box-shadow: 0 2px 10px rgba(0, 123, 255, 0.07);
    }
    /* 수동차감적립 버튼 스타일 */
    .deduction-type-container {
        display: flex;
        gap: 10px;
        margin: 15px 0;
    }
    .deduction-type-btn {
        padding: 8px 16px;
        border: 1px solid #d1e6ff;
        background-color: #f8f9fa;
        border-radius: 50px;
        cursor: pointer;
        font-weight: 600;
        transition: all 0.3s ease;
    }
    .deduction-type-btn:hover {
        background-color: #f0f7ff;
        border-color: #a1c4fd;
        transform: translateY(-2px);
    }
    .deduction-type-btn.selected {
        background: linear-gradient(to right, #36d1dc, #5b86e5);
        color: white;
        border-color: transparent;
        box-shadow: 0 3px 8px rgba(91, 134, 229, 0.3);
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
        background-color: rgba(0,0,0,0.4);
    }
    .modal-content {
        background-color: #fefefe;
        margin: 10% auto;
        padding: 25px;
        border: 1px solid #d1e6ff;
        width: 400px;
        border-radius: 12px;
        box-shadow: 0 10px 30px rgba(0,0,0,0.15);
        animation: fadeIn 0.3s ease-out;
    }
    @keyframes fadeIn {
        from { opacity: 0; transform: translateY(-20px); }
        to { opacity: 1; transform: translateY(0); }
    }
    .close {
        color: #a1c4fd;
        float: right;
        font-size: 28px;
        font-weight: bold;
        cursor: pointer;
        transition: all 0.2s;
    }
    .close:hover {
        color: #3498db;
        transform: rotate(90deg);
    }
    .form-group {
        margin-bottom: 20px;
    }
    .form-group label {
        display: block;
        margin-bottom: 8px;
        font-weight: 600;
        color: #2c3e50;
    }
    .form-group input {
        width: 100%;
        padding: 10px 12px;
        border: 1px solid #d1e6ff;
        border-radius: 8px;
        font-size: 14px;
        transition: all 0.3s;
        background-color: #f8faff;
        box-shadow: inset 0 1px 3px rgba(0, 123, 255, 0.05);
    }
    .form-group input:focus {
        border-color: #3498db;
        outline: none;
        box-shadow: 0 0 0 3px rgba(52, 152, 219, 0.2);
        background-color: #ffffff;
    }
    .form-actions {
        display: flex;
        justify-content: flex-end;
        gap: 10px;
        margin-top: 25px;
    }
</style>

<script>
document.addEventListener('DOMContentLoaded', function() {
    // FontAwesome 아이콘 라이브러리 추가 (인라인으로)
    if (!document.getElementById('fontawesome-css')) {
        const link = document.createElement('link');
        link.id = 'fontawesome-css';
        link.rel = 'stylesheet';
        link.href = 'https://cdnjs.cloudflare.com/ajax/libs/font-awesome/4.7.0/css/font-awesome.min.css';
        document.head.appendChild(link);
    }

    // Google Noto Sans KR 폰트 추가 (인라인으로)
    if (!document.getElementById('noto-sans-kr')) {
        const link = document.createElement('link');
        link.id = 'noto-sans-kr';
        link.rel = 'stylesheet';
        link.href = 'https://fonts.googleapis.com/css2?family=Noto+Sans+KR:wght@400;500;700&display=swap';
        document.head.appendChild(link);
    }
    
    // 크레딧 탭 활성화
    const creditTab = document.querySelector('.tab-button[data-tab="credit"]');
    if (creditTab) {
        creditTab.classList.add('active');
    }

    // 경로 설정 - 더 명확하게 함수로 정의
    const isStandalone = <?php echo json_encode($is_standalone); ?>;
    const memberId = <?php echo $member['member_id']; ?>;
    
    // 실행 환경에 따라 API 경로를 결정하는 함수
    function getApiPath(endpoint) {
        // 직접 실행인 경우는 상대 경로, 포함된 경우는 폴더 경로 포함
        return isStandalone ? endpoint : `member_form_tabs_and_process/${endpoint}`;
    }
    
    // 모달 제어 함수
    function openModal(modalId) {
        document.getElementById(modalId).style.display = 'block';
    }
    
    function closeModal(modalId) {
        document.getElementById(modalId).style.display = 'none';
    }
    
    // 모달 닫기 버튼 이벤트 연결
    document.querySelectorAll('.close').forEach(function(closeBtn) {
        closeBtn.addEventListener('click', function() {
            this.closest('.modal').style.display = 'none';
        });
    });
    
    // 크레딧 폼 취소 버튼
    document.getElementById('cancelCreditBtn').addEventListener('click', function() {
        closeModal('creditFormModal');
    });
    
    // 크레딧 폼 제출 버튼
    document.getElementById('submitCreditBtn').addEventListener('click', function() {
        const memberId = document.getElementById('memberId').value;
        const creditType = document.getElementById('creditType').value;
        const creditAmount = document.getElementById('creditAmount').value;
        const creditDescription = document.getElementById('creditDescription').value;
        
        // 유효성 검사
        if (!creditAmount || isNaN(parseInt(creditAmount)) || parseInt(creditAmount) <= 0) {
            alert('유효한 금액을 입력해주세요.');
            return;
        }
        
        if (!creditDescription.trim()) {
            alert('내용을 입력해주세요.');
            return;
        }
        
        // 로딩 표시
        this.textContent = '처리 중...';
        this.disabled = true;
        
        // 서버에 전송 - 수정된 경로 사용
        fetch(getApiPath('process_manual_credit.php'), {
            method: 'POST',
            headers: {
                'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: `member_id=${memberId}&type=${creditType}&amount=${creditAmount}&text=${encodeURIComponent(creditDescription)}`
        })
        .then(response => response.json())
        .then(data => {
            if (data.success) {
                alert(creditType === 'deposit' ? '입금이 처리되었습니다.' : '사용이 처리되었습니다.');
                closeModal('creditFormModal');
                // 페이지 새로고침
                window.location.reload();
            } else {
                alert('처리 중 오류가 발생했습니다: ' + (data.message || ''));
            }
        })
        .catch(error => {
            console.error('크레딧 처리 오류:', error);
            alert('서버 통신 중 오류가 발생했습니다.');
        })
        .finally(() => {
            // 버튼 상태 복원
            this.textContent = '확인';
            this.disabled = false;
        });
    });
    
    // ESC 키로 모달 닫기
    document.addEventListener('keydown', function(event) {
        if (event.key === 'Escape') {
            document.querySelectorAll('.modal').forEach(function(modal) {
                modal.style.display = 'none';
            });
        }
    });
    
    // 창 클릭 시 모달 닫기
    window.addEventListener('click', function(event) {
        document.querySelectorAll('.modal').forEach(function(modal) {
            if (event.target === modal) {
                modal.style.display = 'none';
            }
        });
    });
    
    // 수동차감적립과 상품구매 버튼 이벤트
    document.getElementById('deductionBtn').addEventListener('click', function() {
        openDeductionModal();
    });

    document.getElementById('purchaseBtn').addEventListener('click', function() {
        openPurchaseModal();
    });

    // 수동차감적립 모달 관련 설정
    const deductionTypeButtons = document.querySelectorAll('.deduction-type-btn');
    deductionTypeButtons.forEach(button => {
        button.addEventListener('click', function() {
            deductionTypeButtons.forEach(btn => btn.classList.remove('selected'));
            this.classList.add('selected');
            selectedDeductionType = this.dataset.type;
        });
    });
    
    console.log("DOM 로드 완료");
});

// 전역 변수 선언
let selectedDeductionType = null;

// 전역 함수로 getApiPath 정의
function getApiPath(endpoint) {
    const isStandalone = <?php echo json_encode($is_standalone); ?>;
    return isStandalone ? endpoint : `member_form_tabs_and_process/${endpoint}`;
}

// 수동차감적립 관련 함수들
function openDeductionModal() {
    // 현재 잔액 가져오기
    const isStandalone = <?php echo json_encode($is_standalone); ?>;
    const memberId = <?php echo $member['member_id']; ?>;
    
    // 별도 창으로 열기
    const width = 500;
    const height = 400;
    const left = (window.screen.width - width) / 2;
    const top = (window.screen.height - height) / 2;
    
    const url = getApiPath(`deduction_form.php?member_id=${memberId}`);
    window.open(url, 'DeductionWindow', `width=${width},height=${height},left=${left},top=${top},resizable=yes,scrollbars=yes,status=yes`);
}

function closeDeductionModal() {
    // 별도 창으로 변경하면서 불필요해짐
    // document.getElementById('deductionModal').style.display = 'none';
}

function processDeduction() {
    // 별도 창으로 변경하면서 불필요해짐
    // 해당 기능은 deduction_form.php에서 처리됨
}

// 상품구매 관련 함수
function openPurchaseModal() {
    // member_id를 URL에서 가져오기
    const memberId = <?php echo $member['member_id']; ?>;
    const isStandalone = <?php echo json_encode($is_standalone); ?>;
    
    // 별도 창으로 열기
    const width = 700;
    const height = 800;
    const left = (window.screen.width - width) / 2;
    const top = (window.screen.height - height) / 2;
    
    const url = getApiPath(`product_form.php?member_id=${memberId}&return_tab=credit`);
    window.open(url, 'ProductPurchaseWindow', `width=${width},height=${height},left=${left},top=${top},resizable=yes,scrollbars=yes,status=yes`);
}
</script>

<?php
// 독립 실행 시 HTML 닫기 태그 추가
if ($is_standalone) {
    echo '</div></body></html>';
}

// 추가 디버깅 정보
echo "<!-- 크레딧 탭 로딩 완료 -->";
?>

<!-- End of credit_tab.php with debugging info -->
<script>
console.log("credit_tab.php loaded successfully");
console.log("isStandalone:", <?php echo json_encode($is_standalone); ?>);
console.log("Member ID:", <?php echo json_encode($member_id); ?>);
document.addEventListener('DOMContentLoaded', function() {
    console.log("Credit tab DOM fully loaded");
});
</script> 