import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math; // min 함수 사용을 위해 추가
import 'package:provider/provider.dart';
import 'package:famd_clientapp/providers/user_provider.dart';
import 'package:famd_clientapp/services/api_service.dart';  // API 서비스 클래스 추가
import 'package:intl/intl.dart';  // 날짜 포맷팅을 위한 패키지 추가

class LessonReservationHistoryScreen extends StatefulWidget {
  int? memberId;
  String? branchId;

  LessonReservationHistoryScreen({Key? key, this.memberId, this.branchId}) : super(key: key);

  @override
  State<LessonReservationHistoryScreen> createState() => _LessonReservationHistoryScreenState();
}

class _LessonReservationHistoryScreenState extends State<LessonReservationHistoryScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _reservations = []; // 예약된 레슨 목록
  List<Map<String, dynamic>> _lessonCountings = []; // 레슨 카운팅 정보
  Map<String, dynamic> _lessonBalances = {}; // LS_id별 잔여 시간 정보
  String? _error;
  Map<String, dynamic> _apiResponse = {}; // API 응답 저장
  bool _showPastReservations = false; // 과거 예약 표시 여부
  
  @override
  void initState() {
    super.initState();
    
    // 앱 시작 시에 데이터 로드
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _apiResponse = {};
      _reservations = [];
      _lessonCountings = [];
      _lessonBalances = {};
    });

    try {
      // 회원 ID 확인
      if (widget.memberId == null) {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        if (userProvider.user != null) {
          // 사용자 ID를 int로 변환
          int? userId = int.tryParse(userProvider.user!.id);
          if (userId != null) {
            widget.memberId = userId;
          } else {
            throw Exception('유효하지 않은 사용자 ID입니다.');
          }
        } else {
          throw Exception('로그인이 필요합니다.');
        }
      }

      // 회원 ID가 여전히 없다면 오류 발생
      if (widget.memberId == null) {
        throw Exception('회원 ID를 가져올 수 없습니다. 로그인이 필요합니다.');
      }

      // API 호출 - 레슨 상태 정보 가져오기 (countings와 orders 포함)
      final response = await _fetchLessonStatusFromAPI(widget.memberId!, widget.branchId);
      _apiResponse = response;
      
      // 1. v2_LS_orders 테이블 데이터 처리 (우선 처리)
      if (response.containsKey('orders') && response['orders'] is List) {
        final orders = response['orders'] as List;
        
        if (orders.isNotEmpty) {
          // orders 데이터 처리
          final processedOrders = _processOrders(orders);
          
          if (processedOrders.isNotEmpty) {
            // 처리된 데이터로 예약 목록 업데이트
            setState(() {
              _reservations = processedOrders;
            });
          }
        }
      }
      
      // 2. v3_LS_countings 데이터 처리
      if (response.containsKey('countings') && response['countings'] is List) {
        final countings = response['countings'] as List;
        
        // countings 데이터에서 잔여 시간 정보만 추출
        _extractLessonBalances(countings);
      }
      
      // 로딩 상태 업데이트
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = '레슨 예약 내역을 불러오는 중 오류가 발생했습니다: $e';
        _isLoading = false;
      });
    }
  }
  
  // API를 사용하여 레슨 상태 정보 가져오기 (countings와 orders 모두 포함)
  Future<Map<String, dynamic>> _fetchLessonStatusFromAPI(int memberId, String? branchId) async {
    try {
      // 1. 레슨 카운팅 정보 조회 (v3_LS_countings)
      final whereConditionsCountings = [
        {'field': 'member_id', 'operator': '=', 'value': memberId.toString()}
      ];
      
      if (branchId != null && branchId.isNotEmpty) {
        whereConditionsCountings.add({'field': 'branch_id', 'operator': '=', 'value': branchId});
      }

      final countingsResponse = await http.post(
        Uri.parse('https://autofms.mycafe24.com/dynamic_api.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'operation': 'get',
          'table': 'v3_LS_countings',
          'where': whereConditionsCountings
        }),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('레슨 카운팅 조회 시간 초과 (30초)');
        },
      );

      // 2. 레슨 예약 정보 조회 (v2_LS_orders)
      final whereConditionsOrders = [
        {'field': 'member_id', 'operator': '=', 'value': memberId.toString()}
      ];
      
      if (branchId != null && branchId.isNotEmpty) {
        whereConditionsOrders.add({'field': 'branch_id', 'operator': '=', 'value': branchId});
      }

      final ordersResponse = await http.post(
        Uri.parse('https://autofms.mycafe24.com/dynamic_api.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'operation': 'get',
          'table': 'v2_LS_orders',
          'where': whereConditionsOrders,
          'orderBy': [
            {'field': 'LS_date', 'direction': 'DESC'},
            {'field': 'LS_start_time', 'direction': 'DESC'}
          ],
          'limit': 100
        }),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('레슨 예약 조회 시간 초과 (30초)');
        },
      );
      
      // 응답 확인 및 데이터 조합
      List<dynamic> countings = [];
      List<dynamic> orders = [];
      
      if (countingsResponse.statusCode == 200) {
        try {
          final countingsData = jsonDecode(countingsResponse.body);
          if (countingsData['success'] == true && countingsData['data'] != null) {
            countings = countingsData['data'];
          }
        } catch (e) {
          print('레슨 카운팅 JSON 파싱 오류: $e');
        }
      }
      
      if (ordersResponse.statusCode == 200) {
        try {
          final ordersData = jsonDecode(ordersResponse.body);
          if (ordersData['success'] == true && ordersData['data'] != null) {
            orders = ordersData['data'];
          }
        } catch (e) {
          print('레슨 예약 JSON 파싱 오류: $e');
        }
      }
      
      // 통합 응답 반환
      return {
        'success': true,
        'countings': countings,
        'orders': orders,
        'data_source': 'dynamic_api'
      };
      
    } catch (e) {
      // 오류가 발생해도 빈 데이터 반환
      return {
        'success': false,
        'error': e.toString(),
        'countings': [],
        'orders': [],
        'data_source': 'dynamic_api_error'
      };
    }
  }

  // LS_orders 데이터 처리
  List<Map<String, dynamic>> _processOrders(List<dynamic> orders) {
    final List<Map<String, dynamic>> result = [];
    
    for (var order in orders) {
      if (order is Map<String, dynamic>) {
        try {
          // 필요한 필드 추출
          final id = order['LS_id'] ?? order['id'] ?? '';
          String date = order['LS_date'] ?? order['date'] ?? '';
          
          // 날짜 형식 정규화 (YY-MM-DD 또는 YYYY-MM-DD 형식으로 변환)
          if (date.length == 10 && date.contains('-')) {
            // 이미 YYYY-MM-DD 형식
          } else if (date.length == 8 && date.contains('-')) {
            // YY-MM-DD 형식
            date = '20$date';
          } else if (date.length == 6 && !date.contains('-')) {
            // YYMMDD 형식일 경우 변환
            date = '20${date.substring(0, 2)}-${date.substring(2, 4)}-${date.substring(4, 6)}';
          }
          
          // 시간 관련 필드 (중요)
          String startTime = order['LS_start_time'] ?? order['start_time'] ?? '';
          String endTime = order['LS_end_time'] ?? order['end_time'] ?? '';
          
          // 시간이 없는 경우 LS_id에서 추출 시도 (예: 250526_es_1950)
          if (startTime.isEmpty && id.toString().contains('_')) {
            final parts = id.toString().split('_');
            if (parts.length >= 3) {
              final timeCode = parts[parts.length - 1];
              if (timeCode.length == 4 && RegExp(r'^\d+$').hasMatch(timeCode)) {
                startTime = '${timeCode.substring(0, 2)}:${timeCode.substring(2, 4)}';
              }
            }
          }
          
          // 시간 형식 처리 (HH:MM:SS -> HH:MM)
          String formattedStartTime = startTime.toString();
          if (formattedStartTime.length >= 5) {
            formattedStartTime = formattedStartTime.substring(0, 5);
          }
          
          // 종료 시간 처리
          String formattedEndTime = endTime.toString();
          if (formattedEndTime.length >= 5) {
            formattedEndTime = formattedEndTime.substring(0, 5);
          } else if (formattedEndTime.isEmpty && formattedStartTime.isNotEmpty) {
            // 종료 시간이 없지만 시작 시간이 있고 duration이 있는 경우 계산
            final duration = order['LS_net_min'] ?? order['duration'] ?? 0;
            final durationMinutes = duration is String ? int.tryParse(duration) ?? 0 : duration;
            
            // 시작 시간 파싱
            if (formattedStartTime.length == 5 && formattedStartTime.contains(':')) {
              final startHour = int.tryParse(formattedStartTime.split(':')[0]) ?? 0;
              final startMinute = int.tryParse(formattedStartTime.split(':')[1]) ?? 0;
              
              // 종료 시간 계산
              final totalMinutes = startHour * 60 + startMinute + durationMinutes;
              final endHour = (totalMinutes ~/ 60) % 24;
              final endMinute = totalMinutes % 60;
              
              formattedEndTime = '${endHour.toString().padLeft(2, '0')}:${endMinute.toString().padLeft(2, '0')}';
            }
          }
          
          // 기본값 하드코딩 제거
          final duration = order['LS_net_min'] ?? order['duration'] ?? 0;
          final proName = order['LS_contract_pro'] ?? order['pro_name'] ?? '';
          final status = order['LS_status'] ?? order['status'] ?? '';
          final lessonType = order['LS_type']?.toString() ?? order['lesson_type']?.toString() ?? '';
          final memberId = order['member_id'] ?? '';
          final memberName = order['member_name'] ?? '';
          
          // 예약 데이터 형식으로 변환
          result.add({
            'id': id.toString(),
            'date': date,
            'time': formattedStartTime, // 이전 표시 형식과의 호환성
            'start_time': formattedStartTime,
            'end_time': formattedEndTime,
            'duration': duration is String ? int.tryParse(duration) ?? 0 : duration,
            'pro_name': proName,
            'status': status,
            'lesson_type': lessonType,
            'member_id': memberId,
            'member_name': memberName,
            'is_actual_reservation': true, // 데이터 구분을 위한 플래그
            'raw_data': order, // 디버깅용 원본 데이터 저장
            'data_source': 'v2_LS_orders' // 데이터 소스 표시
          });
        } catch (e) {
          // 오류 처리 (디버그 출력 제거)
        }
      }
    }
    
    return result;
  }

  // v3_LS_countings에서 LS_id별 잔여 시간 정보 추출
  void _extractLessonBalances(List<dynamic> countings) {
    for (var counting in countings) {
      if (counting is Map<String, dynamic>) {
        final lsId = counting['LS_id'];
        final balanceMinAfter = counting['LS_balance_min_after'];
        final transactionType = counting['LS_transaction_type'];
        
        // 유효한 LS_id와 잔여 시간 정보가 있는 경우에만 저장
        if (lsId != null && balanceMinAfter != null) {
          // 같은 LS_id에 대해 여러 항목이 있을 수 있으므로, 최신 데이터를 사용
          _lessonBalances[lsId.toString()] = {
            'balance_min': balanceMinAfter,
            'transaction_type': transactionType,
          };
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 앱 테마 색상 정의 - 갈색 테마
    final Color primaryColor = const Color(0xFF5D4037); // 갈색 기본 테마
    final Color secondaryColor = const Color(0xFF8D6E63); // 밝은 갈색
    
    // 예약 정렬 및 오늘/미래/과거 예약 분리
    List<Map<String, dynamic>> sorted = List<Map<String, dynamic>>.from(_reservations);
    sorted.sort((a, b) {
      final aDate = a['date'] ?? '';
      final bDate = b['date'] ?? '';
      
      if (aDate == bDate) {
        final aTime = a['start_time'] ?? '';
        final bTime = b['start_time'] ?? '';
        return aTime.compareTo(bTime);
      }
      
      return aDate.compareTo(bDate);
    });
    
    // 오늘 날짜 구하기
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    
    // 오늘/미래/과거 예약 분류
    final todayReservations = sorted.where((r) => r['date'] == todayStr).toList();
    final futureReservations = sorted.where((r) => r['date'].compareTo(todayStr) > 0).toList();
    final pastReservations = sorted.where((r) => r['date'].compareTo(todayStr) < 0).toList();
    
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA), // 매우 연한 회색 배경
      appBar: AppBar(
        title: const Text(
          '레슨 예약 내역',
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
              : _reservations.isEmpty
                  ? _buildEmptyView()
                  : _buildReservationList(todayReservations, futureReservations, pastReservations),
    );
  }
  
  Widget _buildEmptyView() {
    // 앱 테마 색상 정의
    final Color primaryColor = const Color(0xFF5D4037); // 갈색 기본 테마
    
    return Center(
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
                Icons.history_edu,
                size: 80,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '레슨 예약 내역이 없습니다',
              style: TextStyle(
                fontSize: 20,
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
                '예약 내역이 없습니다. 레슨을 예약하고 골프 실력을 향상시켜보세요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade700,
                  height: 1.5,
                ),
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

  Widget _buildReservationList(
    List<Map<String, dynamic>> todayReservations,
    List<Map<String, dynamic>> futureReservations,
    List<Map<String, dynamic>> pastReservations
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 오늘 예약
        if (todayReservations.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8, top: 8),
            child: Text(
              todayReservations[0]['section_name'] ?? '오늘',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Color(0xFF3F51B5),
              ),
            ),
          ),
          ...todayReservations.map((r) => _buildReservationCard(r, color: Colors.blue[50], isToday: true)),
        ],
        
        // 미래 예약
        if (futureReservations.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8, top: 16),
            child: Text(
              futureReservations[0]['section_name'] ?? '예정',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Color(0xFF4CAF50),
              ),
            ),
          ),
          ...futureReservations.map((r) => _buildReservationCard(r, color: Colors.green[50], isToday: false)),
        ],
        
        // 과거 예약 더보기 버튼
        if (pastReservations.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _showPastReservations = !_showPastReservations;
                });
              },
              icon: Icon(_showPastReservations ? Icons.expand_less : Icons.expand_more),
              label: Text(_showPastReservations ? '접기' : '더 보기 (${pastReservations.length}개)'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[700],
              ),
            ),
          ),
          
          // 과거 예약 표시
          if (_showPastReservations)
            ...pastReservations.map((r) => _buildReservationCard(r, color: Colors.grey[100], isToday: false)),
        ],
      ],
    );
  }
  
  Widget _buildReservationCard(Map<String, dynamic> reservation, {Color? color, bool isToday = false}) {
    // 상태에 따른 색상 설정 (상태별로 유연하게 처리)
    final String reservationStatus = reservation['status'] ?? '';
    final bool isCanceled = reservationStatus.contains('취소');
    
    // 카드 배경색 (동적 처리)
    final cardColor = isCanceled ? Colors.grey[200]! : (color ?? Colors.white);
    
    // 아이콘 선택 (동적 처리)
    final iconColor = isCanceled ? Colors.grey : (color == Colors.blue[50] ? Colors.green : color == Colors.green[50] ? Colors.green : Colors.grey);
    
    // 시간 정보 표시
    final String startTime = reservation['start_time'] ?? reservation['time'] ?? '';
    final String endTime = reservation['end_time'] ?? '';
    
    // 시간 표시 형식
    String timeDisplay = '';
    if (startTime.isNotEmpty && endTime.isNotEmpty) {
      timeDisplay = '$startTime ~ $endTime';
    } else if (startTime.isNotEmpty) {
      timeDisplay = startTime;
    }
    
    final dynamic duration = reservation['duration'] ?? '';
    final durationDisplay = duration.toString().isNotEmpty ? '(${duration}분)' : '';
    
    // 날짜 포맷 (YYYY-MM-DD -> YY년MM월DD일)
    String formattedDate = reservation['date'] ?? '';
    if (formattedDate.length >= 10 && formattedDate.contains('-')) {
      try {
        formattedDate = '${formattedDate.substring(2,4)}년${formattedDate.substring(5,7)}월${formattedDate.substring(8,10)}일';
      } catch (e) {
        // 날짜 형식이 예상과 다른 경우 원본 반환
      }
    }
    
    // LS_id를 이용하여 해당 예약의 잔여 시간 정보 가져오기
    String balanceInfo = '';
    if (reservation['id'] != null) {
      final String lsId = reservation['id'].toString();
      if (_lessonBalances.containsKey(lsId)) {
        final balance = _lessonBalances[lsId]['balance_min'];
        if (balance != null) {
          balanceInfo = '잔여 레슨권: $balance분';
        }
      }
    }
    
    return Card(
      color: cardColor,
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 오늘 레슨 배지
          if (isToday)
            Padding(
              padding: const EdgeInsets.only(left: 20, top: 12, bottom: 2),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: isCanceled ? Colors.grey[400] : Colors.blue[300],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isCanceled ? '취소됨' : '오늘예약',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)
                ),
              ),
            ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            leading: Icon(
              isCanceled ? Icons.cancel_outlined : Icons.golf_course,
              color: iconColor, 
              size: 32
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    '$formattedDate  $timeDisplay $durationDisplay', 
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _buildStatusBadge(reservationStatus),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      reservation['pro_name'] != null ? '${reservation['pro_name']} 프로' : '',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                    ),
                    // 잔여 시간 정보 표시
                    if (balanceInfo.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.green[200]!),
                        ),
                        child: Text(
                          balanceInfo,
                          style: TextStyle(fontSize: 12, color: Colors.green[800], fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                if (reservation['lesson_type'] != null && reservation['lesson_type'].toString().isNotEmpty)
                  Text(
                    reservation['lesson_type'].toString(), 
                    style: const TextStyle(fontSize: 13, color: Colors.teal),
                  ),
              ],
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showReservationDetail(context, reservation),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatusBadge(String status) {
    Color color;
    String text = status;
    IconData? icon;
    
    // 상태별 색상 및 아이콘 동적 지정
    if (status.contains('예약취소') || status.contains('취소')) {
      color = Colors.red;
      text = '취소됨';
      icon = Icons.cancel_outlined;
    } else if (status.contains('완료')) {
      color = Colors.green;
      icon = Icons.check_circle_outline;
    } else if (status.contains('예약') || status.contains('확정')) {
      color = Colors.blue;
      text = '예약완료';
      icon = Icons.event_available;
    } else if (status.contains('처리중')) {
      color = Colors.purple;
      icon = Icons.pending_outlined;
    } else if (status.contains('대기')) {
      color = Colors.orange;
      icon = Icons.hourglass_empty;
    } else {
      color = Colors.grey;
      icon = Icons.help_outline;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            text, 
            style: TextStyle(
              color: color, 
              fontWeight: FontWeight.bold, 
              fontSize: 13
            ),
          ),
        ],
      ),
    );
  }
  
  void _showReservationDetail(BuildContext context, Map<String, dynamic> reservation) {
    // 취소 가능 여부 확인 (시작 시간 1시간 전까지만 취소 가능)
    bool canCancel = false;
    String cancelButtonTooltip = '';
    
    final String reservationStatus = reservation['status'] ?? '';
    
    // 이미 취소된 예약인지 확인
    if (reservationStatus.contains('취소')) {
      cancelButtonTooltip = '이미 취소된 예약입니다';
    } 
    // 확정된 예약인지 확인
    else if (reservationStatus.contains('예약') || reservationStatus.contains('완료')) {
      try {
        final now = DateTime.now();
        final reservationDate = reservation['date'] ?? '';
        final reservationTime = reservation['start_time'] ?? reservation['time'] ?? '';
        
        if (reservationDate.isNotEmpty && reservationTime.isNotEmpty) {
          final DateFormat formatter = DateFormat('yyyy-MM-dd');
          DateTime parsedDate;
          
          // 다양한 날짜 형식 처리
          try {
            parsedDate = formatter.parse(reservationDate);
          } catch (e) {
            // YY년MM월DD일 형식이면 변환
            if (reservationDate.contains('년') && reservationDate.contains('월') && reservationDate.contains('일')) {
              final year = int.tryParse('20${reservationDate.substring(0, 2)}') ?? 2000;
              final month = int.tryParse(reservationDate.substring(3, 5)) ?? 1;
              final day = int.tryParse(reservationDate.substring(6, 8)) ?? 1;
              parsedDate = DateTime(year, month, day);
            } else {
              throw Exception('지원되지 않는 날짜 형식: $reservationDate');
            }
          }
          
          // 시간 파싱
          final timeParts = reservationTime.split(':');
          final hour = int.tryParse(timeParts[0]) ?? 0;
          final minute = int.tryParse(timeParts[1]) ?? 0;
          
          final reservationDateTime = DateTime(
            parsedDate.year, 
            parsedDate.month, 
            parsedDate.day,
            hour,
            minute
          );
          
          final difference = reservationDateTime.difference(now);
          
          if (difference.inHours >= 1) {
            canCancel = true;
            cancelButtonTooltip = '예약을 취소하려면 클릭하세요';
          } else if (difference.isNegative) {
            cancelButtonTooltip = '이미 지난 예약은 취소할 수 없습니다';
          } else {
            cancelButtonTooltip = '예약 시작 1시간 전까지만 취소가 가능합니다';
          }
        } else {
          cancelButtonTooltip = '날짜 또는 시간 정보가 없어 취소할 수 없습니다';
        }
      } catch (e) {
        // kDebugMode 참조 제거
        canCancel = false;
        cancelButtonTooltip = '예약 정보 형식 오류로 취소할 수 없습니다';
      }
    } else {
      cancelButtonTooltip = '취소 가능한 예약 상태가 아닙니다';
    }
    
    // 시간 정보 표시
    final String startTime = reservation['start_time'] ?? reservation['time'] ?? '';
    final String endTime = reservation['end_time'] ?? '';
    
    // 시간 표시 형식
    String timeDisplay = '';
    if (startTime.isNotEmpty && endTime.isNotEmpty) {
      timeDisplay = '$startTime ~ $endTime';
    } else if (startTime.isNotEmpty) {
      timeDisplay = startTime;
    }
    
    // 예약 날짜 확인
    final String reservationDate = reservation['date'] ?? '';
    bool isPastReservation = false;
    bool isTodayReservation = false;
    
    try {
      if (reservationDate.isNotEmpty) {
        final DateTime now = DateTime.now();
        final DateTime today = DateTime(now.year, now.month, now.day);
        // 날짜 형식에 따라 처리
        DateTime reservationDateTime;
        if (reservationDate.contains('-')) {
          // YYYY-MM-DD 형식
          reservationDateTime = DateTime.parse(reservationDate);
        } else if (reservationDate.contains('년') && reservationDate.contains('월') && reservationDate.contains('일')) {
          // YY년MM월DD일 형식
          final year = int.tryParse('20${reservationDate.substring(0, 2)}') ?? 2000;
          final month = int.tryParse(reservationDate.substring(3, 5)) ?? 1;
          final day = int.tryParse(reservationDate.substring(6, 8)) ?? 1;
          reservationDateTime = DateTime(year, month, day);
        } else {
          throw Exception('지원되지 않는 날짜 형식');
        }
        
        // 오늘 날짜보다 이전인 경우 과거 예약으로 간주
        isPastReservation = reservationDateTime.isBefore(today);
        
        // 오늘 예약인지 확인
        isTodayReservation = reservationDateTime.year == today.year && 
                             reservationDateTime.month == today.month && 
                             reservationDateTime.day == today.day;
      }
    } catch (e) {
      // 날짜 변환 오류 처리
    }
    
    // 색상 정의
    final Color primaryColor = reservationStatus.contains('취소') ? 
        const Color(0xFFE53935) : // 취소는 빨간색
        (isTodayReservation ? 
          const Color(0xFF1E88E5) : // 오늘은 파란색
          const Color(0xFF43A047)); // 그 외는 녹색
    
    final Color backgroundColor = Colors.white;
    final Color textColor = const Color(0xFF424242);
    final Color labelColor = const Color(0xFF757575);
    
    final bool isCanceled = reservationStatus.contains('취소');
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 드래그 핸들
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              
              // 상태 표시 (오늘 예약 또는 취소된 예약만)
              if (isTodayReservation || isCanceled) 
                Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: primaryColor.withOpacity(0.3), width: 1),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isCanceled ? Icons.cancel_outlined : Icons.event_available,
                        color: primaryColor,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        isCanceled ? '취소된 예약입니다' : '오늘 예약입니다',
                        style: TextStyle(
                          fontSize: 16,
                          color: primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              
              // 예약 정보 카드
              Container(
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      spreadRadius: 1,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 헤더
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.grey.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: primaryColor, size: 20),
                          const SizedBox(width: 10),
                          const Text(
                            '예약 정보',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF424242),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // 내용
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (reservation['date'] != null)
                            _infoRow('날짜', reservation['date']?.toString() ?? '', textColor, labelColor),
                          if (timeDisplay.isNotEmpty)
                            _infoRow('시간', timeDisplay, textColor, labelColor, 
                              suffix: reservation['duration'] != null ? 
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${reservation['duration']}분',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor,
                                    ),
                                  ),
                                ) : null
                            ),
                          if (reservation['pro_name'] != null)
                            _infoRow('담당 프로', '${reservation['pro_name']} 프로', textColor, labelColor),
                          if (reservation['lesson_type'] != null)
                            _infoRow('레슨 유형', reservation['lesson_type']?.toString() ?? '', textColor, labelColor),
                          _infoRow('상태', reservationStatus, textColor, labelColor, 
                            suffix: _buildStatusBadge(reservationStatus)
                          ),
                          if (reservation['id'] != null && _lessonBalances.containsKey(reservation['id'].toString())) 
                            Builder(
                              builder: (context) {
                                final balance = _lessonBalances[reservation['id'].toString()]['balance_min'];
                                if (balance != null) {
                                  return _infoRow(
                                    '잔여 레슨권', 
                                    '$balance분', 
                                    textColor, 
                                    labelColor,
                                    suffix: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.green[50],
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.green.shade200)
                                      ),
                                      child: Text(
                                        '$balance분',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green[700],
                                        ),
                                      ),
                                    )
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // 예약 취소 버튼
              if (canCancel)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showCancelConfirmation(reservation['id']),
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('예약 취소하기'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE53935),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              
              // 취소 불가 메시지 (취소 불가인 경우에만 표시)
              if (!canCancel && !isCanceled) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.grey[700]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isPastReservation ? 
                            '지난 예약은 취소할 수 없습니다.' : 
                            '예약 시작 1시간 전까지만 취소가 가능합니다.',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  // 정보 행 위젯 (고급스러운 디자인)
  Widget _infoRow(String label, String value, Color textColor, Color labelColor, {Widget? suffix}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: labelColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: textColor,
              ),
            ),
          ),
          if (suffix != null) suffix,
        ],
      ),
    );
  }
  
  void _showCancelConfirmation(String reservationId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('예약 취소 확인'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('정말 이 레슨 예약을 취소하시겠습니까?'),
            const SizedBox(height: 16),
            Text(
              '취소 후에는 복구할 수 없으며, 잔여 시간이 재계산됩니다.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('아니오'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _cancelReservation(reservationId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('예, 취소합니다'),
          ),
        ],
      ),
    );
  }
  
  void _cancelReservation(String reservationId) async {
    try {
      // 로딩 다이얼로그 표시
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // 예약 취소 API 호출
      final result = await ApiService.cancelLessonReservation(reservationId);

      // 로딩 다이얼로그 닫기
      Navigator.of(context).pop();

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'])),
        );

        // 모달 닫기
        Navigator.of(context).pop();
        
        // 데이터 새로고침
        _loadData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? '예약 취소 중 오류가 발생했습니다')),
        );
      }
    } catch (e) {
      // 로딩 다이얼로그 닫기
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('예약 취소 중 오류가 발생했습니다: $e')),
      );
    }
  }
}
