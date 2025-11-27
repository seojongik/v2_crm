<?php
header('Content-Type: application/json; charset=utf-8');
require_once '../config/db_connect.php';
session_start();

// 로그인 확인
if (!isset($_SESSION['staff_id'])) {
    echo json_encode(['success' => false, 'message' => '로그인이 필요합니다.']);
    exit;
}

try {
    // 최근 상담기록 게시글 100개 조회
    $query = "
        SELECT b.board_id, b.title, b.content, 
               DATE_FORMAT(b.created_at, '%Y-%m-%d') as created_at,
               s.staff_name, b.member_id,
               (SELECT COUNT(*) FROM Comment WHERE board_id = b.board_id) as comment_count
        FROM Board b
        JOIN Staff s ON b.staff_id = s.staff_id
        WHERE b.board_type = '상담기록'
        ORDER BY b.created_at DESC
        LIMIT 100
    ";
    
    $result = $db->query($query);
    
    if (!$result) {
        throw new Exception('상담기록 조회 중 오류가 발생했습니다.');
    }
    
    $posts = [];
    $board_ids = [];
    
    while ($row = $result->fetch_assoc()) {
        // board_id를 배열에 추가 (댓글 조회를 위해)
        $board_ids[] = $row['board_id'];
        
        // member_id가 유효한지 검사 (NULL 아님, 빈 문자열 아님, 0 아님)
        $member_id_value = $row['member_id'];
        $is_registered = !is_null($member_id_value) && $member_id_value !== '' && 
                        (is_numeric($member_id_value) && intval($member_id_value) > 0);
        
        $posts[] = [
            'board_id' => $row['board_id'],
            'title' => htmlspecialchars($row['title']),
            'content' => htmlspecialchars(substr($row['content'], 0, 200)) . (strlen($row['content']) > 200 ? '...' : ''),
            'created_at' => $row['created_at'],
            'staff_name' => htmlspecialchars($row['staff_name']),
            'is_registered' => $is_registered,
            'member_id' => $member_id_value,
            'comment_count' => (int)$row['comment_count'],
            'comments' => [] // 댓글 배열 초기화
        ];
    }
    
    // 댓글 정보 조회 (간략하게)
    if (!empty($board_ids)) {
        $board_ids_str = implode(',', $board_ids);
        $comments_query = "
            SELECT c.comment_id, c.board_id, c.content, 
                   DATE_FORMAT(c.created_at, '%m-%d %H:%i') as created_at,
                   s.staff_name
            FROM Comment c
            JOIN Staff s ON c.staff_id = s.staff_id
            WHERE c.board_id IN ($board_ids_str)
            ORDER BY c.created_at ASC
        ";
        
        $comments_result = $db->query($comments_query);
        
        if ($comments_result) {
            // 게시글 ID를 키로 하는 맵 생성
            $posts_map = [];
            foreach ($posts as $index => $post) {
                $posts_map[$post['board_id']] = $index;
            }
            
            // 댓글 정보를 해당 게시글에 추가
            while ($comment = $comments_result->fetch_assoc()) {
                $board_id = $comment['board_id'];
                if (isset($posts_map[$board_id])) {
                    $post_index = $posts_map[$board_id];
                    $posts[$post_index]['comments'][] = [
                        'content' => htmlspecialchars($comment['content']),
                        'created_at' => $comment['created_at'],
                        'staff_name' => htmlspecialchars($comment['staff_name'])
                    ];
                }
            }
        }
    }
    
    echo json_encode([
        'success' => true,
        'posts' => $posts
    ]);
    
} catch (Exception $e) {
    echo json_encode(['success' => false, 'message' => $e->getMessage()]);
}
?> 