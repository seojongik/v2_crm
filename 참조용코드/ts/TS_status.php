<?php
// 캐시 방지 헤더 추가
header("Cache-Control: no-store, no-cache, must-revalidate, max-age=0");
header("Cache-Control: post-check=0, pre-check=0", false);
header("Pragma: no-cache");

require_once '../common/header.php';
require_once '../config/db_config.php';

// Google Noto Sans KR 폰트 추가
echo '<script>
if (!document.getElementById("noto-sans-kr")) {
    const link = document.createElement("link");
    link.id = "noto-sans-kr";
    link.rel = "stylesheet";
    link.href = "https://fonts.googleapis.com/css2?family=Noto+Sans+KR:wght@400;500;700&display=swap";
    document.head.appendChild(link);
}
</script>';

// DB 연결 시 문자셋 설정 추가
$conn = new mysqli($db_config['host'], $db_config['user'], $db_config['password'], $db_config['db']);
if ($conn->connect_error) {
    die("Connection failed: " . $conn->connect_error);
}
$conn->set_charset("utf8mb4");

// 날짜 파라미터 처리
$selected_date = isset($_GET['date']) ? $_GET['date'] : date('Y-m-d');
?>

<div class="container">
    <!-- 타석현황 제목 제거 -->
    
    <!-- 날짜 선택 폼 추가 -->
    <div class="date-selector">
        <form method="get" class="date-form">
            <input type="date" name="date" value="<?= $selected_date ?>" onchange="this.form.submit()" class="form-control">
            <button type="button" id="goToToday" class="today-btn">오늘</button>
        </form>
    </div>

    <?php
    // 선택된 날짜로 쿼리 수정
    // 회원별 최신 bill_balance_after도 함께 가져오기
    $sql = "SELECT t.*, m.member_id,
            (SELECT b.bill_balance_after 
             FROM bills b 
             WHERE b.member_id = m.member_id 
             ORDER BY b.bill_id DESC 
             LIMIT 1) as credit_balance 
            FROM `FMS_TS` t 
            LEFT JOIN `members` m ON t.연락처 = m.member_phone 
            WHERE t.`일자` = ? AND t.`분류` != '예약취소' 
            ORDER BY t.`타석번호`, t.`시작시간`";
    $stmt = $conn->prepare($sql);
    if ($stmt === false) {
        die("Prepare failed: " . $conn->error);
    }

    $stmt->bind_param("s", $selected_date);
    $stmt->execute();
    $result = $stmt->get_result();

    // 예약 데이터를 배열로 저장
    $reservations = [];
    while ($row = $result->fetch_assoc()) {
        $reservations[] = $row;
    }
    ?>

    <div class="timetable-container">
        <?php
        // 테이블 셀 너비 정의
        $timeColWidth = 80;   // 시간 열 너비
        $bayColWidth = 100;   // 타석 열 너비
        $totalBays = 9;       // 총 타석 수
        $totalWidth = $timeColWidth + ($bayColWidth * $totalBays); // 테이블 총 너비
        ?>
        <table class="timetable" cellspacing="0" cellpadding="0" style="width: <?= $totalWidth ?>px; border-right: none;">
            <colgroup>
                <col width="<?= $timeColWidth ?>">
                <?php for ($i = 1; $i <= $totalBays; $i++): ?>
                    <col width="<?= $bayColWidth ?>">
                <?php endfor; ?>
            </colgroup>
            <thead>
                <tr>
                    <th class="time-header">시간</th>
                    <?php for ($i = 1; $i <= $totalBays; $i++): ?>
                        <th class="bay-header"><?= $i ?>번 타석</th>
                    <?php endfor; ?>
                </tr>
            </thead>
            <tbody>
                <?php for ($hour = 6; $hour <= 24; $hour++): ?>
                    <tr class="hour-row <?= $hour % 6 == 0 ? 'divider' : '' ?>">
                        <td class="hour-cell"><?= sprintf("%02d", $hour % 24) ?>:00</td>
                        <?php for ($bay = 1; $bay <= $totalBays; $bay++): ?>
                            <td class="bay-cell" data-hour="<?= $hour ?>" data-bay="<?= $bay ?>"></td>
                        <?php endfor; ?>
                    </tr>
                <?php endfor; ?>
            </tbody>
        </table>
        
        <!-- 예약 박스 -->
        <?php 
        // 셀 높이 설정
        $rowHeight = 60;     // 행 높이
        $headerHeight = 40;  // 헤더 높이

        foreach ($reservations as $reservation): 
            // 시작 시간과 종료 시간 파싱
            $timeStr = substr($reservation['시작시간'], -8, 5);
            $timeArr = explode(':', $timeStr);
            $startHour = intval($timeArr[0]);
            $startMin = intval($timeArr[1]);
            
            $endTimeStr = substr($reservation['종료시간'], -8, 5);
            $endTimeArr = explode(':', $endTimeStr);
            $endHour = intval($endTimeArr[0]);
            $endMin = intval($endTimeArr[1]);
            
            // 시작 시간 계산 (6시 기준, 픽셀로 변환)
            $hourDiff = $startHour - 6;
            if ($hourDiff < 0) $hourDiff += 24; // 6시 이전은 다음날로 계산
            
            // 행 위치 계산
            $startPos = ($hourDiff * $rowHeight) + ($startMin / 60 * $rowHeight) + $headerHeight;
            
            // 종료 시간 계산
            $durationHours = 0;
            $durationMins = 0;
            
            if ($endHour < $startHour) {
                // 다음날로 넘어가는 경우
                $durationHours = ($endHour + 24) - $startHour;
            } else {
                $durationHours = $endHour - $startHour;
            }
            
            if ($endMin < $startMin) {
                $durationMins = ($endMin + 60) - $startMin;
                $durationHours--;
            } else {
                $durationMins = $endMin - $startMin;
            }
            
            // 박스 높이 계산
            $height = max(20, ($durationHours + $durationMins / 60) * $rowHeight);
            
            // 타석 번호 (1부터 시작)
            $bayNum = intval($reservation['타석번호']);
            
            // 정확한 위치 계산
            $leftPos = $timeColWidth + ($bayNum - 1) * $bayColWidth;
            
            // 박스 크기 계산 (셀 내부에 딱 맞게, 2px 여백)
            $boxWidth = $bayColWidth - 2;
            
            // 상태 클래스 설정
            if ($reservation['분류'] === '결제완료') {
                if (!isset($reservation['credit_balance'])) {
                    $statusClass = 'status-missing-data';
                } else if ($reservation['credit_balance'] < 0) {
                    $statusClass = 'status-negative';
                } else {
                    $statusClass = 'status-completed';
                }
            } else {
                $statusClass = match($reservation['분류']) {
                    '주니어' => 'status-junior',
                    '웰빙클럽', '리프레쉬', '아이코젠', '김캐디' => 'status-wellbeing',
                    '확인대상' => 'status-pending',
                    default => 'status-other'
                };
            }
            
            // 예약 정보 데이터 (호버 표시용)
            $hoverInfo = htmlspecialchars(
                $reservation['회원명'] . ' - ' . 
                substr($reservation['시작시간'], -8, 5) . ' ~ ' . 
                substr($reservation['종료시간'], -8, 5) . 
                (isset($reservation['credit_balance']) ? ' (잔액: ' . number_format($reservation['credit_balance']) . '원)' : '')
            );
        ?>
        <div class="reservation <?= $statusClass ?>" 
             style="top: <?= round($startPos) ?>px; left: <?= $leftPos + 1 ?>px; height: <?= round($height) ?>px; width: <?= $boxWidth ?>px;"
             data-member-id="<?= $reservation['member_id'] ?>" 
             data-bay="<?= $bayNum ?>"
             data-time="<?= $startHour ?>:<?= $startMin ?>"
             data-info="<?= $hoverInfo ?>">
            <div class="reservation-content">
                <?= $reservation['회원명'] ?> 
                <?php if ($reservation['member_id']): ?>(ID: <?= $reservation['member_id'] ?>)<?php endif; ?>
                <br>
                <?= substr($reservation['시작시간'], -8, 5) ?> ~ <?= substr($reservation['종료시간'], -8, 5) ?>
                <?php if ($reservation['분류'] === '결제완료' && isset($reservation['credit_balance'])): ?>
                <br>잔액: <?= number_format($reservation['credit_balance']) ?>c
                <?php endif; ?>
            </div>
        </div>
        <?php endforeach; ?>
        
        <!-- 예약 정보 팝업 -->
        <div id="infoPopup" class="info-popup"></div>
    </div>
