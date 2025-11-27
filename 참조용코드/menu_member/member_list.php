<?php
// 세션 유지 시간을 30분(1800초)으로 설정
ini_set('session.gc_maxlifetime', 1800); // 서버 측 세션 유지 시간
session_set_cookie_params(1800); // 클라이언트 측 세션 쿠키 유지 시간

session_start();

// header.php를 불러올 때 session_start 호출을 건너뛰도록 플래그 설정
define('SKIP_SESSION_START', true);
require_once '../common/header.php';
require_once '../config/db_connect.php';

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

$search = isset($_GET['search']) ? $_GET['search'] : '';
$exact_match = false;

// 숫자로만 구성된 검색어인지 확인 (member_id 검색)
if ($search !== '' && is_numeric($search)) {
    $exact_match = true;
}

$query = "
    SELECT 
        m.*,
        b.bill_balance_after as current_credit,
        GROUP_CONCAT(s.staff_name SEPARATOR '<br>') as pro_names,
        (
            SELECT ls.LS_balance_after 
            FROM LS_countings ls 
            WHERE ls.member_id = m.member_id 
            ORDER BY ls.LS_id DESC 
            LIMIT 1
        ) as remaining_lessons,
        (
            SELECT MAX(lc.LS_expiry_date) 
            FROM LS_contracts lc 
            WHERE lc.member_id = m.member_id
        ) as lesson_expiry_date,
        " . ($exact_match ? "CASE WHEN m.member_id = ? THEN 1 ELSE 0 END as exact_match" : "0 as exact_match") . "
    FROM members m
    LEFT JOIN (
        SELECT member_id, bill_balance_after
        FROM bills b1
        WHERE bill_id = (
            SELECT bill_id 
            FROM bills b2 
            WHERE b2.member_id = b1.member_id 
            ORDER BY bill_id DESC 
            LIMIT 1
        )
    ) b ON m.member_id = b.member_id
    LEFT JOIN member_pro_match mpm ON m.member_id = mpm.member_id AND mpm.relation_status = '유효'
    LEFT JOIN Staff s ON mpm.staff_nickname = s.staff_nickname
    LEFT JOIN Junior_relation jr ON m.member_id = jr.member_id
    LEFT JOIN Junior j ON jr.junior_id = j.junior_id
    WHERE 1=1" . 
    ($search ? " AND (m.member_id LIKE ? OR m.member_name LIKE ? OR m.member_phone LIKE ? OR s.staff_name LIKE ? OR j.junior_name LIKE ?)" : "") . "
    GROUP BY m.member_id
    ORDER BY exact_match DESC, m.member_id DESC
";

$stmt = $db->prepare($query);

if ($search) {
    if ($exact_match) {
        $exact_id = $search;
        $like_search = '%' . $search . '%';
        $stmt->bind_param('ssssss', $exact_id, $like_search, $like_search, $like_search, $like_search, $like_search);
    } else {
        $like_search = '%' . $search . '%';
        $stmt->bind_param('sssss', $like_search, $like_search, $like_search, $like_search, $like_search);
    }
}

