import 'package:flutter/material.dart';
import '/services/api_service.dart';
import '/services/sms_service.dart';
import '/services/tab_design_upper.dart';
import '/widgets/planner_app_popup.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:html' as html;
import 'tab1_memo_tab.dart';
import 'tab2_contract.dart';
import 'tab3_credit.dart';
import 'tab4_lesson.dart';
import 'tab5_time.dart';
import 'tab6_ts_use.dart';
import 'tab7_term.dart';
import 'tab8_junior.dart';
import 'tab9_game.dart';
import '/constants/font_sizes.dart';

class MemberMainWidget extends StatefulWidget {
  const MemberMainWidget({
    super.key,
    required this.memberId,
    this.memberData,
  });

  final int memberId;
  final Map<String, dynamic>? memberData;

  // 새 창에서 회원 상세 페이지를 여는 정적 메서드
  static void openInNewWindow(int memberId) {
    final memberPageHtml = '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>회원 정보 - $memberId</title>
    <style>
        body {
            margin: 0;
            padding: 20px;
            font-family: 'Pretendard', -apple-system, BlinkMacSystemFont, sans-serif;
            background-color: #f8fafc;
        }
        .member-container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            border-radius: 16px;
            box-shadow: 0 4px 16px rgba(0,0,0,0.1);
            overflow: hidden;
        }
        .member-header {
            background: linear-gradient(135deg, #1e293b, #334155);
            color: white;
            padding: 20px;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        .member-title {
            display: flex;
            align-items: center;
            gap: 12px;
        }
        .member-icon {
            background: #06b6d4;
            padding: 10px;
            border-radius: 12px;
            box-shadow: 0 4px 8px rgba(6, 182, 212, 0.3);
        }
        .member-info h1 {
            margin: 0;
            font-size: 20px;
            font-weight: 700;
        }
        .member-info p {
            margin: 0;
            font-size: 13px;
            color: #cbd5e1;
            font-weight: 500;
        }
        .save-btn {
            background: #10b981;
            color: white;
            border: none;
            padding: 8px 16px;
            border-radius: 10px;
            font-size: 14px;
            font-weight: 600;
            cursor: pointer;
            display: flex;
            align-items: center;
            gap: 6px;
        }
        .save-btn:hover {
            background: #059669;
        }
        .member-content {
            padding: 20px;
        }
        .basic-info {
            background: white;
            border-radius: 16px;
            padding: 20px;
            margin-bottom: 20px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.05);
        }
        .section-header {
            display: flex;
            align-items: center;
            gap: 8px;
            margin-bottom: 16px;
        }
        .section-header h2 {
            margin: 0;
            color: #0891b2;
            font-size: 16px;
            font-weight: 700;
        }
        .form-row {
            display: flex;
            gap: 16px;
            margin-bottom: 12px;
        }
        .form-field {
            flex: 1;
        }
        .form-field.flex-2 {
            flex: 2;
        }
        .form-label {
            display: flex;
            align-items: center;
            gap: 6px;
            margin-bottom: 6px;
            font-size: 12px;
            font-weight: 600;
            color: #374151;
        }
        .form-input {
            width: 100%;
            height: 36px;
            padding: 8px 12px;
            border: 1px solid #e5e7eb;
            border-radius: 8px;
            font-size: 13px;
            font-weight: 500;
            box-sizing: border-box;
        }
        .form-input:focus {
            outline: none;
            border-color: #06b6d4;
            border-width: 1.5px;
        }
        .tabs-container {
            background: white;
            border-radius: 16px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.05);
            overflow: hidden;
        }
        .tabs-header {
            background: linear-gradient(to bottom, #f8fafc, #f1f5f9);
            padding: 0 16px;
            border-bottom: 1px solid #e2e8f0;
        }
        .tabs {
            display: flex;
            gap: 20px;
        }
        .tab {
            padding: 16px 0;
            color: #64748b;
            font-size: 14px;
            font-weight: 500;
            cursor: pointer;
            border-bottom: 3px solid transparent;
            display: flex;
            align-items: center;
            gap: 6px;
        }
        .tab.active {
            color: #06b6d4;
            font-weight: 700;
            border-bottom-color: #06b6d4;
        }
        .tab-content {
            padding: 20px;
            min-height: 400px;
        }
        .loading {
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            padding: 40px;
            gap: 16px;
        }
        .spinner {
            width: 32px;
            height: 32px;
            border: 3px solid #e2e8f0;
            border-top: 3px solid #06b6d4;
            border-radius: 50%;
            animation: spin 1s linear infinite;
        }
        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }
    </style>
</head>
<body>
    <div class="member-container">
        <div class="member-header">
            <div class="member-title">
                <div class="member-icon">
                    <svg width="20" height="20" fill="white" viewBox="0 0 24 24">
                        <path d="M12 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z"/>
                    </svg>
                </div>
                <div class="member-info">
                    <p>회원 정보</p>
                    <h1 id="memberName">로딩중...</h1>
                </div>
            </div>
            <button class="save-btn" onclick="saveMemberInfo()">
                <svg width="16" height="16" fill="currentColor" viewBox="0 0 24 24">
                    <path d="M17 3H5c-1.11 0-2 .9-2 2v14c0 1.1.89 2 2 2h14c1.1 0 2-.9 2-2V7l-4-4zm-5 16c-1.66 0-3-1.34-3-3s1.34-3 3-3 3 1.34 3 3-1.34 3-3 3zm3-10H5V5h10v4z"/>
                </svg>
                저장
            </button>
        </div>
        
