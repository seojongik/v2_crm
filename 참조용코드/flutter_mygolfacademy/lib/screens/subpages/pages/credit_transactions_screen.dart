import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:famd_clientapp/models/credit_transaction.dart';
import 'package:famd_clientapp/providers/user_provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CreditTransactionsScreen extends StatefulWidget {
  const CreditTransactionsScreen({Key? key}) : super(key: key);

  @override
  State<CreditTransactionsScreen> createState() => _CreditTransactionsScreenState();
}

class _CreditTransactionsScreenState extends State<CreditTransactionsScreen> {
  List<CreditTransaction> _transactions = [];
  bool _isLoading = true;
  String? _error;
  
  @override
  void initState() {
    super.initState();
    _loadCreditTransactions();
  }

  // API에서 크레딧 내역 로드 - dynamic_api.php 사용
  Future<void> _loadCreditTransactions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (kDebugMode) {
        print('크레딧 내역 로드 시작');
      }
      
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      
      // 사용자가 로그인되어 있는지 확인
      if (userProvider.user == null) {
        if (kDebugMode) {
          print('로그인되지 않은 상태: 로그인 필요 예외 발생');
        }
        throw Exception('로그인이 필요합니다.');
      }

      if (kDebugMode) {
        print('로그인된 사용자 ID: ${userProvider.user!.id}');
      }

