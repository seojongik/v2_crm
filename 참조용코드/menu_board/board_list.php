<?php
// 세션 유지 시간을 30분(1800초)으로 설정
ini_set('session.gc_maxlifetime', 1800); // 서버 측 세션 유지 시간
session_set_cookie_params(1800); // 클라이언트 측 세션 쿠키 유지 시간

session_start();

// header.php를 불러올 때 session_start 호출을 건너뛰도록 플래그 설정
define('SKIP_SESSION_START', true);
require_once '../common/header.php';
require_once '../config/db_connect.php';

$board_type = $_GET['type'] ?? '일반';

// 검색 조건 처리
$search = isset($_GET['search']) ? $_GET['search'] : '';
$where = 'WHERE b.board_type = ?';
$params = [$board_type];
$types = 's';

if ($search) {
    // 회원요청과 상담기록은 회원 정보도 검색
    if (in_array($board_type, ['회원요청', '상담기록'])) {
        $search = '%' . $search . '%';
        $where .= " AND (b.title LIKE ? OR b.content LIKE ? OR s.staff_name LIKE ? OR m.member_name LIKE ? OR m.member_phone LIKE ?)";
        $params = array_merge($params, [$search, $search, $search, $search, $search]);
        $types .= 'sssss';
    } else {
        $search = '%' . $search . '%';
        $where .= " AND (b.title LIKE ? OR b.content LIKE ? OR s.staff_name LIKE ?)";
        $params = array_merge($params, [$search, $search, $search]);
        $types .= 'sss';
    }
}

// 페이지네이션
$page = isset($_GET['page']) ? (int)$_GET['page'] : 1;
$limit = 10;
$offset = ($page - 1) * $limit;

// 게시글 총 개수
$count_query = "SELECT COUNT(*) as total FROM Board b JOIN Staff s ON b.staff_id = s.staff_id LEFT JOIN members m ON b.member_id = m.member_id " . $where;
$stmt = $db->prepare($count_query);
$stmt->bind_param($types, ...$params);
$stmt->execute();
$total_result = $stmt->get_result();
$total_row = $total_result->fetch_assoc();
$total_pages = ceil($total_row['total'] / $limit);

// 게시글 조회
$query = "
    SELECT b.*, s.staff_name, s.staff_type, m.member_name,
           b.content as full_content,
           (SELECT COUNT(*) FROM Comment WHERE board_id = b.board_id) as comment_count
    FROM Board b
    JOIN Staff s ON b.staff_id = s.staff_id
    LEFT JOIN members m ON b.member_id = m.member_id
    " . $where . "
    ORDER BY b.created_at DESC
    LIMIT ? OFFSET ?
";

$params = array_merge($params, [$limit, $offset]);
$types .= 'ii';
$stmt = $db->prepare($query);
$stmt->bind_param($types, ...$params);
$stmt->execute();
$result = $stmt->get_result();
?>

<div class="container">

    
    <!-- 게시판 유형 탭 추가 -->
    <div class="board-tabs">
        <a href="board_list.php?type=일반" class="board-tab <?php echo $board_type === '일반' ? 'active' : ''; ?>">일반</a>
        <a href="board_list.php?type=이벤트기획" class="board-tab <?php echo $board_type === '이벤트기획' ? 'active' : ''; ?>">이벤트기획</a>
        <a href="board_list.php?type=기기문제" class="board-tab <?php echo $board_type === '기기문제' ? 'active' : ''; ?>">기기문제</a>
        <a href="board_list.php?type=회원요청" class="board-tab <?php echo $board_type === '회원요청' ? 'active' : ''; ?>">회원요청</a>
        <a href="board_list.php?type=상담기록" class="board-tab <?php echo $board_type === '상담기록' ? 'active' : ''; ?>">상담기록</a>
        <a href="board_list.php?type=업무메뉴얼" class="board-tab <?php echo $board_type === '업무메뉴얼' ? 'active' : ''; ?>">업무메뉴얼</a>
    </div>

    <div class="board-actions">
        <div class="action-left">
            <a href="board_write.php?type=<?php echo urlencode($board_type); ?>" class="btn btn-primary">글쓰기</a>
            <?php if ($board_type === '상담기록'): ?>
            <button type="button" class="btn btn-primary" id="registerMemberBtn">회원등록</button>
            <?php endif; ?>
        </div>
        <div class="action-right">
            <form action="" method="GET" class="search-form">
                <input type="hidden" name="type" value="<?php echo htmlspecialchars($board_type); ?>">
                <?php if (in_array($board_type, ['회원요청', '상담기록'])): ?>
                <input type="text" name="search" placeholder="제목, 내용, 작성자, 회원명 검색" 
                       value="<?php echo htmlspecialchars($search); ?>" 
                       class="search-input">
                <?php else: ?>
                <input type="text" name="search" placeholder="제목, 내용, 작성자 검색" 
                       value="<?php echo htmlspecialchars($search); ?>" 
                       class="search-input">
                <?php endif; ?>
                <button type="submit" class="btn">검색</button>
            </form>
        </div>
    </div>
    
    <table class="board-table">
        <thead>
            <tr>
                <th style="width: 5%;">번호</th>
                <th style="width: 10%;">작성일</th>
                <th style="width: 8%;">작성자</th>
                <?php if (in_array($board_type, ['회원요청', '상담기록'])): ?>
                <th style="width: 8%;">회원명</th>
                <?php endif; ?>
                <th style="width: 69%;">제목 및 내용</th>
            </tr>
        </thead>
        <tbody>
            <?php while ($row = $result->fetch_assoc()): ?>
            <tr class="board-row" data-id="<?php echo $row['board_id']; ?>">
                <td class="text-center"><?php echo $row['board_id']; ?></td>
                <td class="text-center"><?php echo date('Y-m-d', strtotime($row['created_at'])); ?></td>
                <td class="text-center"><?php echo htmlspecialchars($row['staff_name']); ?></td>
                <?php if (in_array($board_type, ['회원요청', '상담기록'])): ?>
                <td class="text-center"><?php echo htmlspecialchars($row['member_name'] ?? ''); ?></td>
                <?php endif; ?>
                <td class="content-cell">
                    <div class="content-title">
                        <a href="#" class="title-link" data-id="<?php echo $row['board_id']; ?>">
                            <?php echo htmlspecialchars($row['title']); ?>
                        </a>
                    </div>
                    <div class="content-full"><?php echo nl2br(htmlspecialchars($row['full_content'])); ?></div>
                    <?php if ($row['comment_count'] > 0): ?>
                    <div class="post-comments">
                        <?php
                        // 댓글 가져오기
                        $comment_query = "SELECT c.content, s.staff_name, c.created_at 
                                         FROM Comment c 
                                         JOIN Staff s ON c.staff_id = s.staff_id 
                                         WHERE c.board_id = ? 
                                         ORDER BY c.created_at ASC";
                        $comment_stmt = $db->prepare($comment_query);
                        $comment_stmt->bind_param('i', $row['board_id']);
                        $comment_stmt->execute();
                        $comments_result = $comment_stmt->get_result();
                        
                        while ($comment = $comments_result->fetch_assoc()):
                        ?>
                        <div class="comment-line">
                            <i class="fas fa-comment comment-icon"></i>
                            <span class="comment-author"><?php echo htmlspecialchars($comment['staff_name']); ?></span>: 
                            <?php echo htmlspecialchars($comment['content']); ?>
                            <span class="comment-date">(<?php echo date('m-d H:i', strtotime($comment['created_at'])); ?>)</span>
                        </div>
                        <?php endwhile; ?>
                    </div>
                    <?php endif; ?>
                </td>
            </tr>
            <?php endwhile; ?>
        </tbody>
    </table>
    
    <!-- 페이지네이션 -->
    <div class="pagination">
        <?php
        $start_page = max(1, $page - 5);
        $end_page = min($total_pages, $page + 5);
        
        // 첫 페이지가 1이 아닌 경우
        if ($start_page > 1) {
            echo '<a href="?type=' . urlencode($board_type) . '&page=1' . ($search ? '&search='.urlencode($search) : '') . '">1</a>';
            if ($start_page > 2) {
                echo '<span class="pagination-ellipsis">...</span>';
            }
        }
        
        // 페이지 번호 표시
        for ($i = $start_page; $i <= $end_page; $i++) {
            echo '<a href="?type=' . urlencode($board_type) . '&page=' . $i . ($search ? '&search='.urlencode($search) : '') . '"';
            echo $page === $i ? ' class="active"' : '';
            echo '>' . $i . '</a>';
        }
        
        // 마지막 페이지가 끝이 아닌 경우
        if ($end_page < $total_pages) {
            if ($end_page < $total_pages - 1) {
                echo '<span class="pagination-ellipsis">...</span>';
            }
            echo '<a href="?type=' . urlencode($board_type) . '&page=' . $total_pages . ($search ? '&search='.urlencode($search) : '') . '">' . $total_pages . '</a>';
        }
        ?>
    </div>
