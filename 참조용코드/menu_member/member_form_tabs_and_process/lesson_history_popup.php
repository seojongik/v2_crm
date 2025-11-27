<?php
// 에러 보고 설정
ini_set('display_errors', 1);
error_reporting(E_ALL);

// PHP 타임존 설정
date_default_timezone_set('Asia/Seoul');

// 데이터베이스 연결
require_once dirname(__FILE__) . '/../../config/db_connect.php';

// member_id가 GET으로 전달됐는지 확인
if (!isset($_GET['member_id'])) {
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
    <title><?php echo htmlspecialchars($member['member_name']); ?> 회원 레슨 내역</title>
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

        /* 테이블 스타일 */
        .data-table-container {
            max-height: 550px;
            overflow-y: auto;
            margin-bottom: 20px;
        }

        table {
            width: 100%;
            border-collapse: collapse;
            font-size: 14px;
        }

        table th, table td {
            padding: 10px 8px;
            text-align: center;
            border: 1px solid #ddd;
        }

        table th {
            background-color: var(--background-light);
            font-weight: 600;
            position: sticky;
            top: 0;
            z-index: 10;
        }

        table tr:nth-child(even) {
            background-color: #f9f9f9;
        }

        table tr:hover {
            background-color: #f1f1f1;
        }

        .text-center {
            text-align: center;
        }

        .text-primary {
            color: #007bff;
        }

        .text-info {
            color: #17a2b8;
        }

        /* 버튼 스타일 */
        .btn {
            padding: 8px 16px;
            background-color: var(--primary-color);
            color: white;
            border: none;
            border-radius: 4px;
            cursor: pointer;
            font-size: 14px;
            font-weight: 500;
        }

        .btn:hover {
            background-color: var(--primary-dark);
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
    </style>
</head>
<body>
    <div class="container">
        <h1><?php echo htmlspecialchars($member['member_name']); ?> 회원 레슨 내역</h1>

        <div class="data-table-container">
            <table class="data-table">
                <thead>
                    <tr>
                        <th style="width: 5%;">No</th>
                        <th style="width: 15%;">일자</th>
                        <th style="width: 12%;">프로명</th>
                        <th style="width: 10%;">시작시간</th>
                        <th style="width: 10%;">종료시간</th>
                        <th style="width: 8%;">유형</th>
                        <th style="width: 10%;">수량</th>
                        <th style="width: 10%;">잔여량</th>
                    </tr>
                </thead>
                <tbody id="lessonHistoryTableBody">
                    <!-- 데이터가 여기에 로드됩니다 -->
                    <tr>
                        <td colspan="8" class="text-center">데이터를 불러오는 중...</td>
                    </tr>
                </tbody>
            </table>
        </div>

        <div class="actions">
            <button type="button" class="btn" onclick="window.print()">인쇄</button>
            <button type="button" class="btn" onclick="window.close()">닫기</button>
        </div>
    </div>

    <script>
        document.addEventListener('DOMContentLoaded', function() {
            // 레슨 내역 불러오기
            loadLessonHistory();
        });

        function loadLessonHistory() {
            const memberId = <?php echo $member_id; ?>;
            
            // 요일 변환 함수
            const getDayOfWeek = (dateString) => {
                if (!dateString) return '';
                const days = ['일', '월', '화', '수', '목', '금', '토'];
                const date = new Date(dateString);
                return days[date.getDay()];
            };
            
            // API 호출
            fetch('../member_form_tabs_and_process/get_lesson_history.php?member_id=' + memberId)
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
                    
                    const tbody = document.getElementById('lessonHistoryTableBody');
                    
                    if (!Array.isArray(data) || data.length === 0) {
                        tbody.innerHTML = '<tr><td colspan="8" class="text-center">레슨 내역이 없습니다.</td></tr>';
                        return;
                    }
                    
                    // 데이터를 역순으로 정렬 (이미 쿼리에서 DESC로 가져온 데이터를 다시 역순으로)
                    const sortedData = [...data].reverse();
                    
                    // 데이터 표시
                    tbody.innerHTML = sortedData.map((lesson, index) => {
                        // net_qty가 양수면 '구매', 음수면 '이용'으로 표시
                        const typeText = parseFloat(lesson.net_qty) > 0 ? '구매' : '이용';
                        // net_qty의 절댓값 표시
                        const qty = Math.abs(parseFloat(lesson.net_qty));
                        
                        // 날짜에 요일 추가
                        const dayOfWeek = getDayOfWeek(lesson.lesson_date);
                        const dateWithDay = lesson.lesson_date ? `${lesson.lesson_date} (${dayOfWeek})` : '-';
                        
                        // 유형에 따른 스타일 클래스
                        const typeClass = parseFloat(lesson.net_qty) > 0 ? 'text-primary' : 'text-info';
                        
                        return `
                            <tr>
                                <td class="text-center">${index + 1}</td>
                                <td class="text-center">${dateWithDay}</td>
                                <td class="text-center">${lesson.staff_name || '-'}</td>
                                <td class="text-center">${lesson.start_time || '-'}</td>
                                <td class="text-center">${lesson.end_time || '-'}</td>
                                <td class="text-center ${typeClass}">${typeText}</td>
                                <td class="text-center">${qty}</td>
                                <td class="text-center"><strong>${lesson.balance_after}</strong></td>
                            </tr>
                        `;
                    }).join('');
                })
                .catch(error => {
                    console.error('레슨 내역 조회 실패:', error);
                    document.getElementById('lessonHistoryTableBody').innerHTML = 
                        `<tr><td colspan="8" class="text-center">오류: ${error.message}</td></tr>`;
                });
        }
    </script>
</body>
</html> 