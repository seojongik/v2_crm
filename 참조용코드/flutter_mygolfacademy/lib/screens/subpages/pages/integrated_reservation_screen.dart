import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';  // kDebugMode를 사용하기 위한 import 추가
import 'package:provider/provider.dart';
import 'package:famd_clientapp/providers/user_provider.dart';
import 'package:famd_clientapp/services/ls_countings_service.dart';
import 'package:famd_clientapp/models/lesson_counting.dart';
import 'package:intl/intl.dart';
import 'package:famd_clientapp/screens/subpages/pages/ts_reservation_screen.dart';
import 'package:famd_clientapp/screens/subpages/pages/ts_reservation_history_screen.dart';
import 'package:famd_clientapp/screens/subpages/pages/integrated_reservation_info.dart';
import 'package:famd_clientapp/screens/subpages/pages/junior_reservation_screen.dart';
import 'package:famd_clientapp/screens/subpages/pages/routine_member_screen.dart';
import 'package:famd_clientapp/screens/subpages/pages/routine_junior_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class IntegratedReservationScreen extends StatefulWidget {
  const IntegratedReservationScreen({Key? key}) : super(key: key);

  @override
  State<IntegratedReservationScreen> createState() => _IntegratedReservationScreenState();
}

class _IntegratedReservationScreenState extends State<IntegratedReservationScreen> {
  bool _isLoading = true;
  int _creditBalance = 0;
  int _totalRemainingLessons = 0;
  List<Map<String, dynamic>> _lessonTypes = [];
  List<Map<String, dynamic>> _juniorRelations = [];  // 주니어 관계 정보
  Map<String, List<Map<String, dynamic>>> _juniorLessons = {};  // 주니어 ID별 레슨 정보
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
    _testContractExpiry();  // 계약 만료 테스트 추가
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      
      // 사용자가 로그인되어 있는지 확인
      if (userProvider.user == null) {
        throw Exception('로그인이 필요합니다.');
      }