</div>

<!-- 게시글 보기 모달 -->
<div id="viewPostModal" class="view-modal">
    <div class="view-modal-content">
        <div class="view-modal-header">
            <h3 class="view-modal-title"><i class="fas fa-file-alt"></i> <span id="viewPostTitle">게시글 제목</span></h3>
            <span class="view-modal-close" onclick="closeViewModal()">&times;</span>
        </div>
        <div class="view-modal-info">
            <div class="view-modal-info-item">
                <i class="fas fa-tag"></i>
                <span id="viewPostType">게시판 유형</span>
            </div>
            <div class="view-modal-info-item">
                <i class="fas fa-user-edit"></i>
                <span id="viewPostAuthor">작성자</span>
            </div>
            <div class="view-modal-info-item">
                <i class="fas fa-calendar-alt"></i>
                <span id="viewPostDate">작성일</span>
            </div>
            <div class="view-modal-info-item" id="viewPostMemberInfo" style="display:none;">
                <i class="fas fa-user-circle"></i>
                <span id="viewPostMember">회원명</span>
            </div>
        </div>
        <div class="view-modal-body">
            <div class="view-modal-content-area" id="viewPostContent">
                게시글 내용이 여기에 표시됩니다.
            </div>
            
            <!-- 댓글 섹션 -->
            <div class="view-modal-comments-section">
                <div class="comments-title">
                    <i class="fas fa-comments"></i> 댓글 
                    <span id="commentCount" class="comment-count-badge">0</span>
                </div>
                <div id="commentsContainer" class="comments-container">
                    <!-- 댓글이 여기에 동적으로 추가됩니다 -->
                </div>
                
                <!-- 댓글 작성 폼 -->
                <div class="comment-form-container">
                    <textarea id="commentText" placeholder="댓글을 입력하세요" class="comment-textarea"></textarea>
                    <button type="button" class="comment-submit" onclick="submitComment()"><i class="fas fa-paper-plane"></i> 댓글</button>
                </div>
            </div>
        </div>
        <div class="view-modal-actions">
            <div class="modal-action-buttons">
                <button type="button" class="btn btn-edit" id="editPostBtn" onclick="editPost()"><i class="fas fa-edit"></i> 수정</button>
                <button type="button" class="btn btn-delete" id="deletePostBtn" onclick="deletePost()"><i class="fas fa-trash-alt"></i> 삭제</button>
                <?php if ($board_type === '상담기록'): ?>
                <button type="button" class="btn btn-member" id="mapMemberBtn" onclick="openMapMemberModal()"><i class="fas fa-user-plus"></i> 회원등록</button>
                <?php endif; ?>
                <button type="button" class="btn btn-close" onclick="closeViewModal()"><i class="fas fa-times"></i> 닫기</button>
            </div>
        </div>
    </div>
</div>

<!-- 회원 매핑 모달 -->
<div id="mapMemberModal" class="view-modal">
    <div class="view-modal-content">
        <div class="view-modal-header">
            <h3 class="view-modal-title"><i class="fas fa-user-plus"></i> <span>게시글 회원등록</span></h3>
            <span class="view-modal-close" onclick="closeMapMemberModal()">&times;</span>
        </div>
        <div class="view-modal-body">
            <div class="member-search-container">
                <input type="text" id="mapMemberSearchInput" placeholder="회원명 또는 전화번호로 검색" class="member-search-input">
                <button type="button" class="btn" onclick="searchMembersForMap()"><i class="fas fa-search"></i> 검색</button>
            </div>
            <div class="member-list-container">
                <table class="member-table">
                    <thead>
                        <tr>
                            <th>회원번호</th>
                            <th>회원명</th>
                            <th>전화번호</th>
                            <th>선택</th>
                        </tr>
                    </thead>
                    <tbody id="mapMemberListBody">
                        <tr>
                            <td colspan="4" class="loading-td">
                                <div class="loading-indicator">
                                    <i class="fas fa-spinner fa-pulse"></i> 회원 정보를 로딩 중입니다...
                                </div>
                            </td>
                        </tr>
                    </tbody>
                </table>
                <div id="mapMemberPagination" class="pagination">
                    <!-- 페이지네이션 버튼이 여기에 표시됩니다 -->
                </div>
            </div>
        </div>
        <div class="view-modal-actions">
            <div class="modal-action-buttons">
                <button type="button" class="btn btn-close" onclick="closeMapMemberModal()"><i class="fas fa-times"></i> 닫기</button>
            </div>
        </div>
    </div>
</div>

