<?php
// 메모 작성/수정/조회 폼 - 별도 창으로 열림
require_once '../../config/db_connect.php';
session_start();

// 로그인 확인
if (!isset($_SESSION['staff_id'])) {
    echo '<div class="error-message">로그인이 필요합니다.</div>';
    exit;
}

// 회원 ID가 전달됐는지 확인
if (!isset($_GET['member_id']) || empty($_GET['member_id'])) {
    echo '<div class="error-message">회원 ID가 전달되지 않았습니다.</div>';
    exit;
}

$member_id = intval($_GET['member_id']);
$board_id = isset($_GET['board_id']) ? intval($_GET['board_id']) : null;
$mode = isset($_GET['mode']) ? $_GET['mode'] : ($board_id ? '수정' : '작성');

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

// 게시글 정보 조회 (수정 또는 조회 모드인 경우)
$post = null;
$comments = [];
if ($board_id) {
    $stmt = $db->prepare("
        SELECT b.*, s.staff_name, s.staff_type
        FROM Board b
        JOIN Staff s ON b.staff_id = s.staff_id
        WHERE b.board_id = ?
    ");
    $stmt->bind_param('i', $board_id);
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($result->num_rows === 0) {
        echo '<div class="error-message">메모 정보를 찾을 수 없습니다.</div>';
        exit;
    }
    
    $post = $result->fetch_assoc();

    // 수정 모드이고 자신의 게시글이 아닌 경우 수정 불가
    if ($mode === '수정' && $post['staff_id'] != $_SESSION['staff_id']) {
        echo '<div class="error-message">자신이 작성한 메모만 수정할 수 있습니다.</div>';
        exit;
    }
    
    // 댓글 조회 (조회 모드에서만 필요)
    if ($mode === 'view') {
        $comments_query = "
            SELECT c.*, s.staff_name 
            FROM Comment c
            JOIN Staff s ON c.staff_id = s.staff_id
            WHERE c.board_id = ?
            ORDER BY c.created_at ASC
        ";
        $stmt = $db->prepare($comments_query);
        $stmt->bind_param('i', $board_id);
        $stmt->execute();
        $comments_result = $stmt->get_result();
        
        while ($comment = $comments_result->fetch_assoc()) {
            $comments[] = $comment;
        }
    }
}

// 현재 직원 정보 가져오기
$staff_id = $_SESSION['staff_id'];
$staff_query = "SELECT staff_id, staff_name, staff_type FROM Staff WHERE staff_id = ?";
$staff_stmt = $db->prepare($staff_query);
$staff_stmt->bind_param('i', $staff_id);
$staff_stmt->execute();
$staff_result = $staff_stmt->get_result();
$staff_info = $staff_result->fetch_assoc();

// POST 요청 처리 (저장)
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    // 댓글 작성 요청 처리
    if (isset($_POST['action']) && $_POST['action'] === 'add_comment') {
        if (empty($_POST['comment_content'])) {
            $error_message = "댓글 내용을 입력해주세요.";
        } else {
            $comment_content = $_POST['comment_content'];
            
            // 댓글 저장
            $query = "INSERT INTO Comment (board_id, staff_id, content, created_at) VALUES (?, ?, ?, NOW())";
            $stmt = $db->prepare($query);
            $stmt->bind_param('iis', $board_id, $_SESSION['staff_id'], $comment_content);
            
            if ($stmt->execute()) {
                // 페이지 새로고침 (댓글이 추가된 상태로)
                header("Location: memo_form.php?member_id=$member_id&board_id=$board_id&mode=view");
                exit;
            } else {
                $error_message = "댓글 저장 중 오류가 발생했습니다.";
            }
        }
    }
    // 메모 삭제 요청 처리
    else if (isset($_POST['action']) && $_POST['action'] === 'delete_post') {
        // 자신의 게시글인지 확인
        if ($post['staff_id'] != $_SESSION['staff_id']) {
            $error_message = "자신이 작성한 메모만 삭제할 수 있습니다.";
        } else {
            // 댓글 먼저 삭제
            $stmt = $db->prepare('DELETE FROM Comment WHERE board_id = ?');
            $stmt->bind_param('i', $board_id);
            $stmt->execute();
            
            // 게시글 삭제
            $stmt = $db->prepare('DELETE FROM Board WHERE board_id = ? AND staff_id = ?');
            $stmt->bind_param('ii', $board_id, $_SESSION['staff_id']);
            
            if ($stmt->execute()) {
                // 삭제 성공 시 부모 창 새로고침 후 창 닫기
                echo "<script>
                    alert('메모가 삭제되었습니다.');
                    if (window.opener && !window.opener.closed) {
                        window.opener.location.reload();
                    }
                    window.close();
                </script>";
                exit;
            } else {
                $error_message = "삭제 중 오류가 발생했습니다.";
            }
        }
    }
    // 메모 작성/수정 요청 처리
    else {
        // 필수 항목 체크
        if (empty($_POST['title']) || empty($_POST['content'])) {
            $error_message = "제목과 내용은 필수 입력 항목입니다.";
        } else {
            $title = $_POST['title'];
            $content = $_POST['content'];
            $board_type = '회원요청'; // 기본값

            try {
                if ($mode === '작성') {
                    // 새 메모 저장
                    $query = "INSERT INTO Board (title, content, staff_id, board_type, member_id, created_at, updated_at) 
                            VALUES (?, ?, ?, ?, ?, NOW(), NOW())";
                    $stmt = $db->prepare($query);
                    $stmt->bind_param('ssisi', $title, $content, $staff_id, $board_type, $member_id);
                } else {
                    // 기존 메모 수정
                    $query = "UPDATE Board SET title = ?, content = ?, updated_at = NOW() 
                            WHERE board_id = ? AND staff_id = ?";
                    $stmt = $db->prepare($query);
                    $stmt->bind_param('ssii', $title, $content, $board_id, $staff_id);
                }
                
                $success = $stmt->execute();
                
                if ($success) {
                    // 저장 성공 시 부모 창 새로고침 후 창 닫기
                    echo "<script>
                        alert('메모가 성공적으로 " . ($mode === '작성' ? '저장' : '수정') . "되었습니다.');
                        if (window.opener && !window.opener.closed) {
                            window.opener.location.reload();
                        }
                        window.close();
                    </script>";
                    exit;
                } else {
                    $error_message = "저장 중 오류가 발생했습니다.";
                }
            } catch (Exception $e) {
                $error_message = "오류: " . $e->getMessage();
            }
        }
    }
}