      // 크레딧 잔액 가져오기
      final creditResponse = await http.post(
        Uri.parse('https://autofms.mycafe24.com/dynamic_api.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'operation': 'get',
          'table': 'v2_bill',
          'where': [
            {'field': 'member_id', 'operator': '=', 'value': userProvider.user!.id},
            if (userProvider.currentBranchId != null)
              {'field': 'branch_id', 'operator': '=', 'value': userProvider.currentBranchId!}
          ],
          'orderBy': [
            {'field': 'bill_id', 'direction': 'DESC'}
          ],
          'limit': 1
        }),
      );
      
      if (creditResponse.statusCode == 200) {
        final creditData = jsonDecode(creditResponse.body);
        if (creditData['success'] == true && creditData['data'] != null && creditData['data'].isNotEmpty) {
          // 최신 거래 내역의 잔액 가져오기
          _creditBalance = int.parse(creditData['data'][0]['bill_balance_after'].toString());
        }
      }

      // 레슨 카운팅 데이터 가져오기 (유형별로 구분)
      final lessonData = await LSCountingsService.getLessonTypeBalances(
        userProvider.user!.id,
        branchId: userProvider.currentBranchId,
      );
      
      // 레슨 유형 목록 가져오기
      _lessonTypes = List<Map<String, dynamic>>.from(lessonData['lessonTypes'] ?? []);
      
      // 디버깅: 모든 레슨 유형 정보 상세 출력
      if (kDebugMode) {
        print('\n===== [디버깅] 전체 레슨 유형 정보 상세 출력 =====');
        print('레슨 유형 수: ${_lessonTypes.length}');
        
        for (int i = 0; i < _lessonTypes.length; i++) {
          final lessonType = _lessonTypes[i];
          print('\n[레슨 유형 #${i+1}]');
          print('- 계약 ID: ${lessonType['contractId']}');
          print('- 유형: ${lessonType['type']}');
          print('- 프로: ${lessonType['pro']}');
          print('- 잔여 레슨: ${lessonType['remainingLessons']}분');
          
          if (lessonType['lastRecord'] != null) {
            final record = lessonType['lastRecord'];
            print('- 최신 레코드 정보:');
            print('  - lsId: ${record.lsId}');
            print('  - lsContractId: ${record.lsContractId}');
            print('  - lsType: ${record.lsType}');
            print('  - lsProName: ${record.lsProName}');
            print('  - lsBalanceMinAfter: ${record.lsBalanceMinAfter}');
            print('  - updatedAt: ${record.updatedAt}');
          }
        }
        print('===== [디버깅] 전체 레슨 유형 정보 출력 완료 =====\n');
      }
      
      // 일반 레슨만 필터링하여 총 잔여 레슨 계산
      int regularLessonsTotal = 0;
      if (kDebugMode) {
        print('\n===== [디버깅] 일반 레슨 필터링 과정 =====');
        print('총 레슨 유형 수: ${_lessonTypes.length}');
      }
      
      for (var lessonType in _lessonTypes) {
        // 레슨 유형이 '일반레슨'인 경우만 합산 (대소문자 무시, 공백 무시)
        String type = lessonType['type'].toString().toLowerCase().replaceAll(' ', '');
        int minutes = lessonType['remainingLessons'] as int;
        
        // 만료 여부 확인 (isValid 필드가 없거나 true인 경우만 유효)
        bool isValid = lessonType['isValid'] ?? true;
        
        if (kDebugMode) {
          print('\n계약 ID: ${lessonType['contractId']}');
          print('- 레슨 유형: ${lessonType['type']}');
          print('- 잔여 레슨: ${minutes}분');
          print('- 유효 여부: ${isValid ? "유효" : "만료"}');
          
          // LastRecord 정보 출력
          if (lessonType['lastRecord'] != null) {
            final record = lessonType['lastRecord'];
            print('- 최신 레코드 정보:');
            print('  - lsId: ${record.lsId}');
            print('  - lsContractId: ${record.lsContractId}');
            print('  - lsType: ${record.lsType}');
            print('  - lsProName: ${record.lsProName}');
            print('  - lsBalanceMinAfter: ${record.lsBalanceMinAfter}');
            print('  - updatedAt: ${record.updatedAt}');
          }
        }
        
        if ((type == '일반레슨' || type == '일반' || type == 'regular') && isValid) {
          regularLessonsTotal += minutes;
          if (kDebugMode) {
            print('✅ 결과: 포함됨 (일반레슨 & 유효한 계약)');
          }
        } else {
          String reason = !isValid ? "만료된 계약" : "주니어레슨";
          if (kDebugMode) {
            print('❌ 결과: 제외됨 (이유: $reason)');
          }
        }
      }
      
      if (kDebugMode) {
        print('\n일반 레슨 총 잔여량: ${regularLessonsTotal}분');
        print('===== [디버깅] 일반 레슨 필터링 완료 =====\n');
      }
      
      // 필터링된 일반 레슨 잔여량만 저장
      _totalRemainingLessons = regularLessonsTotal;
      
      // 주니어 관계 정보 가져오기 - dynamic_api.php 사용
      await _loadJuniorRelations(userProvider.user!.id);

      if (kDebugMode) {
        print('일반 레슨 잔여량: $_totalRemainingLessons분');
        print('레슨 유형 수: ${_lessonTypes.length}');
        print('주니어 관계 수: ${_juniorRelations.length}');
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print('데이터 로드 오류: $e');
      }
      setState(() {
        _error = '데이터를 불러오는 중 오류가 발생했습니다: $e';
        _isLoading = false;
      });
    }
  }

  // 주니어 관계 정보 가져오기 - dynamic_api.php 사용
  Future<void> _loadJuniorRelations(String memberId) async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      
      // WHERE 조건 구성
      final whereConditions = [
        {
          'field': 'member_id',
          'operator': '=',
          'value': memberId
        }
      ];
      
      // branchId가 있는 경우 조건에 추가
      if (userProvider.currentBranchId != null && userProvider.currentBranchId!.isNotEmpty) {
        whereConditions.add({
          'field': 'branch_id',
          'operator': '=',
          'value': userProvider.currentBranchId!
        });
      }
      
      // 주니어 관계 정보 조회 API 호출
      final response = await http.post(
        Uri.parse('https://autofms.mycafe24.com/dynamic_api.php'),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'FlutterApp/1.0'
        },
        body: jsonEncode({
          'operation': 'get',
          'table': 'v2_junior_relation',
          'fields': ['member_id', 'junior_member_id', 'junior_name'],
          'where': whereConditions
        }),
      );
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        if (responseData['success'] == true && responseData['data'] != null) {
          // 주니어 관계 정보 저장
          final juniorRelations = List<Map<String, dynamic>>.from(responseData['data']);
          setState(() {
            _juniorRelations = juniorRelations;
          });
          
          // 각 주니어별 레슨 카운팅 정보 조회
          if (juniorRelations.isNotEmpty) {
            await _loadJuniorLessonCountings(juniorRelations);
          }
        } else {
          if (kDebugMode) {
            print('주니어 관계 조회 실패: ${responseData['error']}');
          }
        }
      } else {
        if (kDebugMode) {
          print('주니어 관계 조회 HTTP 오류: ${response.statusCode}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('주니어 관계 로드 오류: $e');
      }
    }
  }

  // 주니어 레슨 카운팅 정보 가져오기
  Future<void> _loadJuniorLessonCountings(List<Map<String, dynamic>> juniorRelations) async {
    final Map<String, List<Map<String, dynamic>>> juniorLessons = {};
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    
    for (final junior in juniorRelations) {
      final juniorMemberId = junior['junior_member_id'].toString();
      
      try {
        // 주니어 회원의 레슨 카운팅 데이터 가져오기
        final lessonData = await LSCountingsService.getLessonTypeBalances(
          juniorMemberId,
          branchId: userProvider.currentBranchId,
        );
        final juniorLessonTypes = List<Map<String, dynamic>>.from(lessonData['lessonTypes'] ?? []);
        
        if (juniorLessonTypes.isNotEmpty) {
          juniorLessons[juniorMemberId] = juniorLessonTypes;
        }
        
        if (kDebugMode) {
          print('주니어(${junior['junior_name']}) 레슨 유형 수: ${juniorLessonTypes.length}');
        }
      } catch (e) {
        if (kDebugMode) {
          print('주니어 레슨 카운팅 로드 오류: $e');
        }
      }
    }
    
    setState(() {
      _juniorLessons = juniorLessons;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 앱 테마 색상 정의 - 갈색 테마
    final Color primaryColor = const Color(0xFF5D4037); // 갈색 기본 테마
    final Color secondaryColor = const Color(0xFF8D6E63); // 밝은 갈색
    final Color accentColor = const Color(0xFFA1887F); // 더 밝은 갈색
    
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA), // 매우 연한 회색 배경
      appBar: AppBar(
        title: const Text(
          '통합예약',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // 새로고침 버튼
          IconButton(
            icon: const Icon(Icons.refresh, size: 22),
            onPressed: _loadData,
            tooltip: '새로고침',
          ),
        ],
      ),
      body: _isLoading 
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '데이터를 불러오는 중입니다',
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          : _error != null
              ? _buildErrorView()
              : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 패딩 복원
                      Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 상단 정보 카드 (썸네일처럼 표시) - 2행으로 변경
                            Row(
                              children: [
                                // 크레딧 잔액
                                Expanded(
                                  flex: 1,
                                  child: _buildInfoCard(
                                    icon: Icons.account_balance_wallet,
                                    title: '크레딧 잔액',
                                    value: '${NumberFormat('#,###').format(_creditBalance)} c',
                                    iconColor: primaryColor,
                                    borderColor: primaryColor,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                
                                // 잔여 레슨권
                                Expanded(
                                  flex: 1,
                                  child: _buildInfoCard(
                                    icon: Icons.golf_course,
                                    title: '잔여 레슨권',
                                    value: '${_totalRemainingLessons}분',
                                    iconColor: secondaryColor,
                                    borderColor: secondaryColor,
                                  ),
                                ),
                              ],
                            ),
                            
                            // 주니어 레슨권을 두 번째 줄에 배치
                            if (_juniorRelations.isNotEmpty && _juniorLessons.isNotEmpty)
                              Column(
                                children: [
                                  const SizedBox(height: 14),
                                  _buildInfoCard(
                                    icon: Icons.child_care,
                                    title: '주니어 레슨권',
                                    value: '${_calculateTotalJuniorLessons()}회',
                                    iconColor: accentColor,
                                    borderColor: accentColor,
                                  ),
                                ],
                              ),
                            
                            const SizedBox(height: 32),

                            // 안내 텍스트
                            Text(
                              '원하시는 예약 유형을 선택해주세요',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            const SizedBox(height: 24),
                            
                            // 타석 예약 카드 → 일반회원 예약으로 변경
                            _buildReservationTypeCard(
                              context,
                              icon: Icons.sports_golf,
                              title: '일반회원 예약(타석+레슨)',
                              description: '골프 타석 및 레슨을 예약합니다',
                              onSingleTap: () => _navigateToSubMenu(context, 1, false),
                              onRoutineTap: () => _handleMemberRoutineTap(context),
                            ),
                            const SizedBox(height: 16),
                            
                            // 타석+레슨 예약 카드 → 주니어 골프스쿨 예약으로 변경
                            _buildReservationTypeCard(
                              context,
                              icon: Icons.person_add,
                              title: '주니어 골프스쿨 예약',
                              description: '주니어 회원을 위한 골프 레슨을 예약합니다',
                              onSingleTap: () => _navigateToSubMenu(context, 2, false),
                              onRoutineTap: () => _handleJuniorRoutineTap(context),
                            ),
                            
                            const SizedBox(height: 30),
                            
                            // 예약내역 조회 버튼 (레슨권 정보 조회 버튼을 수정하여 맨 아래에 배치)
                            _buildStyledButton(
                              icon: Icons.history,
                              label: '예약내역 조회',
                              onTap: () => _navigateToIntegratedReservationInfo(context),
                              bgColor: primaryColor,
                              textColor: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildErrorView() {
    // 앱 테마 색상 정의
    final Color primaryColor = const Color(0xFF5D4037); // 갈색 기본 테마
    
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: Colors.red.shade200, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 64,
                color: Colors.red.shade400,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '데이터를 불러올 수 없습니다',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text(
                _error ?? '알 수 없는 오류가 발생했습니다.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 200,
              child: ElevatedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh),
                label: const Text(
                  '다시 시도',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 개선된 버튼 위젯
  Widget _buildStyledButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color bgColor,
    required Color textColor,
    Color? borderColor,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        backgroundColor: bgColor,
        foregroundColor: textColor,
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.1),
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: borderColor != null
              ? BorderSide(color: borderColor, width: 1)
              : BorderSide.none,
        ),
      ),
    );
  }

  // 정보 타일 위젯
  Widget _buildInfoTile({
    required double width,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
    required String value,
    required Color textColor,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: iconColor.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 타이틀 행 (아이콘 + 텍스트)
          Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: iconColor,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 값 (크게 표시)
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
  
  // 주니어 전체 레슨 횟수 계산
  int _calculateTotalJuniorLessons() {
    int totalMinutes = 0;
    
    // 모든 주니어와 모든 레슨 유형에 대해 분 수를 합산
    _juniorLessons.forEach((juniorId, lessonTypes) {
      for (final lessonType in lessonTypes) {
        totalMinutes += lessonType['remainingLessons'] as int;
      }
    });
    
    // 30분당 1회로 계산하여 반환
    return (totalMinutes / 30).ceil();
  }

  // 작은 정보 카드 위젯
  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required Color iconColor,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor.withOpacity(0.5), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(50),
              border: Border.all(color: iconColor, width: 1),
            ),
            child: Icon(
              icon,
              size: 24,
              color: iconColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14, // 골프 타석 및 레슨을 예약합니다와 동일한 크기
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReservationTypeCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onSingleTap,
    required VoidCallback onRoutineTap,
  }) {
    // 앱 테마 색상 정의
    final Color primaryColor = const Color(0xFF5D4037); // 갈색 기본 테마
    final Color secondaryColor = const Color(0xFF8D6E63); // 밝은 갈색
    
    final Color accentColor = title == '일반회원 예약(타석+레슨)'
        ? primaryColor
        : const Color(0xFF795548); // 다른 갈색 계열
    
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            // 메뉴 헤더 (제목 및 설명)
            Padding(
              padding: const EdgeInsets.all(18.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: accentColor, width: 1),
                    ),
                    child: Icon(
                      icon,
                      size: 32,
                      color: accentColor,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: accentColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          description,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // 구분선
            Divider(color: Colors.grey.shade200, height: 1),
            
            // 예약 버튼 영역
            Padding(
              padding: const EdgeInsets.all(18.0),
              child: Row(
                children: [
                  // 1회 예약 버튼
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onSingleTap,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        '1회 예약',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 루틴 예약 버튼
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onRoutineTap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: accentColor,
                        elevation: 0,
                        side: BorderSide(color: accentColor, width: 1),
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            '루틴 예약',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8, 
                              vertical: 2
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Text(
                              '준비 중',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade700,
                              ),
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

  void _navigateToSubMenu(BuildContext context, int subMenuIndex, bool isRoutine) {
    // 현재 로그인된 사용자의 회원 ID 가져오기
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final String? userIdStr = userProvider.user?.id;
    
    // String 타입의 ID를 int 타입으로 변환 (변환 실패 시 null)
    final int? memberId = userIdStr != null ? int.tryParse(userIdStr) : null;
    
    // 디버깅: 회원 ID 확인
    print('🔍 [디버깅] IntegratedReservationScreen - 화면 이동 시 회원 ID: $memberId (원본: $userIdStr)');
    
    if (isRoutine) {
      // 루틴 예약인 경우 루틴 예약 화면으로 이동
      _navigateToRoutineScreen(context, subMenuIndex, memberId);
    } else if (subMenuIndex == 1) {
      // 일반회원 예약(타석+레슨)인 경우 TSReservationScreen으로 이동
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TSReservationScreen(
            memberId: memberId, // int? 타입으로 변환된 회원 ID 전달
            branchId: userProvider.currentBranchId, // 현재 지점 ID 전달
          ),
        ),
      );
    } else if (subMenuIndex == 2) {
      // 주니어 골프스쿨 예약인 경우 JuniorReservationScreen으로 이동
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => JuniorReservationScreen(
            memberId: memberId, // int? 타입으로 변환된 회원 ID 전달
          ),
        ),
      ).then((result) {
        // 예약 성공 후 돌아왔을 때(result가 true인 경우) 데이터 새로고침
        if (result == true) {
          print('🔄 주니어 예약 성공 후 데이터 새로고침');
          _loadData(); // 데이터 새로고침 실행
        }
      });
    } else {
      // 그 외 메뉴는 기존처럼 준비 중 페이지 표시
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => _buildPlaceholderPage(
            context, 
            _getSubMenuTitle(subMenuIndex, isRoutine),
          ),
        ),
      );
    }
  }

  // 루틴 예약 화면으로 이동
  void _navigateToRoutineScreen(BuildContext context, int subMenuIndex, int? memberId) {
    if (subMenuIndex == 1) {
      // 일반회원 루틴 예약 화면으로 이동
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RoutineMemberScreen(
            memberId: memberId,
          ),
        ),
      );
    } else if (subMenuIndex == 2) {
      // 주니어 골프스쿨 루틴 예약 화면으로 이동
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RoutineJuniorScreen(
            memberId: memberId,
          ),
        ),
      );
    }
  }

  String _getSubMenuTitle(int subMenuIndex, bool isRoutine) {
    String baseTitle = '';
    switch (subMenuIndex) {
      case 1:
        baseTitle = '일반회원 예약(타석+레슨)';
        break;
      case 2:
        baseTitle = '주니어 골프스쿨 예약';
        break;
      default:
        baseTitle = '예약';
    }
    
    return isRoutine ? '$baseTitle (루틴)' : baseTitle;
  }

  Widget _buildPlaceholderPage(BuildContext context, String title) {
    // 앱 테마 색상 정의
    final Color primaryColor = const Color(0xFF5D4037); // 갈색 기본 테마
    
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: Colors.grey.shade300,
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 3,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.construction_rounded,
                  size: 80,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '준비 중입니다',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.grey.shade200,
                    width: 1,
                  ),
                ),
                child: Text(
                  '이 기능은 현재 개발 중이며 곧 제공될 예정입니다.\n이용에 불편을 드려 죄송합니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade700,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: 200,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text(
                    '이전 화면으로',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 준비 중인 페이지로 이동
  void _navigateToPlaceholderPage(BuildContext context, String title) {
    // 준비 중 페이지로 이동
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _buildPlaceholderPage(context, title),
      ),
    );
  }

  void _showRoutineNotReadyMessage(BuildContext context) {
    // 일반회원 루틴 예약 화면으로 이동
    _navigateToRoutineScreen(context, 1, null);
  }

  // 루틴 예약 버튼 클릭 핸들러 (일반회원)
  void _handleMemberRoutineTap(BuildContext context) {
    // 현재 로그인된 사용자의 회원 ID 가져오기
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final String? userIdStr = userProvider.user?.id;
    final int? memberId = userIdStr != null ? int.tryParse(userIdStr) : null;
    
    // 일반회원 루틴 예약 화면으로 이동
    _navigateToRoutineScreen(context, 1, memberId);
  }

  // 루틴 예약 버튼 클릭 핸들러 (주니어)
  void _handleJuniorRoutineTap(BuildContext context) {
    // 현재 로그인된 사용자의 회원 ID 가져오기
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final String? userIdStr = userProvider.user?.id;
    final int? memberId = userIdStr != null ? int.tryParse(userIdStr) : null;
    
    // 주니어 루틴 예약 화면으로 이동
    _navigateToRoutineScreen(context, 2, memberId);
  }

  void _navigateToIntegratedReservationInfo(BuildContext context) {
    // 현재 로그인된 사용자의 회원 ID 가져오기
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final String? userIdStr = userProvider.user?.id;
    final int? memberId = userIdStr != null ? int.tryParse(userIdStr) : null;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => IntegratedReservationInfo(memberId: memberId),
      ),
    );
  }

  // 계약 만료 여부 테스트를 위한 함수 - dynamic_api.php 사용
  Future<void> _testContractExpiry() async {
    try {
      if (kDebugMode) {
        print('\n===== [디버깅] 계약 만료 테스트 =====');
        print('현재 시간: ${DateTime.now()}');
      }
      
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      if (userProvider.user == null) {
        if (kDebugMode) {
          print('로그인되지 않은 사용자입니다.');
        }
        return;
      }
      
      if (kDebugMode) {
        print('회원 ID: ${userProvider.user!.id}');
        print('회원 이름: ${userProvider.user!.name}');
      }
      
      // 1. 계약 정보 직접 가져오기 - dynamic_api.php 사용
      final whereConditions = [
        {
          'field': 'member_id',
          'operator': '=',
          'value': userProvider.user!.id.toString()
        }
      ];
      
      // branchId 조건 추가
      if (userProvider.currentBranchId != null && userProvider.currentBranchId!.isNotEmpty) {
        whereConditions.add({
          'field': 'branch_id',
          'operator': '=',
          'value': userProvider.currentBranchId!
        });
      }
      
      final contractResponse = await http.post(
        Uri.parse('https://autofms.mycafe24.com/dynamic_api.php'),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'FlutterApp/1.0'
        },
        body: jsonEncode({
          'operation': 'get',
          'table': 'v2_LS_contracts',
          'where': whereConditions
        }),
      );
      
      List<Map<String, dynamic>> contracts = [];
      
      if (contractResponse.statusCode == 200) {
        final contractData = jsonDecode(contractResponse.body);
        if (contractData['success'] == true && contractData['data'] != null) {
          contracts = List<Map<String, dynamic>>.from(contractData['data']);
          
          // 만료일 파싱 처리 (프론트엔드에서 처리)
          for (var contract in contracts) {
            if (contract['LS_expiry_date'] != null) {
              try {
                contract['expiry_date'] = DateTime.parse(contract['LS_expiry_date']);
              } catch (e) {
                if (kDebugMode) {
                  print('만료일 파싱 오류: ${contract['LS_expiry_date']}, 오류: $e');
                }
                contract['expiry_date'] = null;
              }
            }
          }
        }
      }
      
      if (kDebugMode) {
        print('직접 가져온 계약 정보 수: ${contracts.length}');
        
        // 계약이 없을 경우 확인
        if (contracts.isEmpty) {
          print('⚠️ 주의: 계약 정보가 없습니다. 이는 다음과 같은 이유일 수 있습니다:');
          print('  1. 해당 회원에게 레슨 계약이 없음');
          print('  2. API 호출 오류 또는 DB 문제');
          print('  3. 데이터 형식 문제 또는 파싱 오류');
        }
        
        // 계약 타입별 요약
        Map<String, int> contractTypeCount = {};
        Map<String, int> validContractCount = {};
        Map<String, int> expiredContractCount = {};
        
        // 각 계약 정보 출력
        for (var contract in contracts) {
          print('\n계약 ID: ${contract['LS_contract_id']}');
          print('계약 유형: ${contract['LS_type']}');
          
          // 계약 타입 카운트
          String type = contract['LS_type'] ?? '불명';
          contractTypeCount[type] = (contractTypeCount[type] ?? 0) + 1;
          
          print('계약일: ${contract['LS_contract_date']}');
          print('계약 종료일: ${contract['LS_contract_enddate']}');
          print('만료일: ${contract['LS_expiry_date']}');
          print('계약 상세 정보:');
          contract.forEach((key, value) {
            if (key != 'expiry_date') { // 변환된 필드는 제외
              print('  $key: $value');
            }
          });
          
          // 만료일 확인 로직
          DateTime? expiryDate = contract['expiry_date'];
          if (expiryDate != null) {
            print('\n만료일 분석:');
            print('- 파싱된 만료일: $expiryDate');
            
            // 만료 여부 확인
            final isExpired = expiryDate.isBefore(DateTime.now());
            print('- 만료 여부: ${isExpired ? '만료됨 ❌' : '유효함 ✅'}');
            
            // 계약 유효성에 따른 카운트
            if (isExpired) {
              expiredContractCount[type] = (expiredContractCount[type] ?? 0) + 1;
              print('- ⚠️ 이 계약은 만료되었습니다! (${DateTime.now().difference(expiryDate).inDays}일 지남)');
            } else {
              validContractCount[type] = (validContractCount[type] ?? 0) + 1;
              print('- 유효한 계약입니다 (${expiryDate.difference(DateTime.now()).inDays}일 남음)');
            }
          } else {
            print('\n⚠️ 만료일이 null이거나 변환에 실패했습니다.');
            print('원본 만료일 데이터: ${contract['LS_expiry_date']}');
            // 만료일이 없는 경우 기본 유효로 처리
            validContractCount[type] = (validContractCount[type] ?? 0) + 1;
          }
        }
        
        // 유형별 계약 요약 출력
        print('\n===== 계약 유형별 요약 =====');
        contractTypeCount.forEach((type, count) {
          final valid = validContractCount[type] ?? 0;
          final expired = expiredContractCount[type] ?? 0;
          print('- $type: 총 $count개 계약 (유효: $valid개, 만료: $expired개)');
        });
        
        // 전체 요약
        print('\n===== 전체 계약 요약 =====');
        print('- 총 계약 수: ${contracts.length}개');
        print('- 유효한 계약 수: ${validContractCount.values.fold(0, (a, b) => a + b)}개');
        print('- 만료된 계약 수: ${expiredContractCount.values.fold(0, (a, b) => a + b)}개');
        
        // 일반레슨 계약 상태
        final regularTotal = (contractTypeCount['일반레슨'] ?? 0) + (contractTypeCount['일반'] ?? 0);
        final regularValid = (validContractCount['일반레슨'] ?? 0) + (validContractCount['일반'] ?? 0);
        print('\n===== 일반 레슨 계약 상태 =====');
        print('- 일반레슨 계약 총 수: $regularTotal개');
        print('- 유효한 일반레슨 계약 수: $regularValid개');
        print('- 만료된 일반레슨 계약 수: ${regularTotal - regularValid}개');
      }
      
      if (kDebugMode) {
        print('\n===== [디버깅] 계약 만료 테스트 완료 =====\n');
      }
    } catch (e) {
      if (kDebugMode) {
        print('계약 만료 테스트 오류: $e');
        print('스택 트레이스:');
        print(StackTrace.current);
      }
    }
  }
} 