import 'package:flutter/material.dart';
import '../../../services/api_service.dart';

/// 약관 타입을 저장 형식으로 변환
String _convertTermTypeForSave(String termsType) {
  switch (termsType) {
    case '표준약관 1 (부분환불형)':
      return '표준약관1(부분환불형)_1.0';
    case '표준약관 2 (전액환불형)':
      return '표준약관2(전액환불형)_1.0';
    case '표준약관 3 (환불제한형)':
      return '표준약관3(환불제한형)_1.0';
    case '비표준약관 신청':
      return '비표준약관신청_1.0';
    default:
      return termsType;
  }
}

/// 저장된 형식을 UI 표시 형식으로 변환
String _convertTermTypeForDisplay(String? savedType) {
  if (savedType == null || savedType.isEmpty) {
    return '표준약관 1 (부분환불형)'; // 기본값
  }

  // 버전 정보 제거 (예: '_1.0' 제거)
  String typeWithoutVersion = savedType.split('_')[0];

  switch (typeWithoutVersion) {
    case '표준약관1(부분환불형)':
      return '표준약관 1 (부분환불형)';
    case '표준약관2(전액환불형)':
      return '표준약관 2 (전액환불형)';
    case '표준약관3(환불제한형)':
      return '표준약관 3 (환불제한형)';
    case '비표준약관신청':
      return '비표준약관 신청';
    default:
      return '표준약관 1 (부분환불형)'; // 기본값
  }
}

