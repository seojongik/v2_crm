import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/main.dart';
import '/services/api_service.dart';
import '/services/chat_notification_service.dart';
import '/services/session_manager.dart';
import '/services/password_service.dart';
import '../../constants/font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'login_model.dart';
import 'change_password_widget.dart';
export 'login_model.dart';

// 웹 전용 import (conditional)
import 'dart:html' as html show window;

class LoginWidget extends StatefulWidget {
  const LoginWidget({super.key});

  static String routeName = 'login';
  static String routePath = '/login';

  @override
  State<LoginWidget> createState() => _LoginWidgetState();
}

class _LoginWidgetState extends State<LoginWidget> {
  late LoginModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => LoginModel());

    _model.staffAccessIdTextController ??= TextEditingController();
    _model.staffAccessIdFocusNode ??= FocusNode();

    _model.staffPasswordTextController ??= TextEditingController();
    _model.staffPasswordFocusNode ??= FocusNode();

    // 웹 빌드인 경우 landing 페이지에서의 자동 로그인 체크
    if (kIsWeb) {
      _checkAutoLoginFromLanding();
    }
  }

  // Landing 페이지에서 로그인한 정보 확인 및 자동 로그인
  Future<void> _checkAutoLoginFromLanding() async {
    try {
      final savedUser = html.window.localStorage['currentUser'];
      final savedBranch = html.window.localStorage['currentBranch'];

      if (savedUser != null && savedBranch != null) {
        print('🔍 Landing 페이지 로그인 정보 발견');

        final user = json.decode(savedUser);
        final branch = json.decode(savedBranch);

        print('  - 사용자: ${user['staff_name'] ?? user['pro_name'] ?? user['manager_name']}');
        print('  - 지점: ${branch['branch_name']}');

        // localStorage 정보 제거 (한 번만 사용)
        html.window.localStorage.remove('currentUser');
        html.window.localStorage.remove('currentBranch');

        // 자동 로그인 처리
        setState(() {
          _model.isLoading = true;
        });

        await _autoLoginFromLanding(user, branch);
      }
    } catch (e) {
      print('⚠️ 자동 로그인 체크 실패: $e');
    }
  }

  // Landing에서 전달받은 정보로 자동 로그인
  Future<void> _autoLoginFromLanding(Map<String, dynamic> user, Map<String, dynamic> branch) async {
    try {
      print('🔐 Landing 정보로 자동 로그인 시작...');

      // Firebase Anonymous 인증
      try {
        final userCredential = await FirebaseAuth.instance.signInAnonymously();
        print('✅ Firebase Anonymous 인증 성공: ${userCredential.user?.uid}');
      } catch (e) {
        print('⚠️ Firebase Anonymous 인증 실패: $e');
      }

      // 직원 정보 설정
      ApiService.setCurrentStaff(
        user['staff_access_id'] as String,
        user['role'] as String,
        user,
      );

      // 지점 정보 설정
      _model.selectedBranch = branch;
      ApiService.setCurrentBranch(
        branch['branch_id'],
        branch,
      );

      print('✅ 자동 로그인 성공!');
      print('  - 직원: ${user['staff_name'] ?? user['pro_name'] ?? user['manager_name']}');
      print('  - 역할: ${user['role']}');
      print('  - 지점: ${branch['branch_name']}');

      setState(() {
        _model.isLoading = false;
      });

      // 메인 페이지로 이동
      await _proceedToMainPage();

    } catch (e) {
      print('❌ 자동 로그인 실패: $e');
      setState(() {
        _model.errorMessage = '자동 로그인 중 오류가 발생했습니다.';
        _model.isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  // 로그인 처리 함수
  Future<void> _handleLogin() async {
    if (_model.staffAccessIdTextController.text.isEmpty ||
        _model.staffPasswordTextController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('아이디와 비밀번호를 입력해주세요.'),
          backgroundColor: FlutterFlowTheme.of(context).error,
        ),
      );
      return;
    }

    setState(() {
      _model.isLoading = true;
      _model.errorMessage = null;
    });

    try {
      // Staff 로그인 인증
      final user = await ApiService.authenticateStaff(
        staffAccessId: _model.staffAccessIdTextController.text.trim(),
        staffPassword: _model.staffPasswordTextController.text.trim(),
      );

      if (user == null) {
        setState(() {
          _model.errorMessage = '아이디 또는 비밀번호가 올바르지 않습니다.';
          _model.isLoading = false;
        });
        return;
      }

      _model.loggedInUser = user;

      // 직원 정보를 전역으로 설정 (staff_access_id, role 포함)
      ApiService.setCurrentStaff(
        user['staff_access_id'],
        user['role'], // 'pro' 또는 'manager'
        user,
      );

      // 직원의 branch_id로 해당 지점 정보 조회
      final branchId = user['branch_id'];
      if (branchId == null || branchId.toString().isEmpty) {
        setState(() {
          _model.errorMessage = '직원의 지점 정보가 없습니다.';
          _model.isLoading = false;
        });
        return;
      }

      // 해당 지점 정보 조회
      final branches = await ApiService.getBranchData(
        where: [
          {
            'field': 'branch_id',
            'operator': '=',
            'value': branchId,
          }
        ]
      );

      if (branches.isEmpty) {
        setState(() {
          _model.errorMessage = '지점 정보를 찾을 수 없습니다.';
          _model.isLoading = false;
        });
        return;
      }

      // 지점 정보 설정
      _model.selectedBranch = branches[0];
      ApiService.setCurrentBranch(
        _model.selectedBranch!['branch_id'],
        _model.selectedBranch!,
      );

      // 초기 비밀번호 체크 (핸드폰 번호 뒷 4자리)
      final storedPassword = user['staff_access_password']?.toString() ?? '';

      // 역할에 따라 전화번호 필드 선택
      String phoneNumber = '';
      if (user['role'] == 'manager') {
        phoneNumber = user['manager_phone']?.toString() ?? '';
      } else if (user['role'] == 'pro') {
        phoneNumber = user['pro_phone']?.toString() ?? '';
      }

      // 폴백: staff_phone도 체크
      if (phoneNumber.isEmpty) {
        phoneNumber = user['staff_phone']?.toString() ?? '';
      }

      print('🔍 초기 비밀번호 체크:');
      print('  - 역할: ${user['role']}');
      print('  - 저장된 비밀번호: $storedPassword');
      print('  - 전화번호: $phoneNumber');
      print('  - user 객체 전체: $user');

      final isInitial = PasswordService.isInitialPassword(storedPassword, phoneNumber);
      print('  - 초기 비밀번호 여부: $isInitial');

      if (isInitial && phoneNumber.isNotEmpty) {
        print('⚠️ 초기 비밀번호 감지 - 비밀번호 변경 필요');
        setState(() {
          _model.isLoading = false;
        });

        // 비밀번호 변경 페이지로 이동
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => ChangePasswordWidget(
              staffAccessId: user['staff_access_id'],
              isInitialPasswordChange: true,
            ),
          ),
        );
        return;
      }

      setState(() {
        _model.isLoading = false;
      });
      await _proceedToMainPage();

    } catch (e) {
      setState(() {
        _model.errorMessage = e.toString().replaceAll('Exception: ', '');
        _model.isLoading = false;
      });
    }
  }

  // 개발용 로그인 처리 함수 - 실제 직원 선택
  Future<void> _handleDevLogin() async {
    print('=== 개발용 로그인 시작 (실제 직원 선택) ===');
    print('시간: ${DateTime.now()}');
    setState(() {
      _model.isLoading = true;
      _model.errorMessage = null;
    });

    try {
      // 모든 지점 목록 조회
      final allBranches = await ApiService.getBranchData();

      if (allBranches.isEmpty) {
        setState(() {
          _model.errorMessage = '등록된 지점이 없습니다.';
          _model.isLoading = false;
        });
        return;
      }

      setState(() {
        _model.isLoading = false;
        _model.availableBranches = allBranches;
      });

      // 지점 선택 다이얼로그 표시
      _showBranchSelectionDialog();

    } catch (e) {
      setState(() {
        _model.errorMessage = e.toString().replaceAll('Exception: ', '');
        _model.isLoading = false;
      });
    }
  }

  // 지점 선택 다이얼로그 - 세련된 디자인으로 변경
  void _showBranchSelectionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: double.maxFinite,
            constraints: BoxConstraints(maxWidth: 500),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20.0),
              boxShadow: [
                BoxShadow(
                  blurRadius: 24.0,
                  color: Color(0x1A000000),
                  offset: Offset(0.0, 8.0),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 헤더
                  Row(
                    children: [
                      Container(
                        width: 48.0,
                        height: 48.0,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                            stops: [0.0, 1.0],
                            begin: AlignmentDirectional(-1.0, -1.0),
                            end: AlignmentDirectional(1.0, 1.0),
                          ),
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        child: Icon(
                          Icons.location_on_rounded,
                          color: Colors.white,
                          size: 24.0,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '지점 선택',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                color: Color(0xFF1E293B),
                                fontSize: 24.0,
                                letterSpacing: -0.3,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '접근할 지점을 선택해주세요',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                color: Color(0xFF64748B),
                                fontSize: 14.0,
                                letterSpacing: 0.0,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 32),
                  
                  // 지점 목록
                  ...(_model.availableBranches.map((branch) => 
                    Container(
                      width: double.infinity,
                      margin: EdgeInsets.only(bottom: 12),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () async {
                            Navigator.of(context).pop();
                            await _showStaffSelectionDialogForBranch(branch);
                          },
                          borderRadius: BorderRadius.circular(16.0),
                          child: Container(
                            padding: EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16.0),
                              border: Border.all(
                                color: Color(0xFFE2E8F0),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40.0,
                                  height: 40.0,
                                  decoration: BoxDecoration(
                                    color: Color(0xFF6366F1).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10.0),
                                  ),
                                  child: Icon(
                                    Icons.business_rounded,
                                    color: Color(0xFF6366F1),
                                    size: 20.0,
                                  ),
                                ),
                                SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        branch['branch_name'] ?? '',
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          color: Color(0xFF1E293B),
                                          fontSize: 16.0,
                                          letterSpacing: 0.0,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (branch['branch_address'] != null && branch['branch_address'].toString().isNotEmpty)
                                        Padding(
                                          padding: EdgeInsets.only(top: 4),
                                          child: Text(
                                            branch['branch_address'],
                                            style: TextStyle(
                                              fontFamily: 'Inter',
                                              color: Color(0xFF64748B),
                                              fontSize: 14.0,
                                              letterSpacing: 0.0,
                                              fontWeight: FontWeight.w400,
                                            ),
                                          ),
                                        ),
                                      if (branch['branch_phone'] != null && branch['branch_phone'].toString().isNotEmpty)
                                        Padding(
                                          padding: EdgeInsets.only(top: 2),
                                          child: Text(
                                            branch['branch_phone'],
                                            style: TextStyle(
                                              fontFamily: 'Inter',
                                              color: Color(0xFF64748B),
                                              fontSize: 13.0,
                                              letterSpacing: 0.0,
                                              fontWeight: FontWeight.w400,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  color: Color(0xFF94A3B8),
                                  size: 16.0,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ).toList()),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // 지점별 직원 선택 다이얼로그
  Future<void> _showStaffSelectionDialogForBranch(Map<String, dynamic> branch) async {
    print('=== 지점별 직원 선택 다이얼로그 시작 (지점: ${branch['branch_name']}) ===');
    
    try {
      setState(() {
        _model.isLoading = true;
        _model.errorMessage = null;
      });

      // 선택된 지점의 직원 목록 조회
      final staffList = await ApiService.getDevStaffListByBranch(branch['branch_id']);
      
      // 각 직원의 권한 정보 조회
      final staffListWithPermissions = <Map<String, dynamic>>[];
      
      for (var staff in staffList) {
        try {
          // 직원의 권한 정보 조회
          final accessSettings = await ApiService.getDataList(
            table: 'v2_staff_access_setting',
            where: [
              {
                'field': 'staff_access_id',
                'operator': '=',
                'value': staff['staff_access_id'],
              },
              {
                'field': 'branch_id',
                'operator': '=',
                'value': branch['branch_id'],
              },
            ],
          );
          
          // 권한 정보를 직원 정보에 추가
          if (accessSettings.isNotEmpty) {
            staff['permissions'] = accessSettings[0];
          } else {
            // 권한 설정이 없으면 기본값 설정
            staff['permissions'] = {
              'member_page': '허용',
              'member_registration': '허용',
              'ts_management': '허용',
              'lesson_status': '전체',
              'communication': '허용',
              'locker': '허용',
              'staff_schedule': '전체',
              'pro_schedule': '전체',
              'salary_view': '본인',
              'salary_management': '불가',
              'hr_management': '허용',
              'branch_settings': '허용',
              'branch_operation': '허용',
              'client_app': '허용',
            };
          }
        } catch (e) {
          print('⚠️ 직원 ${staff['staff_name']} 권한 조회 실패: $e');
          // 권한 조회 실패 시 기본값 설정
          staff['permissions'] = {
            'member_page': '허용',
            'member_registration': '허용',
            'ts_management': '허용',
            'lesson_status': '전체',
            'communication': '허용',
            'locker': '허용',
            'staff_schedule': '전체',
            'pro_schedule': '전체',
            'salary_view': '본인',
            'salary_management': '불가',
            'hr_management': '허용',
            'branch_settings': '허용',
            'branch_operation': '허용',
            'client_app': '허용',
          };
        }
        
        staffListWithPermissions.add(staff);
      }
      
      // 관리자 타일을 맨 앞에 추가 (모든 권한 보유)
      final adminStaff = {
        'staff_access_id': 'ADMIN_${branch['branch_id']}',
        'role': 'admin',
        'staff_name': '관리자',
        'branch_id': branch['branch_id'],
        'is_admin': true, // 관리자 구분용 플래그
        'permissions': {
          'member_page': '허용',
          'member_registration': '허용',
          'ts_management': '허용',
          'lesson_status': '전체',
          'communication': '허용',
          'locker': '허용',
          'staff_schedule': '전체',
          'pro_schedule': '전체',
          'salary_view': '전체',
          'salary_management': '허용',
          'hr_management': '허용',
          'branch_settings': '허용',
          'branch_operation': '허용',
          'client_app': '허용',
        },
      };
      
      // 관리자를 맨 앞에 추가
      final allStaffList = [adminStaff, ...staffListWithPermissions];
      
      setState(() {
        _model.isLoading = false;
      });

      if (allStaffList.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${branch['branch_name']}에 등록된 직원이 없습니다.'),
            backgroundColor: FlutterFlowTheme.of(context).error,
          ),
        );
        return;
      }

      // 직원 선택 다이얼로그 표시
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              width: double.maxFinite,
              constraints: BoxConstraints(maxWidth: 500),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20.0),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 24.0,
                    color: Color(0x1A000000),
                    offset: Offset(0.0, 8.0),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 헤더
                    Row(
                      children: [
                        Container(
                          width: 48.0,
                          height: 48.0,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF00A86B), Color(0xFF00C851)],
                              stops: [0.0, 1.0],
                              begin: AlignmentDirectional(-1.0, -1.0),
                              end: AlignmentDirectional(1.0, 1.0),
                            ),
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          child: Icon(
                            Icons.person_search_rounded,
                            color: Colors.white,
                            size: 24.0,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '직원 선택',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  color: Color(0xFF1E293B),
                                  fontSize: 24.0,
                                  letterSpacing: -0.3,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '${branch['branch_name']} - 로그인할 직원을 선택하세요',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  color: Color(0xFF64748B),
                                  fontSize: 14.0,
                                  letterSpacing: 0.0,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: Icon(Icons.close, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                    
                    SizedBox(height: 32),
                    
                    // 직원 목록
                    Expanded(
                      child: ListView.builder(
                        itemCount: allStaffList.length,
                        itemBuilder: (context, index) {
                          final staff = allStaffList[index];
                          final isAdmin = staff['is_admin'] == true;
                          
                          return Container(
                            width: double.infinity,
                            margin: EdgeInsets.only(bottom: 12),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () async {
                                  Navigator.of(context).pop();
                                  await _loginWithSelectedStaff(staff, branch);
                                },
                                borderRadius: BorderRadius.circular(16.0),
                                child: Container(
                                  padding: EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: isAdmin 
                                        ? Color(0xFF8B5CF6).withOpacity(0.05)  // 관리자는 보라색 배경
                                        : Color(0xFFF8FAFC),  // 일반 직원은 회색 배경
                                    borderRadius: BorderRadius.circular(16.0),
                                    border: Border.all(
                                      color: isAdmin 
                                          ? Color(0xFF8B5CF6).withOpacity(0.3)  // 관리자는 보라색 테두리
                                          : Color(0xFFE2E8F0),  // 일반 직원은 회색 테두리
                                      width: isAdmin ? 2.0 : 1.5,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 40.0,
                                        height: 40.0,
                                        decoration: BoxDecoration(
                                          color: isAdmin 
                                              ? Color(0xFF8B5CF6).withOpacity(0.2)  // 관리자는 보라색
                                              : staff['role'] == 'manager' 
                                                  ? Color(0xFF8B5CF6).withOpacity(0.1)
                                                  : Color(0xFF00A86B).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(10.0),
                                        ),
                                        child: Icon(
                                          isAdmin 
                                              ? Icons.admin_panel_settings_rounded  // 관리자 아이콘
                                              : staff['role'] == 'manager' 
                                                  ? Icons.admin_panel_settings_rounded
                                                  : Icons.sports_golf_rounded,
                                          color: isAdmin 
                                              ? Color(0xFF8B5CF6)  // 관리자는 보라색
                                              : staff['role'] == 'manager' 
                                                  ? Color(0xFF8B5CF6)
                                                  : Color(0xFF00A86B),
                                          size: 20.0,
                                        ),
                                      ),
                                      SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              staff['staff_name'] ?? '이름 없음',
                                              style: TextStyle(
                                                fontFamily: 'Inter',
                                                color: Color(0xFF1E293B),
                                                fontSize: 16.0,
                                                letterSpacing: 0.0,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Container(
                                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: isAdmin 
                                                        ? Color(0xFF8B5CF6).withOpacity(0.2)  // 관리자는 보라색
                                                        : staff['role'] == 'manager' 
                                                            ? Color(0xFF8B5CF6).withOpacity(0.1)
                                                            : Color(0xFF00A86B).withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  child: Text(
                                                    isAdmin 
                                                        ? '관리자'  // 관리자 라벨
                                                        : staff['role'] == 'manager' ? '매니저' : '프로',
                                                    style: TextStyle(
                                                      color: isAdmin 
                                                          ? Color(0xFF8B5CF6)  // 관리자는 보라색
                                                          : staff['role'] == 'manager' 
                                                              ? Color(0xFF8B5CF6)
                                                              : Color(0xFF00A86B),
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(width: 8),
                                                Text(
                                                  'ID: ${staff['staff_access_id'] ?? 'N/A'}',
                                                  style: TextStyle(
                                                    color: Color(0xFF64748B),
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            SizedBox(height: 8),
                                            // 권한 정보 표시
                                            _buildPermissionsWidget(staff['permissions']),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        isAdmin 
                                            ? Icons.admin_panel_settings_rounded  // 관리자 아이콘
                                            : Icons.login,
                                        color: isAdmin 
                                            ? Color(0xFF8B5CF6)  // 관리자는 보라색
                                            : Color(0xFF00A86B),
                                        size: 20.0,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );

    } catch (e) {
      setState(() {
        _model.errorMessage = e.toString().replaceAll('Exception: ', '');
        _model.isLoading = false;
      });
    }
  }

  // 권한 정보를 컴팩트하게 표시하는 위젯
  Widget _buildPermissionsWidget(Map<String, dynamic>? permissions) {
    if (permissions == null) {
      return SizedBox.shrink();
    }

    // 주요 권한들을 컴팩트하게 표시
    final permissionLabels = <String>[];
    
    // 회원 관리 권한
    if (permissions['member_page'] == 'Y' || permissions['member_page'] == '허용') {
      permissionLabels.add('회원관리');
    }
    if (permissions['member_registration'] == 'Y' || permissions['member_registration'] == '허용') {
      permissionLabels.add('신규등록');
    }
    
    // 레슨 관리 권한
    if (permissions['ts_management'] == 'Y' || permissions['ts_management'] == '허용') {
      permissionLabels.add('레슨관리');
    }
    if (permissions['lesson_status'] == '전체') {
      permissionLabels.add('전체레슨');
    } else if (permissions['lesson_status'] == '본인') {
      permissionLabels.add('본인레슨');
    }
    
    // 커뮤니케이션 권한
    if (permissions['communication'] == 'Y' || permissions['communication'] == '허용') {
      permissionLabels.add('커뮤니케이션');
    }
    
    // 사물함 권한
    if (permissions['locker'] == 'Y' || permissions['locker'] == '허용') {
      permissionLabels.add('사물함');
    }
    
    // 스케줄 권한
    if (permissions['staff_schedule'] == '전체') {
      permissionLabels.add('전체스케줄');
    } else if (permissions['staff_schedule'] == '본인') {
      permissionLabels.add('본인스케줄');
    }
    
    // 급여 권한
    if (permissions['salary_view'] == 'Y' || permissions['salary_view'] == '허용' || permissions['salary_view'] == '본인') {
      permissionLabels.add('급여조회');
    }
    if (permissions['salary_management'] == 'Y' || permissions['salary_management'] == '허용') {
      permissionLabels.add('급여관리');
    }
    
    // 인사 관리 권한
    if (permissions['hr_management'] == 'Y' || permissions['hr_management'] == '허용') {
      permissionLabels.add('인사관리');
    }
    
    // 지점 설정 권한
    if (permissions['branch_settings'] == 'Y' || permissions['branch_settings'] == '허용') {
      permissionLabels.add('지점설정');
    }
    if (permissions['branch_operation'] == 'Y' || permissions['branch_operation'] == '허용') {
      permissionLabels.add('지점운영');
    }
    
    // 클라이언트 앱 권한
    if (permissions['client_app'] == 'Y' || permissions['client_app'] == '허용' || permissions['client_app'] == null || permissions['client_app'] == '') {
      permissionLabels.add('클라이언트앱');
    }

    if (permissionLabels.isEmpty) {
      return SizedBox.shrink();
    }

    return Wrap(
      spacing: 4,
      runSpacing: 2,
      children: permissionLabels.take(6).map((label) => Container(
        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Color(0xFFE2E8F0).withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Color(0xFFE2E8F0),
            width: 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Color(0xFF475569),
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      )).toList(),
    );
  }

  // 선택된 직원으로 로그인 처리
  Future<void> _loginWithSelectedStaff(Map<String, dynamic> staff, Map<String, dynamic> branch) async {
    print('=== 선택된 직원으로 로그인 시작 ===');
    print('선택된 직원: ${staff['staff_name']} (${staff['role']})');
    print('선택된 지점: ${branch['branch_name']}');
    
    try {
      setState(() {
        _model.isLoading = true;
        _model.errorMessage = null;
      });

      // Firebase Anonymous 인증 추가
      print('🔐 Firebase Anonymous 인증 시작...');
      try {
        final userCredential = await FirebaseAuth.instance.signInAnonymously();
        print('✅ Firebase Anonymous 인증 성공: ${userCredential.user?.uid}');
      } catch (e) {
        print('⚠️ Firebase Anonymous 인증 실패: $e');
      }

      // 선택된 직원 정보로 로그인 처리
      print('🔧 실제 직원으로 로그인 처리');
      
      // 직원 정보를 전역으로 설정
      ApiService.setCurrentStaff(
        staff['staff_access_id'] as String,
        staff['role'] as String, // 'pro', 'manager', 또는 'admin'
        staff,
      );

      // 지점 정보 설정
      _model.selectedBranch = branch;
      ApiService.setCurrentBranch(
        branch['branch_id'],
        branch,
      );
      
      // 지점 설정 완료 후 채팅 알림 서비스 활성화
      print('🏢 지점 설정 완료: ${branch['branch_id']}');
      print('🔔 채팅 알림 서비스 구독 시작...');
      ChatNotificationService().setupSubscriptions();

      // 관리자인 경우 권한을 직접 설정, 아니면 DB 조회
      if (staff['role'] == 'admin' && staff['permissions'] != null) {
        print('🔧 [관리자 권한] DB 조회 없이 직접 설정');
        ApiService.setCurrentAccessSettings(staff['permissions']);
        print('✅ [관리자 권한] 모든 권한 설정 완료');
        print('   • client_app: ${staff['permissions']['client_app']}');
        print('   • salary_management: ${staff['permissions']['salary_management']}');
        print('   • hr_management: ${staff['permissions']['hr_management']}');
      } else {
        // 일반 직원은 DB에서 권한 정보 조회 및 디버깅 출력
        await _queryAndPrintAccessSettings();
      }

      // 세션 시작 (10분 자동 로그아웃 타이머)
      SessionManager.instance.startSession();

      print('✅ 실제 직원 로그인 성공!');
      print('  - 직원: ${staff['staff_name']}');
      print('  - 역할: ${staff['role']}');
      print('  - 지점: ${branch['branch_name']}');

      setState(() {
        _model.isLoading = false;
      });

      // 메인 페이지로 이동
      await _proceedToMainPage();

    } catch (e) {
      print('❌ 실제 직원 로그인 오류: $e');
      setState(() {
        _model.errorMessage = e.toString().replaceAll('Exception: ', '');
        _model.isLoading = false;
      });
    }
  }

  // 직원 권한 설정 조회 및 디버깅 출력
  Future<void> _queryAndPrintAccessSettings() async {
    try {
      final staffAccessId = ApiService.getCurrentStaffAccessId();
      final branchId = ApiService.getCurrentBranchId();

      if (staffAccessId == null || branchId == null) {
        print('⚠️ [권한조회] staffAccessId 또는 branchId가 null');
        return;
      }

      print('🔍 [권한조회] v2_staff_access_setting 테이블 조회 시작');
      print('📍 [권한조회] staff_access_id: $staffAccessId, branch_id: $branchId');

      final accessSettings = await ApiService.getDataList(
        table: 'v2_staff_access_setting',
        where: [
          {
            'field': 'staff_access_id',
            'operator': '=',
            'value': staffAccessId,
          },
          {
            'field': 'branch_id',
            'operator': '=',
            'value': branchId,
          },
        ],
      );

      if (accessSettings.isNotEmpty) {
        final setting = accessSettings[0];

        // 권한 설정을 전역에 저장
        ApiService.setCurrentAccessSettings(setting);

        print('🎯 [권한조회] 권한 설정 발견:');
        print('==================== 직원 권한 정보 ====================');
        print('📋 기본 정보:');
        print('   • staff_access_id: ${setting['staff_access_id'] ?? 'N/A'}');
        print('   • branch_id: ${setting['branch_id'] ?? 'N/A'}');
        print('   • staff_name: ${setting['staff_name'] ?? 'N/A'}');
        print('   • pro_name: ${setting['pro_name'] ?? 'N/A'}');
        print('');
        print('🔐 권한 설정:');

        // 주요 메뉴 권한 체크 및 처리 결과 출력
        final memberPagePermission = setting['member_page'] ?? 'N';
        final communicationPermission = setting['communication'] ?? 'N';
        final tsManagementPermission = setting['ts_management'] ?? 'N';
        final lockerPermission = setting['locker'] ?? 'N';
        final branchSettingsPermission = setting['branch_settings'] ?? 'N';
        final branchOperationPermission = setting['branch_operation'] ?? 'N';

        final memberRegistrationPermission = setting['member_registration'] ?? 'N';
        print('   • member_registration: ${setting['member_registration'] ?? 'N/A'} → ${memberRegistrationPermission == 'Y' ? '신규등록 버튼 표시' : '신규등록 버튼 숨김완료'}');
        print('   • member_page: ${setting['member_page'] ?? 'N/A'} → ${memberPagePermission == 'Y' ? '표시' : '숨김완료'}');
        print('   • communication: ${setting['communication'] ?? 'N/A'} → ${communicationPermission == 'Y' ? '표시' : '숨김완료'}');
        print('   • ts_management: ${setting['ts_management'] ?? 'N/A'} → ${tsManagementPermission == 'Y' ? '표시' : '숨김완료'}');
        final lessonStatusPermission = setting['lesson_status'] ?? 'N/A';
        print('   • lesson_status: ${setting['lesson_status'] ?? 'N/A'} → ${lessonStatusPermission == '본인' ? '본인 레슨만 표시, 프로 선택 탭 숨김완료' : '모든 프로 레슨 표시'}');
        final salaryPermission = setting['salary_view'] ?? 'N/A';
        String salaryResult = '';
        if (salaryPermission == '본인') {
          final currentRole = ApiService.getCurrentStaffRole();
          if (currentRole == 'manager') {
            salaryResult = ' → 본인 급여조회 버튼만 표시';
          } else if (currentRole == 'pro') {
            salaryResult = ' → 본인 레슨비 정산만 표시';
          }
        } else if (salaryPermission == '전체' || salaryPermission == 'Y') {
          salaryResult = ' → 모든 급여/레슨비 정산 표시';
        }
        print('   • salary_view: ${setting['salary_view'] ?? 'N/A'}$salaryResult');

        final salaryManagementPermission = setting['salary_management'] ?? 'N/A';
        print('   • salary_management: ${setting['salary_management'] ?? 'N/A'} → ${salaryManagementPermission == '허용' ? '급여관리 탭 표시' : '급여관리 탭 숨김완료'}');

        final staffSchedulePermission = setting['staff_schedule'] ?? 'N/A';
        final proSchedulePermission = setting['pro_schedule'] ?? 'N/A';
        final currentRole = ApiService.getCurrentStaffRole();

        // staff_schedule 권한 처리 결과
        String staffScheduleResult = '';
        if (currentRole == 'manager') {
          staffScheduleResult = staffSchedulePermission == '본인' ? ' → 본인 근무시간만 조회 가능' : ' → 전체 직원 근무시간 조회 가능';
        } else if (currentRole == 'pro') {
          staffScheduleResult = staffSchedulePermission == '본인' ? ' → 근무시간표 탭 숨김완료' : ' → 근무시간표 탭 표시';
        }
        print('   • staff_schedule: ${setting['staff_schedule'] ?? 'N/A'}$staffScheduleResult');

        // pro_schedule 권한 처리 결과
        String proScheduleResult = '';
        if (currentRole == 'manager') {
          proScheduleResult = proSchedulePermission == '본인' ? ' → 프로시간표 탭 숨김완료' : ' → 프로시간표 탭 표시';
        } else if (currentRole == 'pro') {
          proScheduleResult = proSchedulePermission == '본인' ? ' → 본인 프로시간만 조회 가능' : ' → 전체 프로시간 조회 가능';
        }
        print('   • pro_schedule: ${setting['pro_schedule'] ?? 'N/A'}$proScheduleResult');
        final hrManagementPermission = setting['hr_management'] ?? 'N/A';
        print('   • hr_management: ${setting['hr_management'] ?? 'N/A'} → ${hrManagementPermission == 'Y' || hrManagementPermission == '허용' ? '직원등록 탭 표시' : '직원등록 탭 숨김완료'}');
        print('   • locker: ${setting['locker'] ?? 'N/A'} → ${lockerPermission == 'Y' ? '표시' : '숨김완료'}');
        print('   • branch_settings: ${setting['branch_settings'] ?? 'N/A'} → ${branchSettingsPermission == 'Y' ? '표시' : '숨김완료'}');
        print('   • branch_operation: ${setting['branch_operation'] ?? 'N/A'} → ${branchOperationPermission == 'Y' ? '표시' : '숨김완료'}');
        print('====================================================');
      } else {
        print('❌ [권한조회] 권한 설정을 찾을 수 없음 → 모든 기능 제한 없이 표시');
      }

    } catch (e) {
      print('💥 [권한조회] 오류 발생: $e');
    }
  }

  // 메인 페이지로 이동
  Future<void> _proceedToMainPage() async {
    // ApiService에 지점 정보 설정 (사용자 정보는 이미 setCurrentStaff에서 설정됨)
    if (_model.selectedBranch != null) {
      ApiService.setCurrentBranch(
        _model.selectedBranch!['branch_id'],
        _model.selectedBranch!,
      );
      
      // 지점 설정 완료 후 채팅 알림 서비스 활성화
      print('🏢 지점 설정 완료: ${_model.selectedBranch!['branch_id']}');
      print('🔔 채팅 알림 서비스 구독 시작...');
      ChatNotificationService().setupSubscriptions();
    }

    // 직원 권한 정보 조회 및 디버깅 출력
    await _queryAndPrintAccessSettings();

    // 세션 시작 (10분 자동 로그아웃 타이머)
    SessionManager.instance.startSession();

    // 로그인 정보를 전역적으로 저장 (추후 SharedPreferences 등으로 개선 가능)
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => NavBarPage(initialPage: 'crm1_board'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: Color(0xFFF8FAFC), // 연한 회색 배경
        body: SafeArea(
          top: true,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            child: Column(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(24.0, 0.0, 24.0, 0.0),
                  child: Container(
                    width: double.infinity,
                    constraints: BoxConstraints(
                      maxWidth: 420.0,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 24.0,
                          color: Color(0x0F000000),
                          offset: Offset(0.0, 8.0),
                          spreadRadius: 0.0,
                        )
                      ],
                      borderRadius: BorderRadius.circular(20.0),
                      border: Border.all(
                        color: Color(0xFFE2E8F0),
                        width: 1.0,
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(40.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 로고 영역 - 더 세련되게
                          Container(
                            width: 72.0,
                            height: 72.0,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                                stops: [0.0, 1.0],
                                begin: AlignmentDirectional(-1.0, -1.0),
                                end: AlignmentDirectional(1.0, 1.0),
                              ),
                              borderRadius: BorderRadius.circular(18.0),
                            ),
                            child: Icon(
                              Icons.golf_course_rounded,
                              color: Colors.white,
                              size: 36.0,
                            ),
                          ),
                          
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(0.0, 24.0, 0.0, 8.0),
                            child: Text(
                              'Auto Golf CRM',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                color: Color(0xFF1E293B),
                                fontSize: 32.0,
                                letterSpacing: -0.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          
                          Text(
                            '골프연습장 고객/예약관리 시스템',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              color: Color(0xFF64748B),
                              fontSize: 16.0,
                              letterSpacing: 0.0,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          
                          // 오류 메시지 표시 - 더 세련되게
                          if (_model.errorMessage != null)
                            Padding(
                              padding: EdgeInsetsDirectional.fromSTEB(0.0, 24.0, 0.0, 0.0),
                              child: Container(
                                width: double.infinity,
                                padding: EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Color(0xFFFECACA),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      color: Color(0xFFDC2626),
                                      size: 20.0,
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        _model.errorMessage!,
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          color: Color(0xFFDC2626),
                                          fontSize: 14.0,
                                          letterSpacing: 0.0,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          
                          // 직원 아이디 입력 필드 - 더 세련되게
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(0.0, 32.0, 0.0, 20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 8.0),
                                  child: Text(
                                    '직원 아이디',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      color: Color(0xFF374151),
                                      fontSize: 14.0,
                                      letterSpacing: 0.0,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                TextFormField(
                                  controller: _model.staffAccessIdTextController,
                                  focusNode: _model.staffAccessIdFocusNode,
                                  autofocus: false,
                                  obscureText: false,
                                  onFieldSubmitted: (_) {
                                    // 아이디 입력 후 엔터 시 비밀번호 필드로 포커스 이동
                                    FocusScope.of(context).requestFocus(_model.staffPasswordFocusNode);
                                  },
                                  decoration: InputDecoration(
                                    hintText: '아이디를 입력하세요',
                                    hintStyle: TextStyle(
                                      fontFamily: 'Inter',
                                      color: Color(0xFF9CA3AF),
                                      fontSize: 16.0,
                                      letterSpacing: 0.0,
                                      fontWeight: FontWeight.w400,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderSide: BorderSide(
                                        color: Color(0xFFD1D5DB),
                                        width: 1.5,
                                      ),
                                      borderRadius: BorderRadius.circular(12.0),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderSide: BorderSide(
                                        color: Color(0xFF6366F1),
                                        width: 2.0,
                                      ),
                                      borderRadius: BorderRadius.circular(12.0),
                                    ),
                                    errorBorder: OutlineInputBorder(
                                      borderSide: BorderSide(
                                        color: Color(0xFFDC2626),
                                        width: 1.5,
                                      ),
                                      borderRadius: BorderRadius.circular(12.0),
                                    ),
                                    focusedErrorBorder: OutlineInputBorder(
                                      borderSide: BorderSide(
                                        color: Color(0xFFDC2626),
                                        width: 2.0,
                                      ),
                                      borderRadius: BorderRadius.circular(12.0),
                                    ),
                                    filled: true,
                                    fillColor: Color(0xFFFAFAFA),
                                    contentPadding: EdgeInsetsDirectional.fromSTEB(16.0, 16.0, 16.0, 16.0),
                                    prefixIcon: Icon(
                                      Icons.person_outline_rounded,
                                      color: Color(0xFF6B7280),
                                      size: 20.0,
                                    ),
                                  ),
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    color: Color(0xFF1F2937),
                                    fontSize: 16.0,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  keyboardType: TextInputType.text,
                                  validator: _model.staffAccessIdTextControllerValidator.asValidator(context),
                                ),
                              ],
                            ),
                          ),
                          
                          // 비밀번호 입력 필드 - 더 세련되게
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 32.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 8.0),
                                  child: Text(
                                    '비밀번호',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      color: Color(0xFF374151),
                                      fontSize: 14.0,
                                      letterSpacing: 0.0,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                TextFormField(
                                  controller: _model.staffPasswordTextController,
                                  focusNode: _model.staffPasswordFocusNode,
                                  autofocus: false,
                                  obscureText: !_model.staffPasswordVisibility,
                                  onFieldSubmitted: (_) {
                                    // 비밀번호 입력 후 엔터 시 로그인 실행
                                    if (!_model.isLoading) {
                                      _handleLogin();
                                    }
                                  },
                                  decoration: InputDecoration(
                                    hintText: '비밀번호를 입력하세요',
                                    hintStyle: TextStyle(
                                      fontFamily: 'Inter',
                                      color: Color(0xFF9CA3AF),
                                      fontSize: 16.0,
                                      letterSpacing: 0.0,
                                      fontWeight: FontWeight.w400,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderSide: BorderSide(
                                        color: Color(0xFFD1D5DB),
                                        width: 1.5,
                                      ),
                                      borderRadius: BorderRadius.circular(12.0),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderSide: BorderSide(
                                        color: Color(0xFF6366F1),
                                        width: 2.0,
                                      ),
                                      borderRadius: BorderRadius.circular(12.0),
                                    ),
                                    errorBorder: OutlineInputBorder(
                                      borderSide: BorderSide(
                                        color: Color(0xFFDC2626),
                                        width: 1.5,
                                      ),
                                      borderRadius: BorderRadius.circular(12.0),
                                    ),
                                    focusedErrorBorder: OutlineInputBorder(
                                      borderSide: BorderSide(
                                        color: Color(0xFFDC2626),
                                        width: 2.0,
                                      ),
                                      borderRadius: BorderRadius.circular(12.0),
                                    ),
                                    filled: true,
                                    fillColor: Color(0xFFFAFAFA),
                                    contentPadding: EdgeInsetsDirectional.fromSTEB(16.0, 16.0, 16.0, 16.0),
                                    prefixIcon: Icon(
                                      Icons.lock_outline_rounded,
                                      color: Color(0xFF6B7280),
                                      size: 20.0,
                                    ),
                                    suffixIcon: InkWell(
                                      onTap: () => safeSetState(
                                        () => _model.staffPasswordVisibility = !_model.staffPasswordVisibility,
                                      ),
                                      focusNode: FocusNode(skipTraversal: true),
                                      child: Icon(
                                        _model.staffPasswordVisibility
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                        color: Color(0xFF6B7280),
                                        size: 20.0,
                                      ),
                                    ),
                                  ),
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    color: Color(0xFF1F2937),
                                    fontSize: 16.0,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  validator: _model.staffPasswordTextControllerValidator.asValidator(context),
                                ),
                              ],
                            ),
                          ),
                          
                          // 로그인 버튼 - 더 세련되게
                          Container(
                            width: double.infinity,
                            height: 52.0,
                            child: ElevatedButton(
                              onPressed: _model.isLoading ? null : _handleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _model.isLoading 
                                    ? Color(0xFFE5E7EB)
                                    : Color(0xFF6366F1),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                ),
                                disabledBackgroundColor: Color(0xFFE5E7EB),
                              ),
                              child: _model.isLoading 
                                  ? Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: 20.0,
                                          height: 20.0,
                                          child: CircularProgressIndicator(
                                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6B7280)),
                                            strokeWidth: 2.0,
                                          ),
                                        ),
                                        SizedBox(width: 12),
                                        Text(
                                          '로그인 중...',
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            color: Color(0xFF6B7280),
                                            fontSize: 16.0,
                                            letterSpacing: 0.0,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Text(
                                      '로그인',
                                      style: AppTextStyles.bodyText.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                                    ),
                            ),
                          ),

                          // 개발용 로그인 버튼 (웹 릴리즈 빌드에서는 비활성화)
                          if (kDebugMode || !kIsWeb)
                            Padding(
                              padding: EdgeInsetsDirectional.fromSTEB(0.0, 16.0, 0.0, 0.0),
                              child: Container(
                                width: double.infinity,
                                height: 48.0,
                                child: OutlinedButton(
                                  onPressed: _model.isLoading ? null : _handleDevLogin,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Color(0xFF6366F1),
                                    side: BorderSide(
                                      color: Color(0xFF6366F1),
                                      width: 1.5,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12.0),
                                    ),
                                    backgroundColor: Colors.transparent,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.developer_mode_rounded,
                                        color: Color(0xFF6366F1),
                                        size: 18.0,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        '개발용 로그인',
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          color: Color(0xFF6366F1),
                                          fontSize: 14.0,
                                          letterSpacing: 0.0,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // 하단 정보
                Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(0.0, 32.0, 0.0, 0.0),
                  child: Text(
                    '© 2025 EnableTech, Co., Ltd. All rights reserved.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: Color(0xFF9CA3AF),
                      fontSize: 14.0,
                      letterSpacing: 0.0,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 