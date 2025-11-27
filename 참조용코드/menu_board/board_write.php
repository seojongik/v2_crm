<?php
require_once '../common/header.php';
require_once '../config/db_connect.php';

$board_type = $_GET['type'] ?? '일반';
$member_id = $_GET['member_id'] ?? null;

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $title = $_POST['title'];
    $content = $_POST['content'];
    $staff_id = $_SESSION['staff_id'];
    $member_id = $_POST['member_id'] ?? null;
    
    $stmt = $db->prepare('INSERT INTO Board (title, content, staff_id, board_type, member_id) VALUES (?, ?, ?, ?, ?)');
    $stmt->bind_param('ssisi', $title, $content, $staff_id, $board_type, $member_id);
    
    if ($stmt->execute()) {
        // 메모 탭에서 왔으면 팝업창 닫고 부모창 새로고침
        if (isset($_GET['member_id'])) {
            echo "<script>
                window.opener.location.reload();
                window.close();
            </script>";
            exit;
        }
        
        header('Location: board_list.php?type=' . urlencode($board_type));
        exit;
    }
}

// 회원 검색 처리
$member_search = isset($_GET['member_search']) ? $_GET['member_search'] : '';
$members_query = 'SELECT member_id, member_name, member_phone FROM members';
$members_params = [];
$members_types = '';

// 회원 ID가 URL로 전달된 경우, 해당 회원 정보 조회
$selected_member = null;
if ($member_id) {
    $member_stmt = $db->prepare('SELECT member_id, member_name, member_phone FROM members WHERE member_id = ?');
    $member_stmt->bind_param('i', $member_id);
    $member_stmt->execute();
    $selected_member = $member_stmt->get_result()->fetch_assoc();
}

if ($member_search && in_array($board_type, ['회원요청', '상담기록'])) {
    $member_search = '%' . $member_search . '%';
    $members_query .= ' WHERE member_name LIKE ? OR member_phone LIKE ?';
    $members_params = [$member_search, $member_search];
    $members_types = 'ss';
}

$members_query .= ' ORDER BY member_name ASC LIMIT 100';
$members_stmt = $db->prepare($members_query);

if (!empty($members_params)) {
    $members_stmt->bind_param($members_types, ...$members_params);
}

$members_stmt->execute();
$members_result = $members_stmt->get_result();
?>

<style>
body {
    font-family: 'Noto Sans KR', sans-serif;
    line-height: 1.6;
    color: #333;
    background-color: #f8f9fa;
    margin: 0;
    padding: 20px;
}

.write-modal {
    width: 800px;
    max-width: 90%;
}

.modal {
    display: block;
    position: fixed;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    background: rgba(0,0,0,0.5);
    z-index: 1000;
    overflow-y: auto;
}

.modal-content {
    position: relative;
    background: #fff;
    margin: 30px auto;
    padding: 0;
    border-radius: 16px;
    box-shadow: 0 10px 30px rgba(0, 0, 0, 0.08);
    overflow: hidden;
    transition: all 0.3s ease;
}

.modal-header {
    background: linear-gradient(135deg, #5b86e5 0%, #36d1dc 100%);
    color: white;
    padding: 16px 20px;
    display: flex;
    justify-content: space-between;
    align-items: center;
    border-bottom: none;
    box-shadow: 0 4px 15px rgba(91, 134, 229, 0.2);
}

.modal-header h3 {
    margin: 0;
    font-size: 22px;
    font-weight: 700;
    display: flex;
    align-items: center;
}

.modal-body {
    padding: 20px;
}

.modal-footer {
    display: flex;
    justify-content: flex-end;
    gap: 10px;
    margin-top: 20px;
    padding: 15px 20px;
    border-top: 1px solid #f0f5ff;
}

.close {
    font-size: 24px;
    cursor: pointer;
    color: white;
    transition: all 0.3s ease;
}

.close:hover {
    transform: rotate(90deg);
}

.form-header {
    background: linear-gradient(to right, #f8fafc, #f1f7fa);
    border-radius: 12px;
    padding: 18px;
    margin-bottom: 25px;
    display: flex;
    flex-wrap: wrap;
    box-shadow: 0 3px 10px rgba(0, 0, 0, 0.03);
}

.writer-info {
    display: flex;
    align-items: center;
    font-size: 14px;
    color: #5c7185;
    background: rgba(255, 255, 255, 0.7);
    padding: 6px 12px;
    border-radius: 30px;
    box-shadow: 0 2px 5px rgba(0, 0, 0, 0.03);
}

.writer-info .date {
    margin-left: 20px;
    display: flex;
    align-items: center;
}

.writer-info .date:before {
    content: '';
    display: inline-block;
    width: 4px;
    height: 4px;
    background: #5c7185;
    border-radius: 50%;
    margin-right: 20px;
}

.form-row {
    display: flex;
    gap: 20px;
    margin-bottom: 20px;
    padding: 0 20px;
}

.title-group {
    flex: 1;
}

.member-group {
    width: 300px;
}

.member-search-container {
    display: flex;
    gap: 10px;
}

.board-form {
    padding: 20px 0;
}

.form-group {
    margin-bottom: 20px;
    padding: 0 20px;
}

.form-group label {
    display: block;
    margin-bottom: 8px;
    font-weight: 600;
    color: #495057;
    font-size: 15px;
}

#title, #content, #member_search {
    width: 100%;
    padding: 12px 15px;
    border: 1px solid #dce1e6;
    border-radius: 12px;
    font-size: 15px;
    transition: all 0.3s ease;
    background-color: #fff;
    box-sizing: border-box;
    font-family: 'Noto Sans KR', sans-serif;
    box-shadow: 0 1px 3px rgba(0,0,0,0.05);
}

#title:focus, #content:focus, #member_search:focus {
    border-color: #36d1dc;
    box-shadow: 0 0 0 3px rgba(54, 209, 220, 0.2);
    outline: none;
}

