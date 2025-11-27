import '/components/side_bar_nav/side_bar_nav_widget.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/services/api_service.dart';
import '/models/ts_reservation.dart';
import 'crm3_ts_widget.dart' show Crm3TsWidget;
import 'package:flutter/material.dart';
import '/components/side_bar_nav/side_bar_nav_model.dart';
import 'package:intl/intl.dart';

class Crm3TsModel extends FlutterFlowModel<Crm3TsWidget> with ChangeNotifier {
  ///  State fields for stateful widgets in this page.

  // Model for sideBarNav component.
  late SideBarNavModel sideBarNavModel;
  
  // State field(s) for TextField widget.
  FocusNode? textFieldFocusNode;
  TextEditingController? textController;
  String? Function(BuildContext, String?)? textControllerValidator;

  // 타석 예약 데이터 관련 상태
  List<TsReservation> reservations = [];
  List<int> availableTsBays = [];
  bool isLoading = false;
  String? errorMessage;
  DateTime selectedDate = DateTime.now();
  
  // 영업시간 데이터
  String? businessStart;
  String? businessEnd;
  bool isHoliday = false;

  @override
  void initState(BuildContext context) {
    sideBarNavModel = createModel(context, () => SideBarNavModel());
  }

  @override
  void dispose() {
    sideBarNavModel.dispose();
    textFieldFocusNode?.dispose();
    textController?.dispose();
  }

  // 타석 정보 로드
  Future<void> loadTsInfo() async {
    try {
      // print('타석 정보 로딩 시작');
      
      final tsInfoData = await ApiService.getTsInfoData(
        fields: ['ts_id'],
        orderBy: [
          {'field': 'ts_id', 'direction': 'ASC'},
        ],
      );
      
      // ts_id 중복 제거
      final Set<int> uniqueTsIds = {};
      for (var item in tsInfoData) {
        if (item['ts_id'] != null) {
          uniqueTsIds.add(int.parse(item['ts_id'].toString()));
        }
      }
      
      if (uniqueTsIds.isNotEmpty) {
        availableTsBays = uniqueTsIds.toList()..sort();
        // print('타석 정보 로딩 완료: ${availableTsBays.length}개 타석 - $availableTsBays');
      } else {
        // 데이터가 없으면 오류 발생
        throw Exception('타석 정보를 찾을 수 없습니다. v2_ts_info 테이블에 해당 지점의 타석 설정이 필요합니다.');
      }
      
    } catch (e) {
      // print('타석 정보 로딩 오류: $e');
      // 기본값 설정하지 않고 오류 재발생
      rethrow;
    }
  }

  // 영업시간 데이터 로드
  Future<void> loadBusinessHours() async {
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
      // print('영업시간 데이터 로딩 시작: $dateStr');
      
      final scheduleData = await ApiService.getScheduleAdjustedTsData(
        fields: ['ts_date', 'business_start', 'business_end', 'is_holiday'],
        where: [
          {
            'field': 'ts_date',
            'operator': '=',
            'value': dateStr,
          },
        ],
        limit: 1,
      );
      
      if (scheduleData.isNotEmpty) {
        final schedule = scheduleData.first;
        businessStart = schedule['business_start'];
        businessEnd = schedule['business_end'];
        isHoliday = schedule['is_holiday'] == 'close';
        
        // print('영업시간 로딩 완료: $businessStart ~ $businessEnd (휴일: $isHoliday)');
      } else {
        // 데이터가 없으면 오류 발생
        throw Exception('영업시간 정보를 찾을 수 없습니다. v2_schedule_adjusted_ts 테이블에 해당 날짜의 영업시간 설정이 필요합니다.');
      }
    } catch (e) {
      // print('영업시간 데이터 로딩 오류: $e');
      // 기본값 설정하지 않고 오류 재발생
      rethrow;
    }
  }

  // 필수 데이터 로드 (타석 정보 + 영업시간)
  Future<void> _loadRequiredData() async {
    // 타석 정보가 없으면 먼저 로드
    if (availableTsBays.isEmpty) {
      await loadTsInfo();
    }
    
    // 영업시간 정보 로드
    await loadBusinessHours();
  }

  // 예약 데이터 로드
  Future<void> _loadReservationData() async {
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
      // print('타석 예약 데이터 로딩 시작: $dateStr');
      
      final data = await ApiService.getTsData(
        fields: [
          'branch_id', 'reservation_id', 'ts_id', 'ts_date', 'ts_start', 'ts_end',
          'ts_status', 'member_id', 'member_name', 'member_type', 'member_phone',
          'total_amt', 'term_discount', 'coupon_discount', 'total_discount', 'net_amt',
          'discount_min', 'normal_min', 'extracharge_min', 'ts_min', 'bill_min',
          'bill_id', 'bill_min_id', 'bill_game_id', 'program_id', 'program_name',
          'ts_payment_method', 'day_of_week', 'time_stamp', 'memo'
        ],
        where: [
          {
            'field': 'ts_date',
            'operator': '=',
            'value': dateStr,
          },
          {
            'field': 'ts_status',
            'operator': '<>',
            'value': '예약취소',
          }
        ],
        orderBy: [
          {'field': 'ts_id', 'direction': 'ASC'},
          {'field': 'ts_start', 'direction': 'ASC'},
        ],
        limit: 200,
      );
      
      // print('타석 예약 데이터 로딩 완료: ${data.length}건');
      reservations = data.map((item) => TsReservation.fromJson(item)).toList();
      
    } catch (e) {
      print('예약 데이터 로딩 실패, 빈 시간표 표시: $e');
      reservations = [];
      // 예약 데이터 실패는 치명적이지 않음
    }
  }

  // 데이터 로드 - 안전한 API 호출
  Future<void> loadTsReservations() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    
    try {
      // 1단계: 필수 데이터 로드 (타석 정보 + 영업시간)
      await _loadRequiredData();
      
      // 2단계: 예약 데이터 로드 (실패해도 시간표 표시 가능)
      await _loadReservationData();
      
    } catch (e) {
      print('필수 데이터 로딩 오류 (치명적): $e');
      
      // 타석 정보나 영업시간 오류 - 치명적 오류
      errorMessage = e.toString();
      reservations = [];
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // 날짜 변경
  void changeDate(DateTime newDate) {
    selectedDate = newDate;
    loadTsReservations();
  }

  // 오늘로 이동
  void goToToday() {
    selectedDate = DateTime.now();
    loadTsReservations();
  }

  // 필터링된 예약 목록 반환
  List<TsReservation> getFilteredReservations() {
    return reservations;
  }

  // 총 타석 수 반환
  int get totalBays => availableTsBays.length;
  
  // 타석 번호 목록 반환
  List<int> get bayNumbers => availableTsBays;

  // 예약 데이터를 타석별로 그룹화
  Map<String, List<TsReservation>> getGroupedReservations() {
    final Map<String, List<TsReservation>> grouped = {};
    
    for (final reservation in reservations) {
      final tsId = reservation.tsId?.toString() ?? '';
      if (tsId.isNotEmpty) {
        if (!grouped.containsKey(tsId)) {
          grouped[tsId] = <TsReservation>[];
        }
        grouped[tsId]!.add(reservation);
      }
    }
    
    return grouped;
  }

}
