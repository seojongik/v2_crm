<?php
// 주니어 회원 등록/수정 페이지 - 새 창으로 열림

// 데이터베이스 연결 파일 포함
require_once dirname(__FILE__) . '/../../config/db_connect.php';

// 파라미터 검증
if (!isset($_GET['member_id']) || !isset($_GET['action'])) {
    echo '<div class="error-message">필수 파라미터가 전달되지 않았습니다.</div>';
    exit;
}

$member_id = intval($_GET['member_id']);
$action = $_GET['action'];
$junior_id = isset($_GET['junior_id']) ? intval($_GET['junior_id']) : null;
$is_edit_mode = ($action === 'edit' && $junior_id);

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

// 주니어 정보 조회 (수정 모드인 경우)
$junior = null;
$relation = null;

if ($is_edit_mode) {
    $junior_query = "
        SELECT 
            j.*,
            jr.relation
        FROM Junior j
        JOIN Junior_relation jr ON j.junior_id = jr.junior_id
        WHERE j.junior_id = ? AND jr.member_id = ?
        LIMIT 1
    ";
    
    $stmt = $db->prepare($junior_query);
    $stmt->bind_param('ii', $junior_id, $member_id);
    $stmt->execute();
    $junior_result = $stmt->get_result();
    
    if ($junior_result->num_rows === 0) {
        echo '<div class="error-message">주니어 정보를 찾을 수 없거나 접근 권한이 없습니다.</div>';
        exit;
    }
    
    $row = $junior_result->fetch_assoc();
    $junior = $row;
    $relation = $row['relation'];
}

// 페이지 제목 설정
$page_title = $is_edit_mode ? '주니어 회원 수정' : '주니어 회원 등록';
?>
<!DOCTYPE html>
<html lang="ko">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title><?php echo $page_title; ?></title>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/4.7.0/css/font-awesome.min.css">
    <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Noto+Sans+KR:wght@400;500;700&display=swap">
    <style>
        * {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
            font-family: 'Noto Sans KR', -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
        }
        
        body {
            background-color: #f5f5f5;
            padding: 20px;
        }
        
        .container {
            background-color: #fff;
            border-radius: 5px;
            box-shadow: 0 1px 3px rgba(0,0,0,0.1);
            padding: 20px;
            max-width: 100%;
        }
        
        .page-header {
            margin-bottom: 20px;
            padding-bottom: 10px;
            border-bottom: 1px solid #eee;
            text-align: center;
        }
        
        .page-header h1 {
            font-size: 24px;
            color: #333;
            font-weight: 600;
        }
        
        .form-group {
            margin-bottom: 15px;
        }
        
        .form-group label {
            display: block;
            margin-bottom: 5px;
            font-weight: bold;
            color: #333;
        }
        
        .form-group input,
        .form-group select {
            width: 100%;
            padding: 10px;
            border: 1px solid #ddd;
            border-radius: 4px;
            font-size: 14px;
        }
        
        .form-group input:focus,
        .form-group select:focus {
            border-color: #007bff;
            outline: none;
            box-shadow: 0 0 0 2px rgba(0, 123, 255, 0.25);
        }
        
        .form-group select {
            appearance: none;
            -webkit-appearance: none;
            -moz-appearance: none;
            background-image: url("data:image/svg+xml;charset=utf-8,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='12' fill='none' stroke='%23333' viewBox='0 0 12 12'%3E%3Cpath d='M3 5l3 3 3-3'/%3E%3C/svg%3E");
            background-repeat: no-repeat;
            background-position: right 10px center;
            background-size: 12px;
            padding-right: 30px;
        }
        
        .form-actions {
            display: flex;
            justify-content: center;
            gap: 10px;
            margin-top: 20px;
        }
        
        .btn {
            display: inline-block;
            font-weight: 700;
            text-align: center;
            white-space: nowrap;
            vertical-align: middle;
            border: 1px solid transparent;
            padding: 10px 20px;
            font-size: 14px;
            line-height: 1.5;
            border-radius: 4px;
            cursor: pointer;
            min-width: 120px;
        }
        
        .btn-cancel {
            background-color: #f8f9fa;
            color: #333;
            border: 1px solid #ddd;
        }
        
        .btn-cancel:hover {
            background-color: #e2e6ea;
        }
        
        .btn-primary {
            background-color: #007bff;
            color: white;
        }
        
        .btn-primary:hover {
            background-color: #0069d9;
        }
        
        .error-message {
            background-color: #f8d7da;
            color: #721c24;
            padding: 12px;
            border-radius: 4px;
            margin-bottom: 20px;
            text-align: center;
        }
    </style>