        <div class="member-content">
            <div class="basic-info">
                <div class="section-header">
                    <svg width="18" height="18" fill="#06b6d4" viewBox="0 0 24 24">
                        <path d="M14 2H6c-1.1 0-1.99.9-1.99 2L4 20c0 1.1.89 2 2 2h8c1.1 0 2-.9 2-2V8l-6-6zm2 16H8v-2h8v2zm0-4H8v-2h8v2zm-3-5V3.5L18.5 9H13z"/>
                    </svg>
                    <h2>기본 정보</h2>
                </div>
                
                <div class="form-row">
                    <div class="form-field">
                        <div class="form-label">
                            <svg width="14" height="14" fill="#06b6d4" viewBox="0 0 24 24">
                                <path d="M12 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z"/>
                            </svg>
                            이름 <span style="color: #ef4444;">*</span>
                        </div>
                        <input type="text" class="form-input" id="memberName" placeholder="이름을 입력하세요">
                    </div>
                    <div class="form-field">
                        <div class="form-label">
                            <svg width="14" height="14" fill="#06b6d4" viewBox="0 0 24 24">
                                <path d="M6.62 10.79c1.44 2.83 3.76 5.14 6.59 6.59l2.2-2.2c.27-.27.67-.36 1.02-.24 1.12.37 2.33.57 3.57.57.55 0 1 .45 1 1V20c0 .55-.45 1-1 1-9.39 0-17-7.61-17-17 0-.55.45-1 1-1h3.5c.55 0 1 .45 1 1 0 1.25.2 2.45.57 3.57.11.35.03.74-.25 1.02l-2.2 2.2z"/>
                            </svg>
                            전화번호
                        </div>
                        <input type="text" class="form-input" id="memberPhone" placeholder="전화번호를 입력하세요">
                    </div>
                    <div class="form-field">
                        <div class="form-label">
                            <svg width="14" height="14" fill="#06b6d4" viewBox="0 0 24 24">
                                <path d="M12 2C13.1 2 14 2.9 14 4C14 5.1 13.1 6 12 6C10.9 6 10 5.1 10 4C10 2.9 10.9 2 12 2ZM21 9V7L15 1H5C3.9 1 3 1.9 3 3V21C3 22.1 3.9 23 5 23H19C20.1 23 21 22.1 21 21V9Z"/>
                            </svg>
                            성별
                        </div>
                        <select class="form-input" id="memberGender">
                            <option value="남성">남성</option>
                            <option value="여성">여성</option>
                        </select>
                    </div>
                    <div class="form-field">
                        <div class="form-label">
                            <svg width="14" height="14" fill="#06b6d4" viewBox="0 0 24 24">
                                <path d="M19 3h-1V1h-2v2H8V1H6v2H5c-1.11 0-1.99.9-1.99 2L3 19c0 1.1.89 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zm0 16H5V8h14v11zM7 10h5v5H7z"/>
                            </svg>
                            생년월일
                        </div>
                        <input type="text" class="form-input" id="memberBirthdate" placeholder="생년월일을 입력하세요">
                    </div>
                </div>
                
                <div class="form-row">
                    <div class="form-field">
                        <div class="form-label">
                            <svg width="14" height="14" fill="#06b6d4" viewBox="0 0 24 24">
                                <path d="M12 2C13.1 2 14 2.9 14 4C14 5.1 13.1 6 12 6C10.9 6 10 5.1 10 4C10 2.9 10.9 2 12 2ZM21 9V7L15 1H5C3.9 1 3 1.9 3 3V21C3 22.1 3.9 23 5 23H19C20.1 23 21 22.1 21 21V9Z"/>
                            </svg>
                            닉네임
                        </div>
                        <input type="text" class="form-input" id="memberNickname" placeholder="닉네임을 입력하세요">
                    </div>
                    <div class="form-field">
                        <div class="form-label">
                            <svg width="14" height="14" fill="#06b6d4" viewBox="0 0 24 24">
                                <path d="M5.5 7A1.5 1.5 0 0 1 4 5.5A1.5 1.5 0 0 1 5.5 4A1.5 1.5 0 0 1 7 5.5A1.5 1.5 0 0 1 5.5 7M21.41 11.58L12.41 2.58C12.05 2.22 11.55 2 11 2H4C2.9 2 2 2.9 2 4V11C2 11.55 2.22 12.05 2.59 12.41L11.58 21.41C11.95 21.78 12.45 22 13 22S14.05 21.78 14.41 21.41L21.41 14.41C21.78 14.05 22 13.55 22 13S21.78 11.95 21.41 11.58Z"/>
                            </svg>
                            채널키워드
                        </div>
                        <input type="text" class="form-input" id="memberChannelKeyword" placeholder="채널키워드를 입력하세요">
                    </div>
                    <div class="form-field flex-2">
                        <div class="form-label">
                            <svg width="14" height="14" fill="#06b6d4" viewBox="0 0 24 24">
                                <path d="M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7zm0 9.5c-1.38 0-2.5-1.12-2.5-2.5s1.12-2.5 2.5-2.5 2.5 1.12 2.5 2.5-1.12 2.5-2.5 2.5z"/>
                            </svg>
                            주소
                        </div>
                        <input type="text" class="form-input" id="memberAddress" placeholder="주소를 입력하세요">
                    </div>
                </div>
            </div>
            
