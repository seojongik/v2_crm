<!DOCTYPE html>
<html lang="ko">
<head>
    <meta charset="UTF-8">
    <title>상품 구매</title>
    <!-- FontAwesome 아이콘 라이브러리 추가 -->
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/5.15.4/css/all.min.css">
    <!-- Google Noto Sans KR 폰트 추가 -->
    <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Noto+Sans+KR:wght@400;500;700&display=swap">
    <style>
        /* 기본 스타일 */
        body {
            font-family: 'Noto Sans KR', sans-serif;
            line-height: 1.6;
            color: #333;
            background-color: #f8f9fa;
            margin: 0;
            padding: 0;
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
            background: #e0e0e0;
            border-radius: 3px;
        }
        
        h2 {
            font-size: 20px;
            color: #555;
            font-weight: 500;
        }
        
        /* 폼 스타일 */
        .form-group {
            margin-bottom: 25px;
        }
        
        .form-group label {
            display: block;
            margin-bottom: 8px;
            font-weight: 600;
            color: #444;
        }
        
        .form-group input[type="text"],
        .form-group input[type="number"],
        .form-group input[type="date"],
        .form-group select {
            width: 100%;
            padding: 12px;
            border: 1px solid #e0e0e0;
            border-radius: 8px;
            font-family: 'Noto Sans KR', sans-serif;
            box-shadow: inset 0 1px 3px rgba(0,0,0,0.05);
            transition: all 0.3s;
        }
        
        .form-group input:focus,
        .form-group select:focus {
            border-color: #2c7be5;
            outline: none;
            box-shadow: 0 0 0 3px rgba(44, 123, 229, 0.1);
        }
        
        .form-actions {
            margin-top: 30px;
            display: flex;
            justify-content: center;
            gap: 15px;
            padding-top: 20px;
            border-top: 1px solid #f1f1f1;
        }
        
        label.required:after {
            content: " *";
            color: #e74c3c;
        }
        
        /* 버튼 스타일 */
        .btn, .btn-save {
            display: inline-flex;
            align-items: center;
            justify-content: center;
            padding: 10px 16px;
            border-radius: 8px;
            cursor: pointer;
            font-size: 14px;
            font-weight: 600;
            text-decoration: none;
            text-align: center;
            border: 1px solid #dee2e6;
            transition: all 0.3s ease;
            background-color: #f8f9fa;
            color: #495057;
            box-shadow: 0 1px 3px rgba(0,0,0,0.08);
            min-width: 150px;
            max-width: 200px;
            flex: 1;
        }

        .btn-save, button[type="submit"] {
            background-color: #f8f9fa;
            color: #2c7be5;
            border-color: #2c7be5;
        }

        .btn:hover {
            background-color: #f1f3f5;
        }

        .btn-save:hover, button[type="submit"]:hover {
            background-color: #eaf2ff;
        }

        .btn.selected {
            background-color: #eaf2ff;
            color: #2c7be5;
            border-color: #2c7be5;
        }

        .product-grid {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 30px;
            margin-bottom: 40px;
        }

        .product-selection {
            background: white;
            padding: 25px;
            border-radius: 15px;
            box-shadow: 0 5px 20px rgba(0,0,0,0.05);
            border-left: 4px solid #dee2e6;
            transition: all 0.3s ease;
        }
        
        .product-selection:hover {
            box-shadow: 0 8px 25px rgba(0,0,0,0.08);
        }

        .product-info {
            background: white;
            padding: 25px;
            border-radius: 15px;
            box-shadow: 0 5px 20px rgba(0,0,0,0.05);
            border-left: 4px solid #dee2e6;
            transition: all 0.3s ease;
        }
        
        .product-info:hover {
            box-shadow: 0 8px 25px rgba(0,0,0,0.08);
        }

        .button-group {
            display: flex;
            flex-wrap: wrap;
            gap: 10px;
            margin-bottom: 25px;
        }

        .product-list {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(140px, 1fr));
            gap: 12px;
            margin-top: 15px;
            max-height: 300px;
            overflow-y: auto;
            padding-right: 5px;
        }
        
        /* 스크롤바 스타일 */
        .product-list::-webkit-scrollbar {
            width: 6px;
        }
        
        .product-list::-webkit-scrollbar-track {
            background: #f1f1f1;
            border-radius: 10px;
        }
        
        .product-list::-webkit-scrollbar-thumb {
            background: #c1c1c1;
            border-radius: 10px;
        }
        
        .product-list::-webkit-scrollbar-thumb:hover {
            background: #a8a8a8;
        }

        .product-item {
            padding: 12px;
            border: 1px solid #e0e0e0;
            border-radius: 8px;
            background-color: #f8f9fa;
            cursor: pointer;
            text-align: center;
            transition: all 0.3s ease;
            font-size: 14px;
            display: flex;
            align-items: center;
            justify-content: center;
            min-height: 50px;
            word-break: keep-all;
            line-height: 1.4;
            font-weight: 500;
            color: #555;
        }

        .product-item:hover {
            background-color: #f1f3f5;
            border-color: #ced4da;
        }

        .product-item.selected {
            background-color: #eaf2ff;
            border-color: #2c7be5;
            color: #2c7be5;
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
            border: 1px solid #e0e0e0;
        }

        .info-item label {
            display: block;
            margin-bottom: 10px;
            color: #555;
            font-size: 0.95em;
            font-weight: 600;
        }

        .info-item input {
            width: 100%;
            padding: 12px;
            border: 1px solid #e0e0e0;
            border-radius: 8px;
            text-align: center;
            font-size: 1.1em;
            font-weight: 500;
            background: white;
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
            border: 1px solid #e0e0e0;
            border-radius: 8px;
            cursor: pointer;
            transition: all 0.3s ease;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            min-height: 80px;
            font-size: 14px;
        }

        .payment-option i {
            font-size: 24px;
            margin-bottom: 8px;
            color: #6c757d;
        }

        .payment-option:hover {
            background: #f1f3f5;
            border-color: #ced4da;
        }

        .payment-option.selected {
            background: #eaf2ff;
            border-color: #2c7be5;
            color: #2c7be5;
        }
        
        .payment-option.selected i {
            color: #2c7be5;
        }

        .payment-option.disabled {
            opacity: 0.5;
            cursor: not-allowed;
        }

        .date-section {
            max-width: 300px;
            margin: 0 auto 30px;
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
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 20px;
            padding-bottom: 15px;
            border-bottom: 1px solid #f1f1f1;
        }
        
        .modal-header h2 {
            margin: 0;
            font-size: 20px;
            text-align: left;
            color: #333;
            font-weight: 600;
        }
        
        .modal-body {
            margin-bottom: 20px;
        }
        
        .modal-footer {
            display: flex;
            justify-content: flex-end;
            gap: 10px;
            padding-top: 15px;
            border-top: 1px solid #f1f1f1;
        }

        .close {
            color: #aaa;
            font-size: 24px;
            font-weight: bold;
            cursor: pointer;
            transition: all 0.3s;
        }

        .close:hover {
            color: #555;
        }
        
        /* 유틸리티 클래스 */
        .text-right {
            text-align: right;
        }
        
        .text-center {
            text-align: center;
        }
        
        .mb-10 {
            margin-bottom: 10px;
        }
        
        .mb-20 {
            margin-bottom: 20px;
        }
        
        @media (max-width: 768px) {
            .container {
                padding: 20px;
                margin: 15px;
            }
            
            .product-grid {
                grid-template-columns: 1fr;
            }
            
            .info-grid {
                grid-template-columns: 1fr;
            }
            
            .payment-options {
                grid-template-columns: repeat(2, 1fr);
            }
            
            .form-actions {
                flex-direction: column;
                gap: 10px;
            }
            
            .form-actions .btn,
            .form-actions .btn-save {
                max-width: 100%;
            }
        }
    </style>
