import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';  // kDebugMode를 사용하기 위한 import 추가
import 'package:provider/provider.dart';
import 'package:famd_clientapp/providers/user_provider.dart';
import 'package:famd_clientapp/services/api_service.dart';
import 'package:famd_clientapp/services/ls_countings_service.dart';
import 'package:famd_clientapp/models/lesson_counting.dart';
import 'package:intl/intl.dart';
import 'package:famd_clientapp/screens/subpages/pages/ts_reservation_history_screen.dart';
import 'package:famd_clientapp/screens/subpages/pages/lesson_reservation_history.dart'; // 레슨 예약 히스토리 화면 추가
import 'package:famd_clientapp/screens/subpages/pages/junior_reservation_info.dart'; // 주니어 예약 정보 화면 추가

class IntegratedReservationInfo extends StatefulWidget {
  final int? memberId;

  const IntegratedReservationInfo({Key? key, this.memberId}) : super(key: key);

  @override
  State<IntegratedReservationInfo> createState() => _IntegratedReservationInfoState();
}

class _IntegratedReservationInfoState extends State<IntegratedReservationInfo> {
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
      final creditTransactions = await ApiService.getCreditTransactions(
        userProvider.user!.id,
        branchId: userProvider.currentBranchId,
      );
      
      if (creditTransactions.isNotEmpty) {
        // 최신 거래 내역의 잔액 가져오기
        _creditBalance = creditTransactions.first.balance;
      }

      // 레슨 카운팅 데이터 가져오기 (유형별로 구분)
      final lessonData = await LSCountingsService.getLessonTypeBalances(
        userProvider.user!.id,
        branchId: userProvider.currentBranchId,
      );
      
      // 레슨 유형 목록 가져오기
      _lessonTypes = List<Map<String, dynamic>>.from(lessonData['lessonTypes'] ?? []);
      
      // 일반 레슨만 필터링하여 총 잔여 레슨 계산
      int regularLessonsTotal = 0;
      
      for (var lessonType in _lessonTypes) {
        // 레슨 유형이 '일반레슨'인 경우만 합산 (대소문자 무시, 공백 무시)
        String type = lessonType['type'].toString().toLowerCase().replaceAll(' ', '');
        int minutes = lessonType['remainingLessons'] as int;
        
        // 만료 여부 확인 (isValid 필드가 없거나 true인 경우만 유효)
        bool isValid = lessonType['isValid'] ?? true;
        
        if ((type == '일반레슨' || type == '일반' || type == 'regular') && isValid) {
          regularLessonsTotal += minutes;
        }
      }
      
      // 필터링된 일반 레슨 잔여량만 저장
      _totalRemainingLessons = regularLessonsTotal;
      
      // 주니어 관계 정보 가져오기
      await _loadJuniorRelations(userProvider.user!.id);

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

  // 주니어 관계 정보 가져오기
  Future<void> _loadJuniorRelations(String memberId) async {
    try {
      // 주니어 관계 정보 조회 API 호출
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final response = await ApiService.getJuniorRelations(
        memberId,
        branchId: userProvider.currentBranchId,
      );
      
      if (response['success'] == true) {
        // 주니어 관계 정보 저장
        final juniorRelations = List<Map<String, dynamic>>.from(response['data'] ?? []);
        setState(() {
          _juniorRelations = juniorRelations;
        });
        
        // 각 주니어별 레슨 카운팅 정보 조회
        if (juniorRelations.isNotEmpty) {
          await _loadJuniorLessonCountings(juniorRelations);
        }
      } else {
        if (kDebugMode) {
          print('주니어 관계 조회 실패: ${response['error']}');
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
          '예약내역 조회',
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
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 정보 카드들을 2행으로 배치
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
                                isCompact: false,
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
                                isCompact: false,
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
                                isCompact: false,
                              ),
                            ],
                          ),
                        
                        const SizedBox(height: 32),
                        Text(
                          '예약 내역',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        // 타석예약 조회 버튼
                        _buildStyledButton(
                          icon: Icons.history,
                          label: '타석예약 조회',
                          onTap: () => _navigateToReservationHistory(context),
                          bgColor: primaryColor,
                          textColor: Colors.white,
                        ),
                        const SizedBox(height: 12),
                        
                        // 레슨예약 조회 버튼 - 새로운 레슨 예약 히스토리 화면으로 이동
                        _buildStyledButton(
                          icon: Icons.history_edu,
                          label: '레슨예약 조회',
                          onTap: () => _navigateToLessonReservationHistory(context),
                          bgColor: secondaryColor,
                          textColor: Colors.white,
                        ),
                        
                        // 주니어예약 조회 버튼 (주니어가 있는 경우만)
                        if (_juniorRelations.isNotEmpty)
                          Column(
                            children: [
                              const SizedBox(height: 12),
                              _buildStyledButton(
                                icon: Icons.child_care,
                                label: '주니어예약 조회',
                                onTap: () => _navigateToJuniorReservationInfo(context),
                                bgColor: accentColor,
                                textColor: Colors.white,
                              ),
                            ],
                          ),
                      ],
                    ),
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

  // 정보 카드 위젯
  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required Color iconColor,
    required Color borderColor,
    bool isCompact = false,
  }) {
    return Container(
      width: isCompact ? null : double.infinity,
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
        mainAxisSize: isCompact ? MainAxisSize.min : MainAxisSize.max,
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
                    fontSize: 14,
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

  // 버튼 위젯
  Widget _buildStyledButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color bgColor,
    required Color textColor,
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
        ),
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

  void _navigateToReservationHistory(BuildContext context) {
    // 예약 내역 조회 화면으로 이동
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final String? userIdStr = userProvider.user?.id;
    final int? memberId = userIdStr != null ? int.tryParse(userIdStr) : null;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TSReservationHistoryScreen(memberId: memberId),
      ),
    );
  }

  // 레슨 예약 내역 조회 화면으로 이동하는 새 메서드
  void _navigateToLessonReservationHistory(BuildContext context) {
    // 레슨 예약 내역 조회 화면으로 이동
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final String? userIdStr = userProvider.user?.id;
    final int? memberId = userIdStr != null ? int.tryParse(userIdStr) : null;
    
    // 새로운 레슨 예약 내역 화면으로 이동
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LessonReservationHistoryScreen(memberId: memberId),
      ),
    );
  }

  // 주니어 예약 내역 조회 화면으로 이동하는 새 메서드
  void _navigateToJuniorReservationInfo(BuildContext context) {
    // 주니어 예약 내역 조회 화면으로 이동
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final String? userIdStr = userProvider.user?.id;
    final int? memberId = userIdStr != null ? int.tryParse(userIdStr) : null;
    
    // 주니어 예약 정보 화면으로 이동
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => JuniorReservationInfoScreen(memberId: memberId),
      ),
    );
  }
} 