            <div class="tabs-container">
                <div class="tabs-header">
                    <div class="tabs">
                        <div class="tab active" onclick="switchTab('memo')">
                            <svg width="16" height="16" fill="currentColor" viewBox="0 0 24 24">
                                <path d="M14 2H6c-1.1 0-1.99.9-1.99 2L4 20c0 1.1.89 2 2 2h8c1.1 0 2-.9 2-2V8l-6-6zm2 16H8v-2h8v2zm0-4H8v-2h8v2zm-3-5V3.5L18.5 9H13z"/>
                            </svg>
                            메모
                        </div>
                        <div class="tab" onclick="switchTab('contract')">
                            <svg width="16" height="16" fill="currentColor" viewBox="0 0 24 24">
                                <path d="M14 2H6c-1.1 0-1.99.9-1.99 2L4 20c0 1.1.89 2 2 2h8c1.1 0 2-.9 2-2V8l-6-6zm2 16H8v-2h8v2zm0-4H8v-2h8v2zm-3-5V3.5L18.5 9H13z"/>
                            </svg>
                            계약
                        </div>
                        <div class="tab" onclick="switchTab('credit')">
                            <svg width="16" height="16" fill="currentColor" viewBox="0 0 24 24">
                                <path d="M11.8 10.9c-2.27-.59-3-1.2-3-2.15 0-1.09 1.01-1.85 2.7-1.85 1.78 0 2.44.85 2.5 2.1h2.21c-.07-1.72-1.12-3.3-3.21-3.81V3h-3v2.16c-1.94.42-3.5 1.68-3.5 3.61 0 2.31 1.91 3.46 4.7 4.13 2.5.6 3 1.48 3 2.41 0 .69-.49 1.79-2.7 1.79-2.06 0-2.87-.92-2.98-2.1h-2.2c.12 2.19 1.76 3.42 3.68 3.83V21h3v-2.15c1.95-.37 3.5-1.5 3.5-3.55 0-2.84-2.43-3.81-4.7-4.4z"/>
                            </svg>
                            크레딧
                        </div>
                        <div class="tab" onclick="switchTab('lesson')">
                            <svg width="16" height="16" fill="currentColor" viewBox="0 0 24 24">
                                <path d="M5 13.18v4L12 21l7-3.82v-4L12 17l-7-3.82zM12 3L1 9l11 6 9-4.91V17h2V9L12 3z"/>
                            </svg>
                            레슨
                        </div>
                        <div class="tab" onclick="switchTab('ts')">
                            <svg width="16" height="16" fill="currentColor" viewBox="0 0 24 24">
                                <path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z"/>
                            </svg>
                            타석이용
                        </div>
                        <div class="tab" onclick="switchTab('term')">
                            <svg width="16" height="16" fill="currentColor" viewBox="0 0 24 24">
                                <path d="M19 3h-1V1h-2v2H8V1H6v2H5c-1.11 0-1.99.9-1.99 2L3 19c0 1.1.89 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zm0 16H5V8h14v11zM7 10h5v5H7z"/>
                            </svg>
                            기간권
                        </div>
                        <div class="tab" onclick="switchTab('junior')">
                            <svg width="16" height="16" fill="currentColor" viewBox="0 0 24 24">
                                <path d="M16 4c0-1.11.89-2 2-2s2 .89 2 2-.89 2-2 2-2-.89-2-2zm4 18v-6h2.5l-2.54-7.63A1.5 1.5 0 0 0 18.54 8H16c-.8 0-1.54.37-2.01.99l-2.54 3.38c-.35.47-.35 1.1 0 1.58l2.54 3.38c.47.62 1.21.99 2.01.99h2.46c.83 0 1.54-.67 1.54-1.5V22h-2z"/>
                            </svg>
                            주니어
                        </div>
                    </div>
                </div>
                <div class="tab-content" id="tabContent">
                    <div class="loading">
                        <div class="spinner"></div>
                        <p>회원 정보를 불러오는 중...</p>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <script>
        const memberId = $memberId;
        let memberData = null;
        