</head>
<body>
    <?php
    require_once dirname(__FILE__) . '/../../config/db_connect.php';

    $member_id = $_GET['member_id'] ?? null;
    if (!$member_id) {
        header('Location: ../member_list.php');
        exit;
    }

    // 회원 정보 조회
    $stmt = $db->prepare('SELECT * FROM members WHERE member_id = ?');
    $stmt->bind_param('i', $member_id);
    $stmt->execute();
    $member = $stmt->get_result()->fetch_assoc();

    if (!$member) {
        header('Location: ../member_list.php');
        exit;
    }

    // 상품 목록 조회
    $products_query = "
        SELECT * FROM contracts 
        WHERE contract_status = '유효'
        AND contract_category = '판매상품'
        ORDER BY 
            CASE contract_type
                WHEN '식음료' THEN 1
                WHEN '상품' THEN 2
                ELSE 3
            END,
            contract_id
    ";
    $products = $db->query($products_query)->fetch_all(MYSQLI_ASSOC);

    // 상품 유형 목록 조회
    $types_query = "
        SELECT DISTINCT contract_type 
        FROM contracts 
        WHERE contract_category = '판매상품'
        ORDER BY 
            CASE contract_type
                WHEN '식음료' THEN 1
                WHEN '상품' THEN 2
                ELSE 3
            END
    ";
    $types = $db->query($types_query)->fetch_all(MYSQLI_ASSOC);
    ?>

    <div class="container">
        <h1>상품 구매</h1>
        <h2><?php echo htmlspecialchars($member['member_name']); ?> 님의 상품 구매</h2>

        <form action="../member_form_tabs_and_process/product_process.php" method="POST">
            <input type="hidden" name="member_id" value="<?php echo $member_id; ?>">
            
            <div class="product-grid">
                <div class="product-selection">
                    <div class="form-group">
                        <label class="required">상품 유형</label>
                        <div class="button-group" id="product_type_buttons">
                            <?php foreach ($types as $type): ?>
                                <button type="button" class="btn" data-type="<?php echo htmlspecialchars($type['contract_type']); ?>">
                                    <?php echo htmlspecialchars($type['contract_type']); ?>
                                </button>
                            <?php endforeach; ?>
                        </div>
                        <input type="hidden" id="product_type" name="product_type">
                    </div>

                    <div class="form-group">
                        <label class="required">상품 선택</label>
                        <div class="product-list" id="product_list">
                            <!-- 상품 목록은 JavaScript로 동적 생성됨 -->
                        </div>
                        <input type="hidden" id="product_id" name="product_id" required>
                    </div>
                </div>

                <div class="product-info">
                    <div class="info-grid">
                        <div class="info-item">
                            <label>상품가격</label>
                            <div class="value">
                                <input type="text" id="product_price" name="product_price" value="0" readonly>
                            </div>
                        </div>
                        <div class="info-item">
                            <label>수량</label>
                            <div class="value">
                                <input type="number" id="quantity" name="quantity" value="1" min="1">
                            </div>
                        </div>
                        <div class="info-item">
                            <label>총 금액</label>
                            <div class="value">
                                <input type="text" id="total_price" name="total_price" value="0" readonly>
                            </div>
                        </div>
                    </div>

                    <div class="payment-options">
                        <input type="hidden" name="payment_type" id="payment_type_input">
                        <div class="payment-option" data-value="카드결제">
                            <i class="fas fa-credit-card"></i>
                            <div>카드결제</div>
                            <div class="price-amount"></div>
                        </div>
                        <div class="payment-option" data-value="현금결제">
                            <i class="fas fa-money-bill-wave"></i>
                            <div>현금결제</div>
                            <div class="price-amount"></div>
                        </div>
                        <div class="payment-option" data-value="크레딧결제">
                            <i class="fas fa-coins"></i>
                            <div>크레딧결제</div>
                            <div class="credit-amount"></div>
                        </div>
                    </div>
                </div>
            </div>

            <div class="date-section">
                <div class="form-group">
                    <label for="purchase_date" class="required">구매일자</label>
                    <input type="date" id="purchase_date" name="purchase_date" required value="<?php echo date('Y-m-d'); ?>">
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
                <h2 id="modalTitle">오류</h2>
                <span class="close">&times;</span>
            </div>
            <div class="modal-body">
                <p id="modalMessage"></p>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn" onclick="document.getElementById('errorModal').style.display='none'">확인</button>
            </div>
        </div>
    </div>

    <script>
    document.addEventListener('DOMContentLoaded', function() {
        // FontAwesome 아이콘 라이브러리 추가 (인라인으로)
        if (!document.getElementById('fontawesome-css')) {
            const link = document.createElement('link');
            link.id = 'fontawesome-css';
            link.rel = 'stylesheet';
            link.href = 'https://cdnjs.cloudflare.com/ajax/libs/font-awesome/5.15.4/css/all.min.css';
            document.head.appendChild(link);
        }

        // Google Noto Sans KR 폰트 추가 (인라인으로)
        if (!document.getElementById('noto-sans-kr')) {
            const link = document.createElement('link');
            link.id = 'noto-sans-kr';
            link.rel = 'stylesheet';
            link.href = 'https://fonts.googleapis.com/css2?family=Noto+Sans+KR:wght@400;500;700&display=swap';
            document.head.appendChild(link);
        }
        
        const productTypeButtons = document.getElementById('product_type_buttons');
        const productList = document.getElementById('product_list');
        const productTypeInput = document.getElementById('product_type');
        const productIdInput = document.getElementById('product_id');
        const priceInput = document.getElementById('product_price');
        const quantityInput = document.getElementById('quantity');
        const totalPriceInput = document.getElementById('total_price');
        const paymentTypeInput = document.getElementById('payment_type_input');

        // 상품 데이터
        const productsData = <?php echo json_encode($products); ?>;

        // 숫자 포맷 함수
        function formatNumber(number) {
            return new Intl.NumberFormat('ko-KR').format(number);
        }

        // 상품 유형 버튼 클릭 이벤트
        productTypeButtons.addEventListener('click', function(e) {
            if (e.target.classList.contains('btn')) {
                productTypeButtons.querySelectorAll('.btn').forEach(btn => btn.classList.remove('selected'));
                e.target.classList.add('selected');
                const selectedType = e.target.dataset.type;
                productTypeInput.value = selectedType;
                updateProductList(selectedType);
            }
        });

        // 상품 목록 업데이트
        function updateProductList(selectedType) {
            productList.innerHTML = '';
            const filteredProducts = productsData.filter(p => p.contract_type === selectedType);
            
            filteredProducts.forEach(product => {
                const productItem = document.createElement('div');
                productItem.className = 'product-item';
                productItem.dataset.id = product.contract_id;
                productItem.textContent = product.contract_name;
                
                productItem.addEventListener('click', () => selectProduct(product, productItem));
                productList.appendChild(productItem);
            });
        }

        // 상품 선택
        function selectProduct(product, element) {
            productList.querySelectorAll('.product-item').forEach(item => item.classList.remove('selected'));
            element.classList.add('selected');
            productIdInput.value = product.contract_id;
            
            priceInput.value = formatNumber(product.price) + '원';
            updateTotalPrice();
            updatePaymentOptions(product);
        }

        // 수량 변경 시 총 금액 업데이트
        quantityInput.addEventListener('change', updateTotalPrice);
        quantityInput.addEventListener('input', updateTotalPrice);

        function updateTotalPrice() {
            const price = parseInt(priceInput.value.replace(/[^0-9]/g, '')) || 0;
            const quantity = parseInt(quantityInput.value) || 1;
            const total = price * quantity;
            totalPriceInput.value = formatNumber(total) + '원';

            // 결제 옵션 금액 업데이트
            document.querySelectorAll('.payment-option .price-amount').forEach(el => {
                el.textContent = `(${formatNumber(total)}원)`;
            });
        }

        // 결제 옵션 업데이트
        function updatePaymentOptions(selectedProduct) {
            const creditOption = document.querySelector('.payment-option[data-value="크레딧결제"]');
            const creditAmount = creditOption.querySelector('.credit-amount');
            
            if (selectedProduct.sell_by_credit_price > 0) {
                creditOption.classList.remove('disabled');
                const creditPrice = selectedProduct.sell_by_credit_price * (parseInt(quantityInput.value) || 1);
                creditAmount.textContent = `(${formatNumber(creditPrice)} 크레딧)`;
            } else {
                creditOption.classList.add('disabled');
                creditAmount.textContent = '';
                if (paymentTypeInput.value === '크레딧결제') {
                    paymentTypeInput.value = '';
                    creditOption.classList.remove('selected');
                }
            }
        }

        // 결제 옵션 선택
        document.querySelectorAll('.payment-option').forEach(option => {
            option.addEventListener('click', function() {
                if (this.classList.contains('disabled')) return;
                
                document.querySelectorAll('.payment-option').forEach(opt => opt.classList.remove('selected'));
                this.classList.add('selected');
                paymentTypeInput.value = this.dataset.value;
            });
        });

        // 폼 제출
        document.querySelector('form').addEventListener('submit', function(e) {
            e.preventDefault();
            
            fetch('../member_form_tabs_and_process/product_process.php', {
                method: 'POST',
                body: new FormData(this)
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    // 부모 창 새로고침하고 현재 창 닫기
                    if (window.opener && !window.opener.closed) {
                        window.opener.location.href = '../member_form.php?id=' + data.member_id + '#credit';
                        window.opener.location.reload();
                    }
                    window.close();
                } else {
                    showModal('오류', data.message);
                }
            })
            .catch(error => {
                console.error('Error:', error);
                showModal('오류', '처리 중 오류가 발생했습니다.');
            });
        });

        // 취소 버튼 이벤트 - 창 닫기
        document.getElementById('cancelBtn').addEventListener('click', function() {
            window.close();
        });

        // 모달 관련 함수
        function showModal(title, message) {
            const modal = document.getElementById('errorModal');
            document.getElementById('modalTitle').textContent = title;
            document.getElementById('modalMessage').textContent = message;
            modal.style.display = 'block';
        }

        // 모달 닫기
        document.querySelector('.close').addEventListener('click', () => {
            document.getElementById('errorModal').style.display = 'none';
        });

        // 모달 외부 클릭 시 닫기
        window.onclick = function(event) {
            const modal = document.getElementById('errorModal');
            if (event.target === modal) {
                modal.style.display = 'none';
            }
        };

        // 첫 번째 상품 유형 버튼 자동 클릭
        const firstTypeButton = productTypeButtons.querySelector('.btn');
        if (firstTypeButton) {
            firstTypeButton.click();
        }
    });
    </script>
</body>
</html> 