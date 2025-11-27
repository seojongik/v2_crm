<?php
// 기간(Term) 탭 컨텐츠 - member_form.php에서 불러와서 사용

// 디버깅 메시지 추가
echo "<!-- Term Tab Debug: Start -->";
echo "<!-- isStandalone: " . (!isset($in_parent_page) || !$in_parent_page ? 'true' : 'false') . " -->";
echo "<!-- member_id: " . (isset($member_id) ? $member_id : 'not set') . " -->";
echo "<!-- db connection: " . (isset($db) && $db ? 'valid' : 'invalid') . " -->";

// $db 변수가 전달되지 않는 문제를 해결하기 위해 DB 연결 직접 수행
if (isset($db_copy) && $db_copy) {
    $db = $db_copy;
    echo "<!-- Using db_copy -->";
} else if (!isset($db) || !$db) {
    echo "<!-- Connecting to DB directly -->";
    require_once '../../config/db_connect.php';
}

// 직접 실행되는지 아니면 다른 파일에서 포함되는지 확인
$isStandalone = !isset($in_parent_page) || !$in_parent_page;

// member_id가 GET으로 전달됐는지 확인
if ($isStandalone) {
    // 독립 실행 모드
    if (!isset($_GET['id'])) {
        echo '<div class="error-message">회원 ID가 전달되지 않았습니다.</div>';
        exit;
    }
    $member_id = intval($_GET['id']);
} else {
    // 포함된 모드 - 부모 페이지에서 member_id를 받아야 함
    if (!isset($member_id)) {
        echo '<div class="error-message">회원 ID가 전달되지 않았습니다.</div>';
        exit;
    }
}

// 회원 정보 조회
$stmt = $db->prepare("SELECT member_id, member_name FROM members WHERE member_id = ?");
$stmt->bind_param('i', $member_id);
$stmt->execute();
$result = $stmt->get_result();

if ($result->num_rows === 0) {
    echo '<div class="error-message">회원 정보를 찾을 수 없습니다.</div>';
    echo "<!-- Member not found for ID: $member_id -->";
    exit;
}

$member = $result->fetch_assoc();
echo "<!-- Member found: " . htmlspecialchars($member['member_name']) . " -->";

// 현재 날짜
$current_date = date('Y-m-d');
?>

<!-- FontAwesome과 Noto Sans KR 폰트 추가 -->
<script>
// FontAwesome 아이콘 라이브러리 추가 (CDN)
if (!document.getElementById('fontawesome-css')) {
    const link = document.createElement('link');
    link.id = 'fontawesome-css';
    link.rel = 'stylesheet';
    link.href = 'https://cdnjs.cloudflare.com/ajax/libs/font-awesome/4.7.0/css/font-awesome.min.css';
    document.head.appendChild(link);
}

// Google Noto Sans KR 폰트 추가
if (!document.getElementById('noto-sans-kr')) {
    const link = document.createElement('link');
    link.id = 'noto-sans-kr';
    link.rel = 'stylesheet';
    link.href = 'https://fonts.googleapis.com/css2?family=Noto+Sans+KR:wght@400;500;700&display=swap';
    document.head.appendChild(link);
}
</script>

