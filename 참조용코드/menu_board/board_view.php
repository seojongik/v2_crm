<?php
require_once '../common/header.php';
require_once '../config/db_connect.php';

$id = $_GET['id'] ?? null;
$redirect_url = 'board_list.php';

if ($id) {
    // 게시글 ID가 있으면 해당 게시글의 board_type을 가져와서 해당 게시판으로 리다이렉트
    $stmt = $db->prepare('SELECT board_type FROM Board WHERE board_id = ?');
    $stmt->bind_param('i', $id);
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($result->num_rows > 0) {
        $board = $result->fetch_assoc();
        $redirect_url = 'board_list.php?type=' . urlencode($board['board_type']);
    }
}
?>
<!DOCTYPE html>
<html lang="ko">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>게시글 보기</title>
    <script>
    // 페이지 로드 시 리다이렉트 및 모달 열기
    window.onload = function() {
        const boardId = <?php echo $id ?: 'null'; ?>;
        
        if (boardId) {
            // 게시글 ID가 있으면 리다이렉트 후 모달 열기
            const redirectUrl = "<?php echo $redirect_url; ?>";
            
            // localStorage에 게시글 ID 저장 (리다이렉트 후 모달 열기 위함)
            localStorage.setItem('openPostModal', boardId);
            
            // 리다이렉트
            window.location.href = redirectUrl;
        } else {
            // 게시글 ID가 없으면 목록으로만 리다이렉트
            window.location.href = "<?php echo $redirect_url; ?>";
        }
    };
    </script>
</head>
<body>
    <p>리다이렉트 중입니다...</p>
</body>
</html>