/// 약관 내용 반환 함수
String getTermsContent(String termsType, String branchName) {
  switch (termsType) {
    case '표준약관 1 (부분환불형)':
      return '''
제1조 (목적)
본 약관은 $branchName(이하 "매장")이 제공하는 온라인 회원권의 판매 및 이용 조건, 당사자의 권리·의무 및 책임사항을 규정함을 목적으로 합니다.

제2조 (적용범위)
본 약관은 플랫폼을 통해 온라인으로 판매된 회원권에만 적용되며, 매장에서 오프라인으로 판매한 회원권에는 적용되지 않습니다.

제3조 (정의)
1. "회원권"이란 매장이 제공하는 골프 관련 서비스를 일정 기간 또는 횟수 이용할 수 있는 권리를 말합니다.
2. "회원"이란 본 약관에 동의하고 회원권을 구매한 자를 말합니다.
3. "서비스 이용"이란 회원권을 사용한 예약 완료를 말하며, 예약 시점부터 이용으로 간주합니다.
4. "회원혜택"이란 회원권 구매 시 무상 제공되는 추가 이용권을 말합니다.
5. "플랫폼 사업자"란 온라인 회원권 판매 플랫폼을 운영하는 주식회사 이네이블테크를 말합니다.

제4조 (회원권의 내용)
회원권의 종류, 이용기간, 이용횟수, 가격 등은 매장이 정하여 구매 시 명시합니다.

제5조 (계약의 성립)
1. 회원권 구매계약은 회원의 구매 신청과 플랫폼을 통한 결제 완료로 성립합니다.
2. 결제수단은 플랫폼이 제공하는 방법에 따릅니다.

제6조 (청약철회)
1. 회원은 구매일로부터 10일 이내에 서비스를 미이용한 경우 청약을 철회할 수 있습니다.
2. 제1항에 따른 청약철회 시 결제금액 전액을 환급합니다.
3. 제1항의 청약철회는 플랫폼 사업자를 통해 신청합니다.

제7조 (계약의 해제 및 환급)
1. 회원이 서비스를 1회 이상 이용한 경우 계약 해제를 청구할 수 있으며, 이 경우 다음 각 호에 따라 환급합니다.
   ① 이용 서비스는 비회원가 기준으로 산정합니다.
   ② 회원혜택 사용분도 비회원가 기준으로 산정합니다.
   ③ 잔여금액에서 10%의 위약금을 공제하고 환급합니다.

   환급금액 = (결제금액 - 비회원가 기준 이용금액) × 90%

2. 제1항의 계약 해제는 매장 방문을 통해 신청합니다.

제8조 (개별 예약의 취소)
개별 예약의 취소 및 변경은 매장이 별도 공지하는 매장이용약관에 따릅니다.

제9조 (회원권의 양도)
1. 회원권은 제3자에게 양도할 수 있습니다.
2. 온라인 구매 회원권은 오프라인 양도도 가능합니다.
3. 양도 시 양도인과 양수인은 매장에 통지하고 소정의 절차를 이행하여야 합니다.
4. 플랫폼 사업자에게 양수인 주선을 의뢰하는 경우 양도금액의 10%에 해당하는 수수료가 발생할 수 있습니다.
5. 양도수수료는 양도인이 부담함을 원칙으로 하되, 당사자 합의로 달리 정할 수 있습니다.

제10조 (매장의 의무)
1. 매장은 약정한 서비스를 성실히 제공하여야 합니다.
2. 매장의 귀책사유로 서비스 제공이 불가능한 경우 회원은 전액 환급을 청구할 수 있습니다.

제11조 (회원의 의무)
1. 회원은 매장의 이용규칙을 준수하여야 합니다.
2. 회원은 회원권을 부정 사용하거나 타인에게 대여할 수 없습니다.

제12조 (약관의 우선순위)
1. 본 약관과 매장이용약관이 상충하는 경우 본 약관이 우선 적용됩니다.
2. 본 약관에 정하지 않은 사항은 매장이용약관 및 관련 법령을 따릅니다.

제13조 (개인정보보호)
매장과 플랫폼 사업자는 관련 법령에 따라 회원의 개인정보를 보호합니다.

제14조 (분쟁의 해결)
본 약관에 관한 분쟁은 당사자 간 협의로 해결하며, 합의가 이루어지지 않을 때는 관련 법령 및 관할법원의 판단에 따릅니다.

부칙
본 약관은 2025년 11월 22일부터 시행합니다.
''';

    case '표준약관 2 (전액환불형)':
      return '''
제1조 (목적)
본 약관은 $branchName(이하 "매장")이 제공하는 온라인 회원권의 판매 및 이용 조건, 당사자의 권리·의무 및 책임사항을 규정함을 목적으로 합니다.

제2조 (적용범위)
본 약관은 플랫폼을 통해 온라인으로 판매된 회원권에만 적용되며, 매장에서 오프라인으로 판매한 회원권에는 적용되지 않습니다.

제3조 (정의)
1. "회원권"이란 매장이 제공하는 골프 관련 서비스를 일정 기간 또는 횟수 이용할 수 있는 권리를 말합니다.
2. "회원"이란 본 약관에 동의하고 회원권을 구매한 자를 말합니다.
3. "서비스 이용"이란 회원권을 사용한 예약 완료를 말하며, 예약 시점부터 이용으로 간주합니다.
4. "회원혜택"이란 회원권 구매 시 무상 제공되는 추가 이용권을 말합니다.
5. "플랫폼 사업자"란 온라인 회원권 판매 플랫폼을 운영하는 주식회사 이네이블테크를 말합니다.

제4조 (회원권의 내용)
회원권의 종류, 이용기간, 이용횟수, 가격 등은 매장이 정하여 구매 시 명시합니다.

제5조 (계약의 성립)
1. 회원권 구매계약은 회원의 구매 신청과 플랫폼을 통한 결제 완료로 성립합니다.
2. 결제수단은 플랫폼이 제공하는 방법에 따릅니다.

제6조 (청약철회)
1. 회원은 구매일로부터 10일 이내에 서비스를 미이용한 경우 청약을 철회할 수 있습니다.
2. 제1항에 따른 청약철회 시 결제금액 전액을 환급합니다.
3. 제1항의 청약철회는 플랫폼 사업자를 통해 신청합니다.

제7조 (계약의 해제 및 환급)
1. 회원이 서비스를 1회 이상 이용한 경우 계약 해제를 청구할 수 있으며, 이 경우 다음 각 호에 따라 환급합니다.
   ① 유상 제공분은 비회원가 기준으로 산정합니다.
   ② 회원혜택 사용분은 환급 산정에서 제외합니다.
   ③ 잔여금액 전액을 환급합니다.

   환급금액 = 결제금액 - 비회원가 기준 유상 이용금액

2. 제1항의 계약 해제는 매장 방문을 통해 신청합니다.

제8조 (개별 예약의 취소)
개별 예약의 취소 및 변경은 매장이 별도 공지하는 매장이용약관에 따릅니다.

제9조 (회원권의 양도)
1. 회원권은 제3자에게 양도할 수 있습니다.
2. 온라인 구매 회원권은 오프라인 양도도 가능합니다.
3. 양도 시 양도인과 양수인은 매장에 통지하고 소정의 절차를 이행하여야 합니다.
4. 플랫폼 사업자에게 양수인 주선을 의뢰하는 경우 양도금액의 10%에 해당하는 수수료가 발생할 수 있습니다.
5. 양도수수료는 양도인이 부담함을 원칙으로 하되, 당사자 합의로 달리 정할 수 있습니다.

제10조 (매장의 의무)
1. 매장은 약정한 서비스를 성실히 제공하여야 합니다.
2. 매장의 귀책사유로 서비스 제공이 불가능한 경우 회원은 전액 환급을 청구할 수 있습니다.

제11조 (회원의 의무)
1. 회원은 매장의 이용규칙을 준수하여야 합니다.
2. 회원은 회원권을 부정 사용하거나 타인에게 대여할 수 없습니다.

제12조 (약관의 우선순위)
1. 본 약관과 매장이용약관이 상충하는 경우 본 약관이 우선 적용됩니다.
2. 본 약관에 정하지 않은 사항은 매장이용약관 및 관련 법령을 따릅니다.

제13조 (개인정보보호)
매장과 플랫폼 사업자는 관련 법령에 따라 회원의 개인정보를 보호합니다.

제14조 (분쟁의 해결)
본 약관에 관한 분쟁은 당사자 간 협의로 해결하며, 합의가 이루어지지 않을 때는 관련 법령 및 관할법원의 판단에 따릅니다.

부칙
본 약관은 2025년 11월 22일부터 시행합니다.
''';

    case '표준약관 3 (환불제한형)':
      return '''
제1조 (목적)
본 약관은 $branchName(이하 "매장")이 제공하는 온라인 회원권의 판매 및 이용 조건, 당사자의 권리·의무 및 책임사항을 규정함을 목적으로 합니다.

제2조 (적용범위)
본 약관은 플랫폼을 통해 온라인으로 판매된 회원권에만 적용되며, 매장에서 오프라인으로 판매한 회원권에는 적용되지 않습니다.

제3조 (정의)
1. "회원권"이란 매장이 제공하는 골프 관련 서비스를 일정 기간 또는 횟수 이용할 수 있는 권리를 말합니다.
2. "회원"이란 본 약관에 동의하고 회원권을 구매한 자를 말합니다.
3. "서비스 이용"이란 회원권을 사용한 예약 완료를 말하며, 예약 시점부터 이용으로 간주합니다.
4. "플랫폼 사업자"란 온라인 회원권 판매 플랫폼을 운영하는 주식회사 이네이블테크를 말합니다.

제4조 (회원권의 내용)
회원권의 종류, 이용기간, 이용횟수, 가격 등은 매장이 정하여 구매 시 명시합니다.

제5조 (계약의 성립)
1. 회원권 구매계약은 회원의 구매 신청과 플랫폼을 통한 결제 완료로 성립합니다.
2. 결제수단은 플랫폼이 제공하는 방법에 따릅니다.

제6조 (청약철회)
1. 회원은 구매일로부터 10일 이내에 서비스를 미이용한 경우 청약을 철회할 수 있습니다.
2. 제1항에 따른 청약철회 시 결제금액 전액을 환급합니다.
3. 제1항의 청약철회는 플랫폼 사업자를 통해 신청합니다.

제7조 (계약 해제의 제한)
1. 회원이 서비스를 1회 이상 이용한 경우 매장의 귀책사유 없이는 계약을 해제할 수 없습니다.
2. 매장의 귀책사유로 서비스 제공이 불가능한 경우에 한하여 미이용 잔여분에 대한 환급을 청구할 수 있습니다.
3. 제2항의 귀책사유는 다음 각 호와 같습니다.
   ① 매장의 폐업 또는 장기 영업정지
   ② 매장 사정으로 인한 서비스 제공 중단
   ③ 기타 매장의 명백한 귀책사유로 인한 서비스 제공 불가
4. 제1항 및 제2항의 계약 해제는 매장 방문을 통해 신청합니다.

제8조 (개별 예약의 취소)
개별 예약의 취소 및 변경은 매장이 별도 공지하는 매장이용약관에 따릅니다.

제9조 (회원권의 양도)
1. 회원권은 제3자에게 양도할 수 있습니다.
2. 온라인 구매 회원권은 오프라인 양도도 가능합니다.
3. 양도 시 양도인과 양수인은 매장에 통지하고 소정의 절차를 이행하여야 합니다.
4. 플랫폼 사업자에게 양수인 주선을 의뢰하는 경우 양도금액의 10%에 해당하는 수수료가 발생할 수 있습니다.
5. 양도수수료는 양도인이 부담함을 원칙으로 하되, 당사자 합의로 달리 정할 수 있습니다.

제10조 (매장의 의무)
1. 매장은 약정한 서비스를 성실히 제공하여야 합니다.
2. 매장의 귀책사유로 서비스 제공이 불가능한 경우 회원은 환급을 청구할 수 있습니다.

제11조 (회원의 의무)
1. 회원은 매장의 이용규칙을 준수하여야 합니다.
2. 회원은 회원권을 부정 사용하거나 타인에게 대여할 수 없습니다.
3. 회원은 본 약관의 계약 해제 제한 조항을 충분히 이해하고 동의한 것으로 간주합니다.

제12조 (약관의 우선순위)
1. 본 약관과 매장이용약관이 상충하는 경우 본 약관이 우선 적용됩니다.
2. 본 약관에 정하지 않은 사항은 매장이용약관 및 관련 법령을 따릅니다.

제13조 (개인정보보호)
매장과 플랫폼 사업자는 관련 법령에 따라 회원의 개인정보를 보호합니다.

제14조 (분쟁의 해결)
본 약관에 관한 분쟁은 당사자 간 협의로 해결하며, 합의가 이루어지지 않을 때는 관련 법령 및 관할법원의 판단에 따릅니다.

부칙
본 약관은 2025년 11월 22일부터 시행합니다.
''';

    case '비표준약관 신청':
      return '''
비표준약관 신청 안내

표준약관 1, 2, 3 외에 매장 특성에 맞는 별도 약관이 필요하신 경우,
아래 이메일로 문의해 주시기 바랍니다.

📧 문의 이메일: enables.tech@gmail.com

신청 절차:
1. 매장에서 원하시는 약관 내용을 이메일로 송부
2. (주)이네이블테크에서 내용 검토
3. 검토 완료 후 승인 여부 안내
4. 승인된 경우 플랫폼에 적용

※ 참고사항
- 검토에는 영업일 기준 5-7일 정도 소요됩니다
- 신청하신 약관이 승인되지 않을 수 있습니다
''';

    default:
      return '';
  }
}