</div>

<style>
.timetable-container {
    position: relative;
    overflow-x: auto;
    margin: 20px 0;
    border: 1px solid #ddd;
    border-right: none;
    overflow-y: visible;
    max-height: 1500px; /* 최대 높이 설정 */
    padding-bottom: 20px;
    box-shadow: 0 1px 3px rgba(0,0,0,0.1);
    scrollbar-width: thin;
    scrollbar-color: #ddd transparent;
}

/* 크롬 스크롤바 스타일 */
.timetable-container::-webkit-scrollbar {
    width: 8px;
    height: 8px;
}

.timetable-container::-webkit-scrollbar-track {
    background: transparent;
}

.timetable-container::-webkit-scrollbar-thumb {
    background-color: #ddd;
    border-radius: 4px;
    border: 2px solid transparent;
}

.timetable-container::-webkit-scrollbar-thumb:hover {
    background-color: #ccc;
}

.timetable {
    table-layout: fixed; /* 고정 너비 테이블 */
    border-collapse: collapse;
    margin: 0;
    padding: 0;
    border-spacing: 0;
    empty-cells: show;
    border-right: none;
}

.time-header, .bay-header {
    position: sticky;
    top: 0;
    background: #f8f9fa;
    z-index: 10;
    padding: 0;
    margin: 0;
    text-align: center;
    font-weight: bold;
    border: 1px solid #ddd;
    box-sizing: border-box;
    height: 40px;
    line-height: 40px;
    overflow: hidden;
    color: #000; /* 제목을 검정색으로 변경 */
}