$stmt->execute();
$result = $stmt->get_result();
?>
<style>
    /* 테이블 너비 설정을 최우선으로 적용 */
    col.col1 { width: 5% !important; } /* # */
    col.col2 { width: 9% !important; } /* 이름 */
    col.col3 { width: 12% !important; } /* 전화번호 */
    col.col4 { width: 10% !important; } /* 닉네임 */
    col.col5 { width: 5% !important; } /* 성별 */
    col.col6 { width: 10% !important; } /* 가입일 */
    col.col7 { width: 10% !important; } /* 잔여크레딧 */
    col.col8 { width: 9% !important; } /* 잔여레슨권 */
    col.col9 { width: 11% !important; } /* 레슨권유효기간 */
    col.col10 { width: 6% !important; } /* 프로 */
    col.col11 { width: 12% !important; } /* 관리 */

    /* 버튼 스타일 최우선 적용 (중요도 순서를 보장하기 위해) */
    .btn-view {
        background: linear-gradient(to right, #5b86e5, #36d1dc) !important;
        color: white !important;
    }
    
    .btn-view:hover {
        background: linear-gradient(to right, #36d1dc, #5b86e5) !important;
        box-shadow: 0 5px 15px rgba(91, 134, 229, 0.4) !important;
    }
    
    .btn-delete {
        background: linear-gradient(to right, #ff416c, #ff4b2b) !important;
        color: white !important;
    }
    
    .btn-delete:hover {
        background: linear-gradient(to right, #ff4b2b, #ff416c) !important;
        box-shadow: 0 5px 15px rgba(255, 65, 108, 0.4) !important;
    }

    /* 중요도가 낮은 컬럼 숨기기 - 모바일 */
    @media screen and (max-width: 768px) {
        col.col4, th:nth-child(4), td:nth-child(4), /* 닉네임 */
        col.col8, th:nth-child(8), td:nth-child(8), /* 잔여레슨권 */
        col.col9, th:nth-child(9), td:nth-child(9) /* 레슨권유효기간 */ {
            display: none;
        }
        
        /* 남은 컬럼 너비 재조정 */
        col.col1 { width: 7% !important; }
        col.col2 { width: 15% !important; }
        col.col3 { width: 20% !important; }
        col.col5 { width: 8% !important; }
        col.col6 { width: 12% !important; }
        col.col7 { width: 14% !important; }
        col.col10 { width: 6% !important; }
        col.col11 { width: 18% !important; }
    }

    @media screen and (max-width: 576px) {
        col.col5, th:nth-child(5), td:nth-child(5), /* 성별 */
        col.col6, th:nth-child(6), td:nth-child(6) /* 가입일 */ {
            display: none;
        }
    }
</style>

    <div class="container">
        <div class="page-header">
            <h1 class="page-title">회원 관리</h1>
        </div>
        <div class="actions">
            <div class="action-left">
                <a href="javascript:void(0);" class="btn btn-success" id="newMemberBtn" onclick="openNewMemberForm(); return false;"><i class="fa fa-plus-circle"></i> 신규 회원 등록</a>
            </div>
            <div class="action-right">
                <form action="" method="GET" class="search-form">
                    <div class="search-group">
                        <input type="text" name="search" placeholder="회원번호, 이름, 전화번호, 프로명 또는 자녀이름" 
                               value="<?php echo isset($_GET['search']) ? htmlspecialchars($_GET['search']) : ''; ?>" 
                               class="search-input">
                        <button type="submit" class="btn-search-submit"><i class="fa fa-search"></i> 검색</button>
                    </div>
                </form>
            </div>
        </div>
        
        <div class="table-container" style="max-height: 600px; overflow-y: auto; overflow-x: auto;">
            <table>
                <colgroup>
                    <col class="col1">
                    <col class="col2">
                    <col class="col3">
                    <col class="col4">
                    <col class="col5">
                    <col class="col6">
                    <col class="col7">
                    <col class="col8">
                    <col class="col9">
                    <col class="col10">
                    <col class="col11">
                </colgroup>
                <thead style="position: sticky; top: 0; z-index: 10; background-color: #3498db;">
                    <tr>
                        <th>#</th>
                        <th>이름</th>
                        <th>전화번호</th>
                        <th>닉네임</th>
                        <th>성별</th>
                        <th>가입일</th>
                        <th>잔여크레딧</th>
                        <th>잔여레슨권</th>
                        <th>레슨유효기간</th>
                        <th>프로</th>
                        <th>관리</th>
                    </tr>
                </thead>
                <tbody>
                    <?php while ($row = $result->fetch_assoc()) : 
                        // 현재 날짜 가져오기
                        $current_date = date('Y-m-d');
                        
                        // 레슨 유효기간이 지났는지 확인
                        $lesson_expired = false;
                        if ($row['lesson_expiry_date'] && strtotime($row['lesson_expiry_date']) < strtotime($current_date)) {
                            $lesson_expired = true;
                        }
                        
                        // 닉네임이 비어있는지 확인
                        $nickname_empty = empty($row['member_nickname']);
                        
                        // 잔여크레딧이 0인지 확인
                        $credit_zero = ($row['current_credit'] === null || $row['current_credit'] <= 0);
                        
                        // 잔여레슨권이 0인지 확인
                        $lesson_zero = ($row['remaining_lessons'] === null || $row['remaining_lessons'] <= 0);
                    ?>
                    <tr>
                        <td><?php echo $row['member_id']; ?></td>
                        <td><?php echo htmlspecialchars($row['member_name']); ?></td>
                        <td><?php echo htmlspecialchars($row['member_phone']); ?></td>
                        <td <?php if ($nickname_empty): ?>class="highlight-cell"<?php endif; ?>><?php echo htmlspecialchars($row['member_nickname'] ?: ''); ?></td>
                        <td><?php echo htmlspecialchars($row['member_gender']); ?></td>
                        <td><?php echo date('Y-m-d', strtotime($row['member_register'])); ?></td>
                        <td <?php if ($credit_zero): ?>class="highlight-cell text-right"<?php else: ?>class="text-right"<?php endif; ?>><?php echo $row['current_credit'] ? number_format($row['current_credit']) : '0'; ?></td>
                        <td <?php if ($lesson_zero): ?>class="highlight-cell text-right"<?php else: ?>class="text-right"<?php endif; ?>><?php echo ($row['remaining_lessons'] !== null && $row['remaining_lessons'] > 0) ? number_format($row['remaining_lessons']) : '-'; ?></td>
                        <td <?php if ($lesson_expired): ?>class="highlight-cell"<?php endif; ?>><?php echo $row['lesson_expiry_date'] ? date('Y-m-d', strtotime($row['lesson_expiry_date'])) : '-'; ?></td>
                        <td class="pro-cell"><?php echo $row['pro_names'] ? $row['pro_names'] : '-'; ?></td>
                        <td>
                            <a href="javascript:void(0);" onclick="openMemberForm(<?php echo $row['member_id']; ?>); return false;" class="btn btn-small btn-view">
                                <i class="fa fa-eye"></i> <span class="btn-text">조회</span>
                            </a>
                            <a href="#" onclick="deleteMember(<?php echo $row['member_id']; ?>); return false;" class="btn btn-small btn-delete">
                                <i class="fa fa-trash"></i> <span class="btn-text">삭제</span>
                            </a>
                        </td>
                    </tr>
                    <?php endwhile; ?>
                </tbody>
            </table>
        </div>
    </div>

    <!-- 회원 삭제 확인 모달 -->
    <div id="deleteMemberModal" class="modal">
        <div class="modal-content delete-modal">
            <div class="modal-header delete-header">
                <h2>회원 삭제 확인</h2>
                <span class="close" id="closeDeleteModal">&times;</span>
            </div>
            <div class="modal-body">
                <p class="delete-message">선택한 회원을 정말 삭제하시겠습니까?</p>
                <p class="delete-warning"><i class="fa fa-exclamation-triangle"></i> 이 작업은 되돌릴 수 없습니다.</p>
                
                <div class="password-form">
                    <label for="deletePassword">관리자 비밀번호</label>
                    <input type="password" id="deletePassword" class="form-input" placeholder="비밀번호를 입력하세요">
                </div>
            </div>
            <div class="modal-footer">
                <button type="button" id="confirmDeleteBtn" class="btn btn-delete">삭제</button>
                <button type="button" id="cancelDeleteBtn" class="btn btn-secondary">취소</button>
            </div>
        </div>
    </div>

    <script>
    // 회원 삭제 처리를 위한 변수
    var deleteMemberId = null;
    var deleteMemberModal = document.getElementById("deleteMemberModal");
    var closeDeleteModal = document.getElementById("closeDeleteModal");
    var confirmDeleteBtn = document.getElementById("confirmDeleteBtn");
    var cancelDeleteBtn = document.getElementById("cancelDeleteBtn");
    
    // 검색창 포커스 효과 처리
    document.addEventListener('DOMContentLoaded', function() {
        const searchInput = document.querySelector('.search-input');
        const searchGroup = document.querySelector('.search-group');
        
        if (searchInput && searchGroup) {
            searchInput.addEventListener('focus', function() {
                searchGroup.classList.add('focused');
            });
            
            searchInput.addEventListener('blur', function() {
                searchGroup.classList.remove('focused');
            });
        }
    });
    
    // 회원 폼 팝업 열기 함수
    function openMemberForm(id) {
        const width = 1200;
        const height = 800;
        const left = (screen.width - width) / 2;
        const top = (screen.height - height) / 2;
        
        // 팝업 창 열기
        const memberWindow = window.open(
            'member_form.php?id=' + id,
            'memberForm_' + id,
            `width=${width},height=${height},left=${left},top=${top},resizable=yes,scrollbars=yes`
        );
        
        // 팝업이 차단되었는지 확인
        if (memberWindow === null || typeof memberWindow === 'undefined') {
            alert('팝업이 차단되었습니다. 팝업 차단을 해제해주세요.');
        }
    }
    
    // 신규 회원 등록 폼 팝업 열기 함수
    function openNewMemberForm() {
        const width = 1200;
        const height = 800;
        const left = (screen.width - width) / 2;
        const top = (screen.height - height) / 2;
        
        // 팝업 창 열기
        const newMemberWindow = window.open(
            'member_form.php',
            'newMemberForm',
            `width=${width},height=${height},left=${left},top=${top},resizable=yes,scrollbars=yes`
        );
        
        // 팝업이 차단되었는지 확인
        if (newMemberWindow === null || typeof newMemberWindow === 'undefined') {
            alert('팝업이 차단되었습니다. 팝업 차단을 해제해주세요.');
        }
    }
    
    // 삭제 함수
    function deleteMember(id) {
        deleteMemberId = id;
        deleteMemberModal.style.display = "block";
        document.body.style.overflow = "hidden"; // 스크롤 방지
        document.getElementById("deletePassword").value = ""; // 비밀번호 필드 초기화
        document.getElementById("deletePassword").focus();
    }
    
    // 삭제 모달 닫기
    closeDeleteModal.onclick = function() {
        deleteMemberModal.style.display = "none";
        document.body.style.overflow = ""; // 스크롤 허용
    }
    
    // 삭제 취소
    cancelDeleteBtn.onclick = function() {
        deleteMemberModal.style.display = "none";
        document.body.style.overflow = ""; // 스크롤 허용
    }
    
    // 삭제 확인
    confirmDeleteBtn.onclick = function() {
        const password = document.getElementById("deletePassword").value;
        
        if (!password) {
            alert("비밀번호를 입력해주세요.");
            return;
        }
        
        if (password === '0102') {
            processDeleteMember(deleteMemberId, password);
        } else {
            alert('비밀번호가 올바르지 않습니다.');
        }
    }
    
    // Enter 키로 삭제 실행
    document.getElementById("deletePassword").addEventListener("keyup", function(event) {
        if (event.key === "Enter") {
            confirmDeleteBtn.click();
        }
    });
    
    // 모달 외부 클릭시 닫기
    window.onclick = function(event) {
        // 삭제 모달 배경 클릭 시 닫기
        if (event.target == deleteMemberModal) {
            deleteMemberModal.style.display = "none";
            document.body.style.overflow = ""; // 스크롤 허용
        }
    }
    
    // 삭제 처리 함수
    function processDeleteMember(id, password) {
        // 버튼 비활성화 및 로딩 표시
        confirmDeleteBtn.disabled = true;
        confirmDeleteBtn.innerHTML = '<i class="fa fa-spinner fa-spin"></i> 처리 중...';
        
        fetch('member_delete.php', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: `id=${id}&password=${password}`
        })
        .then(response => response.json())
        .then(data => {
            if (data.success) {
                deleteMemberModal.style.display = "none";
                document.body.style.overflow = ""; // 스크롤 허용
                location.reload();
            } else {
                alert('삭제 실패: ' + (data.message || '알 수 없는 오류가 발생했습니다.'));
                // 버튼 상태 복원
                confirmDeleteBtn.disabled = false;
                confirmDeleteBtn.innerHTML = '삭제';
            }
        })
        .catch(error => {
            console.error('Error:', error);
            alert('삭제 중 오류가 발생했습니다.');
            // 버튼 상태 복원
            confirmDeleteBtn.disabled = false;
            confirmDeleteBtn.innerHTML = '삭제';
        });
    }
    </script>
</body>
</html> 