      // dynamic_api.php를 직접 사용하여 크레딧 내역 가져오기
      final response = await http.post(
        Uri.parse('https://autofms.mycafe24.com/dynamic_api.php'),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'FlutterApp/1.0'
        },
        body: jsonEncode({
          'operation': 'get',
          'table': 'v2_bills',
          'where': [
            {
              'field': 'member_id',
              'operator': '=',
              'value': userProvider.user!.id.toString()
            },
            if (userProvider.currentBranchId != null && userProvider.currentBranchId!.isNotEmpty)
              {
                'field': 'branch_id',
                'operator': '=',
                'value': userProvider.currentBranchId!
              }
          ],
          'orderBy': [
            {
              'field': 'bill_id',
              'direction': 'DESC'
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        if (kDebugMode) {
          print('API 응답: ${jsonEncode(responseData)}');
        }

        if (responseData['success'] == true && responseData['data'] != null) {
          final List<dynamic> billsData = responseData['data'];
          List<CreditTransaction> transactions = [];
          
          if (kDebugMode) {
            print('조회된 크레딧 내역 수: ${billsData.length}');
          }
          
          // 크레딧 내역 리스트 생성
          for (var item in billsData) {
            try {
              // null 값 처리
              final deduction = item['bill_deduction'] == null ? 0 : int.parse(item['bill_deduction'].toString());
              
              transactions.add(CreditTransaction(
                date: DateTime.parse(item['bill_date']),
                type: _getTransactionType(item['bill_type']),
                description: item['bill_text'] ?? '',
                amount: int.parse(item['bill_totalamt'].toString()),
                deduction: deduction,
                netAmount: int.parse(item['bill_netamt'].toString()),
                balance: int.parse(item['bill_balance_after'].toString()),
                status: item['bill_status']?.toString() ?? 'completed',
              ));
            } catch (e) {
              if (kDebugMode) {
                print('데이터 변환 중 오류: $e, 데이터: ${jsonEncode(item)}');
              }
              // 오류가 발생하면 해당 항목은 건너뛰기
              continue;
            }
          }
          
          if (kDebugMode) {
            print('성공적으로 변환된 거래 내역 수: ${transactions.length}');
          }

          setState(() {
            _transactions = transactions;
            _isLoading = false;
          });
        } else {
          // API 호출은 성공했지만 데이터 없음
          final errorMessage = responseData['error'] ?? '크레딧 내역이 없습니다.';
          if (kDebugMode) {
            print('API 응답 오류: $errorMessage');
          }
          
          setState(() {
            _transactions = [];
            _isLoading = false;
          });
        }
      } else {
        throw Exception('API 응답 오류: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('크레딧 내역 로드 오류: $e');
      }

      setState(() {
        _error = '데이터를 불러오는 중 오류가 발생했습니다: $e';
        _isLoading = false;
      });
    }
  }

  // bill_type에 따른 거래 유형 반환 헬퍼 메소드
  String _getTransactionType(String billType) {
    // 영문 타입을 한글로 변환
    if (billType.toLowerCase() == 'deposit') {
      return '수동적립';
    } else if (billType.toLowerCase() == 'withdraw') {
      return '수동차감';
    } else if (billType.toLowerCase().contains('membership') || 
              billType.toLowerCase().contains('회원권')) {
      return '회원권구매';
    }
    
    // 그 외의 경우 원래 값 그대로 사용
    return billType;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('크레딧 이용 내역'),
        actions: [
          // 새로고침 버튼 추가
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCreditTransactions,
            tooltip: '새로고침',
          ),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorView()
              : Column(
                  children: [
                    _buildCurrentBalance(),
                    _buildTransactionList(),
                  ],
                ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 60,
            color: Colors.red.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            '데이터를 불러올 수 없습니다',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _error ?? '알 수 없는 오류가 발생했습니다.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadCreditTransactions,
            icon: const Icon(Icons.refresh),
            label: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentBalance() {
    // 현재 잔액이 있는지 확인
    int currentBalance = _transactions.isNotEmpty ? _transactions.first.balance : 0;
    
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '현재 잔액',
            style: GoogleFonts.notoSans(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${NumberFormat('#,###').format(currentBalance)} c',
            style: GoogleFonts.notoSans(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade900,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList() {
    if (_transactions.isEmpty) {
      return Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.receipt_long,
                size: 64,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                '크레딧 내역이 없습니다',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    // 날짜별로 그룹화하기 위한 맵 생성
    Map<String, List<CreditTransaction>> groupedTransactions = {};
    
    for (var transaction in _transactions) {
      // 날짜를 yyyy-MM-dd 형식의 문자열로 변환하여 키로 사용
      String dateKey = DateFormat('yyyy-MM-dd').format(transaction.date);
      
      if (!groupedTransactions.containsKey(dateKey)) {
        groupedTransactions[dateKey] = [];
      }
      
      groupedTransactions[dateKey]!.add(transaction);
    }
    
    // 날짜 키 목록을 역순으로 정렬 (최신순)
    List<String> sortedDates = groupedTransactions.keys.toList()
      ..sort((a, b) => b.compareTo(a));
    
    return Expanded(
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: sortedDates.length,
        itemBuilder: (context, index) {
          String dateKey = sortedDates[index];
          List<CreditTransaction> dayTransactions = groupedTransactions[dateKey]!;
          
          // 날짜 표시 포맷 변경 (yyyy-MM-dd -> yyyy년 MM월 dd일)
          DateTime date = DateTime.parse(dateKey);
          String formattedDate = DateFormat('yyyy년 MM월 dd일').format(date);
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 날짜 헤더
              Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 8),
                child: Text(
                  formattedDate,
                  style: GoogleFonts.notoSans(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
              // 해당 날짜의 거래 내역
              ...dayTransactions.map((transaction) => _buildTransactionItem(transaction)).toList(),
              // 날짜 구분선
              if (index < sortedDates.length - 1)
                Divider(color: Colors.grey.shade200, height: 32),
            ],
          );
        },
      ),
    );
  }
  
  Widget _buildTransactionItem(CreditTransaction transaction) {
    // 거래 유형 판별
    bool isDeposit = false;
    bool isWithdraw = false;
    
    // 적립(수입) 유형 판별 - '수동적립', '적립' 포함 또는 금액이 양수인 경우
    if (transaction.type.contains('적립') || transaction.netAmount > 0) {
      isDeposit = true;
    }
    
    // 차감(지출) 유형 판별 - '수동차감', '사용' 포함 또는 금액이 음수인 경우
    if (transaction.type.contains('차감') || 
        transaction.type.contains('사용') || 
        transaction.netAmount < 0) {
      isDeposit = false;
      isWithdraw = true;
    }
    
    // 색상 설정
    final Color amountColor;
    if (transaction.netAmount > 0) {
      amountColor = Colors.green.shade700;  // 양수(적립)는 녹색
    } else if (transaction.netAmount < 0) {
      amountColor = Colors.red.shade700;    // 음수(차감)는 빨간색
    } else {
      amountColor = Colors.black;           // 0원은 검정색
    }
    
    // 텍스트 형식
    String amountText;
    if (transaction.netAmount == 0) {
      amountText = "0";
    } else if (transaction.netAmount < 0) {
      // 음수인 경우 부호를 앞에 표시하고 절대값으로 포맷
      amountText = NumberFormat('-#,###').format(transaction.netAmount.abs());
    } else {
      // 양수인 경우 그대로 포맷
      amountText = NumberFormat('#,###').format(transaction.netAmount);
    }
    
    // c 단위 추가
    amountText = "$amountText c";
    
    // 카드 스타일 설정 - 모든 항목에 완전히 동일한 테두리 적용
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300, width: 1.0), // 모든 항목에 동일한 테두리 적용
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: isDeposit
              ? Colors.green.shade50 
              : Colors.pink.shade50,
          child: Icon(
            isDeposit ? Icons.add : Icons.remove,
            color: isDeposit ? Colors.green.shade600 : Colors.pink.shade300,
            size: 20,
          ),
        ),
        title: Text(
          transaction.description,
          style: GoogleFonts.notoSans(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade800,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            transaction.type,
            style: GoogleFonts.notoSans(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.normal,
            ),
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // 금액 (c 단위 포함)
            Text(
              amountText,
              style: GoogleFonts.notoSans(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: amountColor,
              ),
            ),
            const SizedBox(height: 6),
            // 잔액 (c 단위 포함)
            Text(
              '잔액: ${NumberFormat('#,###').format(transaction.balance)} c',
              style: GoogleFonts.notoSans(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }
} 