</head>
<body>
    <div class="container">
        <header class="page-header">
            <h1><i class="fa <?php echo $is_edit_mode ? 'fa-edit' : 'fa-child'; ?>"></i> <?php echo $page_title; ?></h1>
        </header>
        
        <form id="juniorForm">
            <input type="hidden" id="juniorId" name="juniorId" value="<?php echo $junior_id ?? ''; ?>">
            <input type="hidden" id="memberId" name="memberId" value="<?php echo $member_id; ?>">
            <input type="hidden" id="action" name="action" value="<?php echo $action; ?>">
            
            <div class="form-group">
                <label for="memberName"><i class="fa fa-user-circle"></i> 부모 회원</label>
                <input type="text" id="memberName" name="memberName" value="<?php echo htmlspecialchars($member['member_name']); ?>" readonly>
            </div>
            
            <div class="form-group">
                <label for="juniorName"><i class="fa fa-user"></i> 이름</label>
                <input type="text" id="juniorName" name="juniorName" value="<?php echo htmlspecialchars($junior['junior_name'] ?? ''); ?>" required>
            </div>
            
            <div class="form-group">
                <label for="juniorSchool"><i class="fa fa-graduation-cap"></i> 학교</label>
                <input type="text" id="juniorSchool" name="juniorSchool" value="<?php echo htmlspecialchars($junior['junior_school'] ?? ''); ?>">
            </div>
            
            <div class="form-group">
                <label for="juniorBirthday"><i class="fa fa-calendar"></i> 생년월일</label>
                <input type="date" id="juniorBirthday" name="juniorBirthday" value="<?php echo $junior ? substr($junior['junior_birthday'], 0, 10) : ''; ?>">
            </div>
            
            <div class="form-group">
                <label for="juniorRelation"><i class="fa fa-users"></i> 관계</label>
                <select id="juniorRelation" name="juniorRelation" required>
                    <option value="">선택</option>
                    <option value="부" <?php echo $relation === '부' ? 'selected' : ''; ?>>부</option>
                    <option value="모" <?php echo $relation === '모' ? 'selected' : ''; ?>>모</option>
                    <option value="조부" <?php echo $relation === '조부' ? 'selected' : ''; ?>>조부</option>
                    <option value="조모" <?php echo $relation === '조모' ? 'selected' : ''; ?>>조모</option>
                    <option value="기타" <?php echo $relation === '기타' ? 'selected' : ''; ?>>기타</option>
                </select>
            </div>
            
            <div class="form-actions">
                <button type="button" class="btn btn-cancel" onclick="window.close();"><i class="fa fa-times"></i> 취소</button>
                <button type="button" class="btn btn-primary" onclick="submitForm();"><i class="fa fa-check"></i> 저장</button>
            </div>
        </form>
    </div>
    
    <script>
        // API 경로 설정
        function getApiPath() {
            // 현재 페이지의 경로에서 API 경로 생성
            const path = window.location.pathname;
            const parentDir = path.substring(0, path.lastIndexOf('/'));
            return `${parentDir}/junior_process.php`;
        }
        
        // 폼 제출 함수
        function submitForm() {
            const juniorId = document.getElementById('juniorId').value;
            const memberId = document.getElementById('memberId').value;
            const juniorName = document.getElementById('juniorName').value.trim();
            const juniorSchool = document.getElementById('juniorSchool').value.trim();
            const juniorBirthday = document.getElementById('juniorBirthday').value;
            const juniorRelation = document.getElementById('juniorRelation').value;
            
            if (!juniorName || !juniorRelation) {
                alert('이름과 관계는 필수 입력 항목입니다.');
                return;
            }
            
            const action = juniorId ? 'update' : 'add';
            
            // API 호출하여 주니어 등록/수정
            fetch(getApiPath(), {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/x-www-form-urlencoded',
                },
                body: `action=${action}&junior_id=${juniorId}&member_id=${memberId}&junior_name=${encodeURIComponent(juniorName)}&junior_school=${encodeURIComponent(juniorSchool)}&junior_birthday=${juniorBirthday}&relation=${juniorRelation}`
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    alert(juniorId ? '주니어 정보가 수정되었습니다.' : '주니어가 등록되었습니다.');
                    if (window.opener && !window.opener.closed) {
                        window.opener.location.reload(); // 부모 창 새로고침
                    }
                    window.close(); // 현재 창 닫기
                } else {
                    alert('오류가 발생했습니다: ' + data.message);
                }
            })
            .catch(error => {
                console.error('Error:', error);
                alert('처리 중 오류가 발생했습니다.');
            });
        }
        
        // 페이지 로드 시 실행
        document.addEventListener('DOMContentLoaded', function() {
            console.log("junior_edit.php loaded successfully");
        });
    </script>
</body>
</html> 