.bay-header {
    border-right: none;
}

.bay-header:last-child {
    border-right: 1px solid #ddd;
}

.hour-row {
    height: 60px;
    padding: 0;
    margin: 0;
}

.hour-row.divider {
    border-top: 2px solid #aaa;
}

.hour-cell {
    background: #f8f9fa;
    text-align: center;
    font-weight: bold;
    border: 1px solid #ddd;
    border-right: 1px solid #ddd;
    height: 60px;
    box-sizing: border-box;
    padding: 0;
    margin: 0;
    line-height: 60px;
    overflow: hidden;
    color: #000; /* 시간을 검정색으로 변경 */
}

.bay-cell {
    border: 1px solid #eee;
    border-right: none; /* 오른쪽 테두리 제거 */
    position: relative;
    height: 60px;
    box-sizing: border-box;
    padding: 0;
    margin: 0;
}

/* 마지막 열의 오른쪽 테두리만 표시 */
.bay-cell:last-child {
    border-right: 1px solid #eee;
}

/* 마지막 행의 아래쪽 테두리 */
.hour-row:last-child .bay-cell {
    border-bottom: 1px solid #eee;
}

.reservation {
    position: absolute;
    border: 1px solid;
    border-radius: 3px;
    padding: 2px 3px;
    font-size: 11px;
    background-color: white;
    overflow: hidden;
    cursor: pointer;
    z-index: 20;
    box-sizing: border-box;
    margin: 0;
    line-height: 1.2;
}

.reservation:hover {
    z-index: 1000;
    box-shadow: 0 0 8px rgba(0,0,0,0.3);
}

.reservation-content {
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    font-family: 'Noto Sans KR', sans-serif;
    line-height: 1.2;
    font-size: 11px;
}

.reservation-content br {
    display: block;
    content: "";
    margin-top: 2px;
}

/* 상태별 스타일 */
.status-completed {
    background-color: #e3f2fd;
    border-color: #90caf9;
}

.status-negative {
    background-color: #f44336;
    border-color: #d32f2f;
    color: white;
}

