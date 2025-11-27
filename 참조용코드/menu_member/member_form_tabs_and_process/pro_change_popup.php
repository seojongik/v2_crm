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
?>

<!DOCTYPE html>
<html lang="ko">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title><?php echo htmlspecialchars($member['member_name']); ?> 담당프로 변경</title>
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

        /* 프로 목록 스타일 */
        .form-hint {
            font-size: 14px;
            color: var(--text-muted);
            margin-bottom: 15px;
        }

        .pro-list {
            max-height: 350px;
            overflow-y: auto;
            border: 1px solid #ddd;
            border-radius: 4px;
            padding: 10px;
            margin-bottom: 20px;
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
            width: 100%;
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
        <h1><?php echo htmlspecialchars($member['member_name']); ?> 담당프로 변경</h1>

        <div id="result-message" class="result-message"></div>

        <p class="form-hint">* 체크된 프로가 담당 프로입니다. 변경하려면 체크를 해제하거나 다른 프로를 선택하세요.</p>

        <div id="proList" class="pro-list">
            <div class="loading-message">프로 목록을 불러오는 중...</div>
        </div>

        <div class="actions">
            <button type="button" class="btn" onclick="saveProChanges()">저장</button>
            <button type="button" class="btn btn-secondary" onclick="window.close()">취소</button>
        </div>
    </div>

    <script>
        document.addEventListener('DOMContentLoaded', function() {
            // 프로 목록 불러오기
            loadProList();
        });

        function loadProList() {
            const memberId = <?php echo $member_id; ?>;
            const proListContainer = document.getElementById('proList');
            
            // 로딩 메시지 표시
            proListContainer.innerHTML = '<div class="loading-message">프로 목록을 불러오는 중...</div>';
            
            // AJAX 요청
            fetch('../member_form_tabs_and_process/get_pro_list.php?member_id=' + memberId)
                .then(response => {
                    if (!response.ok) {
                        throw new Error('서버 응답 오류');
                    }
                    return response.json();
                })
                .then(data => {
                    if (data.error) {
                        throw new Error(data.message || '데이터를 불러오는데 실패했습니다.');
                    }
                    
                    // 프로 목록 표시
                    if (!Array.isArray(data.pros) || data.pros.length === 0) {
                        proListContainer.innerHTML = '<div class="loading-message">등록된 프로가 없습니다.</div>';
                        return;
                    }
                    
                    // 프로 목록 렌더링
                    const proItems = data.pros.map(pro => {
                        const isActive = pro.staff_status === '재직';
                        const isAssigned = pro.is_assigned === true;
                        const statusClass = isActive ? 'active' : 'inactive';
                        const statusText = isActive ? '재직' : '퇴직';
                        const disabled = !isActive ? 'disabled' : '';
                        
                        return `
                        <div class="pro-item">
                            <label>
                                <input type="checkbox" name="pro_selection" 
                                    value="${pro.staff_nickname}" 
                                    ${isAssigned ? 'checked' : ''} 
                                    ${disabled}
                                    data-pro-name="${pro.staff_name}">
                                ${pro.staff_name} (${pro.staff_nickname})
                            </label>
                            <span class="pro-status ${statusClass}">${statusText}</span>
                        </div>
                        `;
                    }).join('');
                    
                    proListContainer.innerHTML = proItems;
                })
                .catch(error => {
                    console.error('프로 목록 불러오기 실패:', error);
                    proListContainer.innerHTML = `<div class="loading-message">오류: ${error.message}</div>`;
                });
        }

        function saveProChanges() {
            const memberId = <?php echo $member_id; ?>;
            const selectedPros = Array.from(document.querySelectorAll('input[name="pro_selection"]:checked')).map(cb => cb.value);
            
            // 선택된 프로 정보 (UI에 표시용)
            const selectedProNames = Array.from(document.querySelectorAll('input[name="pro_selection"]:checked')).map(cb => cb.dataset.proName);
            
            // AJAX 요청
            fetch('../member_form_tabs_and_process/update_pro_assignment.php', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    member_id: memberId,
                    pros: selectedPros
                })
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    // 성공 메시지 만들기
                    let message = '담당 프로가 ';
                    if (selectedProNames.length > 0) {
                        message += selectedProNames.join(', ') + '(으)로 ';
                    } else {
                        message += '없음으로 ';
                    }
                    message += '변경되었습니다.';
                    
                    // 결과 메시지 표시
                    const resultMessage = document.getElementById('result-message');
                    resultMessage.textContent = message;
                    resultMessage.style.display = 'block';
                    
                    // 부모 창 새로고침 및 현재 창 닫기
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
    </script>
</body>
</html> 