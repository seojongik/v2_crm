<?php
// 계약 삭제 폼 - 새 창에서 열림
require_once dirname(__FILE__) . '/../../config/db_connect.php';

// GET 파라미터 확인
if (!isset($_GET['contract_id']) || !isset($_GET['member_id'])) {
    echo '<div class="error-message">필수 파라미터가 누락되었습니다.</div>';
    exit;
}

$contract_id = intval($_GET['contract_id']);
$member_id = intval($_GET['member_id']);

// 계약 정보 가져오기
$stmt = $db->prepare("
    SELECT 
        ch.contract_history_id,
        ch.contract_date,
        ch.actual_price,
        ch.actual_credit,
        ch.payment_type,
        c.contract_type,
        c.contract_name,
        c.contract_LS,
        m.member_name
    FROM contract_history ch
    JOIN contracts c ON ch.contract_id = c.contract_id
    JOIN members m ON ch.member_id = m.member_id
    WHERE ch.contract_history_id = ? AND ch.member_id = ?
");
$stmt->bind_param('ii', $contract_id, $member_id);
$stmt->execute();
$result = $stmt->get_result();

if ($result->num_rows === 0) {
    echo '<div class="error-message">해당 계약 정보를 찾을 수 없습니다.</div>';
    exit;
}

$contract = $result->fetch_assoc();

// POST 요청 처리 (삭제 실행)
$error_message = "";
$success_message = "";

if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['delete'])) {
    // 비밀번호 검증
    $password = isset($_POST['password']) ? $_POST['password'] : '';
    
    if (empty($password)) {
        $error_message = "비밀번호를 입력해주세요.";
    } else {
        // 비밀번호 검증 로직
        $password_hash = '$2y$10$NvgmUiQNYTrDrLQzrPgAKuaX6ztFf/uhO.BBoL6yGIHwkWcTCJJfm'; // 실제 환경에서는 DB에서 가져와야 함
        
        if (password_verify($password, $password_hash) || $password === '1234') { // 임시 검증 로직 (실제 구현시 수정 필요)
            // 비밀번호 검증 성공, 계약 삭제 실행
            $update_stmt = $db->prepare("
                UPDATE contract_history 
                SET contract_history_status = '삭제'
                WHERE contract_history_id = ?
            ");
            $update_stmt->bind_param('i', $contract_id);
            
            if ($update_stmt->execute()) {
                $success_message = "계약이 성공적으로 삭제되었습니다.";
                // 부모 창 새로고침을 위한 스크립트 추가
                echo '<script>
                    setTimeout(function() {
                        window.opener.location.reload();
                        window.close();
                    }, 2000);
                </script>';
            } else {
                $error_message = "계약 삭제 중 오류가 발생했습니다: " . $db->error;
            }
        } else {
            $error_message = "비밀번호가 일치하지 않습니다.";
        }
    }
}
?>
<!DOCTYPE html>
<html lang="ko">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>계약 삭제</title>
    <link href="https://fonts.googleapis.com/css2?family=Noto+Sans+KR:wght@400;500;700&display=swap" rel="stylesheet">
    <style>
        body {
            font-family: 'Noto Sans KR', sans-serif;
            background-color: #f8f9fa;
            margin: 0;
            padding: 20px;
            font-size: 14px;
        }
        
        .container {
            max-width: 450px;
            margin: 0 auto;
            background: #fff;
            border-radius: 8px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            padding: 20px;
        }
        
        h1 {
            font-size: 20px;
            margin-top: 0;
            margin-bottom: 20px;
            color: #333;
            text-align: center;
            padding-bottom: 10px;
            border-bottom: 1px solid #eee;
        }
        
        .contract-info {
            margin-bottom: 20px;
            background-color: #f8f9fa;
            padding: 15px;
            border-radius: 5px;
            border-left: 4px solid #3498db;
        }
        
        .info-row {
            display: flex;
            justify-content: space-between;
            margin-bottom: 8px;
        }
        
        .info-label {
            font-weight: 500;
            color: #555;
        }
        
        .info-value {
            color: #333;
            text-align: right;
        }
        
        .warning-message {
            color: #dc3545;
            background-color: #fff5f5;
            padding: 10px;
            border-radius: 5px;
            margin-bottom: 20px;
            text-align: center;
        }
        
        .form-group {
            margin-bottom: 15px;
        }
        
        label {
            display: block;
            margin-bottom: 5px;
            font-weight: 500;
        }
        
        input[type="password"] {
            width: 100%;
            padding: 10px;
            border: 1px solid #ddd;
            border-radius: 4px;
            box-sizing: border-box;
        }
        
        .buttons {
            display: flex;
            justify-content: space-between;
        }
        
        .btn {
            padding: 10px 20px;
            border: none;
            border-radius: 4px;
            cursor: pointer;
            font-weight: 500;
        }
        
        .btn-cancel {
            background-color: #6c757d;
            color: white;
        }
        
        .btn-delete {
            background-color: #dc3545;
            color: white;
        }
        
        .btn:hover {
            opacity: 0.9;
        }
        
        /* 새로운 버튼 스타일 */
        .btn {
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
            gap: 6px;
        }
        
        .btn-cancel {
            background: linear-gradient(to right, #a1c4fd, #c2e9fb);
            color: #2c3e50;
        }
        
        .btn-cancel:hover {
            background: linear-gradient(to right, #c2e9fb, #a1c4fd);
            transform: translateY(-2px);
            box-shadow: 0 5px 15px rgba(161, 196, 253, 0.4);
        }
        
        .btn-delete {
            background: linear-gradient(to right, #ff9a9e, #fad0c4);
            color: #c23616;
        }
        
        .btn-delete:hover {
            background: linear-gradient(to right, #ff9a9e, #ff6b6b);
            transform: translateY(-2px);
            box-shadow: 0 5px 15px rgba(255, 154, 158, 0.4);
        }
        
        .error-message {
            color: #dc3545;
            background-color: #fff5f5;
            padding: 10px;
            border-radius: 5px;
            margin-bottom: 15px;
        }
        
        .success-message {
            color: #28a745;
            background-color: #f4fff5;
            padding: 10px;
            border-radius: 5px;
            margin-bottom: 15px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>계약 삭제</h1>
        
        <?php if ($error_message): ?>
        <div class="error-message"><?php echo $error_message; ?></div>
        <?php endif; ?>
        
        <?php if ($success_message): ?>
        <div class="success-message"><?php echo $success_message; ?></div>
        <?php else: ?>
        
        <div class="contract-info">
            <div class="info-row">
                <span class="info-label">회원명:</span>
                <span class="info-value"><?php echo htmlspecialchars($contract['member_name']); ?></span>
            </div>
            <div class="info-row">
                <span class="info-label">계약일자:</span>
                <span class="info-value"><?php echo date('Y-m-d', strtotime($contract['contract_date'])); ?></span>
            </div>
            <div class="info-row">
                <span class="info-label">상품명:</span>
                <span class="info-value"><?php echo htmlspecialchars($contract['contract_name']); ?></span>
            </div>
            <div class="info-row">
                <span class="info-label">결제금액:</span>
                <span class="info-value"><?php echo number_format($contract['actual_price']); ?>원</span>
            </div>
            <div class="info-row">
                <span class="info-label">크레딧:</span>
                <span class="info-value"><?php echo number_format($contract['actual_credit']); ?>c</span>
            </div>
            <div class="info-row">
                <span class="info-label">레슨횟수:</span>
                <span class="info-value"><?php echo $contract['contract_LS']; ?>회</span>
            </div>
        </div>
        
        <div class="warning-message">
            주의: 계약 삭제는 되돌릴 수 없으며, 관리자 권한이 필요합니다.
        </div>
        
        <form method="post">
            <div class="form-group">
                <label for="password">관리자 비밀번호:</label>
                <input type="password" id="password" name="password" required placeholder="비밀번호를 입력하세요">
            </div>
            
            <div class="buttons">
                <button type="button" class="btn btn-cancel" onclick="window.close()">취소</button>
                <button type="submit" name="delete" class="btn btn-delete">삭제 확인</button>
            </div>
        </form>
        
        <?php endif; ?>
    </div>
</body>
</html> 