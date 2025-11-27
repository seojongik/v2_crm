<?php
// 주니어 탭 컨텐츠 - iframe 내에서 독립적으로 실행되는 페이지

// 필수 파라미터 확인
if (!isset($_GET['member_id'])) {
    echo '<div class="error-message">회원 ID가 전달되지 않았습니다.</div>';
    exit;
}

$member_id = intval($_GET['member_id']);

// 데이터베이스 연결 파일 포함
require_once dirname(__FILE__) . '/../../config/db_connect.php';

// 회원 정보 조회
$stmt = $db->prepare("SELECT member_id, member_name, member_gender, member_birthday FROM members WHERE member_id = ?");
$stmt->bind_param('i', $member_id);
$stmt->execute();
$result = $stmt->get_result();

if ($result->num_rows === 0) {
    echo '<div class="error-message">회원 정보를 찾을 수 없습니다.</div>';
    exit;
}

$member = $result->fetch_assoc();

// 부모 여부 확인 (회원이 Junior_relation 테이블에서 parent로 등록된 경우)
$check_parent_query = "SELECT COUNT(*) as count FROM Junior_relation WHERE member_id = ?";
$stmt = $db->prepare($check_parent_query);
$stmt->bind_param('i', $member_id);
$stmt->execute();
$parent_result = $stmt->get_result();
$parent_row = $parent_result->fetch_assoc();
$is_parent = ($parent_row['count'] > 0);
?>
<!DOCTYPE html>
<html lang="ko">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>주니어 회원 관리</title>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/4.7.0/css/font-awesome.min.css">
    <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Noto+Sans+KR:wght@400;500;700&display=swap">
    <style>
    /* 리셋 및 기본 스타일 */
    * {
        box-sizing: border-box;
        margin: 0;
        padding: 0;
        font-family: 'Noto Sans KR', -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
    }
    
    body {
        background-color: #ffffff;
        padding: 15px;
        font-size: 14px;
        line-height: 1.5;
    }
    
    /* 오류 메시지 */
    .error-message {
        background-color: #f8d7da;
        color: #721c24;
        padding: 12px;
        border-radius: 4px;
        margin-bottom: 20px;
        border: 1px solid #f5c6cb;
        text-align: center;
    }
    
    /* 자녀 탭 기본 스타일 */
    .juniors-tab-content {
        background-color: #ffffff;
        box-shadow: 0 1px 3px rgba(0,0,0,0.1);
        border-radius: 5px;
    }
    
    /* 섹션 헤더 */
    .section-header {
        display: flex;
        justify-content: space-between;
        align-items: center;
        margin-bottom: 20px;
        padding-bottom: 10px;
        border-bottom: 1px solid #eee;
    }
    
    .section-header h3 {
        font-size: 18px;
        margin: 0;
        color: #333;
        font-weight: 600;
    }
    
    /* 버튼 스타일 */
    .btn {
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
        background: linear-gradient(to right, #a1c4fd, #c2e9fb);
        color: #2c3e50;
    }
    
    .btn:hover {
        background: linear-gradient(to right, #c2e9fb, #a1c4fd);
        transform: translateY(-2px);
        box-shadow: 0 5px 15px rgba(161, 196, 253, 0.4);
    }
    
    .btn-small {
        padding: 5px 12px;
        font-size: 12px;
        font-weight: 700;
    }
    
    .btn-delete {
        background: linear-gradient(to right, #ff9a9e, #fad0c4);
        color: #742a2a;
    }
    
    .btn-delete:hover {
        background: linear-gradient(to right, #fad0c4, #ff9a9e);
        box-shadow: 0 5px 15px rgba(255, 154, 158, 0.4);
    }
    
    .section-actions .btn {
        background: linear-gradient(to right, #36d1dc, #5b86e5);
        color: white;
    }
    
    .section-actions .btn:hover {
        background: linear-gradient(to right, #5b86e5, #36d1dc);
        transform: translateY(-2px);
        box-shadow: 0 5px 15px rgba(91, 134, 229, 0.4);
    }
    
    .btn i {
        margin-right: 5px;
    }
    
    .section-actions {
        display: flex;
        gap: 10px;
    }
    
    /* 데이터 없음 표시 */
    .no-data {
        text-align: center;
        font-style: italic;
        color: #777;
        padding: 20px 0;
        background-color: #f8f9fa;
        border-radius: 5px;
    }
    
    /* 테이블 스타일 */
    .data-table {
        width: 100%;
        border-collapse: collapse;
        font-size: 14px;
        border: 1px solid #eee;
        margin-bottom: 30px;
    }
    
    .data-table th, 
    .data-table td {
        padding: 10px;
        text-align: center;
        border-bottom: 1px solid #eee;
    }
    
    .data-table th {
        background-color: #f8f9fa;
        font-weight: bold;
        color: #555;
    }
    
    .data-table tr:hover {
        background-color: #f8f9fa;
    }
    
    .text-right {
        text-align: right;
    }
    </style>
</head>
<body>
    <div class="juniors-tab-content">
        <div class="section-header">
            <h3><i class="fa fa-child"></i> 주니어 회원 관리</h3>
            <div class="section-actions">
                <button type="button" class="btn" onclick="openJuniorForm()"><i class="fa fa-plus"></i> 주니어 회원 등록</button>
            </div>
        </div>
        
        <?php
        // 주니어 정보 조회
        try {
            $junior_query = "
                SELECT 
                    j.junior_id,
                    j.junior_name,
                    j.junior_school,
                    j.junior_birthday,
                    j.junior_register,
                    jr.relation
                FROM Junior_relation jr
                JOIN Junior j ON jr.junior_id = j.junior_id
                WHERE jr.member_id = ?
                ORDER BY j.junior_register DESC
            ";
            
            $stmt = $db->prepare($junior_query);
            $stmt->bind_param('i', $member_id);
            $stmt->execute();
            $juniors = $stmt->get_result();
        ?>
        
        <table class="data-table">
            <thead>
                <tr>
                    <th>이름</th>
                    <th>학교</th>
                    <th>생년월일</th>
                    <th>등록일</th>
                    <th>관계</th>
                    <th>관리</th>
                </tr>
            </thead>
            <tbody>
                <?php if ($juniors->num_rows > 0) : ?>
                    <?php while ($junior = $juniors->fetch_assoc()) : ?>
                        <tr data-junior-id="<?php echo $junior['junior_id']; ?>">
                            <td><?php echo htmlspecialchars($junior['junior_name']); ?></td>
                            <td><?php echo htmlspecialchars($junior['junior_school'] ?: '-'); ?></td>
                            <td><?php echo $junior['junior_birthday'] ? date('Y-m-d', strtotime($junior['junior_birthday'])) : '-'; ?></td>
                            <td><?php echo date('Y-m-d', strtotime($junior['junior_register'])); ?></td>
                            <td><?php echo htmlspecialchars($junior['relation']); ?></td>
                            <td>
                                <button type="button" class="btn btn-small" onclick="editJunior(<?php echo $junior['junior_id']; ?>)"><i class="fa fa-pencil"></i> 수정</button>
                                <button type="button" class="btn btn-small btn-delete" onclick="deleteJunior(<?php echo $junior['junior_id']; ?>)"><i class="fa fa-trash"></i> 삭제</button>
                            </td>
                        </tr>
                    <?php endwhile; ?>
                <?php else : ?>
                    <tr>
                        <td colspan="6" class="no-data">등록된 주니어 회원이 없습니다.</td>
                    </tr>
                <?php endif; ?>
            </tbody>
        </table>
        
        <?php
        } catch (mysqli_sql_exception $e) {
            echo '<div class="error-message"><i class="fa fa-exclamation-triangle"></i> 주니어 정보를 불러올 수 없습니다. 필요한 테이블이 없거나 데이터베이스 오류가 발생했습니다.</div>';
        }
        ?>
        
        <div class="section-header">
            <h3><i class="fa fa-file-text-o"></i> 주니어 계약 이력</h3>
        </div>
        
        <?php
        // 주니어 계약 이력 조회
        try {
            $junior_contract_query = "
                SELECT 
                    ch.contract_history_id,
                    ch.contract_date,
                    c.contract_name,
                    j.junior_name,
                    ch.actual_price,
                    ch.actual_credit,
                    ch.payment_type,
                    ch.contract_history_status
                FROM contract_history ch
                JOIN contracts c ON ch.contract_id = c.contract_id
                LEFT JOIN Junior j ON ch.junior_id = j.junior_id
                WHERE ch.member_id = ?
                AND c.contract_type = '주니어'
                ORDER BY ch.contract_date DESC
            ";
            
            $stmt = $db->prepare($junior_contract_query);
            $stmt->bind_param('i', $member_id);
            $stmt->execute();
            $junior_contracts = $stmt->get_result();
        ?>
        
        <table class="data-table">
            <thead>
                <tr>
                    <th>계약일자</th>
                    <th>계약명</th>
                    <th>주니어</th>
                    <th>결제금액</th>
                    <th>크레딧</th>
                    <th>결제방식</th>
                    <th>상태</th>
                </tr>
            </thead>
            <tbody>
                <?php if ($junior_contracts->num_rows > 0) : ?>
                    <?php while ($contract = $junior_contracts->fetch_assoc()) : ?>
                        <tr>
                            <td><?php echo date('Y-m-d', strtotime($contract['contract_date'])); ?></td>
                            <td><?php echo htmlspecialchars($contract['contract_name']); ?></td>
                            <td><?php echo htmlspecialchars($contract['junior_name'] ?? '-'); ?></td>
                            <td class="text-right"><?php echo number_format($contract['actual_price']); ?>원</td>
                            <td class="text-right"><?php echo number_format($contract['actual_credit']); ?>원</td>
                            <td><?php echo htmlspecialchars($contract['payment_type'] ?? '-'); ?></td>
                            <td><?php echo htmlspecialchars($contract['contract_history_status']); ?></td>
                        </tr>
                    <?php endwhile; ?>
                <?php else : ?>
                    <tr>
                        <td colspan="7" class="no-data">주니어 계약 이력이 없습니다.</td>
                    </tr>
                <?php endif; ?>
            </tbody>
        </table>
        
        <?php
        } catch (mysqli_sql_exception $e) {
            echo '<div class="error-message"><i class="fa fa-exclamation-triangle"></i> 주니어 계약 이력을 불러올 수 없습니다. 필요한 테이블이 없거나 데이터베이스 오류가 발생했습니다.</div>';
        }
        ?>
    </div>

    <script>
    // 페이지 로드 후 부모 페이지에 높이 전달
    window.addEventListener('DOMContentLoaded', function() {
        // 페이지 높이 계산 및 부모 페이지에 전달
        function sendHeightToParent() {
            const height = document.body.scrollHeight;
            window.parent.postMessage({
                type: 'resize',
                height: height
            }, '*');
        }
        
        // 초기 높이 전달
        sendHeightToParent();
        
        // 창 크기 변경 시 높이 업데이트
        window.addEventListener('resize', sendHeightToParent);
    });
    
    // 회원 ID
    const memberId = <?php echo $member_id; ?>;
    
    // API 경로 생성 함수
    function getApiPath(endpoint) {
        const basePath = window.location.pathname.substring(0, window.location.pathname.lastIndexOf('/'));
        return `${basePath}/${endpoint}`;
    }
    
    // 주니어 폼 열기
    function openJuniorForm(junior_id = null) {
        const width = 600;
        const height = 500;
        const left = (window.innerWidth - width) / 2;
        const top = (window.innerHeight - height) / 2;
        
        let url = getApiPath('junior_edit.php') + '?member_id=' + memberId;
        if (junior_id) {
            url += '&junior_id=' + junior_id + '&action=edit';
        } else {
            url += '&action=add';
        }
        
        const newWindow = window.open(url, 'juniorEditWindow', `width=${width},height=${height},top=${top},left=${left},resizable=yes,scrollbars=yes`);
        
        // 창이 닫히면 부모 페이지 새로고침
        if (newWindow) {
            const timer = setInterval(function() {
                if (newWindow.closed) {
                    clearInterval(timer);
                    location.reload();
                }
            }, 500);
        }
    }
    
    // 주니어 수정
    function editJunior(junior_id) {
        openJuniorForm(junior_id);
    }
    
    // 주니어 삭제
    function deleteJunior(juniorId) {
        if (!confirm('이 주니어 회원을 삭제하시겠습니까?')) {
            return;
        }
        
        fetch(getApiPath('junior_process.php'), {
            method: 'POST',
            headers: {
                'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: `action=delete&junior_id=${juniorId}&member_id=${memberId}`
        })
        .then(response => response.json())
        .then(data => {
            if (data.success) {
                alert('주니어 회원이 삭제되었습니다.');
                location.reload();
            } else {
                alert('오류가 발생했습니다: ' + data.message);
            }
        })
        .catch(error => {
            console.error('Error:', error);
            alert('처리 중 오류가 발생했습니다.');
        });
    }
    </script>
</body>
</html> 