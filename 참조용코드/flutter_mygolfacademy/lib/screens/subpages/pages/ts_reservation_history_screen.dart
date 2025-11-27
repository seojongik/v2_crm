import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../providers/user_provider.dart';

class TSReservationHistoryScreen extends StatefulWidget {
  final int? memberId;
  const TSReservationHistoryScreen({Key? key, required this.memberId}) : super(key: key);

  @override
  State<TSReservationHistoryScreen> createState() => _TSReservationHistoryScreenState();
}

class _TSReservationHistoryScreenState extends State<TSReservationHistoryScreen> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _reservations = [];
  bool _showPastReservations = false;

  @override
  void initState() {
    super.initState();
    _loadReservations();
  }

  Future<void> _loadReservations({String? specificDate, String? status}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      // dynamic_api.php를 사용한 예약 내역 조회
      final url = 'https://autofms.mycafe24.com/dynamic_api.php';
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      
      // UserProvider에서 현재 사용자의 branchId 가져오기
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      
      // 기본 조건: member_id
      List<Map<String, dynamic>> whereConditions = [
        {
          'field': 'member_id',
          'operator': '=',
          'value': widget.memberId
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
      
      // 선택적 조건 추가
      if (specificDate != null && specificDate.isNotEmpty) {
        whereConditions.add({
          'field': 'ts_date',
          'operator': '=',
          'value': specificDate
        });
      }
      
      if (status != null && status.isNotEmpty) {
        whereConditions.add({
          'field': 'ts_status',
          'operator': '=',
          'value': status
        });
      }
      
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode({
          'operation': 'get',
          'table': 'v2_priced_TS',
          'where': whereConditions,
          'orderBy': [
            {
              'field': 'ts_date',
              'direction': 'DESC'
            },
            {
              'field': 'ts_start',
              'direction': 'DESC'
            }
          ]
        }),
      );
      if (response.statusCode == 200) {
        final resp = jsonDecode(response.body);
        if (resp['success'] == true && resp['data'] != null) {
          _reservations = List<Map<String, dynamic>>.from(resp['data']);
        } else {
          _error = resp['error'] ?? '예약내역을 불러올 수 없습니다.';
        }
      } else {
        _error = '서버 오류: ${response.statusCode}';
      }
    } catch (e) {
      _error = '예약내역 조회 중 오류: $e';
    }
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _cancelReservation(String reservationId) async {
    try {
      // 1단계: 예약 정보 조회
      final reservationInfo = await _getReservationInfo(reservationId);
      if (reservationInfo == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('예약 정보를 찾을 수 없습니다.')),
        );
        return;
      }

      // 2단계: 취소 가능 여부 검증
      if (!_canCancelReservation(reservationInfo)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('취소 불가능한 예약입니다.')),
        );
        return;
      }

      // 3단계: Bills 정보 조회 (크레딧 결제인 경우)
      final billInfo = await _getBillInfo(reservationId);
      
      // 4단계: 예약 상태 업데이트
      await _updateReservationStatus(reservationId);

      // 5단계: Bills 처리 (크레딧 결제인 경우만)
      int refundedAmount = 0;
      int currentBalance = 0;
      bool creditUpdated = false;

      if (billInfo != null) {
        creditUpdated = true;
        refundedAmount = billInfo['bill_netamt'] ?? 0;
        
        // 이전 잔액 조회
        final previousBalance = await _getPreviousBalance(
          billInfo['member_id'], 
          billInfo['bill_id']
        );
        
        // Bills 상태 업데이트
        await _updateBillStatus(billInfo['bill_id']);
        
        // 취소된 거래 잔액 재설정
        await _resetCancelledBillBalance(billInfo['bill_id'], previousBalance);
        
        // 후속 거래들의 잔액 재계산
        await _recalculateSubsequentBalances(
          billInfo['member_id'], 
          billInfo['bill_id']
        );
        
        // 최종 잔액 조회
        currentBalance = await _getCurrentBalance(billInfo['member_id']);
      }

      // 성공 메시지 표시
      if (creditUpdated) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('예약이 취소되었습니다.'),
                Text('환불된 금액: ${NumberFormat('#,###').format(refundedAmount)}원'),
                Text('현재 잔액: ${NumberFormat('#,###').format(currentBalance)}원'),
              ],
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('예약이 취소되었습니다.')),
        );
      }
      
      _loadReservations();
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('취소 중 오류: $e')),
      );
    }
  }

  // 예약 정보 조회
  Future<Map<String, dynamic>?> _getReservationInfo(String reservationId) async {
    final response = await http.post(
      Uri.parse('https://autofms.mycafe24.com/dynamic_api.php'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'operation': 'get',
        'table': 'v2_priced_TS',
        'where': [
          {'field': 'reservation_id', 'operator': '=', 'value': reservationId}
        ]
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] && data['data'].isNotEmpty) {
        return data['data'][0];
      }
    }
    return null;
  }

  // 취소 가능 여부 검증
  bool _canCancelReservation(Map<String, dynamic> reservationInfo) {
    final status = reservationInfo['ts_status'];
    if (status == '예약취소') {
      return false;
    }
    
    final tsDate = reservationInfo['ts_date'];
    final tsStart = reservationInfo['ts_start'];
    
    if (tsDate != null && tsStart != null) {
      final reservationDateTime = DateTime.parse('${tsDate}T${tsStart}');
      final now = DateTime.now();
      
      // 예약 시간이 지났으면 취소 불가
      if (reservationDateTime.isBefore(now)) {
        return false;
      }
    }
    
    return true;
  }

  // Bills 정보 조회
  Future<Map<String, dynamic>?> _getBillInfo(String reservationId) async {
    final response = await http.post(
      Uri.parse('https://autofms.mycafe24.com/dynamic_api.php'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'operation': 'get',
        'table': 'v2_bills',
        'fields': ['bill_id', 'member_id', 'bill_netamt'],
        'where': [
          {'field': 'reservation_id', 'operator': '=', 'value': reservationId},
          {'field': 'bill_status', 'operator': '<>', 'value': '예약취소'}
        ]
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] && data['data'].isNotEmpty) {
        return data['data'][0];
      }
    }
    return null;
  }

  // 예약 상태 업데이트
  Future<void> _updateReservationStatus(String reservationId) async {
    final response = await http.post(
      Uri.parse('https://autofms.mycafe24.com/dynamic_api.php'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'operation': 'update',
        'table': 'v2_priced_TS',
        'data': {
          'ts_status': '예약취소',
          'time_stamp': DateTime.now().toIso8601String().replaceAll('T', ' ').substring(0, 19),
        },
        'where': [
          {'field': 'reservation_id', 'operator': '=', 'value': reservationId}
        ]
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('예약 상태 업데이트 실패: HTTP ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    if (!data['success']) {
      throw Exception('예약 상태 업데이트 실패: ${data['error']}');
    }
  }

  // Bills 상태 업데이트
  Future<void> _updateBillStatus(int billId) async {
    final response = await http.post(
      Uri.parse('https://autofms.mycafe24.com/dynamic_api.php'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'operation': 'update',
        'table': 'v2_bills',
        'data': {
          'bill_status': '예약취소',
          'bill_totalamt': 0,
          'bill_deduction': 0,
          'bill_netamt': 0,
          'time_stamp': DateTime.now().toIso8601String().replaceAll('T', ' ').substring(0, 19),
        },
        'where': [
          {'field': 'bill_id', 'operator': '=', 'value': billId}
        ]
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Bills 상태 업데이트 실패: HTTP ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    if (!data['success']) {
      throw Exception('Bills 상태 업데이트 실패: ${data['error']}');
    }
  }

  // 이전 잔액 조회
  Future<int> _getPreviousBalance(int memberId, int billId) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    
    final whereConditions = [
      {'field': 'member_id', 'operator': '=', 'value': memberId},
      {'field': 'bill_id', 'operator': '<', 'value': billId}
    ];
    
    if (userProvider.currentBranchId != null && userProvider.currentBranchId!.isNotEmpty) {
      whereConditions.add({'field': 'branch_id', 'operator': '=', 'value': userProvider.currentBranchId!});
    }

    final response = await http.post(
      Uri.parse('https://autofms.mycafe24.com/dynamic_api.php'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'operation': 'get',
        'table': 'v2_bills',
        'fields': ['bill_balance_after'],
        'where': whereConditions,
        'orderBy': [
          {'field': 'bill_id', 'direction': 'DESC'}
        ],
        'limit': 1
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] && data['data'].isNotEmpty) {
        return data['data'][0]['bill_balance_after'] ?? 0;
      }
    }
    return 0;
  }

  // 취소된 거래 잔액 재설정
  Future<void> _resetCancelledBillBalance(int billId, int previousBalance) async {
    final response = await http.post(
      Uri.parse('https://autofms.mycafe24.com/dynamic_api.php'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'operation': 'update',
        'table': 'v2_bills',
        'data': {
          'bill_balance_before': previousBalance,
          'bill_balance_after': previousBalance,
          'time_stamp': DateTime.now().toIso8601String().replaceAll('T', ' ').substring(0, 19),
        },
        'where': [
          {'field': 'bill_id', 'operator': '=', 'value': billId}
        ]
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('취소된 거래 잔액 재설정 실패: HTTP ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    if (!data['success']) {
      throw Exception('취소된 거래 잔액 재설정 실패: ${data['error']}');
    }
  }

  // 후속 거래들의 잔액 재계산
  Future<void> _recalculateSubsequentBalances(int memberId, int billId) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    
    // 후속 거래들 조회
    final whereConditions = [
      {'field': 'member_id', 'operator': '=', 'value': memberId},
      {'field': 'bill_id', 'operator': '>', 'value': billId}
    ];
    
    if (userProvider.currentBranchId != null && userProvider.currentBranchId!.isNotEmpty) {
      whereConditions.add({'field': 'branch_id', 'operator': '=', 'value': userProvider.currentBranchId!});
    }

    final response = await http.post(
      Uri.parse('https://autofms.mycafe24.com/dynamic_api.php'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'operation': 'get',
        'table': 'v2_bills',
        'fields': ['bill_id', 'bill_netamt'],
        'where': whereConditions,
        'orderBy': [
          {'field': 'bill_id', 'direction': 'ASC'}
        ]
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('후속 거래 조회 실패: HTTP ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    if (!data['success']) {
      throw Exception('후속 거래 조회 실패: ${data['error']}');
    }

    // 이전 잔액 조회
    int currentBalance = await _getPreviousBalance(memberId, billId);

    // 각 후속 거래의 잔액 재계산 및 업데이트
    for (var bill in data['data']) {
      final int billIdToUpdate = bill['bill_id'];
      final int netAmount = bill['bill_netamt'] ?? 0;
      final int newBalance = currentBalance + netAmount;

      await _updateBillBalance(billIdToUpdate, currentBalance, newBalance);
      currentBalance = newBalance;
    }
  }

  // 개별 거래 잔액 업데이트
  Future<void> _updateBillBalance(int billId, int balanceBefore, int balanceAfter) async {
    final response = await http.post(
      Uri.parse('https://autofms.mycafe24.com/dynamic_api.php'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'operation': 'update',
        'table': 'v2_bills',
        'data': {
          'bill_balance_before': balanceBefore,
          'bill_balance_after': balanceAfter,
          'time_stamp': DateTime.now().toIso8601String().replaceAll('T', ' ').substring(0, 19),
        },
        'where': [
          {'field': 'bill_id', 'operator': '=', 'value': billId}
        ]
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('거래 잔액 업데이트 실패: HTTP ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    if (!data['success']) {
      throw Exception('거래 잔액 업데이트 실패: ${data['error']}');
    }
  }

  // 현재 잔액 조회
  Future<int> _getCurrentBalance(int memberId) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    
    final whereConditions = [
      {'field': 'member_id', 'operator': '=', 'value': memberId}
    ];
    
    if (userProvider.currentBranchId != null && userProvider.currentBranchId!.isNotEmpty) {
      whereConditions.add({'field': 'branch_id', 'operator': '=', 'value': userProvider.currentBranchId!});
    }

    final response = await http.post(
      Uri.parse('https://autofms.mycafe24.com/dynamic_api.php'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'operation': 'get',
        'table': 'v2_bills',
        'fields': ['bill_balance_after'],
        'where': whereConditions,
        'orderBy': [
          {'field': 'bill_id', 'direction': 'DESC'}
        ],
        'limit': 1
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] && data['data'].isNotEmpty) {
        return data['data'][0]['bill_balance_after'] ?? 0;
      }
    }
    return 0;
  }

  Widget _statusBadge(String status) {
    Color color;
    String text = status;
    switch (status) {
      case '결제완료':
        color = Colors.blue;
        break;
      case '예약취소':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }

  String _formatTime(String? t) {
    if (t == null) return '';
    final parts = t.split(':');
    if (parts.length >= 2) return '${parts[0]}:${parts[1]}';
    return t;
  }

  String _formatDate(String date) {
    if (date.length >= 10) {
      return '${date.substring(2,4)}년${date.substring(5,7)}월${date.substring(8,10)}일';
    }
    return date;
  }

  String _typeLabel(String? type) {
    switch (type) {
      case '일반':
        return '일반예약(1회)';
      case '주니어':
        return '주니어(1회)';
      case '일반루틴':
        return '일반예약(루틴)';
      case '주니어루틴':
        return '주니어(루틴)';
      default:
        return type ?? '';
    }
  }

  Widget _reservationCard(Map<String, dynamic> r, {Color? color, bool isToday = false}) {
    final date = r['ts_date'] ?? '';
    final start = r['ts_start'] ?? '';
    final end = r['ts_end'] ?? '';
    final tsNum = r['ts_id']?.toString() ?? '';
    final status = r['ts_status'] ?? '';
    final tsMin = r['ts_min']?.toString() ?? '';
    final tsType = r['ts_type']?.toString() ?? '';
    final isCancelled = status == '예약취소';
    
    // 취소된 예약은 회색 배경으로 표시
    Color cardColor = isCancelled ? Colors.grey[200]! : (color ?? Colors.white);
    
    final iconColor = isCancelled ? Colors.grey : (color == Colors.blue[50] ? Colors.green : color == Colors.green[50] ? Colors.green : Colors.grey);
    return Card(
      color: cardColor,
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isToday)
            Padding(
              padding: const EdgeInsets.only(left: 20, top: 12, bottom: 2),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: isCancelled ? Colors.grey[400] : Colors.blue[300],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isCancelled ? '취소됨' : '오늘예약', 
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)
                ),
              ),
            ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            leading: Icon(
              isCancelled ? Icons.cancel_outlined : Icons.golf_course, 
              color: iconColor, 
              size: 32
            ),
            title: Row(
              children: [
                Text('${_formatDate(date)}  ${_formatTime(start)}~${_formatTime(end)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                if (tsMin.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Text('(${tsMin}분)', style: TextStyle(fontSize: 13, color: Colors.grey)),
                ],
                const SizedBox(width: 8),
                _statusBadge(status),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('${tsNum}번 타석', style: const TextStyle(fontSize: 15)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(_typeLabel(tsType), style: const TextStyle(fontSize: 13, color: Colors.teal)),
              ],
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showReservationDetail(context, r),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 소팅 및 오늘/미래/과거 예약 분리 (중복 방지)
    List<Map<String, dynamic>> sorted = List<Map<String, dynamic>>.from(_reservations);
    sorted.sort((a, b) {
      final aDateTime = DateTime.parse('${a['ts_date']}T${a['ts_start']}');
      final bDateTime = DateTime.parse('${b['ts_date']}T${b['ts_start']}');
      return bDateTime.compareTo(aDateTime);
    });
    final today = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(today);
    final todayReservations = sorted.where((r) => r['ts_date'] == todayStr).toList();
    final futureReservations = sorted.where((r) => r['ts_date'].compareTo(todayStr) > 0).toList();
    final pastReservations = sorted.where((r) => r['ts_date'].compareTo(todayStr) < 0).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('통합 예약내역')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : sorted.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.event_busy, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          const Text('예약내역이 없습니다.', style: TextStyle(fontSize: 18, color: Colors.black54)),
                        ],
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // 오늘 예약
                        if (todayReservations.isNotEmpty)
                          ...todayReservations.map((r) => _reservationCard(r, color: Colors.blue[50], isToday: true)),
                        // 미래 예약
                        if (futureReservations.isNotEmpty)
                          ...futureReservations.map((r) => _reservationCard(
                            r,
                            color: (r['ts_status'] == '예약취소') ? Colors.grey[300] : Colors.green[50],
                            isToday: false,
                          )),
                        // 과거 예약 더보기 버튼
                        if (pastReservations.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _showPastReservations = !_showPastReservations;
                                });
                              },
                              icon: Icon(_showPastReservations ? Icons.expand_less : Icons.expand_more),
                              label: Text(_showPastReservations ? '과거 예약 접기' : '과거 예약 더보기'),
                            ),
                          ),
                        // 과거 예약 펼치기
                        if (_showPastReservations && pastReservations.isNotEmpty)
                          ...pastReservations.map((r) => _reservationCard(r, color: const Color(0xFFFFF6E5), isToday: false)),
                      ],
                    ),
    );
  }

  void _showReservationDetail(BuildContext context, Map<String, dynamic> r) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.only(top: 40),
          child: ReservationDetailModal(
            reservation: r,
            memberId: widget.memberId,
            onCancel: _showCancelDialog,
          ),
        );
      },
    );
  }

  void _showCancelDialog(String reservationId, String tsDate, String tsStart) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('예약 취소'),
        content: const Text('정말로 이 예약을 취소하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('아니오'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _cancelReservation(reservationId);
            },
            child: const Text('예', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class ReservationDetailModal extends StatefulWidget {
  final Map<String, dynamic> reservation;
  final int? memberId;
  final void Function(String reservationId, String tsDate, String tsStart) onCancel;
  const ReservationDetailModal({required this.reservation, required this.memberId, required this.onCancel});

  @override
  State<ReservationDetailModal> createState() => _ReservationDetailModalState();
}

class _ReservationDetailModalState extends State<ReservationDetailModal> {
  late Timer _timer;
  String _otp = '';
  int _secondsLeft = 0;
  bool _showDiscountDetail = false;

  @override
  void initState() {
    super.initState();
    _generateOtpAndTimer();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _generateOtpAndTimer());
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _generateOtpAndTimer() {
    final now = DateTime.now();
    final blockMinute = (now.minute ~/ 5) * 5;
    final blockTime = DateTime(now.year, now.month, now.day, now.hour, blockMinute);
    final blockStr = DateFormat('yyyyMMddHHmm').format(blockTime);
    final raw = '${widget.reservation['reservation_id']}_${widget.memberId}_$blockStr';
    final hash = sha256.convert(utf8.encode(raw)).toString();
    final digits = hash.replaceAll(RegExp(r'[^0-9]'), '');
    String otp = digits.padRight(6, '0').substring(0, 6);
    // 남은 초 계산
    final nextBlock = blockTime.add(const Duration(minutes: 5));
    final secondsLeft = nextBlock.difference(now).inSeconds;
    setState(() {
      _otp = otp;
      _secondsLeft = secondsLeft;
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.reservation;
    final numberFormat = NumberFormat('#,###');
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final tsDate = r['ts_date'] ?? '';
    final status = r['ts_status'] ?? '';

    Widget otpSection;
    if (status == '예약취소') {
      otpSection = Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Colors.red[400],
        margin: const EdgeInsets.only(bottom: 24),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cancel, color: Colors.white, size: 40),
                const SizedBox(height: 10),
                Text('취소된 예약입니다.', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      );
    } else if (tsDate == todayStr) {
      // 오늘 예약: 기존 OTP 카드
      otpSection = Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Colors.blue[50],
        margin: const EdgeInsets.only(bottom: 24),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('타석 오픈 OTP', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue[900])),
                  const SizedBox(width: 16),
                  Text('${_formatTime(r['ts_start'])} ~ ${_formatTime(r['ts_end'])}', style: TextStyle(fontSize: 16, color: Colors.blue[900], fontWeight: FontWeight.w500)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: _otp.split('').map((d) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(d, style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.blue[700])),
                )).toList(),
              ),
              const SizedBox(width: 12),
              Text(
                '${(_secondsLeft ~/ 60).toString().padLeft(2, '0')}:${(_secondsLeft % 60).toString().padLeft(2, '0')}',
                style: TextStyle(fontSize: 16, color: Colors.blue, fontWeight: FontWeight.w600),
              ),
              Text('이용중인 고객이 없을시 예약시간 10분 전부터 미리 오픈 가능합니다.',
                style: TextStyle(fontSize: 13, color: Colors.blue[900]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    } else if (tsDate.compareTo(todayStr) > 0) {
      // 미래 예약: 안내 메시지 (취소 상태면 회색)
      final isCancelled = status == '예약취소';
      otpSection = Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: isCancelled ? Colors.grey[400] : Colors.green[50],
        margin: const EdgeInsets.only(bottom: 24),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_clock, color: isCancelled ? Colors.white : Colors.blue, size: 40),
                const SizedBox(height: 10),
                Text('이용 당일에 OTP가 활성화됩니다.',
                  style: TextStyle(fontSize: 16, color: isCancelled ? Colors.white : Colors.blue[900], fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      // 과거 예약: 만료 메시지 (진회색+흰글씨)
      otpSection = Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Colors.grey[800],
        margin: const EdgeInsets.only(bottom: 24),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, color: Colors.white, size: 40),
                const SizedBox(height: 10),
                Text('만료된 OTP입니다.', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              otpSection,
              // 예약 상세 카드 (간결하게)
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                margin: const EdgeInsets.only(bottom: 24),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('${r['ts_date'] ?? ''}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          SizedBox(width: 12),
                          Text('타석 ${r['ts_id']}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          SizedBox(width: 12),
                          _statusBadge(r['ts_status'] ?? ''),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Text('${_formatTime(r['ts_start'])} ~ ${_formatTime(r['ts_end'])}', style: TextStyle(fontSize: 15)),
                          Spacer(),
                          Text('${r['ts_payment_method'] ?? ''}', style: TextStyle(fontSize: 14, color: Colors.grey[700])),
                        ],
                      ),
                      Divider(height: 24),
                      Row(
                        children: [
                          Text('총금액', style: TextStyle(fontWeight: FontWeight.bold)),
                          Spacer(),
                          Text('${numberFormat.format(r['total_amt'] ?? 0)}원', style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Row(
                        children: [
                          Text('결제금액', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                          Spacer(),
                          Text('${numberFormat.format(r['net_amt'] ?? 0)}원', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                        ],
                      ),
                      Row(
                        children: [
                          Text('총할인', style: TextStyle(color: Colors.green[700])),
                          Spacer(),
                          Text('-${numberFormat.format(r['total_discount'] ?? 0)}원', style: TextStyle(color: Colors.green[700])),
                        ],
                      ),
                      if ((r['term_discount'] ?? 0) != 0 || (r['member_discount'] ?? 0) != 0 || (r['junior_discount'] ?? 0) != 0 || (r['overtime_discount'] ?? 0) != 0 || (r['revisit_discount'] ?? 0) != 0 || (r['emergency_discount'] ?? 0) != 0 || (r['routine_discount'] ?? 0) != 0)
                        Column(
                          children: [
                            SizedBox(height: 8),
                            GestureDetector(
                              onTap: () => setState(() => _showDiscountDetail = !_showDiscountDetail),
                              child: Row(
                                children: [
                                  Text(_showDiscountDetail ? '할인 상세 닫기' : '할인 상세 보기', style: TextStyle(color: Colors.blue, fontSize: 13)),
                                  Icon(_showDiscountDetail ? Icons.expand_less : Icons.expand_more, color: Colors.blue, size: 18),
                                ],
                              ),
                            ),
                            if (_showDiscountDetail)
                              Padding(
                                padding: const EdgeInsets.only(top: 6.0),
                                child: Column(
                                  children: [
                                    if ((r['term_discount'] ?? 0) != 0)
                                      _infoRow('기간권할인', '${numberFormat.format(r['term_discount'] ?? 0)}원'),
                                    if ((r['member_discount'] ?? 0) != 0)
                                      _infoRow('등록회원할인', '${numberFormat.format(r['member_discount'] ?? 0)}원'),
                                    if ((r['junior_discount'] ?? 0) != 0)
                                      _infoRow('주니어할인', '${numberFormat.format(r['junior_discount'] ?? 0)}원'),
                                    if ((r['overtime_discount'] ?? 0) != 0)
                                      _infoRow('집중연습할인', '${numberFormat.format(r['overtime_discount'] ?? 0)}원'),
                                    if ((r['revisit_discount'] ?? 0) != 0)
                                      _infoRow('재방문할인', '${numberFormat.format(r['revisit_discount'] ?? 0)}원'),
                                    if ((r['emergency_discount'] ?? 0) != 0)
                                      _infoRow('긴급할인', '${numberFormat.format(r['emergency_discount'] ?? 0)}원'),
                                    if ((r['routine_discount'] ?? 0) != 0)
                                      _infoRow('루틴할인', '${numberFormat.format(r['routine_discount'] ?? 0)}원'),
                                  ],
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              // 예약 취소 버튼
              Row(
                children: [
                  Expanded(
                    child: Tooltip(
                      message: _getCancelButtonTooltip(r),
                      child: ElevatedButton.icon(
                        onPressed: _canCancelReservation(r),
                        icon: const Icon(Icons.cancel, color: Colors.white),
                        label: const Text('예약 취소'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
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

  Widget _statusBadge(String status) {
    Color color;
    String text = status;
    switch (status) {
      case '결제완료':
        color = Colors.blue;
        break;
      case '예약취소':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }

  String _formatTime(String? t) {
    if (t == null) return '';
    final parts = t.split(':');
    if (parts.length >= 2) return '${parts[0]}:${parts[1]}';
    return t;
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text('$label', style: TextStyle(color: Colors.grey[700]))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  // 예약 취소 가능 여부 체크
  Function()? _canCancelReservation(Map<String, dynamic> r) {
    // 예약 상태가 결제완료가 아니면 취소 불가
    if (r['ts_status'] != '결제완료') {
      return null;
    }
    
    // 예약 시작 시간 1시간 전까지만 취소 가능
    final now = DateTime.now();
    final tsDate = r['ts_date'] ?? '';
    final tsStart = r['ts_start'] ?? '';
    
    try {
      final reservationDateTime = DateTime.parse('${tsDate}T$tsStart');
      final difference = reservationDateTime.difference(now);
      
      // 1시간 미만이거나 이미 지난 예약이면 취소 불가
      if (difference.inHours < 1) {
        return null;
      }
      
      // 취소 가능한 경우 취소 함수 반환
      return () {
        Navigator.of(context).pop();
        final reservationId = r['reservation_id'] ?? '';
        widget.onCancel(reservationId, tsDate, tsStart);
      };
    } catch (e) {
      // 날짜 파싱 오류 시 취소 불가
      return null;
    }
  }

  // 취소 버튼 툴팁 메시지 반환
  String _getCancelButtonTooltip(Map<String, dynamic> r) {
    if (r['ts_status'] == '예약취소') {
      return '이미 취소된 예약입니다';
    }
    
    if (r['ts_status'] != '결제완료') {
      return '현재 상태에서는 취소할 수 없습니다';
    }
    
    final now = DateTime.now();
    final tsDate = r['ts_date'] ?? '';
    final tsStart = r['ts_start'] ?? '';
    
    try {
      final reservationDateTime = DateTime.parse('${tsDate}T$tsStart');
      final difference = reservationDateTime.difference(now);
      
      if (difference.isNegative) {
        return '이미 지난 예약은 취소할 수 없습니다';
      }
      
      if (difference.inHours < 1) {
        return '예약 시작 1시간 전까지만 취소가 가능합니다';
      }
      
      return '예약을 취소하려면 클릭하세요';
    } catch (e) {
      return '예약 정보 오류';
    }
  }
} 