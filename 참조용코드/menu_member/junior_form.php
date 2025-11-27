<?php
require_once '../config/db_connect.php';

// 수정 시 주니어 정보 조회
$junior = null;
if (isset($_GET['id'])) {
    $stmt = $db->prepare('
        SELECT 
            j.*,
            jr.relation
        FROM Junior j
        LEFT JOIN Junior_relation jr ON j.junior_id = jr.junior_id
        WHERE j.junior_id = ?
    ');
    $stmt->bind_param('i', $_GET['id']);
    $stmt->execute();
    $junior = $stmt->get_result()->fetch_assoc();
}

// 부모 회원 ID 가져오기
$member_id = isset($_GET['member_id']) ? $_GET['member_id'] : null;
if (!$member_id) {
    die('회원 정보가 없습니다.');
}

// 회원 이름 조회 - 테이블 이름을 members로 수정
$stmt = $db->prepare('SELECT member_name FROM members WHERE member_id = ?');
$stmt->bind_param('i', $member_id);
$stmt->execute();
$member_result = $stmt->get_result();
$member = $member_result->fetch_assoc();
$member_name = $member['member_name'];

// 돌아갈 탭 정보
$return_tab = isset($_GET['return_tab']) ? $_GET['return_tab'] : 'juniors';
?>

<!DOCTYPE html>
<html lang="ko">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title><?php echo $junior ? '의 자녀회원 수정입니다.' : '의 자녀회원 등록입니다.'; ?></title>
    <link rel="stylesheet" href="../assets/css/style.css">
    <style>
        .container {
            max-width: 800px;
            margin: 20px auto;
            padding: 20px;
            background: #fff;
            border-radius: 5px;
            box-shadow: 0 2px 5px rgba(0,0,0,0.1);
        }

        .form-group {
            margin-bottom: 15px;
        }

        .form-group label {
            display: block;
            margin-bottom: 5px;
            font-weight: bold;
        }

        .form-group input, .form-group select {
            width: 100%;
            padding: 8px;
            border: 1px solid #ddd;
            border-radius: 4px;
        }

        .btn-container {
            margin-top: 20px;
            text-align: right;
        }

        .btn {
            padding: 8px 15px;
            margin-left: 10px;
            border: none;
            border-radius: 4px;
            cursor: pointer;
        }

        .btn-primary {
            background-color: #007bff;
            color: white;
        }

        .btn-secondary {
            background-color: #6c757d;
            color: white;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>
            <?php echo htmlspecialchars($member_name); ?> 회원
            <?php echo $junior?'님 의 자녀회원 수정입니다' :'님 의 자녀회원 등록입니다'; ?>
        </h1>
        
        <form id="juniorForm" action="junior_process.php" method="POST">
            <input type="hidden" name="member_id" value="<?php echo htmlspecialchars($member_id); ?>">
            <?php if ($junior) : ?>
                <input type="hidden" name="junior_id" value="<?php echo $junior['junior_id']; ?>">
            <?php endif; ?>
            <input type="hidden" name="return_tab" value="<?php echo htmlspecialchars($return_tab); ?>">

            <div class="form-group">
                <label for="junior_name" class="required">이름</label>
                <input type="text" id="junior_name" name="junior_name" required
                    value="<?php echo $junior ? htmlspecialchars($junior['junior_name']) : ''; ?>">
            </div>

            <div class="form-group">
                <label for="junior_school">학교</label>
                <input type="text" id="junior_school" name="junior_school"
                    value="<?php echo $junior ? htmlspecialchars($junior['junior_school']) : ''; ?>">
            </div>

            <div class="form-group">
                <label for="junior_birthday">생년월일</label>
                <input type="date" id="junior_birthday" name="junior_birthday"
                    value="<?php echo $junior ? $junior['junior_birthday'] : ''; ?>">
            </div>

            <div class="form-group">
                <label for="relation">관계</label>
                <select id="relation" name="relation" required>
                    <option value="">선택하세요</option>
                    <option value="부" <?php echo ($junior && $junior['relation'] == '부') ? 'selected' : ''; ?>>부</option>
                    <option value="모" <?php echo ($junior && $junior['relation'] == '모') ? 'selected' : ''; ?>>모</option>
                </select>
            </div>

            <div class="btn-container">
                <button type="button" class="btn btn-secondary" onclick="goBack()">취소</button>
                <button type="submit" class="btn btn-primary">저장</button>
            </div>
        </form>
    </div>

    <script>
    function goBack() {
        const memberId = <?php echo $member_id; ?>;
        const returnTab = '<?php echo $return_tab; ?>';
        window.location.href = `member_form.php?id=${memberId}#${returnTab}`;
    }
    </script>
</body>
</html> 