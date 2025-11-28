import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'dart:html' as html;
import 'dart:convert';
import '/services/api_service.dart';
import '/constants/font_sizes.dart';

class TransferContractPage extends StatefulWidget {
  final Map<String, dynamic> contract;
  final Map<String, dynamic> transferee;
  final int creditBalance;
  final int lessonBalance;
  final int timeBalance;
  final int gameBalance;
  final String? termExpiryDate;

  const TransferContractPage({
    Key? key,
    required this.contract,
    required this.transferee,
    required this.creditBalance,
    required this.lessonBalance,
    required this.timeBalance,
    required this.gameBalance,
    this.termExpiryDate,
  }) : super(key: key);

  @override
  _TransferContractPageState createState() => _TransferContractPageState();
}

class _TransferContractPageState extends State<TransferContractPage> {
  Map<String, dynamic>? branchInfo;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBranchInfo();
  }

  Future<void> _loadBranchInfo() async {
    try {
      final data = await ApiService.getDataList(
        table: 'v2_branch',
        where: [
          {
            'field': 'branch_id',
            'operator': '=',
            'value': ApiService.getCurrentBranchId(),
          }
        ],
      );

      if (data.isNotEmpty) {
        setState(() {
          branchInfo = data[0];
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print('지점 정보 로드 실패: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  void _printContract() {
    // 웹에서 인쇄 실행
    html.window.print();
  }

  void _downloadPDF() {
    // 현재 화면을 HTML로 변환하여 다운로드
    final htmlContent = '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>회원권 양도계약서</title>
    <style>
        @page {
            size: A4;
            margin: 20mm;
        }
        body {
            font-family: 'Malgun Gothic', sans-serif;
            margin: 0;
            padding: 0;
            background: white;
        }
        .contract-container {
            width: 100%;
            max-width: 210mm;
            margin: 0 auto;
            background: white;
        }
        .header {
            text-align: center;
            padding: 20px;
            border: 2px solid black;
            margin-bottom: 20px;
        }
        .title {
            font-size: 28px;
            font-weight: bold;
            margin-bottom: 10px;
        }
        .subtitle {
            font-size: 16px;
            color: #666;
        }
        .section {
            margin-bottom: 20px;
            border: 1px solid #ddd;
            padding: 16px;
        }
        .section-title {
            font-size: 16px;
            font-weight: bold;
            margin-bottom: 10px;
        }
        .info-row {
            display: flex;
            margin-bottom: 4px;
        }
        .info-label {
            width: 120px;
            font-weight: bold;
        }
        .parties-container {
            display: flex;
            gap: 24px;
        }
        .party-box {
            flex: 1;
            padding: 12px;
            border: 1px solid #ddd;
            border-radius: 8px;
        }
        .party-title {
            font-weight: bold;
            margin-bottom: 8px;
        }
        .signature-section {
            margin-top: 20px;
        }
        .signature-row {
            display: flex;
            gap: 40px;
            margin-top: 20px;
        }
        .signature-box {
            flex: 1;
            text-align: center;
        }
        .signature-line {
            border-bottom: 1px solid black;
            margin: 20px 0 8px 0;
        }
    </style>
</head>
<body>
    <div class="contract-container">
        <div class="header">
            <div class="title">회원권 양도계약서</div>
            <div class="subtitle">MEMBER TRANSFER AGREEMENT</div>
        </div>
        
        <div class="section">
            <div class="section-title">사용처 정보</div>
            <div class="info-row">
                <div class="info-label">사업장명:</div>
                <div>${branchInfo?['branch_name'] ?? '-'}</div>
            </div>
            <div class="info-row">
                <div class="info-label">주소:</div>
                <div>${branchInfo?['branch_address'] ?? '-'}</div>
            </div>
            <div class="info-row">
                <div class="info-label">사업자등록번호:</div>
                <div>${branchInfo?['branch_business_reg_no'] ?? '-'}</div>
            </div>
            <div class="info-row">
                <div class="info-label">전화번호:</div>
                <div>${branchInfo?['branch_phone'] ?? '-'}</div>
            </div>
        </div>
        
        <div class="section">
            <div class="section-title">계약조건</div>
            <div>• 본 회원권은 위 사용처에서만 사용 가능합니다.</div>
            <div>• 회원약관에 의거 양도수수료가 발생할 수 있습니다.</div>
            <div>• 양도 후 원회원의 회원권은 즉시 소멸됩니다.</div>
            <div>• 양수인은 양도받은 회원권의 조건을 그대로 승계합니다.</div>
        </div>
        
        <div class="section">
            <div class="section-title">양도내용</div>
            <div>${_getTransferItemsText()}</div>
        </div>
        
        <div class="section">
            <div class="parties-container">
                <div class="party-box">
                    <div class="party-title">양도인</div>
                    <div class="info-row">
                        <div class="info-label">성명:</div>
                        <div>${widget.contract['member_name'] ?? '-'}</div>
                    </div>
                    <div class="info-row">
                        <div class="info-label">회원번호:</div>
                        <div>${widget.contract['member_id'] ?? '-'}</div>
                    </div>
                    <div class="info-row">
                        <div class="info-label">전화번호:</div>
                        <div>${widget.contract['member_phone'] ?? '-'}</div>
                    </div>
                </div>
                <div class="party-box">
                    <div class="party-title">양수인</div>
                    <div class="info-row">
                        <div class="info-label">성명:</div>
                        <div>${widget.transferee['member_name'] ?? '-'}</div>
                    </div>
                    <div class="info-row">
                        <div class="info-label">회원번호:</div>
                        <div>${widget.transferee['member_id'] ?? '-'}</div>
                    </div>
                    <div class="info-row">
                        <div class="info-label">전화번호:</div>
                        <div>${widget.transferee['member_phone'] ?? '-'}</div>
                    </div>
                </div>
            </div>
        </div>
        
        <div class="signature-section">
            <div>양도일: ${DateFormat('yyyy년 MM월 dd일').format(DateTime.now())}</div>
            <div class="signature-row">
                <div class="signature-box">
                    <div>양도인</div>
                    <div class="signature-line"></div>
                    <div>(서명)</div>
                </div>
                <div class="signature-box">
                    <div>양수인</div>
                    <div class="signature-line"></div>
                    <div>(서명)</div>
                </div>
            </div>
        </div>
    </div>
</body>
</html>
    ''';
    
    // HTML을 Blob으로 변환하여 다운로드
    final blob = html.Blob([htmlContent], 'text/html');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', '회원권_양도계약서_${DateFormat('yyyyMMdd').format(DateTime.now())}.html')
      ..click();
    html.Url.revokeObjectUrl(url);
  }
  
  String _getTransferItemsText() {
    List<String> items = [];
    if (widget.creditBalance > 0) {
      items.add('크레딧: ${NumberFormat('#,###').format(widget.creditBalance)}원');
    }
    if (widget.lessonBalance > 0) {
      items.add('레슨권: ${widget.lessonBalance}분');
    }
    if (widget.timeBalance > 0) {
      items.add('시간권: ${widget.timeBalance}분');
    }
    if (widget.gameBalance > 0) {
      items.add('게임권: ${widget.gameBalance}회');
    }
    if (widget.termExpiryDate != null && widget.termExpiryDate!.isNotEmpty) {
      items.add('기간권: ~${widget.termExpiryDate}');
    }
    return items.join(', ');
  }

  Widget _buildContractHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Column(
        children: [
          Text(
            '회원권 양도계약서',
            style: AppTextStyles.h1.copyWith(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'MEMBER TRANSFER AGREEMENT',
            style: AppTextStyles.h3.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBranchInfo() {
    if (branchInfo == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '사용처 정보',
            style: AppTextStyles.h3.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow('사업장명', branchInfo!['branch_name'] ?? '-'),
                    _buildInfoRow('주소', branchInfo!['branch_address'] ?? '-'),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow('사업자등록번호', branchInfo!['branch_business_reg_no'] ?? '-'),
                    _buildInfoRow('전화번호', branchInfo!['branch_phone'] ?? '-'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: AppTextStyles.cardBody.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.cardBody.copyWith(
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContractTerms() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.yellow[50],
        border: Border.all(color: Colors.orange[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '계약조건',
            style: AppTextStyles.h3.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '• 본 회원권은 위 사용처에서만 사용 가능합니다.\n'
            '• 회원약관에 의거 양도수수료가 발생할 수 있습니다.\n'
            '• 양도 후 원회원의 회원권은 즉시 소멸됩니다.\n'
            '• 양수인은 양도받은 회원권의 조건을 그대로 승계합니다.',
            style: AppTextStyles.cardBody.copyWith(
              color: Colors.black,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransferDetails() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '양도내용',
            style: AppTextStyles.h3.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              if (widget.creditBalance > 0)
                _buildTransferItem(
                  '크레딧',
                  '${NumberFormat('#,###').format(widget.creditBalance)}원',
                  Icons.account_balance_wallet,
                  const Color(0xFF059669),
                ),
              if (widget.lessonBalance > 0)
                _buildTransferItem(
                  '레슨권',
                  '${widget.lessonBalance}분',
                  Icons.school,
                  const Color(0xFF3B82F6),
                ),
              if (widget.timeBalance > 0)
                _buildTransferItem(
                  '시간권',
                  '${widget.timeBalance}분',
                  Icons.access_time,
                  const Color(0xFF8B5CF6),
                ),
              if (widget.gameBalance > 0)
                _buildTransferItem(
                  '게임권',
                  '${widget.gameBalance}회',
                  Icons.sports_golf,
                  const Color(0xFFEC4899),
                ),
              if (widget.termExpiryDate != null && widget.termExpiryDate!.isNotEmpty)
                _buildTransferItem(
                  '기간권',
                  '~${widget.termExpiryDate}',
                  Icons.calendar_today,
                  const Color(0xFFF59E0B),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransferItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            '$label: $value',
            style: AppTextStyles.cardBody.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartiesInfo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildPartyInfo('양도인', widget.contract),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _buildPartyInfo('양수인', widget.transferee),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPartyInfo(String title, Map<String, dynamic> member) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: title == '양도인' ? Colors.blue[50] : Colors.green[50],
        border: Border.all(
          color: title == '양도인' ? Colors.blue[300]! : Colors.green[300]!,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.cardTitle.copyWith(
              fontWeight: FontWeight.bold,
              color: title == '양도인' ? Colors.blue[800] : Colors.green[800],
            ),
          ),
          const SizedBox(height: 8),
          _buildPartyDetail('성명', member['member_name'] ?? '-'),
          _buildPartyDetail('회원번호', member['member_id']?.toString() ?? '-'),
          _buildPartyDetail('전화번호', member['member_phone'] ?? '-'),
        ],
      ),
    );
  }

  Widget _buildPartyDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              '$label:',
              style: AppTextStyles.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.caption.copyWith(
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignatureSection() {
    final today = DateFormat('yyyy년 MM월 dd일').format(DateTime.now());
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '양도일: $today',
            style: AppTextStyles.cardBody.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '양도인',
                      style: AppTextStyles.cardBody.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 40),
                    Container(
                      width: double.infinity,
                      height: 1,
                      color: Colors.black,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '(서명)',
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 40),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '양수인',
                      style: AppTextStyles.cardBody.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 40),
                    Container(
                      width: double.infinity,
                      height: 1,
                      color: Colors.black,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '(서명)',
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('회원권 양도계약서'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          IconButton(
            onPressed: _printContract,
            icon: const Icon(Icons.print),
            tooltip: '인쇄',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Container(
            width: 595, // A4 세로 너비 (210mm)
            constraints: const BoxConstraints(
              minHeight: 842, // A4 세로 높이 (297mm)
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey[300]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildContractHeader(),
                _buildBranchInfo(),
                _buildContractTerms(),
                _buildTransferDetails(),
                _buildPartiesInfo(),
                _buildSignatureSection(),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: _printContract,
            backgroundColor: const Color(0xFF059669),
            child: const Icon(Icons.print, color: Colors.white),
            tooltip: '인쇄',
          ),
        ],
      ),
    );
  }
}
