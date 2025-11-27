<?php
// 메모 삭제 처리
require_once '../../config/db_connect.php';
session_start();

// 로그인 확인
if (!isset($_SESSION['staff_id'])) {
    echo '<script>alert("로그인이 필요합니다."); window.close();</script>';
    exit;
}

$staff_id = $_SESSION['staff_id'];

// GET 파라미터 확인
if (!isset($_GET['board_id']) || !isset($_GET['member_id'])) {
    echo '<script>alert("필수 파라미터가 누락되었습니다."); window.close();</script>';
    exit;
}

$board_id = intval($_GET['board_id']);
$member_id = intval($_GET['member_id']);

// 메모 존재 여부 및 권한 확인 (자신이 작성한 메모인지)
$check_query = "SELECT board_id FROM Board WHERE board_id = ? AND staff_id = ?";
$check_stmt = $db->prepare($check_query);
$check_stmt->bind_param('ii', $board_id, $staff_id);
$check_stmt->execute();
$check_result = $check_stmt->get_result();

if ($check_result->num_rows === 0) {
    echo '<script>alert("존재하지 않는 메모이거나 삭제 권한이 없습니다."); window.close();</script>';
    exit;
}

// 메모 삭제 - 관련 댓글도 함께 삭제 (CASCADE 처리가 되어있다면 불필요)
try {
    // 트랜잭션 시작
    $db->begin_transaction();
    
    // 댓글 삭제
    $delete_comments = "DELETE FROM Comment WHERE board_id = ?";
    $comment_stmt = $db->prepare($delete_comments);
    $comment_stmt->bind_param('i', $board_id);
    $comment_stmt->execute();
    
    // 메모 삭제
    $delete_memo = "DELETE FROM Board WHERE board_id = ? AND staff_id = ?";
    $memo_stmt = $db->prepare($delete_memo);
    $memo_stmt->bind_param('ii', $board_id, $staff_id);
    $memo_stmt->execute();
    
    // 트랜잭션 커밋
    $db->commit();
    
    // 성공 시 부모 창 새로고침 후 창 닫기
    echo '<script>
        alert("메모가 성공적으로 삭제되었습니다.");
        if (window.opener && !window.opener.closed) {
            window.opener.location.reload();
        }
        window.close();
    </script>';
} catch (Exception $e) {
    // 오류 발생 시 롤백
    $db->rollback();
    echo '<script>alert("메모 삭제 중 오류가 발생했습니다: ' . $e->getMessage() . '"); window.close();</script>';
} 