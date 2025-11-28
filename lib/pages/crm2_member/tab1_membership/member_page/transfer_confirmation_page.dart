import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:html' as html;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show rootBundle;
import '/services/api_service.dart';
import '/constants/font_sizes.dart';

class TransferConfirmationPage extends StatefulWidget {
  final Map<String, dynamic> contract;
  final Map<String, dynamic> transferee;
  final int creditBalance;
  final int lessonBalance;
  final int timeBalance;
  final int gameBalance;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const TransferConfirmationPage({
    Key? key,
    required this.contract,
    required this.transferee,
    required this.creditBalance,
    required this.lessonBalance,
    required this.timeBalance,
    required this.gameBalance,
    required this.onConfirm,
    required this.onCancel,
  }) : super(key: key);

  @override
  _TransferConfirmationPageState createState() => _TransferConfirmationPageState();
}

class _TransferConfirmationPageState extends State<TransferConfirmationPage> {
  Map<String, dynamic>? branchInfo;
  bool isLoading = true;
  String? _transferorPhone; // 양도인 전화번호 (계약에 없을 때 조회)

  @override
  void initState() {
    super.initState();
    _loadBranchInfo();
    _loadTransferorPhoneIfNeeded();
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

  Future<void> _loadTransferorPhoneIfNeeded() async {
    if ((widget.contract['member_phone'] ?? '').toString().trim().isNotEmpty) {
      _transferorPhone = widget.contract['member_phone']?.toString();
      return;
    }
    try {
      final data = await ApiService.getDataList(
        table: 'v3_members',
        where: [
          {
            'field': 'member_id',
            'operator': '=',
            'value': widget.contract['member_id'],
          },
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
          _transferorPhone = data.first['member_phone']?.toString();
        });
      }
    } catch (e) {
      // 무시: 폰 없으면 '-' 처리
    }
  }

  void _printContract() {
    final htmlDoc = _buildPrintableHtml();
    final blob = html.Blob([htmlDoc], 'text/html');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.window.open(url, '_blank');
    // 약간의 지연 후 URL 해제 (새 창이 로드될 시간 확보)
    Future.delayed(const Duration(seconds: 2), () {
      html.Url.revokeObjectUrl(url);
    });
  }