textarea#content {
    min-height: 300px;
    resize: vertical;
}

/* 버튼 기본 스타일 */
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
    background: linear-gradient(to right, #36d1dc, #5b86e5);
    color: white;
}

.btn:hover {
    background: linear-gradient(to right, #5b86e5, #36d1dc);
    transform: translateY(-2px);
    box-shadow: 0 5px 15px rgba(91, 134, 229, 0.4);
}

.btn-small {
    padding: 5px 10px;
    font-size: 12px;
}

.btn-cancel {
    background: linear-gradient(to right, #a1c4fd, #c2e9fb);
    color: #2c3e50;
}

.btn-cancel:hover {
    background: linear-gradient(to right, #c2e9fb, #a1c4fd);
}

#searchResults {
    max-height: 400px;
    overflow-y: auto;
}

.search-result-item {
    padding: 10px;
    border-bottom: 1px solid #eee;
    cursor: pointer;
    transition: background 0.2s;
}

.search-result-item:hover {
    background: #f5f9ff;
}

.search-result-item .member-name {
    font-weight: bold;
}

.search-result-item .member-phone {
    color: #666;
    margin-left: 10px;
}

.no-results {
    text-align: center;
    padding: 20px;
    color: #666;
}

/* 폰트 추가 */
@import url('https://fonts.googleapis.com/css2?family=Noto+Sans+KR:wght@400;500;700&display=swap');
</style>

<!-- FontAwesome 아이콘 추가 -->
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/5.15.4/css/all.min.css">

<!-- 글쓰기 모달 -->
<div id="writeModal" class="modal">
    <div class="modal-content write-modal">
        <div class="modal-header">
            <h3><i class="fas fa-edit"></i> <?php echo htmlspecialchars($board_type); ?> 글쓰기</h3>
            <span class="close" onclick="closeWriteModal()">&times;</span>
        </div>
        <form method="POST" class="board-form" id="writeForm">
            <div class="form-header">
                <div class="writer-info">
                    <i class="fas fa-user-edit"></i> 작성자: <?php echo htmlspecialchars($_SESSION['staff_name']); ?>
                    (<?php echo htmlspecialchars($_SESSION['staff_type']); ?>)
                    <span class="date"><i class="fas fa-calendar-alt"></i> 작성일: <?php echo date('Y-m-d H:i'); ?></span>
                </div>
            </div>

            <div class="form-row">
                <div class="title-group">
                    <label for="title">제목</label>
                    <input type="text" id="title" name="title" required>
                </div>
                
                <?php if (in_array($board_type, ['회원요청', '상담기록'])): ?>
                <div class="member-group">
                    <label for="member_search">회원 검색</label>
                    <div class="member-search-container">
                        <input type="text" id="member_search" 
                               placeholder="회원명 또는 전화번호" 
                               value="<?php echo $selected_member ? $selected_member['member_name'] . ' (' . $selected_member['member_phone'] . ')' : ''; ?>">
                        <input type="hidden" id="member_id" name="member_id" 
                               value="<?php echo $selected_member ? $selected_member['member_id'] : ''; ?>" 
                               required>
                        <button type="button" class="btn btn-small" onclick="searchMembers()"><i class="fas fa-search"></i> 검색</button>
                    </div>
                </div>
                <?php endif; ?>
            </div>
            
            <div class="form-group">
                <label for="content">내용</label>
                <textarea id="content" name="content" required><?php echo $board_type === '상담기록' ? "구분 : \n고객명 : \n전화번호 : \n특기사항 : " : ''; ?></textarea>
            </div>

            <div class="modal-footer">
                <button type="submit" class="btn"><i class="fas fa-save"></i> 저장</button>
                <button type="button" class="btn btn-cancel" onclick="closeWriteModal()"><i class="fas fa-times"></i> 취소</button>
            </div>
        </form>
    </div>
</div>

<!-- 회원 검색 결과 모달 -->
<div id="memberSearchModal" class="modal" style="display: none;">
    <div class="modal-content">
        <div class="modal-header">
            <h3><i class="fas fa-search"></i> 회원 검색 결과</h3>
            <span class="close" onclick="closeMemberSearchModal()">&times;</span>
        </div>
        <div class="modal-body">
            <div id="searchResults"></div>
        </div>
    </div>
</div>

<script>
// 페이지 로드 시 글쓰기 모달 표시
document.addEventListener('DOMContentLoaded', function() {
    document.getElementById('writeModal').style.display = 'block';
    
    // 회원 ID가 미리 선택된 경우, 상담기록 템플릿에 회원 정보 자동 입력
    <?php if ($selected_member && $board_type === '상담기록'): ?>
    const selectedMember = {
        member_name: '<?php echo addslashes($selected_member['member_name']); ?>',
        member_phone: '<?php echo addslashes($selected_member['member_phone']); ?>'
    };
    
    let content = document.getElementById('content').value;
    content = content.replace(/고객명 : .*$/m, `고객명 : ${selectedMember.member_name}`);
    content = content.replace(/전화번호 : .*$/m, `전화번호 : ${selectedMember.member_phone}`);
    document.getElementById('content').value = content;
    <?php endif; ?>
});

function closeWriteModal() {
    if (confirm('작성 중인 내용이 저장되지 않습니다. 창을 닫으시겠습니까?')) {
        window.location.href = 'board_list.php?type=<?php echo urlencode($board_type); ?>';
    }
}

function searchMembers() {
    const searchValue = document.getElementById('member_search').value;
    if (searchValue.length < 2) {
        alert('검색어를 2자 이상 입력하세요.');
        return;
    }

    fetch(`member_search.php?search=${encodeURIComponent(searchValue)}`)
        .then(response => response.json())
        .then(data => {
            if (data.error) {
                alert(data.error === 'Unauthorized' ? '로그인이 필요합니다.' : '오류가 발생했습니다.');
                return;
            }

            if (data.length === 0) {
                alert('검색 결과가 없습니다.');
                return;
            }

            const resultsDiv = document.getElementById('searchResults');
            resultsDiv.innerHTML = '';
            
            data.forEach(member => {
                const div = document.createElement('div');
                div.className = 'member-item';
                div.innerHTML = `${member.member_name} (${member.member_phone})`;
                div.onclick = () => selectMember(member);
                resultsDiv.appendChild(div);
            });

            document.getElementById('memberSearchModal').style.display = 'block';
        })
        .catch(error => {
            console.error('Error:', error);
            alert('회원 검색 중 오류가 발생했습니다.');
        });
}

function selectMember(member) {
    document.getElementById('member_search').value = `${member.member_name} (${member.member_phone})`;
    document.getElementById('member_id').value = member.member_id;
    closeMemberSearchModal();

    if ('<?php echo $board_type; ?>' === '상담기록') {
        let content = document.getElementById('content').value;
        content = content.replace(/고객명 : .*$/m, `고객명 : ${member.member_name}`);
        content = content.replace(/전화번호 : .*$/m, `전화번호 : ${member.member_phone}`);
        document.getElementById('content').value = content;
    }
}

function closeMemberSearchModal() {
    document.getElementById('memberSearchModal').style.display = 'none';
}

// 회원 검색창에서 Enter 키 처리
const memberSearchElement = document.getElementById('member_search');
if (memberSearchElement) {
    memberSearchElement.addEventListener('keypress', function(e) {
        if (e.key === 'Enter') {
            e.preventDefault();
            searchMembers();
        }
    });
}

// ESC 키로 모달 닫기 방지
window.addEventListener('keydown', function(e) {
    if (e.key === 'Escape') {
        e.preventDefault();
        if (document.getElementById('memberSearchModal').style.display === 'block') {
            closeMemberSearchModal();
        } else {
            closeWriteModal();
        }
    }
});
</script>

</body>
</html>