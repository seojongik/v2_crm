<?php
// 홀드 등록 팝업 페이지
require_once('../../config/db_connect.php');

// URL 파라미터 받기
$term_id = isset($_GET['term_id']) ? intval($_GET['term_id']) : 0;
$member_id = isset($_GET['member_id']) ? intval($_GET['member_id']) : 0;
$member_name = isset($_GET['member_name']) ? $_GET['member_name'] : '';

// 파라미터 검증
if (!$term_id || !$member_id) {
    echo '<div class="error-message">필수 정보가 누락되었습니다.</div>';
    exit;
}

// 홀드 등록 처리
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $response = ['success' => false, 'message' => ''];
    
    // POST 데이터 검증
    $start_date = isset($_POST['start_date']) ? $_POST['start_date'] : '';
    $end_date = isset($_POST['end_date']) ? $_POST['end_date'] : '';
    $reason = isset($_POST['reason']) ? $_POST['reason'] : '';
    
    if (!$start_date || !$end_date || !$reason) {
        $response['message'] = '모든 필드를 입력해주세요.';
        echo json_encode($response);
        exit;
    }
    
    // 날짜 검증
    $start_timestamp = strtotime($start_date);
    $end_timestamp = strtotime($end_date);
    
    if ($start_timestamp > $end_timestamp) {
        $response['message'] = '시작일은 종료일보다 이전이어야 합니다.';
        echo json_encode($response);
        exit;
    }
    
    // 일수 계산 (종료일 포함)
    $days_diff = floor(($end_timestamp - $start_timestamp) / (60 * 60 * 24)) + 1;
    
    if ($days_diff > 30) {
        $response['message'] = '홀드 기간은 최대 30일까지 가능합니다.';
        echo json_encode($response);
        exit;
    }
    
    try {
        // 기간권 정보 확인
        $stmt = $db->prepare("
            SELECT 
                term_id, 
                term_startdate, 
                term_enddate, 
                term_expirydate 
            FROM Term_member 
            WHERE term_id = ?
        ");
        $stmt->bind_param('i', $term_id);
        $stmt->execute();
        $result = $stmt->get_result();
        
        if ($result->num_rows === 0) {
            $response['message'] = '기간권 정보를 찾을 수 없습니다.';
            echo json_encode($response);
            exit;
        }
        
        $term = $result->fetch_assoc();
        
        // 트랜잭션 시작
        $db->begin_transaction();
        
        // 홀드 등록
        $insert_query = "
            INSERT INTO Term_hold (
                term_id, 
                term_hold_start, 
                term_hold_end, 
                term_add_dates, 
                term_hold_reason, 
                staff_id, 
                term_hold_timestamp
            ) VALUES (?, ?, ?, ?, ?, ?, NOW())
        ";
        
        // 현재 로그인한 staff_id를 가져올 수 없으므로 임시로 10 사용
        $staff_id = 10;
        
        $stmt = $db->prepare($insert_query);
        $stmt->bind_param('issisi', $term_id, $start_date, $end_date, $days_diff, $reason, $staff_id);
        $result = $stmt->execute();
        
        if (!$result) {
            throw new Exception("홀드 등록 중 오류가 발생했습니다.");
        }
        
        // 기간권 만료일 업데이트
        $update_query = "
            UPDATE Term_member 
            SET term_expirydate = DATE_ADD(term_expirydate, INTERVAL ? DAY) 
            WHERE term_id = ?
        ";
        
        $stmt = $db->prepare($update_query);
        $stmt->bind_param('ii', $days_diff, $term_id);
        $result = $stmt->execute();
        
        if (!$result) {
            throw new Exception("만료일 업데이트 중 오류가 발생했습니다.");
        }
        
        // 트랜잭션 완료
        $db->commit();
        
        $response['success'] = true;
        $response['message'] = '홀드가 성공적으로 등록되었습니다.';
        echo json_encode($response);
        exit;
        
    } catch (Exception $e) {
        // 오류 발생 시 롤백
        $db->rollback();
        $response['message'] = $e->getMessage();
        echo json_encode($response);
        exit;
    }
}

