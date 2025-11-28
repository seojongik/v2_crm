import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:html' as html;
import '/services/api_service.dart';
import '/constants/font_sizes.dart';
import 'package:intl/intl.dart';

class ContractReceiptDialog extends StatefulWidget {
  final Map<String, dynamic> contractData;

  const ContractReceiptDialog({
    Key? key,
    required this.contractData,
  }) : super(key: key);

  @override
  State<ContractReceiptDialog> createState() => _ContractReceiptDialogState();
}

class _ContractReceiptDialogState extends State<ContractReceiptDialog> {
  Map<String, dynamic>? branchData;
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadBranchData();
  }

  Future<void> _loadBranchData() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      // branch_id로 사업자 정보 조회
      final data = await ApiService.getDataList(
        table: 'v2_branch',
        where: [
          {
            'field': 'branch_id',
            'operator': '=',
            'value': ApiService.getCurrentBranchId(),
          }
        ],
        limit: 1,
      );

      if (data.isNotEmpty) {
        setState(() {
          branchData = data[0];
          isLoading = false;
        });
      } else {
        throw Exception('사업자 정보를 찾을 수 없습니다');
      }
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '-';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('yyyy년 MM월 dd일').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  String _formatDateTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '-';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('yyyy년 MM월 dd일 HH:mm').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  String _formatCurrency(dynamic amount) {
    if (amount == null) return '0';
    final int amountInt = amount is int ? amount : int.tryParse(amount.toString()) ?? 0;
    return NumberFormat('#,###').format(amountInt);
  }

  String _formatBusinessRegNo(String? regNo) {
    if (regNo == null || regNo.isEmpty) return '-';
    // 사업자등록번호 형식: XXX-XX-XXXXX
    if (regNo.length == 10) {
      return '${regNo.substring(0, 3)}-${regNo.substring(3, 5)}-${regNo.substring(5)}';
    }
    return regNo;
  }

  int _safeParseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value);
      return parsed ?? 0;
    }
    return 0;
  }

  // 제공 혜택 리스트 생성
  List<Map<String, String>> _getBenefitsList() {
    List<Map<String, String>> benefits = [];
    
    final credit = _safeParseInt(widget.contractData['contract_credit']);
    if (credit > 0) {
      benefits.add({
        'name': '선불크레딧',
        'amount': '${_formatCurrency(credit)}원',
        'expiry': _formatDate(widget.contractData['contract_credit_expiry_date']),
      });
    }
    
    final lessonMin = _safeParseInt(widget.contractData['contract_LS_min']);
    if (lessonMin > 0) {
      benefits.add({
        'name': '레슨권',
        'amount': '${lessonMin}분',
        'expiry': _formatDate(widget.contractData['contract_LS_min_expiry_date']),
      });
    }
    
    final games = _safeParseInt(widget.contractData['contract_games']);
    if (games > 0) {
      benefits.add({
        'name': '스크린게임',
        'amount': '${games}회',
        'expiry': _formatDate(widget.contractData['contract_games_expiry_date']),
      });
    }
    
    final timeMin = _safeParseInt(widget.contractData['contract_TS_min']);
    if (timeMin > 0) {
      benefits.add({
        'name': '타석시간',
        'amount': '${_formatCurrency(timeMin)}분',
        'expiry': _formatDate(widget.contractData['contract_TS_min_expiry_date']),
      });
    }
    
    final termMonth = _safeParseInt(widget.contractData['contract_term_month']);
    if (termMonth > 0) {
      benefits.add({
        'name': '기간권',
        'amount': '${termMonth}개월',
        'expiry': _formatDate(widget.contractData['contract_term_month_expiry_date']),
      });
    }
    
    return benefits;
  }

  void _printReceipt() {
    // 영수증 내용을 HTML로 구성
    final receiptHtml = _buildReceiptHtml();
    
    // 새 창에서 인쇄
    final blob = html.Blob([receiptHtml], 'text/html');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.window.open(url, '_blank');
    
    // 새 창에서 자동으로 인쇄되도록 HTML에 스크립트 포함
  }

  String _buildReceiptHtml() {
    final benefits = _getBenefitsList();
    
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>회원권 구매 영수증</title>
  <script>
    window.onload = function() {
      window.print();
      // 인쇄 다이얼로그가 닫히면 창도 닫기
      window.onafterprint = function() {
        window.close();
      }
    }
  </script>
  <style>
    @page {
      size: A4;
      margin: 10mm;
    }
    body {
      font-family: 'Malgun Gothic', sans-serif;
      line-height: 1.4;
      color: #333;
      max-width: 210mm;
      margin: 0 auto;
      padding: 15px;
    }
    .header {
      text-align: center;
      border-bottom: 3px solid #333;
      padding-bottom: 15px;
      margin-bottom: 20px;
    }
    .title {
      font-size: 22px;
      font-weight: bold;
      margin-bottom: 8px;
    }
    .business-info {
      margin-top: 8px;
      font-size: 11px;
      color: #666;
      line-height: 1.5;
    }
    .section {
      margin-bottom: 18px;
    }
    .section-title {
      font-size: 13px;
      font-weight: bold;
      color: #333;
      border-bottom: 1px solid #ddd;
      padding-bottom: 4px;
      margin-bottom: 8px;
    }
    table {
      width: 100%;
      border-collapse: collapse;
    }
    th, td {
      padding: 6px;
      text-align: left;
      border-bottom: 1px solid #eee;
      font-size: 12px;
    }
    th {
      background-color: #f8f9fa;
      font-weight: bold;
      color: #495057;
    }
    .info-row {
      display: flex;
      margin-bottom: 6px;
    }
    .info-label {
      width: 120px;
      color: #666;
      font-size: 12px;
    }
    .info-value {
      flex: 1;
      font-weight: 500;
      font-size: 12px;
    }
    .total-section {
      margin-top: 15px;
      padding: 15px;
      background-color: #f8f9fa;
      border-radius: 5px;
    }
    .total-amount {
      font-size: 20px;
      font-weight: bold;
      color: #1E293B;
      text-align: right;
    }
    .footer {
      margin-top: 20px;
      padding-top: 15px;
      border-top: 1px solid #ddd;
      text-align: center;
      font-size: 10px;
      color: #666;
    }
    .footer p {
      margin: 3px 0;
    }
    .receipt-no {
      position: absolute;
      top: 20px;
      right: 20px;
      font-size: 12px;
      color: #666;
    }
    .stamp {
      margin-top: 30px;
      text-align: right;
    }
    .stamp-box {
      display: inline-block;
      padding: 10px 20px;
      border: 2px solid #333;
      border-radius: 5px;
      font-weight: bold;
    }
    @media print {
      body { margin: 0; }
      .no-print { display: none; }
    }
  </style>
</head>
<body>
  <div class="receipt-no">No. ${widget.contractData['contract_history_id']}</div>
  
  <div class="header">
    <div class="title">회원권 구매 영수증</div>
    <div class="business-info">
      <div>${branchData?['branch_name'] ?? ''} | ${branchData?['branch_address'] ?? ''}</div>
      <div>사업자등록번호: ${_formatBusinessRegNo(branchData?['branch_business_reg_no'])} | TEL: ${branchData?['branch_phone'] ?? ''}</div>
    </div>
  </div>

  <div class="section">
    <div class="section-title">구매자 정보</div>
    <div class="info-row">
      <span class="info-label">회원명:</span>
      <span class="info-value">${widget.contractData['member_name'] ?? ''}</span>
    </div>
    <div class="info-row">
      <span class="info-label">회원번호:</span>
      <span class="info-value">${widget.contractData['member_id'] ?? ''}</span>
    </div>
    <div class="info-row">
      <span class="info-label">구매일시:</span>
      <span class="info-value">${_formatDateTime(widget.contractData['contract_register'])}</span>
    </div>
  </div>

  <div class="section">
    <div class="section-title">구매 내역</div>
    <table>
      <tr>
        <th style="width: 30%;">상품명</th>
        <td>${widget.contractData['contract_name'] ?? ''}</td>
      </tr>
      <tr>
        <th>상품유형</th>
        <td>${widget.contractData['contract_type'] ?? ''}</td>
      </tr>
      <tr>
        <th>결제방식</th>
        <td>${widget.contractData['payment_type'] ?? ''}</td>
      </tr>
    </table>
  </div>

  ${benefits.isNotEmpty ? '''
  <div class="section">
    <div class="section-title">서비스 내용 상세</div>
    <table>
      <thead>
        <tr>
          <th style="width: 30%;">구분</th>
          <th style="width: 35%;">내용</th>
          <th style="width: 35%;">유효기간</th>
        </tr>
      </thead>
      <tbody>
        ${benefits.map((benefit) => '''
        <tr>
          <td>${benefit['name']}</td>
          <td>${benefit['amount']}</td>
          <td>${benefit['expiry']}</td>
        </tr>
        ''').join('')}
      </tbody>
    </table>
  </div>
  ''' : ''}

  <div class="total-section">
    <div class="info-row">
      <span class="info-label">결제금액:</span>
      <span class="total-amount" style="color: #1E293B;">${_formatCurrency(widget.contractData['price'])}원</span>
    </div>
  </div>
  
  <div style="text-align: center; margin-top: 10px; margin-bottom: 15px; color: #64748B; font-style: italic; font-size: 12px; line-height: 1.5;">
    위 금액을 정히 영수하였습니다.<br>
    계약 상세내용은 매장 이용약관을 참조하세요.
  </div>

  <div class="footer">
    <p>본 영수증은 회원권 구매 증빙 자료로 사용하실 수 있습니다.</p>
    <p>문의사항: ${branchData?['branch_phone'] ?? ''}</p>
    <p>발행일시: ${DateFormat('yyyy년 MM월 dd일 HH:mm:ss').format(DateTime.now())}</p>
  </div>
</body>
</html>
    ''';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: 500,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 헤더
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF1E40AF)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.receipt_long,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '회원권 구매 영수증',
                          style: AppTextStyles.titleH3.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'No. ${widget.contractData['contract_history_id']}',
                          style: AppTextStyles.cardMeta.copyWith(
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            // 본문
            Expanded(
              child: isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF3B82F6),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 사업자 정보
                          if (branchData != null) ...[
                            _buildSection(
                              '사업자 정보',
                              Icons.store,
                              [
                                _buildInfoRow('매장명', branchData!['branch_name'] ?? ''),
                                _buildInfoRow('대표자', branchData!['branch_director_name'] ?? ''),
                                _buildInfoRow('사업자등록번호', _formatBusinessRegNo(branchData!['branch_business_reg_no'])),
                                _buildInfoRow('주소', branchData!['branch_address'] ?? ''),
                                _buildInfoRow('전화번호', branchData!['branch_phone'] ?? ''),
                              ],
                            ),
                            SizedBox(height: 16),
                          ],

                          // 구매자 정보
                          _buildSection(
                            '구매자 정보',
                            Icons.person,
                            [
                              _buildInfoRow('회원명', widget.contractData['member_name'] ?? ''),
                              _buildInfoRow('회원번호', widget.contractData['member_id']?.toString() ?? ''),
                              _buildInfoRow('구매일시', _formatDateTime(widget.contractData['contract_register'])),
                            ],
                          ),
                          SizedBox(height: 16),

                          // 구매 내역
                          _buildSection(
                            '구매 내역',
                            Icons.shopping_cart,
                            [
                              _buildInfoRow('상품명', widget.contractData['contract_name'] ?? ''),
                              _buildInfoRow('상품유형', widget.contractData['contract_type'] ?? ''),
                              _buildInfoRow('결제방식', widget.contractData['payment_type'] ?? ''),
                            ],
                          ),
                          SizedBox(height: 16),

                          // 서비스 내용 상세
                          if (_getBenefitsList().isNotEmpty) ...[
                            _buildBenefitsSection(),
                            SizedBox(height: 16),
                          ],

                          // 결제 금액
                          Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '결제금액',
                                  style: AppTextStyles.titleH4.copyWith(
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                Text(
                                  '${_formatCurrency(widget.contractData['price'])}원',
                                  style: AppTextStyles.titleH3.copyWith(
                                    color: Color(0xFF1E293B),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 16),
                          Center(
                            child: Column(
                              children: [
                                Text(
                                  '위 금액을 정히 영수하였습니다.',
                                  style: AppTextStyles.cardBody.copyWith(
                                    color: Color(0xFF64748B),
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  '계약 상세내용은 매장 이용약관을 참조하세요.',
                                  style: AppTextStyles.cardMeta.copyWith(
                                    color: Color(0xFF94A3B8),
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            // 하단 버튼
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    onPressed: _printReceipt,
                    icon: Icon(Icons.print),
                    label: Text('출력'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('닫기'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF64748B),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: Color(0xFF64748B)),
                SizedBox(width: 8),
                Text(
                  title,
                  style: AppTextStyles.cardBody.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF334155),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitsSection() {
    final benefits = _getBenefitsList();
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.card_giftcard, size: 18, color: Color(0xFF64748B)),
                SizedBox(width: 8),
                Text(
                  '서비스 내용 상세',
                  style: AppTextStyles.cardBody.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF334155),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.all(16),
            child: Table(
              columnWidths: {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(2),
                2: FlexColumnWidth(3),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        '구분',
                        style: AppTextStyles.cardMeta.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        '내용',
                        style: AppTextStyles.cardMeta.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        '유효기간',
                        style: AppTextStyles.cardMeta.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
                ...benefits.map((benefit) => TableRow(
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        benefit['name'] ?? '',
                        style: AppTextStyles.cardBody.copyWith(
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        benefit['amount'] ?? '',
                        style: AppTextStyles.cardBody.copyWith(
                          color: Color(0xFF1E293B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        benefit['expiry'] ?? '',
                        style: AppTextStyles.cardMeta.copyWith(
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: AppTextStyles.cardMeta.copyWith(
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.cardBody.copyWith(
                color: Color(0xFF1E293B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}