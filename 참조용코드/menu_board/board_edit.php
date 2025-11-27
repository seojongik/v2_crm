<?php
require_once '../common/header.php';
require_once '../config/db_connect.php';

$id = $_GET['id'] ?? null;
if (!$id) {
    header('Location: board_list.php');
    exit;
}

// 게시글 조회
$stmt = $db->prepare('SELECT * FROM Board WHERE board_id = ?');
$stmt->bind_param('i', $id);
$stmt->execute();
$result = $stmt->get_result();
$post = $result->fetch_assoc();

// 자신의 글이 아니면 목록으로
if (!$post || $post['staff_id'] !== $_SESSION['staff_id']) {
    header('Location: board_list.php');
    exit;
}

// 수정 처리
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $title = $_POST['title'];
    $content = $_POST['content'];
    $member_id = $_POST['member_id'] ?? null;
    
    $stmt = $db->prepare('UPDATE Board SET title = ?, content = ?, member_id = ? WHERE board_id = ? AND staff_id = ?');
    $stmt->bind_param('ssiii', $title, $content, $member_id, $id, $_SESSION['staff_id']);
    
    if ($stmt->execute()) {
        header('Location: board_view.php?id=' . $id);
        exit;
    }
}

// 회원 검색 처리
$member_search = isset($_GET['member_search']) ? $_GET['member_search'] : '';
$members_query = 'SELECT member_id, member_name, member_phone FROM members';
$members_params = [];
$members_types = '';

if ($member_search && in_array($post['board_type'], ['회원요청', '상담기록'])) {
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

<div class="container">
    <h1><?php echo htmlspecialchars($post['board_type']); ?> 글 수정</h1>
    <form method="POST" class="board-form">
        <div class="form-group">
            <label for="title">제목</label>
            <input type="text" id="title" name="title" required 
                   value="<?php echo htmlspecialchars($post['title']); ?>">
        </div>
        
        <?php if (in_array($post['board_type'], ['회원요청', '상담기록'])): ?>
        <div class="form-group">
            <label for="member_id">회원 선택</label>
            <div class="member-search-container">
                <input type="text" id="member_search_input" placeholder="회원명 또는 전화번호 검색" 
                       value="<?php echo htmlspecialchars($member_search); ?>">
                <button type="button" id="search_member_btn" class="btn">검색</button>
            </div>
            <select id="member_id" name="member_id" required>
                <option value="">회원을 선택하세요</option>
                <?php while ($member = $members_result->fetch_assoc()): ?>
                <option value="<?php echo $member['member_id']; ?>"
                        <?php echo $member['member_id'] == $post['member_id'] ? ' selected' : ''; ?>>
                    <?php echo htmlspecialchars($member['member_name']); ?> 
                    (<?php echo htmlspecialchars($member['member_phone']); ?>)
                </option>
                <?php endwhile; ?>
            </select>
        </div>
        <?php endif; ?>
        
        <div class="form-group">
            <label for="content">내용</label>
            <textarea id="content" name="content" required><?php echo htmlspecialchars($post['content']); ?></textarea>
        </div>
        
        <div class="form-actions">
            <button type="submit" class="btn">저장</button>
            <a href="board_view.php?id=<?php echo $post['board_id']; ?>" class="btn">취소</a>
        </div>
    </form>
</div>

<script>
document.getElementById('search_member_btn').addEventListener('click', function() {
    const searchValue = document.getElementById('member_search_input').value;
    window.location.href = `board_edit.php?id=<?php echo $id; ?>&member_search=${encodeURIComponent(searchValue)}`;
});

document.getElementById('member_search_input').addEventListener('keypress', function(e) {
    if (e.key === 'Enter') {
        e.preventDefault();
        document.getElementById('search_member_btn').click();
    }
});

<?php if (in_array($post['board_type'], ['회원요청', '상담기록'])): ?>
// 회원 선택 시 자동으로 내용에 회원 정보 추가 (상담기록인 경우)
document.getElementById('member_id').addEventListener('change', function() {
    if ('<?php echo $post['board_type']; ?>' === '상담기록') {
        const memberSelect = document.getElementById('member_id');
        const selectedOption = memberSelect.options[memberSelect.selectedIndex];
        
        if (selectedOption.value) {
            const memberInfo = selectedOption.text.split('(');
            const memberName = memberInfo[0].trim();
            const memberPhone = memberInfo[1].replace(')', '').trim();
            
            let content = document.getElementById('content').value;
            content = content.replace(/고객명 : .*$/m, `고객명 : ${memberName}`);
            content = content.replace(/전화번호 : .*$/m, `전화번호 : ${memberPhone}`);
            
            document.getElementById('content').value = content;
        }
    }
});
<?php endif; ?>
</script>

</body>
</html>