<!-- 회원 선택 모달 (상담기록 탭의 회원등록 버튼용) -->
<div id="selectMemberModal" class="view-modal">
    <div class="view-modal-content">
        <div class="view-modal-header">
            <h3 class="view-modal-title"><i class="fas fa-user-plus"></i> <span>회원등록</span></h3>
            <span class="view-modal-close" onclick="closeSelectMemberModal()">&times;</span>
        </div>
        <div class="view-modal-body">
            <div class="select-member-content">
                <div class="member-selection-layout">
                    <div class="post-selection-panel">
                        <h4><i class="fas fa-clipboard-list"></i> 상담기록 선택</h4>
                        <div class="post-list-container">
                            <div id="postListContainer">
                                <!-- 게시글 목록이 여기에 동적으로 표시됩니다 -->
                                <div class="loading-indicator">
                                    <i class="fas fa-spinner fa-pulse"></i> 상담기록을 로딩 중입니다...
                                </div>
                            </div>
                        </div>
                    </div>
                    
                    <div class="member-selection-panel">
                        <h4><i class="fas fa-users"></i> 회원 검색 및 선택</h4>
                        <div class="member-search-container">
                            <input type="text" id="memberSearchInput" placeholder="회원명 또는 전화번호로 검색" class="member-search-input">
                            <button type="button" class="btn" onclick="searchMembers()"><i class="fas fa-search"></i> 검색</button>
                        </div>
                        <div class="member-list-container">
                            <table class="member-table">
                                <thead>
                                    <tr>
                                        <th>회원번호</th>
                                        <th>회원명</th>
                                        <th>전화번호</th>
                                        <th>선택</th>
                                    </tr>
                                </thead>
                                <tbody id="memberListBody">
                                    <tr>
                                        <td colspan="4" class="loading-td">
                                            <div class="loading-indicator">
                                                <i class="fas fa-spinner fa-pulse"></i> 회원 정보를 로딩 중입니다...
                                            </div>
                                        </td>
                                    </tr>
                                </tbody>
                            </table>
                            <div id="memberPagination" class="pagination">
                                <!-- 페이지네이션 버튼이 여기에 표시됩니다 -->
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
        <div class="view-modal-actions">
            <div class="modal-action-buttons">
                <button type="button" class="btn btn-close" onclick="closeSelectMemberModal()"><i class="fas fa-times"></i> 닫기</button>
            </div>
        </div>
    </div>
</div>