.status-missing-data {
    background-color: #f44336;
    border-color: #d32f2f;
    color: white;
    animation: blink 1s infinite alternate;
}

.status-junior {
    background-color: #f3e5f5;
    border-color: #ce93d8;
}

.status-wellbeing {
    background-color: #e8f5e9;
    border-color: #a5d6a7;
}

.status-pending {
    background-color: #fff3e0;
    border-color: #ffb74d;
}

.status-other {
    background-color: #f5f5f5;
    border-color: #bdbdbd;
}

@keyframes blink {
    from { background-color: #f44336; }
    to { background-color: #b71c1c; }
}

/* 날짜 선택 스타일 */
.date-selector {
    margin: 20px 0 10px 0;
    max-width: 300px;
    padding: 0 10px;
}

.date-form {
    display: flex;
    align-items: center;
    gap: 10px;
}

.form-control {
    padding: 8px;
    border: 1px solid #ddd;
    border-radius: 4px;
    font-size: 14px;
    width: 100%;
    font-family: 'Noto Sans KR', sans-serif;
}

.today-btn {
    padding: 8px 12px;
    background: #4285f4;
    color: white;
    border: none;
    border-radius: 4px;
    cursor: pointer;
    font-family: 'Noto Sans KR', sans-serif;
}

.today-btn:hover {
    background: #3367d6;
}

/* 조금 더 견고한 표 스타일링 */
.timetable tr, .timetable td, .timetable th {
    padding: 0;
    margin: 0;
    vertical-align: middle;
}

/* 6시간 간격으로 강조 표시 */
tr.hour-row:nth-child(6n) td {
    border-bottom: 2px solid #aaa;
}

/* 현재 시간 강조 표시 */
.current-hour {
    background-color: rgba(255, 252, 200, 0.3);
}

/* 예약 정보 팝업 스타일 */
.info-popup {
    position: absolute;
    display: none;
    background: white;
    border: 1px solid #ddd;
    border-radius: 4px;
    padding: 8px 12px;
    box-shadow: 0 2px 5px rgba(0,0,0,0.2);
    z-index: 1000;
    font-size: 12px;
    min-width: 200px;
    max-width: 300px;
    white-space: normal;
    font-family: 'Noto Sans KR', sans-serif;
}
</style>

<script>
document.addEventListener('DOMContentLoaded', function() {
    // 현재 시간을 URL에 추가하여 캐시 방지
    const currentURL = window.location.href;
    if (!currentURL.includes('_nocache=')) {
        const separator = currentURL.includes('?') ? '&' : '?';
        const nocacheURL = currentURL + separator + '_nocache=' + new Date().getTime();
        window.location.replace(nocacheURL);
    }
    
    // 테이블 및 예약 박스 정렬 보정
    setTimeout(() => {
        // 테이블 구조 확인
        const table = document.querySelector('.timetable');
        const container = document.querySelector('.timetable-container');
        const timeHeader = document.querySelector('.time-header');
        const timeWidth = timeHeader ? timeHeader.offsetWidth : 80;
        
        // 타석 열 너비 확인
        const bayHeaders = document.querySelectorAll('.bay-header');
        const bayWidth = bayHeaders.length > 0 ? bayHeaders[0].offsetWidth : 100;
        
        // 시간별 행 위치 맵 만들기
        const hourRows = document.querySelectorAll('.hour-row');
        const hourPositions = {};
        
        hourRows.forEach((row, index) => {
            const hour = index + 6; // 6시부터 시작
            const rect = row.getBoundingClientRect();
            const containerRect = container.getBoundingClientRect();
            // 컨테이너 내부 상대 위치 계산
            hourPositions[hour] = rect.top - containerRect.top + container.scrollTop;
        });
        
        // 예약 박스 위치 조정
        document.querySelectorAll('.reservation').forEach(box => {
            // 타석 번호 기준 가로 위치 조정
            const bayNum = parseInt(box.getAttribute('data-bay')) || 1;
            const leftPos = timeWidth + (bayNum - 1) * bayWidth + 1;
            box.style.left = leftPos + 'px';
            box.style.width = (bayWidth - 2) + 'px';
            
            // 시간 정보 추출
            const timeData = box.getAttribute('data-time') || '';
            const timeParts = timeData.split(':');
            
            if (timeParts.length >= 2) {
                const hour = parseInt(timeParts[0]);
                const minute = parseInt(timeParts[1]);
                
                // 시간별 위치에서 실제 위치 계산
                if (hourPositions[hour] !== undefined) {
                    const minuteOffset = (minute / 60) * 60; // 60px 기준
                    const topPos = hourPositions[hour] + minuteOffset;
                    box.style.top = topPos + 'px';
                }
            }
        });
    }, 100);
    
    // 오늘 날짜로 이동 버튼
    document.getElementById('goToToday').addEventListener('click', function() {
        const today = new Date().toISOString().split('T')[0];
        document.querySelector('input[name="date"]').value = today;
        document.querySelector('form.date-form').submit();
    });
    
    // 현재 시간대 강조 표시
    const now = new Date();
    const currentHour = now.getHours();
    if (currentHour >= 6) {
        const hourIndex = currentHour - 6 + 1; // 6시가 첫 번째 행이므로 +1
        const hourRow = document.querySelector(`.hour-row:nth-child(${hourIndex})`);
        if (hourRow) {
            hourRow.classList.add('current-hour');
        }
    }
    
    // 스크롤 위치 조정 (현재 시간대로 스크롤)
    setTimeout(() => {
        const today = new Date().toISOString().split('T')[0];
        const selectedDate = document.querySelector('input[name="date"]').value;
        
        if (today === selectedDate) {
            // 현재 시간으로 스크롤
            const currentHour = new Date().getHours();
            if (currentHour >= 6) {
                const hourPos = (currentHour - 6) * 60 + 40 - 100; // 헤더 높이 + 100px 여백
                document.querySelector('.timetable-container').scrollTop = Math.max(0, hourPos);
            }
        } else if (document.querySelector('.reservation')) {
            // 예약이 있으면 첫 번째 예약으로 스크롤
            const firstRes = document.querySelector('.reservation');
            const topPos = Math.max(0, parseFloat(firstRes.style.top) - 100);
            document.querySelector('.timetable-container').scrollTop = topPos;
        }
    }, 500);
    
    // 날짜 선택 시 자동 새로고침
    document.querySelector('input[type="date"]').addEventListener('change', function() {
        this.form.submit();
    });

    // 예약 박스 호버/클릭 이벤트
    document.querySelectorAll('.reservation').forEach(function(box) {
        // 호버 이벤트
        box.addEventListener('mouseenter', function(e) {
            const infoText = this.getAttribute('data-info');
            const popup = document.getElementById('infoPopup');
            popup.textContent = infoText;
            popup.style.display = 'block';
            
            // 마우스 위치에 따라 팝업 위치 조정
            const boxRect = this.getBoundingClientRect();
            popup.style.top = (boxRect.top + window.scrollY) + 'px';
            popup.style.left = (boxRect.right + window.scrollX + 10) + 'px';
        });
        
        box.addEventListener('mouseleave', function() {
            document.getElementById('infoPopup').style.display = 'none';
        });
        
        // 클릭 이벤트
        box.addEventListener('click', function(e) {
            const memberId = this.getAttribute('data-member-id');
            if (memberId) {
                // 팝업 설정
                const popupWidth = 1000;
                const popupHeight = 800;
                const left = (window.screen.width - popupWidth) / 2;
                const top = (window.screen.height - popupHeight) / 2;
                const popupOptions = `width=${popupWidth},height=${popupHeight},top=${top},left=${left},toolbar=no,menubar=no,location=no,status=no,scrollbars=yes,resizable=yes`;
                
                // 팝업 열기
                const popup = window.open(`member_form.php?id=${memberId}`, 'memberPopup', popupOptions);
                
                // 팝업이 차단되었는지 확인
                if (!popup || popup.closed || typeof popup.closed === 'undefined') {
                    alert('팝업이 차단되었습니다. 브라우저의 팝업 차단 설정을 확인해주세요.');
                }
            }
        });
    });
});
</script> 