/// 약관 다이얼로그 표시
void showTermsDialog(BuildContext context) async {
  // 브랜치 이름 가져오기
  String branchName = 'Friends Academy Mokdong Premium';
  String selectedTermsType = '표준약관 1 (부분환불형)';
  String initialTermsType = '표준약관 1 (부분환불형)'; // 초기 DB 값 저장

  try {
    final branch = ApiService.getCurrentBranch();
    if (branch != null && branch['branch_name'] != null) {
      branchName = branch['branch_name'].toString();
    }

    // DB에서 저장된 약관 타입 가져오기
    if (branch != null && branch['online_sales_term_type'] != null) {
      selectedTermsType = _convertTermTypeForDisplay(branch['online_sales_term_type'].toString());
      initialTermsType = selectedTermsType; // 초기값 저장
    }
  } catch (e) {
    print('브랜치 정보 가져오기 실패: $e');
  }

  bool isEditMode = false; // 변경 모드 여부

  showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.3),
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 10,
            child: Container(
              width: 900,
              height: 950,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 헤더
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        bottom: BorderSide(
                          color: Color(0xFFE5E7EB),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Color(0xFF6366F1).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.description,
                                color: Color(0xFF6366F1),
                                size: 24,
                              ),
                            ),
                            SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '온라인 회원권 판매약관',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  '회원권 판매 시 적용되는 약관을 확인하고 선택하세요',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            if (!isEditMode) ...[
                              // 현재 적용중인 약관 표시
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Color(0xFF10B981).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Color(0xFF10B981).withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.check_circle, color: Color(0xFF10B981), size: 18),
                                    SizedBox(width: 8),
                                    Text(
                                      '적용중: $initialTermsType',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF059669),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: 8),
                              // 변경 버튼
                              OutlinedButton.icon(
                                onPressed: () {
                                  setDialogState(() {
                                    isEditMode = true;
                                  });
                                },
                                icon: Icon(Icons.edit, size: 16),
                                label: Text('변경'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Color(0xFF6366F1),
                                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  side: BorderSide(color: Color(0xFF6366F1)),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ] else ...[
                              // 드롭다운 (변경 모드)
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Color(0xFFF9FAFB),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Color(0xFF6366F1), width: 2),
                                ),
                                child: DropdownButton<String>(
                                  value: selectedTermsType,
                                  underline: SizedBox(),
                                  dropdownColor: Colors.white,
                                  icon: Icon(Icons.keyboard_arrow_down, color: Color(0xFF6366F1), size: 18),
                                  items: [
                                    '표준약관 1 (부분환불형)',
                                    '표준약관 2 (전액환불형)',
                                    '표준약관 3 (환불제한형)',
                                    '비표준약관 신청'
                                  ].map((String value) {
                                    return DropdownMenuItem<String>(
                                      value: value,
                                      child: Text(
                                        value,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF111827),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (String? newValue) {
                                    if (newValue != null) {
                                      setDialogState(() {
                                        selectedTermsType = newValue;
                                      });
                                    }
                                  },
                                ),
                              ),
                              SizedBox(width: 8),
                              // 취소 버튼
                              TextButton(
                                onPressed: () {
                                  setDialogState(() {
                                    selectedTermsType = initialTermsType;
                                    isEditMode = false;
                                  });
                                },
                                child: Text('취소', style: TextStyle(color: Color(0xFF6B7280))),
                              ),
                            ],
                            SizedBox(width: 12),
                            IconButton(
                              icon: Icon(Icons.close, size: 22),
                              onPressed: () => Navigator.pop(context),
                              color: Color(0xFF9CA3AF),
                              tooltip: '닫기',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // 본문 영역
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Color(0xFFFAFAFA),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Color(0xFFE5E7EB)),
                        ),
                        child: SingleChildScrollView(
                          child: SizedBox(
                            width: double.infinity,
                            child: SelectableText(
                              getTermsContent(selectedTermsType, branchName),
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.6,
                                color: Color(0xFF1F2937),
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 하단 버튼 영역
                  Container(
                    padding: EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        top: BorderSide(
                          color: Color(0xFFE5E7EB),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              side: BorderSide(color: Color(0xFFD1D5DB), width: 1.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              '닫기',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: selectedTermsType != initialTermsType ? () async {
                              try {
                                final branchId = ApiService.getCurrentBranchId();
                                if (branchId == null) {
                                  throw Exception('현재 지점 정보가 없습니다.');
                                }

                                // 약관 타입을 저장 형식으로 변환
                                String termTypeValue = _convertTermTypeForSave(selectedTermsType);

                                // v2_branch 테이블 업데이트
                                await ApiService.updateData(
                                  table: 'v2_branch',
                                  data: {
                                    'online_sales_term_type': termTypeValue,
                                  },
                                  where: [
                                    {
                                      'field': 'branch_id',
                                      'operator': '=',
                                      'value': branchId,
                                    }
                                  ],
                                );

                                // 저장 성공 후 초기값 업데이트
                                setDialogState(() {
                                  initialTermsType = selectedTermsType;
                                  isEditMode = false;
                                });

                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('$selectedTermsType이(가) 저장되었습니다.'),
                                      backgroundColor: Color(0xFF10B981),
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('저장 실패: $e'),
                                      backgroundColor: Colors.red,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  );
                                }
                              }
                            } : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF6366F1),
                              disabledBackgroundColor: Color(0xFFE5E7EB),
                              padding: EdgeInsets.symmetric(vertical: 16),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.check,
                                  size: 20,
                                  color: selectedTermsType != initialTermsType ? Colors.white : Color(0xFF9CA3AF),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  '저장',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: selectedTermsType != initialTermsType ? Colors.white : Color(0xFF9CA3AF),
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
        },
      );
    },
  );
}
