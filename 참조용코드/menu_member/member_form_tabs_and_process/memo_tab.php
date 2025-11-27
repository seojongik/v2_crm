<?php
// 메모 탭 컨텐츠 - member_form.php에서 불러와서 사용
// DB 연결 필요 없음 (member_form.php에서 이미 연결됨)

// 단독 실행을 위한 데이터베이스 연결
if (!isset($db)) {
    require_once dirname(__FILE__) . '/../../config/db_connect.php';
}

// 현재 페이지가 member_form.php인지 여부 확인
$is_in_member_form = basename($_SERVER['PHP_SELF']) === 'member_form.php' || 
                     strpos($_SERVER['REQUEST_URI'], 'member_form.php') !== false ||
                     isset($in_parent_page);

// 기본 경로 설정
$base_path = $is_in_member_form ? '' : '../';

// member_id가 GET으로 전달됐는지 확인
if (!isset($_GET['id']) && !isset($member_id)) {
    echo '<div class="error-message">회원 ID가 전달되지 않았습니다.</div>';
    exit;
}

// member_id 설정 (포함된 경우 $member_id 변수 사용, 직접 접근 시 GET 파라미터 사용)
$member_id = isset($member_id) ? $member_id : intval($_GET['id']);

// 현재 로그인한 직원 정보 가져오기
$staff_info = array('staff_name' => '로그인 필요');
if (isset($_SESSION['staff_id'])) {
    $staff_id = $_SESSION['staff_id'];
    $staff_query = "SELECT staff_id, staff_name FROM Staff WHERE staff_id = ?";
    $staff_stmt = $db->prepare($staff_query);
    $staff_stmt->bind_param('i', $staff_id);
    $staff_stmt->execute();
    $staff_result = $staff_stmt->get_result();
    if ($staff_result->num_rows > 0) {
        $staff_info = $staff_result->fetch_assoc();
    }
}

// 회원 정보 조회
try {
    $stmt = $db->prepare("SELECT member_id, member_name FROM members WHERE member_id = ?");
    $stmt->bind_param('i', $member_id);
    $stmt->execute();
    $result = $stmt->get_result();

    if ($result->num_rows === 0) {
        echo '<div class="error-message">회원 정보를 찾을 수 없습니다.</div>';
        exit;
    }

    $member = $result->fetch_assoc();
    
    // 해당 회원의 Board 테이블 글 목록 조회
    $board_query = "
        SELECT b.*, s.staff_name, s.staff_type,
               (SELECT COUNT(*) FROM Comment WHERE board_id = b.board_id) AS comment_count
        FROM Board b
        JOIN Staff s ON b.staff_id = s.staff_id
        WHERE b.member_id = ?
        ORDER BY b.created_at DESC
    ";
    
    $stmt = $db->prepare($board_query);
    $stmt->bind_param('i', $member_id);
    $stmt->execute();
    $board_posts = $stmt->get_result();
    
} catch (Exception $e) {
    echo "<div style='color:red;'>조회 오류: " . $e->getMessage() . "</div>";
    exit;
}
?>

<div id="memo-area" class="memo-module card">
    <div class="memo-header card-header">
        <h3 class="member-name">
            <i class="fa fa-user-circle"></i> 
            <?php echo htmlspecialchars($member['member_name']); ?> 회원 메모
            <span class="record-count badge"><?php echo $board_posts->num_rows; ?>개</span>
        </h3>
        <button type="button" class="memo-btn memo-btn-primary" id="writeNewMemoBtn">
            <i class="fa fa-plus"></i> 새 메모 작성
        </button>
    </div>
    
    <div class="memo-card-body">
        <?php if ($board_posts->num_rows === 0): ?>
            <div class="memo-empty-state">
                <div class="memo-empty-icon">
                    <i class="fa fa-file-text-o"></i>
                </div>
                <p>등록된 메모나 게시글이 없습니다.</p>
                <button type="button" class="memo-btn memo-btn-outline" id="emptyStateWriteBtn">
                    첫 메모 작성하기
                </button>
            </div>
        <?php else: ?>
            <div class="memo-board-list">
                <table class="memo-board-table">
                    <thead>
                        <tr>
                            <th class="memo-col-id text-center">번호</th>
                            <th class="memo-col-date text-center">작성일</th>
                            <th class="memo-col-author text-center">작성자</th>
                            <th class="memo-col-title text-center">제목</th>
                            <th class="memo-col-content text-center">내용</th>
                        </tr>
                    </thead>
                    <tbody>
                        <?php while ($post = $board_posts->fetch_assoc()): ?>
                        <tr class="memo-board-row" data-id="<?php echo $post['board_id']; ?>">
                            <td class="memo-col-id text-center"><?php echo $post['board_id']; ?></td>
                            <td class="memo-col-date text-center"><?php echo date('Y-m-d', strtotime($post['created_at'])); ?></td>
                            <td class="memo-col-author text-center"><?php echo htmlspecialchars($post['staff_name']); ?></td>
                            <td class="memo-col-title text-center">
                                <a href="../menu_board/board_view.php?id=<?php echo $post['board_id']; ?>" class="memo-title-link">
                                    <?php echo htmlspecialchars($post['title']); ?>
                                    <?php if(isset($post['comment_count'])): ?>
                                        <span class="comment-count-indicator">(<?php echo $post['comment_count'] > 0 ? $post['comment_count'] : '-'; ?>)</span>
                                    <?php endif; ?>
                                </a>
                            </td>
                            <td class="memo-col-content">
                                <div class="memo-content-full">
                                    <?php echo nl2br(htmlspecialchars($post['content'])); ?>
                                </div>
                            </td>
                        </tr>
                        <?php endwhile; ?>
                    </tbody>
                </table>
            </div>
        <?php endif; ?>
    </div>