<div class="term-tab-content">
    <div class="header-flex">
        <div class="title-and-info">
            <h3 class="inline-title"></h3>
            <span class="member-info"><span class="member-name"><?php echo htmlspecialchars($member['member_name']); ?></span> 회원님의 기간권 정보입니다.</span>
        </div>
    </div>
    <table class="data-table">
        <thead>
            <tr>
                <th>기간권 유형</th>
                <th>계약기간(월)</th>
                <th>시작일</th>
                <th>종료일</th>
                <th>만료일</th>
                <th>총 홀드일수</th>
                <th>관리</th>
            </tr>
        </thead>
        <tbody>
            <?php
            try {
                // 기간권 정보 조회 쿼리
                $term_query = "
                    SELECT 
                        t.term_id,
                        t.term_type,
                        t.term_period_month,
                        t.term_startdate,
                        t.term_enddate,
                        t.term_expirydate,
                        COALESCE((
                            SELECT SUM(th.term_add_dates)
                            FROM Term_hold th
                            WHERE th.term_id = t.term_id
                        ), 0) as total_hold_days
                    FROM Term_member t
                    WHERE member_id = ?
                    ORDER BY t.term_startdate DESC
                ";
                
                $stmt = $db->prepare($term_query);
                $stmt->bind_param('i', $member_id);
                $stmt->execute();
                $terms = $stmt->get_result();

                if ($terms->num_rows > 0) {
                    while ($term = $terms->fetch_assoc()) : ?>
                        <tr data-term-id="<?php echo $term['term_id']; ?>">
                            <td class="text-center"><?php echo htmlspecialchars($term['term_type']); ?></td>
                            <td class="text-right"><?php echo $term['term_period_month']; ?>개월</td>
                            <td class="text-center"><?php echo date('Y-m-d', strtotime($term['term_startdate'])); ?></td>
                            <td class="text-center"><?php echo date('Y-m-d', strtotime($term['term_enddate'])); ?></td>
                            <td class="text-center"><?php echo date('Y-m-d', strtotime($term['term_expirydate'])); ?></td>
                            <td class="text-right"><?php echo $term['total_hold_days']; ?>일</td>
                            <td class="text-center">
                                <?php 
                                // 팝업 URL 구성
                                $hold_url = ($isStandalone) 
                                    ? "hold_register.php?term_id={$term['term_id']}&member_id={$member_id}&member_name=" . urlencode($member['member_name'])
                                    : "member_form_tabs_and_process/hold_register.php?term_id={$term['term_id']}&member_id={$member_id}&member_name=" . urlencode($member['member_name']);
                                ?>
                                <a href="javascript:void(0);" 
                                   onclick="window.open('<?php echo $hold_url; ?>', 'holdWindow', 'width=600,height=580,resizable=yes,scrollbars=yes'); return false;"
                                   class="btn btn-small hold-btn" 
                                   data-term-id="<?php echo $term['term_id']; ?>">
                                    <i class="fa fa-calendar-plus-o"></i> 홀드등록
                                </a>
                            </td>
                        </tr>
                    <?php endwhile;
                } else { ?>
                    <tr>
                        <td colspan="7" class="text-center">등록된 기간권이 없습니다.</td>
                    </tr>
                <?php } 
            } catch (mysqli_sql_exception $e) {
                // 테이블이 없는 경우 또는 다른 DB 오류
                echo "<tr><td colspan='7' class='error-message text-center'>";
                echo "기간권 정보를 불러올 수 없습니다. 필요한 테이블이 없거나 데이터베이스 오류가 발생했습니다.";
                echo "</td></tr>";
            }
            ?>
        </tbody>
    </table>
</div>

<style>
.term-tab-content {
    padding: 20px;
    font-family: 'Noto Sans KR', sans-serif;
}

/* 헤더 스타일 */
.header-flex {
    display: flex;
    justify-content: space-between;
    align-items: center;
    background-color: #f8f9fa;
    padding: 12px 20px;
    border-radius: 8px;
    box-shadow: 0 1px 3px rgba(0,0,0,0.1);
    margin-bottom: 20px;
}

.title-and-info {
    display: flex;
    align-items: center;
    gap: 15px;
}

.inline-title {
    margin: 0;
    font-size: 18px;
    color: #2c3e50;
    white-space: nowrap;
}

.member-info {
    font-size: 14px;
    color: #555;
}