        // 회원 정보 로드
        async function loadMemberInfo() {
            try {
                // 실제 API 호출 대신 임시 데이터
                memberData = {
                    member_name: '김학준',
                    member_phone: '010-8806-8044',
                    member_gender: '남성',
                    member_birthday: '1990-01-01',
                    member_nickname: '골프왕',
                    member_chn_keyword: '카리스마',
                    member_address: '서울시 강남구 신논현로 1326-1102'
                };
                
                // 폼에 데이터 설정
                document.getElementById('memberName').textContent = memberData.member_name;
                document.querySelector('input[id="memberName"]').value = memberData.member_name || '';
                document.getElementById('memberPhone').value = memberData.member_phone || '';
                document.getElementById('memberGender').value = memberData.member_gender || '남성';
                document.getElementById('memberBirthdate').value = memberData.member_birthday || '';
                document.getElementById('memberNickname').value = memberData.member_nickname || '';
                document.getElementById('memberChannelKeyword').value = memberData.member_chn_keyword || '';
                document.getElementById('memberAddress').value = memberData.member_address || '';
                
                // 기본 탭 로드
                switchTab('memo');
            } catch (error) {
                console.error('회원 정보 로드 오류:', error);
                document.getElementById('tabContent').innerHTML = '<div class="loading"><p style="color: #ef4444;">회원 정보를 불러오는데 실패했습니다.</p></div>';
            }
        }
        
        // 탭 전환
        function switchTab(tabName) {
            // 탭 활성화 상태 변경
            document.querySelectorAll('.tab').forEach(tab => tab.classList.remove('active'));
            event.target.closest('.tab').classList.add('active');
            
            // 탭 내용 변경
            const content = document.getElementById('tabContent');
            switch(tabName) {
                case 'memo':
                    content.innerHTML = '<div style="padding: 20px;"><h3>메모</h3><p>회원 메모 내용이 여기에 표시됩니다.</p></div>';
                    break;
                case 'contract':
                    content.innerHTML = '<div style="padding: 20px;"><h3>계약</h3><p>계약 정보가 여기에 표시됩니다.</p></div>';
                    break;
                case 'credit':
                    content.innerHTML = '<div style="padding: 20px;"><h3>크레딧</h3><p>크레딧 정보가 여기에 표시됩니다.</p></div>';
                    break;
                case 'lesson':
                    content.innerHTML = '<div style="padding: 20px;"><h3>레슨</h3><p>레슨 정보가 여기에 표시됩니다.</p></div>';
                    break;
                case 'ts':
                    content.innerHTML = '<div style="padding: 20px;"><h3>타석이용</h3><p>타석 이용 정보가 여기에 표시됩니다.</p></div>';
                    break;
                case 'term':
                    content.innerHTML = '<div style="padding: 20px;"><h3>기간권</h3><p>기간권 정보가 여기에 표시됩니다.</p></div>';
                    break;
                case 'junior':
                    content.innerHTML = '<div style="padding: 20px;"><h3>주니어</h3><p>주니어 정보가 여기에 표시됩니다.</p></div>';
                    break;
            }
        }
        
        // 회원 정보 저장
        function saveMemberInfo() {
            const updatedData = {
                member_name: document.querySelector('input[id="memberName"]').value,
                member_phone: document.getElementById('memberPhone').value,
                member_birthday: document.getElementById('memberBirthdate').value,
                member_nickname: document.getElementById('memberNickname').value,
                member_chn_keyword: document.getElementById('memberChannelKeyword').value,
                member_address: document.getElementById('memberAddress').value,
            };
            
            console.log('저장할 데이터:', updatedData);
            alert('회원 정보가 저장되었습니다.');
        }
        
