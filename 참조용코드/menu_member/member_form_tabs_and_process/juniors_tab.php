<?php
// 주니어 탭 컨텐츠 - iframe 사용하여 독립적인 환경으로 로드
$is_standalone = !isset($member_id);

// 독립 실행 모드 처리
if ($is_standalone) {
    require_once dirname(__FILE__) . '/../../config/db_connect.php';
    
    if (!isset($_GET['member_id'])) {
        echo '<div class="alert alert-danger">필수 파라미터가 전달되지 않았습니다.</div>';
        exit;
    }
    
    $member_id = intval($_GET['member_id']);
}
?>

<style>
.juniors-iframe {
    width: 100%;
    min-height: 500px;
    border: none;
    overflow: hidden;
}

.error-message {
    background-color: #f8d7da;
    color: #721c24;
    padding: 12px;
    border-radius: 4px;
    margin-bottom: 20px;
    border: 1px solid #f5c6cb;
    text-align: center;
}
</style>

<!-- iframe으로 주니어 컨텐츠 로드 -->
<iframe 
    id="juniors-iframe" 
    class="juniors-iframe" 
    src="member_form_tabs_and_process/juniors_content.php?member_id=<?php echo $member_id; ?>"
    title="주니어 탭 컨텐츠"
    scrolling="no"
    loading="lazy"
></iframe>

<script>
// iframe 높이 자동 조정 기능
window.addEventListener('message', function(event) {
    // 메시지가 resize 타입인지 확인
    if (event.data && event.data.type === 'resize') {
        const iframe = document.getElementById('juniors-iframe');
        if (iframe) {
            // 여유 공간을 위해 약간의 패딩 추가
            iframe.style.height = (event.data.height + 20) + 'px';
        }
    }
});

// iframe 로딩 오류 처리
document.getElementById('juniors-iframe').onerror = function() {
    this.style.display = 'none';
    const errorDiv = document.createElement('div');
    errorDiv.className = 'error-message';
    errorDiv.innerHTML = '<i class="fa fa-exclamation-triangle"></i> 주니어 탭을 로드하는 중 오류가 발생했습니다.';
    this.parentNode.insertBefore(errorDiv, this);
};
</script>

<?php echo "<!-- 주니어 탭 iframe 로드 완료 -->"; ?> 