.member-name {
    font-weight: 600;
    color: #3498db;
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
    text-align: center; /* 기본적으로 모든 셀 가운데 정렬 */
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

.btn-small {
    padding: 5px 10px;
    font-size: 13px;
    background-color: #007bff;
    color: white;
    border: none;
    border-radius: 3px;
    cursor: pointer;
    text-align: center;
    font-weight: bold;
}

.btn-small:hover {
    background-color: #0056b3;
}

.btn-small i {
    margin-right: 4px;
}

.error-message {
    color: #dc3545;
}

/* 반응형 스타일 */
@media (max-width: 768px) {
    .header-flex {
        flex-direction: column;
        align-items: flex-start;
        gap: 10px;
    }
    
    .title-and-info {
        flex-direction: column;
        align-items: flex-start;
        gap: 5px;
    }
}
</style>

<script>
// PHP 변수를 JavaScript 변수로 전달
var isStandalone = <?php echo json_encode($isStandalone); ?>;
var memberId = <?php echo json_encode($member_id); ?>;
var memberName = "<?php echo htmlspecialchars($member['member_name']); ?>";

// 페이지 새로고침 함수 - 전역 스코프로 노출
function refreshTermTab() {
    console.log("refreshTermTab 함수 호출됨");
    location.reload();
}

// 전역 window 객체에 함수 직접 할당 (리프레시 함수에 대한 다양한 접근 경로 제공)
window.refreshTermTab = refreshTermTab;

// DOM 상태를 디버깅하는 함수
function debugButtons() {
    console.log("====== DEBUG TERM TAB BUTTONS ======");
    console.log("isStandalone:", isStandalone);
    console.log("memberId:", memberId);
    
    // 모든 홀드 버튼 검사
    const holdButtons = document.querySelectorAll(".hold-btn");
    console.log(`Found ${holdButtons.length} hold buttons:`);
    
    holdButtons.forEach((btn, index) => {
        const termId = btn.getAttribute("data-term-id");
        console.log(`Button ${index+1}:`, {
            element: btn,
            termId: termId,
            hasClickListeners: btn.onclick !== null || btn._hasEventListeners
        });
    });
}

// 직접 버튼 클릭 처리 함수 (전역으로 노출)
function directOpenHold(termId) {
    console.log("Direct open hold called for term ID:", termId);
    openHoldModal(termId);
    return false; // 이벤트 전파 중지
}

// 문서 로드 완료 후 이벤트 바인딩 (바닐라 자바스크립트 사용)
document.addEventListener('DOMContentLoaded', function() {
    console.log("term_tab.php - DOM loaded, binding events");
    debugButtons();
    bindHoldButtonEvents();
    
    // 5초 후에 다시 디버깅 실행 (지연 로딩 문제 확인)
    setTimeout(debugButtons, 5000);
});

// 홀드 버튼에 이벤트 바인딩
function bindHoldButtonEvents() {
    console.log("Binding hold button events in term_tab.php");
    
    // 모든 기존 이벤트 리스너를 제거하고 새로 바인딩
    document.querySelectorAll(".hold-btn").forEach(function(button) {
        console.log("Processing button:", button, "data-term-id:", button.getAttribute("data-term-id"));
        
        // 기존 이벤트 리스너 제거 (클린업)
        button.removeEventListener("click", holdButtonClickHandler);
        
        // 새 이벤트 리스너 추가 (이벤트 캡처링 사용)
        button.addEventListener("click", holdButtonClickHandler, true);
        
        // 디버깅 목적으로 속성 추가
        button._hasEventListeners = true;
    });
}

// 홀드 버튼 클릭 핸들러
function holdButtonClickHandler(event) {
    // 이벤트 발생 확인
    console.log("Hold button clicked!", event);
    
    // 이벤트 소스 확인
    const button = event.currentTarget;
    console.log("Button element:", button);
    
    var termId = button.getAttribute("data-term-id");
    console.log("Hold button clicked for term ID:", termId);
    
    // 이벤트 전파 중지 (다른 핸들러와의 충돌 방지)
    event.preventDefault();
    event.stopPropagation();
    
    // 홀드 모달 열기
    openHoldModal(termId);
}

// 홀드 모달 열기
function openHoldModal(termId) {
    // 홀드 등록 새창 팝업 열기
    // 실행 환경(직접 실행 vs include)에 따라 경로 구분
    let holdWindowUrl;
    
    console.log("Opening hold modal for term ID:", termId, "isStandalone:", isStandalone);
    
    if (isStandalone) {
        // term_tab.php가 직접 실행되는 경우
        holdWindowUrl = `hold_register.php?term_id=${termId}&member_id=${memberId}&member_name=${encodeURIComponent(memberName)}`;
    } else {
        // member_form.php에서 include되는 경우
        holdWindowUrl = `member_form_tabs_and_process/hold_register.php?term_id=${termId}&member_id=${memberId}&member_name=${encodeURIComponent(memberName)}`;
    }
    
    console.log("홀드 등록 URL:", holdWindowUrl);
    const holdWindow = window.open(holdWindowUrl, 'holdWindow', 'width=600,height=580,resizable=yes,scrollbars=yes');
    
    if (holdWindow) {
        holdWindow.focus();
    } else {
        alert('팝업 창이 차단되었습니다. 팝업 차단을 해제해주세요.');
    }
}

// 페이지 새로고침 함수
function refreshTermTab() {
    location.reload();
}

// 부모 창이 접근할 수 있는 전역 함수 노출
window.termTabFunctions = {
    refreshTermTab: refreshTermTab,
    openHoldModal: openHoldModal,
    bindHoldButtonEvents: bindHoldButtonEvents,
    debugButtons: debugButtons,
    directOpenHold: directOpenHold
};

// 전역 객체 접근성 확인
console.log("전역 객체 확인:", {
    termTabFunctions: !!window.termTabFunctions,
    refreshTermTab: typeof window.refreshTermTab
});

// 페이지 로드 후 상태 확인을 위한 MutationObserver 설정
setTimeout(function() {
    console.log("Setting up MutationObserver for term tab");
    const observer = new MutationObserver(function(mutations) {
        console.log("DOM mutation detected in term tab", mutations);
        debugButtons();
    });
    
    // 탭 컨텐츠 관찰 시작
    const termTabContent = document.querySelector('.term-tab-content');
    if (termTabContent) {
        observer.observe(termTabContent, { childList: true, subtree: true });
        console.log("Observing term tab content for changes");
    }
}, 1000);
</script>

<!-- 전역 함수 재확인 - 스크립트가 모두 로드된 후 -->
<script>
// 모든 스크립트가 실행된 후 전역 함수 접근성 재확인
document.addEventListener('DOMContentLoaded', function() {
    console.log("DOM 로드 완료 후 전역 함수 확인:", {
        termTabFunctions: !!window.termTabFunctions,
        refreshTermTab: typeof window.refreshTermTab
    });
});
</script>

<!-- Term Tab Debug: End --> 