</div>

<style>
/* memo-module 클래스로 스타일 독립성 유지 */
.memo-module {
    font-family: 'Noto Sans KR', sans-serif !important;
    color: #333 !important;
}

/* 카드 스타일 */
.memo-module.card {
    background: #fff !important;
    border-radius: 16px !important;
    box-shadow: 0 10px 30px rgba(0, 0, 0, 0.08) !important;
    overflow: hidden !important;
    margin-bottom: 20px !important;
    transition: all 0.3s ease !important;
}

.memo-module.card:hover {
    transform: translateY(-5px) !important;
    box-shadow: 0 15px 40px rgba(91, 134, 229, 0.15) !important;
}

.memo-module .card-header {
    background: #ffffff !important;
    padding: 18px 25px !important;
    border-bottom: 1px solid #eaeef2 !important;
    color: #333 !important;
}

.memo-module .memo-card-body {
    padding: 25px !important;
    min-height: 300px !important;
}

/* 헤더 스타일 */
.memo-module .memo-header {
    display: flex !important;
    justify-content: space-between !important;
    align-items: center !important;
}

.memo-module .member-name {
    font-size: 18px !important;
    margin: 0 !important;
    font-weight: 600 !important;
    color: #333 !important;
    display: flex !important;
    align-items: center !important;
    gap: 8px !important;
}

