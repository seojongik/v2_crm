<?php
// 수동차감적립 폼 - 별도 창으로 열림
require_once '../../config/db_connect.php';

// 회원 ID 가져오기
if (!isset($_GET['member_id']) || empty($_GET['member_id'])) {
    echo '<div class="error-message">회원 ID가 전달되지 않았습니다.</div>';
    exit;
}

$member_id = intval($_GET['member_id']);

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

// 현재 크레딧 잔액 조회
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
?>

<!DOCTYPE html>
<html lang="ko">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>수동차감적립 - <?php echo htmlspecialchars($member['member_name']); ?></title>
    <!-- FontAwesome 아이콘 라이브러리 추가 -->
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/4.7.0/css/font-awesome.min.css">
    <!-- Google Noto Sans KR 폰트 추가 -->
    <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Noto+Sans+KR:wght@400;500;700&display=swap">
    <script src="https://code.jquery.com/jquery-3.6.0.min.js"></script>
    <style>
        body {
            font-family: 'Noto Sans KR', sans-serif;
            line-height: 1.6;
            color: #333;
            background-color: #f0f7ff;
            margin: 0;
            padding: 20px;
        }
        
        .container {
            max-width: 480px;
            margin: 0 auto;
            padding: 20px;
            background-color: #fff;
            box-shadow: 0 8px 20px rgba(0, 123, 255, 0.1);
            border-radius: 12px;
            border: 1px solid #e1edff;
        }
        
        .header {
            text-align: center;
            margin-bottom: 20px;
            padding-bottom: 15px;
            border-bottom: 1px solid #d1e6ff;
        }
        
        .header h1 {
            margin: 0;
            font-size: 20px;
            color: #2c3e50;
        }
        
        .member-info {
            display: flex;
            justify-content: space-between;
            margin-bottom: 20px;
            padding: 15px;
            background: linear-gradient(to right, #ffffff, #f0f7ff);
            border-radius: 8px;
            border: 1px solid #d1e6ff;
        }
        
        .current-balance {
            font-size: 18px;
            font-weight: 700;
            color: #2980b9;
        }
        
        .current-balance.negative {
            color: #e74c3c;
        }
        
        .deduction-type-container {
            display: flex;
            gap: 10px;
            margin: 15px 0;
        }
        
        .deduction-type-btn {
            flex: 1;
            padding: 12px 15px;
            border: 1px solid #d1e6ff;
            background-color: #f8f9fa;
            border-radius: 50px;
            cursor: pointer;
            font-weight: 600;
            text-align: center;
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
            padding: 12px 15px;
            border: 1px solid #d1e6ff;
            border-radius: 8px;
            font-size: 14px;
            box-sizing: border-box;
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
        
        .btn, .btn-save {
            display: inline-flex;
            align-items: center;
            justify-content: center;
            padding: 10px 20px;
            border-radius: 50px;
            cursor: pointer;
            font-size: 14px;
            font-weight: 700;
            text-decoration: none;
            text-align: center;
            border: none;
            transition: all 0.3s ease;
            box-shadow: 0 3px 6px rgba(0,0,0,0.1);
        }
        
        .btn-save {
            background: linear-gradient(to right, #36d1dc, #5b86e5);
            color: white;
        }
        
        .btn-save:hover {
            background: linear-gradient(to right, #5b86e5, #36d1dc);
            transform: translateY(-2px);
            box-shadow: 0 5px 15px rgba(91, 134, 229, 0.4);
        }
        
        .btn {
            background: linear-gradient(to right, #a1c4fd, #c2e9fb);
            color: #2c3e50;
        }
        
        .btn:hover {
            background: linear-gradient(to right, #c2e9fb, #a1c4fd);
            transform: translateY(-2px);
            box-shadow: 0 5px 15px rgba(161, 196, 253, 0.4);
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
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1><?php echo htmlspecialchars($member['member_name']); ?> 회원 수동차감적립</h1>
        </div>
        
        <div class="member-info">
            <div>회원명: <strong><?php echo htmlspecialchars($member['member_name']); ?></strong></div>
            <div>현재 잔액: <span class="current-balance <?php echo $current_balance < 0 ? 'negative' : ''; ?>"><?php echo number_format($current_balance); ?>원</span></div>
        </div>
        
        <div class="deduction-type-container">
            <button type="button" class="deduction-type-btn" data-type="deduct">차감</button>
            <button type="button" class="deduction-type-btn" data-type="credit">적립</button>
        </div>
        
        <div class="form-group">
            <label for="deductionAmount">금액</label>
            <input type="number" id="deductionAmount" placeholder="금액을 입력하세요" min="1">
        </div>
        
        <div class="form-group">
            <label for="deductionText">적요</label>
            <input type="text" id="deductionText" placeholder="내용을 입력하세요">
        </div>
        
        <div class="form-actions">
            <button type="button" class="btn" onclick="window.close()">취소</button>
            <button type="button" class="btn-save" onclick="processDeduction()">확인</button>
        </div>
    </div>
    
    <script>
        // 전역 변수
        let selectedDeductionType = null;
        const memberId = <?php echo $member_id; ?>;
        
        // 차감/적립 버튼 이벤트 리스너
        document.addEventListener('DOMContentLoaded', function() {
            const deductionTypeButtons = document.querySelectorAll('.deduction-type-btn');
            deductionTypeButtons.forEach(button => {
                button.addEventListener('click', function() {
                    deductionTypeButtons.forEach(btn => btn.classList.remove('selected'));
                    this.classList.add('selected');
                    selectedDeductionType = this.dataset.type;
                });
            });
        });
        
        // 수동차감적립 처리 함수
        function processDeduction() {
            if (!selectedDeductionType) {
                alert('차감 또는 적립을 선택해주세요.');
                return;
            }

            const amount = Number(document.getElementById('deductionAmount').value);
            const text = document.getElementById('deductionText').value.trim();

            if (!amount || amount <= 0) {
                alert('올바른 금액을 입력해주세요.');
                return;
            }

            if (!text) {
                alert('적요를 입력해주세요.');
                return;
            }

            // 실제 금액 계산 (차감이면 음수, 적립이면 양수)
            const finalAmount = selectedDeductionType === 'deduct' ? -amount : amount;
            const creditType = selectedDeductionType === 'deduct' ? 'withdraw' : 'deposit';
            const description = selectedDeductionType === 'deduct' ? '수동차감: ' + text : '수동적립: ' + text;

            // 버튼 상태 변경
            const confirmBtn = document.querySelector('.btn-save');
            confirmBtn.textContent = '처리 중...';
            confirmBtn.disabled = true;

            // 서버에 전송
            fetch('../member_form_tabs_and_process/process_manual_credit.php', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/x-www-form-urlencoded',
                },
                body: `member_id=${memberId}&type=${creditType}&amount=${finalAmount}&text=${encodeURIComponent(description)}`
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    alert(selectedDeductionType === 'deduct' ? '차감이 처리되었습니다.' : '적립이 처리되었습니다.');
                    // 부모 창 새로고침
                    if (window.opener && !window.opener.closed) {
                        window.opener.location.reload();
                    }
                    window.close();
                } else {
                    alert('처리 중 오류가 발생했습니다: ' + (data.message || ''));
                }
            })
            .catch(error => {
                console.error('차감/적립 처리 오류:', error);
                alert('서버 통신 중 오류가 발생했습니다.');
            })
            .finally(() => {
                // 버튼 상태 복원
                confirmBtn.textContent = '확인';
                confirmBtn.disabled = false;
            });
        }
    </script>
</body>
</html> 