  String _buildPrintableHtml() {
    final today = DateFormat('yyyy년 MM월 dd일').format(DateTime.now());
    final items = _getTransferItemsText();
    final branchName = branchInfo?['branch_name'] ?? '-';
    final branchAddress = branchInfo?['branch_address'] ?? '-';
    final branchRegNo = branchInfo?['branch_business_reg_no'] ?? '-';
    final branchPhone = branchInfo?['branch_phone'] ?? '-';

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8" />
  <title>회원권 양도 확인서</title>
  <style>
    @page { size: A4; margin: 20mm; }
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI',
           'Noto Sans KR', Roboto, Helvetica, Arial, 'Apple SD Gothic Neo',
           'Malgun Gothic', '맑은 고딕', sans-serif; margin:0; background:#fff; }
    .container { max-width: 210mm; margin: 0 auto; padding: 0; }
    .header { text-align:center; padding:20px; border:2px solid #000; }
    .title { font-size:26px; font-weight:700; }
    .subtitle { color:#666; margin-top:6px; }
    .section { border:1px solid #ddd; padding:14px; margin:14px 0; }
    .section h3 { margin:0 0 8px 0; font-size:16px; }
    .row { display:flex; gap:24px; }
    .col { flex:1; }
    .info-row { display:flex; margin-bottom:4px; }
    .label { width:120px; font-weight:600; }
    .sign { margin-top:20px; }
    .sign .line { border-bottom:1px solid #000; height:1px; margin:24px 0 6px; }
    @media print {
      body { background:#fff; }
    }
  </style>
  <script>
    window.onload = function(){
      window.print();
      setTimeout(function(){ window.close(); }, 200);
    }
  </script>
  </head>
  <body>
    <div class="container">
      <div class="header">
        <div class="title">회원권 양도 확인서</div>
      </div>

      <div class="section">
        <h3>사용처 정보</h3>
        <div class="row">
          <div class="col">
            <div class="info-row"><div class="label">사업장명</div><div>${branchName}</div></div>
            <div class="info-row"><div class="label">주소</div><div>${branchAddress}</div></div>
          </div>
          <div class="col">
            <div class="info-row"><div class="label">사업자등록번호</div><div>${branchRegNo}</div></div>
            <div class="info-row"><div class="label">전화번호</div><div>${branchPhone}</div></div>
          </div>
        </div>
      </div>

      <div class="section">
        <h3>계약조건</h3>
        <div>• 본 회원권은 위 사용처에서만 사용 가능합니다.</div>
        <div>• 회원약관에 의거 양도수수료가 발생할 수 있습니다.</div>
        <div>• 양도 후 원회원의 회원권은 즉시 소멸됩니다.</div>
        <div>• 양수인은 양도받은 회원권의 조건을 그대로 승계합니다.</div>
      </div>

      <div class="section">
        <h3>양도내용</h3>
        <div>${items.isEmpty ? '-' : items}</div>
        <div style="margin-top:12px;">양도일: ${today}</div>
      </div>

      

      <div class="row">
        <div class="col">
          <div class="section" style="text-align:left;">
            <h3>양도인</h3>
            <div class="info-row"><div class="label">성명</div><div>${(widget.contract['member_name'] ?? '-')} (서명)</div></div>
            <div class="info-row"><div class="label">회원번호</div><div>${(widget.contract['member_id'] ?? '-')}</div></div>
            <div class="info-row"><div class="label">전화번호</div><div>${(_transferorPhone ?? widget.contract['member_phone'] ?? '-')}</div></div>
          </div>
        </div>
        <div class="col">
          <div class="section" style="text-align:left;">
            <h3>양수인</h3>
            <div class="info-row"><div class="label">성명</div><div>${(widget.transferee['member_name'] ?? '-')} (서명)</div></div>
            <div class="info-row"><div class="label">회원번호</div><div>${(widget.transferee['member_id'] ?? '-')}</div></div>
            <div class="info-row"><div class="label">전화번호</div><div>${(widget.transferee['member_phone'] ?? '-')}</div></div>
          </div>
        </div>
      </div>
    </div>
  </body>
</html>
''';
  }

  Future<void> _downloadPDF() async {
    final doc = pw.Document();

    final today = DateFormat('yyyy년 MM월 dd일').format(DateTime.now());
    final items = _getTransferItemsText();
    final branchName = branchInfo?['branch_name'] ?? '-';
    final branchAddress = branchInfo?['branch_address'] ?? '-';
    final branchRegNo = branchInfo?['branch_business_reg_no'] ?? '-';
    final branchPhone = branchInfo?['branch_phone'] ?? '-';

    // 한글 폰트 로드 (에셋에 NotoSansKR-Regular.ttf, NotoSansKR-Bold.ttf 추가 필요)
    pw.Font? baseKorean;
    pw.Font? boldKorean;
    try {
      final baseData = await rootBundle.load('assets/fonts/NotoSansKR-Regular.ttf');
      baseKorean = pw.Font.ttf(baseData);
    } catch (_) {}
    try {
      final boldData = await rootBundle.load('assets/fonts/NotoSansKR-Bold.ttf');
      boldKorean = pw.Font.ttf(boldData);
    } catch (_) {}

    final theme = (baseKorean != null)
        ? pw.ThemeData.withFont(
            base: baseKorean,
            bold: boldKorean ?? baseKorean,
          )
        : pw.ThemeData.base();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: theme,
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(width: 2, color: PdfColors.black),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Text('회원권 양도계약서', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                      // 영어 부제 제거
                    ],
                  ),
                ),
                pw.SizedBox(height: 14),
                // Branch info
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300)),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('사용처 정보', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 8),
                      _pdfInfoRow('사업장명', branchName),
                      _pdfInfoRow('주소', branchAddress),
                      _pdfInfoRow('사업자등록번호', branchRegNo),
                      _pdfInfoRow('전화번호', branchPhone),
                    ],
                  ),
                ),
                pw.SizedBox(height: 10),
                // Terms
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.orange300)),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('계약조건', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 6),
                      pw.Text('• 본 회원권은 위 사용처에서만 사용 가능합니다.'),
                      pw.Text('• 회원약관에 의거 양도수수료가 발생할 수 있습니다.'),
                      pw.Text('• 양도 후 원회원의 회원권은 즉시 소멸됩니다.'),
                      pw.Text('• 양수인은 양도받은 회원권의 조건을 그대로 승계합니다.'),
                    ],
                  ),
                ),
                pw.SizedBox(height: 10),
                // Items
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300)),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('양도내용', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 6),
                      pw.Text(items.isEmpty ? '-' : items),
                    ],
                  ),
                ),
                pw.SizedBox(height: 10),
                // Parties side by side
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(child: _pdfPartyBox('양도인', widget.contract)),
                    pw.SizedBox(width: 16),
                    pw.Expanded(child: _pdfPartyBox('양수인', widget.transferee)),
                  ],
                ),
                pw.SizedBox(height: 10),
                // Signature
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300)),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('양도일: $today', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 12),
                      pw.Row(
                        children: [
                          pw.Expanded(child: _pdfSignatureBox('양도인')),
                          pw.SizedBox(width: 24),
                          pw.Expanded(child: _pdfSignatureBox('양수인')),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    final fileName = '회원권_양도계약서_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';
    final bytes = await doc.save();
    await Printing.sharePdf(bytes: bytes, filename: fileName);
  }

  pw.Widget _pdfInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(children: [
        pw.Container(width: 100, child: pw.Text('$label:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
        pw.Expanded(child: pw.Text(value)),
      ]),
    );
  }

  pw.Widget _pdfPartyBox(String title, Map<String, dynamic> member) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300)),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        _pdfInfoRow('성명', (member['member_name'] ?? '-').toString()),
        _pdfInfoRow('회원번호', (member['member_id'] ?? '-').toString()),
        _pdfInfoRow('전화번호', (member['member_phone'] ?? '-').toString()),
      ]),
    );
  }

  pw.Widget _pdfSignatureBox(String title) {
    return pw.Column(children: [
      pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 24),
      pw.Container(height: 1, color: PdfColors.black),
      pw.SizedBox(height: 6),
      pw.Text('(서명)', style: pw.TextStyle(color: PdfColors.grey700)),
    ]);
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
    if (widget.contract['contract_term_month_expiry_date'] != null && 
        widget.contract['contract_term_month_expiry_date'].toString().isNotEmpty) {
      items.add('기간권: ~${widget.contract['contract_term_month_expiry_date']}');
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
              if (widget.contract['contract_term_month_expiry_date'] != null &&
                  widget.contract['contract_term_month_expiry_date'].toString().isNotEmpty)
                _buildTransferItem(
                  '기간권',
                  '~${widget.contract['contract_term_month_expiry_date']}',
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
      return const Dialog(
        child: SizedBox(
          width: 200,
          height: 200,
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: 595, // A4 세로 너비
        constraints: const BoxConstraints(
          minHeight: 842, // A4 세로 높이
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // 헤더
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF3B82F6),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '회원권 양도 확인서',
                    style: AppTextStyles.h2.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: _printContract,
                        icon: const Icon(Icons.print, color: Colors.white),
                        tooltip: '인쇄',
                      ),
                      IconButton(
                        onPressed: widget.onCancel,
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 계약서 내용
            Expanded(
              child: SingleChildScrollView(
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

            // 하단 버튼
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFF9FAFB),
                border: Border(
                  top: BorderSide(color: Color(0xFFE5E7EB)),
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.onCancel,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: Color(0xFFD1D5DB)),
                      ),
                      child: Text(
                        '취소',
                        style: AppTextStyles.cardBody.copyWith(
                          color: const Color(0xFF374151),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: widget.onConfirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            '확인 및 양도 진행',
                            style: AppTextStyles.cardBody.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
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

}