// 기간권 정보 조회
$stmt = $db->prepare("
    SELECT 
        t.term_id, 
        t.term_type, 
        t.term_startdate, 
        t.term_enddate,
        t.term_expirydate
    FROM Term_member t 
    WHERE t.term_id = ? AND t.member_id = ?
");
$stmt->bind_param('ii', $term_id, $member_id);
$stmt->execute();
$result = $stmt->get_result();

if ($result->num_rows === 0) {
    echo '<div class="error-message">기간권 정보를 찾을 수 없습니다.</div>';
    exit;
}

$term = $result->fetch_assoc();
$current_date = date('Y-m-d');

// 홀드 목록 조회
$hold_list = [];
$stmt = $db->prepare("
    SELECT 
        th.term_hold_id,
        th.term_hold_start,
        th.term_hold_end,
        th.term_add_dates,
        th.term_hold_reason,
        s.staff_name,
        th.term_hold_timestamp
    FROM 
        Term_hold th
    LEFT JOIN 
        Staff s ON th.staff_id = s.staff_id
    WHERE 
        th.term_id = ?
    ORDER BY 
        th.term_hold_start DESC
");

$stmt->bind_param('i', $term_id);
$stmt->execute();
$hold_result = $stmt->get_result();

while ($row = $hold_result->fetch_assoc()) {
    // 날짜 포맷 변경
    $row['term_hold_start'] = date('Y-m-d', strtotime($row['term_hold_start']));
    $row['term_hold_end'] = date('Y-m-d', strtotime($row['term_hold_end']));
    $row['term_hold_timestamp'] = date('Y-m-d H:i', strtotime($row['term_hold_timestamp']));
    
    $hold_list[] = $row;
}
?>

<!DOCTYPE html>
<html lang="ko">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>홀드 등록 - <?php echo htmlspecialchars($member_name); ?></title>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/4.7.0/css/font-awesome.min.css">
    <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Noto+Sans+KR:wght@400;500;700&display=swap">
    <style>
        body {
            font-family: 'Noto Sans KR', sans-serif;
            padding: 20px;
            background-color: #f8f9fa;
            margin: 0;
        }
        
        .container {
            max-width: 100%;
            background-color: #fff;
            border-radius: 8px;
            box-shadow: 0 1px 3px rgba(0,0,0,0.1);
            padding: 20px;
        }
        
        .header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            border-bottom: 1px solid #eee;
            padding-bottom: 15px;
            margin-bottom: 20px;
        }
        
        .header h2 {
            margin: 0;
            font-size: 20px;
            color: #2c3e50;
        }
        
        .member-info {
            margin-bottom: 15px;
            color: #555;
        }
        
        .member-name {
            font-weight: 600;
            color: #3498db;
        }
        
        .term-info {
            background-color: #f8f9fa;
            padding: 10px;
            border-radius: 4px;
            margin-bottom: 20px;
        }
        
        .term-info p {
            margin: 5px 0;
        }
        
        .hold-list-container {
            margin-bottom: 20px;
            max-height: 200px;
            overflow-y: auto;
        }
        
        .data-table {
            width: 100%;
            border-collapse: collapse;
            font-size: 14px;
            margin-bottom: 20px;
        }
        
        .data-table th, 
        .data-table td {
            padding: 10px;
            border-bottom: 1px solid #eee;
            text-align: center;
        }
        
        .data-table th {
            background-color: #f8f9fa;
            font-weight: bold;
        }
        
        .text-center {
            text-align: center;
        }
        
        .text-right {
            text-align: right;
        }
        
        .form-group {
            margin-bottom: 15px;
        }
        
        .form-group label {
            display: block;
            margin-bottom: 5px;
            font-weight: bold;
        }
        
        .form-control {
            width: 100%;
            padding: 8px;
            border: 1px solid #ddd;
            border-radius: 4px;
            box-sizing: border-box;
        }
        
        .form-actions {
            display: flex;
            justify-content: flex-end;
            gap: 10px;
            margin-top: 15px;
        }
        
        button {
            padding: 8px 16px;
            border: none;
            border-radius: 4px;
            cursor: pointer;
            font-weight: bold;
            text-align: center;
        }
        
        .btn-cancel {
            background-color: #f8f9fa;
            color: #333;
        }
        
        .btn-submit {
            background-color: #007bff;
            color: white;
        }
        
        .error-message {
            color: #dc3545;
            padding: 10px;
            text-align: center;
            font-weight: bold;
            margin-bottom: 15px;
        }
        
        .no-data {
            font-style: italic;
            color: #777;
            padding: 10px 0;
            text-align: center;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h2>기간권 홀드 등록</h2>
        </div>
        
        <div class="member-info">
            <span class="member-name"><?php echo htmlspecialchars($member_name); ?></span> 회원님의 
            <strong><?php echo htmlspecialchars($term['term_type']); ?></strong> 기간권 홀드 정보입니다.
        </div>
        
        <div class="term-info">
            <p><strong>시작일:</strong> <?php echo date('Y-m-d', strtotime($term['term_startdate'])); ?></p>
            <p><strong>종료일:</strong> <?php echo date('Y-m-d', strtotime($term['term_enddate'])); ?></p>
            <p><strong>만료일:</strong> <?php echo date('Y-m-d', strtotime($term['term_expirydate'])); ?></p>
        </div>
        
        <div class="hold-list-container">
            <h3>홀드 내역</h3>
            <table class="data-table">
                <thead>
                    <tr>
                        <th>시작일</th>
                        <th>종료일</th>
                        <th>일수</th>
                        <th>사유</th>
                        <th>등록자</th>
                        <th>등록일시</th>
                    </tr>
                </thead>
                <tbody id="holdListBody">
                    <?php if (empty($hold_list)): ?>
                        <tr><td colspan="6" class="no-data">홀드 내역이 없습니다.</td></tr>
                    <?php else: ?>
                        <?php foreach ($hold_list as $hold): ?>
                            <tr>
                                <td class="text-center"><?php echo $hold['term_hold_start']; ?></td>
                                <td class="text-center"><?php echo $hold['term_hold_end']; ?></td>
                                <td class="text-right"><?php echo $hold['term_add_dates']; ?>일</td>
                                <td class="text-center"><?php echo $hold['term_hold_reason']; ?></td>
                                <td class="text-center"><?php echo $hold['staff_name'] ?: '-'; ?></td>
                                <td class="text-center"><?php echo $hold['term_hold_timestamp']; ?></td>
                            </tr>
                        <?php endforeach; ?>
                    <?php endif; ?>
                </tbody>
            </table>
        </div>
        
        <div class="hold-form" style="background: #f8f9fa; padding: 20px; border-radius: 4px;">
            <h3>홀드 등록</h3>
            <div class="form-group">
                <label>시작일</label>
                <input type="date" id="holdStartDate" class="form-control" value="<?php echo $current_date; ?>">
            </div>
            <div class="form-group">
                <label>종료일</label>
                <input type="date" id="holdEndDate" class="form-control">
            </div>
            <div class="form-group">
                <label>사유</label>
                <select id="holdReason" class="form-control">
                    <option value="">선택</option>
                    <option value="여행">여행</option>
                    <option value="업무">업무</option>
                    <option value="건강">건강</option>
                    <option value="기타">기타</option>
                </select>
            </div>
            <div class="form-actions">
                <button type="button" class="btn-cancel" onclick="window.close()">
                    <i class="fa fa-times"></i> 취소
                </button>
                <button type="button" class="btn-submit" onclick="registerHold()">
                    <i class="fa fa-check"></i> 등록
                </button>
            </div>
        </div>
    </div>
    
    <script>
        var termId = <?php echo json_encode($term_id); ?>;
        
        // 페이지 로드 시 실행
        document.addEventListener('DOMContentLoaded', function() {
            // 오늘 날짜 설정
            const today = new Date();
            const formattedToday = today.toISOString().split('T')[0];
            document.getElementById('holdStartDate').value = formattedToday;
            
            // 30일 후 날짜를 종료일로 설정
            const endDate = new Date(today);
            endDate.setDate(today.getDate() + 30);
            const formattedEndDate = endDate.toISOString().split('T')[0];
            document.getElementById('holdEndDate').value = formattedEndDate;
        });
        
        // 날짜 입력 제한
        document.getElementById('holdStartDate').addEventListener('change', function() {
            const startDate = new Date(this.value);
            const endDate = new Date(startDate);
            endDate.setDate(startDate.getDate() + 30);
            
            const formattedEndDate = endDate.toISOString().split('T')[0];
            document.getElementById('holdEndDate').value = formattedEndDate;
        });
        
        // 홀드 등록
        function registerHold() {
            const startDate = document.getElementById('holdStartDate').value;
            const endDate = document.getElementById('holdEndDate').value;
            const reason = document.getElementById('holdReason').value;

            if (!startDate || !endDate || !reason) {
                alert('모든 필드를 입력해주세요.');
                return;
            }
            
            // 시작일이 종료일보다 늦은지 확인
            if (new Date(startDate) > new Date(endDate)) {
                alert('시작일은 종료일보다 이전 날짜여야 합니다.');
                return;
            }
            
            // 홀드 기간이 30일을 초과하는지 확인
            const diffTime = Math.abs(new Date(endDate) - new Date(startDate));
            const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24)) + 1;
            
            if (diffDays > 30) {
                alert('홀드 기간은 최대 30일까지 가능합니다.');
                return;
            }

            // 폼 데이터 생성
            const formData = new FormData();
            formData.append('start_date', startDate);
            formData.append('end_date', endDate);
            formData.append('reason', reason);
            
            // 등록 버튼 비활성화하여 중복 등록 방지
            const submitButton = document.querySelector('.btn-submit');
            if (submitButton) {
                submitButton.disabled = true;
                submitButton.innerHTML = '<i class="fa fa-spinner fa-spin"></i> 처리 중...';
            }
            
            // 서버로 데이터 전송
            fetch(window.location.href, {
                method: 'POST',
                body: formData
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    // 성공 메시지 표시
                    alert('홀드가 성공적으로 등록되었습니다.');
                    
                    try {
                        // 부모 창 업데이트
                        if (window.opener && !window.opener.closed) {
                            console.log("부모 창 새로고침 시도");
                            
                            // 방법 1: 부모 창 전체 새로고침
                            window.opener.location.reload();
                            
                            // 방법 2: 부모 창의 함수 호출 시도 (실패 시에도 계속 진행)
                            try {
                                if (window.opener.termTabFunctions && typeof window.opener.termTabFunctions.refreshTermTab === 'function') {
                                    window.opener.termTabFunctions.refreshTermTab();
                                }
                            } catch (innerError) {
                                console.error("부모 창 함수 호출 실패:", innerError);
                            }
                        }
                    } catch (e) {
                        console.error("부모 창 접근 중 오류:", e);
                    } finally {
                        // 항상 창 닫기 시도
                        console.log("창 닫기 시도");
                        setTimeout(function() {
                            window.close();
                        }, 500);
                    }
                } else {
                    // 실패 메시지 표시
                    alert(data.message || '홀드 등록 중 오류가 발생했습니다.');
                    
                    // 버튼 상태 복원
                    if (submitButton) {
                        submitButton.disabled = false;
                        submitButton.innerHTML = '<i class="fa fa-check"></i> 등록';
                    }
                }
            })
            .catch(error => {
                console.error('Error:', error);
                alert('홀드 등록 중 오류가 발생했습니다. 네트워크 연결을 확인해주세요.');
                
                // 버튼 상태 복원
                if (submitButton) {
                    submitButton.disabled = false;
                    submitButton.innerHTML = '<i class="fa fa-check"></i> 등록';
                }
            });
        }
    </script>
</body>
</html> 