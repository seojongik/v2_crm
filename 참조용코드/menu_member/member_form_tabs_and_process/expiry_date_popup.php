<?php
// 에러 보고 설정
ini_set('display_errors', 1);
error_reporting(E_ALL);

// PHP 타임존 설정
date_default_timezone_set('Asia/Seoul');

// 데이터베이스 연결
require_once dirname(__FILE__) . '/../../config/db_connect.php';

// 필수 파라미터 체크
if (!isset($_GET['member_id']) || empty($_GET['member_id'])) {
    echo '<div class="error-message">회원 ID가 전달되지 않았습니다.</div>';
    exit;
}

if (!isset($_GET['current_expiry'])) {
    echo '<div class="error-message">현재 유효기간 정보가 전달되지 않았습니다.</div>';
    exit;
}

$member_id = intval($_GET['member_id']);
$current_expiry = $_GET['current_expiry'];

// 유효기간이 '-'인 경우 오늘 날짜로 설정
if ($current_expiry == '-') {
    $current_expiry = date('Y-m-d');
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
?>

<!DOCTYPE html>
<html lang="ko">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title><?php echo htmlspecialchars($member['member_name']); ?> 레슨권 유효기간 변경</title>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/5.15.3/css/all.min.css">
    <style>
        /* 폰트 및 기본 스타일 */
        @import url('https://fonts.googleapis.com/css2?family=Noto+Sans+KR:wght@300;400;500;700&display=swap');

        :root {
            --primary-color: #3498db;
            --primary-dark: #2980b9;
            --text-dark: #333;
            --text-muted: #666;
            --border-color: #eee;
            --background-light: #f8f9fa;
        }

        body {
            font-family: 'Noto Sans KR', sans-serif;
            color: var(--text-dark);
            margin: 0;
            padding: 20px;
            background-color: #f5f5f5;
        }

        .container {
            max-width: 100%;
            margin: 0 auto;
            background-color: #fff;
            border-radius: 8px;
            box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
            padding: 20px;
        }

        h1 {
            margin-top: 0;
            color: var(--text-dark);
            font-size: 24px;
            margin-bottom: 20px;
            padding-bottom: 10px;
            border-bottom: 1px solid var(--border-color);
        }

        /* 폼 스타일 */
        .form-group {
            margin-bottom: 20px;
        }

        .form-group label {
            display: block;
            margin-bottom: 8px;
            font-weight: 500;
            color: var(--text-dark);
            font-size: 16px;
        }

        .form-group input {
            width: 100%;
            padding: 10px;
            border: 1px solid #ddd;
            border-radius: 4px;
            font-size: 16px;
            box-sizing: border-box;
        }

        .form-group input[readonly] {
            background-color: var(--background-light);
        }

        .form-hint {
            font-size: 14px;
            color: var(--text-muted);
            margin-top: 5px;
        }

        /* 버튼 스타일 */
        .btn {
            padding: 10px 20px;
            background-color: var(--primary-color);
            color: white;
            border: none;
            border-radius: 4px;
            cursor: pointer;
            font-size: 16px;
            font-weight: 500;
        }

        .btn:hover {
            background-color: var(--primary-dark);
        }

        .btn-secondary {
            background-color: #6c757d;
        }

        .btn-secondary:hover {
            background-color: #5a6268;
        }

        .actions {
            text-align: center;
            margin-top: 20px;
        }

        /* 에러 메시지 */
        .error-message {
            color: #721c24;
            background-color: #f8d7da;
            border: 1px solid #f5c6cb;
            padding: 10px;
            border-radius: 4px;
            margin-bottom: 15px;
        }

        /* 결과 메시지 */
        .result-message {
            color: #155724;
            background-color: #d4edda;
            border: 1px solid #c3e6cb;
            padding: 10px;
            border-radius: 4px;
            margin-top: 15px;
            display: none;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1><?php echo htmlspecialchars($member['member_name']); ?> 레슨권 유효기간 변경</h1>

        <div id="result-message" class="result-message"></div>

        <form id="expiryDateForm">
            <div class="form-group">
                <label for="currentExpiryDate">현재 유효기간</label>
                <input type="text" id="currentExpiryDate" value="<?php echo htmlspecialchars($current_expiry); ?>" readonly>
            </div>

            <div class="form-group">
                <label for="newExpiryDate">새 유효기간</label>
                <input type="date" id="newExpiryDate" value="<?php echo htmlspecialchars($current_expiry); ?>" required>
                <p class="form-hint">* 설정한 날짜는 해당 회원의 모든 레슨권에 적용됩니다.</p>
            </div>

            <div class="actions">
                <button type="button" class="btn" onclick="updateExpiryDate()">변경</button>
                <button type="button" class="btn btn-secondary" onclick="window.close()">취소</button>
            </div>
        </form>
    </div>

    <script>
        function updateExpiryDate() {
            const memberId = <?php echo $member_id; ?>;
            const newExpiryDate = document.getElementById('newExpiryDate').value;
            
            if (!newExpiryDate) {
                alert('유효기간을 선택해주세요.');
                return;
            }
            
            if (confirm('이 회원의 모든 레슨권 유효기간을 ' + newExpiryDate + '로 변경하시겠습니까?')) {
                fetch('../member_form_tabs_and_process/update_lesson_expiry.php', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/x-www-form-urlencoded',
                    },
                    body: `member_id=${memberId}&expiry_date=${newExpiryDate}`
                })
                .then(response => response.json())
                .then(data => {
                    if (data.success) {
                        const resultMessage = document.getElementById('result-message');
                        resultMessage.textContent = '유효기간이 변경되었습니다.';
                        resultMessage.style.display = 'block';
                        
                        // 상태 업데이트 (선택사항: 부모 창 새로고침)
                        setTimeout(() => {
                            if (window.opener && !window.opener.closed) {
                                window.opener.location.reload();
                            }
                            window.close();
                        }, 2000);
                    } else {
                        alert(data.message || '변경 중 오류가 발생했습니다.');
                    }
                })
                .catch(error => {
                    console.error('Error:', error);
                    alert('변경 중 오류가 발생했습니다.');
                });
            }
        }
    </script>
</body>
</html> 