<?php
// PHP 타임존 설정
date_default_timezone_set('Asia/Seoul');

require_once '../config/db_connect.php';

$member = null;
if (isset($_GET['id'])) {
    // 디버깅용 출력
    echo "<!-- Member ID: " . $_GET['id'] . " -->";
    
    $stmt = $db->prepare('
        SELECT 
            m.*,
            COALESCE(m.member_memo, "") as member_memo
        FROM members m 
        WHERE m.member_id = ?
    ');
    $stmt->bind_param('i', $_GET['id']);
    $stmt->execute();
    $result = $stmt->get_result();
    $member = $result->fetch_assoc();
    
    // member_memo가 NULL인 경우 빈 문자열로 설정
    if ($member && is_null($member['member_memo'])) {
        $member['member_memo'] = '';
    }
    
    // 디버깅용 출력
    echo "<!-- Member Data: ";
    var_dump($member);
    echo " -->";
}

// bills 테이블의 날짜 범위 조회
$bills_date_range_query = "
    SELECT 
        MIN(bill_date) as min_date,
        MAX(bill_date) as max_date
    FROM bills 
    WHERE member_id = ?
";
$stmt = $db->prepare($bills_date_range_query);
$stmt->bind_param('i', $_GET['id']);
$stmt->execute();
$bills_date_range = $stmt->get_result()->fetch_assoc();

// JavaScript로 전달하기 위해 변수 설정
echo "<script>
    var billsMinDate = '" . ($bills_date_range['min_date'] ?? date('Y-m-d')) . "';
    var billsMaxDate = '" . ($bills_date_range['max_date'] ?? date('Y-m-d')) . "';
</script>";

// bills 테이블의 날짜 범위 조회 - 회원이 있을 때만 실행
$date_range = ['min_date' => null, 'max_date' => null];
if ($member) {
    $stmt = $db->prepare('
        SELECT 
            MIN(bill_date) as min_date,
            MAX(bill_date) as max_date
        FROM bills 
        WHERE member_id = ?
    ');
    $stmt->bind_param('i', $member['member_id']);
    $stmt->execute();
    $date_range = $stmt->get_result()->fetch_assoc();
    
    // 날짜가 null인 경우 기본값 설정
    if (!$date_range['min_date']) {
        $date_range['min_date'] = date('Y-m-d');
    }
    if (!$date_range['max_date']) {
        $date_range['max_date'] = date('Y-m-d');
    }
}

// 계약 정보 조회 부분
$contracts = [];
if ($member) {
    $contract_query = "
        SELECT 
            ch.contract_history_id,
            ch.contract_date,
            ch.actual_price,
            ch.actual_credit,
            ch.payment_type,
            c.contract_type,
            c.contract_name,
            c.contract_LS,
            ch.contract_history_status
        FROM contract_history ch
        JOIN contracts c ON ch.contract_id = c.contract_id
        WHERE ch.member_id = ?
        ORDER BY ch.contract_date DESC
    ";
    $stmt = $db->prepare($contract_query);
    $stmt->bind_param('i', $member['member_id']);
    $stmt->execute();
    $contracts = $stmt->get_result();
}
?>
<!DOCTYPE html>
<html lang="ko">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title><?php echo $member ? '회원 정보 <span style="font-size:14px; color:#888;">(회원번호 : ' . $member['member_id'] . ')</span>' : '신규 회원 등록'; ?></title>
    <!-- 외부 스타일시트 및 라이브러리 -->
    <link rel="stylesheet" href="../assets/css/style.css">
    <script src="https://code.jquery.com/jquery-3.6.0.min.js"></script>
    <script src="https://code.jquery.com/ui/1.12.1/jquery-ui.min.js"></script>
    <link rel="stylesheet" href="https://code.jquery.com/ui/1.12.1/themes/base/jquery-ui.css">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/4.7.0/css/font-awesome.min.css">
    <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Noto+Sans+KR:wght@400;500;700&display=swap">
    
    <!-- 폼 유효성 검사 함수 -->
    <script>
    function validateForm() {
        // 필수 입력 필드 확인
        const memberName = document.getElementById('member_name');
        const memberPhone = document.getElementById('member_phone');
        
        if (!memberName || !memberName.value.trim()) {
            alert('이름을 입력해주세요.');
            if (memberName) memberName.focus();
            return false;
        }
        
        if (!memberPhone || !memberPhone.value.trim()) {
            alert('전화번호를 입력해주세요.');
            if (memberPhone) memberPhone.focus();
            return false;
        }
        
        // 전화번호 형식 검사 (선택적)
        const phonePattern = /^[0-9]{3}-[0-9]{3,4}-[0-9]{4}$/;
        if (memberPhone && memberPhone.value.trim() && !phonePattern.test(memberPhone.value.trim())) {
            alert('전화번호 형식이 올바르지 않습니다. (예: 010-1234-5678)');
            memberPhone.focus();
            return false;
        }
        
        return true;
    }
    
    function submitMemberForm() {
        const memberForm = document.getElementById('memberForm');
        
        if (!memberForm) {
            alert('폼을 찾을 수 없습니다. 페이지를 새로고침해보세요.');
            return false;
        }
        
        if (validateForm()) {
            // 폼을 AJAX로 제출하여 페이지 이동 없이 처리
            const formData = new FormData(memberForm);
            
            // 버튼 비활성화 및 로딩 표시
            const submitBtn = document.getElementById('saveMemberBtn');
            submitBtn.disabled = true;
            submitBtn.innerHTML = '<i class="fa fa-spinner fa-spin"></i> 저장 중...';
            
            fetch('member_process.php', {
                method: 'POST',
                body: formData
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    // 성공 메시지 표시
                    alert('회원정보가 성공적으로 저장되었습니다.');
                    
                    // 부모 창 새로고침
                    if (window.opener && !window.opener.closed) {
                        window.opener.location.reload();
                    }
                    
                    // 창 닫기
                    window.close();
                } else {
                    // 오류 메시지 표시
                    alert('회원정보 저장에 실패했습니다: ' + (data.message || '알 수 없는 오류'));
                    
                    // 버튼 상태 복원
                    submitBtn.disabled = false;
                    submitBtn.innerHTML = '회원정보 저장';
                }
            })
            .catch(error => {
                console.error('처리 중 오류 발생:', error);
                alert('처리 중 오류가 발생했습니다.');
                
                // 버튼 상태 복원
                submitBtn.disabled = false;
                submitBtn.innerHTML = '회원정보 저장';
            });
            
            return false; // 기본 폼 제출 방지
        }
        
        return false; // 기본 이벤트 중지
    }
    </script>
    
    <!-- 탭 전환 함수 -->
    <script>
    // 탭 전환 함수
    function switchTab(tabId) {
        console.log(`[member_form.php] 탭 전환 시작 - 탭 ID: ${tabId}`);
        
        // 모든 탭 내용 숨기기
        document.querySelectorAll('.tab-content').forEach(function(content) {
            content.style.display = 'none';
        });
        
        // 모든 탭 버튼 비활성화
        document.querySelectorAll('.tab-button').forEach(function(button) {
            button.classList.remove('active');
        });
        
        // 선택한 탭 내용 표시
        const selectedTab = document.getElementById(tabId);
        if (selectedTab) {
            selectedTab.style.display = 'block';
            console.log(`[member_form.php] 탭 표시됨: ${tabId}`);
        } else {
            console.error(`[member_form.php] 탭을 찾을 수 없음: ${tabId}`);
        }
        
        // 선택한 탭 버튼 활성화
        const button = document.querySelector(`.tab-button[data-tab="${tabId}"]`);
        if (button) {
            button.classList.add('active');
        }
        
        // 기간권 탭이 활성화되면 이벤트 초기화
        if (tabId === 'term') {
            console.log("[member_form.php] 기간권 탭 활성화됨");
            
            // termTabFunctions 접근 가능한지 확인
            if (typeof window.termTabFunctions !== 'undefined') {
                console.log("[member_form.php] termTabFunctions 존재함:", window.termTabFunctions);
                
                // 이벤트 초기화 시도
                setTimeout(function() {
                    console.log("[member_form.php] 기간권 탭 이벤트 초기화 시도");
                    
                    // 디버깅 함수 호출 (사용 가능한 경우)
                    if (typeof window.termTabFunctions.debugButtons === 'function') {
                        console.log("[member_form.php] 디버깅 함수 호출");
                        window.termTabFunctions.debugButtons();
                    }
                    
                    // 이벤트 바인딩 함수 호출
                    if (typeof window.termTabFunctions.bindHoldButtonEvents === 'function') {
                        console.log("[member_form.php] 이벤트 바인딩 함수 호출");
                        window.termTabFunctions.bindHoldButtonEvents();
                    } else {
                        console.error("[member_form.php] bindHoldButtonEvents 함수를 찾을 수 없음");
                        
                        // 대체 방법: 모든 홀드 버튼에 직접 onclick 이벤트 설정
                        console.log("[member_form.php] 대체 방법으로 onclick 속성 설정");
                        document.querySelectorAll('.hold-btn').forEach(function(btn) {
                            const termId = btn.getAttribute('data-term-id');
                            if (termId) {
                                console.log(`[member_form.php] 버튼에 onclick 설정: termId=${termId}`);
                                btn.setAttribute('onclick', `window.termTabFunctions.openHoldModal(${termId}); return false;`);
                            }
                        });
                    }
                }, 500);
            } else {
                console.error("[member_form.php] termTabFunctions를 찾을 수 없음");
            }
        }
        
        // URL 해시 업데이트
        window.location.hash = tabId;
        
        // localStorage에 현재 탭 저장
        const memberId = <?php echo isset($member['member_id']) ? $member['member_id'] : 0; ?>;
        localStorage.setItem(`selectedTab_${memberId}`, tabId);
        
        console.log(`[member_form.php] 탭 전환 완료: ${tabId}`);
    }
    
    // 초기 탭 설정 - 페이지 로딩 시
    document.addEventListener('DOMContentLoaded', function() {
        console.log("[member_form.php] DOM 로드 완료");
        
        // 탭 버튼에 이벤트 리스너 추가
        document.querySelectorAll('.tab-button').forEach(function(button) {
            button.addEventListener('click', function() {
                const tabId = this.getAttribute('data-tab');
                switchTab(tabId);
            });
        });
        
        // 초기 탭 선택 (URL 해시 또는 기본값)
        const hash = window.location.hash ? window.location.hash.substring(1) : null;
        const memberId = <?php echo isset($member['member_id']) ? $member['member_id'] : 0; ?>;
        const savedTab = localStorage.getItem(`selectedTab_${memberId}`);
        
        // 우선순위: 1. URL 해시, 2. 저장된 탭, 3. 기본 'term' 탭으로 변경
        const initialTab = hash || savedTab || 'term';
        
        console.log(`[member_form.php] 초기 탭 선택: ${initialTab} (hash: ${hash}, savedTab: ${savedTab})`);
        
        // 약간의 지연 후 탭 전환
        setTimeout(function() {
            switchTab(initialTab);
            
            // 디버깅을 위한 콘솔 로그 추가
            console.log("[member_form.php] 초기 탭 전환 완료");
            console.log("[member_form.php] 탭 존재 여부:", document.getElementById(initialTab) ? true : false);
            
            // 10초 후 term 탭에 MutationObserver 설정 (지연 로딩 문제 확인)
            setTimeout(function() {
                if (initialTab === 'term') {
                    console.log("[member_form.php] 10초 후 term 탭 상태 확인");
                    // termTabFunctions 접근 가능한지 다시 확인
                    if (window.termTabFunctions && window.termTabFunctions.debugButtons) {
                        window.termTabFunctions.debugButtons();
                    }
                    
                    // 홀드 버튼 찾기
                    const holdButtons = document.querySelectorAll('.hold-btn');
                    console.log(`[member_form.php] 홀드 버튼 개수: ${holdButtons.length}`);
                }
            }, 10000);
        }, 300);
    });
    </script>
    
    <!-- 페이지 특화 스타일 -->
    <style>
        /* 전체 페이지 스타일 */
        body {
            background-color: #f0f7ff; /* 밝은 하늘색 배경으로 변경 */
        }
        
        /* 전체 컨테이너 스타일 */
        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
        }
        
        /* 페이지 헤더 스타일 */
        .page-actions {
            background: linear-gradient(to right, #ffffff, #f0f7ff); /* 그라데이션 배경 추가 */
            padding: 15px;
            border-radius: 8px 8px 0 0;
            border-bottom: 1px solid #d1e6ff; /* 더 밝은 파란색 경계선 */
        }
        
        /* 폼 스타일 */
        #memberForm {
            background-color: #ffffff;
            border-radius: 12px;
            box-shadow: 0 8px 20px rgba(0, 123, 255, 0.1);
            padding: 20px;
            margin-bottom: 20px;
            border: 1px solid #e1edff;
        }
        
        /* 폼 레이아웃 */
        .form-header {
            background: linear-gradient(to right, #f9f9f9, #f0f7ff);
            border-radius: 8px;
            padding: 15px;
            margin-bottom: 20px;
            border: 1px solid #d1e6ff;
            overflow-x: auto;
            box-shadow: 0 2px 6px rgba(0, 123, 255, 0.05);
        }
        
        .form-row {
            display: flex;
            gap: 8px;
            margin-bottom: 0;
            flex-wrap: nowrap;
            padding: 2px;
        }
        
        .form-group {
            position: relative;
            margin: 0;
            padding: 0 1px;
            border-spacing: 0;
            display: flex;
            align-items: center;
            flex: none;
        }
        
        /* 단일 행 최적화 */
        .single-row {
            display: flex;
            align-items: center;
            flex-wrap: nowrap;
            white-space: nowrap;
            min-width: 100%;
        }
        
        /* 레이블 스타일 */
        .form-group label {
            display: inline-block;
            margin: 0 4px 0 0;
            font-size: 12px;
            white-space: nowrap;
            flex: none;
            width: auto;
        }
        
        /* 요소별 너비 설정 - 한 줄 레이아웃 */
        .name-group .form-input { width: 85px; }
        .phone-group .form-input { width: 120px; }
        .gender-group .form-input { width: 70px; }
        .birth-group .form-input { width: 120px; }
        .nickname-group .form-input { width: 80px; }
        .keyword-group .form-input { width: 100px; }
        .address-group .form-input { width: 155px; }
        
        /* 생년월일 날짜 선택 박스 크기 직접 설정 */
        #member_birthday {
            width: 100px;
            height: 36px;
        }
        
        /* 요소별 배경색 */
        .name-group .form-input { background-color: #e8f4ff; } /* 이름 */
        .phone-group .form-input { background-color: #e8f4ff; } /* 전화번호 */
        .gender-group .form-input { background-color: #e8f4ff; } /* 성별 */
        .birth-group .form-input { background-color: #e8f4ff; } /* 생년월일 */
        .nickname-group .form-input { background-color: #fff6e5; } /* 닉네임 */
        .keyword-group .form-input { background-color: #fff6e5; } /* 채널키워드 */
        .address-group .form-input { background-color: #f0f8ff; } /* 주소 */
        
        /* 탭 스타일 덮어쓰기 */
        .tab-buttons {
            background: linear-gradient(to right, #fafcff, #f0f7ff);
            border-radius: 8px 8px 0 0;
            padding: 5px 5px 0;
        }
        
        .tab-button {
            background: rgba(255, 255, 255, 0.7);
            border: 1px solid #e1edff;
            border-bottom: none;
            color: #5a7ba6;
            position: relative; /* 자식 요소의 절대 위치 기준점 */
            overflow: visible; /* 넘치는 부분 표시되도록 */
        }
        
        .tab-button:hover {
            color: #4a89dc;
            background-color: rgba(255, 255, 255, 0.9);
            transform: translateY(-3px);
        }
        
        .tab-button.active {
            background: linear-gradient(to bottom, #ffffff, #f8fcff);
            color: #3498db;
        }
        
        .tab-button.active:after {
            content: '';
            position: absolute;
            bottom: -1px; /* 위치 미세 조정 */
            left: 0;
            width: 100%;
            height: 3px;
            background-image: linear-gradient(to right, #36d1dc, #5b86e5, #4facd6, #3fabe0, #36d1dc);
            animation: gradientFlow 3s linear infinite;
            background-size: 200% auto;
            border-radius: 3px;
            z-index: 2; /* 다른 요소보다 앞에 표시 */
        }
        
        @keyframes gradientFlow {
            0% { background-position: 0% center; }
            100% { background-position: 200% center; }
        }
        
        /* 반응형 스타일 */
        @media (max-width: 1200px) {
            .form-header {
                overflow-x: auto;
            }
            
            .single-row {
                min-width: 1000px; /* 최소 너비 설정으로 스크롤 보장 */
                flex-wrap: nowrap !important;
            }
            
            .form-group {
                margin-bottom: 0 !important;
            }
        }
        
        @media (max-width: 768px) {
            .page-actions {
                flex-direction: column;
                align-items: flex-start;
                gap: 10px;
            }
            
            .action-buttons {
                width: 100%;
                justify-content: space-between;
            }
            
            .single-row {
                min-width: 950px; /* 작은 화면에서 최소 너비 조정 */
            }
            
            .form-group label {
                font-size: 11px;
            }
        }
        
        /* 모바일 최적화 - 수평 스크롤 강제 */
        @media (max-width: 576px) {
            .form-header {
                padding: 8px;
                overflow-x: auto;
                -webkit-overflow-scrolling: touch;
            }
            
            .single-row {
                min-width: 900px; /* 모바일에서 스크롤 강제 */
                flex-wrap: nowrap !important;
                flex-direction: row !important;
            }
            
            .form-group {
                flex-direction: row !important;
                width: auto !important;
                margin-bottom: 0 !important;
            }
        }
        
        /* 셀렉트 화살표 커스터마이징 */
        select.form-input {
            padding-right: 24px;
            appearance: none;
            background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='16' height='16' viewBox='0 0 24 24' fill='none' stroke='%23555' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpolyline points='6 9 12 15 18 9'%3E%3C/polyline%3E%3C/svg%3E");
            background-repeat: no-repeat;
            background-position: right 8px center;
            background-size: 12px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="page-actions">
            <h1 class="page-title"><?php echo $member ? '회원 정보 <span style="font-size:14px; color:#888;">(회원번호 : ' . $member['member_id'] . ')</span>' : '신규 회원 등록'; ?></h1>
            <div class="action-buttons">
                <button type="submit" id="saveMemberBtn" class="btn-save" onclick="return submitMemberForm();">회원정보 저장</button>
                <a href="javascript:void(0);" onclick="window.close();" class="btn">닫기</a>
            </div>
        </div>

        <form id="memberForm" action="member_process.php" method="POST" onsubmit="return submitMemberForm();">
            <?php if ($member) : ?>
                <input type="hidden" name="id" value="<?php echo $member['member_id']; ?>">
            <?php endif; ?>
            
            <div class="form-header">
                <div class="form-row single-row">
                    <div class="form-group name-group">
                        <label for="member_name" class="required">이름</label>
                        <input type="text" id="member_name" name="member_name" required maxlength="10" class="form-input"
                            value="<?php echo $member ? htmlspecialchars($member['member_name']) : ''; ?>">
                    </div>

                    <div class="form-group phone-group">
                        <label for="member_phone" class="required">전화번호</label>
                        <input type="tel" id="member_phone" name="member_phone" required maxlength="13" class="form-input"
                            placeholder="010-0000-0000"
                            value="<?php echo $member ? htmlspecialchars($member['member_phone']) : ''; ?>">
                    </div>

                    <div class="form-group gender-group">
                        <label for="member_gender">성별</label>
                        <select id="member_gender" name="member_gender" class="form-input">
                            <option value="">선택</option>
                            <option value="남성" <?php echo ($member && $member['member_gender'] == '남성') ? 'selected' : ''; ?>>남성</option>
                            <option value="여성" <?php echo ($member && $member['member_gender'] == '여성') ? 'selected' : ''; ?>>여성</option>
                        </select>
                    </div>

                    <div class="form-group birth-group">
                        <label for="member_birthday">생년월일</label>
                        <input type="date" id="member_birthday" name="member_birthday" class="form-input"
                            value="<?php echo $member ? $member['member_birthday'] : ''; ?>">
                    </div>

                    <div class="form-group nickname-group">
                        <label for="member_nickname">닉네임</label>
                        <input type="text" id="member_nickname" name="member_nickname" class="form-input"
                            value="<?php echo $member ? htmlspecialchars($member['member_nickname']) : ''; ?>">
                    </div>

                    <div class="form-group keyword-group">
                        <label for="member_chn_keyword">채널키워드</label>
                        <input type="text" id="member_chn_keyword" name="member_chn_keyword" class="form-input"
                            value="<?php echo $member ? htmlspecialchars($member['member_chn_keyword']) : ''; ?>">
                    </div>
                    
                    <div class="form-group address-group">
                        <label for="member_address">주소</label>
                        <input type="text" id="member_address" name="member_address" class="form-input"
                            value="<?php echo $member ? htmlspecialchars($member['member_address']) : ''; ?>">
                    </div>
                </div>
            </div>

            <?php if ($member) : ?>
                <div class="tabs">
                    <div class="tab-buttons">
                        <button type="button" class="tab-button" data-tab="memo">메모</button>
                        <button type="button" class="tab-button" data-tab="contracts">회원권</button>
                        <button type="button" class="tab-button" data-tab="credit">크레딧</button>
                        <button type="button" class="tab-button" data-tab="lesson">레슨권</button>
                        <button type="button" class="tab-button" data-tab="teebox">타석이용</button>
                        <button type="button" class="tab-button" data-tab="term">기간권</button>
                        <button type="button" class="tab-button" data-tab="juniors">주니어</button>
                    </div>

                    <!-- 탭 컨텐츠 컨테이너 -->
                    <div id="memo" class="tab-content">
                        <!-- 메모 탭 컨텐츠 -->
                        <?php
                        // 메모 탭 컨텐츠 로드
                        include 'member_form_tabs_and_process/memo_tab.php';
                        ?>
                    </div>
                    
                    <div id="contracts" class="tab-content">
                        <!-- 회원권 탭 컨텐츠 -->
                        <?php
                        // 부모 페이지에서 포함됨을 나타내는 변수 설정
                        $in_parent_page = true;
                        
                        // member_id 명시적 전달
                        $member_id = $member['member_id'];
                        $db_copy = $db;
                        
                        // 회원권 탭 컨텐츠 로드
                        include 'member_form_tabs_and_process/contracts_tab.php';
                        ?>
                    </div>
                    
                    <div id="credit" class="tab-content">
                        <!-- 크레딧 탭 컨텐츠 -->
                        <?php
                        // 부모 페이지에서 포함됨을 나타내는 변수 설정
                        $in_parent_page = true;
                        
                        // member_id 명시적 전달
                        $member_id = $member['member_id'];
                        $db_copy = $db;
                        
                        // member_id 디버깅
                        echo "<!-- 부모 페이지의 member_id = " . (isset($member['member_id']) ? $member['member_id'] : 'undefined') . " -->";
                        
                        // 크레딧 탭 컨텐츠 로드
                        include 'member_form_tabs_and_process/credit_tab.php';
                        ?>
                    </div>
                    
                    <div id="lesson" class="tab-content">
                        <!-- 레슨권 탭 컨텐츠 -->
                        <?php
                        // 부모 페이지에서 포함됨을 나타내는 변수 설정
                        $in_parent_page = true;
                        
                        // member_id 명시적 전달
                        $member_id = $member['member_id'];
                        
                        // 레슨 탭 컨텐츠 로드
                        include 'member_form_tabs_and_process/lesson_tab.php';
                        ?>
                    </div>
                    
                    <div id="teebox" class="tab-content">
                        <!-- 타석이용 탭 컨텐츠 -->
                        <?php
                        // 부모 페이지에서 포함됨을 나타내는 변수 설정
                        $in_parent_page = true;
                        
                        // member_id 명시적 전달
                        $member_id = $member['member_id'];
                        
                        // 타석이용 탭 컨텐츠 로드
                        include 'member_form_tabs_and_process/teebox_tab.php';
                        ?>
                    </div>
                    
                    <div id="term" class="tab-content">
                        <!-- 기간권 탭 컨텐츠 -->
                        <?php
                        // 부모 페이지에서 포함됨을 나타내는 변수 설정
                        $in_parent_page = true;
                        
                        // member_id 명시적 전달
                        $member_id = $member['member_id'];
                        $db_copy = $db;
                        
                        // 기간권 탭 컨텐츠 로드
                        include 'member_form_tabs_and_process/term_tab.php';
                        ?>
                    </div>
                    
                    <div id="juniors" class="tab-content">
                        <!-- 주니어 탭 컨텐츠 -->
                        <?php
                        // 부모 페이지에서 포함됨을 나타내는 변수 설정
                        $in_parent_page = true;
                        
                        // member_id 명시적 전달
                        $member_id = $member['member_id'];
                        $db_copy = $db;
                        
                        // 주니어 탭 컨텐츠 로드
                        include 'member_form_tabs_and_process/juniors_tab.php';
                        ?>
                    </div>
                </div>
            <?php endif; ?>
        </form>
    </div>
</body>
</html>
