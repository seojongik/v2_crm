import '/components/side_bar_nav/side_bar_nav_widget.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '../../services/lesson_api_service.dart';
import '../../services/api_service.dart';
import '../../services/tab_design_upper.dart';
import '../../services/upper_button_input_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'crm4_lesson_model.dart';
import 'crm4_lesson_feedback.dart';
import 'crm4_lesson_salary.dart';
export 'crm4_lesson_model.dart';

class Crm4LessonWidget extends StatefulWidget {
  const Crm4LessonWidget({super.key, this.onNavigate});

  final Function(String)? onNavigate;

  static String routeName = 'crm4_lesson';
  static String routePath = 'crm4Lesson';

  @override
  State<Crm4LessonWidget> createState() => _Crm4LessonWidgetState();
}

class _Crm4LessonWidgetState extends State<Crm4LessonWidget>
    with TickerProviderStateMixin {
  late Crm4LessonModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  TabController? _proTabController;

  // 프로 관련 상태
  List<Map<String, dynamic>> staffList = [];
  Map<String, dynamic>? selectedStaff;
  bool includeRetiredStaff = false;
  bool isLoadingStaff = true;
  
  // 날짜 선택 관련 상태
  DateTime selectedDate = DateTime.now();
  DateTime currentWeekStart = DateTime.now();
  
  // 레슨 데이터 관련 상태
  List<Map<String, dynamic>> lessonData = [];
  bool isLoadingLessons = false;
  Map<String, Map<String, int>> lessonCountByDate = {}; // 날짜별 레슨 횟수 캐시 (completed/total)
  bool showAllLessons = false; // 전체 레슨 보기 여부
  Map<String, dynamic>? workSchedule; // 프로 근무시간 정보

  // salary_view 권한 체크 - 레슨비 정산 버튼 표시 여부 결정
  bool _canViewLessonFee() {
    final salaryPermission = ApiService.getCurrentAccessSettings()?['salary_view'] ?? '전체';

    // 전체 권한이면 항상 표시
    if (salaryPermission == '전체' || salaryPermission == 'Y') {
      return true;
    }

    // 본인 권한인 경우
    if (salaryPermission == '본인') {
      final currentUser = ApiService.getCurrentUser();
      final currentRole = ApiService.getCurrentStaffRole();

      // 프로 계정이고 선택된 프로가 본인인 경우만 표시
      if (currentRole == 'pro' && currentUser != null && selectedStaff != null) {
        final currentProId = currentUser['pro_id'];
        final selectedProId = selectedStaff!['pro_id'];
        return currentProId != null && selectedProId != null &&
               currentProId.toString() == selectedProId.toString();
      }
    }

    // 그 외의 경우는 표시하지 않음
    return false;
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => Crm4LessonModel());

    _model.textController ??= TextEditingController();
    _model.textFieldFocusNode ??= FocusNode();

    // 현재 주의 시작일 계산 (월요일 기준)
    _initializeWeekStart();
    _loadStaffList();
  }
  
  // 주의 시작일 초기화 (오늘 기준으로 과거 10일)
  void _initializeWeekStart() {
    DateTime now = DateTime.now();
    // 오늘부터 9일 전까지 (총 10일)
    currentWeekStart = now.subtract(Duration(days: 9));
  }
  
  // 특정 날짜의 레슨 수 조회 (분수 형태)
  String _getLessonCountForDate(DateTime date) {
    String dateStr = DateFormat('yyyy-MM-dd').format(date);
    final count = lessonCountByDate[dateStr];
    if (count == null) return '0/0';
    return '${count['completed'] ?? 0}/${count['total'] ?? 0}';
  }

  @override
  void dispose() {
    _proTabController?.dispose();
    _model.dispose();
    super.dispose();
  }
  
  // 필터링된 레슨 데이터 반환
  List<Map<String, dynamic>> get filteredLessonData {
    if (showAllLessons) {
      return lessonData;
    } else {
      return lessonData.where((lesson) =>
        lesson['LS_status'] == '결제완료' || lesson['LS_status'] == '예약완료'
      ).toList();
    }
  }

  // 시간대별 타일 데이터 생성 (근무시간 + 레슨)
  List<Map<String, dynamic>> get timeSlotTiles {
    List<Map<String, dynamic>> tiles = [];

    // 근무시간이 없거나 휴무인 경우 빈 리스트 반환
    if (workSchedule == null || workSchedule!['is_day_off'] == '휴무') {
      if (kDebugMode) {
        print('⚠️ [타일 생성] 근무시간 없음 또는 휴무');
      }
      return tiles;
    }

    // 근무 시작/종료 시간 파싱
    String workStart = workSchedule!['work_start'] ?? '00:00:00';
    String workEnd = workSchedule!['work_end'] ?? '00:00:00';

    if (kDebugMode) {
      print('🔍 [타일 생성] 근무시간: $workStart ~ $workEnd');
    }

    if (workStart == '00:00:00' && workEnd == '00:00:00') {
      if (kDebugMode) {
        print('⚠️ [타일 생성] 근무시간이 00:00:00 (휴무)');
      }
      return tiles; // 휴무
    }

    DateTime workStartTime = _parseTime(workStart);
    DateTime workEndTime = _parseTime(workEnd);

    // 필터링된 레슨을 시간순으로 정렬
    List<Map<String, dynamic>> sortedLessons = List.from(filteredLessonData);
    sortedLessons.sort((a, b) {
      String aTime = a['LS_start_time'] ?? '00:00:00';
      String bTime = b['LS_start_time'] ?? '00:00:00';
      return aTime.compareTo(bTime);
    });

    if (kDebugMode) {
      print('🔍 [타일 생성] 레슨 개수: ${sortedLessons.length}');
    }

    DateTime currentTime = workStartTime;

    // 레슨이 없으면 전체 근무시간을 빈 시간으로 표시
    if (sortedLessons.isEmpty) {
      tiles.add({
        'type': 'empty',
        'start_time': _formatTime(workStartTime),
        'end_time': _formatTime(workEndTime),
        'duration': workEndTime.difference(workStartTime).inMinutes,
      });
      if (kDebugMode) {
        print('✅ [타일 생성] 레슨 없음 - 전체 빈 시간 타일 추가');
      }
      return tiles;
    }

    for (var lesson in sortedLessons) {
      DateTime lessonStart = _parseTime(lesson['LS_start_time'] ?? '00:00:00');
      DateTime lessonEnd = _parseTime(lesson['LS_end_time'] ?? '00:00:00');

      // 레슨 시작 전 빈 시간이 있으면 추가
      if (currentTime.isBefore(lessonStart)) {
        tiles.add({
          'type': 'empty',
          'start_time': _formatTime(currentTime),
          'end_time': _formatTime(lessonStart),
          'duration': lessonStart.difference(currentTime).inMinutes,
        });
        if (kDebugMode) {
          print('✅ [타일 생성] 빈 시간 추가: ${_formatTime(currentTime)} ~ ${_formatTime(lessonStart)}');
        }
      }

      // 레슨 타일 추가
      tiles.add({
        'type': 'lesson',
        'data': lesson,
      });
      if (kDebugMode) {
        print('✅ [타일 생성] 레슨 추가: ${lesson['LS_start_time']} ~ ${lesson['LS_end_time']}');
      }

      currentTime = lessonEnd;
    }

    // 마지막 레슨 이후 근무 종료까지 빈 시간이 있으면 추가
    if (currentTime.isBefore(workEndTime)) {
      tiles.add({
        'type': 'empty',
        'start_time': _formatTime(currentTime),
        'end_time': _formatTime(workEndTime),
        'duration': workEndTime.difference(currentTime).inMinutes,
      });
      if (kDebugMode) {
        print('✅ [타일 생성] 마지막 빈 시간 추가: ${_formatTime(currentTime)} ~ ${_formatTime(workEndTime)}');
      }
    }

    if (kDebugMode) {
      print('✅ [타일 생성] 총 ${tiles.length}개 타일 생성 완료');
    }

    return tiles;
  }

  // 시간 문자열을 DateTime으로 파싱 (HH:mm:ss)
  DateTime _parseTime(String timeStr) {
    List<String> parts = timeStr.split(':');
    int hour = int.parse(parts[0]);
    int minute = int.parse(parts[1]);
    return DateTime(2000, 1, 1, hour, minute);
  }

  // DateTime을 시간 문자열로 변환 (HH:mm)
  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
  
  // 프로 목록 로드
  Future<void> _loadStaffList() async {
    try {
      setState(() {
        isLoadingStaff = true;
      });

      // 현재 branch_id 가져오기
      final currentBranchId = ApiService.getCurrentBranchId();
      if (currentBranchId == null) {
        print('❌ branch_id를 찾을 수 없습니다. 로그인이 필요합니다.');
        setState(() {
          isLoadingStaff = false;
        });
        return;
      }

      // lesson_status 권한 체크
      final accessSettings = ApiService.getCurrentAccessSettings();
      final lessonStatusPermission = accessSettings?['lesson_status'] ?? '전체'; // 설정이 없으면 전체 권한
      final hasFullLessonAccess = lessonStatusPermission != '본인';

      if (!hasFullLessonAccess) {
        // 본인 권한인 경우 현재 사용자의 정보만 로드
        final currentUser = ApiService.getCurrentUser();
        final currentRole = ApiService.getCurrentStaffRole();

        if (currentRole == 'pro' && currentUser != null) {
          // 현재 사용자가 프로인 경우 자신의 정보만 포함
          setState(() {
            staffList = [currentUser];
            selectedStaff = currentUser;
            isLoadingStaff = false;

            // TabController 초기화 (본인만)
            _proTabController?.dispose();
            _proTabController = TabController(
              length: 1,
              vsync: this,
            );
            _proTabController!.addListener(_onProTabChanged);
          });

          // 자동으로 레슨 데이터 로드
          _loadLessonData();
          _loadLessonCountsForDates();

          print('🔒 lesson_status 본인 권한: ${currentUser['pro_name']} 프로만 표시');
          return;
        } else {
          // 매니저이거나 프로가 아닌 경우 빈 목록
          setState(() {
            staffList = [];
            isLoadingStaff = false;
          });
          print('⚠️ lesson_status 본인 권한: 매니저는 레슨 조회 불가');
          return;
        }
      }

      // 전체 권한인 경우 모든 프로 조회
      final result = await LessonApiService.getStaffList(
        branchId: currentBranchId,
        includeRetired: true, // 모든 프로 조회 (필터링은 UI에서)
      );

      setState(() {
        staffList = result;
        isLoadingStaff = false;

        // TabController 초기화
        if (filteredStaffList.isNotEmpty) {
          _proTabController?.dispose();
          _proTabController = TabController(
            length: filteredStaffList.length,
            vsync: this,
          );
          _proTabController!.addListener(_onProTabChanged);
        }
      });

      if (result.isEmpty) {
        print('⚠️ 프로 목록이 비어있습니다.');
      }
    } catch (e) {
      setState(() {
        isLoadingStaff = false;
      });
      print('❌ 프로 목록 로드 오류: $e');
    }
  }
  
  // 선택된 프로의 레슨 데이터 로드
  Future<void> _loadLessonData() async {
    if (selectedStaff == null) return;

    try {
      setState(() {
        isLoadingLessons = true;
      });

      // 현재 branch_id 가져오기
      final currentBranchId = ApiService.getCurrentBranchId();
      if (currentBranchId == null) {
        print('❌ branch_id를 찾을 수 없습니다. 로그인이 필요합니다.');
        setState(() {
          isLoadingLessons = false;
        });
        return;
      }

      // 실제 API 호출로 v2_LS_orders에서 레슨 데이터 조회
      final formattedDate = DateFormat('yyyy-MM-dd').format(selectedDate);

      // 레슨 데이터와 근무시간 병렬 조회
      final results = await Future.wait([
        LessonApiService.getLessonsByProAndDate(
          branchId: currentBranchId,
          proId: selectedStaff!['pro_id'],
          date: formattedDate,
        ),
        LessonApiService.getProWorkSchedule(
          branchId: currentBranchId,
          proId: selectedStaff!['pro_id'],
          date: formattedDate,
        ),
      ]);

      setState(() {
        lessonData = results[0] as List<Map<String, dynamic>>;
        workSchedule = results[1] as Map<String, dynamic>?;
        isLoadingLessons = false;
      });

      if (lessonData.isEmpty) {
        print('ℹ️ ${selectedStaff!['pro_name']} 프로의 $formattedDate 레슨이 없습니다.');
      } else {
        print('✅ ${lessonData.length}개의 레슨을 불러왔습니다.');
      }

      if (workSchedule != null) {
        print('✅ 근무시간: ${workSchedule!['work_start']} ~ ${workSchedule!['work_end']}');
      }
    } catch (e) {
      setState(() {
        isLoadingLessons = false;
      });
      print('❌ 레슨 데이터 로드 오류: $e');
    }
  }
  
  // 10일간의 모든 날짜별 레슨 횟수 미리 로드
  Future<void> _loadLessonCountsForDates() async {
    if (selectedStaff == null) return;
    
    try {
      final currentBranchId = ApiService.getCurrentBranchId();
      if (currentBranchId == null) return;
      
      Map<String, Map<String, int>> newLessonCounts = {};
      
      // 10일간 각 날짜별로 레슨 횟수 조회 (레슨완료/결제완료)
      for (DateTime date in weekDates) {
        final formattedDate = DateFormat('yyyy-MM-dd').format(date);
        final result = await LessonApiService.getLessonsByProAndDate(
          branchId: currentBranchId,
          proId: selectedStaff!['pro_id'],
          date: formattedDate,
        );
        
        // 결제완료 레슨들 필터링
        final paymentCompletedLessons = result.where((lesson) => lesson['LS_status'] == '결제완료').toList();
        
        // 그 중에서 일반레슨 상태인 것들 카운트
        final lessonCompletedCount = paymentCompletedLessons.where((lesson) => lesson['LS_confirm'] == '일반레슨').length;
        
        newLessonCounts[formattedDate] = {
          'completed': lessonCompletedCount,
          'total': paymentCompletedLessons.length,
        };
      }
      
      setState(() {
        lessonCountByDate = newLessonCounts;
      });
    } catch (e) {
      print('❌ 레슨 카운트 로드 오류: $e');
    }
  }
  
  // 프로 필터링 (재직/퇴직 포함 옵션)
  List<Map<String, dynamic>> get filteredStaffList {
    if (includeRetiredStaff) {
      return staffList;
    } else {
      return staffList.where((staff) => staff['staff_status'] == '재직').toList();
    }
  }
  
  // 프로 태그 리스트 생성
  List<String> get proTagList {
    return filteredStaffList.map((staff) {
      String name = staff['pro_name'] ?? '';
      String status = staff['staff_status'] ?? '';
      return status == '퇴직' ? '$name(퇴직)' : name;
    }).toList();
  }
  
  // 탭 선택 처리
  void _onProTabChanged() {
    if (_proTabController == null || !_proTabController!.indexIsChanging) return;

    final selectedIndex = _proTabController!.index;
    if (selectedIndex >= 0 && selectedIndex < filteredStaffList.length) {
      setState(() {
        selectedStaff = filteredStaffList[selectedIndex];
        if (selectedStaff != null && selectedStaff!.isNotEmpty) {
          _loadLessonData();
          _loadLessonCountsForDates();
        }
      });
    }
  }
  
  // 10일 날짜 리스트 생성
  List<DateTime> get weekDates {
    List<DateTime> dates = [];
    for (int i = 0; i < 10; i++) {
      dates.add(currentWeekStart.add(Duration(days: i)));
    }
    return dates;
  }
  
  // 이전 10일로 이동
  void _goToPreviousWeek() {
    setState(() {
      currentWeekStart = currentWeekStart.subtract(Duration(days: 10));
    });
    if (selectedStaff != null) {
      _loadLessonCountsForDates();
    }
  }
  
  // 다음 10일로 이동
  void _goToNextWeek() {
    setState(() {
      currentWeekStart = currentWeekStart.add(Duration(days: 10));
    });
    if (selectedStaff != null) {
      _loadLessonCountsForDates();
    }
  }
  
  // 날짜 선택
  void _selectDate(DateTime date) {
    setState(() {
      selectedDate = date;
    });
    if (selectedStaff != null) {
      _loadLessonData();
    }
  }
  
  // 달력 다이얼로그 표시
  Future<void> _showDatePicker() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('ko', 'KR'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Color(0xFF14B8A6),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
        // 선택된 날짜를 기준으로 currentWeekStart도 조정
        currentWeekStart = DateTime(picked.year, picked.month, picked.day);
      });
      
      if (selectedStaff != null) {
        _loadLessonData();
        _loadLessonCountsForDates();
      }
    }
  }
  
  // 요일 한글 변환
  String _getKoreanDayOfWeek(DateTime date) {
    const days = ['월', '화', '수', '목', '금', '토', '일'];
    return days[date.weekday - 1];
  }
  
  // 요일별 색상 반환
  Color _getDayOfWeekColor(DateTime date) {
    switch (date.weekday) {
      case 6: // 토요일
        return Color(0xFF2563EB); // 파란색
      case 7: // 일요일
        return Color(0xFFDC2626); // 빨간색
      default: // 평일
        return Color(0xFF64748B); // 기본 회색
    }
  }
  
  // LS_confirm 상태별 색상 반환
  Color _getConfirmColor(String? confirm) {
    switch (confirm) {
      case '일반레슨':
        return Color(0xFF10B981); // 녹색
      case '고객증정레슨':
        return Color(0xFF8B5CF6); // 보라색
      case '신규체험레슨':
        return Color(0xFF06B6D4); // 청록색
      case '노쇼':
        return Color(0xFFF59E0B); // 주황색
      case '예약취소(환불)':
      case '환불':
        return Color(0xFFEF4444); // 빨간색
      case '미확인':
        return Color(0xFF94A3B8); // 연한 회색
      default:
        return Color(0xFF94A3B8); // 연한 회색
    }
  }
  
  // LS_confirm 상태별 그라데이션 색상 반환
  List<Color> _getConfirmGradientColors(String? confirm) {
    switch (confirm) {
      case '일반레슨':
        return [Color(0xFF14B8A6), Color(0xFF0D9488)]; // 녹색
      case '고객증정레슨':
        return [Color(0xFF8B5CF6), Color(0xFF7C3AED)]; // 보라색
      case '신규체험레슨':
        return [Color(0xFF06B6D4), Color(0xFF0891B2)]; // 청록색
      case '노쇼':
        return [Color(0xFFF59E0B), Color(0xFFD97706)]; // 주황색
      case '예약취소(환불)':
      case '환불':
        return [Color(0xFFEF4444), Color(0xFFDC2626)]; // 빨간색
      case '미확인':
        return [Color(0xFF6B7280), Color(0xFF4B5563)]; // 회색
      default:
        return [Color(0xFF6B7280), Color(0xFF4B5563)]; // 회색
    }
  }
  
  // LS_status 상태별 색상 반환
  Color _getStatusColor(String? status) {
    switch (status) {
      case '결제완료':
        return Color(0xFF10B981); // 녹색
      case '예약완료':
        return Color(0xFF3B82F6); // 파란색
      case '체크인전':
        return Color(0xFFF59E0B); // 주황색
      default:
        return Color(0xFF6B7280); // 회색
    }
  }
  
  // LS_status 상태별 배경색 반환
  Color _getStatusBgColor(String? status) {
    switch (status) {
      case '결제완료':
        return Color(0xFF10B981).withOpacity(0.1); // 녹색
      case '예약완료':
        return Color(0xFF3B82F6).withOpacity(0.1); // 파란색
      case '체크인전':
        return Color(0xFFF59E0B).withOpacity(0.1); // 주황색
      default:
        return Color(0xFF6B7280).withOpacity(0.1); // 회색
    }
  }
  
  // 피드백 다이얼로그 열기
  void _openFeedbackDialog(DateTime date) {
    if (selectedStaff == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('프로를 먼저 선택해주세요.')),
      );
      return;
    }
    
    String dateStr = DateFormat('yyyy-MM-dd').format(date);
    List<Map<String, dynamic>> dayLessons = lessonData.where((lesson) => 
      lesson['LS_date'] == dateStr
    ).toList();
    
    if (dayLessons.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('해당 날짜에 레슨이 없습니다.')),
      );
      return;
    }
    
    // 첫 번째 레슨에 대한 피드백 다이얼로그 열기
    showDialog(
      context: context,
      builder: (context) => LessonFeedbackDialog(
        lesson: dayLessons.first,
        onSaved: () {
          _loadLessonData();
          _loadLessonCountsForDates();
        },
      ),
    );
  }
  
  // 회원 관심분야 섹션
  Widget _buildMemberInterestSection(Map<String, dynamic> lesson) {
    String content = lesson['LS_request'] != null && lesson['LS_request'].toString().isNotEmpty 
      ? lesson['LS_request'].toString().replaceAll('집중 분야:', '') 
      : '';
    
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Color(0xFF6B7280).withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Color(0xFF6B7280).withOpacity(0.2), width: 1),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 헤더
              Text(
                '💡 회원 관심분야',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6B7280),
                ),
              ),
              if (content.isNotEmpty) ...[
                SizedBox(height: 6),
                Text(
                  content,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4B5563),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ] else ...[
                SizedBox(height: 6),
                Text(
                  '미입력',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF9CA3AF),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
          // 결제완료 배지 (우측상단)
          if (lesson['LS_status'] != null && lesson['LS_status'].toString().isNotEmpty)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: _getStatusBgColor(lesson['LS_status']),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _getStatusColor(lesson['LS_status']).withOpacity(0.3), width: 1),
                ),
                child: Text(
                  lesson['LS_status'],
                  style: TextStyle(
                    fontSize: 11,
                    color: _getStatusColor(lesson['LS_status']),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // 프로 피드백 통합 섹션
  Widget _buildProFeedbackSection(Map<String, dynamic> lesson) {
    List<Widget> feedbackItems = [];
    
    // 입력된 항목들만 수집
    if (lesson['LS_feedback_good'] != null && lesson['LS_feedback_good'].toString().isNotEmpty) {
      feedbackItems.add(_buildSubFeedbackRow('잘하고 있는 점', lesson['LS_feedback_good']));
    }
    if (lesson['LS_feedback_homework'] != null && lesson['LS_feedback_homework'].toString().isNotEmpty) {
      feedbackItems.add(_buildSubFeedbackRow('숙제', lesson['LS_feedback_homework']));
    }
    if (lesson['LS_feedback_nextlesson'] != null && lesson['LS_feedback_nextlesson'].toString().isNotEmpty) {
      feedbackItems.add(_buildSubFeedbackRow('다음 레슨 주안점', lesson['LS_feedback_nextlesson']));
    }
    
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Color(0xFF6B7280).withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Color(0xFF6B7280).withOpacity(0.2), width: 1),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 헤더
              Text(
                '📝 프로 피드백',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6B7280),
                ),
              ),
              SizedBox(height: 6),
              
              // 하위 항목들 또는 미입력
              if (feedbackItems.isNotEmpty) ...[
                for (int i = 0; i < feedbackItems.length; i++) ...[
                  if (i > 0) SizedBox(height: 4),
                  feedbackItems[i],
                ],
              ] else ...[
                Text(
                  '미입력',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF9CA3AF),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
          // 레슨완료 배지 (우측상단) - 없으면 미확인 표시
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _getConfirmGradientColors(
                    lesson['LS_confirm'] != null && lesson['LS_confirm'].toString().isNotEmpty 
                      ? lesson['LS_confirm'] 
                      : '미확인'
                  ),
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _getConfirmColor(
                    lesson['LS_confirm'] != null && lesson['LS_confirm'].toString().isNotEmpty 
                      ? lesson['LS_confirm'] 
                      : '미확인'
                  ), 
                  width: 1
                ),
              ),
              child: Text(
                lesson['LS_confirm'] != null && lesson['LS_confirm'].toString().isNotEmpty 
                  ? lesson['LS_confirm'] 
                  : '미확인',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // 하위 피드백 행 빌드
  Widget _buildSubFeedbackRow(String title, dynamic content) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '• ',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF6B7280),
          ),
        ),
        Text(
          '$title: ',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF6B7280),
          ),
        ),
        Expanded(
          child: Text(
            content.toString(),
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFF4B5563),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
  
  // 피드백 아이템 빌드
  Widget _buildFeedbackItem(String title, String content, Color color, {bool isHeader = false}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: isHeader
        ? Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              SizedBox(height: 4),
              Text(
                content,
                style: TextStyle(
                  fontSize: 11,
                  color: content == '미입력' ? Color(0xFF9CA3AF) : Color(0xFF374151),
                  fontStyle: content == '미입력' ? FontStyle.italic : FontStyle.normal,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
    );
  }

  // 빈 시간 타일 위젯
  Widget _buildEmptyTimeSlot(Map<String, dynamic> tile) {
    String startTime = tile['start_time'];
    String endTime = tile['end_time'];
    int duration = tile['duration'];

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Color(0xFFE5E7EB),
          width: 1,
          style: BorderStyle.solid,
        ),
      ),
      child: Row(
        children: [
          // 시간 표시
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Color(0xFFE5E7EB).withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.schedule,
                  color: Color(0xFF9CA3AF),
                  size: 14,
                ),
                SizedBox(width: 6),
                Text(
                  '$startTime~$endTime',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 12),
          // 빈 시간 표시
          Expanded(
            child: Text(
              '빈 시간 (${duration}분)',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF9CA3AF),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          SizedBox(width: 12),
          // 스케줄 등록 버튼
          ElevatedButton.icon(
            onPressed: () => _showScheduleDialog(startTime, endTime),
            icon: Icon(Icons.add_circle_outline, size: 16),
            label: Text('스케줄 등록'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF14B8A6),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  // 스케줄 타일 위젯
  Widget _buildScheduleTile(Map<String, dynamic> schedule) {
    final startTime = schedule['LS_start_time']?.substring(0, 5) ?? '';
    final endTime = schedule['LS_end_time']?.substring(0, 5) ?? '';
    final content = schedule['LS_request'] ?? '';
    final statusText = schedule['LS_status'] ?? '';
    final isCancelled = statusText == '예약취소';
    final netMin = schedule['LS_net_min'] ?? 0;

    // 시간 배지 색상 (보라색 계열)
    List<Color> timeColors = isCancelled
      ? [Color(0xFF9CA3AF), Color(0xFF6B7280)]
      : [Color(0xFF8B5CF6), Color(0xFF7C3AED)];
    Color shadowColor = isCancelled ? Color(0xFF9CA3AF) : Color(0xFF8B5CF6);

    // 상태 색상
    Color statusColor = isCancelled ? Color(0xFF6B7280) : Color(0xFF8B5CF6);
    Color statusBgColor = isCancelled
      ? Color(0xFF6B7280).withOpacity(0.1)
      : Color(0xFF8B5CF6).withOpacity(0.1);

    return GestureDetector(
      child: Opacity(
        opacity: isCancelled ? 0.6 : 1.0,
        child: Container(
          margin: EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Color(0xFF000000).withOpacity(0.05),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 시간 배지 (왼쪽 상단)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: timeColors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: shadowColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.access_time, color: Colors.white, size: 14),
                          SizedBox(width: 6),
                          Text(
                            '$startTime~$endTime ($netMin분)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 메인 콘텐츠
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 40), // 시간 배지 공간 확보

                        // 스케줄 배지 + 상태
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusBgColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.event_note, size: 12, color: statusColor),
                                  SizedBox(width: 4),
                                  Text(
                                    '스케줄',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: statusColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 8),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusBgColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                statusText,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: statusColor,
                                ),
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 12),

                        // 내용
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: statusColor.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            content,
                            style: TextStyle(
                              fontSize: 14,
                              color: isCancelled ? Color(0xFF9CA3AF) : Color(0xFF1F2937),
                              decoration: isCancelled ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        ),

                        // 취소 버튼
                        if (!isCancelled) ...[
                          SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => _cancelSchedule(schedule),
                              icon: Icon(Icons.close, size: 16),
                              label: Text('스케줄 취소'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Color(0xFFEF4444),
                                side: BorderSide(color: Color(0xFFEF4444)),
                                padding: EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 스케줄 취소
  Future<void> _cancelSchedule(Map<String, dynamic> schedule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('스케줄 취소'),
        content: Text('이 스케줄을 취소하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('아니오'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFEF4444),
            ),
            child: Text('예, 취소합니다', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final currentBranchId = ApiService.getCurrentBranchId();
      if (currentBranchId == null) {
        throw Exception('로그인 정보를 찾을 수 없습니다.');
      }

      final success = await LessonApiService.cancelSchedule(
        branchId: currentBranchId,
        lessonId: schedule['LS_id'],
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('스케줄이 취소되었습니다.'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        _loadLessonData();
        _loadLessonCountsForDates();
      } else {
        throw Exception('스케줄 취소에 실패했습니다.');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('오류가 발생했습니다: $e'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
    }
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
        backgroundColor: Color(0xFFF8FAFC),
        body: Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (responsiveVisibility(
              context: context,
              phone: false,
            ))
              wrapWithModel(
                model: _model.sideBarNavModel,
                updateCallback: () => safeSetState(() {}),
                child: SideBarNavWidget(
                  currentPage: 'crm4_lesson',
                  onNavigate: (String routeName) {
                    widget.onNavigate?.call(routeName);
                  },
                ),
              ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.max,
                children: [
                  if (responsiveVisibility(
                    context: context,
                    tabletLandscape: false,
                    desktop: false,
                  ))
                    Container(
                      width: double.infinity,
                      height: 44.0,
                      decoration: BoxDecoration(
                        color: Color(0xFFF8FAFC),
                      ),
                    ),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.max,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 프로 선택 탭바 (lesson_status가 '본인'이 아닐 때만 표시) - 컨테이너 밖으로
                        if ((ApiService.getCurrentAccessSettings()?['lesson_status'] ?? '전체') != '본인')
                          Padding(
                            padding: EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 8.0),
                            child: Row(
                              children: [
                                // 프로 탭바
                                Expanded(
                                  child: isLoadingStaff
                                    ? Container(
                                        height: 48.0,
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            color: Color(0xFF14B8A6),
                                            strokeWidth: 2.0,
                                          ),
                                        ),
                                      )
                                    : (_proTabController != null && filteredStaffList.isNotEmpty)
                                        ? TabDesignUpper.buildStyledTabBar(
                                            controller: _proTabController!,
                                            themeNumber: 3,
                                            size: 'large',
                                            tabs: proTagList.map((name) =>
                                              TabDesignUpper.buildTabItem(Icons.person, name, size: 'large')
                                            ).toList(),
                                          )
                                        : Container(
                                            height: 48.0,
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              '프로를 선택할 수 없습니다.',
                                              style: TextStyle(
                                                fontFamily: 'Pretendard',
                                                color: Color(0xFF64748B),
                                                fontSize: 14.0,
                                              ),
                                            ),
                                          ),
                                ),

                                // 퇴직 프로 포함 토글 (오른쪽에 배치)
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Switch(
                                        value: includeRetiredStaff,
                                        onChanged: (value) {
                                          setState(() {
                                            includeRetiredStaff = value;
                                            selectedStaff = null;

                                            // TabController 재초기화
                                            if (filteredStaffList.isNotEmpty) {
                                              _proTabController?.dispose();
                                              _proTabController = TabController(
                                                length: filteredStaffList.length,
                                                vsync: this,
                                              );
                                              _proTabController!.addListener(_onProTabChanged);
                                            }
                                          });
                                        },
                                        activeColor: Color(0xFF14B8A6),
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      Text(
                                        '퇴직 프로 포함',
                                        style: TextStyle(
                                          fontFamily: 'Pretendard',
                                          color: Color(0xFF64748B),
                                          fontSize: 14.0,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // 메인 컨텐츠 영역 - 헤더 + 날짜 선택 + 레슨 그리드를 하나의 컨테이너로
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(24.0, 8.0, 24.0, 24.0),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12.0),
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0xFF000000).withOpacity(0.05),
                                    blurRadius: 10,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  // 헤더 섹션
                                  Container(
                                    width: double.infinity,
                                    padding: EdgeInsets.all(16.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        // 왼쪽: 레슨비 정산 버튼 + 툴팁 (권한 있을 때만)
                                        if (_canViewLessonFee())
                                          Row(
                                            children: [
                                              // 레슨비 정산 버튼
                                              ButtonDesignUpper.buildIconButton(
                                                text: '레슨비 정산',
                                                icon: Icons.calculate_outlined,
                                                onPressed: selectedStaff != null ? () {
                                                  _showLessonFeeSettlementDialog();
                                                } : () {},
                                                color: 'orange',
                                                size: 'large',
                                              ),
                                              SizedBox(width: 12.0),
                                              // 툴팁
                                              ButtonDesignUpper.buildHelpTooltip(
                                                message: '레슨확인 결과는 프로계약내역에 따라 급여정산과 연계됩니다',
                                                iconSize: 20.0,
                                              ),
                                            ],
                                          )
                                        else
                                          SizedBox.shrink(),
                                        // 오른쪽: 새로고침 버튼
                                        ButtonDesignUpper.buildIconButton(
                                          text: '새로고침',
                                          icon: Icons.refresh,
                                          onPressed: () {
                                            _loadStaffList();
                                            if (selectedStaff != null) {
                                              _loadLessonData();
                                              _loadLessonCountsForDates();
                                            }
                                          },
                                          color: 'cyan',
                                          size: 'large',
                                        ),
                                      ],
                                    ),
                                  ),

                                  // 날짜 선택 영역
                                  if (selectedStaff != null) ...[
                                    Container(
                                      width: double.infinity,
                                      padding: EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 16.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // 왼쪽: 년월 표시와 화살표 버튼
                                    Column(
                                      children: [
                                        Container(
                                          padding: EdgeInsets.symmetric(vertical: 8.0),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              // 이전 기간 버튼
                                              Container(
                                                width: 36,
                                                height: 36,
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  border: Border.all(color: Color(0xFFE2E8F0)),
                                                  borderRadius: BorderRadius.circular(6.0),
                                                ),
                                                child: IconButton(
                                                  onPressed: _goToPreviousWeek,
                                                  icon: Icon(Icons.chevron_left, color: Color(0xFF6B7280), size: 18),
                                                  padding: EdgeInsets.zero,
                                                ),
                                              ),
                                              
                                              SizedBox(width: 12.0),
                                              
                                              // 현재 조회중인 날짜 표시 (클릭 가능)
                                              GestureDetector(
                                                onTap: _showDatePicker,
                                                child: Container(
                                                  padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    border: Border.all(color: Color(0xFFE2E8F0)),
                                                    borderRadius: BorderRadius.circular(6.0),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        DateFormat('yyyy년 MM월 dd일').format(selectedDate),
                                                        style: TextStyle(
                                                          fontFamily: 'Pretendard',
                                                          color: Color(0xFF1E293B),
                                                          fontSize: 14.0,
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                      SizedBox(width: 8),
                                                      Icon(
                                                        Icons.calendar_today,
                                                        size: 16,
                                                        color: Color(0xFF6B7280),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              
                                              SizedBox(width: 12.0),
                                              
                                              // 다음 기간 버튼
                                              Container(
                                                width: 36,
                                                height: 36,
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  border: Border.all(color: Color(0xFFE2E8F0)),
                                                  borderRadius: BorderRadius.circular(6.0),
                                                ),
                                                child: IconButton(
                                                  onPressed: _goToNextWeek,
                                                  icon: Icon(Icons.chevron_right, color: Color(0xFF6B7280), size: 18),
                                                  padding: EdgeInsets.zero,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    
                                    SizedBox(width: 24.0),
                                    
                                    // 오른쪽: 10일 날짜 버튼들
                                    Expanded(
                                      child: Wrap(
                                        spacing: 4.0,
                                        runSpacing: 4.0,
                                        children: weekDates.map((date) {
                                          bool isSelected = DateFormat('yyyy-MM-dd').format(date) == 
                                                           DateFormat('yyyy-MM-dd').format(selectedDate);
                                          bool isToday = DateFormat('yyyy-MM-dd').format(date) == 
                                                        DateFormat('yyyy-MM-dd').format(DateTime.now());
                                          String lessonCount = _getLessonCountForDate(date);
                                          
                                          return GestureDetector(
                                            onTap: () => _selectDate(date),
                                            onDoubleTap: () => _openFeedbackDialog(date),
                                            child: Container(
                                              width: 60,
                                              height: 50,
                                              decoration: BoxDecoration(
                                                color: isSelected 
                                                  ? Color(0xFF6366F1) 
                                                  : (isToday ? Color(0xFFE0F2FE) : Colors.white),
                                                border: Border.all(
                                                  color: isSelected 
                                                    ? Color(0xFF6366F1) 
                                                    : (isToday ? Color(0xFF0EA5E9) : Color(0xFFE2E8F0)),
                                                  width: 1.0,
                                                ),
                                                borderRadius: BorderRadius.circular(6.0),
                                              ),
                                              child: Stack(
                                                children: [
                                                  // 날짜와 요일 (좌우 배치)
                                                  Center(
                                                    child: Column(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        // 날짜와 요일을 한 줄로
                                                        Row(
                                                          mainAxisAlignment: MainAxisAlignment.center,
                                                          children: [
                                                            Text(
                                                              '${date.month}/${date.day}',
                                                              style: TextStyle(
                                                                fontFamily: 'Pretendard',
                                                                color: isSelected 
                                                                  ? Colors.white 
                                                                  : (isToday ? Color(0xFF0369A1) : Color(0xFF1E293B)),
                                                                fontSize: 12.0,
                                                                fontWeight: FontWeight.w600,
                                                              ),
                                                            ),
                                                            SizedBox(width: 3.0),
                                                            Text(
                                                              _getKoreanDayOfWeek(date),
                                                              style: TextStyle(
                                                                fontFamily: 'Pretendard',
                                                                color: isSelected 
                                                                  ? Colors.white.withOpacity(0.8) 
                                                                  : (isToday 
                                                                    ? Color(0xFF0369A1) 
                                                                    : _getDayOfWeekColor(date)),
                                                                fontSize: 10.0,
                                                                fontWeight: FontWeight.w700,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        SizedBox(height: 4.0),
                                                        // 분수 표시 (요일 위치) - 배지 스타일
                                                        if (lessonCount != '0/0')
                                                          Container(
                                                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                            decoration: BoxDecoration(
                                                              color: isSelected 
                                                                ? Colors.white.withOpacity(0.2)
                                                                : Color(0xFF10B981),
                                                              borderRadius: BorderRadius.circular(8),
                                                              border: Border.all(
                                                                color: isSelected 
                                                                  ? Colors.white.withOpacity(0.3)
                                                                  : Colors.white.withOpacity(0.2),
                                                                width: 0.5,
                                                              ),
                                                            ),
                                                            child: Text(
                                                              '완료:$lessonCount',
                                                              style: TextStyle(
                                                                fontFamily: 'Pretendard',
                                                                color: isSelected 
                                                                  ? Colors.white
                                                                  : Colors.white,
                                                                fontSize: 10.0,
                                                                fontWeight: FontWeight.w700,
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
                                        }).toList(),
                                      ),
                                    ),
                                    
                                    SizedBox(width: 16.0),
                                    
                                    // 전체 레슨 보기 토글
                                    Container(
                                      padding: EdgeInsets.symmetric(vertical: 8.0),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Switch(
                                            value: showAllLessons,
                                            onChanged: (value) {
                                              setState(() {
                                                showAllLessons = value;
                                              });
                                            },
                                            activeColor: Color(0xFF14B8A6),
                                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            '전체 레슨 보기',
                                            style: TextStyle(
                                              fontFamily: 'Pretendard',
                                              color: Color(0xFF64748B),
                                              fontSize: 14.0,
                                              fontWeight: FontWeight.w400,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                                  ],

                                  // 레슨 현황 섹션
                                  Expanded(
                                    child: Padding(
                                      padding: EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 16.0),
                                      child: selectedStaff == null
                                        ? Center(
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Container(
                                                  padding: EdgeInsets.all(24),
                                                  decoration: BoxDecoration(
                                                    color: Color(0xFF14B8A6).withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(20),
                                                  ),
                                                  child: Icon(
                                                    Icons.school,
                                                    size: 64,
                                                    color: Color(0xFF14B8A6),
                                                  ),
                                                ),
                                                SizedBox(height: 24),
                                                Text(
                                                  '프로를 선택해주세요',
                                                  style: TextStyle(
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF1F2937),
                                                  ),
                                                ),
                                                SizedBox(height: 8),
                                                Text(
                                                  '위의 프로 태그를 선택하면 해당 날짜의 레슨 현황을 확인할 수 있습니다',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    color: Color(0xFF6B7280),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                        : Container(
                                            height: double.infinity,
                                            decoration: BoxDecoration(
                                              color: Color(0xFFF8FAFC),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Column(
                                              children: [
                                                // 레슨 리스트
                                                Expanded(
                                                  child: isLoadingLessons
                                                    ? Center(
                                                        child: CircularProgressIndicator(
                                                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF14B8A6)),
                                                        ),
                                                      )
                                                    : timeSlotTiles.isEmpty
                                                      ? Center(
                                                          child: Column(
                                                            mainAxisAlignment: MainAxisAlignment.center,
                                                            children: [
                                                              Container(
                                                                padding: EdgeInsets.all(24),
                                                                decoration: BoxDecoration(
                                                                  color: Color(0xFF6B7280).withOpacity(0.1),
                                                                  borderRadius: BorderRadius.circular(20),
                                                                ),
                                                                child: Icon(
                                                                  Icons.event_busy,
                                                                  size: 48,
                                                                  color: Color(0xFF6B7280),
                                                                ),
                                                              ),
                                                              SizedBox(height: 16),
                                                              Text(
                                                                workSchedule?['is_day_off'] == '휴무'
                                                                  ? '휴무일입니다'
                                                                  : '근무 스케줄이 없습니다',
                                                                style: TextStyle(
                                                                  fontSize: 18,
                                                                  fontWeight: FontWeight.bold,
                                                                  color: Color(0xFF1F2937),
                                                                ),
                                                              ),
                                                              SizedBox(height: 8),
                                                              Text(
                                                                '다른 날짜를 선택해보세요',
                                                                style: TextStyle(
                                                                  fontSize: 14,
                                                                  color: Color(0xFF6B7280),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        )
                                                      : ListView.builder(
                                                          padding: EdgeInsets.all(16),
                                                          itemCount: timeSlotTiles.length,
                                                          itemBuilder: (context, index) {
                                                            final tile = timeSlotTiles[index];

                                                      // 빈 시간 타일
                                                      if (tile['type'] == 'empty') {
                                                        return _buildEmptyTimeSlot(tile);
                                                      }

                                                      // 레슨 타일
                                                      final lesson = tile['data'];
                                                      final isSchedule = lesson['LS_transaction_type'] == '스케줄등록';

                                                      // 스케줄 타일인 경우
                                                      if (isSchedule) {
                                                        return _buildScheduleTile(lesson);
                                                      }

                                                      // 일반 레슨 타일
                                                      final startTime = lesson['LS_start_time']?.substring(0, 5) ?? '';
                                                      final endTime = lesson['LS_end_time']?.substring(0, 5) ?? '';

                                                      // LS_status 색상
                                                      Color statusColor;
                                                      Color statusBgColor;
                                                      String statusText = lesson['LS_status'] ?? '';

                                                      switch (statusText) {
                                                        case '결제완료':
                                                          statusColor = Color(0xFF10B981);
                                                          statusBgColor = Color(0xFF10B981).withOpacity(0.1);
                                                          break;
                                                        case '예약완료':
                                                          statusColor = Color(0xFF3B82F6);
                                                          statusBgColor = Color(0xFF3B82F6).withOpacity(0.1);
                                                          break;
                                                        case '체크인전':
                                                          statusColor = Color(0xFFF59E0B);
                                                          statusBgColor = Color(0xFFF59E0B).withOpacity(0.1);
                                                          break;
                                                        default:
                                                          statusColor = Color(0xFF6B7280);
                                                          statusBgColor = Color(0xFF6B7280).withOpacity(0.1);
                                                      }
                                                      
                                                      // LS_confirm 상태에 따른 시간 배지 색상
                                                      List<Color> timeColors;
                                                      Color shadowColor;
                                                      String confirmStatus = lesson['LS_confirm'] ?? '';
                                                      
                                                      // 디버깅: confirmStatus 값 확인
                                                      if (kDebugMode) {
                                                        print('🔍 confirmStatus: "$confirmStatus"');
                                                      }
                                                      
                                                      switch (confirmStatus) {
                                                        case '일반레슨':
                                                          timeColors = [Color(0xFF14B8A6), Color(0xFF0D9488)]; // 초록
                                                          shadowColor = Color(0xFF14B8A6);
                                                          break;
                                                        case '고객증정레슨':
                                                          timeColors = [Color(0xFF8B5CF6), Color(0xFF7C3AED)]; // 보라
                                                          shadowColor = Color(0xFF8B5CF6);
                                                          break;
                                                        case '신규체험레슨':
                                                          timeColors = [Color(0xFF06B6D4), Color(0xFF0891B2)]; // 청록
                                                          shadowColor = Color(0xFF06B6D4);
                                                          break;
                                                        case '노쇼':
                                                          timeColors = [Color(0xFFF59E0B), Color(0xFFD97706)]; // 노랑
                                                          shadowColor = Color(0xFFF59E0B);
                                                          break;
                                                        case '예약취소(환불)':
                                                        case '환불':
                                                          timeColors = [Color(0xFFEF4444), Color(0xFFDC2626)]; // 빨강
                                                          shadowColor = Color(0xFFEF4444);
                                                          break;
                                                        default: // 미확인
                                                          timeColors = [Color(0xFF6B7280), Color(0xFF4B5563)]; // 회색
                                                          shadowColor = Color(0xFF6B7280);
                                                      }
                                                      
                                                      return GestureDetector(
                                                        onTap: (statusText == '결제완료' || statusText == '예약완료') ? () {
                                                          showDialog(
                                                            context: context,
                                                            builder: (context) => LessonFeedbackDialog(
                                                              lesson: lesson,
                                                              onSaved: () {
                                                                _loadLessonData();
                                                                _loadLessonCountsForDates();
                                                              },
                                                            ),
                                                          );
                                                        } : null,
                                                        child: Opacity(
                                                          opacity: (statusText == '결제완료' || statusText == '예약완료') ? 1.0 : 0.6,
                                                          child: Container(
                                                            margin: EdgeInsets.only(bottom: 12),
                                                          decoration: BoxDecoration(
                                                            color: Colors.white,
                                                            borderRadius: BorderRadius.circular(12),
                                                            border: Border.all(
                                                              color: Color(0xFFE5E7EB),
                                                              width: 1,
                                                            ),
                                                            boxShadow: [
                                                              BoxShadow(
                                                                color: Color(0xFF000000).withOpacity(0.02),
                                                                blurRadius: 4,
                                                                offset: Offset(0, 2),
                                                              ),
                                                            ],
                                                          ),
                                                        child: Stack(
                                                          children: [
                                                            // 시간 배지 (좌측 상단 고정)
                                                            Positioned(
                                                              top: 0,
                                                              left: 0,
                                                              child: Container(
                                                                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                                decoration: BoxDecoration(
                                                                  gradient: LinearGradient(
                                                                    colors: timeColors,
                                                                    begin: Alignment.topLeft,
                                                                    end: Alignment.bottomRight,
                                                                  ),
                                                                  borderRadius: BorderRadius.only(
                                                                    topLeft: Radius.circular(11),
                                                                    bottomRight: Radius.circular(8),
                                                                  ),
                                                                  boxShadow: [
                                                                    BoxShadow(
                                                                      color: shadowColor.withOpacity(0.3),
                                                                      blurRadius: 4,
                                                                      offset: Offset(0, 2),
                                                                    ),
                                                                  ],
                                                                ),
                                                                child: Row(
                                                                  mainAxisSize: MainAxisSize.min,
                                                                  children: [
                                                                    Icon(
                                                                      Icons.access_time,
                                                                      color: Colors.white,
                                                                      size: 14,
                                                                    ),
                                                                    SizedBox(width: 4),
                                                                    Text(
                                                                      '$startTime~$endTime (${lesson['LS_net_min'] ?? 0}분)',
                                                                      style: TextStyle(
                                                                        fontSize: 12,
                                                                        fontWeight: FontWeight.bold,
                                                                        color: Colors.white,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                                                            
                                                            // 회원명과 유형 (시간 배지 오른쪽)
                                                            Positioned(
                                                              top: 8,
                                                              left: 180,
                                                              child: Row(
                                                                children: [
                                                                  // 회원명
                                                                  Text(
                                                                    lesson['member_name'] ?? '미정',
                                                                    style: TextStyle(
                                                                      fontSize: 16,
                                                                      fontWeight: FontWeight.w700,
                                                                      color: Color(0xFF1F2937),
                                                                    ),
                                                                  ),
                                                                  SizedBox(width: 10),
                                                                  // 유형
                                                                  if (lesson['LS_type'] != null) ...[
                                                                    Container(
                                                                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                                      decoration: BoxDecoration(
                                                                        color: Color(0xFF6366F1).withOpacity(0.1),
                                                                        borderRadius: BorderRadius.circular(4),
                                                                      ),
                                                                      child: Text(
                                                                        lesson['LS_type'] ?? '',
                                                                        style: TextStyle(
                                                                          fontSize: 11,
                                                                          fontWeight: FontWeight.w600,
                                                                          color: Color(0xFF6366F1),
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ],
                                                              ),
                                                            ),
                                                            
                                                            // 메인 콘텐츠
                                                            Padding(
                                                              padding: EdgeInsets.all(16),
                                                              child: Column(
                                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                                children: [
                                                                  SizedBox(height: 20), // 시간 배지와 회원명 공간 확보
                                                                    // 회원 관심분야와 프로 피드백 (좌우 배치)
                                                                    SizedBox(height: 8),
                                                                    IntrinsicHeight(
                                                                      child: Row(
                                                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                                                        children: [
                                                                          Expanded(
                                                                            child: _buildMemberInterestSection(lesson),
                                                                          ),
                                                                          SizedBox(width: 8),
                                                                          Expanded(
                                                                            child: _buildProFeedbackSection(lesson),
                                                                          ),
                                                                        ],
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ],
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
                            ),

                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
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

  // 레슨비 정산 다이얼로그 표시
  void _showLessonFeeSettlementDialog() {
    showLessonFeeSettlementDialog(
      context,
      selectedStaff?['pro_id'],
      selectedStaff?['pro_name'] ?? '',
    );
  }

  // 스케줄 등록 다이얼로그 표시
  void _showScheduleDialog(String minStartTime, String maxEndTime) {
    showDialog(
      context: context,
      builder: (context) => _ScheduleRegistrationDialog(
        minStartTime: minStartTime,
        maxEndTime: maxEndTime,
        selectedDate: selectedDate,
        selectedStaff: selectedStaff,
        onSaved: () {
          _loadLessonData();
          _loadLessonCountsForDates();
        },
      ),
    );
  }
}

// 스케줄 등록 다이얼로그 위젯
class _ScheduleRegistrationDialog extends StatefulWidget {
  final String minStartTime;
  final String maxEndTime;
  final DateTime selectedDate;
  final Map<String, dynamic>? selectedStaff;
  final VoidCallback onSaved;

  const _ScheduleRegistrationDialog({
    required this.minStartTime,
    required this.maxEndTime,
    required this.selectedDate,
    required this.selectedStaff,
    required this.onSaved,
  });

  @override
  State<_ScheduleRegistrationDialog> createState() => _ScheduleRegistrationDialogState();
}

class _ScheduleRegistrationDialogState extends State<_ScheduleRegistrationDialog> {
  late TimeOfDay startTime;
  late TimeOfDay endTime;
  final TextEditingController contentController = TextEditingController();
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    // 기본값 설정 (빈 시간의 시작/종료) - 5분 단위로 반올림
    TimeOfDay rawStartTime = _parseTimeOfDay(widget.minStartTime);
    TimeOfDay rawEndTime = _parseTimeOfDay(widget.maxEndTime);

    // 5분 단위로 반올림
    int startMinute = (rawStartTime.minute / 5).round() * 5;
    if (startMinute == 60) startMinute = 0;
    int endMinute = (rawEndTime.minute / 5).round() * 5;
    if (endMinute == 60) endMinute = 0;

    startTime = TimeOfDay(hour: rawStartTime.hour, minute: startMinute);
    endTime = TimeOfDay(hour: rawEndTime.hour, minute: endMinute);
  }

  @override
  void dispose() {
    contentController.dispose();
    super.dispose();
  }

  // HH:mm 문자열을 TimeOfDay로 변환
  TimeOfDay _parseTimeOfDay(String timeStr) {
    List<String> parts = timeStr.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  // TimeOfDay를 HH:mm 문자열로 변환
  String _formatTimeOfDay(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  // 시간 선택
  Future<void> _selectTime(BuildContext context, bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStart ? startTime : endTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.light(
                primary: Color(0xFF14B8A6),
                onPrimary: Colors.white,
                surface: Colors.white,
                onSurface: Colors.black,
              ),
            ),
            child: child!,
          ),
        );
      },
    );

    if (picked != null) {
      // 5분 단위로 반올림
      int roundedMinute = (picked.minute / 5).round() * 5;
      if (roundedMinute == 60) {
        roundedMinute = 0;
      }
      TimeOfDay roundedTime = TimeOfDay(hour: picked.hour, minute: roundedMinute);

      // 시간 범위 검증
      TimeOfDay minTime = _parseTimeOfDay(widget.minStartTime);
      TimeOfDay maxTime = _parseTimeOfDay(widget.maxEndTime);

      int pickedMinutes = roundedTime.hour * 60 + roundedTime.minute;
      int minMinutes = minTime.hour * 60 + minTime.minute;
      int maxMinutes = maxTime.hour * 60 + maxTime.minute;

      if (pickedMinutes < minMinutes || pickedMinutes > maxMinutes) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.minStartTime} ~ ${widget.maxEndTime} 범위 내에서 선택해주세요.'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
        return;
      }

      setState(() {
        if (isStart) {
          startTime = roundedTime;
          // 시작 시간이 종료 시간보다 늦으면 종료 시간도 조정
          int startMinutes = startTime.hour * 60 + startTime.minute;
          int endMinutes = endTime.hour * 60 + endTime.minute;
          if (startMinutes >= endMinutes) {
            // 최소 30분 간격으로 설정
            int newEndMinutes = startMinutes + 30;
            int newEndHour = newEndMinutes ~/ 60;
            int newEndMinute = newEndMinutes % 60;
            endTime = TimeOfDay(hour: newEndHour, minute: newEndMinute);

            // 최대 시간을 넘지 않도록 조정
            int endTotalMinutes = endTime.hour * 60 + endTime.minute;
            if (endTotalMinutes > maxMinutes) {
              endTime = maxTime;
            }
          }
        } else {
          endTime = roundedTime;
        }
      });
    }
  }

  // 저장
  Future<void> _save() async {
    if (contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('내용을 입력해주세요.')),
      );
      return;
    }

    // 시작 시간이 종료 시간보다 늦은지 확인
    int startMinutes = startTime.hour * 60 + startTime.minute;
    int endMinutes = endTime.hour * 60 + endTime.minute;
    if (startMinutes >= endMinutes) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('종료 시간은 시작 시간보다 늦어야 합니다.')),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // 현재 branch_id와 staff_access_id 가져오기
      final currentBranchId = ApiService.getCurrentBranchId();
      final currentUser = ApiService.getCurrentUser();

      if (currentBranchId == null || currentUser == null) {
        throw Exception('로그인 정보를 찾을 수 없습니다.');
      }

      if (widget.selectedStaff == null) {
        throw Exception('선택된 프로 정보를 찾을 수 없습니다.');
      }

      final staffAccessId = currentUser['staff_access_id'] ?? '';
      final proId = widget.selectedStaff!['pro_id'];
      final proName = widget.selectedStaff!['pro_name'] ?? '';
      final date = DateFormat('yyyy-MM-dd').format(widget.selectedDate);

      // API 호출
      final success = await LessonApiService.createSchedule(
        branchId: currentBranchId,
        date: date,
        proId: proId,
        proName: proName,
        staffAccessId: staffAccessId,
        startTime: _formatTimeOfDay(startTime),
        endTime: _formatTimeOfDay(endTime),
        content: contentController.text.trim(),
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('스케줄이 등록되었습니다.'),
            backgroundColor: Color(0xFF10B981),
          ),
        );

        widget.onSaved();
        Navigator.of(context).pop();
      } else {
        throw Exception('스케줄 등록에 실패했습니다.');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('오류가 발생했습니다: $e'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: 500,
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Color(0xFF14B8A6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.event_note,
                    color: Color(0xFF14B8A6),
                    size: 20,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '스케줄 등록',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      Text(
                        '빈 시간: ${widget.minStartTime} ~ ${widget.maxEndTime}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close, color: Color(0xFF6B7280)),
                ),
              ],
            ),

            SizedBox(height: 24),

            // 시간 선택
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '시작 시간',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      SizedBox(height: 8),
                      InkWell(
                        onTap: () => _selectTime(context, true),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Color(0xFFD1D5DB)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.access_time, color: Color(0xFF14B8A6), size: 20),
                              SizedBox(width: 8),
                              Text(
                                _formatTimeOfDay(startTime),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '종료 시간',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      SizedBox(height: 8),
                      InkWell(
                        onTap: () => _selectTime(context, false),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Color(0xFFD1D5DB)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.access_time, color: Color(0xFF14B8A6), size: 20),
                              SizedBox(width: 8),
                              Text(
                                _formatTimeOfDay(endTime),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1F2937),
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

            SizedBox(height: 16),

            // 내용 입력
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '내용',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                SizedBox(height: 8),
                TextField(
                  controller: contentController,
                  maxLines: 4,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: '스케줄 내용을 입력하세요',
                    hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Color(0xFFD1D5DB), width: 1),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Color(0xFF14B8A6), width: 2),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Color(0xFFD1D5DB), width: 1),
                    ),
                    contentPadding: EdgeInsets.all(12),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ],
            ),

            SizedBox(height: 24),

            // 버튼
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: isLoading ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: Color(0xFFE5E7EB)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      '취소',
                      style: TextStyle(
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF14B8A6),
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: isLoading
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            '저장',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