// 페이지 타이틀 설정
if ($mode === 'view') {
    $page_title = "메모 보기";
} else if ($mode === '수정') {
    $page_title = "메모 수정";
} else {
    $page_title = "새 메모 작성";
}
?>

<!DOCTYPE html>
<html lang="ko">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title><?php echo $page_title; ?></title>
    <link href="https://fonts.googleapis.com/css2?family=Noto+Sans+KR:wght@400;500;700&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/5.15.4/css/all.min.css">
    <style>
        body {
            font-family: 'Noto Sans KR', sans-serif;
            line-height: 1.6;
            color: #333;
            background-color: #f8f9fa;
            margin: 0;
            padding: 0;
        }
        
        .memo-container {
            max-width: 700px;
            margin: 0 auto;
            padding: 0;
            background-color: transparent;
        }
        
        .memo-card {
            background-color: #fff;
            border-radius: 16px;
            box-shadow: 0 10px 30px rgba(0, 0, 0, 0.08);
            overflow: hidden;
            margin-bottom: 20px;
            transition: all 0.3s ease;
        }
        
        .memo-card:hover {
            transform: translateY(-5px);
            box-shadow: 0 15px 40px rgba(91, 134, 229, 0.15);
        }
        
        .memo-header {
            background: linear-gradient(135deg, #5b86e5 0%, #36d1dc 100%);
            color: white;
            padding: 16px 20px;
            display: flex;
            justify-content: space-between;
            align-items: center;
            border-bottom: none;
            box-shadow: 0 4px 15px rgba(91, 134, 229, 0.2);
        }
        
        .memo-header h1 {
            margin: 0;
            font-size: 22px;
            font-weight: 700;
            display: flex;
            align-items: center;
        }
        
        .memo-header h1 i {
            margin-right: 10px;
            font-size: 24px;
        }
        
        .member-info {
            background-color: rgba(255, 255, 255, 0.1);
            padding: 6px 15px;
            border-radius: 50px;
            font-size: 14px;
            display: inline-flex;
            align-items: center;
            margin-left: 15px;
        }
        
        .member-info i {
            margin-right: 8px;
            font-size: 16px;
        }
        
        .memo-body {
            padding: 15px;
        }
        
        .memo-section {
            margin-bottom: 15px;
        }
        
        .memo-section-title {
            font-size: 16px;
            font-weight: 700;
            color: #333;
            margin-bottom: 12px;
            display: flex;
            align-items: center;
            padding-bottom: 8px;
            border-bottom: 2px solid rgba(54, 209, 220, 0.3);
        }
        
        .memo-section-title i {
            margin-right: 8px;
            color: #5b86e5;
        }
        
        .form-group {
            margin-bottom: 20px;
        }
        
        .form-group label {
            display: block;
            margin-bottom: 8px;
            font-weight: 600;
            color: #495057;
            font-size: 15px;
        }
        
        .form-control {
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
        
        .form-control:focus {
            border-color: #36d1dc;
            box-shadow: 0 0 0 3px rgba(54, 209, 220, 0.2);
            outline: none;
        }
        
        textarea.form-control {
            min-height: 200px;
            resize: vertical;
        }
        
        .memo-view-content {
            padding: 5px;
            line-height: 1.5;
            white-space: pre-line;
            word-break: break-word;
        }
        
        .memo-meta {
            background: linear-gradient(to right, #f8fafc, #f1f7fa);
            border-radius: 12px;
            padding: 18px;
            margin-bottom: 25px;
            display: flex;
            flex-wrap: wrap;
            gap: 20px;
            box-shadow: 0 3px 10px rgba(0, 0, 0, 0.03);
        }
        
        .memo-meta-item {
            display: flex;
            align-items: center;
            font-size: 14px;
            color: #5c7185;
            background: rgba(255, 255, 255, 0.7);
            padding: 6px 12px;
            border-radius: 30px;
            box-shadow: 0 2px 5px rgba(0, 0, 0, 0.03);
        }
        
        .memo-meta-item i {
            margin-right: 8px;
            color: #5b86e5;
            font-size: 16px;
        }
        
        .memo-actions {
            display: flex;
            justify-content: flex-end;
            align-items: center;
            margin-top: 15px;
            gap: 8px;
        }
        
        /* 버튼 기본 스타일 */
        .btn-primary, .btn-secondary, .btn-warning, .btn-danger {
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
            margin-right: 5px;
        }
        
        .btn-primary {
            background: linear-gradient(to right, #36d1dc, #5b86e5);
            color: white;
        }
        
        .btn-primary:hover {
            background: linear-gradient(to right, #5b86e5, #36d1dc);
            transform: translateY(-2px);
            box-shadow: 0 5px 15px rgba(91, 134, 229, 0.4);
        }
        
        .btn-secondary {
            background: linear-gradient(to right, #a1c4fd, #c2e9fb);
            color: #2c3e50;
        }
        
        .btn-secondary:hover {
            background: linear-gradient(to right, #c2e9fb, #a1c4fd);
            transform: translateY(-2px);
            box-shadow: 0 5px 15px rgba(161, 196, 253, 0.4);
        }
        
        .btn-warning {
            background: linear-gradient(to right, #ffd86f, #fc6076);
            color: white;
        }
        
        .btn-warning:hover {
            background: linear-gradient(to right, #fc6076, #ffd86f);
            transform: translateY(-2px);
            box-shadow: 0 5px 15px rgba(252, 96, 118, 0.4);
        }
        
        .btn-danger {
            background: linear-gradient(to right, #ff416c, #ff4b2b);
            color: white;
        }
        
        .btn-danger:hover {
            background: linear-gradient(to right, #ff4b2b, #ff416c);
            transform: translateY(-2px);
            box-shadow: 0 5px 15px rgba(255, 65, 108, 0.4);
        }
        
        .btn-primary i, .btn-secondary i, .btn-warning i, .btn-danger i {
            margin-right: 5px;
            font-size: 12px;
        }
        
        .error-message {
            color: #fff;
            background: linear-gradient(to right, #ff416c, #ff4b2b);
            padding: 15px 20px;
            border-radius: 8px;
            margin: 20px auto;
            max-width: 800px;
            box-shadow: 0 4px 8px rgba(255, 65, 108, 0.2);
            font-weight: 500;
            display: flex;
            align-items: center;
        }
        
        .error-message i {
            margin-right: 10px;
            font-size: 20px;
        }
        
        /* 댓글 스타일 */
        .comments-section {
            margin-top: 25px;
            padding-top: 20px;
            border-top: 1px solid #e6eaf0;
            background: linear-gradient(to bottom, #f9f9f9, #ffffff);
            border-radius: 12px;
            padding: 20px;
        }
        
        .comments-title {
            font-size: 15px;
            font-weight: 700;
            margin-bottom: 15px;
            display: flex;
            align-items: center;
            color: #333;
        }
        
        .comments-title i {
            margin-right: 8px;
            color: #5b86e5;
        }
        
        .comment-count {
            display: inline-block;
            background: linear-gradient(to right, rgba(54, 209, 220, 0.2), rgba(91, 134, 229, 0.2));
            color: #5b86e5;
            padding: 3px 12px;
            border-radius: 20px;
            font-size: 12px;
            font-weight: 500;
            margin-left: 8px;
        }
        
        .comments-container {
            margin-bottom: 20px;
        }
        
        .comment-item {
            padding: 12px 15px;
            border-radius: 12px;
            margin-bottom: 10px;
            background: linear-gradient(to right, #f8fafc, #ffffff);
            border: 1px solid #eaeef2;
            transition: all 0.3s ease;
            display: flex;
            flex-direction: column;
            box-shadow: 0 2px 5px rgba(0, 0, 0, 0.02);
        }
        
        .comment-item:hover {
            background: linear-gradient(to right, #f1f7fa, #ffffff);
            transform: translateY(-2px);
            box-shadow: 0 5px 15px rgba(91, 134, 229, 0.08);
        }
        
        .comment-header {
            display: flex;
            flex-direction: row;
            align-items: center;
            justify-content: flex-start;
            font-size: 14px;
            color: #6c757d;
            margin-bottom: 5px;
            border-bottom: 1px dashed #eaeef2;
            padding-bottom: 5px;
        }
        
        .comment-author {
            font-weight: 600;
            color: #333;
            display: flex;
            align-items: center;
            white-space: nowrap;
            overflow: hidden;
            text-overflow: ellipsis;
            max-width: 150px;
            margin-right: 15px;
        }
        
        .comment-author i {
            margin-right: 5px;
            color: #0078ff;
            font-size: 14px;
        }
        
        .comment-date {
            font-size: 14px;
            color: #8995a2;
            white-space: nowrap;
        }
        
        .comment-content {
            font-size: 14px;
            color: #333;
            white-space: normal;
            word-break: break-word;
            line-height: 1.5;
            width: 100%;
            padding-top: 5px;
        }
        
        .comment-form {
            margin-top: 10px;
            display: flex;
            align-items: flex-start;
            gap: 8px;
        }
        
        .comment-textarea {
            flex: 1;
            padding: 10px 15px;
            border: 1px solid #dce1e6;
            border-radius: 20px;
            min-height: 36px;
            max-height: 80px;
            resize: none;
            margin-bottom: 0;
            font-family: 'Noto Sans KR', sans-serif;
            font-size: 14px;
            box-sizing: border-box;
            background-color: #fff;
            transition: all 0.3s ease;
            box-shadow: 0 1px 3px rgba(0,0,0,0.05);
        }
        
        .comment-textarea:focus {
            border-color: #36d1dc;
            box-shadow: 0 0 0 3px rgba(54, 209, 220, 0.2);
            outline: none;
        }
        
        .no-comments {
            padding: 20px;
            text-align: center;
            color: #8995a2;
            font-size: 15px;
            background: #f8fafc;
            border-radius: 8px;
            border: 1px dashed #e6eaf0;
        }
        
        .no-comments i {
            font-size: 24px;
            margin-bottom: 10px;
            color: #8995a2;
            display: block;
        }
        
        /* 테이블 스타일 조정 - 숫자 오른쪽 정렬, 나머지 중앙 정렬 */
        table th, table td {
            text-align: center;
        }
        
        table td.number {
            text-align: right;
        }
        
        .back-link {
            font-size: 14px;
            color: white;
            text-decoration: none;
            display: inline-flex;
            align-items: center;
        }
        
        .back-link i {
            margin-right: 6px;
        }
        
        .back-link:hover {
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <div class="memo-container">
        <?php if (isset($error_message)): ?>
        <div class="error-message">
            <i class="fas fa-exclamation-circle"></i> <?php echo $error_message; ?>
        </div>
        <?php endif; ?>
        
        <div class="memo-card">
            <div class="memo-header">
                <h1>
                    <?php if ($mode === 'view'): ?>
                        <i class="fas fa-file-alt"></i> 메모 상세보기
                    <?php elseif ($mode === '수정'): ?>
                        <i class="fas fa-edit"></i> 메모 수정
                    <?php else: ?>
                        <i class="fas fa-plus-circle"></i> 새 메모 작성
                    <?php endif; ?>
                    <span class="member-info">
                        <i class="fas fa-user"></i> <?php echo htmlspecialchars($member['member_name']); ?> 회원
                    </span>
                </h1>
            </div>
            
            <div class="memo-body">
                <?php if ($mode === 'view' && $post): ?>
                <div class="memo-meta">
                    <div class="memo-meta-item">
                        <i class="fas fa-user-edit"></i> 작성자: <?php echo htmlspecialchars($post['staff_name']); ?> (<?php echo htmlspecialchars($post['staff_type']); ?>)
                    </div>
                    <div class="memo-meta-item">
                        <i class="fas fa-calendar-alt"></i> 작성일: <?php echo date('Y-m-d H:i', strtotime($post['created_at'])); ?>
                    </div>
                    <?php if ($post['updated_at'] !== $post['created_at']): ?>
                    <div class="memo-meta-item">
                        <i class="fas fa-history"></i> 수정일: <?php echo date('Y-m-d H:i', strtotime($post['updated_at'])); ?>
                    </div>
                    <?php endif; ?>
                </div>
                <?php endif; ?>
                
                <form method="post" action="">
                    <?php if ($mode !== 'view'): ?>
                    <div class="memo-section">
                        <div class="memo-section-title">
                            <i class="fas fa-pen"></i> 메모 내용 입력
                        </div>
                        <div class="form-group">
                            <label for="title">제목</label>
                            <input type="text" id="title" name="title" class="form-control" value="<?php echo isset($post['title']) ? htmlspecialchars($post['title']) : ''; ?>" required>
                        </div>
                        <div class="form-group">
                            <label for="content">내용</label>
                            <textarea id="content" name="content" class="form-control" required><?php echo isset($post['content']) ? htmlspecialchars($post['content']) : ''; ?></textarea>
                        </div>
                    </div>
                    <?php else: ?>
                    <div class="memo-section">
                        <div class="memo-section-title">
                            <i class="fas fa-file-alt"></i> <?php echo htmlspecialchars($post['title']); ?>
                        </div>
                        <div class="memo-view-content">
                            <?php echo nl2br(htmlspecialchars($post['content'])); ?>
                        </div>
                    </div>
                    <?php endif; ?>
                    
                    <?php if ($mode === 'view'): ?>
                    <div class="comments-section">
                        <div class="comments-title">
                            <i class="fas fa-comments"></i> 댓글
                            <span class="comment-count"><?php echo count($comments); ?></span>
                        </div>
                        <div class="comments-container">
                            <?php if (empty($comments)): ?>
                            <div class="no-comments">
                                <i class="fas fa-comment-slash"></i>
                                작성된 댓글이 없습니다.
                            </div>
                            <?php else: ?>
                                <?php foreach ($comments as $comment): ?>
                                <div class="comment-item">
                                    <div class="comment-header">
                                        <span class="comment-author">
                                            <i class="fas fa-user-circle"></i>
                                            <?php echo htmlspecialchars($comment['staff_name']); ?>
                                        </span>
                                        <span class="comment-date">
                                            <?php echo date('Y-m-d H:i', strtotime($comment['created_at'])); ?>
                                        </span>
                                    </div>
                                    <div class="comment-content">
                                        <?php echo nl2br(htmlspecialchars(isset($comment['comment_content']) ? $comment['comment_content'] : $comment['content'])); ?>
                                    </div>
                                </div>
                                <?php endforeach; ?>
                            <?php endif; ?>
                        </div>
                        
                        <div class="comment-form">
                            <textarea class="comment-textarea" id="comment" name="comment" placeholder="댓글을 입력하세요"></textarea>
                            <button type="button" class="btn-primary" onclick="submitComment(<?php echo $board_id; ?>)">
                                <i class="fas fa-paper-plane"></i> 댓글
                            </button>
                        </div>
                    </div>
                    <?php endif; ?>
                    
                    <div class="memo-actions">
                        <?php if ($mode === 'view' && isset($post['staff_id']) && $post['staff_id'] == $_SESSION['staff_id']): ?>
                            <a href="?member_id=<?php echo $member_id; ?>&board_id=<?php echo $board_id; ?>&mode=수정" class="btn-warning">
                                <i class="fas fa-edit"></i> 수정
                            </a>
                            <button type="button" class="btn-danger" onclick="confirmDelete(<?php echo $board_id; ?>)">
                                <i class="fas fa-trash-alt"></i> 삭제
                            </button>
                        <?php endif; ?>
                        
                        <?php if ($mode !== 'view'): ?>
                            <input type="hidden" name="save_memo" value="1">
                            <button type="submit" class="btn-primary">
                                <i class="fas fa-save"></i> <?php echo $mode === '수정' ? '저장' : '작성완료'; ?>
                            </button>
                        <?php endif; ?>
                        
                        <button type="button" class="btn-secondary" onclick="window.close()">
                            <i class="fas fa-times"></i> 닫기
                        </button>
                    </div>
                </form>
            </div>
        </div>
    </div>
    
    <script>
        function confirmDelete(boardId) {
            if (confirm('정말로 이 메모를 삭제하시겠습니까?')) {
                window.location.href = `memo_delete.php?board_id=${boardId}&member_id=<?php echo $member_id; ?>`;
            }
        }
        
        function submitComment(boardId) {
            const commentText = document.getElementById('comment').value.trim();
            if (!commentText) {
                alert('댓글 내용을 입력해주세요.');
                return;
            }
            
            const formData = new FormData();
            formData.append('board_id', boardId);
            formData.append('comment_content', commentText);
            formData.append('content', commentText);
            
            fetch('comment_add.php', {
                method: 'POST',
                body: formData
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    alert('댓글이 성공적으로 추가되었습니다.');
                    location.reload();
                } else {
                    alert('댓글 추가 실패: ' + (data.message || '알 수 없는 오류가 발생했습니다.'));
                }
            })
            .catch(error => {
                console.error('Error:', error);
                alert('댓글 추가 중 오류가 발생했습니다.');
            });
        }
    </script>
</body>
</html> 