        // 페이지 로드 시 회원 정보 로드
        window.onload = function() {
            loadMemberInfo();
        };
    </script>
</body>
</html>
    ''';

    final blob = html.Blob([memberPageHtml], 'text/html');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.window.open(url, '_blank', 'width=1200,height=800,scrollbars=yes,resizable=yes');
  }

  @override
  State<MemberMainWidget> createState() => _MemberMainWidgetState();
}

class _MemberMainWidgetState extends State<MemberMainWidget>
    with TickerProviderStateMixin {
  TabController? _tabController;
  Map<String, dynamic>? memberInfo;
  bool isLoading = true;
  String? errorMessage;

  // 폼 컨트롤러들
  late TextEditingController nameController;
  late TextEditingController phoneController;
  late TextEditingController birthdateController;
  late TextEditingController nicknameController;
  late TextEditingController channelKeywordController;
  late TextEditingController addressController;
  String selectedGender = '남성';
  
  // 전화번호 인증 상태
  bool isPhoneVerified = false;
  String? originalPhone; // 원래 전화번호 (변경 감지용)

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 9, vsync: this);
    
    // 컨트롤러 초기화
    nameController = TextEditingController();
    phoneController = TextEditingController();
    birthdateController = TextEditingController();
    nicknameController = TextEditingController();
    channelKeywordController = TextEditingController();
    addressController = TextEditingController();
    
    loadMemberInfo();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    nameController.dispose();
    phoneController.dispose();
    birthdateController.dispose();
    nicknameController.dispose();
    channelKeywordController.dispose();
    addressController.dispose();
    super.dispose();
  }

  Future<void> loadMemberInfo() async {
    try {
      print('회원 정보 로드 시작 - 회원 ID: ${widget.memberId}');
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      Map<String, dynamic>? memberData;
      
      // 캐시된 데이터가 있으면 우선 사용
      if (widget.memberData != null) {
        print('캐시된 회원 데이터 사용');
        memberData = widget.memberData!;
      } else {
        // 캐시된 데이터가 없으면 API 호출
        print('API 호출 시작');
        memberData = await ApiService.getMemberById(widget.memberId);
        print('API 호출 완료 - 데이터: $memberData');
      }

      if (memberData != null) {
        print('회원 데이터 존재 - 폼 필드 설정 시작');
        
        // 먼저 memberInfo 설정
        memberInfo = memberData;
        
        // 각 컨트롤러에 값 설정
        nameController.text = memberData['member_name']?.toString() ?? '';
        phoneController.text = memberData['member_phone']?.toString() ?? '';
        birthdateController.text = memberData['member_birthday']?.toString() ?? '';
        nicknameController.text = memberData['member_nickname']?.toString() ?? '';
        channelKeywordController.text = memberData['member_chn_keyword']?.toString() ?? '';
        addressController.text = memberData['member_address']?.toString() ?? '';
        selectedGender = memberData['member_gender']?.toString() ?? '남성';
        // 빈 문자열이거나 유효하지 않은 값인 경우 기본값 설정
        if (selectedGender.isEmpty || (selectedGender != '남성' && selectedGender != '여성')) {
          selectedGender = '남성';
        }
        
        // 전화번호 인증 상태 설정
        isPhoneVerified = memberData['member_phone_auth']?.toString() == 'success';
        originalPhone = memberData['member_phone']?.toString() ?? '';
        
        print('폼 필드 설정 완료');
        print('이름: ${nameController.text}');
        print('전화번호: ${phoneController.text}');
        print('생년월일: ${birthdateController.text}');
        print('성별: $selectedGender');
        
        // UI 업데이트를 위한 setState 호출
        setState(() {
          isLoading = false;
        });
        
        // 추가 UI 업데이트 강제 실행
        WidgetsBinding.instance.addPostFrameCallback((_) {
          setState(() {});
        });
        
      } else {
        print('회원 데이터 없음');
        setState(() {
          errorMessage = '회원 정보를 찾을 수 없습니다.';
          isLoading = false;
        });
      }
    } catch (e) {
      print('회원 정보 로드 오류: $e');
      setState(() {
        errorMessage = '회원 정보 로드 중 오류가 발생했습니다: $e';
        isLoading = false;
      });
    }
    print('회원 정보 로드 완료');
  }

  Future<void> saveMemberInfo() async {
    try {
      final newPhone = phoneController.text.trim().isEmpty ? null : phoneController.text.trim();
      final phoneChanged = originalPhone != newPhone;
      
      // 전화번호가 변경되었고 기존에 인증된 상태였다면 인증 해제
      Map<String, dynamic> updateData = {
        'member_name': nameController.text.trim().isEmpty ? null : nameController.text.trim(),
        'member_phone': newPhone,
        'member_birthday': birthdateController.text.trim().isEmpty ? null : birthdateController.text.trim(),
        'member_nickname': nicknameController.text.trim().isEmpty ? null : nicknameController.text.trim(),
        'member_chn_keyword': channelKeywordController.text.trim().isEmpty ? null : channelKeywordController.text.trim(),
        'member_address': addressController.text.trim().isEmpty ? null : addressController.text.trim(),
        'member_gender': selectedGender.isEmpty ? null : selectedGender,
      };
      
      // 전화번호 변경 시 해당 회원의 인증 정보만 초기화 (지점별 독립)
      if (phoneChanged) {
        updateData['member_phone_auth'] = null;
        updateData['member_phone_auth_timestamp'] = null;
        print('📱 전화번호 변경 감지: $originalPhone → $newPhone (인증 해제)');
      }
      
      await ApiService.updateMember(widget.memberId, updateData);

      String message = '회원 정보가 성공적으로 저장되었습니다.';
      if (phoneChanged && isPhoneVerified) {
        message += '\n전화번호가 변경되어 재인증이 필요합니다.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Color(0xFF10B981),
          duration: Duration(seconds: phoneChanged ? 4 : 2),
        ),
      );

      // 정보 다시 로드
      await loadMemberInfo();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('저장 중 오류가 발생했습니다: $e'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
    }
  }

  // 앱 설치 안내 SMS 발송
  Future<void> sendAppInstallSms() async {
    if (memberInfo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('회원 정보를 불러오는 중입니다. 잠시 후 다시 시도해주세요.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    final memberPhone = memberInfo!['member_phone']?.toString();
    final memberName = memberInfo!['member_name']?.toString() ?? '';

    if (memberPhone == null || memberPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('회원 전화번호가 등록되어 있지 않습니다.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    // 발송 확인 다이얼로그
    final shouldSend = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          title: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Icon(
                  Icons.sms_outlined,
                  color: Color(0xFF10B981),
                  size: 24.0,
                ),
              ),
              SizedBox(width: 12.0),
              Text(
                '앱 설치 안내',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 18.0,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$memberName 회원님에게',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 15.0,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151),
                ),
              ),
              SizedBox(height: 4.0),
              Text(
                '앱 설치 링크를 문자로 발송하시겠습니까?',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 15.0,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF374151),
                ),
              ),
              SizedBox(height: 12.0),
              Container(
                padding: EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Row(
                  children: [
                    Icon(Icons.phone_android, size: 16.0, color: Color(0xFF6B7280)),
                    SizedBox(width: 8.0),
                    Text(
                      memberPhone,
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 14.0,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF374151),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                '취소',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              child: Text(
                '발송하기',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (shouldSend != true) return;

    // SMS 발송
    try {
      final result = await SmsService.sendAppInstallSms(
        phoneNumber: memberPhone,
        memberName: memberName,
        appName: 'crm_lite_pro',
      );

      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('앱 설치 안내 문자가 발송되었습니다.'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('문자 발송 실패: ${result['error']}'),
              backgroundColor: Color(0xFFEF4444),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('문자 발송 중 오류가 발생했습니다.'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  void openReservationApp() {
    if (memberInfo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('회원 정보를 불러오는 중입니다. 잠시 후 다시 시도해주세요.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    // 현재 지점 ID 가져오기 - 회원 정보에서 먼저 확인, 없으면 현재 로그인 사용자의 지점 사용
    String? branchId = memberInfo!['branch_id']?.toString();

    if (branchId == null || branchId.isEmpty) {
      // 회원 정보에 branch_id가 없으면 현재 로그인한 사용자의 지점 정보 사용
      final currentBranchId = ApiService.getCurrentBranchId();
      branchId = currentBranchId;
      print('⚠️ 회원 정보에 branch_id 없음. 현재 로그인 지점 사용: $branchId');
    }

    if (branchId == null || branchId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('지점 정보를 찾을 수 없습니다.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    // 골프플래너 앱 모달 팝업 열기 (회원 선택 건너뛰고 바로 메인 화면으로)
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return MemberDirectPlannerAppPopup(
          member: memberInfo!,
          branchId: branchId!,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8FAFC),
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(70.0),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1E293B), Color(0xFF334155)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0x20000000),
                blurRadius: 8.0,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            toolbarHeight: 70.0,
            title: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10.0),
                  decoration: BoxDecoration(
                    color: Color(0xFF06B6D4),
                    borderRadius: BorderRadius.circular(12.0),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x4006B6D4),
                        blurRadius: 6.0,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 20.0,
                  ),
                ),
                SizedBox(width: 12.0),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '회원 정보',
                      style: AppTextStyles.cardMeta.copyWith(
                        color: Color(0xFFCBD5E1),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      memberInfo?['member_name'] ?? '로딩중...',
                      style: AppTextStyles.h3.copyWith(
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
            leading: Container(
              margin: EdgeInsets.all(10.0),
              decoration: BoxDecoration(
                color: Color(0x20FFFFFF),
                borderRadius: BorderRadius.circular(10.0),
              ),
              child: IconButton(
                icon: Icon(Icons.close, color: Colors.white, size: 18.0),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            actions: [
              // 예약앱 버튼
              Container(
                margin: EdgeInsets.only(right: 8.0, top: 12.0, bottom: 12.0),
                child: ElevatedButton.icon(
                  onPressed: openReservationApp,
                  icon: Icon(Icons.calendar_month, size: 16.0, color: Colors.white),
                  label: Text(
                    '예약앱',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      color: Colors.white,
                      fontSize: 14.0,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  ),
                ),
              ),
              // 앱설치안내 버튼
              Container(
                margin: EdgeInsets.only(right: 8.0, top: 12.0, bottom: 12.0),
                child: ElevatedButton.icon(
                  onPressed: sendAppInstallSms,
                  icon: Icon(Icons.install_mobile, size: 16.0, color: Colors.white),
                  label: Text(
                    '앱설치안내',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      color: Colors.white,
                      fontSize: 14.0,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF8B5CF6),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  ),
                ),
              ),
              // 저장 버튼
              Container(
                margin: EdgeInsets.only(right: 16.0, top: 12.0, bottom: 12.0),
                child: ElevatedButton.icon(
                  onPressed: saveMemberInfo,
                  icon: Icon(Icons.save_outlined, size: 16.0, color: Colors.white),
                  label: Text(
                    '저장',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      color: Colors.white,
                      fontSize: 14.0,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: isLoading
          ? Center(
              child: Container(
                padding: EdgeInsets.all(32.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16.0),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x1A000000),
                      blurRadius: 12.0,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      color: Color(0xFF06B6D4),
                      strokeWidth: 2.5,
                    ),
                    SizedBox(height: 12.0),
                    Text(
                      '회원 정보를 불러오는 중...',
                      style: AppTextStyles.bodyTextSmall.copyWith(
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : errorMessage != null
              ? Center(
                  child: Container(
                    padding: EdgeInsets.all(32.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16.0),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x1A000000),
                          blurRadius: 12.0,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: EdgeInsets.all(12.0),
                          decoration: BoxDecoration(
                            color: Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          child: Icon(
                            Icons.error_outline,
                            size: 32.0,
                            color: Color(0xFFEF4444),
                          ),
                        ),
                        SizedBox(height: 16.0),
                        Text(
                          '오류가 발생했습니다',
                          style: AppTextStyles.cardTitle.copyWith(
                            color: Color(0xFF1E293B),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 6.0),
                        Text(
                          errorMessage!,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.cardSubtitle.copyWith(
                            color: Color(0xFF64748B),
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 3,
                        ),
                        SizedBox(height: 16.0),
                        ElevatedButton.icon(
                          onPressed: loadMemberInfo,
                          icon: Icon(Icons.refresh, size: 16.0),
                          label: Text('다시 시도'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF06B6D4),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                            padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    // 컴팩트한 기본 정보 섹션 (30%)
                    Container(
                      height: MediaQuery.of(context).size.height * 0.25,
                      padding: EdgeInsets.all(20.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16.0),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x0A000000),
                              blurRadius: 8.0,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 첫 번째 행
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildCompactFormField(
                                      label: '이름',
                                      controller: nameController,
                                      icon: Icons.person_outline,
                                      isRequired: true,
                                    ),
                                  ),
                                  SizedBox(width: 16.0),
                                  Expanded(
                                    child: _buildPhoneFieldWithAuthStatus(),
                                  ),
                                  SizedBox(width: 16.0),
                                  Expanded(
                                    child: _buildCompactGenderField(),
                                  ),
                                  SizedBox(width: 16.0),
                                  Expanded(
                                    child: _buildCompactFormField(
                                      label: '생년월일',
                                      controller: birthdateController,
                                      icon: Icons.calendar_today_outlined,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12.0),
                              // 두 번째 행
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildCompactFormField(
                                      label: '닉네임',
                                      controller: nicknameController,
                                      icon: Icons.badge_outlined,
                                    ),
                                  ),
                                  SizedBox(width: 16.0),
                                  Expanded(
                                    child: _buildCompactFormField(
                                      label: '채널키워드',
                                      controller: channelKeywordController,
                                      icon: Icons.tag_outlined,
                                    ),
                                  ),
                                  SizedBox(width: 16.0),
                                  Expanded(
                                    flex: 2,
                                    child: _buildCompactFormField(
                                      label: '주소',
                                      controller: addressController,
                                      icon: Icons.location_on_outlined,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // 탭 섹션 (70%)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(20.0, 0.0, 20.0, 20.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16.0),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0x0A000000),
                                blurRadius: 8.0,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              // 탭바
                              TabDesignUpper.buildCompleteTabBar(
                                controller: _tabController!,
                                tabs: [
                                  TabDesignUpper.buildTabItem(Icons.note_alt_outlined, '메모'),
                                  TabDesignUpper.buildTabItem(Icons.description_outlined, '회원권'),
                                  TabDesignUpper.buildTabItem(Icons.account_balance_wallet_outlined, '크레딧'),
                                  TabDesignUpper.buildTabItem(Icons.school_outlined, '레슨'),
                                  TabDesignUpper.buildTabItem(Icons.access_time, '시간권'),
                                  TabDesignUpper.buildTabItem(Icons.schedule_outlined, '기간권'),
                                  TabDesignUpper.buildTabItem(Icons.sports_esports, '게임권'),
                                  TabDesignUpper.buildTabItem(Icons.sports_golf_outlined, '타석이용'),
                                  TabDesignUpper.buildTabItem(Icons.family_restroom_outlined, '관계'),
                                ],
                              ),
                              // 탭 내용
                              Expanded(
                                child: TabBarView(
                                  controller: _tabController!,
                                  physics: AlwaysScrollableScrollPhysics(),
                                  children: [
                                    Tab1MemoTabWidget(memberId: widget.memberId),
                                    Tab2ContractWidget(
                                      memberId: widget.memberId,
                                      memberData: memberInfo,
                                    ),
                                    Tab3CreditWidget(memberId: widget.memberId),
                                    Tab4LessonWidget(memberId: widget.memberId),
                                    Tab5TimeWidget(memberId: widget.memberId),
                                    Tab7TermWidget(memberId: widget.memberId),
                                    Tab9GameWidget(memberId: widget.memberId),
                                    Tab6TsUseWidget(
                                      memberId: widget.memberId,
                                      memberData: memberInfo,
                                    ),
                                    Tab8JuniorWidget(memberId: widget.memberId),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  // 컴팩트한 폼 필드 빌더
  Widget _buildCompactFormField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    bool isRequired = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 14.0,
              color: Color(0xFF06B6D4),
            ),
            SizedBox(width: 6.0),
            Text(
              label,
              style: AppTextStyles.cardBody.copyWith(
                color: Color(0xFF374151),
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            if (isRequired) ...[
              SizedBox(width: 2.0),
              Text(
                '*',
                style: AppTextStyles.cardBody.copyWith(
                  color: Color(0xFFEF4444),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
        SizedBox(height: 6.0),
        Container(
          height: 36.0,
          child: TextFormField(
            controller: controller,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide: BorderSide(color: Color(0xFFE5E7EB), width: 1.0),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide: BorderSide(color: Color(0xFFE5E7EB), width: 1.0),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide: BorderSide(color: Color(0xFF06B6D4), width: 1.5),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            ),
            style: AppTextStyles.cardSubtitle.copyWith(
              fontWeight: FontWeight.w500,
              color: Color(0xFF1F2937),
            ),
          ),
        ),
      ],
    );
  }

  // 전화번호 필드 (인증 상태 표시 포함)
  Widget _buildPhoneFieldWithAuthStatus() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.phone_outlined,
              size: 14.0,
              color: Color(0xFF06B6D4),
            ),
            SizedBox(width: 6.0),
            Text(
              '전화번호',
              style: AppTextStyles.cardBody.copyWith(
                color: Color(0xFF374151),
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(width: 8.0),
            // 인증 상태 배지
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
              decoration: BoxDecoration(
                color: isPhoneVerified ? Color(0xFFDCFCE7) : Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(4.0),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isPhoneVerified ? Icons.verified : Icons.warning_amber_rounded,
                    size: 12.0,
                    color: isPhoneVerified ? Color(0xFF16A34A) : Color(0xFFD97706),
                  ),
                  SizedBox(width: 3.0),
                  Text(
                    isPhoneVerified ? '인증됨' : '미인증',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 11.0,
                      fontWeight: FontWeight.w600,
                      color: isPhoneVerified ? Color(0xFF16A34A) : Color(0xFFD97706),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 6.0),
        Container(
          height: 36.0,
          child: TextFormField(
            controller: phoneController,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide: BorderSide(
                  color: isPhoneVerified ? Color(0xFF16A34A) : Color(0xFFE5E7EB),
                  width: isPhoneVerified ? 1.5 : 1.0,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide: BorderSide(
                  color: isPhoneVerified ? Color(0xFF16A34A) : Color(0xFFE5E7EB),
                  width: isPhoneVerified ? 1.5 : 1.0,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide: BorderSide(color: Color(0xFF06B6D4), width: 1.5),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              suffixIcon: isPhoneVerified
                  ? Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 18.0)
                  : null,
            ),
            style: AppTextStyles.cardSubtitle.copyWith(
              fontWeight: FontWeight.w500,
              color: Color(0xFF1F2937),
            ),
          ),
        ),
      ],
    );
  }

  // 컴팩트한 성별 필드 빌더
  Widget _buildCompactGenderField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.wc_outlined,
              size: 14.0,
              color: Color(0xFF06B6D4),
            ),
            SizedBox(width: 6.0),
            Text(
              '성별',
              style: AppTextStyles.cardBody.copyWith(
                color: Color(0xFF374151),
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        SizedBox(height: 6.0),
        Container(
          height: 36.0,
          child: DropdownButtonFormField<String>(
            value: selectedGender,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide: BorderSide(color: Color(0xFFE5E7EB), width: 1.0),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide: BorderSide(color: Color(0xFFE5E7EB), width: 1.0),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide: BorderSide(color: Color(0xFF06B6D4), width: 1.5),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            ),
            items: ['남성', '여성'].map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(
                  value,
                  style: AppTextStyles.cardSubtitle.copyWith(
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1F2937),
                  ),
                ),
              );
            }).toList(),
            onChanged: (String? newValue) {
              if (newValue != null) {
                setState(() {
                  selectedGender = newValue;
                });
              }
            },
          ),
        ),
      ],
    );
  }
} 