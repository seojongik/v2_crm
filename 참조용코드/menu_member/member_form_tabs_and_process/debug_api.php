<?php
// 데이터베이스 연결
require_once '../../config/db_connect.php';

// 헤더 설정
header('Content-Type: text/html; charset=utf-8');

// 설정
$member_id = isset($_GET['member_id']) ? intval($_GET['member_id']) : 44; // 기본값 설정

echo '<h1>API 디버깅 페이지</h1>';
echo '<h2>Staff 테이블 구조</h2>';

// Staff 테이블 구조 확인
try {
    $result = $db->query("DESCRIBE Staff");
    echo '<table border="1">';
    echo '<tr><th>필드</th><th>타입</th><th>Null</th><th>키</th><th>기본값</th><th>추가</th></tr>';
    while ($row = $result->fetch_assoc()) {
        echo '<tr>';
        echo '<td>' . htmlspecialchars($row['Field']) . '</td>';
        echo '<td>' . htmlspecialchars($row['Type']) . '</td>';
        echo '<td>' . htmlspecialchars($row['Null']) . '</td>';
        echo '<td>' . htmlspecialchars($row['Key']) . '</td>';
        echo '<td>' . htmlspecialchars($row['Default']) . '</td>';
        echo '<td>' . htmlspecialchars($row['Extra']) . '</td>';
        echo '</tr>';
    }
    echo '</table>';
} catch (Exception $e) {
    echo '<p style="color:red">Staff 테이블 구조 확인 실패: ' . htmlspecialchars($e->getMessage()) . '</p>';
}

echo '<h2>Staff 데이터 목록 (프로만)</h2>';

// Staff 데이터 확인
try {
    $result = $db->query("SELECT * FROM Staff WHERE staff_type = '프로' ORDER BY staff_name");
    if ($result->num_rows > 0) {
        echo '<table border="1">';
        // 헤더 출력
        $first_row = $result->fetch_assoc();
        $result->data_seek(0);
        echo '<tr>';
        foreach (array_keys($first_row) as $key) {
            echo '<th>' . htmlspecialchars($key) . '</th>';
        }
        echo '</tr>';
        
        // 데이터 출력
        while ($row = $result->fetch_assoc()) {
            echo '<tr>';
            foreach ($row as $key => $value) {
                echo '<td>' . htmlspecialchars($value ?: 'NULL') . '</td>';
            }
            echo '</tr>';
        }
        echo '</table>';
    } else {
        echo '<p>프로 데이터가 없습니다.</p>';
    }
} catch (Exception $e) {
    echo '<p style="color:red">Staff 데이터 확인 실패: ' . htmlspecialchars($e->getMessage()) . '</p>';
}

echo '<h2>member_pro_match 테이블 구조</h2>';

// member_pro_match 테이블 구조 확인
try {
    $result = $db->query("DESCRIBE member_pro_match");
    echo '<table border="1">';
    echo '<tr><th>필드</th><th>타입</th><th>Null</th><th>키</th><th>기본값</th><th>추가</th></tr>';
    while ($row = $result->fetch_assoc()) {
        echo '<tr>';
        echo '<td>' . htmlspecialchars($row['Field']) . '</td>';
        echo '<td>' . htmlspecialchars($row['Type']) . '</td>';
        echo '<td>' . htmlspecialchars($row['Null']) . '</td>';
        echo '<td>' . htmlspecialchars($row['Key']) . '</td>';
        echo '<td>' . htmlspecialchars($row['Default']) . '</td>';
        echo '<td>' . htmlspecialchars($row['Extra']) . '</td>';
        echo '</tr>';
    }
    echo '</table>';
} catch (Exception $e) {
    echo '<p style="color:red">member_pro_match 테이블 구조 확인 실패: ' . htmlspecialchars($e->getMessage()) . '</p>';
}

echo '<h2>member_pro_match 데이터</h2>';

// member_pro_match 데이터 확인
try {
    $stmt = $db->prepare("SELECT * FROM member_pro_match WHERE member_id = ? ORDER BY registered_at DESC");
    $stmt->bind_param('i', $member_id);
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($result->num_rows > 0) {
        echo '<table border="1">';
        // 헤더 출력
        $first_row = $result->fetch_assoc();
        $result->data_seek(0);
        echo '<tr>';
        foreach (array_keys($first_row) as $key) {
            echo '<th>' . htmlspecialchars($key) . '</th>';
        }
        echo '</tr>';
        
        // 데이터 출력
        while ($row = $result->fetch_assoc()) {
            echo '<tr>';
            foreach ($row as $key => $value) {
                echo '<td>' . htmlspecialchars($value ?: 'NULL') . '</td>';
            }
            echo '</tr>';
        }
        echo '</table>';
    } else {
        echo '<p>회원 ' . $member_id . '에 대한 프로 매핑 데이터가 없습니다.</p>';
    }
} catch (Exception $e) {
    echo '<p style="color:red">member_pro_match 데이터 확인 실패: ' . htmlspecialchars($e->getMessage()) . '</p>';
}

// 다른 회원 ID로 테스트할 수 있는 링크 제공
echo '<h2>다른 회원으로 테스트</h2>';
echo '<form action="" method="GET">';
echo '회원 ID: <input type="number" name="member_id" value="' . $member_id . '">';
echo '<input type="submit" value="테스트">';
echo '</form>';

// get_pro_list.php 테스트 링크
echo '<h2>get_pro_list.php 직접 테스트</h2>';
echo '<a href="get_pro_list.php?member_id=' . $member_id . '" target="_blank">get_pro_list.php 테스트</a>';

$db->close();
?> 