.memo-module .record-count {
    display: inline-block !important;
    background: linear-gradient(to right, #36d1dc, #5b86e5) !important;
    color: white !important;
    padding: 4px 12px !important;
    border-radius: 30px !important;
    font-size: 12px !important;
    font-weight: 500 !important;
    margin-left: 12px !important;
    box-shadow: 0 2px 5px rgba(0, 0, 0, 0.1) !important;
}

/* 버튼 스타일 */
.memo-module .memo-btn {
    display: inline-flex !important;
    align-items: center !important;
    justify-content: center !important;
    padding: 8px 16px !important;
    border-radius: 50px !important;
    cursor: pointer !important;
    font-size: 14px !important;
    font-weight: 700 !important;
    text-decoration: none !important;
    text-align: center !important;
    border: none !important;
    transition: all 0.3s ease !important;
    box-shadow: 0 3px 6px rgba(0,0,0,0.1) !important;
    gap: 6px !important;
}

.memo-module .memo-btn-primary {
    background: linear-gradient(to right, #36d1dc, #5b86e5) !important;
    color: white !important;
}

.memo-module .memo-btn-primary:hover {
    background: linear-gradient(to right, #5b86e5, #36d1dc) !important;
    transform: translateY(-2px) !important;
    box-shadow: 0 5px 15px rgba(91, 134, 229, 0.4) !important;
}

.memo-module .memo-btn-outline {
    background: linear-gradient(to right, #a1c4fd, #c2e9fb) !important;
    color: #2c3e50 !important;
    border: none !important;
}

.memo-module .memo-btn-outline:hover {
    background: linear-gradient(to right, #c2e9fb, #a1c4fd) !important;
    transform: translateY(-2px) !important;
    box-shadow: 0 5px 15px rgba(161, 196, 253, 0.4) !important;
}

/* 테이블 스타일 */
.memo-module .memo-board-table {
    width: 100% !important;
    border-collapse: separate !important;
    border-spacing: 0 !important;
    margin: 0 !important;
    font-family: 'Noto Sans KR', 'Malgun Gothic', sans-serif !important;
    font-size: 14px !important;
}

.memo-module .memo-board-table th,
.memo-module .memo-board-table td {
    padding: 12px !important;
    text-align: left !important;
    border-bottom: 1px solid #e9ecef !important;
}

.memo-module .memo-board-table th {
    background: #f8f9fa !important;
    color: #495057 !important;
    font-weight: 600 !important;
    font-size: 14px !important;
    white-space: nowrap !important;
}

.memo-module .memo-board-row {
    transition: background 0.2s !important;
}

.memo-module .memo-board-row:hover {
    background: #f8f9fa !important;
}

/* 열 너비 조정 */
.memo-module .memo-col-id { width: 5% !important; text-align: center !important; }
.memo-module .memo-col-date { width: 10% !important; text-align: center !important; }
.memo-module .memo-col-author { width: 10% !important; text-align: center !important; }
.memo-module .memo-col-title { width: 25% !important; }
.memo-module .memo-col-content { width: 50% !important; }

/* 타입 배지 */
.memo-module .memo-type-badge {
    display: inline-block !important;
    padding: 5px 12px !important;
    border-radius: 30px !important;
    font-size: 12px !important;
    font-weight: 600 !important;
    color: white !important;
    text-align: center !important;
    box-shadow: 0 2px 5px rgba(0, 0, 0, 0.1) !important;
    transition: all 0.3s ease !important;
}

.memo-module .memo-type-badge:hover {
    transform: translateY(-2px) !important;
    box-shadow: 0 5px 15px rgba(0, 0, 0, 0.1) !important;
}

.memo-module .memo-type-일반 {
    background: linear-gradient(to right, #6c757d, #495057) !important;
}

.memo-module .memo-type-회원요청 {
    background: linear-gradient(to right, #28a745, #20c997) !important;
}

.memo-module .memo-type-상담기록 {
    background: linear-gradient(to right, #36d1dc, #5b86e5) !important;
}

.memo-module .memo-type-이벤트기획 {
    background: linear-gradient(to right, #fd7e14, #ff9a44) !important;
}

.memo-module .memo-type-기기문제 {
    background: linear-gradient(to right, #dc3545, #ff416c) !important;
}

.memo-module .memo-type-업무메뉴얼 {
    background: linear-gradient(to right, #6f42c1, #8e44ad) !important;
}

/* 제목 링크 */
.memo-module .memo-title-link {
    color: #212529 !important;
    text-decoration: none !important;
    font-weight: 500 !important;
    display: block !important;
    max-width: 100% !important;
    overflow: hidden !important;
    text-overflow: ellipsis !important;
    white-space: nowrap !important;
    cursor: pointer !important;
}

.memo-module .memo-title-link:hover {
    color: #007bff !important;
    text-decoration: underline !important;
}

/* 내용 미리보기를 전체 내용 표시로 변경 */
.memo-module .memo-content-full {
    color: #333 !important; /* 텍스트 색상을 더 진하게 조정 */
    font-size: 14px !important; /* 내용 폰트 크기를 제목과 동일하게 조정 */
    line-height: 1.6 !important;
    white-space: pre-line !important; /* pre-line으로 변경하여 연속 공백은 하나로 처리하되 줄바꿈은 유지 */
    word-break: break-word !important; /* 긴 단어 줄바꿈 */
    overflow: visible !important; /* 내용이 넘쳐도 표시 */
}

/* 미리보기 스타일 제거하거나 수정 */
.memo-module .memo-content-preview {
    display: none !important; /* 기존 미리보기 스타일 숨김 */
}

/* 빈 상태 */
.memo-module .memo-empty-state {
    display: flex !important;
    flex-direction: column !important;
    align-items: center !important;
    justify-content: center !important;
    padding: 40px 20px !important;
    text-align: center !important;
    color: #6c757d !important;
}

.memo-module .memo-empty-icon {
    font-size: 48px !important;
    margin-bottom: 16px !important;
    color: #dee2e6 !important;
}

.memo-module .memo-empty-state p {
    margin-bottom: 24px !important;
    font-size: 16px !important;
}

/* 게시글 보기 모달 */
.memo-module .view-modal {
    display: none !important;
    position: fixed !important;
    top: 0 !important;
    left: 0 !important;
    width: 100% !important;
    height: 100% !important;
    background: rgba(0,0,0,0.5) !important;
    z-index: 1000 !important;
    overflow-y: auto !important;
    justify-content: center !important;
    align-items: center !important;
    padding-top: 0 !important;
}

.memo-module .view-modal-content {
    position: relative !important;
    background: #fff !important;
    margin: 0 auto !important;
    padding: 0 !important;
    width: 800px !important;
    max-width: 90% !important;
    border-radius: 8px !important;
    box-shadow: 0 4px 20px rgba(0,0,0,0.15) !important;
    overflow: hidden !important;
    max-height: 90vh !important;
    overflow-y: auto !important;
}

.memo-module .view-modal-header {
    background: #f8f9fa !important;
    padding: 15px 20px !important;
    border-bottom: 1px solid #dee2e6 !important;
    display: flex !important;
    justify-content: space-between !important;
    align-items: center !important;
}

.memo-module .view-modal-title {
    margin: 0 !important;
    font-size: 20px !important;
    font-weight: 600 !important;
    color: #333 !important;
}

.memo-module .view-modal-close {
    font-size: 24px !important;
    cursor: pointer !important;
    color: #6c757d !important;
}

.memo-module .view-modal-info {
    background: #f8f9fa !important;
    padding: 12px 20px !important;
    border-bottom: 1px solid #dee2e6 !important;
    font-size: 13px !important;
    color: #6c757d !important;
    display: flex !important;
    flex-wrap: wrap !important;
    gap: 12px !important;
}

.memo-module .view-modal-info-item {
    display: flex !important;
    align-items: center !important;
    gap: 5px !important;
}

.memo-module .view-modal-body {
    padding: 20px !important;
}

.memo-module .view-modal-content-area {
    padding: 15px !important;
    min-height: 200px !important;
    line-height: 1.6 !important;
    border: 1px solid #e9ecef !important;
    border-radius: 4px !important;
    background: #fff !important;
    white-space: pre-wrap !important;
    font-family: 'Noto Sans KR', 'Malgun Gothic', sans-serif !important;
}

.memo-module .view-modal-actions {
    display: flex !important;
    justify-content: space-between !important;
    padding: 15px 20px !important;
    border-top: 1px solid #dee2e6 !important;
}

.memo-module .modal-action-left {
    display: flex !important;
    gap: 10px !important;
}

.memo-module .modal-action-right {
    display: flex !important;
    gap: 10px !important;
}

/* Google Noto Sans KR 폰트 추가 */
@import url('https://fonts.googleapis.com/css2?family=Noto+Sans+KR:wght@400;500;700&display=swap');

/* 반응형 */
@media (max-width: 768px) {
    .memo-module .memo-col-content {
        display: none !important;
    }
    
    .memo-module .memo-col-date, .memo-module .memo-col-author {
        display: none !important;
    }
}

/* 댓글 스타일 */
.memo-module .view-modal-comments-section {
    margin-top: 30px !important;
    border-top: 1px solid #dee2e6 !important;
    padding-top: 20px !important;
}

.memo-module .comments-title {
    font-size: 16px !important;
    font-weight: 600 !important;
    margin-bottom: 15px !important;
    color: #495057 !important;
    display: flex !important;
    align-items: center !important;
    gap: 8px !important;
}

.memo-module .comment-count-badge {
    display: inline-block !important;
    background: #6c757d !important;
    color: white !important;
    padding: 2px 8px !important;
    border-radius: 12px !important;
    font-size: 12px !important;
    font-weight: normal !important;
}

.memo-module .comments-container {
    margin-bottom: 20px !important;
}

.memo-module .comment-item {
    padding: 12px 15px !important;
    border: 1px solid #e9ecef !important;
    border-radius: 4px !important;
    margin-bottom: 10px !important;
    background: #f8f9fa !important;
}

.memo-module .comment-header {
    display: flex !important;
    justify-content: space-between !important;
    margin-bottom: 8px !important;
    font-size: 13px !important;
    color: #6c757d !important;
}

.memo-module .comment-author {
    font-weight: 500 !important;
    color: #495057 !important;
}

.memo-module .comment-content {
    font-size: 14px !important;
    line-height: 1.5 !important;
    color: #212529 !important;
    white-space: pre-wrap !important;
}

.memo-module .no-comments {
    color: #6c757d !important;
    font-style: italic !important;
    text-align: center !important;
    padding: 15px !important;
}

/* 댓글 작성 폼 */
.memo-module .comment-form-container {
    margin-top: 15px !important;
}

.memo-module .comment-textarea {
    width: 100% !important;
    padding: 10px !important;
    border: 1px solid #ddd !important;
    border-radius: 4px !important;
    resize: vertical !important;
    min-height: 80px !important;
    margin-bottom: 10px !important;
    font-family: 'Noto Sans KR', 'Malgun Gothic', sans-serif !important;
}

.memo-module .comment-submit {
    background: linear-gradient(to right, #36d1dc, #5b86e5) !important;
    color: white !important;
    border-radius: 50px !important;
    padding: 8px 16px !important;
    font-weight: 700 !important;
    transition: all 0.3s ease !important;
    box-shadow: 0 3px 6px rgba(0,0,0,0.1) !important;
}

.memo-module .comment-submit:hover {
    background: linear-gradient(to right, #5b86e5, #36d1dc) !important;
    transform: translateY(-2px) !important;
    box-shadow: 0 5px 15px rgba(91, 134, 229, 0.4) !important;
}

/* 버튼 스타일 */
.memo-module .btn-edit {
    background: linear-gradient(to right, #ffd86f, #fc6076) !important;
    color: white !important;
}

.memo-module .btn-edit:hover {
    background: linear-gradient(to right, #fc6076, #ffd86f) !important;
    transform: translateY(-2px) !important;
    box-shadow: 0 5px 15px rgba(252, 96, 118, 0.4) !important;
}

.memo-module .btn-delete {
    background: linear-gradient(to right, #ff416c, #ff4b2b) !important;
    color: white !important;
}

.memo-module .btn-delete:hover {
    background: linear-gradient(to right, #ff4b2b, #ff416c) !important;
    transform: translateY(-2px) !important;
    box-shadow: 0 5px 15px rgba(255, 65, 108, 0.4) !important;
}

.memo-module .btn-list {
    background: linear-gradient(to right, #a1c4fd, #c2e9fb) !important;
    color: #2c3e50 !important;
}

.memo-module .btn-list:hover {
    background: linear-gradient(to right, #c2e9fb, #a1c4fd) !important;
    transform: translateY(-2px) !important;
    box-shadow: 0 5px 15px rgba(161, 196, 253, 0.4) !important;
}

/* 텍스트 정렬 클래스 추가 */
.memo-module .text-center {
    text-align: center !important;
}

/* 댓글 개수 표시 스타일 */
.memo-module .comment-count-indicator {
    display: inline-block !important;
    margin-left: 5px !important;
    color: #5b86e5 !important;
    font-weight: normal !important;
    font-size: 13px !important;
}
</style>

<!-- 게시글 보기 모달 -->
<div id="viewPostModal" class="memo-module view-modal" style="display: none;">
    <div class="view-modal-content">
        <div class="view-modal-header">
            <h3 class="view-modal-title" id="viewPostTitle">게시글 제목</h3>
            <span class="view-modal-close" onclick="closeViewModal()">&times;</span>
        </div>
        <div class="view-modal-info">
            <div class="view-modal-info-item">
                <i class="fa fa-tag"></i>
                <span id="viewPostType">게시판 유형</span>
            </div>
            <div class="view-modal-info-item">
                <i class="fa fa-user"></i>
                <span id="viewPostAuthor">작성자</span>
            </div>
            <div class="view-modal-info-item">
                <i class="fa fa-calendar"></i>
                <span id="viewPostDate">작성일</span>
            </div>
            <div class="view-modal-info-item" id="viewPostMemberInfo" style="display:none;">
                <i class="fa fa-user-circle"></i>
                <span id="viewPostMember">회원명</span>
            </div>
        </div>
        <div class="view-modal-body">
            <div class="view-modal-content-area" id="viewPostContent">
                게시글 내용이 여기에 표시됩니다.
            </div>
            
            <!-- 댓글 섹션 -->
            <div class="view-modal-comments-section">
                <h4 class="comments-title">
                    <i class="fa fa-comments"></i> 댓글 
                    <span id="commentCount" class="comment-count-badge">0</span>
                </h4>
                <div id="commentsContainer" class="comments-container">
                    <!-- 댓글이 여기에 동적으로 추가됩니다 -->
                </div>
                
                <!-- 댓글 작성 폼 -->
                <div class="comment-form-container">
                    <textarea id="commentText" placeholder="댓글을 입력하세요" class="comment-textarea"></textarea>
                    <button type="button" class="memo-btn comment-submit" onclick="submitComment()">댓글 작성</button>
                </div>
            </div>
        </div>
        <div class="view-modal-actions">
            <div class="modal-action-left">
                <!-- 목록 버튼 제거 -->
            </div>
            <div class="modal-action-right">
                <button type="button" class="memo-btn memo-btn-edit" id="editPostBtn" onclick="editPost()"><i class="fa fa-pencil"></i> 수정</button>
                <button type="button" class="memo-btn memo-btn-delete" id="deletePostBtn" onclick="deletePost()"><i class="fa fa-trash"></i> 삭제</button>
                <button type="button" class="memo-btn" onclick="closeViewModal()">닫기</button>
            </div>
        </div>
    </div>
</div>

<!-- 메모 작성 모달 -->
<div id="writePostModal" class="memo-module view-modal" style="display: none;">
    <div class="view-modal-content">
        <div class="view-modal-header">
            <h3 class="view-modal-title">새 메모 작성</h3>
            <span class="view-modal-close" onclick="closeWriteModal()">&times;</span>
        </div>
        <div class="view-modal-info">
            <div class="view-modal-info-item">
                <i class="fa fa-tag"></i>
                <span>회원요청</span>
            </div>
            <div class="view-modal-info-item">
                <i class="fa fa-user-circle"></i>
                <span><?php echo htmlspecialchars($member['member_name']); ?> 회원</span>
            </div>
        </div>
        <div class="view-modal-body">
            <form id="writePostForm">
                <div class="form-group" style="margin-bottom: 15px;">
                    <label for="postTitle" style="display: block; margin-bottom: 5px; font-weight: 500;">제목</label>
                    <input type="text" id="postTitle" name="title" class="form-control" placeholder="제목을 입력하세요" required style="width: 100%; padding: 8px; border: 1px solid #ddd; border-radius: 4px; font-family: 'Noto Sans KR', 'Malgun Gothic', sans-serif;">
                </div>
                <div class="form-group" style="margin-bottom: 15px;">
                    <label for="postContent" style="display: block; margin-bottom: 5px; font-weight: 500;">내용</label>
                    <textarea id="postContent" name="content" class="form-control" placeholder="내용을 입력하세요" required style="width: 100%; padding: 8px; min-height: 200px; border: 1px solid #ddd; border-radius: 4px; resize: vertical; font-family: 'Noto Sans KR', 'Malgun Gothic', sans-serif;"></textarea>
                </div>
                <input type="hidden" id="postMemberId" name="member_id" value="<?php echo $member_id; ?>">
                <input type="hidden" name="board_type" value="회원요청">
                <input type="hidden" name="staff_id" value="<?php echo isset($_SESSION['staff_id']) ? $_SESSION['staff_id'] : ''; ?>">
            </form>
        </div>
        <div class="view-modal-actions">
            <div class="modal-action-right">
                <button type="button" class="memo-btn memo-btn-primary" onclick="submitNewPost()"><i class="fa fa-check"></i> 저장하기</button>
                <button type="button" class="memo-btn" onclick="closeWriteModal()">취소</button>
            </div>
        </div>
    </div>
</div>

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

// PHP에서 설정한 경로 변수를 JavaScript 변수로 사용
const basePath = "<?php echo $base_path; ?>";

document.addEventListener('DOMContentLoaded', function() {
    // 새 메모 작성 버튼 클릭 시 동작
    const writeButton = document.getElementById('writeNewMemoBtn');
    const emptyStateWriteBtn = document.getElementById('emptyStateWriteBtn');
    
    // 현재 페이지의 경로를 확인하여 상대 경로 결정
    const isInMemberForm = window.location.pathname.includes('member_form.php');
    const clientBasePath = isInMemberForm ? '' : '../';
    
    const openWriteModal = function(e) {
        if (e) e.preventDefault();
        
        // 별도 창으로 열기
        const width = 800;
        const height = 600;
        const left = (window.screen.width - width) / 2;
        const top = (window.screen.height - height) / 2;
        
        const memberId = <?php echo $member_id; ?>;
        const url = `${basePath}member_form_tabs_and_process/memo_form.php?member_id=${memberId}`;
        
        window.open(url, 'MemoWriteWindow', `width=${width},height=${height},left=${left},top=${top},resizable=yes,scrollbars=yes,status=yes`);
    };
    
    if (writeButton) {
        writeButton.addEventListener('click', openWriteModal);
    }
    
    if (emptyStateWriteBtn) {
        emptyStateWriteBtn.addEventListener('click', openWriteModal);
    }
    
    // 행 클릭 시 게시글 모달 열기
    const rows = document.querySelectorAll('.memo-board-row');
    rows.forEach(row => {
        row.addEventListener('click', function(e) {
            // 이미 링크를 클릭한 경우는 처리하지 않음
            if (e.target.tagName === 'A' || e.target.closest('a')) {
                return; // 링크 클릭은 링크 자체의 이벤트 핸들러에서 처리
            }
            
            const boardId = this.getAttribute('data-id');
            openPostModal(boardId);
        });
    });
    
    // 제목 링크 클릭 처리 
    const titleLinks = document.querySelectorAll('.memo-title-link');
    titleLinks.forEach(link => {
        link.addEventListener('click', function(e) {
            e.preventDefault();
            
            // 제목 링크의 href 속성에서 basePath가 이미 적용되어 있는지 확인
            if (!this.getAttribute('href').startsWith(basePath) && 
                !this.getAttribute('href').startsWith('/') && 
                !this.getAttribute('href').includes('://')) {
                // 상대 경로에 basePath 적용
                this.setAttribute('href', basePath + this.getAttribute('href').replace(/^\.\.\//, ''));
            }
            
            const boardId = this.closest('.memo-board-row').getAttribute('data-id');
            openPostModal(boardId);
        });
    });

    // 모달 외부 클릭 시 모달 닫기
    const viewModal = document.getElementById('viewPostModal');
    if (viewModal) {
        viewModal.addEventListener('click', function(e) {
            if (e.target === this) {
                closeViewModal();
            }
        });
    }
    
    // member_form 내부에서 실행 중인지 확인
    if (isInMemberForm || document.getElementById('memberForm') !== null) {
        // 모달을 body에 직접 추가하기 위해 준비
        moveModalToBody();
    }
});

// 모달을 body로 이동시키는 함수
function moveModalToBody() {
    // 게시글 보기 모달 이동
    const viewModal = document.getElementById('viewPostModal');
    if (viewModal && viewModal.parentNode) {
        // 모달이 있고 부모 요소가 있으면 body로 이동
        document.body.appendChild(viewModal);
        
        // 스타일 추가/수정
        viewModal.style.position = 'fixed';
        viewModal.style.zIndex = '9999'; // 최상위 z-index로 설정
        viewModal.style.display = 'none'; // 초기에는 표시하지 않음
        viewModal.style.justifyContent = 'center';
        viewModal.style.alignItems = 'center';
        viewModal.style.top = '0';
        viewModal.style.left = '0';
        viewModal.style.width = '100%';
        viewModal.style.height = '100%';
        
        // 모달 컨텐츠의 스타일 설정
        const modalContent = viewModal.querySelector('.view-modal-content');
        if (modalContent) {
            modalContent.style.maxHeight = '80vh'; // 약간 줄여서 더 중앙에 오도록 함
            modalContent.style.margin = '0 auto';
            modalContent.style.overflowY = 'auto';
            modalContent.style.position = 'relative';
            modalContent.style.top = '50%';
            modalContent.style.transform = 'translateY(-50%)'; // 정확한 수직 중앙 정렬
        }
    }
    
    // 메모 작성 모달도 이동
    const writeModal = document.getElementById('writePostModal');
    if (writeModal && writeModal.parentNode) {
        document.body.appendChild(writeModal);
        
        // 스타일 추가/수정
        writeModal.style.position = 'fixed';
        writeModal.style.zIndex = '9999';
        writeModal.style.display = 'none';
        writeModal.style.justifyContent = 'center';
        writeModal.style.alignItems = 'center';
        writeModal.style.top = '0';
        writeModal.style.left = '0';
        writeModal.style.width = '100%';
        writeModal.style.height = '100%';
        
        // 모달 컨텐츠 스타일
        const writeModalContent = writeModal.querySelector('.view-modal-content');
        if (writeModalContent) {
            writeModalContent.style.maxHeight = '80vh';
            writeModalContent.style.margin = '0 auto';
            writeModalContent.style.overflowY = 'auto';
            writeModalContent.style.position = 'relative';
            writeModalContent.style.top = '50%';
            writeModalContent.style.transform = 'translateY(-50%)';
        }
    }
}

// 게시글 모달 열기
function openPostModal(boardId) {
    // 별도 창으로 열기
    const width = 800;
    const height = 600;
    const left = (window.screen.width - width) / 2;
    const top = (window.screen.height - height) / 2;
    
    const memberId = <?php echo $member_id; ?>;
    const url = `${basePath}member_form_tabs_and_process/memo_form.php?member_id=${memberId}&board_id=${boardId}&mode=view`;
    
    window.open(url, 'MemoViewWindow', `width=${width},height=${height},left=${left},top=${top},resizable=yes,scrollbars=yes,status=yes`);
}

// 게시글 모달 닫기
function closeViewModal() {
    const modal = document.getElementById('viewPostModal');
    modal.style.display = 'none';
    document.body.style.overflow = ''; // 전체 페이지 스크롤 복원
}

// 게시글 수정
function editPost() {
    const boardId = document.getElementById('viewPostModal').getAttribute('data-post-id');
    const memberId = <?php echo $member_id; ?>;
    
    // 별도 창으로 열기
    const width = 800;
    const height = 600;
    const left = (window.screen.width - width) / 2;
    const top = (window.screen.height - height) / 2;
    
    const url = `${basePath}member_form_tabs_and_process/memo_form.php?member_id=${memberId}&board_id=${boardId}`;
    
    window.open(url, 'MemoEditWindow', `width=${width},height=${height},left=${left},top=${top},resizable=yes,scrollbars=yes,status=yes`);
    
    // 모달 닫기
    closeViewModal();
}

// 게시글 삭제
function deletePost() {
    const boardId = document.getElementById('viewPostModal').getAttribute('data-post-id');
    
    if (confirm('정말 이 게시글을 삭제하시겠습니까?')) {
        fetch('../../menu_board/board_delete.php', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: `id=${boardId}`
        })
        .then(response => response.json())
        .then(data => {
            if (data.success) {
                alert('게시글이 삭제되었습니다.');
                closeViewModal();
                location.reload(); // 현재 페이지 새로고침
            } else {
                alert('삭제 실패: ' + (data.message || '알 수 없는 오류가 발생했습니다.'));
            }
        })
        .catch(error => {
            console.error('Error:', error);
            alert('게시글 삭제 중 오류가 발생했습니다.');
        });
    }
}

// 게시판 목록으로 이동
function goToList() {
    const boardType = document.getElementById('viewPostModal').getAttribute('data-board-type');
    window.location.href = `${basePath}board_list.php?type=${encodeURIComponent(boardType)}`;
}

// 댓글 작성
function submitComment() {
    const boardId = document.getElementById('viewPostModal').getAttribute('data-post-id');
    const content = document.getElementById('commentText').value.trim();
    
    if (!content) {
        alert('댓글 내용을 입력하세요.');
        return;
    }
    
    fetch('../../menu_board/comment_add.php', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: `board_id=${boardId}&content=${encodeURIComponent(content)}`
    })
    .then(response => response.json())
    .then(data => {
        if (data.success) {
            // 댓글 입력창 초기화
            document.getElementById('commentText').value = '';
            
            // 댓글 데이터 다시 불러오기
            fetch(`${basePath}menu_board/get_post_data.php?id=${boardId}`)
                .then(response => response.json())
                .then(postData => {
                    if (postData.success) {
                        renderComments(postData.comments);
                    }
                });
        } else {
            alert('댓글 작성 실패: ' + (data.message || '알 수 없는 오류가 발생했습니다.'));
        }
    })
    .catch(error => {
        console.error('Error:', error);
        alert('댓글 작성 중 오류가 발생했습니다.');
    });
}

// ESC 키로 모달 닫기
window.addEventListener('keydown', function(e) {
    if (e.key === 'Escape' && document.getElementById('viewPostModal').style.display === 'flex') {
        closeViewModal();
    }
});

// 댓글 렌더링
function renderComments(comments) {
    const container = document.getElementById('commentsContainer');
    const countBadge = document.getElementById('commentCount');
    
    container.innerHTML = '';
    countBadge.textContent = comments.length;
    
    if (comments.length === 0) {
        container.innerHTML = '<div class="no-comments">아직 댓글이 없습니다.</div>';
        return;
    }
    
    comments.forEach(comment => {
        const commentEl = document.createElement('div');
        commentEl.className = 'comment-item';
        
        commentEl.innerHTML = `
            <div class="comment-header">
                <span class="comment-author">${comment.staff_name}</span>
                <span class="comment-date">${comment.created_at}</span>
            </div>
            <div class="comment-content">${comment.content}</div>
        `;
        
        container.appendChild(commentEl);
    });
}

// 메모 작성 모달 닫기
function closeWriteModal() {
    // body에 직접 추가된 모달과 원래 위치의 모달 모두 찾기
    const modal = document.querySelector('body > #writePostModal') || document.getElementById('writePostModal');
    if (modal) {
        modal.style.display = 'none';
        document.body.style.overflow = ''; // 페이지 스크롤 복원
    }
}

// 새 메모 저장하기
function submitNewPost() {
    // 현재 열려있는 모달 폼 찾기 (body에 직접 추가된 경우와 원래 위치의 경우 모두 처리)
    const modal = document.querySelector('body > #writePostModal') || document.getElementById('writePostModal');
    if (!modal) {
        alert('모달을 찾을 수 없습니다.');
        return;
    }
    
    // 직접 입력 필드에서 값 가져오기
    const titleInput = modal.querySelector('#postTitle');
    const contentInput = modal.querySelector('#postContent');
    const memberIdInput = modal.querySelector('input[name="member_id"]');
    
    if (!titleInput || !contentInput) {
        alert('입력 필드를 찾을 수 없습니다.');
        return;
    }
    
    const title = titleInput.value.trim();
    const content = contentInput.value.trim();
    const memberId = memberIdInput ? memberIdInput.value : '';
    
    // 필수 입력값 확인
    if (!title || !content) {
        alert('제목과 내용을 모두 입력해주세요.');
        return;
    }
    
    // 전송할 데이터 객체 생성
    const formObject = {
        title: title,
        content: content,
        board_type: '회원요청',
        member_id: memberId
    };
    
    // staff_id가 있으면 추가
    const staffIdInput = modal.querySelector('input[name="staff_id"]');
    if (staffIdInput && staffIdInput.value) {
        formObject.staff_id = staffIdInput.value;
    }
    
    // 저장 버튼 비활성화 및 텍스트 변경
    const submitButton = modal.querySelector('.memo-btn-primary');
    if (!submitButton) {
        alert('저장 버튼을 찾을 수 없습니다.');
        return;
    }
    
    const originalText = submitButton.innerHTML;
    submitButton.innerHTML = '<i class="fa fa-spinner fa-spin"></i> 저장 중...';
    submitButton.disabled = true;
    
    // 서버로 데이터 전송
    fetch('../../menu_board/board_save.php', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify(formObject)
    })
    .then(response => response.json())
    .then(data => {
        if (data.success) {
            alert('메모가 성공적으로 저장되었습니다.');
            closeWriteModal();
            location.reload(); // 페이지 새로고침
        } else {
            alert('저장 실패: ' + (data.message || '알 수 없는 오류가 발생했습니다.'));
        }
    })
    .catch(error => {
        console.error('Error:', error);
        alert('메모 저장 중 오류가 발생했습니다.');
    })
    .finally(() => {
        // 버튼 상태 복원
        submitButton.innerHTML = originalText;
        submitButton.disabled = false;
    });
}

// ESC 키로 모달 닫기 (기존 코드 확장)
window.addEventListener('keydown', function(e) {
    if (e.key === 'Escape') {
        const viewModal = document.getElementById('viewPostModal');
        const writeModal = document.getElementById('writePostModal');
        
        if (viewModal.style.display === 'flex') {
            closeViewModal();
        }
        
        if (writeModal.style.display === 'flex') {
            closeWriteModal();
        }
    }
});
</script> 