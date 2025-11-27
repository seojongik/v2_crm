<?php
require_once '../../config/db_connect.php';

$contract_history = null;
if (isset($_GET['id'])) {
    $stmt = $db->prepare('
        SELECT 
            ch.*,
            c.contract_type,
            c.contract_name,
            c.contract_credit,
            c.contract_LS,
            c.sell_by_credit_price
        FROM contract_history ch
        JOIN contracts c ON ch.contract_id = c.contract_id
        WHERE ch.contract_history_id = ?
    ');
    $stmt->bind_param('i', $_GET['id']);
    $stmt->execute();
    $result = $stmt->get_result();
    $contract_history = $result->fetch_assoc();
    
    if ($contract_history) {
        $_GET['member_id'] = $contract_history['member_id'];
    }
}

if (!isset($_GET['member_id'])) {
    header('Location: ../member_list.php');
    exit;
}

$member_id = $_GET['member_id'];

// 직원 정보 조회
$stmt = $db->prepare('SELECT * FROM members WHERE member_id = ?');
$stmt->bind_param('i', $member_id);
$stmt->execute();
$result = $stmt->get_result();
$member = $result->fetch_assoc();

if (!$member) {
    header('Location: ../member_list.php');
    exit;
}

// contracts 테이블에서 유효한 계약들을 회원권 유형별로 정렬하여 조회
$category = isset($_GET['category']) ? $_GET['category'] : '회원권';

$contracts_query = "
    SELECT * FROM contracts 
    WHERE contract_status = '유효'
    AND contract_category = ?
    ORDER BY 
        CASE contract_type
            WHEN '크레딧' THEN 1
            WHEN '레슨권' THEN 2
            WHEN '패키지' THEN 3
            WHEN '기간권' THEN 4
            WHEN '식음료' THEN 5
            WHEN '상품' THEN 6
            ELSE 7
        END,
        CASE WHEN contract_name LIKE '%프렌즈%' THEN 0 ELSE 1 END,
        contract_id
";

$stmt = $db->prepare($contracts_query);
$stmt->bind_param('s', $category);
$stmt->execute();
$contracts_result = $stmt->get_result();
$contracts = [];
while ($row = $contracts_result->fetch_assoc()) {
    $contracts[] = $row;
}

// 계약 유형 목록 조회
$types_query = "
    SELECT DISTINCT contract_type 
    FROM contracts 
    WHERE contract_category = '회원권'
    ORDER BY 
        CASE contract_type
            WHEN '크레딧' THEN 1
            WHEN '레슨권' THEN 2
            WHEN '패키지' THEN 3
            WHEN '기간권' THEN 4
            ELSE 5
        END
";
$types_result = $db->query($types_query);
?>

<!DOCTYPE html>
<html lang="ko">
<head>
    <meta charset="UTF-8">
    <title><?php echo $contract_history ? '회원권 수정' : '회원권 등록'; ?></title>
    <!-- 스타일시트는 동적으로 추가됩니다 -->
    <script>
    // 외부 리소스 동적 로드
    document.addEventListener('DOMContentLoaded', function() {
        console.log('contract_form.php 초기화');
        
        // FontAwesome 아이콘 라이브러리 추가 (CDN)
        if (!document.getElementById('fontawesome-css')) {
            const link = document.createElement('link');
            link.id = 'fontawesome-css';
            link.rel = 'stylesheet';
            link.href = 'https://cdnjs.cloudflare.com/ajax/libs/font-awesome/5.15.4/css/all.min.css';
            document.head.appendChild(link);
            console.log('FontAwesome 추가됨');
        }

        // Google Noto Sans KR 폰트 추가
        if (!document.getElementById('noto-sans-kr')) {
            const link = document.createElement('link');
            link.id = 'noto-sans-kr';
            link.rel = 'stylesheet';
            link.href = 'https://fonts.googleapis.com/css2?family=Noto+Sans+KR:wght@400;500;700&display=swap';
            document.head.appendChild(link);
            console.log('Noto Sans KR 폰트 추가됨');
        }
    });
    </script>
    <style>
        body {
            font-family: 'Noto Sans KR', sans-serif;
            background-color: #f8f9fa;
            color: #333;
            margin: 0;
            padding: 0;
            line-height: 1.6;
        }
        
        .container {
            max-width: 1000px;
            margin: 30px auto;
            padding: 30px;
            background: white;
            border-radius: 15px;
            box-shadow: 0 5px 25px rgba(0,0,0,0.08);
        }

        h1, h2 {
            color: #2c3e50;
            margin-bottom: 20px;
            text-align: center;
        }
        
        h1 {
            font-size: 26px;
            font-weight: 700;
            margin-top: 0;
            position: relative;
            padding-bottom: 15px;
        }
        
        h1:after {
            content: '';
            position: absolute;
            bottom: 0;
            left: 50%;
            transform: translateX(-50%);
            width: 80px;
            height: 3px;
            background: linear-gradient(to right, #36d1dc, #5b86e5);
            border-radius: 3px;
        }
        
        h2 {
            font-size: 20px;
            color: #5b86e5;
            font-weight: 500;
        }
        
        label {
            display: block;
            margin-bottom: 8px;
            font-weight: 600;
            color: #444;
        }
        
        label.required:after {
            content: '*';
            color: #e74c3c;
            margin-left: 4px;
        }

        .modal {
            display: none;
            position: fixed;
            z-index: 1000;
            left: 0;
            top: 0;
            width: 100%;
            height: 100%;
            background-color: rgba(0,0,0,0.4);
        }

        .modal-content {
            background-color: #fefefe;
            margin: 15% auto;
            padding: 25px;
            border: none;
            width: 80%;
            max-width: 500px;
            border-radius: 15px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.1);
        }

        .modal-header {
            margin-bottom: 20px;
            position: relative;
            border-bottom: 1px solid #f1f1f1;
            padding-bottom: 15px;
        }
        
        .modal-header h2 {
            text-align: left;
            margin: 0;
            padding: 0;
            font-size: 20px;
        }

        .modal-body {
            margin-bottom: 25px;
        }

        .modal-footer {
            text-align: right;
            display: flex;
            justify-content: flex-end;
            gap: 10px;
        }

        .close {
            position: absolute;
            right: 0;
            top: 0;
            color: #aaa;
            font-size: 24px;
            font-weight: bold;
            cursor: pointer;
            transition: all 0.3s;
        }

        .close:hover {
            color: #5b86e5;
        }

        /* 버튼 기본 스타일 */
        .btn, .btn-save {
            display: inline-flex;
            align-items: center;
            justify-content: center;
            padding: 10px 16px;
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
            min-width: 120px;
        }

        /* 저장 버튼 (파란색 계열 그라데이션) */
        .btn-save, button[type="submit"] {
            background: linear-gradient(to right, #36d1dc, #5b86e5);
            color: white;
        }

        .btn-save:hover, button[type="submit"]:hover {
            background: linear-gradient(to right, #5b86e5, #36d1dc);
            transform: translateY(-2px);
            box-shadow: 0 5px 15px rgba(91, 134, 229, 0.4);
        }

        /* 일반 버튼 (하늘색 계열 그라데이션) */
        .btn {
            background: linear-gradient(to right, #a1c4fd, #c2e9fb);
            color: #2c3e50;
        }

        .btn:hover {
            background: linear-gradient(to right, #c2e9fb, #a1c4fd);
            transform: translateY(-2px);
            box-shadow: 0 5px 15px rgba(161, 196, 253, 0.4);
            border-color: transparent;
        }

        .btn.selected {
            background: linear-gradient(to right, #5b86e5, #36d1dc);
            color: white;
            border-color: transparent;
        }

        .btn.disabled {
            opacity: 0.6;
            cursor: not-allowed;
            transform: none;
            box-shadow: none;
        }

        .contract-grid {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 30px;
            margin-bottom: 40px;
        }

        .contract-selection {
            background: white;
            padding: 25px;
            border-radius: 15px;
            box-shadow: 0 5px 20px rgba(0,0,0,0.05);
            border-left: 4px solid #5b86e5;
            transition: all 0.3s ease;
        }
        
        .contract-selection:hover {
            box-shadow: 0 8px 25px rgba(91, 134, 229, 0.15);
        }

        .contract-info {
            background: white;
            padding: 25px;
            border-radius: 15px;
            box-shadow: 0 5px 20px rgba(0,0,0,0.05);
            border-left: 4px solid #36d1dc;
            transition: all 0.3s ease;
        }
        
        .contract-info:hover {
            box-shadow: 0 8px 25px rgba(54, 209, 220, 0.15);
        }

        .form-group {
            margin-bottom: 25px;
        }

        .info-grid {
            display: grid;
            grid-template-columns: repeat(3, 1fr);
            gap: 20px;
            margin-top: 20px;
        }

        .info-item {
            text-align: center;
            padding: 20px;
            background: #f8f9fa;
            border-radius: 12px;
            transition: all 0.3s ease;
            border: 1px solid rgba(0,0,0,0.05);
        }
        
        .info-item:hover {
            transform: translateY(-5px);
            box-shadow: 0 10px 20px rgba(0,0,0,0.05);
        }

        .info-item label {
            display: block;
            margin-bottom: 10px;
            color: #5b86e5;
            font-size: 0.95em;
            font-weight: 700;
        }

        .info-item input {
            width: 100%;
            padding: 12px;
            border: 1px solid #e0e0e0;
            border-radius: 50px;
            text-align: center;
            font-size: 1.2em;
            font-weight: bold;
            color: #2c3e50;
            background: white;
            transition: all 0.3s;
            box-shadow: inset 0 1px 3px rgba(0,0,0,0.05);
        }
        
        .info-item input:focus {
            border-color: #5b86e5;
            outline: none;
            box-shadow: 0 0 0 3px rgba(91, 134, 229, 0.2);
        }

        .button-group {
            display: flex;
            flex-wrap: wrap;
            gap: 10px;
            margin-bottom: 25px;
        }

        .contract-list {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(140px, 1fr));
            gap: 12px;
            margin-top: 15px;
        }

        .contract-item {
            padding: 12px;
            border: none;
            border-radius: 12px;
            background: linear-gradient(to bottom right, #f1f1f1, #e9ecef);
            cursor: pointer;
            text-align: center;
            transition: all 0.3s ease;
            font-size: 13px;
            display: flex;
            align-items: center;
            justify-content: center;
            min-height: 50px;
            word-break: keep-all;
            line-height: 1.4;
            font-weight: 600;
            color: #555;
            box-shadow: 0 2px 5px rgba(0,0,0,0.05);
        }

        .contract-item:hover {
            background: linear-gradient(to right, #e7f0fd, #d8e9ff);
            transform: translateY(-3px);
            box-shadow: 0 5px 15px rgba(91, 134, 229, 0.2);
            color: #2c3e50;
        }

        .contract-item.selected {
            background: linear-gradient(to right, #5b86e5, #36d1dc);
            color: white;
        }

        .payment-options {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(130px, 1fr));
            gap: 15px;
            margin-top: 25px;
        }

        .payment-option {
            padding: 15px 10px;
            text-align: center;
            background: #f8f9fa;
            border: none;
            border-radius: 12px;
            cursor: pointer;
            transition: all 0.3s ease;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            min-height: 80px;
            font-size: 14px;
            box-shadow: 0 3px 10px rgba(0,0,0,0.05);
        }

        .payment-option i {
            font-size: 24px;
            margin-bottom: 8px;
            color: #5b86e5;
        }

        .payment-option:hover {
            background: linear-gradient(to right, #e7f0fd, #d8e9ff);
            transform: translateY(-3px);
            box-shadow: 0 8px 20px rgba(91, 134, 229, 0.2);
        }

        .payment-option.selected {
            background: linear-gradient(to right, #5b86e5, #36d1dc);
            color: white;
        }
        
        .payment-option.selected i {
            color: white;
        }

        .payment-option.disabled {
            opacity: 0.5;
            cursor: not-allowed;
            transform: none;
            box-shadow: none;
        }

        .date-section {
            max-width: 300px;
            margin: 0 auto 30px;
        }

        input[type="date"] {
            width: 100%;
            padding: 12px 15px;
            border: 1px solid #e0e0e0;
            border-radius: 50px;
            font-size: 14px;
            text-align: center;
            background: white;
            transition: all 0.3s;
            box-shadow: inset 0 1px 3px rgba(0,0,0,0.05);
            font-family: 'Noto Sans KR', sans-serif;
        }
        
        input[type="date"]:focus {
            border-color: #5b86e5;
            outline: none;
            box-shadow: 0 0 0 3px rgba(91, 134, 229, 0.2);
        }

        .form-actions {
            display: flex;
            justify-content: center;
            gap: 15px;
            margin-top: 30px;
            padding-top: 20px;
            border-top: 1px solid #f1f1f1;
        }
        
        .form-actions .btn, 
        .form-actions button[type="submit"] {
            min-width: 150px;
            padding: 12px 24px;
        }

        @media (max-width: 768px) {
            .container {
                padding: 20px;
                margin: 15px;
            }
            
            .contract-grid {
                grid-template-columns: 1fr;
            }
            
            .info-grid {
                grid-template-columns: 1fr;
            }
            
            .payment-options {
                grid-template-columns: repeat(2, 1fr);
            }
        }

        /* 프로 선택 모달과 주니어 선택 모달 스타일 개선 */
        .junior-table,
        .pro-table {
            width: 100%;
            border-collapse: collapse;
            margin: 15px 0;
            font-size: 14px;
            box-shadow: 0 3px 15px rgba(0,0,0,0.05);
            border-radius: 12px;
            overflow: hidden;
        }

        .junior-table th, 
        .junior-table td,
        .pro-table th, 
        .pro-table td {
            padding: 12px 15px;
            text-align: left;
            border: none;
        }

        .junior-table th,
        .pro-table th {
            background-color: #f1f1f1;
            color: #333;
            font-weight: 600;
            text-align: center;
            border-bottom: 1px solid #dee2e6;
        }

        .junior-table tr:nth-child(even),
        .pro-table tr:nth-child(even) {
            background-color: #f8f9fa;
        }

        .junior-table tr:hover,
        .pro-table tr:hover {
            background-color: #e7f0fd;
            transition: background-color 0.3s ease;
        }

        /* 라디오 버튼 스타일 개선 */
        .junior-table input[type="radio"],
        .pro-table input[type="radio"] {
            appearance: none;
            -webkit-appearance: none;
            width: 20px;
            height: 20px;
            border: 2px solid #ddd;
            border-radius: 50%;
            outline: none;
            cursor: pointer;
            position: relative;
            vertical-align: middle;
            margin: 0 auto;
            display: block;
            transition: all 0.3s ease;
        }

        .junior-table input[type="radio"]:checked,
        .pro-table input[type="radio"]:checked {
            border-color: #5b86e5;
            background-color: #fff;
        }

        .junior-table input[type="radio"]:checked:after,
        .pro-table input[type="radio"]:checked:after {
            content: '';
            position: absolute;
            top: 50%;
            left: 50%;
            transform: translate(-50%, -50%);
            width: 10px;
            height: 10px;
            border-radius: 50%;
            background: linear-gradient(to right, #5b86e5, #36d1dc);
        }

        /* 선택된 프로/주니어 정보 스타일 개선 */
        .selected-junior-info,
        .selected-pro-info {
            margin: 15px 0;
            padding: 15px;
            border-radius: 12px;
            background: linear-gradient(to right, rgba(91, 134, 229, 0.1), rgba(54, 209, 220, 0.1));
            display: flex;
            align-items: center;
            box-shadow: 0 3px 10px rgba(0,0,0,0.03);
            border-left: 4px solid #5b86e5;
            font-weight: 500;
            color: #2c3e50;
        }

        .selected-junior-info:before,
        .selected-pro-info:before {
            content: '\f007'; /* FontAwesome user icon */
            font-family: 'Font Awesome 5 Free';
            font-weight: 900;
            margin-right: 10px;
            font-size: 18px;
            color: #5b86e5;
            width: 30px;
            height: 30px;
            line-height: 30px;
            text-align: center;
            background: white;
            border-radius: 50%;
            box-shadow: 0 3px 5px rgba(0,0,0,0.1);
        }

        .selected-pro-info:before {
            content: '\f0b1'; /* FontAwesome briefcase icon for pro */
        }

        .no-juniors,
        .no-pros {
            text-align: center;
            padding: 30px;
            background-color: #f8f9fa;
            border-radius: 12px;
            color: #6c757d;
            font-style: italic;
            margin: 20px 0;
        }

        /* 버튼 균일 크기 */
        .form-actions .btn,
        .form-actions .btn-save {
            min-width: 150px;
            padding: 12px 24px;
            flex: 1; /* 버튼들이 동일한 너비를 가지도록 함 */
            max-width: 200px;
        }

        .modal-footer .btn,
        .modal-footer .btn-save {
            min-width: 120px;
            flex: 1;
            margin: 0 5px;
        }

        @media (max-width: 768px) {
            .form-actions {
                flex-direction: column;
                gap: 10px;
            }
            
            .form-actions .btn,
            .form-actions .btn-save {
                max-width: 100%;
            }
            
            .modal-footer {
                flex-direction: column;
                gap: 10px;
            }
            
            .modal-footer .btn,
            .modal-footer .btn-save {
                width: 100%;
            }
        }

        /* 프로 변경 확인 모달 스타일 개선 */
        .pro-change-options {
            display: flex;
            gap: 15px;
            margin-top: 20px;
            flex-direction: column;
        }

        .pro-change-option {
            background-color: #f8f9fa;
            border: 1px solid #dee2e6;
            border-radius: 8px;
            padding: 15px;
            cursor: pointer;
            transition: all 0.2s;
        }

        .pro-change-option:hover {
            background-color: #e9ecef;
            border-color: #ced4da;
        }

        .pro-change-option div {
            font-weight: 600;
            color: #495057;
            margin-bottom: 5px;
        }

        .pro-change-option small {
            color: #6c757d;
            display: block;
        }

        /* 모달 테이블 색상 개선 */
        .junior-table th,
        .pro-table th {
            background-color: #f1f1f1;
            color: #333;
            font-weight: 600;
            text-align: center;
            border-bottom: 1px solid #dee2e6;
        }

        #multiple_pros_message {
            background-color: #fff3cd;
            border: 1px solid #ffeeba;
            color: #856404;
            padding: 10px;
            border-radius: 5px;
            margin-bottom: 15px;
        }

        #change_message {
            color: #495057;
            font-weight: 500;
            margin-bottom: 15px;
            line-height: 1.6;
        }

        /* 프로 선택 탭 제거 */
        .pro-tabs {
            display: none;
        }

        .modal-header h2 {
            color: #333;
            font-weight: 600;
        }

        /* 모달 내용 영역 스타일 간소화 */
        .modal-content {
            box-shadow: 0 5px 15px rgba(0,0,0,0.1);
            border-radius: 8px;
        }

        .modal-body {
            margin-bottom: 20px;
        }

        /* 프로 선택 모달 추가 */
        .pro-table {
            width: 100%;
            border-collapse: collapse;
            margin: 15px 0;
            font-size: 14px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.05);
            overflow: hidden;
        }

        .pro-table th, 
        .pro-table td {
            padding: 10px 15px;
            text-align: left;
            border-bottom: 1px solid #eee;
        }

        .pro-table th {
            background-color: #f8f9fa;
            color: #333;
            font-weight: 500;
            text-align: center;
        }

        .pro-table tr:hover {
            background-color: #f5f9ff;
        }

        .pro-table td:first-child {
            width: 60px;
            text-align: center;
        }

        /* 선택 버튼 스타일 개선 */
        .modal-footer .btn,
        .modal-footer .btn-save {
            background: #f8f9fa;
            color: #333;
            border: 1px solid #dee2e6;
            box-shadow: none;
            min-width: 100px;
            padding: 8px 16px;
        }

        .modal-footer .btn-save {
            background: #f8f9fa;
            color: #2c7be5;
            border-color: #2c7be5;
        }

        .modal-footer .btn:hover,
        .modal-footer .btn-save:hover {
            background: #f1f3f5;
            transform: none;
            box-shadow: none;
        }

        .modal-footer .btn-save:hover {
            background: #eaf2ff;
        }
    </style>
    <script>
    document.addEventListener('DOMContentLoaded', function() {
        const contractTypeButtons = document.getElementById('contract_type_buttons');
        const contractList = document.getElementById('contract_list');
        const contractTypeInput = document.getElementById('contract_type');
        const contractIdInput = document.getElementById('contract_id');
        const creditInput = document.getElementById('contract_credit');
        const lsInput = document.getElementById('contract_LS');
        const priceInput = document.getElementById('contract_price');
        const paymentTypeInput = document.getElementById('payment_type_input');
        const juniorModal = document.getElementById('juniorModal');
        const proModal = document.getElementById('proModal');
        let selectedJuniorId = null;
        let isJuniorProduct = false;
        let currentProNickname = null;
        let selectedProNickname = null;
        let hasMultiplePros = false;
        let allProMappings = [];

        // 계약 정보를 JavaScript 객체로 저장
        const contractsData = <?php echo json_encode($contracts); ?>;

        // 숫자 포맷 함수
        function formatNumber(number) {
            return new Intl.NumberFormat('ko-KR').format(number);
        }

        // 회원권 유형 버튼 클릭 이벤트
        contractTypeButtons.addEventListener('click', function(e) {
            if (e.target.classList.contains('btn')) {
                // 기존 선택 제거
                contractTypeButtons.querySelectorAll('.btn').forEach(btn => btn.classList.remove('selected'));
                
                // 새로운 선택 추가
                e.target.classList.add('selected');
                const selectedType = e.target.dataset.type;
                contractTypeInput.value = selectedType;
                
                // 계약 목록 업데이트
                updateContractList(selectedType);
            }
        });

        // 계약 목록 업데이트 함수
        function updateContractList(selectedType) {
            contractList.innerHTML = '';
            const filteredContracts = contractsData.filter(c => c.contract_type === selectedType);
            
            filteredContracts.forEach(contract => {
                const contractItem = document.createElement('div');
                contractItem.className = 'contract-item';
                contractItem.dataset.id = contract.contract_id;
                contractItem.textContent = contract.contract_name;
                
                contractItem.addEventListener('click', () => selectContract(contract, contractItem));
                contractList.appendChild(contractItem);
            });
        }

        // 계약 선택 함수
        function selectContract(contract, element) {
            // 기존 선택 제거
            contractList.querySelectorAll('.contract-item').forEach(item => item.classList.remove('selected'));
            
            // 새로운 선택 추가
            element.classList.add('selected');
            contractIdInput.value = contract.contract_id;
            
            // 정보 업데이트
            creditInput.value = contract.contract_credit;
            lsInput.value = contract.contract_LS;
            priceInput.value = formatNumber(contract.price) + '원';

            // 자유적립 크레딧인 경우 (c01) 입력 가능하게 설정
            if (contract.contract_id === 'c01') {
                creditInput.readOnly = false;
                creditInput.style.backgroundColor = '#fff3cd';
                creditInput.value = '';
                creditInput.placeholder = '크레딧을 입력하세요 (최소 200,000)';
                creditInput.min = 200000;
            } else {
                creditInput.readOnly = true;
                creditInput.style.backgroundColor = '#e9ecef';
                creditInput.placeholder = '';
                creditInput.min = '';
            }

            // 주니어 상품인지 확인 (contract_id가 'j'로 시작하는 경우)
            isJuniorProduct = contract.contract_id.startsWith('j');
            
            // 주니어 상품이면서 주니어가 선택되지 않은 경우
            if (isJuniorProduct) {
                showJuniorModal();
            }

            // 레슨권, 패키지 또는 주니어 상품인 경우 프로 선택 모달 표시
            if (contract.contract_type === '레슨권' || contract.contract_type === '패키지' || isJuniorProduct) {
                showProModal();
            }

            // 결제 유형 옵션 업데이트
            updatePaymentOptions(contract);
        }

        // 결제 유형 옵션 업데이트
        function updatePaymentOptions(selectedContract) {
            const creditOption = document.querySelector('.payment-option[data-value="크레딧결제"]');
            if (!creditOption) return; // 요소가 없으면 함수를 종료합니다
            
            const creditAmount = creditOption.querySelector('.credit-amount');
            if (!creditAmount) return; // 요소가 없으면 함수를 종료합니다
            
            if (selectedContract && selectedContract.sell_by_credit_price > 0) {
                creditOption.classList.remove('disabled');
                creditAmount.textContent = `(${formatNumber(selectedContract.sell_by_credit_price)} 크레딧)`;
            } else {
                creditOption.classList.add('disabled');
                creditAmount.textContent = '';
                if (paymentTypeInput && paymentTypeInput.value === '크레딧결제') {
                    paymentTypeInput.value = '';
                    creditOption.classList.remove('selected');
                }
            }
        }

        <?php if ($contract_history): ?>
        // 기존 계약 정보 설정
        const contractType = <?php echo json_encode($contract_history['contract_type']); ?>;
        const contractId = <?php echo json_encode($contract_history['contract_id']); ?>;
        
        // 회원권 유형 버튼 선택
        const typeButton = contractTypeButtons.querySelector(`[data-type="${contractType}"]`);
        if (typeButton) {
            typeButton.click();
        }
        
        // 계약 선택
        setTimeout(() => {
            const contractItem = contractList.querySelector(`[data-id="${contractId}"]`);
            if (contractItem) {
                contractItem.click();
            }
        }, 100);
        
        // 기존 결제 유형 설정
        if (<?php echo json_encode($contract_history['payment_type']); ?>) {
            const paymentType = <?php echo json_encode($contract_history['payment_type']); ?>;
            const paymentOption = document.querySelector(`.payment-option[data-value="${paymentType}"]`);
            if (paymentOption) {
                paymentOption.click();
            }
        }
        <?php endif; ?>

        // 모달 관련 함수
        function showModal(title, message) {
            const modal = document.getElementById('errorModal');
            const modalTitle = document.getElementById('modalTitle');
            const modalMessage = document.getElementById('modalMessage');
            
            modalTitle.textContent = title;
            modalMessage.textContent = message;
            modal.style.display = 'block';
        }

        // 폼 제출 처리
        document.querySelector('form').addEventListener('submit', function(e) {
            e.preventDefault();
            
            // 자유적립 크레딧 유효성 검사
            if (contractIdInput.value === 'c01') {
                const creditValue = parseInt(creditInput.value);
                if (isNaN(creditValue) || creditValue < 200000) {
                    alert('자유적립 크레딧은 최소 200,000 이상 입력해야 합니다.');
                    creditInput.focus();
                    return;
                }
            }
            
            if (isJuniorProduct && !selectedJuniorId) {
                alert('주니어 상품은 주니어를 선택해야 합니다.\n주니어탭에서 주니어를 먼저 등록하세요.');
                showJuniorModal();
                return;
            }

            // 선택된 주니어 ID를 폼에 추가
            if (selectedJuniorId) {
                const juniorInput = document.createElement('input');
                juniorInput.type = 'hidden';
                juniorInput.name = 'junior_id';
                juniorInput.value = selectedJuniorId;
                this.appendChild(juniorInput);
            }

            // 디버깅: 폼 제출 시 pro_change_type 값 확인
            console.log('폼 제출 시 pro_change_type 값: ' + document.getElementById('pro_change_type').value);

            // 상대 경로 명확하게 수정
            fetch('../member_form_tabs_and_process/contract_process.php', {
                method: 'POST',
                body: new FormData(this)
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    window.location.href = '../member_form.php?id=' + data.member_id + '#contracts';
                } else {
                    let message = data.message;
                    if (data.currentBalance !== undefined) {
                        message += `\n현재 잔액: ${data.currentBalance} 크레딧\n필요 금액: ${data.requiredAmount} 크레딧`;
                    }
                    showModal('오류', message);
                }
            })
            .catch(error => {
                console.error('처리 중 오류 발생:', error);
                showModal('오류', '처리 중 오류가 발생했습니다.');
            });
        });

        // 모달 닫기 버튼
        document.querySelector('.close').addEventListener('click', function() {
            document.getElementById('errorModal').style.display = 'none';
        });

        // 모달 외부 클릭 시 닫기
        window.addEventListener('click', function(event) {
            const modal = document.getElementById('errorModal');
            if (event.target === modal) {
                modal.style.display = 'none';
            }
        });

        // 결제 옵션 선택 처리
        const paymentOptions = document.querySelectorAll('.payment-option');

        paymentOptions.forEach(option => {
            option.addEventListener('click', function() {
                if (this.classList.contains('disabled')) return;
                
                // 기존 선택 제거
                paymentOptions.forEach(opt => opt.classList.remove('selected'));
                
                // 새로운 선택 추가
                this.classList.add('selected');
                paymentTypeInput.value = this.dataset.value;
            });
        });

        // 주니어 모달 표시
        function showJuniorModal() {
            juniorModal.style.display = 'block';
        }

        // 주니어 선택
        window.selectJunior = function() {
            const selectedRadio = document.querySelector('input[name="selected_junior"]:checked');
            if (!selectedRadio) {
                alert('주니어를 선택해주세요.');
                return;
            }

            selectedJuniorId = selectedRadio.value;
            const juniorName = selectedRadio.closest('tr').querySelector('td:nth-child(2)').textContent;
            
            // 선택된 주니어 정보 표시
            const selectedJuniorInfo = document.createElement('div');
            selectedJuniorInfo.className = 'selected-junior-info';
            selectedJuniorInfo.innerHTML = `${juniorName}`;
            
            const existingInfo = document.querySelector('.selected-junior-info');
            if (existingInfo) {
                existingInfo.remove();
            }
            
            document.querySelector('.contract-info').insertBefore(selectedJuniorInfo, document.querySelector('.payment-options'));
            selectedJuniorInfo.style.display = 'block';
            
            juniorModal.style.display = 'none';
        }

        // 프로 모달 표시
        function showProModal() {
            console.log('프로 모달 표시 함수 호출됨');
            proModal.style.display = 'block';
            
            // 현재 회원 또는 선택된 주니어의 매핑 정보 조회 - 상대 경로 수정
            fetch(`../get_pro_mapping.php?member_id=${<?php echo $member_id; ?>}${selectedJuniorId ? '&junior_id=' + selectedJuniorId : ''}`)
                .then(response => {
                    console.log('프로 매핑 정보 응답 상태:', response.status);
                    return response.json();
                })
                .then(data => {
                    console.log('프로 매핑 정보 응답 데이터:', data);
                    if (data.current_mapping) {
                        // 기존 매핑된 프로가 있으면 선택
                        const radioBtn = document.querySelector(`input[name="selected_pro"][value="${data.current_mapping.staff_nickname}"]`);
                        if (radioBtn) {
                            radioBtn.checked = true;
                            currentProNickname = data.current_mapping.staff_nickname;
                        }
                        
                        // 복수 프로 여부 저장
                        hasMultiplePros = data.has_multiple_pros;
                        
                        // 모든 매핑 정보 저장
                        allProMappings = data.all_mappings;
                    }
                })
                .catch(error => {
                    console.error('프로 매핑 정보 조회 오류:', error);
                });
        }
        
        // 프로 선택
        window.selectPro = function() {
            console.log('프로 선택 함수 호출됨');
            const selectedRadio = document.querySelector('input[name="selected_pro"]:checked');
            if (!selectedRadio) {
                alert('프로를 선택해주세요.');
                return;
            }

            const selectedProNickname = selectedRadio.value;
            const proName = selectedRadio.closest('tr').querySelector('td:nth-child(2)').textContent;
            
            console.log('선택된 프로:', proName, '(', selectedProNickname, ')');
            console.log('현재 프로:', currentProNickname);
            console.log('복수 프로 여부:', hasMultiplePros);
            
            // 복수 프로가 있거나, 현재 매핑된 프로가 있고 다른 프로를 선택한 경우
            if (hasMultiplePros || (currentProNickname && currentProNickname !== selectedProNickname)) {
                console.log('프로 변경 모달 표시 필요함');
                showProChangeConfirmation(currentProNickname, selectedProNickname);
                return;
            }

            // 프로 정보 설정
            console.log('프로 정보 직접 설정');
            setSelectedPro(selectedProNickname, proName);
        }
        
        // 선택된 프로 정보 설정
        function setSelectedPro(proNickname, proName) {
            selectedProNickname = proNickname;
            
            // 선택된 프로 정보 표시
            const selectedProInfo = document.createElement('div');
            selectedProInfo.className = 'selected-pro-info';
            selectedProInfo.innerHTML = `${proName}`;
            
            const existingInfo = document.querySelector('.selected-pro-info');
            if (existingInfo) {
                existingInfo.remove();
            }
            
            document.querySelector('.contract-info').insertBefore(selectedProInfo, document.querySelector('.payment-options'));
            selectedProInfo.style.display = 'block';
            
            // 폼에 프로 정보 추가
            let proInput = document.getElementById('pro_nickname');
            if (!proInput) {
                proInput = document.createElement('input');
                proInput.type = 'hidden';
                proInput.id = 'pro_nickname';
                proInput.name = 'pro_nickname';
                document.querySelector('form').appendChild(proInput);
            }
            proInput.value = proNickname;
            
            proModal.style.display = 'none';
        }
        
        // 프로 변경 확인 모달 표시
        function showProChangeConfirmation(oldPro, newPro) {
            console.log('프로 변경 확인 모달 표시 함수 호출됨');
            const confirmationModal = document.getElementById('proChangeModal');
            const oldProSpan = document.getElementById('old_pro');
            const newProSpan = document.getElementById('new_pro');
            const proChangeTypeInput = document.getElementById('pro_change_type');
            const multipleProsMessage = document.getElementById('multiple_pros_message');
            const changeBtnText = document.querySelector('#change_pro_btn div');
            const changeBtnDesc = document.querySelector('#change_pro_btn small');
            const changeMessage = document.getElementById('change_message');
            
            if (!confirmationModal) {
                console.error('프로 변경 확인 모달 엘리먼트를 찾을 수 없습니다.');
                return;
            }
            
            oldProSpan.textContent = oldPro;
            newProSpan.textContent = newPro;
            
            // 복수 프로인 경우 메시지와 버튼 텍스트 수정
            if (hasMultiplePros) {
                multipleProsMessage.style.display = 'block';
                const proNames = allProMappings.map(mapping => {
                    const proRadio = document.querySelector(`input[name="selected_pro"][value="${mapping.staff_nickname}"]`);
                    return proRadio ? proRadio.closest('tr').querySelector('td:nth-child(2)').textContent : mapping.staff_nickname;
                }).join(', ');
                multipleProsMessage.textContent = `현재 ${proNames} 프로가 매핑되어 있습니다.`;
                
                // 버튼 텍스트와 메시지 변경
                changeBtnText.textContent = '모든 기존 매핑 종료';
                changeBtnDesc.textContent = '모든 기존 매핑을 종료하고 새로운 프로와 매핑합니다.';
                changeMessage.innerHTML = `<span id="new_pro">${newPro}</span> 프로로 변경하시겠습니까?`;
            } else {
                multipleProsMessage.style.display = 'none';
                changeBtnText.textContent = '기존 매핑된 프로에서 변경';
                changeBtnDesc.textContent = '기존 매핑을 종료하고 새로운 프로와 매핑합니다.';
                changeMessage.innerHTML = `기존 매핑된 프로 <span id="old_pro">${oldPro}</span>에서 <span id="new_pro">${newPro}</span> 프로로 변경하시겠습니까?`;
            }
            
            console.log('프로 변경 모달 표시');
            confirmationModal.style.display = 'block';
            
            // 기존 이벤트 리스너 제거 (중복 방지)
            const changeProBtn = document.getElementById('change_pro_btn');
            const addProBtn = document.getElementById('add_pro_btn');
            
            if (!changeProBtn || !addProBtn) {
                console.error('변경 또는 추가 버튼 엘리먼트를 찾을 수 없습니다.');
                return;
            }
            
            // 기존 이벤트 리스너 완전히 제거
            const newChangeProBtn = changeProBtn.cloneNode(true);
            const newAddProBtn = addProBtn.cloneNode(true);
            
            changeProBtn.parentNode.replaceChild(newChangeProBtn, changeProBtn);
            addProBtn.parentNode.replaceChild(newAddProBtn, addProBtn);
            
            // 새 이벤트 리스너 설정
            newChangeProBtn.addEventListener('click', function() {
                console.log('프로 변경 버튼 클릭됨');
                proChangeTypeInput.value = 'change';
                console.log('프로 변경 유형 설정: ' + proChangeTypeInput.value);
                
                try {
                    const proNameElement = document.querySelector(`input[name="selected_pro"][value="${newPro}"]`).closest('tr').querySelector('td:nth-child(2)');
                    const proName = proNameElement ? proNameElement.textContent : newPro;
                    setSelectedPro(newPro, proName);
                } catch (error) {
                    console.error('프로 변경 처리 중 오류:', error);
                    setSelectedPro(newPro, newPro); // 기본값 사용
                }
                
                confirmationModal.style.display = 'none';
            });
            
            newAddProBtn.addEventListener('click', function() {
                console.log('프로 추가 버튼 클릭됨');
                proChangeTypeInput.value = 'add';
                console.log('프로 변경 유형 설정: ' + proChangeTypeInput.value);
                
                try {
                    const proNameElement = document.querySelector(`input[name="selected_pro"][value="${newPro}"]`).closest('tr').querySelector('td:nth-child(2)');
                    const proName = proNameElement ? proNameElement.textContent : newPro;
                    setSelectedPro(newPro, proName);
                } catch (error) {
                    console.error('프로 추가 처리 중 오류:', error);
                    setSelectedPro(newPro, newPro); // 기본값 사용
                }
                
                confirmationModal.style.display = 'none';
            });
            
            // 모달 닫기 버튼 이벤트도 재설정
            const closeBtn = confirmationModal.querySelector('.close');
            if (closeBtn) {
                const newCloseBtn = closeBtn.cloneNode(true);
                closeBtn.parentNode.replaceChild(newCloseBtn, closeBtn);
                
                newCloseBtn.addEventListener('click', function() {
                    console.log('닫기 버튼 클릭됨');
                    confirmationModal.style.display = 'none';
                });
            }
        }

        // 취소 버튼 클릭 이벤트
        document.getElementById('cancelBtn').addEventListener('click', function() {
            window.close();
        });
    });
    </script>
</head>
<body>
    <div class="container">
        <h1><?php echo $contract_history ? '회원권 수정' : '회원권 등록'; ?></h1>
        <h2><?php echo htmlspecialchars($member['member_name']); ?> 님의 회원권</h2>

        <form action="../member_form_tabs_and_process/contract_process.php" method="POST">
            <input type="hidden" name="member_id" value="<?php echo $member_id; ?>">
            <?php if ($contract_history): ?>
            <input type="hidden" name="id" value="<?php echo $contract_history['contract_history_id']; ?>">
            <?php endif; ?>
            <input type="hidden" id="pro_change_type" name="pro_change_type" value="">
            
            <div class="contract-grid">
                <div class="contract-selection">
                    <div class="form-group">
                        <label class="required">회원권 유형</label>
                        <div class="button-group" id="contract_type_buttons">
                            <?php
                            $types_result->data_seek(0);
                            while ($type = $types_result->fetch_assoc()) {
                                echo '<button type="button" class="btn" data-type="' . htmlspecialchars($type['contract_type']) . '">' 
                                    . htmlspecialchars($type['contract_type']) . '</button>';
                            }
                            ?>
                        </div>
                        <input type="hidden" id="contract_type" name="contract_type">
                    </div>

                    <div class="form-group">
                        <label class="required">계약 선택</label>
                        <div class="contract-list" id="contract_list">
                            <!-- 계약 목록은 JavaScript로 동적 생성됨 -->
                        </div>
                        <input type="hidden" id="contract_id" name="contract_id" required>
                    </div>
                </div>

                <div class="contract-info">
                    <div class="info-grid">
                        <div class="info-item">
                            <label>크레딧</label>
                            <div class="value">
                                <input type="number" id="contract_credit" name="contract_credit" value="0" readonly>
                            </div>
                        </div>
                        <div class="info-item">
                            <label>레슨횟수</label>
                            <div class="value">
                                <input type="number" id="contract_LS" name="contract_LS" value="0" readonly>
                            </div>
                        </div>
                        <div class="info-item">
                            <label>가격</label>
                            <div class="value">
                                <input type="text" id="contract_price" name="contract_price" value="0" readonly>
                            </div>
                        </div>
                    </div>

                    <div class="payment-options">
                        <input type="hidden" name="payment_type" id="payment_type_input">
                        <div class="payment-option" data-value="카드결제">
                            <i class="fas fa-credit-card"></i>
                            <div>카드결제</div>
                        </div>
                        <div class="payment-option" data-value="현금결제">
                            <i class="fas fa-money-bill-wave"></i>
                            <div>현금결제</div>
                        </div>
                        <div class="payment-option" data-value="크레딧결제">
                            <i class="fas fa-coins"></i>
                            <div>크레딧결제</div>
                            <div class="credit-amount"></div>
                        </div>
                        <div class="payment-option" data-value="톡스토어">
                            <i class="fas fa-store"></i>
                            <div>톡스토어</div>
                        </div>
                    </div>
                </div>
            </div>

            <div class="date-section">
                <div class="form-group">
                    <label for="contract_date" class="required">등록일자</label>
                    <input type="date" id="contract_date" name="contract_date" required
                        value="<?php echo $contract_history ? $contract_history['contract_date'] : date('Y-m-d'); ?>">
                </div>
            </div>

            <div class="form-actions">
                <button type="submit" class="btn-save">저장</button>
                <button type="button" class="btn" id="cancelBtn">취소</button>
            </div>
        </form>
    </div>

    <!-- 에러 모달 -->
    <div id="errorModal" class="modal">
        <div class="modal-content">
            <div class="modal-header">
                <span class="close">&times;</span>
                <h2 id="modalTitle">오류</h2>
            </div>
            <div class="modal-body">
                <p id="modalMessage"></p>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn" onclick="document.getElementById('errorModal').style.display='none'">확인</button>
            </div>
        </div>
    </div>

    <!-- 주니어 선택 모달 추가 -->
    <div id="juniorModal" class="modal">
        <div class="modal-content">
            <div class="modal-header">
                <span class="close">&times;</span>
                <h2>주니어 선택</h2>
            </div>
            <div class="modal-body">
                <div class="junior-list">
                    <?php
                    // 해당 회원의 주니어 목록 조회
                    $stmt = $db->prepare("
                        SELECT j.junior_id, j.junior_name, j.junior_school, jr.relation
                        FROM Junior_relation jr
                        JOIN Junior j ON jr.junior_id = j.junior_id
                        WHERE jr.member_id = ?
                        ORDER BY j.junior_id
                    ");
                    $stmt->bind_param('i', $member_id);
                    $stmt->execute();
                    $juniors = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
                    
                    if (empty($juniors)) {
                        echo '<p class="no-juniors">등록된 주니어가 없습니다. 주니어탭에서 주니어를 먼저 등록하세요.</p>';
                    } else {
                        echo '<table class="junior-table">
                                <thead>
                                    <tr>
                                        <th>선택</th>
                                        <th>이름</th>
                                        <th>학교</th>
                                        <th>관계</th>
                                    </tr>
                                </thead>
                                <tbody>';
                        foreach ($juniors as $junior) {
                            echo '<tr>
                                    <td><input type="radio" name="selected_junior" value="' . $junior['junior_id'] . '"></td>
                                    <td>' . htmlspecialchars($junior['junior_name']) . '</td>
                                    <td>' . htmlspecialchars($junior['junior_school'] ?: '-') . '</td>
                                    <td>' . htmlspecialchars($junior['relation']) . '</td>
                                </tr>';
                        }
                        echo '</tbody></table>';
                    }
                    ?>
                </div>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn-save" onclick="selectJunior()">선택</button>
                <button type="button" class="btn" onclick="document.getElementById('juniorModal').style.display='none'">취소</button>
            </div>
        </div>
    </div>

    <!-- 프로 선택 모달 추가 -->
    <div id="proModal" class="modal">
        <div class="modal-content">
            <div class="modal-header">
                <span class="close" onclick="document.getElementById('proModal').style.display='none'">&times;</span>
                <h2>프로 선택</h2>
            </div>
            <div class="modal-body">
                <?php
                // 재직 중인 프로 목록 조회
                $stmt = $db->prepare("
                    SELECT staff_id, staff_name, staff_nickname
                    FROM Staff
                    WHERE staff_type = '프로' AND staff_status = '재직'
                    ORDER BY staff_name
                ");
                $stmt->execute();
                $pros = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
                
                if (empty($pros)) {
                    echo '<p class="no-pros">등록된 프로가 없습니다.</p>';
                } else {
                    echo '<table class="pro-table">
                            <thead>
                                <tr>
                                    <th>선택</th>
                                    <th>이름</th>
                                </tr>
                            </thead>
                            <tbody>';
                    foreach ($pros as $pro) {
                        echo '<tr>
                                <td><input type="radio" name="selected_pro" value="' . $pro['staff_nickname'] . '"></td>
                                <td>' . htmlspecialchars($pro['staff_name']) . '</td>
                            </tr>';
                    }
                    echo '</tbody></table>';
                }
                ?>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn-save" onclick="selectPro()">선택</button>
                <button type="button" class="btn" onclick="document.getElementById('proModal').style.display='none'">취소</button>
            </div>
        </div>
    </div>

    <!-- 프로 변경 확인 모달 -->
    <div id="proChangeModal" class="modal">
        <div class="modal-content">
            <div class="modal-header">
                <span class="close" onclick="document.getElementById('proChangeModal').style.display='none'">&times;</span>
                <h2>프로 변경 확인</h2>
            </div>
            <div class="modal-body">
                <p id="multiple_pros_message" style="display: none;"></p>
                <p id="change_message">기존 매핑된 프로 <span id="old_pro"></span>에서 <span id="new_pro"></span> 프로로 변경하시겠습니까?</p>
                <div class="pro-change-options">
                    <button id="change_pro_btn" class="btn">
                        <div>기존 매핑된 프로에서 변경</div>
                        <small>기존 매핑을 종료하고 새로운 프로와 매핑합니다.</small>
                    </button>
                    <button id="add_pro_btn" class="btn">
                        <div>복수 프로 레슨 등록</div>
                        <small>기존 매핑을 유지하고 추가로 새로운 프로를 매핑합니다.</small>
                    </button>
                </div>
            </div>
        </div>
    </div>
</body>
</html>