<style>
/* 기존 스타일 */
.board-table {
    width: 100%;
    border-collapse: collapse;
    margin-top: 20px;
    font-family: 'Noto Sans KR', 'Malgun Gothic', sans-serif;
    border-radius: 4px;
    overflow: hidden;
    box-shadow: 0 1px 3px rgba(0,0,0,0.05);
    table-layout: fixed; /* 고정 테이블 레이아웃 */
}
.board-table th,
.board-table td {
    padding: 10px 12px;
    border-bottom: 1px solid #eee;
    font-size: 14px; /* 통일된 폰트 사이즈 */
    text-align: left !important; /* 모든 셀 왼쪽 정렬 강제 적용 */
}
.board-table th {
    background: #f8f9fa;
    color: #333;
    font-weight: 600;
    border-bottom: 2px solid #ddd;
    text-align: center !important; /* 헤더는 중앙 정렬 유지 */
}
.board-table tr:hover {
    background-color: #f9fafc;
}
.text-center {
    text-align: center !important;
}
.content-cell {
    padding: 15px 12px;
    text-align: left !important;
    vertical-align: top;
}
.content-title {
    font-weight: 700;
    font-size: 15px;
    margin-bottom: 10px;
}
.content-title a {
    color: #2980b9;
    text-decoration: none;
    background: linear-gradient(to right, #3498db, #2980b9);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
    display: inline;
    transition: all 0.2s ease;
}
.content-title a:hover {
    text-decoration: underline;
    background: linear-gradient(to right, #2980b9, #3498db);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
}
.content-full {
    color: #333;
    font-size: 14px;
    line-height: 1.5;
    max-height: none;
    overflow: visible;
    white-space: pre-line;
    margin-bottom: 12px;
}
.comment-preview {
    background: #f9f9f9;
    border-left: 3px solid #4a89dc;
    padding: 10px 12px;
    margin-top: 12px;
    border-radius: 0 4px 4px 0;
}
.comment-header {
    font-size: 13px;
    color: #666;
    margin-bottom: 5px;
    display: flex;
    align-items: center;
    gap: 5px;
}
.comment-author {
    color: #3498db;
    font-weight: 600;
}
.comment-content {
    font-size: 14px;
    color: #333;
    padding-left: 5px;
    border-left: 1px solid #e0e0e0;
    margin-left: 5px;
}
.more-comments {
    font-size: 12px;
    color: #888;
    text-align: right;
    margin-top: 5px;
    font-style: italic;
}
.board-actions {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin: 20px 0;
}
.search-form {
    display: flex;
    gap: 10px;
}
.search-input {
    width: 300px;
    padding: 10px 15px;
    border: 1px solid #eee;
    border-radius: 50px;
    box-shadow: 0 2px 5px rgba(0,0,0,0.05);
    transition: all 0.3s ease;
}
.search-input:focus {
    outline: none;
    border-color: #5b86e5;
    box-shadow: 0 3px 8px rgba(91, 134, 229, 0.2);
}

/* 게시판 탭 스타일 */
.board-tabs {
    display: flex;
    flex-wrap: wrap;
    gap: 6px;
    margin-bottom: 20px;
    padding-bottom: 10px;
    border-bottom: 1px solid #eee;
}
.board-tab {
    padding: 8px 16px;
    border-radius: 4px;
    text-decoration: none;
    color: #444;
    background: #f8f9fa;
    border: 1px solid #eee;
    transition: all 0.2s ease;
    font-weight: 500;
}
.board-tab.active {
    background: #4a89dc;
    color: white;
    border-color: #4a89dc;
}
.board-tab:hover {
    background: #eef1f5;
}
.board-tab.active:hover {
    background: #3a70c2;
}

/* 행 선택 스타일 */
.board-row {
    cursor: pointer;
    transition: all 0.2s;
}
.board-row:hover {
    background: #f0f5ff;
}

/* 제목 링크 스타일 */
.title-link {
    color: #2c3e50;
    text-decoration: none;
    font-weight: 500;
    transition: all 0.2s ease;
}
.title-link:hover {
    color: #5b86e5;
    text-decoration: none;
}

/* 댓글 카운트 스타일 */
.comment-count {
    display: inline-block;
    background: linear-gradient(to right, #5b86e5, #36d1dc);
    color: white;
    min-width: 24px;
    height: 24px;
    line-height: 24px;
    text-align: center;
    border-radius: 12px;
    font-size: 12px;
    box-shadow: 0 2px 4px rgba(91, 134, 229, 0.3);
}

/* 버튼 기본 스타일 */
.btn {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    padding: 10px 20px;
    border-radius: 50px;
    cursor: pointer;
    font-size: 14px;
    font-weight: 700;
    text-decoration: none;
    text-align: center;
    border: none;
    transition: all 0.3s ease;
    box-shadow: 0 3px 6px rgba(0,0,0,0.1);
    gap: 8px;
    background: linear-gradient(to right, #a1c4fd, #c2e9fb);
    color: #2c3e50;
    min-width: 100px;
    height: 40px;
    line-height: 1;
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

.btn-edit {
    background: linear-gradient(to right, #3498db, #2980b9);
    color: white;
}
.btn-edit:hover {
    background: linear-gradient(to right, #2980b9, #3498db);
    box-shadow: 0 5px 15px rgba(52, 152, 219, 0.4);
}

.btn-delete {
    background: linear-gradient(to right, #fc6076, #ff4b2b);
    color: white;
}
.btn-delete:hover {
    background: linear-gradient(to right, #ff4b2b, #fc6076);
    box-shadow: 0 5px 15px rgba(252, 96, 118, 0.4);
}

.btn-close {
    background: linear-gradient(to right, #8e9eab, #eef2f3);
    color: #2c3e50;
}
.btn-close:hover {
    background: linear-gradient(to right, #eef2f3, #8e9eab);
    box-shadow: 0 5px 15px rgba(142, 158, 171, 0.4);
}

/* 페이지네이션 */
.pagination {
    display: flex;
    justify-content: center;
    gap: 8px;
    margin-top: 30px;
}
.pagination a {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 36px;
    height: 36px;
    border-radius: 50%;
    background: #f0f5ff;
    color: #5b86e5;
    text-decoration: none;
    font-weight: 500;
    transition: all 0.3s ease;
}
.pagination a:hover {
    background: #e0e9ff;
    transform: translateY(-2px);
}
.pagination a.active {
    background: linear-gradient(to right, #5b86e5, #36d1dc);
    color: white;
    box-shadow: 0 4px 10px rgba(91, 134, 229, 0.3);
}

/* 게시글 보기 모달 */
.view-modal {
    display: none;
    position: fixed;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    background: rgba(0,0,0,0.5);
    z-index: 1000;
    overflow-y: auto;
}

.view-modal-content {
    position: relative;
    background: #fff;
    margin: 30px auto;
    padding: 0;
    width: 800px;
    max-width: 90%;
    border-radius: 16px;
    box-shadow: 0 10px 30px rgba(0, 0, 0, 0.08);
    overflow: hidden;
}

.view-modal-header {
    background: linear-gradient(135deg, #5b86e5 0%, #36d1dc 100%);
    padding: 16px 20px;
    display: flex;
    justify-content: space-between;
    align-items: center;
    border-bottom: none;
    box-shadow: 0 4px 15px rgba(91, 134, 229, 0.2);
}

.view-modal-title {
    margin: 0;
    font-size: 22px;
    font-weight: 700;
    color: white;
    display: flex;
    align-items: center;
}

.view-modal-close {
    font-size: 24px;
    cursor: pointer;
    color: white;
    transition: all 0.3s ease;
}
.view-modal-close:hover {
    transform: rotate(90deg);
}

.view-modal-info {
    background: linear-gradient(to right, #f8fafc, #f1f7fa);
    border-radius: 12px;
    padding: 18px;
    margin: 20px;
    display: flex;
    flex-wrap: wrap;
    gap: 15px;
    box-shadow: 0 3px 10px rgba(0, 0, 0, 0.03);
}

.view-modal-info-item {
    display: flex;
    align-items: center;
    font-size: 14px;
    color: #5c7185;
    background: rgba(255, 255, 255, 0.7);
    padding: 6px 12px;
    border-radius: 30px;
    box-shadow: 0 2px 5px rgba(0, 0, 0, 0.03);
}

.view-modal-info-item i {
    margin-right: 8px;
    color: #5b86e5;
}

.view-modal-body {
    padding: 0 20px 20px 20px;
}

.view-modal-content-area {
    padding: 20px;
    min-height: 200px;
    line-height: 1.7;
    border: 1px solid #f0f5ff;
    border-radius: 8px;
    background: #fff;
    white-space: pre-wrap;
    font-family: 'Noto Sans KR', 'Malgun Gothic', sans-serif;
}

.view-modal-actions {
    padding: 20px;
    border-top: 1px solid #f0f5ff;
    display: flex;
    justify-content: center;
    background-color: #f9fafc;
}

.modal-action-buttons {
    display: flex;
    justify-content: center;
    gap: 15px;
    width: 100%;
    max-width: 500px;
}

/* 댓글 스타일 */
.view-modal-comments-section {
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

.comment-count-badge {
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
    margin-top: 12px;
}

.post-comments {
    margin-top: 10px;
    border-left: 3px solid #4a89dc;
    padding-left: 10px;
    background-color: #f9f9f9;
    border-radius: 0 4px 4px 0;
}

.comment-line {
    font-size: 13px;
    color: #555;
    padding: 4px 0;
    border-top: 1px dashed #eee;
    display: flex;
    align-items: flex-start;
    flex-wrap: wrap;
}

.comment-line:first-child {
    border-top: none;
}

.comment-icon {
    color: #3498db;
    margin-right: 5px;
    font-size: 12px;
    margin-top: 3px;
}

.comment-author {
    color: #3498db;
    font-weight: 600;
    margin-right: 3px;
}

.comment-date {
    color: #999;
    font-size: 12px;
    margin-left: 5px;
}

.comment-count-badge {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    background: #f0f5ff;
    color: #3498db;
    border-radius: 12px;
    padding: 2px 8px;
    font-size: 11px;
    margin-left: 8px;
    font-weight: 600;
    border: 1px solid #d6e4ff;
}

.no-comments {
    color: #95a5a6;
    font-style: italic;
    text-align: center;
    padding: 20px;
    background: #f8fafc;
    border-radius: 8px;
    border: 1px dashed #e6eaf0;
}

/* 댓글 작성 폼 */
.comment-form-container {
    margin-top: 15px;
    display: flex;
    align-items: flex-start;
    gap: 8px;
}

.comment-textarea {
    flex: 1;
    padding: 12px 15px;
    border: 1px solid #dce1e6;
    border-radius: 20px;
    min-height: 40px;
    resize: none;
    font-family: 'Noto Sans KR', 'Malgun Gothic', sans-serif;
    font-size: 14px;
    transition: all 0.3s ease;
    box-shadow: 0 1px 3px rgba(0,0,0,0.05);
}

.comment-textarea:focus {
    border-color: #36d1dc;
    box-shadow: 0 0 0 3px rgba(54, 209, 220, 0.2);
    outline: none;
}

.comment-submit {
    background: linear-gradient(to right, #36d1dc, #5b86e5);
    color: white;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    padding: 8px 16px;
    border-radius: 50px;
    font-weight: 700;
    border: none;
    cursor: pointer;
    transition: all 0.3s ease;
    box-shadow: 0 3px 6px rgba(0,0,0,0.1);
    gap: 6px;
}

.comment-submit:hover {
    background: linear-gradient(to right, #5b86e5, #36d1dc);
    transform: translateY(-2px);
    box-shadow: 0 5px 15px rgba(91, 134, 229, 0.4);
}

/* Google Noto Sans KR 폰트 추가 */
@import url('https://fonts.googleapis.com/css2?family=Noto+Sans+KR:wght@400;500;700&display=swap');

.pagination-ellipsis {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 36px;
    height: 36px;
    color: #95a5a6;
    font-weight: 500;
    user-select: none;
}

/* 회원 선택 모달 스타일 수정 */
.member-selection-layout {
    display: flex;
    flex-direction: row;
    gap: 20px;
    height: 60vh;
    max-height: 600px;
}

.post-selection-panel, 
.member-selection-panel {
    flex: 1;
    display: flex;
    flex-direction: column;
    border: 1px solid #eee;
    border-radius: 8px;
    padding: 15px;
    background: #fff;
    box-shadow: 0 2px 5px rgba(0,0,0,0.05);
    overflow: hidden;
}

.post-list-container {
    flex: 1;
    overflow-y: auto;
    margin-top: 10px;
}

.member-search-container {
    display: flex;
    gap: 10px;
    margin-bottom: 15px;
}

.post-item {
    padding: 12px 15px;
    border-bottom: 1px solid #eee;
    cursor: pointer;
    transition: all 0.2s ease;
}

.post-item:hover {
    background-color: #f0f5ff;
}

.post-item.selected {
    background-color: #e0f7fa;
    box-shadow: inset 0 0 0 2px #36d1dc;
}

.post-item-title {
    font-weight: 500;
    margin-bottom: 8px;
    color: #333;
}

.post-item-content {
    color: #666;
    font-size: 13px;
    line-height: 1.4;
    margin-bottom: 8px;
    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
    overflow: hidden;
    text-overflow: ellipsis;
}

.post-item-meta {
    color: #888;
    font-size: 12px;
    display: flex;
    justify-content: space-between;
}

.post-item-checkbox {
    margin-right: 10px;
}

.loading-indicator {
    padding: 20px;
    text-align: center;
    color: #666;
}

.loading-indicator i {
    margin-right: 8px;
    color: #36d1dc;
}

.loading-td {
    padding: 20px !important;
}

.empty-message {
    padding: 20px;
    text-align: center;
    color: #666;
    font-style: italic;
}

.member-selection-panel {
    display: flex;
    flex-direction: column;
}

.member-list-container {
    flex: 1;
    overflow-y: auto;
    display: flex;
    flex-direction: column;
}

.post-item.registered {
    background-color: #f9f9f9;
    opacity: 0.8;
    cursor: default;
}

.registration-badge {
    display: inline-block;
    background: linear-gradient(to right, #e9f7ef, #d4efdf);
    color: #27ae60;
    font-size: 12px;
    font-weight: 600;
    padding: 3px 10px;
    border-radius: 20px;
    margin-left: 10px;
    border: 1px solid #d4efdf;
}

.post-item-checkbox:disabled {
    opacity: 0.5;
    cursor: not-allowed;
}

.debug-info {
    background: #f8f9fa;
    border: 1px solid #ddd;
    border-radius: 5px;
    padding: 15px;
    margin-bottom: 20px;
    font-size: 14px;
    color: #333;
}

.debug-info h3 {
    color: #3498db;
    margin-top: 0;
    margin-bottom: 10px;
    font-size: 16px;
}

/* 비활성화 버튼 스타일 */
.btn-disabled {
    opacity: 0.6;
    cursor: not-allowed;
    background: linear-gradient(to right, #ccc, #999) !important;
    box-shadow: none !important;
}

.btn-disabled:hover {
    transform: none !important;
    box-shadow: none !important;
}

/* 회원 매핑 버튼 스타일 */
.btn-member {
    background: linear-gradient(to right, #36d1dc, #5b86e5);
    color: white;
}

.btn-member:hover {
    background: linear-gradient(to right, #5b86e5, #36d1dc);
    box-shadow: 0 5px 15px rgba(54, 209, 220, 0.4);
}

/* 회원 테이블 내 선택 버튼 */
.select-btn {
    background: linear-gradient(to right, #36d1dc, #5b86e5);
    color: white;
    border: none;
    padding: 5px 10px;
    border-radius: 4px;
    cursor: pointer;
    font-size: 12px;
    transition: all 0.3s ease;
}

.select-btn:hover {
    background: linear-gradient(to right, #5b86e5, #36d1dc);
    transform: translateY(-2px);
    box-shadow: 0 3px 6px rgba(0,0,0,0.1);
}
</style>

<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/5.15.4/css/all.min.css">

<script>
// Google Noto Sans KR 폰트 추가
if (!document.getElementById('noto-sans-kr')) {
    const link = document.createElement('link');
    link.id = 'noto-sans-kr';
    link.rel = 'stylesheet';
    link.href = 'https://fonts.googleapis.com/css2?family=Noto+Sans+KR:wght@400;500;700&display=swap';
    document.head.appendChild(link);
}

document.addEventListener('DOMContentLoaded', function() {
    // 행 클릭 시 게시글 모달 열기
    const rows = document.querySelectorAll('.board-row');
    rows.forEach(row => {
        row.addEventListener('click', function(e) {
            // 이미 링크를 클릭한 경우는 처리하지 않음
            if (e.target.tagName === 'A' || e.target.closest('a')) {
                e.preventDefault(); // 기본 링크 이벤트 방지
                const boardId = this.getAttribute('data-id');
                openPostModal(boardId);
                return;
            }
            
            const boardId = this.getAttribute('data-id');
            openPostModal(boardId);
        });
    });
    
    // 제목 링크 클릭 처리 
    const titleLinks = document.querySelectorAll('.title-link');
    titleLinks.forEach(link => {
        link.addEventListener('click', function(e) {
            e.preventDefault();
            const boardId = this.getAttribute('data-id');
            openPostModal(boardId);
        });
    });
    
    // 페이지 로드 시 저장된 데이터 체크
    if (localStorage.getItem('openPostModal')) {
        const postData = JSON.parse(localStorage.getItem('openPostModal'));
        openPostModal(postData.postId, postData.title, postData.content, postData.images);
        localStorage.removeItem('openPostModal');
    }
    
    // 회원등록 버튼 클릭 처리 수정
    const registerMemberBtn = document.getElementById('registerMemberBtn');
    if (registerMemberBtn) {
        registerMemberBtn.addEventListener('click', function() {
            openSelectMemberModal();
        });
    }
    
    // 회원 검색 입력창에서 엔터 키 처리
    const memberSearchInput = document.getElementById('memberSearchInput');
    if (memberSearchInput) {
        memberSearchInput.addEventListener('keypress', function(e) {
            if (e.key === 'Enter') {
                e.preventDefault();
                searchMembers();
            }
        });
    }
});

// 게시글 모달 열기
function openPostModal(boardId) {
    // 게시글 데이터 가져오기
    fetch(`get_post_data.php?id=${boardId}`)
        .then(response => response.json())
        .then(data => {
            if (data.success) {
                document.getElementById('viewPostTitle').textContent = data.post.title;
                document.getElementById('viewPostType').textContent = data.post.board_type;
                document.getElementById('viewPostAuthor').textContent = data.post.staff_name;
                document.getElementById('viewPostDate').textContent = data.post.created_at;
                document.getElementById('viewPostContent').textContent = data.post.content;
                
                // 회원 정보 표시 (있는 경우)
                const memberInfoEl = document.getElementById('viewPostMemberInfo');
                const memberNameEl = document.getElementById('viewPostMember');
                if (data.post.member_name) {
                    memberNameEl.textContent = data.post.member_name;
                    memberInfoEl.style.display = 'flex';
                } else {
                    memberInfoEl.style.display = 'none';
                }
                
                // 수정/삭제 버튼 표시 여부 결정 (자신의 글인 경우에만)
                const editButton = document.getElementById('editPostBtn');
                const deleteButton = document.getElementById('deletePostBtn');
                const isMyPost = <?php echo $_SESSION['staff_id']; ?> === parseInt(data.post.staff_id);
                
                if (isMyPost) {
                    editButton.style.display = 'inline-block';
                    deleteButton.style.display = 'inline-block';
                } else {
                    editButton.style.display = 'none';
                    deleteButton.style.display = 'none';
                }
                
                // 회원 매핑 버튼 표시 여부 결정 (상담기록인 경우에만)
                const mapMemberBtn = document.getElementById('mapMemberBtn');
                if (mapMemberBtn) {
                    if (data.post.board_type === '상담기록') {
                        mapMemberBtn.style.display = 'inline-block';
                        
                        // 이미 회원이 연결된 경우 버튼 비활성화
                        if (data.post.member_name) {
                            mapMemberBtn.disabled = true;
                            mapMemberBtn.title = "이미 회원이 등록되어 있습니다";
                            mapMemberBtn.classList.add('btn-disabled');
                        } else {
                            mapMemberBtn.disabled = false;
                            mapMemberBtn.title = "";
                            mapMemberBtn.classList.remove('btn-disabled');
                        }
                    } else {
                        mapMemberBtn.style.display = 'none';
                    }
                }
                
                // 댓글 표시
                renderComments(data.comments);
                
                // 현재 열려있는 게시글 ID 저장
                document.getElementById('viewPostModal').setAttribute('data-post-id', boardId);
                document.getElementById('viewPostModal').setAttribute('data-board-type', data.post.board_type);
                
                // 댓글 입력창 초기화
                document.getElementById('commentText').value = '';
                
                // 모달 열기
                document.getElementById('viewPostModal').style.display = 'block';
                document.body.style.overflow = 'hidden'; // 스크롤 방지
            } else {
                alert('게시글을 불러오는 중 오류가 발생했습니다.');
            }
        })
        .catch(error => {
            console.error('Error:', error);
            alert('게시글을 불러오는 중 오류가 발생했습니다.');
        });
}

// 게시글 모달 닫기
function closeViewModal() {
    document.getElementById('viewPostModal').style.display = 'none';
    document.body.style.overflow = ''; // 스크롤 복원
}

// 게시글 수정
function editPost() {
    const boardId = document.getElementById('viewPostModal').getAttribute('data-post-id');
    window.location.href = `board_edit.php?id=${boardId}`;
}

// 댓글 작성
function submitComment() {
    const boardId = document.getElementById('viewPostModal').getAttribute('data-post-id');
    const content = document.getElementById('commentText').value.trim();
    
    if (!content) {
        alert('댓글 내용을 입력하세요.');
        return;
    }
    
    fetch('comment_add.php', {
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
            fetch(`get_post_data.php?id=${boardId}`)
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

// 댓글 렌더링
function renderComments(comments) {
    const container = document.getElementById('commentsContainer');
    const countBadge = document.getElementById('commentCount');
    
    container.innerHTML = '';
    countBadge.textContent = comments.length;
    
    if (comments.length === 0) {
        container.innerHTML = '<div class="no-comments"><i class="fas fa-comment-slash"></i>아직 댓글이 없습니다.</div>';
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

// ESC 키로 모달 닫기
window.addEventListener('keydown', function(e) {
    if (e.key === 'Escape' && document.getElementById('viewPostModal').style.display === 'block') {
        closeViewModal();
    }
});

// 게시글 삭제 함수
function deletePost() {
    const boardId = document.getElementById('viewPostModal').getAttribute('data-post-id');
    
    if (confirm('정말 이 게시글을 삭제하시겠습니까?')) {
        fetch('board_delete.php', {
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

// 회원등록 모달 열기 시 상담기록 목록과 회원 목록 로드
function openSelectMemberModal() {
    document.getElementById('memberSearchInput').value = '';
    document.getElementById('selectMemberModal').style.display = 'block';
    document.body.style.overflow = 'hidden'; // 스크롤 방지
    
    // 상담기록 목록 로드
    loadConsultationPosts();
    
    // 회원 목록 초기 로드
    loadInitialMembers();
}

// 상담기록 게시글 목록 로드
function loadConsultationPosts() {
    const postListContainer = document.getElementById('postListContainer');
    postListContainer.innerHTML = '<div class="loading-indicator"><i class="fas fa-spinner fa-pulse"></i> 상담기록을 로딩 중입니다...</div>';
    
    // 서버에서 상담기록 목록 가져오기
    fetch('get_consultation_posts.php')
        .then(response => response.json())
        .then(data => {
            if (data.success) {
                // 전역 변수에 응답 저장
                window.lastConsultationResponse = data;
                renderConsultationPosts(data.posts);
            } else {
                postListContainer.innerHTML = '<div class="error-message">상담기록을 불러오는 중 오류가 발생했습니다.</div>';
            }
        })
        .catch(error => {
            console.error('Error:', error);
            postListContainer.innerHTML = '<div class="error-message">상담기록을 불러오는 중 오류가 발생했습니다.</div>';
        });
}

// 회원 목록 초기 로드
function loadInitialMembers(page = 1) {
    const memberListBody = document.getElementById('memberListBody');
    memberListBody.innerHTML = `
        <tr>
            <td colspan="4" class="loading-td">
                <div class="loading-indicator">
                    <i class="fas fa-spinner fa-pulse"></i> 회원 정보를 로딩 중입니다...
                </div>
            </td>
        </tr>
    `;
    
    fetch('../menu_member/get_initial_members.php?page=' + page)
        .then(response => response.json())
        .then(data => {
            if (data.success) {
                renderMemberList(data.members, data.total_pages, page);
            } else {
                memberListBody.innerHTML = '<tr><td colspan="4">회원 정보를 불러오는 중 오류가 발생했습니다.</td></tr>';
            }
        })
        .catch(error => {
            console.error('Error:', error);
            memberListBody.innerHTML = '<tr><td colspan="4">회원 정보를 불러오는 중 오류가 발생했습니다.</td></tr>';
        });
}

// 상담기록 게시글 목록 렌더링
function renderConsultationPosts(posts) {
    const postListContainer = document.getElementById('postListContainer');
    postListContainer.innerHTML = '';
    
    if (posts.length === 0) {
        postListContainer.innerHTML += '<div class="empty-message">등록된 상담기록이 없습니다.</div>';
        return;
    }
    
    posts.forEach(post => {
        const postItem = document.createElement('div');
        postItem.className = 'post-item';
        postItem.setAttribute('data-id', post.board_id);
        
        // 회원에 이미 등록된 상담기록 체크
        const isRegistered = post.is_registered ? true : false;
        
        // 댓글 부분 HTML 생성
        let commentsHtml = '';
        if (post.comments && post.comments.length > 0) {
            commentsHtml = '<div class="post-comments">';
            post.comments.forEach(comment => {
                commentsHtml += `
                    <div class="comment-line">
                        <i class="fas fa-comment comment-icon"></i>
                        <span class="comment-author">${comment.staff_name}</span>: 
                        ${comment.content}
                        <span class="comment-date">(${comment.created_at})</span>
                    </div>
                `;
            });
            commentsHtml += '</div>';
        }
        
        postItem.innerHTML = `
            <div class="post-item-header">
                <input type="checkbox" class="post-item-checkbox" id="post_${post.board_id}" ${isRegistered ? 'disabled' : ''}>
                <label for="post_${post.board_id}" class="post-item-title">
                    ${post.title}
                    ${isRegistered ? '<span class="registration-badge">회원등록완료</span>' : ''}
                    ${post.comment_count > 0 ? `<span class="comment-count-badge">${post.comment_count}</span>` : ''}
                </label>
            </div>
            <div class="post-item-content">${post.content}</div>
            ${commentsHtml}
            <div class="post-item-meta">
                <span>${post.created_at}</span>
                <span>${post.staff_name}</span>
            </div>
        `;
        
        if (isRegistered) {
            postItem.classList.add('registered');
        } else {
            // 체크박스 클릭 이벤트
            const checkbox = postItem.querySelector('input[type="checkbox"]');
            checkbox.addEventListener('change', function(e) {
                // 다른 모든 체크박스 해제
                document.querySelectorAll('.post-item-checkbox:not([disabled])').forEach(cb => {
                    if (cb !== this) {
                        cb.checked = false;
                        cb.closest('.post-item').classList.remove('selected');
                    }
                });
                
                // 현재 항목 선택/해제
                if (this.checked) {
                    postItem.classList.add('selected');
                } else {
                    postItem.classList.remove('selected');
                }
                
                e.stopPropagation(); // 이벤트 전파 중지
            });
            
            // 항목 클릭 시 체크박스 토글
            postItem.addEventListener('click', function(e) {
                // 체크박스 자체 클릭은 제외
                if (e.target !== checkbox) {
                    checkbox.checked = !checkbox.checked;
                    checkbox.dispatchEvent(new Event('change'));
                }
            });
        }
        
        postListContainer.appendChild(postItem);
    });
}

// 회원 목록 렌더링
function renderMemberList(members, totalPages, currentPage) {
    const memberListBody = document.getElementById('memberListBody');
    memberListBody.innerHTML = '';
    
    if (members.length === 0) {
        memberListBody.innerHTML = '<tr><td colspan="4">표시할 회원 정보가 없습니다.</td></tr>';
        return;
    }
    
    members.forEach(member => {
        const row = document.createElement('tr');
        row.innerHTML = `
            <td>${member.member_id}</td>
            <td>${member.member_name}</td>
            <td>${member.member_phone}</td>
            <td>
                <button type="button" class="select-btn" 
                        onclick="registerPostToMember(${member.member_id}, '${member.member_name}')">
                    선택
                </button>
            </td>
        `;
        memberListBody.appendChild(row);
    });
    
    // 페이지네이션 처리
    renderMemberPagination(totalPages, currentPage);
}

// 페이지네이션 렌더링
function renderMemberPagination(totalPages, currentPage) {
    const paginationEl = document.getElementById('memberPagination');
    paginationEl.innerHTML = '';
    
    if (totalPages <= 1) return;
    
    const startPage = Math.max(1, currentPage - 2);
    const endPage = Math.min(totalPages, currentPage + 2);
    
    // 이전 페이지 버튼
    if (currentPage > 1) {
        const prevBtn = document.createElement('a');
        prevBtn.href = '#';
        prevBtn.innerHTML = '&laquo;';
        prevBtn.addEventListener('click', (e) => {
            e.preventDefault();
            const searchTerm = document.getElementById('memberSearchInput').value.trim();
            if (searchTerm) {
                searchMembers(currentPage - 1);
            } else {
                loadInitialMembers(currentPage - 1);
            }
        });
        paginationEl.appendChild(prevBtn);
    }
    
    // 페이지 번호 버튼
    for (let i = startPage; i <= endPage; i++) {
        const pageLink = document.createElement('a');
        pageLink.href = '#';
        pageLink.innerText = i;
        if (i === currentPage) {
            pageLink.classList.add('active');
        }
        pageLink.addEventListener('click', (e) => {
            e.preventDefault();
            const searchTerm = document.getElementById('memberSearchInput').value.trim();
            if (searchTerm) {
                searchMembers(i);
            } else {
                loadInitialMembers(i);
            }
        });
        paginationEl.appendChild(pageLink);
    }
    
    // 다음 페이지 버튼
    if (currentPage < totalPages) {
        const nextBtn = document.createElement('a');
        nextBtn.href = '#';
        nextBtn.innerHTML = '&raquo;';
        nextBtn.addEventListener('click', (e) => {
            e.preventDefault();
            const searchTerm = document.getElementById('memberSearchInput').value.trim();
            if (searchTerm) {
                searchMembers(currentPage + 1);
            } else {
                loadInitialMembers(currentPage + 1);
            }
        });
        paginationEl.appendChild(nextBtn);
    }
}

// 회원 검색 함수
function searchMembers(page = 1) {
    const searchTerm = document.getElementById('memberSearchInput').value.trim();
    const memberListBody = document.getElementById('memberListBody');
    
    if (searchTerm === '') {
        // 검색어가 비어있으면 초기 회원 목록 로드
        loadInitialMembers(page);
        return;
    }
    
    memberListBody.innerHTML = `
        <tr>
            <td colspan="4" class="loading-td">
                <div class="loading-indicator">
                    <i class="fas fa-spinner fa-pulse"></i> 검색 중입니다...
                </div>
            </td>
        </tr>
    `;
    
    fetch(`search_members.php?term=${encodeURIComponent(searchTerm)}&page=${page}`)
        .then(response => response.json())
        .then(data => {
            if (data.success) {
                renderMemberList(data.members, data.total_pages, page);
            } else {
                memberListBody.innerHTML = '<tr><td colspan="4">검색 중 오류가 발생했습니다: ' + (data.message || '알 수 없는 오류') + '</td></tr>';
            }
        })
        .catch(error => {
            console.error('Error:', error);
            memberListBody.innerHTML = '<tr><td colspan="4">검색 중 오류가 발생했습니다.</td></tr>';
        });
}

// 게시글에 회원 연결 함수 (상담기록 탭의 회원등록 버튼용)
function registerPostToMember(memberId, memberName) {
    // 선택된 게시글 체크
    const selectedCheckbox = document.querySelector('.post-item-checkbox:checked');
    
    if (!selectedCheckbox) {
        alert('선택된 상담기록이 없습니다. 먼저 상담기록을 선택해주세요.');
        return;
    }
    
    const postItem = selectedCheckbox.closest('.post-item');
    const boardId = postItem.getAttribute('data-id');
    
    if (!confirm(`선택한 상담기록에 ${memberName} 회원을 연결하시겠습니까?`)) {
        return;
    }
    
    fetch('register_member_request.php', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: `board_id=${boardId}&member_id=${memberId}`
    })
    .then(response => response.json())
    .then(data => {
        if (data.success) {
            alert(`성공적으로 ${memberName} 회원이 등록되었습니다.`);
            
            // 즉시 UI 업데이트 - 등록완료 표시
            postItem.classList.add('registered');
            const checkbox = postItem.querySelector('.post-item-checkbox');
            checkbox.disabled = true;
            checkbox.checked = false;
            
            // 제목 옆에 등록완료 배지 추가
            const titleLabel = postItem.querySelector('.post-item-title');
            if (!titleLabel.querySelector('.registration-badge')) {
                const badge = document.createElement('span');
                badge.className = 'registration-badge';
                badge.textContent = '회원등록완료';
                titleLabel.appendChild(badge);
            }
            
            // 이벤트 리스너 제거
            postItem.replaceWith(postItem.cloneNode(true));
            
            // 모달 닫기 및 상담기록 탭 새로고침
            setTimeout(() => {
                closeSelectMemberModal();
                window.location.href = 'board_list.php?type=상담기록';
            }, 800);
        } else {
            alert('등록 실패: ' + (data.message || '알 수 없는 오류가 발생했습니다.'));
        }
    })
    .catch(error => {
        console.error('Error:', error);
        alert('회원 등록 중 오류가 발생했습니다.');
    });
}

// 회원 선택 모달 닫기
function closeSelectMemberModal() {
    document.getElementById('selectMemberModal').style.display = 'none';
    document.body.style.overflow = ''; // 스크롤 복원
}

// 회원 검색 입력 필드의 엔터 키 처리 
document.addEventListener('DOMContentLoaded', function() {
    const memberSearchInput = document.getElementById('memberSearchInput');
    if (memberSearchInput) {
        memberSearchInput.addEventListener('keypress', function(e) {
            if (e.key === 'Enter') {
                e.preventDefault();
                searchMembers();
            }
        });
    }
});

// 게시글 모달에서 회원 매핑 모달 열기
function openMapMemberModal() {
    document.getElementById('mapMemberSearchInput').value = '';
    document.getElementById('mapMemberModal').style.display = 'block';
    
    // 회원 목록 초기 로드
    loadMembersForMap(1);
}

// 게시글 모달에서 회원 매핑 모달 닫기
function closeMapMemberModal() {
    document.getElementById('mapMemberModal').style.display = 'none';
}

// 회원 매핑을 위한 회원 목록 로드
function loadMembersForMap(page = 1) {
    const memberListBody = document.getElementById('mapMemberListBody');
    memberListBody.innerHTML = `
        <tr>
            <td colspan="4" class="loading-td">
                <div class="loading-indicator">
                    <i class="fas fa-spinner fa-pulse"></i> 회원 정보를 로딩 중입니다...
                </div>
            </td>
        </tr>
    `;
    
    fetch('../menu_member/get_initial_members.php?page=' + page)
        .then(response => response.json())
        .then(data => {
            if (data.success) {
                renderMembersForMap(data.members, data.total_pages, page);
            } else {
                memberListBody.innerHTML = '<tr><td colspan="4">회원 정보를 불러오는 중 오류가 발생했습니다.</td></tr>';
            }
        })
        .catch(error => {
            console.error('Error:', error);
            memberListBody.innerHTML = '<tr><td colspan="4">회원 정보를 불러오는 중 오류가 발생했습니다.</td></tr>';
        });
}

// 회원 매핑을 위한 회원 목록 렌더링
function renderMembersForMap(members, totalPages, currentPage) {
    const memberListBody = document.getElementById('mapMemberListBody');
    memberListBody.innerHTML = '';
    
    if (members.length === 0) {
        memberListBody.innerHTML = '<tr><td colspan="4">표시할 회원 정보가 없습니다.</td></tr>';
        return;
    }
    
    members.forEach(member => {
        const row = document.createElement('tr');
        row.innerHTML = `
            <td>${member.member_id}</td>
            <td>${member.member_name}</td>
            <td>${member.member_phone}</td>
            <td>
                <button type="button" class="select-btn" 
                        onclick="mapMemberToPost(${member.member_id}, '${member.member_name}')">
                    선택
                </button>
            </td>
        `;
        memberListBody.appendChild(row);
    });
    
    // 페이지네이션 처리
    renderMapMemberPagination(totalPages, currentPage);
}

// 회원 매핑을 위한 페이지네이션 렌더링
function renderMapMemberPagination(totalPages, currentPage) {
    const paginationEl = document.getElementById('mapMemberPagination');
    paginationEl.innerHTML = '';
    
    if (totalPages <= 1) return;
    
    const startPage = Math.max(1, currentPage - 2);
    const endPage = Math.min(totalPages, currentPage + 2);
    
    // 이전 페이지 버튼
    if (currentPage > 1) {
        const prevBtn = document.createElement('a');
        prevBtn.href = '#';
        prevBtn.innerHTML = '&laquo;';
        prevBtn.addEventListener('click', (e) => {
            e.preventDefault();
            const searchTerm = document.getElementById('mapMemberSearchInput').value.trim();
            if (searchTerm) {
                searchMembersForMap(currentPage - 1);
            } else {
                loadMembersForMap(currentPage - 1);
            }
        });
        paginationEl.appendChild(prevBtn);
    }
    
    // 페이지 번호 버튼
    for (let i = startPage; i <= endPage; i++) {
        const pageLink = document.createElement('a');
        pageLink.href = '#';
        pageLink.innerText = i;
        if (i === currentPage) {
            pageLink.classList.add('active');
        }
        pageLink.addEventListener('click', (e) => {
            e.preventDefault();
            const searchTerm = document.getElementById('mapMemberSearchInput').value.trim();
            if (searchTerm) {
                searchMembersForMap(i);
            } else {
                loadMembersForMap(i);
            }
        });
        paginationEl.appendChild(pageLink);
    }
    
    // 다음 페이지 버튼
    if (currentPage < totalPages) {
        const nextBtn = document.createElement('a');
        nextBtn.href = '#';
        nextBtn.innerHTML = '&raquo;';
        nextBtn.addEventListener('click', (e) => {
            e.preventDefault();
            const searchTerm = document.getElementById('mapMemberSearchInput').value.trim();
            if (searchTerm) {
                searchMembersForMap(currentPage + 1);
            } else {
                loadMembersForMap(currentPage + 1);
            }
        });
        paginationEl.appendChild(nextBtn);
    }
}

// 회원 매핑을 위한 회원 검색
function searchMembersForMap(page = 1) {
    const searchTerm = document.getElementById('mapMemberSearchInput').value.trim();
    const memberListBody = document.getElementById('mapMemberListBody');
    
    if (searchTerm === '') {
        // 검색어가 비어있으면 초기 회원 목록 로드
        loadMembersForMap(page);
        return;
    }
    
    memberListBody.innerHTML = `
        <tr>
            <td colspan="4" class="loading-td">
                <div class="loading-indicator">
                    <i class="fas fa-spinner fa-pulse"></i> 검색 중입니다...
                </div>
            </td>
        </tr>
    `;
    
    fetch(`search_members.php?term=${encodeURIComponent(searchTerm)}&page=${page}`)
        .then(response => response.json())
        .then(data => {
            if (data.success) {
                renderMembersForMap(data.members, data.total_pages, page);
            } else {
                memberListBody.innerHTML = '<tr><td colspan="4">검색 중 오류가 발생했습니다: ' + (data.message || '알 수 없는 오류') + '</td></tr>';
            }
        })
        .catch(error => {
            console.error('Error:', error);
            memberListBody.innerHTML = '<tr><td colspan="4">검색 중 오류가 발생했습니다.</td></tr>';
        });
}

// 게시글에 회원 매핑
function mapMemberToPost(memberId, memberName) {
    const boardId = document.getElementById('viewPostModal').getAttribute('data-post-id');
    
    if (!confirm(`이 상담기록에 ${memberName} 회원을 등록하시겠습니까?`)) {
        return;
    }
    
    fetch('register_member_request.php', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: `board_id=${boardId}&member_id=${memberId}`
    })
    .then(response => response.json())
    .then(data => {
        if (data.success) {
            alert(`성공적으로 ${memberName} 회원이 등록되었습니다.`);
            
            // 회원 매핑 모달 닫기
            closeMapMemberModal();
            
            // 게시글 모달도 닫기
            closeViewModal();
            
            // 페이지 새로고침
            location.reload();
        } else {
            alert('등록 실패: ' + (data.message || '알 수 없는 오류가 발생했습니다.'));
        }
    })
    .catch(error => {
        console.error('Error:', error);
        alert('회원 등록 중 오류가 발생했습니다.');
    });
}

// 회원 매핑 검색 입력 필드의 엔터 키 처리
document.addEventListener('DOMContentLoaded', function() {
    const mapMemberSearchInput = document.getElementById('mapMemberSearchInput');
    if (mapMemberSearchInput) {
        mapMemberSearchInput.addEventListener('keypress', function(e) {
            if (e.key === 'Enter') {
                e.preventDefault();
                searchMembersForMap();
            }
        });
    }
});
</script>

</body>
</html>