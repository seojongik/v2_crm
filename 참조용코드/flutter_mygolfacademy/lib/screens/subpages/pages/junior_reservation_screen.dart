import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async'; // TimeoutException을 위한 import 추가
import 'package:http/http.dart' as http;
import 'package:famd_clientapp/services/api_service.dart';
import 'package:famd_clientapp/services/ls_countings_service.dart';
import 'package:famd_clientapp/models/staff.dart'; // Staff 모델 추가
import 'package:famd_clientapp/services/junior_lesson_service.dart'; // 주니어 레슨 서비스 추가
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:famd_clientapp/providers/user_provider.dart';

/// 주니어 골프스쿨 예약 화면
/// 공사중 메시지를 보여주면서 주니어 관계 정보를 조회합니다.
class JuniorReservationScreen extends StatefulWidget {
  final int? memberId;

  const JuniorReservationScreen({
    Key? key,
    required this.memberId,
  }) : super(key: key);

  @override
  State<JuniorReservationScreen> createState() => _JuniorReservationScreenState();
}

class _JuniorReservationScreenState extends State<JuniorReservationScreen> {
  bool _isLoading = true;
  String _message = '';
  // 스태프 정보를 저장할 맵 변수 추가
  Map<String, Staff> _staffMap = {};
  
  // 예약 가능 시간대를 저장할 변수 추가
  List<Map<String, int>> _availableBlocks = [];
  
  // 주니어 예약 가능 시간 세트 목록 (UI 표시용)
  List<Map<String, dynamic>> _availableTimeSets = [];
  
  // 단계별 예약을 위한 변수들
  int _currentStep = 0; // 현재 단계
  Map<String, dynamic>? _selectedContract; // 선택된 계약
  DateTime _selectedDate = DateTime.now(); // 선택된 날짜
  TimeOfDay? _selectedTime; // 선택된 시간
  Map<String, dynamic>? _selectedTimeSet; // 선택된 시간 세트
  int? _selectedTS; // 선택된 타석
  
  // 주니어 관계 정보
  List<Map<String, dynamic>> _juniorRelations = [];
  
  // 선택된 주니어 정보
  Map<String, dynamic>? _selectedJunior;
  
  // 선택된 주니어의 계약 목록
  List<Map<String, dynamic>> _juniorContracts = [];
  
  // 타석 예약 상태
  bool _checkingTS = false;
  
  // 스크롤 컨트롤러 추가
  final ScrollController _scrollController = ScrollController();
  
  @override
  void initState() {
    super.initState();
    print('🚨🚨🚨🚨🚨 [주니어 예약] INIT STATE 호출됨!!! - ${DateTime.now()}');
    print('🔍 [주니어 예약] Member ID: ${widget.memberId}');
    
    // 위젯이 완전히 빌드된 후에 데이터 로딩 시작
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      print('📱 [주니어 예약] PostFrameCallback 실행됨');
      
      // Staff 목록을 먼저 로드
      await _loadStaffList();
      
      // Staff 로드 완료 후 주니어 관계 정보 로드
      await _loadJuniorRelations();
    });
    
    print('✅ [주니어 예약] INIT STATE 완료됨!!! - ${DateTime.now()}');
  }
  
  // 스태프 목록을 로드하는 함수
  Future<void> _loadStaffList() async {
    // 매우 눈에 띄는 로그 추가
    for (int i = 0; i < 5; i++) {
      print('📞📞📞📞📞 [주니어 예약] _loadStaffList 호출됨!!! ($i) 📞📞📞📞📞');
    }
    
    try {
      print('\n🔍 [주니어 예약] ===== Staff 목록 로드 시작 =====');
      print('🔍 [주니어 예약] ApiService.getStaffList() 호출 전');
      
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final staffList = await ApiService.getStaffList(branchId: userProvider.currentBranchId);
      
      print('🔍 [주니어 예약] ApiService.getStaffList() 호출 완료');
      print('🔍 [주니어 예약] 받은 Staff 목록 수: ${staffList.length}');
      
      if (staffList.isEmpty) {
        print('❌ [주니어 예약] Staff 목록이 비어있습니다!');
        print('❌ [주니어 예약] API 호출은 성공했지만 데이터가 없거나 오류가 발생했습니다.');
        return;
      }
      
      // Staff 목록을 맵으로 변환
      Map<String, Staff> staffMap = {};
      
      print('🔍 [주니어 예약] Staff 목록을 맵으로 변환 시작');
      for (var staff in staffList) {
        if (staff.name.isNotEmpty) {
          final trimmedName = staff.name.trim();
          staffMap[trimmedName] = staff;
          print('🔍 [주니어 예약] Staff 추가: "${trimmedName}" -> 닉네임: "${staff.nickname}"');
        } else {
          print('⚠️ [주니어 예약] 이름이 비어있는 Staff 발견: ${staff.toString()}');
        }
      }
      
      setState(() {
        _staffMap = staffMap;
      });
      
      print('✅ [주니어 예약] Staff 목록을 맵으로 변환 완료');
      print('✅ [주니어 예약] Staff 맵 키들: ${_staffMap.keys.toList()}');
      print('✅ [주니어 예약] Staff 맵 크기: ${_staffMap.length}');
      
      // 이재윤 강사가 있는지 직접 확인
      if (_staffMap.containsKey('이재윤')) {
        print('✅ [주니어 예약] "이재윤" 강사 찾음: ${_staffMap['이재윤']?.nickname}');
      } else {
        print('❌ [주니어 예약] "이재윤" 강사를 찾을 수 없음');
        print('❌ [주니어 예약] 사용 가능한 강사 목록:');
        _staffMap.forEach((name, staff) {
          print('   - "$name" (닉네임: ${staff.nickname})');
        });
      }
      
      print('🔍 [주니어 예약] ===== Staff 목록 로드 완료 =====\n');
      
    } catch (e, stackTrace) {
      print('❌ [주니어 예약] Staff 목록 로드 오류: $e');
      print('❌ [주니어 예약] 스택 트레이스: $stackTrace');
    }
  }

  // 주니어 관계 정보를 조회하는 함수 수정
  Future<void> _loadJuniorRelations() async {
    setState(() {
      _isLoading = true;
      _message = '주니어 관계 정보를 조회 중입니다...';
    });

    // 회원 ID가 없는 경우 처리
    if (widget.memberId == null) {
      print('❌ 회원 ID가 없습니다. 로그인 후 이용해주세요.');
      setState(() {
        _isLoading = false;
        _message = '회원 정보가 필요합니다. 로그인 후 이용해주세요.';
      });
      return;
    }

    try {
      print('🔍 [시작] 주니어 관계 정보 조회 시작');
      print('📡 [API 요청] 회원 ID: ${widget.memberId}의 주니어 관계 정보 조회');

      // ApiService를 사용하여 주니어 관계 정보 조회
      final response = await ApiService.getJuniorRelations(widget.memberId.toString());
      
      print('📡 [API 응답] 데이터: $response');

      if (response['success'] == true) {
        // 주니어 관계 정보(자식 관계)
        final juniorRelations = List<Map<String, dynamic>>.from(response['data'] ?? []);
        
        setState(() {
          _isLoading = false;
          _juniorRelations = juniorRelations;
          if (juniorRelations.isNotEmpty) {
            _selectedJunior = juniorRelations.first;
            _loadJuniorContracts(_selectedJunior!['junior_member_id'].toString());
          } else {
            _message = '연결된 주니어 관계가 없습니다.';
          }
        });
      } else {
        print('❌ API 오류: ${response['error'] ?? '알 수 없는 오류'}');
        setState(() {
          _isLoading = false;
          _message = '주니어 관계 정보를 가져오는 중 오류가 발생했습니다: ${response['error'] ?? '알 수 없는 오류'}';
        });
      }
    } catch (e) {
      print('❌ 주니어 관계 정보 조회 중 예외 발생: $e');
      print('❌ 스택 트레이스: ${StackTrace.current}');
      setState(() {
        _isLoading = false;
        _message = '오류 발생: $e';
      });
    } finally {
      print('🔍 [완료] 주니어 관계 정보 조회 요청 종료');
    }
  }
  
  // 주니어 계약 정보 로드
  Future<void> _loadJuniorContracts(String juniorId) async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      
      setState(() {
        _isLoading = true;
        _message = '주니어 계약 정보를 가져오는 중...';
      });
      
      // WHERE 조건 구성
      final whereConditions = [
        {'field': 'member_id', 'operator': '=', 'value': juniorId}
      ];
      
      // branchId가 있는 경우 조건에 추가
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
          'table': 'v2_LS_contracts',
          'where': whereConditions,
          'orderBy': [
            {'field': 'LS_contract_date', 'direction': 'DESC'}
          ]
        }),
      );
      
      print('📡 [API 요청] 주니어 ID: $juniorId의 계약 정보 조회 (dynamic_api 사용)');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true) {
          // 계약 정보
          final contracts = List<Map<String, dynamic>>.from(data['data'] ?? []);
          
          print('📋 주니어 계약 정보 조회 결과: ${contracts.length}개의 계약 발견');
          
          // 잔여 레슨 시간 정보 가져오기
          final lessonData = await LSCountingsService.getLessonTypeBalances(
            juniorId,
            branchId: userProvider.currentBranchId,
          );
          final lessonTypes = List<Map<String, dynamic>>.from(lessonData['lessonTypes'] ?? []);
          
          // 계약 정보에 잔여 시간 추가
          for (var contract in contracts) {
            final contractId = contract['LS_contract_id']?.toString() ?? '';
            // 이 계약 ID에 해당하는 레슨 타입 찾기
            final lessonType = lessonTypes.firstWhere(
              (lt) => lt['contractId'].toString() == contractId,
              orElse: () => {'remainingLessons': 0, 'isValid': false}
            );
            
            contract['remainingLessons'] = lessonType['remainingLessons'] ?? 0;
            contract['isValid'] = lessonType['isValid'] ?? false;
            
            // 담당 프로 정보
            final proName = contract['LS_contract_pro']?.toString() ?? '';
            String staffNickname = '';
            
            if (proName.isNotEmpty) {
              // 공백 제거하여 비교
              String trimmedProName = proName.trim();
              print('🔍 프로 정보 찾기: 계약의 프로명="$proName", 트림된 프로명="$trimmedProName"');
              print('🔍 현재 Staff 맵 키들: ${_staffMap.keys.toList()}');
              
              if (_staffMap.containsKey(trimmedProName)) {
                staffNickname = _staffMap[trimmedProName]!.nickname;
                print('✅ 프로 정보 찾음: $trimmedProName -> 닉네임: $staffNickname');
              } else {
                print('⚠️ 담당 프로 정보를 찾을 수 없음: "$trimmedProName"');
                print('⚠️ 사용 가능한 프로 목록:');
                _staffMap.forEach((key, value) {
                  print('   - "$key" (닉네임: "${value.nickname}")');
                });
              }
            }
            
            // 계약 유형 분류
            String contractName = contract['contract_name'] ?? '';
            String contractType = '기타 레슨';
            if (contractName.startsWith('1:1')) {
              contractType = '1:1레슨';
            } else if (contractName.startsWith('2:1')) {
              contractType = '2:1레슨';
            }
            
            // 핵심 정보 출력
            print('📄 계약 ID: $contractId, 계약명: ${contract['contract_name'] ?? "계약명 없음"}, 유형: $contractType, 담당 프로: $proName, 닉네임: $staffNickname, 잔여 레슨: ${lessonType['remainingLessons'] ?? 0}분, 유효 여부: ${lessonType['isValid'] ?? false}');
          }
          
          setState(() {
            _juniorContracts = contracts;
            _isLoading = false;
            if (contracts.isNotEmpty) {
              // 유효한 계약이 있으면 첫 번째 유효한 계약을 선택
              final validContracts = contracts.where((c) => c['isValid'] == true).toList();
              if (validContracts.isNotEmpty) {
                _selectedContract = validContracts.first;
                // 계약 유형 분류
                String contractName = validContracts.first['contract_name'] ?? '';
                String contractType = '기타 레슨';
                if (contractName.startsWith('1:1')) {
                  contractType = '1:1레슨';
                } else if (contractName.startsWith('2:1')) {
                  contractType = '2:1레슨';
                }
                print('✅ 유효한 계약을 자동 선택했습니다: 계약 ID: ${validContracts.first['LS_contract_id']}, 계약명: ${validContracts.first['contract_name'] ?? "계약명 없음"}, 유형: $contractType');
              } else {
                _selectedContract = contracts.first;
                // 계약 유형 분류
                String contractName = contracts.first['contract_name'] ?? '';
                String contractType = '기타 레슨';
                if (contractName.startsWith('1:1')) {
                  contractType = '1:1레슨';
                } else if (contractName.startsWith('2:1')) {
                  contractType = '2:1레슨';
                }
                print('⚠️ 유효한 계약이 없어 첫 번째 계약을 선택했습니다: 계약 ID: ${contracts.first['LS_contract_id']}, 계약명: ${contracts.first['contract_name'] ?? "계약명 없음"}, 유형: $contractType');
              }
            }
          });
          
          print('📋 [주니어 계약 정보 로드 완료] 총 ${contracts.length}개의 계약, 유효한 계약: ${contracts.where((c) => c['isValid'] == true).length}개');
        } else {
          print('❌ API 오류: ${data['error'] ?? '알 수 없는 오류'}');
          setState(() {
            _isLoading = false;
            _juniorContracts = [];
            _message = '계약 정보를 가져오는 중 오류가 발생했습니다';
          });
        }
      } else {
        print('❌ API 요청 실패: ${response.statusCode}');
        setState(() {
          _isLoading = false;
          _juniorContracts = [];
          _message = '서버 연결에 실패했습니다';
        });
      }
    } catch (e) {
      print('❌ 주니어 계약 정보 조회 중 예외 발생: $e');
      setState(() {
        _isLoading = false;
        _juniorContracts = [];
        _message = '오류 발생: $e';
      });
    }
  }
  
  // 주니어 선택 시 호출되는 함수
  void _onJuniorSelected(Map<String, dynamic> junior) {
    setState(() {
      _selectedJunior = junior;
      _selectedContract = null;
      _currentStep = 0; // 주니어가 변경되면 첫 단계로 되돌아감
    });
    _loadJuniorContracts(junior['junior_member_id'].toString());
  }

  @override
  Widget build(BuildContext context) {
    // 앱 테마 색상 정의 - 갈색 테마
    final Color primaryColor = const Color(0xFF5D4037); // 갈색 기본 테마

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA), // 매우 연한 회색 배경
      appBar: AppBar(
        title: const Text(
          '주니어 골프스쿨 예약',
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
          // 새로고침 버튼 추가
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadJuniorRelations,
            tooltip: '새로고침',
          ),
        ],
      ),
      body: _isLoading 
        ? _buildLoadingView(primaryColor)
        : _juniorRelations.isEmpty 
          ? _buildNoJuniorView(primaryColor)
          : _buildStepperView(primaryColor),
    );
  }
  
  // 로딩 화면
  Widget _buildLoadingView(Color primaryColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
          ),
          const SizedBox(height: 16),
          Text(
            _message,
            style: TextStyle(color: primaryColor, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  // 주니어 관계가 없는 경우
  Widget _buildNoJuniorView(Color primaryColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.child_care, size: 64, color: primaryColor),
            const SizedBox(height: 16),
            Text(
              '주니어 관계가 없습니다',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '주니어 골프스쿨 예약을 위해서는 먼저 주니어 관계를 등록해주세요.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('이전 화면으로'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // 스텝퍼 화면 (주니어 골프스쿨 예약 플로우)
  Widget _buildStepperView(Color primaryColor) {
    return Column(
      children: [
        // 주니어 선택 드롭다운
        if (_juniorRelations.length > 1)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: '주니어 선택',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              value: _selectedJunior?['junior_member_id'].toString(),
              items: _juniorRelations.map((junior) {
                return DropdownMenuItem<String>(
                  value: junior['junior_member_id'].toString(),
                  child: Text('${junior['junior_name']} (${junior['relation']})'),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  final selected = _juniorRelations.firstWhere(
                    (junior) => junior['junior_member_id'].toString() == value
                  );
                  _onJuniorSelected(selected);
                }
              },
            ),
          ),
        
        Expanded(
          child: Stepper(
            type: StepperType.vertical,
            currentStep: _currentStep,
            onStepTapped: (step) {
              setState(() {
                _currentStep = step;
                
                // 날짜 선택 단계로 이동하면 스케줄 정보 자동 출력
                if (step == 1 && _selectedContract != null) {
                  _loadSelectedDateSchedule();
                }
              });
            },
            onStepContinue: () {
              // 다음 단계로 이동 전에 유효성 검사
              if (_currentStep == 0 && _selectedContract == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('계약을 선택해 주세요')),
                );
                return;
              }
              
              // 시간 선택 단계에서 시간이 선택되지 않았을 경우
              if (_currentStep == 1 && _selectedTimeSet == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('예약 시간을 선택해 주세요')),
                );
                return;
              }

              // 타석 확인 단계에서 타석이 선택되지 않은 경우
              if (_currentStep == 2 && _selectedTS == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('이용 가능한 타석이 없습니다. 다른 시간을 선택해 주세요.')),
                );
                return;
              }
              
              if (_currentStep < 3) {
                setState(() {
                  _currentStep += 1;
                  
                  // 날짜 선택 단계로 이동하면 스케줄 정보 자동 출력
                  if (_currentStep == 1 && _selectedContract != null) {
                    _loadSelectedDateSchedule();
                  }
                });
              } else {
                // 최종 예약 처리 로직 (노란색 버튼에 구현되어 있음)
                // 이 부분은 사용하지 않음
              }
            },
            onStepCancel: () {
              if (_currentStep > 0) {
                setState(() {
                  _currentStep -= 1;
                });
              }
            },
            controlsBuilder: (context, details) {
              // 마지막 단계(예약 확인 화면)에서는 버튼 표시하지 않음
              if (_currentStep == 3) {
                return const SizedBox.shrink(); // 버튼 영역 완전히 제거
              }
              
              // 현재 단계에 따른 다음 버튼 활성화 여부
              bool isNextButtonEnabled = true;
              
              if (_currentStep == 0 && _selectedContract == null) {
                isNextButtonEnabled = false;
              } else if (_currentStep == 1 && _selectedTimeSet == null) {
                isNextButtonEnabled = false;
              }
              
              return Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Row(
                  children: [
                    if (_currentStep > 0)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: details.onStepCancel,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey.shade700,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('이전'),
                        ),
                      ),
                    if (_currentStep > 0)
                      const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isNextButtonEnabled ? details.onStepContinue : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey.shade300,
                          disabledForegroundColor: Colors.grey.shade500,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('다음'),
                      ),
                    ),
                  ],
                ),
              );
            },
            steps: [
              Step(
                title: const Text('계약 선택'),
                content: _buildContractSelection(),
                isActive: _currentStep >= 0,
              ),
              Step(
                title: const Text('날짜/시간 선택'),
                subtitle: null, // 파란색 글씨 제거
                content: _buildDateSelection(),
                isActive: _currentStep >= 1,
              ),
              Step(
                title: const Text('타석 확인'),
                subtitle: null, // 파란색 글씨 제거
                content: _buildTeeingStationConfirmation(),
                isActive: _currentStep >= 2,
              ),
              Step(
                title: const Text('예약 확인'),
                content: _buildReservationSummary(),
                isActive: _currentStep >= 3,
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  // 계약 선택 위젯
  Widget _buildContractSelection() {
    if (_juniorContracts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.orange),
              const SizedBox(height: 16),
              Text(
                '${_selectedJunior?['junior_name'] ?? '선택된 주니어'}님의 유효한 계약이 없습니다',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _juniorContracts.length,
      itemBuilder: (context, index) {
        final contract = _juniorContracts[index];
        final bool isSelected = _selectedContract != null && 
                               _selectedContract!['LS_contract_id'] == contract['LS_contract_id'];
        final bool isValid = contract['isValid'] == true;
        
        // 계약 ID와 주요 정보 저장
        final contractId = contract['LS_contract_id']?.toString() ?? '';
        final remainingLessons = contract['remainingLessons'] ?? 0;
        
        // 만료일 파싱해서 만료 여부 판단
        DateTime? expiryDate;
        bool isExpired = false;
        String expiryText = '';
        
        if (contract['LS_expiry_date'] != null && contract['LS_expiry_date'].toString().isNotEmpty) {
          try {
            expiryDate = DateTime.parse(contract['LS_expiry_date'].toString());
            isExpired = expiryDate.isBefore(DateTime.now());
            final diffDays = expiryDate.difference(DateTime.now()).inDays;
            expiryText = isExpired 
              ? '만료됨 ❌ - ${-diffDays}일 지남' 
              : '유효함 ✅ - ${diffDays}일 남음';
          } catch (e) {
            print('⚠️ 만료일 파싱 오류: ${e}');
          }
        }
        
        // 담당 프로 정보 가져오기
        final proName = contract['LS_contract_pro']?.toString() ?? '';
        String proDisplayText = proName;
        String staffNickname = '';
        
        if (proName.isNotEmpty) {
          // 공백 제거하여 비교
          String trimmedProName = proName.trim();
          print('🔍 UI 프로 정보 찾기: 계약의 프로명="$proName", 트림된 프로명="$trimmedProName"');
          
          if (_staffMap.containsKey(trimmedProName)) {
            staffNickname = _staffMap[trimmedProName]!.nickname;
            if (staffNickname.isNotEmpty) {
              proDisplayText = '$proName (닉네임: $staffNickname)';
            }
            print('✅ UI 프로 정보 찾음: $trimmedProName -> 닉네임: $staffNickname');
          } else {
            print('⚠️ UI에서 담당 프로 정보를 찾을 수 없음: "$trimmedProName"');
          }
        }
        
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedContract = contract;
              
              // 선택 시 주요 정보 출력
              print('✅ 계약 선택됨: 계약 ID: $contractId, 담당 프로: $proName, 닉네임: $staffNickname, 잔여 레슨: $remainingLessons분, 유효 여부: $isValid');
            });
          },
          child: Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: isSelected 
                  ? Theme.of(context).primaryColor 
                  : Colors.grey.shade300,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected 
                  ? Colors.brown.shade50 
                  : (isValid ? Colors.white : Colors.grey.shade100),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          contract['contract_name'] ?? '계약명 없음',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isValid ? Colors.black87 : Colors.grey.shade600,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isValid 
                            ? Colors.green.shade100 
                            : Colors.red.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isValid ? '유효함' : '만료됨',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isValid 
                              ? Colors.green.shade700 
                              : Colors.red.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // 계약 세부 정보 - 계약 ID 추가
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 계약 ID 표시 제거
                            // _buildInfoRow(Icons.bookmark, '계약 ID: $contractId'),
                            // const SizedBox(height: 4),
                            
                            // 잔여 시간을 회수로 변환하여 표시
                            _buildInfoRow(Icons.schedule, '잔여 횟수: ${(remainingLessons / 30).ceil()}회'),
                            const SizedBox(height: 4),
                            
                            // 닉네임 정보 제외하고 프로 이름만 표시
                            _buildInfoRow(Icons.person, '담당 프로: $proName'),
                            const SizedBox(height: 4),
                            if (expiryDate != null)
                              _buildInfoRow(
                                Icons.event_available, 
                                '만료일: ${expiryDate.year}-${expiryDate.month.toString().padLeft(2, '0')}-${expiryDate.day.toString().padLeft(2, '0')} ($expiryText)'
                              ),
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
      },
    );
  }
  
  // 정보 행 위젯 (아이콘 + 텍스트)
  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
  
  // 날짜 선택 위젯
  Widget _buildDateSelection() {
    // 계약이 선택되지 않은 경우
    if (_selectedContract == null) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.warning_amber, size: 48, color: Colors.orange),
              const SizedBox(height: 16),
              const Text(
                '먼저 계약을 선택해주세요',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }
    
    // 계약 정보 확인
    final contractId = _selectedContract!['LS_contract_id']?.toString() ?? '';
    final contractName = _selectedContract!['contract_name'] ?? '계약명 없음';
    final proName = _selectedContract!['LS_contract_pro']?.toString() ?? '프로 정보 없음';
    
    // 만료일 계산
    DateTime? expiryDate;
    if (_selectedContract!['LS_expiry_date'] != null && 
        _selectedContract!['LS_expiry_date'].toString().isNotEmpty) {
      try {
        expiryDate = DateTime.parse(_selectedContract!['LS_expiry_date'].toString());
      } catch (e) {
        print('⚠️ 만료일 파싱 오류: ${e}');
      }
    }
    
    // 달력 설정
    final firstDay = DateTime.now();
    final lastDay = expiryDate ?? DateTime.now().add(const Duration(days: 60));
    
    return SingleChildScrollView(
      child: Column(
        children: [
          
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: TableCalendar(
                firstDay: firstDay,
                lastDay: lastDay,
                focusedDay: _selectedDate,
                calendarFormat: CalendarFormat.month,
                availableCalendarFormats: const {
                  CalendarFormat.month: '달력',
                },
                selectedDayPredicate: (day) {
                  return day.year == _selectedDate.year &&
                      day.month == _selectedDate.month &&
                      day.day == _selectedDate.day;
                },
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDate = selectedDay;
                    _selectedTimeSet = null;  // 날짜가 변경되면, 선택된 시간 초기화
                    
                    // 날짜 선택 시 주요 정보 출력
                    final formattedDate = DateFormat('yyyy-MM-dd').format(selectedDay);
                    print('📅 날짜 선택됨: $formattedDate, 계약 ID: $contractId, 담당 프로: $proName');
                    
                    // 담당 프로 닉네임 가져오기
                    String proNickname = '';
                    if (proName.isNotEmpty) {
                      String trimmedProName = proName.trim();
                      print('🔍 날짜 선택 시 프로 정보 찾기: 프로명="$proName", 트림된 프로명="$trimmedProName"');
                      
                      // Staff 맵이 비어있으면 즉시 로드
                      if (_staffMap.isEmpty) {
                        print('⚠️ [자동 선택] Staff 맵이 비어있음! 즉시 로드 시작...');
                        _loadStaffList().then((_) {
                          // Staff 로드 완료 후 프로 정보 다시 확인
                          if (_staffMap.containsKey(trimmedProName)) {
                            proNickname = _staffMap[trimmedProName]!.nickname;
                            print('✅ [자동 선택 로드 후] 프로 정보 찾음: $trimmedProName -> 닉네임: $proNickname');
                            // 프로 스케줄 조회 후 예약 가능 시간대 계산
                            _getStaffScheduleAndAvailability(proNickname, formattedDate, proName);
                          } else {
                            print('⚠️ [자동 선택 로드 후에도] 담당 프로 정보를 찾을 수 없음: $proName');
                            print('⚠️ [자동 선택 로드 후] 현재 Staff 맵 키들: ${_staffMap.keys.toList()}');
                          }
                        });
                        return; // Staff 로드 중이므로 여기서 리턴
                      }
                      
                      if (_staffMap.containsKey(trimmedProName)) {
                        proNickname = _staffMap[trimmedProName]!.nickname;
                        print('✅ 자동 날짜 선택 시 프로 정보 찾음: $trimmedProName -> 닉네임: $proNickname');
                        // 프로 스케줄 조회 후 예약 가능 시간대 계산
                        _getStaffScheduleAndAvailability(proNickname, formattedDate, proName);
                      } else {
                        print('⚠️ 담당 프로 정보를 찾을 수 없음: $proName');
                        print('⚠️ 현재 Staff 맵 키들: ${_staffMap.keys.toList()}');
                      }
                    }
                  });
                },
                headerStyle: HeaderStyle(
                  titleCentered: true,
                  formatButtonVisible: false,
                ),
                calendarStyle: CalendarStyle(
                  selectedDecoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    shape: BoxShape.circle,
                  ),
                  todayDecoration: BoxDecoration(
                    color: Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(color: Theme.of(context).primaryColor, width: 1.5),
                  ),
                  todayTextStyle: TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // 선택된 날짜 표시
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '선택된 날짜',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('yyyy년 MM월 dd일 (E)', 'ko_KR').format(_selectedDate),
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          
          // 예약 가능 시간 표시
          const SizedBox(height: 20),
          if (_availableTimeSets.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade100, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '예약 가능 시간',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // 아래 안내 메시지 제거
                  // Text(
                  //   '각 시간은 15분 레슨 2회(총 30분)와 25분 자율연습을 포함합니다.',
                  //   style: TextStyle(
                  //     fontSize: 11,
                  //     color: Colors.grey.shade600,
                  //   ),
                  // ),
                  const SizedBox(height: 12),
                  
                  // 시간 선택 타일 그리드
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 2.5,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: _availableTimeSets.length,
                    padding: const EdgeInsets.all(0),
                    itemBuilder: (context, index) {
                      final timeSet = _availableTimeSets[index];
                      final isSelected = _selectedTimeSet == timeSet;
                      
                      return _buildTimeSelectionTile(
                        timeSet,
                        isSelected,
                        () {
                          // 이미 선택된 시간을 다시 클릭하는 경우 아무 작업도 하지 않음
                          if (isSelected) return;
                          
                          // 시간 선택 시 상태 한 번에 업데이트
                          setState(() {
                            _selectedTimeSet = timeSet;
                            _selectedTime = TimeOfDay(
                              hour: timeSet['startMinutes'] ~/ 60,
                              minute: timeSet['startMinutes'] % 60
                            );
                            _selectedTS = null;
                            _checkingTS = true;
                          });
                          
                          print('⏰ 시간 선택됨: ${timeSet['startStr']}~${timeSet['endStr']} (주니어예약 세트)');
                          
                          // 타석 현황 조회는 백그라운드로 실행
                          _checkAvailableTeeingStations(timeSet).then((_) {
                            setState(() {
                              _checkingTS = false;
                            });
                          });
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ] else if (_isLoading) ...[
            const SizedBox(height: 20),
            Center(
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  Text(
                    '예약 가능한 시간을 계산 중입니다...',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                children: [
                  Icon(Icons.warning_amber, size: 40, color: Colors.orange),
                  const SizedBox(height: 8),
                  const Text(
                    '해당 날짜에 예약 가능한 시간이 없습니다',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepOrange,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '다른 날짜를 선택하거나 프로에게 문의해주세요',
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }
  
  // 선택된 날짜의 스케줄 정보를 자동으로 조회하는 함수
  void _loadSelectedDateSchedule() {
    if (_selectedContract == null) return;
    
    // 담당 프로 정보 가져오기
    final proName = _selectedContract!['LS_contract_pro']?.toString() ?? '';
    final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
    
    // 계약 유형 분류
    String contractName = _selectedContract!['contract_name'] ?? '';
    String contractType = '기타 레슨';
    if (contractName.startsWith('1:1')) {
      contractType = '1:1레슨';
    } else if (contractName.startsWith('2:1')) {
      contractType = '2:1레슨';
    }
    
    print('📅 [자동] 선택된 날짜: $formattedDate, 계약 ID: ${_selectedContract!['LS_contract_id']}, 계약명: $contractName, 유형: $contractType, 담당 프로: $proName');
    
    // 담당 프로 닉네임 가져와서 스케줄 조회
    if (proName.isNotEmpty) {
      String trimmedProName = proName.trim();
      print('🔍 자동 날짜 선택 시 프로 정보 찾기: 프로명="$proName", 트림된 프로명="$trimmedProName"');
      
      // Staff 맵이 비어있으면 즉시 로드
      if (_staffMap.isEmpty) {
        print('⚠️ [자동 선택] Staff 맵이 비어있음! 즉시 로드 시작...');
        _loadStaffList().then((_) {
          // Staff 로드 완료 후 프로 정보 다시 확인
          if (_staffMap.containsKey(trimmedProName)) {
            final proNickname = _staffMap[trimmedProName]!.nickname;
            print('✅ [자동 선택 로드 후] 프로 정보 찾음: $trimmedProName -> 닉네임: $proNickname');
            // 프로 스케줄 조회 후 예약 가능 시간대 계산
            _getStaffScheduleAndAvailability(proNickname, formattedDate, proName);
          } else {
            print('⚠️ [자동 선택 로드 후에도] 담당 프로 정보를 찾을 수 없음: $proName');
            print('⚠️ [자동 선택 로드 후] 현재 Staff 맵 키들: ${_staffMap.keys.toList()}');
          }
        });
        return; // Staff 로드 중이므로 여기서 리턴
      }
      
      if (_staffMap.containsKey(trimmedProName)) {
        final proNickname = _staffMap[trimmedProName]!.nickname;
        print('✅ 자동 날짜 선택 시 프로 정보 찾음: $trimmedProName -> 닉네임: $proNickname');
        // 프로 스케줄 조회 후 예약 가능 시간대 계산
        _getStaffScheduleAndAvailability(proNickname, formattedDate, proName);
      } else {
        print('⚠️ 담당 프로 정보를 찾을 수 없음: $proName');
        print('⚠️ 현재 Staff 맵 키들: ${_staffMap.keys.toList()}');
      }
    }
  }
  
  // 프로 스케줄 및 예약 가능 시간대 조회 함수
  Future<void> _getStaffScheduleAndAvailability(String staffNickname, String scheduledDate, String proName) async {
    if (staffNickname.isEmpty) {
      print('⚠️ 스케줄 조회 실패: 스태프 닉네임이 비어있습니다.');
      setState(() {
        _availableTimeSets = []; // 스태프 닉네임이 없는 경우 빈 배열 설정
      });
      return;
    }
    
    try {
      // 계약 유형 분류
      String contractName = _selectedContract!['contract_name'] ?? '';
      String contractType = '기타 레슨';
      if (contractName.startsWith('1:1')) {
        contractType = '1:1레슨';
      } else if (contractName.startsWith('2:1')) {
        contractType = '2:1레슨';
      }
      
      print('📡 [스케줄 및 예약 가능시간 조회] 스태프: $staffNickname, 날짜: $scheduledDate, 프로: $proName, 계약 유형: $contractType');
      
      // 1. 스태프 근무 스케줄 조회 - 먼저 날짜별 개별 스케줄(schedule_adjusted) 확인
      final scheduleUrl = 'https://autofms.mycafe24.com/dynamic_api.php';
      final headers = {
        'Content-Type': 'application/json; charset=utf-8',
        'Accept': 'application/json',
      };
      
      Map<String, dynamic>? schedule;
      
      // 1-1. 먼저 schedule_adjusted 테이블에서 해당 날짜의 개별 스케줄 확인
      print('📡 [1단계] schedule_adjusted 테이블에서 날짜별 개별 스케줄 조회 중...');
      final adjustedScheduleRequestData = {
        "operation": "get",
        "table": "schedule_adjusted",
        "where": [
          {"field": "staff_nickname", "operator": "=", "value": staffNickname},
          {"field": "scheduled_date", "operator": "=", "value": scheduledDate}
        ]
      };
      
      final adjustedScheduleBody = jsonEncode(adjustedScheduleRequestData);
      
      final adjustedScheduleResponse = await http.post(
        Uri.parse(scheduleUrl),
        headers: headers,
        body: adjustedScheduleBody,
      ).timeout(const Duration(seconds: 10));
      
      if (adjustedScheduleResponse.statusCode == 200) {
        final adjustedScheduleData = jsonDecode(adjustedScheduleResponse.body);
        if (adjustedScheduleData['success'] == true && 
            adjustedScheduleData['data'] != null && 
            (adjustedScheduleData['data'] as List).isNotEmpty) {
          schedule = (adjustedScheduleData['data'] as List)[0];
          print('✅ [1단계 성공] schedule_adjusted에서 날짜별 개별 스케줄을 찾았습니다!');
          print('📋 [개별 스케줄] 근무시간: ${schedule!['work_start']} ~ ${schedule['work_end']}');
        } else {
          print('ℹ️ [1단계] schedule_adjusted에 해당 날짜의 개별 스케줄이 없습니다.');
        }
      } else {
        print('⚠️ [1단계] schedule_adjusted API 요청 실패: ${adjustedScheduleResponse.statusCode}');
      }
      
      // 1-2. 개별 스케줄이 없으면 schedule_weekly_base에서 요일별 기본 스케줄 확인
      if (schedule == null) {
        print('📡 [2단계] schedule_weekly_base 테이블에서 요일별 기본 스케줄 조회 중...');
        final scheduleRequestData = {
          "operation": "get",
          "table": "schedule_weekly_base",
          "where": [
            {"field": "staff_nickname", "operator": "=", "value": staffNickname}
          ]
        };
        
        final scheduleBody = jsonEncode(scheduleRequestData);
        
        final scheduleResponse = await http.post(
          Uri.parse(scheduleUrl),
          headers: headers,
          body: scheduleBody,
        ).timeout(const Duration(seconds: 10));
        
        if (scheduleResponse.statusCode != 200) {
          print('❌ [2단계] 기본 스케줄 API 요청 실패: ${scheduleResponse.statusCode}');
          setState(() {
            _availableTimeSets = []; // API 요청 실패 시 빈 배열 설정
          });
          return;
        }
        
        final scheduleData = jsonDecode(scheduleResponse.body);
        if (scheduleData['success'] != true) {
          print('❌ [2단계] 기본 스케줄 API 오류: ${scheduleData['error'] ?? '알 수 없는 오류'}');
          setState(() {
            _availableTimeSets = []; // API 오류 시 빈 배열 설정
          });
          return;
        }
        
        // 스케줄 데이터에서 해당 요일의 스케줄 찾기
        final scheduleList = scheduleData['data'] as List<dynamic>;
        
        // 요일 계산 (0: 일요일, 1: 월요일, ..., 6: 토요일)
        final DateTime date = DateTime.parse(scheduledDate);
        final int weekday = date.weekday == 7 ? 0 : date.weekday; // DateTime.weekday: 1(월)~7(일) → DB weekday: 0(일)~6(토)
        
        print('📅 [요일 계산] 선택된 날짜: $scheduledDate');
        print('📅 [요일 계산] DateTime.weekday: ${date.weekday} → DB weekday: $weekday');
        
        for (final item in scheduleList) {
          print('📋 [스케줄 검색] DB weekday: ${item['weekday']}, 찾는 weekday: $weekday');
          if (item['weekday']?.toString() == weekday.toString()) {
            schedule = item;
            print('✅ [2단계 성공] schedule_weekly_base에서 요일별 기본 스케줄을 찾았습니다!');
            break;
          }
        }
      }
      
      // 최종적으로 스케줄을 찾지 못한 경우
      if (schedule == null) {
        print('❌ 해당 날짜의 스케줄 정보를 찾을 수 없습니다.');
        print('❌ v2_schedule_adjusted_pro와 schedule_weekly_base 모두에서 스케줄을 찾지 못했습니다.');
        setState(() {
          _availableTimeSets = [];
        });
        return;
      }
      
      // 스케줄 정보 디버깅
      print('📋 [최종 스태프 근무 스케줄]');
      print('🧑‍💼 스태프: $staffNickname, 날짜: $scheduledDate');
      print('⏰ 근무 시작: ${schedule['work_start'] ?? '정보 없음'}');
      print('⏰ 근무 종료: ${schedule['work_end'] ?? '정보 없음'}');
      print('☕ 휴식 시작: ${schedule['break_start'] ?? '정보 없음'}');
      print('☕ 휴식 종료: ${schedule['break_end'] ?? '정보 없음'}');
      print('🚫 휴무일 여부: ${schedule['is_day_off'] == '1' ? '휴무일' : '근무일'}');
      
      // 휴무일인 경우 처리
      if (schedule['is_day_off'] == '1') {
        print('🚫 선택한 날짜는 휴무일입니다. 예약이 불가능합니다.');
        setState(() {
          _availableBlocks = []; // 빈 배열로 초기화
          _availableTimeSets = []; // 휴무일인 경우 빈 배열 설정
        });
        return;
      }
      
      // 2. 근무 시간대 및 휴식 시간대 추출
      final String? workStartStr = schedule['work_start']?.toString();
      final String? workEndStr = schedule['work_end']?.toString();
      final String? breakStartStr = schedule['break_start']?.toString();
      final String? breakEndStr = schedule['break_end']?.toString();
      
      // 필수 시간 정보가 없는 경우 예약 불가능 처리
      if (workStartStr == null || workEndStr == null || 
          workStartStr.isEmpty || workEndStr.isEmpty) {
        print('❌ 근무 시간 정보가 없습니다. 예약이 불가능합니다.');
        setState(() {
          _availableBlocks = []; // 빈 배열로 초기화
          _availableTimeSets = []; // 근무 시간 정보가 없는 경우 빈 배열 설정
        });
        return;
      }
      
      final int workStart = _timeToMinutes(workStartStr);
      final int workEnd = _timeToMinutes(workEndStr);
      final int breakStart = breakStartStr != null && breakStartStr.isNotEmpty ? 
                             _timeToMinutes(breakStartStr) : 0;
      final int breakEnd = breakEndStr != null && breakEndStr.isNotEmpty ? 
                           _timeToMinutes(breakEndStr) : 0;
      
      // 근무 시간이 유효하지 않은 경우 처리
      if (workStart >= workEnd || workStart == 0 && workEnd == 0) {
        print('⚠️ [경고] 근무 시간 오류: 시작(${_minutesToTimeString(workStart)})이 종료(${_minutesToTimeString(workEnd)})보다 크거나 같습니다.');
        setState(() {
          _availableBlocks = []; // 빈 배열로 초기화
          _availableTimeSets = []; // 유효하지 않은 근무 시간인 경우 빈 배열 설정
        });
        return;
      }
      
      // 3. 이미 예약된 프로 일정 조회 - dynamic_api.php 사용
      print('📡 [프로 예약 현황 조회] 프로: $proName, 날짜: $scheduledDate');
      
      List<List<int>> reservedBlocks = [];
      
      try {
        final ordersRequestData = {
          "operation": "get",
          "table": "v2_LS_orders",
          "where": [
            {"field": "pro_id", "operator": "=", "value": proName},
            {"field": "LS_date", "operator": "=", "value": scheduledDate}
          ],
          "orderBy": [
            {"field": "LS_start_time", "direction": "ASC"}
          ]
        };
        
        final ordersBody = jsonEncode(ordersRequestData);
        
        print('📡 [API 요청 데이터] $ordersBody');
        
        final ordersResponse = await http.post(
          Uri.parse(scheduleUrl), // 같은 dynamic_api.php 사용
          headers: headers,
          body: ordersBody,
        ).timeout(const Duration(seconds: 10));
        
        print('📡 [API 응답 상태 코드] ${ordersResponse.statusCode}');
        
        if (ordersResponse.statusCode == 200) {
          final ordersData = jsonDecode(ordersResponse.body);
          print('📡 [API 응답 데이터] ${ordersResponse.body}');
          
          if (ordersData['success'] == true) {
            final orders = List<Map<String, dynamic>>.from(ordersData['data'] ?? []);
            print('📋 [프로 예약 현황] ${orders.length}개의 예약 확인됨');
            
            // 예약된 시간대 추출
            for (final order in orders) {
              final startTimeStr = order['LS_start_time']?.toString() ?? '';
              final endTimeStr = order['LS_end_time']?.toString() ?? '';
              
              if (startTimeStr.isNotEmpty && endTimeStr.isNotEmpty) {
                final startMinutes = _timeToMinutes(startTimeStr);
                final endMinutes = _timeToMinutes(endTimeStr);
                
                if (startMinutes < endMinutes) {
                  reservedBlocks.add([startMinutes, endMinutes]);
                  print('🔒 예약된 시간: ${startTimeStr} ~ ${endTimeStr}');
                }
              }
            }
          } else {
            print('⚠️ 프로 예약 현황 API 응답 오류: ${ordersData['error'] ?? '알 수 없는 오류'}');
            print('ℹ️ 예약 정보 없이 계산을 진행합니다.');
          }
        } else {
          print('⚠️ 프로 예약 현황 API 요청 실패: ${ordersResponse.statusCode}');
          print('ℹ️ 예약 정보 없이 계산을 진행합니다.');
        }
      } catch (e) {
        print('⚠️ 프로 예약 현황 조회 중 오류 발생: $e');
        print('⚠️ 스택 트레이스: ${StackTrace.current}');
        print('ℹ️ 예약 정보 없이 계산을 진행합니다.');
      }
      
      // 4. 예약 가능한 시간대 계산
      final availableBlocks = _getAvailableBlocks(
        workStart: workStart,
        workEnd: workEnd,
        reserved: reservedBlocks,
        breakRange: [breakStart, breakEnd],
      );
      
      // 5. 예약 가능한 시간이 있는지 확인
      if (availableBlocks.isEmpty) {
        print('❌ 예약 가능한 시간대가 없습니다.');
        setState(() {
          _availableBlocks = []; // 빈 배열로 초기화
          _availableTimeSets = []; // 예약 가능한 시간이 없는 경우 빈 배열 설정
        });
        return;
      }
      
      // 전역 변수에 저장
      setState(() {
        _availableBlocks = availableBlocks;
      });
      
      // 5. 가능한 시간대 출력
      print('\n📊 [예약 가능 시간대 계산 결과]');
      if (availableBlocks.isEmpty) {
        print('❌ 예약 가능한 시간대가 없습니다.');
      } else {
        print('✅ 총 ${availableBlocks.length}개의 예약 가능 시간대를 찾았습니다:');
        for (final block in availableBlocks) {
          final startHour = block['start']! ~/ 60;
          final startMinute = block['start']! % 60;
          final endHour = block['end']! ~/ 60;
          final endMinute = block['end']! % 60;
          
          final startTimeStr = '${startHour.toString().padLeft(2, '0')}:${startMinute.toString().padLeft(2, '0')}';
          final endTimeStr = '${endHour.toString().padLeft(2, '0')}:${endMinute.toString().padLeft(2, '0')}';
          
          print('🕒 ${startTimeStr} ~ ${endTimeStr} (${(block['end']! - block['start']!)} 분)');
        }
      }
      
      // 6. 30분 단위 시간대 리스트 생성 (디버깅용)
      print('\n📋 [30분 단위 시간대 리스트]');
      _generateTimeSlotsList(workStart, workEnd);
      
    } catch (e) {
      print('❌ 스케줄 및 예약 가능시간 조회 중 예외 발생: $e');
      print('스택 트레이스: ${StackTrace.current}');
      setState(() {
        _availableBlocks = []; // 빈 배열로 초기화
        _availableTimeSets = []; // 예외 발생 시 빈 배열 설정
      });
    }
  }
  
  // 30분 단위 시간대 리스트 생성 함수
  void _generateTimeSlotsList(int workStartMinutes, int workEndMinutes) {
    // 근무 종료 30분 전까지만 계산
    final endMinutes = workEndMinutes - 30;
    
    if (workStartMinutes >= endMinutes) {
      print('❌ 유효한 시간대가 없습니다. 근무 시간이 너무 짧습니다.');
      setState(() {
        _availableTimeSets = []; // 빈 배열로 설정
      });
      return;
    }
    
    // 예약 가능 시간대가 없는 경우
    if (_availableBlocks.isEmpty) {
      print('❌ 예약 가능한 시간대가 없습니다. 빈 시간 목록을 설정합니다.');
      setState(() {
        _availableTimeSets = []; // 빈 배열로 설정
      });
      return;
    }
    
    // 현재 시간을 분 단위로 계산 (오늘 날짜인 경우 사용)
    final now = DateTime.now();
    final currentTimeInMinutes = now.hour * 60 + now.minute;
    // 현재 시간에서 최소 15분 이후 시간 (여유 시간)
    final minAvailableTime = currentTimeInMinutes + 15;
    
    // 오늘 날짜인지 확인
    final today = DateTime(now.year, now.month, now.day);
    final selectedDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final isToday = today.isAtSameMomentAs(selectedDay);
    
    print('📅 선택된 날짜: ${DateFormat('yyyy-MM-dd').format(_selectedDate)}, 오늘 여부: ${isToday ? "오늘" : "미래 날짜"}');
    if (isToday) {
      print('⏰ 현재 시간: ${_minutesToTimeString(currentTimeInMinutes)}, 최소 예약 가능 시간: ${_minutesToTimeString(minAvailableTime)}');
    }
    
    // 시작 시간을 30분 단위로 조정 (올림)
    int currentMinutes = workStartMinutes;
    if (currentMinutes % 30 != 0) {
      currentMinutes = ((currentMinutes ~/ 30) + 1) * 30;
    }
    
    print('⏰ 근무 시간: ${_minutesToTimeString(workStartMinutes)} ~ ${_minutesToTimeString(workEndMinutes)}');
    
    // 예약 가능 시간대 요약 출력
    print('\n📋 [예약 가능 시간대 요약]');
    for (final block in _availableBlocks) {
      final startStr = _minutesToTimeString(block['start']!);
      final endStr = _minutesToTimeString(block['end']!);
      print('✅ $startStr ~ $endStr (${block['end']! - block['start']!} 분)');
    }
    
    print('\n📆 [주니어 예약 가능 세트 목록]');
    
    int count = 0;
    int availableSetCount = 0;
    List<Map<String, dynamic>> availableSets = [];
    
    // 시간 단위 정렬을 위해 처음 실행
    while (currentMinutes <= endMinutes) {
      count++;
      final timeStr = _minutesToTimeString(currentMinutes);
      
      // 세트 가능 여부 확인
      bool isSet1Available = _isTimeSlotAvailable(currentMinutes, currentMinutes + 15);
      bool isSet3Available = _isTimeSlotAvailable(currentMinutes + 30, currentMinutes + 45);
      bool isSetAvailable = isSet1Available && isSet3Available;
      
      // 오늘 날짜인 경우 현재 시간보다 15분 이후인지 확인
      if (isToday && currentMinutes < minAvailableTime) {
        print('⏰ $timeStr - 현재 시간보다 이전이므로 예약 불가');
        isSetAvailable = false;
      }
      
      if (isSetAvailable) {
        availableSetCount++;
        
        // 가능한 세트 정보 저장 (UI 표시용)
        availableSets.add({
          'startMinutes': currentMinutes,
          'endMinutes': currentMinutes + 55, // 55분 형태로 표시
          'startStr': timeStr,
          'endStr': _minutesToTimeString(currentMinutes + 55),
          'slot1Start': timeStr,
          'slot1End': _minutesToTimeString(currentMinutes + 15),
          'slot3Start': _minutesToTimeString(currentMinutes + 30),
          'slot3End': _minutesToTimeString(currentMinutes + 45),
        });
        
        // 세트 헤더 출력 (예약 가능한 경우만)
        final setTimeRange = "${timeStr} ~ ${_minutesToTimeString(currentMinutes + 55)}";
        print('✅ $setTimeRange - 예약1: ${timeStr}~${_minutesToTimeString(currentMinutes + 15)}, 예약3: ${_minutesToTimeString(currentMinutes + 30)}~${_minutesToTimeString(currentMinutes + 45)}');
      }
      
      currentMinutes += 30;
    }
    
    // 예약 가능 시간이 없는 경우 확인
    if (availableSets.isEmpty) {
      print('❌ 주니어 예약 가능한 시간대가 없습니다.');
    }
    
    // UI 업데이트 (가능한 시간대 목록)
    setState(() {
      _availableTimeSets = availableSets;
    });
    
    print('\n📊 [요약] 총 ${count}개의 시간대 중 ${availableSetCount}개 예약 가능');
  }
  
  // 15분 단위 세부 예약 시간 출력 함수
  void _printDetailedTimeSlots(int startMinutes, bool isSetAvailable) {
    // 세트 정보 표시만 하고 세부 정보는 생략 (UI에서 표시될 것임)
    if (isSetAvailable) {
      final timeStr = _minutesToTimeString(startMinutes);
      final setTimeRange = "${timeStr} ~ ${_minutesToTimeString(startMinutes + 55)}";
      print('✅ $setTimeRange - 주니어 예약 가능');
    }
  }
  
  // 특정 시간대가 예약 가능한지 체크하는 함수
  bool _isTimeSlotAvailable(int startMinutes, int endMinutes) {
    try {
      // 시간 비교를 통해 해당 시간대가 예약 가능한지 확인
      for (final block in _availableBlocks) {
        // 슬롯이 예약 가능 블록 내에 완전히 포함되는 경우
        if (block['start']! <= startMinutes && block['end']! >= endMinutes) {
          return true;
        }
      }
      
      // 예약 가능 블록에 포함되지 않으면 불가능
      return false;
    } catch (e) {
      print('⚠️ 예약 가능 여부 확인 중 오류: $e');
      return false;  // 오류 발생 시 안전하게 불가능으로 처리
    }
  }
  
  // 시간 문자열(HH:MM:SS)을 분 단위 정수로 변환하는 유틸리티 함수
  int _timeToMinutes(String timeStr) {
    final parts = timeStr.split(':');
    if (parts.length < 2) return 0;
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }
  
  // 예약/휴게 구간을 제외한 실제 예약 가능 구간 추출 (예약 구간 사이의 빈 구간만 available로 반환)
  List<Map<String, int>> _getAvailableBlocks({
    required int workStart,
    required int workEnd,
    required List<List<int>> reserved,
    required List<int> breakRange, // [breakStart, breakEnd]
  }) {
    try {
      // 예약 가능 블록 계산 전에 유효성 검사
      if (workStart >= workEnd) {
        print('⚠️ [경고] 근무 시간 오류: 시작(${_minutesToTimeString(workStart)})이 종료(${_minutesToTimeString(workEnd)})보다 크거나 같습니다.');
        return [];
      }

      print('\n📊 [예약 가능 시간대 계산 시작]');
      print('⏰ 근무 시간: ${_minutesToTimeString(workStart)} ~ ${_minutesToTimeString(workEnd)}');
      
      List<List<int>> blocks = List.from(reserved);
      
      // 휴식 시간이 유효한 경우만 추가
      if (breakRange.length >= 2 && breakRange[0] < breakRange[1] && breakRange[0] > 0) {
        blocks.add(breakRange);
        print('☕ 휴식 시간 추가: ${_minutesToTimeString(breakRange[0])} ~ ${_minutesToTimeString(breakRange[1])}');
      } else {
        print('⚠️ 휴식 시간 무시: 유효하지 않은 범위 또는 0시간');
      }
      
      // 예약된 시간대 출력
      if (reserved.isNotEmpty) {
        print('🔒 예약된 시간대 (${reserved.length}개):');
        for (int i = 0; i < reserved.length; i++) {
          final r = reserved[i];
          if (r.length >= 2) {
            print('  - 예약 #${i+1}: ${_minutesToTimeString(r[0])} ~ ${_minutesToTimeString(r[1])} (${r[1] - r[0]} 분)');
          }
        }
      } else {
        print('✅ 예약된 시간대가 없습니다.');
      }
      
      // 예약 블록 정렬
      blocks.sort((a, b) => a[0].compareTo(b[0]));
      
      List<Map<String, int>> available = [];
      int cursor = workStart;
      
      // 각 블록 사이의 빈 구간 추출
      for (final b in blocks) {
        if (b.length < 2) {
          print('⚠️ [경고] 유효하지 않은 블록 무시: $b');
          continue;  // 유효하지 않은 블록 무시
        }
        
        if (cursor < b[0]) {
          available.add({'start': cursor, 'end': b[0]});
          print('➕ 가능 구간 추가: ${_minutesToTimeString(cursor)} ~ ${_minutesToTimeString(b[0])} (${b[0] - cursor} 분)');
        }
        cursor = b[1] > cursor ? b[1] : cursor;
      }
      
      // 마지막 블록 이후의 시간이 있는 경우
      if (cursor < workEnd) {
        available.add({'start': cursor, 'end': workEnd});
        print('➕ 가능 구간 추가: ${_minutesToTimeString(cursor)} ~ ${_minutesToTimeString(workEnd)} (${workEnd - cursor} 분)');
      }
      
      // 예약 구간 사이의 빈 구간만 남기고, 예약 구간과 겹치거나 0분짜리 구간은 제외
      final validBlocks = available.where((b) => b['end']! > b['start']!).toList();
      print('📊 [결과] 최종 예약 가능 구간 수: ${validBlocks.length}개');
      return validBlocks;
    } catch (e) {
      print('⚠️ [경고] 예약 가능 구간 계산 중 오류: $e');
      print('⚠️ 스택 트레이스: ${StackTrace.current}');
      return [];
    }
  }
  
  // 분 단위 정수를 시간 문자열(HH:MM)로 변환
  String _minutesToTimeString(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return '${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}';
  }

  // 예약 정보 요약 위젯 - 스크린샷과 유사하게 디자인
  Widget _buildReservationSummary() {
    // 선택한 정보가 없는 경우
    if (_selectedContract == null || _selectedTimeSet == null || _selectedTS == null) {
      return Center(
        child: Column(
          children: [
            Icon(Icons.warning_amber, size: 48, color: Colors.orange),
            const SizedBox(height: 16),
            const Text(
              '모든 정보를 선택해주세요',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      );
    }
    
    // 주요 정보 추출
    final juniorName = _selectedJunior?['junior_name'] ?? '알 수 없음';
    final contractName = _selectedContract!['contract_name'] ?? '계약명 없음';
    final proName = _selectedContract!['LS_contract_pro']?.toString() ?? '프로 정보 없음';
    final formattedDate = DateFormat('yyyy년 MM월 dd일 (E)', 'ko_KR').format(_selectedDate);
    final timeRange = _formatTimeRange(_selectedTimeSet!['startStr'], _selectedTimeSet!['endStr']);
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E1), // 연한 베이지색 배경
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Text(
                '예약 정보 확인',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            const Divider(height: 32),
            
            // 주니어 정보
            _buildReservationInfoRow(Icons.visibility, '주니어:', juniorName),
            const SizedBox(height: 16),
            
            // 계약 정보
            _buildReservationInfoRow(Icons.description_outlined, '계약:', contractName),
            const SizedBox(height: 16),
            
            // 담당 프로 정보
            _buildReservationInfoRow(Icons.person_outline, '담당 프로:', proName),
            const SizedBox(height: 16),
            
            // 날짜 정보
            _buildReservationInfoRow(
              Icons.calendar_today_outlined, 
              '예약 날짜:', 
              formattedDate
            ),
            const SizedBox(height: 16),
            
            // 시간 정보
            _buildReservationInfoRow(Icons.access_time, '예약 시간:', timeRange),
            const SizedBox(height: 16),
            
            // 타석 정보
            _buildReservationInfoRow(Icons.golf_course_outlined, '타석:', '$_selectedTS번 타석'),
            
            const SizedBox(height: 24),
            const Center(
              child: Text(
                '위 정보로 예약하시겠습니까?',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
            
            // 노란색 예약 버튼
            const SizedBox(height: 20),
            Center(
              child: SizedBox(
                width: 120,
                child: ElevatedButton(
                  onPressed: _submitReservation, // 예약 함수 연결
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFCA28), // 노란색
                    foregroundColor: Colors.black87,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text(
                    '예약하기',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // 예약 정보 행 위젯 (예약 확인 화면용)
  Widget _buildReservationInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          child: Icon(icon, size: 18, color: Colors.grey.shade700),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
  
  // 기존 요약 정보 행 위젯 (다른 곳에서 사용)
  Widget _buildSummaryRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        SizedBox(
          width: 80,
          child: Text(
            '$label:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  // 시작/종료 시간 표시 형식 간결화 함수
  String _formatTimeRange(String startStr, String endStr) {
    // 항상 전체 시간을 표시 (요청대로 "10:00~10:55" 형식)
    return "$startStr~$endStr";
  }

  // 시간 선택 타일 위젯
  Widget _buildTimeSelectionTile(Map<String, dynamic> timeSet, bool isSelected, VoidCallback onTap) {
    // 선택 상태에 따라 색상 변경
    final Color tileColor = isSelected ? Colors.blue.shade200 : Colors.white;
    final Color textColor = isSelected ? Colors.white : Colors.black87;
    final Color borderColor = isSelected ? Colors.blue.shade500 : Colors.grey.shade300;
    final double borderWidth = isSelected ? 2.0 : 1.0;
    
    // 시간 표시 형식 사용
    final String timeDisplay = _formatTimeRange(timeSet['startStr'], timeSet['endStr']);
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          onTap();
          // 이미 선택된 시간 타일을 다시 탭한 경우 API를 다시 호출하지 않음
          if (!isSelected) {
            // 선택되지 않은 시간을 탭했을 때만 타석 현황 조회
            // 화면 전환 시 _selectedTS 초기화
            setState(() {
              _selectedTS = null;
            });
            _checkAvailableTeeingStations(timeSet);
          }
        },
        borderRadius: BorderRadius.circular(12),
        splashColor: Colors.blue.shade200,
        highlightColor: Colors.blue.shade100,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: tileColor,
            border: Border.all(
              color: borderColor,
              width: borderWidth,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected ? Colors.blue.shade300.withOpacity(0.5) : Colors.grey.shade200,
                blurRadius: isSelected ? 4 : 2,
                offset: isSelected ? const Offset(0, 2) : const Offset(0, 1),
              ),
            ],
            // 선택된 경우 그라데이션 효과 추가
            gradient: isSelected ? LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.blue.shade300,
                Colors.blue.shade400,
              ],
            ) : null,
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
              child: Text(
                timeDisplay,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: textColor,
                  fontSize: isSelected ? 17 : 16,
                  height: 1.1,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 선택된 시간대에 이용 가능한 타석 조회 함수
  Future<void> _checkAvailableTeeingStations(Map<String, dynamic> timeSet) async {
    if (_selectedDate == null) return;
    
    final String formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final String startTime = timeSet['startStr'];
    final String endTime = timeSet['endStr'];
    
    // 계약 유형 분류 - try 블록 바깥으로 이동
    String contractName = _selectedContract!['contract_name'] ?? '';
    String contractType = '기타 레슨';
    if (contractName.startsWith('1:1')) {
      contractType = '1:1레슨';
    } else if (contractName.startsWith('2:1')) {
      contractType = '2:1레슨';
    }
    
    try {
      print('\n🔍 [타석 현황 조회] 날짜: $formattedDate, 시간: $startTime~$endTime');
      
      print('📊 타석 현황 조회 - 계약 유형: $contractType');
      
      // ApiService 라이브러리를 사용하여 API 호출
      final Map<String, String> headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      
      final Map<String, dynamic> params = {
        'ts_date': formattedDate,
        'ts_start': startTime,
        'ts_end': endTime,
      };
      
      print('📡 [API 요청] 타석 현황 요청: ${jsonEncode(params)}');
      
      // dynamic_api.php를 통한 API 호출
      final url = 'https://autofms.mycafe24.com/dynamic_api.php';
      
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode({
          'operation': 'get',
          'table': 'v2_priced_TS',
          'where': [
            {'field': 'ts_date', 'operator': '=', 'value': formattedDate}
          ],
        }),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          print('⚠️ API 요청 시간 초과 (15초)');
          throw TimeoutException('타석 현황 조회 요청 시간이 초과되었습니다.');
        },
      );
      
      print('📡 [API 응답 상태] ${response.statusCode}');
      
      if (response.statusCode == 200) {
        // 응답 본문이 비어있는지 확인
        if (response.body.trim().isEmpty) {
          print('⚠️ API 응답이 비어있습니다.');
          print('🔍 [타석 현황 조회 완료 - 빈 응답]\n');
          return;
        }
        
        // 응답 디코딩 시도
        try {
          final data = jsonDecode(response.body);
          print('📡 [API 응답] ${response.body.length > 100 ? '${response.body.substring(0, 100)}...' : response.body}');
          
          if (data['success'] == true) {
            final List<dynamic> reservedOrders = data['data'] ?? [];
            
            print('✅ 타석 현황 조회 성공: 총 ${reservedOrders.length}개 예약 정보');
            
            // 시간대 겹침 확인 함수
            bool isTimeOverlap(String orderStart, String orderEnd, String requestStart, String requestEnd) {
              // 시간을 분으로 변환하여 비교
              int orderStartMin = _timeToMinutes(orderStart);
              int orderEndMin = _timeToMinutes(orderEnd);
              int requestStartMin = _timeToMinutes(requestStart);
              int requestEndMin = _timeToMinutes(requestEnd);
              
              // 겹침 조건: (시작시간 < 다른끝시간) && (끝시간 > 다른시작시간)
              return (requestStartMin < orderEndMin) && (requestEndMin > orderStartMin);
            }
            
            // 전체 타석 목록 (1-9번)
            final List<int> allTSNumbers = List.generate(9, (index) => index + 1);
            
            // 요청 시간대와 겹치는 예약이 있는 타석 번호들 추출
            final Set<int> conflictTSNumbers = <int>{};
            
            for (var order in reservedOrders) {
              final String orderStart = order['ts_start']?.toString() ?? '';
              final String orderEnd = order['ts_end']?.toString() ?? '';
              final String orderStatus = order['ts_status']?.toString() ?? '';
              final int tsNumber = int.tryParse(order['ts_id']?.toString() ?? '') ?? 0;
              
              // 결제완료 상태인 예약만 처리
              if (tsNumber > 0 && orderStatus == '결제완료' && isTimeOverlap(orderStart, orderEnd, startTime, endTime)) {
                conflictTSNumbers.add(tsNumber);
                print('🔒 시간 겹침 발견: ${tsNumber}번 타석 (${orderStart}~${orderEnd}, 상태: ${orderStatus})');
              }
            }
            
            // 가용 타석 번호 계산 (겹치지 않는 타석들)
            final List<int> availableTSNumbers = allTSNumbers.where((tsNumber) => !conflictTSNumbers.contains(tsNumber)).toList();
            
            // 타석 유형별로 분류
            final List<int> availableOpenTS = availableTSNumbers.where((num) => num <= 6).toList();
            final List<int> availablePrivateTS = availableTSNumbers.where((num) => num > 6).toList();
            
            print('📋 [타석 현황 요약]');
            print('- 전체 타석 수: ${allTSNumbers.length}');
            print('- 이용 가능한 타석 수: ${availableTSNumbers.length}');
            print('- 시간 겹침 타석 수: ${conflictTSNumbers.length}');
            print('- 이용 가능한 오픈 타석: ${availableOpenTS.join(', ')}');
            print('- 이용 가능한 단독 타석: ${availablePrivateTS.join(', ')}');
            print('- 시간 겹침 타석: ${conflictTSNumbers.isEmpty ? '없음' : conflictTSNumbers.join(', ')}');
            
            // 계약 유형에 따른 타석 자동 선택
            int? selectedTS;
            List<int> preferredTSNumbers = [];
            
            if (contractType == '1:1레슨') {
              preferredTSNumbers = [7, 8, 9]; // 1:1레슨은 7, 8, 9번 선호
              print('💡 [타석 선택] 1:1레슨은 단독타석(7-9번)을 우선 배정합니다.');
              
              // 선호하는 타석 중에서 이용 가능한 타석 찾기
              for (int tsNumber in preferredTSNumbers) {
                if (availableTSNumbers.contains(tsNumber)) {
                  selectedTS = tsNumber;
                  print('✅ 선택된 타석: $selectedTS번 (단독타석)');
                  break;
                }
              }
              
              if (selectedTS == null) {
                print('❌ 이용 가능한 단독타석이 없습니다. 다른 시간을 선택해야 합니다.');
              }
            } else if (contractType == '2:1레슨') {
              preferredTSNumbers = [5, 6]; // 2:1레슨은 5, 6번만 사용
              print('💡 [타석 선택] 2:1레슨은 5-6번 타석만 이용 가능합니다.');
              
              // 5, 6번 타석 중에서 이용 가능한 타석 찾기
              for (int tsNumber in preferredTSNumbers) {
                if (availableTSNumbers.contains(tsNumber)) {
                  selectedTS = tsNumber;
                  print('✅ 선택된 타석: $selectedTS번 (오픈타석)');
                  break;
                }
              }
              
              if (selectedTS == null) {
                print('❌ 이용 가능한 5-6번 타석이 없습니다. 다른 시간을 선택해야 합니다.');
              }
            } else {
              // 기타 레슨은 모든 타석 이용 가능 (현재는 사용하지 않음)
              print('ℹ️ 기타 레슨 유형은 자동 타석 배정 대상이 아닙니다.');
            }
            
            // 선택된 타석 상태 업데이트
            setState(() {
              _selectedTS = selectedTS;
            });
          } else {
            print('❌ 타석 현황 조회 실패: ${data['error'] ?? '알 수 없는 오류'}');
            setState(() {
              _selectedTS = null;
            });
          }
        } catch (parseError) {
          print('❌ 응답 파싱 오류: $parseError');
          print('❌ 원본 응답: ${response.body}');
          setState(() {
            _selectedTS = null;
          });
        }
      } else {
        print('❌ 타석 현황 API 요청 실패: ${response.statusCode}');
        print('❌ 응답 내용: ${response.body}');
        setState(() {
          _selectedTS = null;
        });
      }
    } catch (e) {
      print('❌ 타석 현황 조회 중 예외 발생: $e');
      print('❌ 스택 트레이스: ${StackTrace.current}');
      
      // 더미 데이터 생성 코드 제거 - 실제 오류 상황을 그대로 처리
      // 타석 선택을 null로 설정하여 "이용 가능한 타석이 없습니다" 메시지 표시
      setState(() {
        _selectedTS = null;
      });
      
    } finally {
      print('🔍 [타석 현황 조회 완료]\n');
    }
  }

  // 타석 확인 위젯 추가
  Widget _buildTeeingStationConfirmation() {
    if (_selectedTimeSet == null) {
      return Center(
        child: Column(
          children: [
            Icon(Icons.warning_amber, size: 48, color: Colors.orange),
            const SizedBox(height: 16),
            const Text(
              '먼저 시간을 선택해주세요',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      );
    }

    // 계약 유형에 따라 타석 자동 선택
    String contractName = _selectedContract!['contract_name'] ?? '';
    String contractType = '기타 레슨';
    List<int> preferredTSNumbers = [];
    
    if (contractName.startsWith('1:1')) {
      contractType = '1:1레슨';
      preferredTSNumbers = [7, 8, 9]; // 1:1레슨은 7, 8, 9번 타석 선호
    } else if (contractName.startsWith('2:1')) {
      contractType = '2:1레슨';
      preferredTSNumbers = [5, 6]; // 2:1레슨은 5, 6번 타석만 사용
    }

    // API 호출이 진행 중인지 확인
    if (_checkingTS) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              '타석 정보를 확인 중입니다...',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
        ),
      );
    }

    // 타석 상태에 따라 적절한 메시지 표시
    return _buildTeeingStationContent(contractType, preferredTSNumbers);
  }

  // 타석 확인 내용 위젯
  Widget _buildTeeingStationContent(String contractType, List<int> preferredTSNumbers) {
    if (_selectedTS == null) {
      // 이용 가능한 타석이 없는 경우
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              '이용 가능한 타석이 없습니다',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red.shade800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '다른 시간을 선택해주세요',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      );
    }

    // 완전히 새로운 디자인
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    Icons.golf_course,
                    color: Colors.teal.shade700,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '배정된 타석',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$_selectedTS번',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal.shade700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 32),
            Row(
              children: [
                Icon(Icons.schedule, size: 20, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  '${DateFormat('MM/dd (E)', 'ko_KR').format(_selectedDate)} ${_formatTimeRange(_selectedTimeSet!['startStr'], _selectedTimeSet!['endStr'])}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.person, size: 20, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  _selectedContract!['LS_contract_pro']?.toString() ?? '정보 없음',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 예약 제출 함수 추가
  Future<void> _submitReservation() async {
    print('\n==================================================');
    print('📝 [주니어 레슨 예약 시작]');
    print('📅 시간: ${DateTime.now()}');
    
    setState(() {
      _isLoading = true;
      _message = '예약 진행 중...';
    });
    
    try {
      // 주니어 정보 및 선택된 시간 확인
      if (_selectedJunior == null || _selectedTimeSet == null || _selectedTS == null) {
        print('❌ 필수 정보 누락: 주니어, 시간 또는 타석 정보가 선택되지 않았습니다.');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('모든 정보가 선택되지 않았습니다.')),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // 선택된 계약 정보 확인
      if (_selectedContract == null) {
        print('❌ 필수 정보 누락: 계약 정보가 선택되지 않았습니다.');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('유효한 계약이 선택되지 않았습니다.')),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // 주니어 회원 ID 및 이름
      final juniorMemberId = _selectedJunior!['junior_member_id'].toString();
      final juniorName = _selectedJunior!['junior_name'];
      
      // 선택된 날짜 형식 변환 (yyyy-MM-dd)
      final lessonDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
      
      // 담당 프로 이름
      final proName = _selectedContract!['LS_contract_pro']?.toString() ?? '';
      
      // 선택된 시간 정보
      final startTime1 = '${_selectedTimeSet!['slot1Start']}:00'; // 첫 번째 레슨 세션 시작 (HH:mm:00)
      final endTime1 = '${_selectedTimeSet!['slot1End']}:00';    // 첫 번째 레슨 세션 종료 (HH:mm:00)
      
      final startTime2 = '${_selectedTimeSet!['slot3Start']}:00'; // 두 번째 레슨 세션 시작 (HH:mm:00)
      final endTime2 = '${_selectedTimeSet!['slot3End']}:00';    // 두 번째 레슨 세션 종료 (HH:mm:00)
      
      // 타석 번호
      final teeingStationId = _selectedTS!;
      
      // 계약 ID
      final contractId = int.parse(_selectedContract!['LS_contract_id'].toString());
      
      print('📋 [주니어 레슨 예약 요청 정보]');
      print('주니어 ID: $juniorMemberId, 이름: $juniorName');
      print('날짜: $lessonDate, 담당 프로: $proName');
      print('첫 번째 세션: $startTime1 ~ $endTime1');
      print('두 번째 세션: $startTime2 ~ $endTime2');
      print('전체 시간 범위: $startTime1 ~ ${_selectedTimeSet!['endStr']}:00 (총 55분)');
      print('타석 번호: $teeingStationId');
      print('계약 ID: $contractId');
      
      print('📡 [API 호출 전] JuniorLessonService.addJuniorLesson 호출');
      
      // 예약 API 호출
      final result = await JuniorLessonService.addJuniorLesson(
        juniorMemberId: int.parse(juniorMemberId),
        juniorName: juniorName,
        lessonDate: lessonDate,
        proName: proName,
        sessionStartTime: startTime1,
        sessionEndTime: endTime2,
        sessionMinutes: 55,
        notes: '주니어 레슨 예약',
      );
      
      print('📡 [API 호출 후] 응답 결과: ${result['success'] ? '성공' : '실패'}');
      
      if (result['success'] == true) {
        // 예약 성공
        print('✅ [예약 성공] 메시지: ${result['message'] ?? '예약이 완료되었습니다.'}');
        
        // 타석 예약 시스템에도 데이터 추가
        await _submitTSreservation(
          juniorMemberId: juniorMemberId,
          juniorName: juniorName,
          lessonDate: lessonDate,
          startTime: startTime1,  // 첫 번째 세션 시작 시간 사용
          endTime: '${_selectedTimeSet!['endStr']}:00',  // 전체 시간 범위의 종료 시간 사용
          teeingStationId: teeingStationId
        );
        
        // 예약 성공 메시지 표시
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('예약이 성공적으로 등록되었습니다.'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );

        // 잠시 대기 후 통합예약 화면으로 돌아가기
        Future.delayed(const Duration(seconds: 1), () {
          // 현재 화면 닫기 (통합예약 화면으로 돌아감)
          // true를 전달하여 통합예약 화면에 데이터 갱신이 필요함을 알림
          Navigator.of(context).pop(true);
        });
        
      } else {
        // 예약 실패
        print('❌ [예약 실패] 오류: ${result['error'] ?? '알 수 없는 오류'}');
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('예약 등록에 실패했습니다: ${result['error'] ?? '알 수 없는 오류'}'),
            backgroundColor: Colors.red,
          ),
        );

        setState(() {
          _isLoading = false;
          _message = '';
        });
      }
    } catch (e) {
      print('❌ 예약 제출 중 오류 발생: $e');
      print('❌ 스택 트레이스: ${StackTrace.current}');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('예약 과정에서 오류가 발생했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
      
      setState(() {
        _isLoading = false;
        _message = '';
      });
    } finally {
      print('📝 [주니어 레슨 예약 종료]');
      print('==================================================\n');
    }
  }

  // 타석 예약 시스템에 데이터 추가 함수
  Future<void> _submitTSreservation({
    required String juniorMemberId,
    required String juniorName,
    required String lessonDate,
    required String startTime,
    required String endTime,
    required int teeingStationId,
  }) async {
    print('\n==================================================');
    print('📝 [타석 예약 시스템 데이터 추가 시작]');
    
    try {
      // 날짜 포맷 변환 (YYYY-MM-DD -> YYMMDD)
      final dateObj = DateTime.parse(lessonDate);
      final shortDate = DateFormat('yyMMdd').format(dateObj);
      
      // 시간 포맷에서 시간만 추출 (HH:MM:SS -> HHMM)
      final startHour = startTime.split(':')[0];
      final startMinute = startTime.split(':')[1];
      final startTimeStr = '$startHour$startMinute';
      
      // 예약 ID 생성: "날짜_회원ID_시간" (예: "250522_2_1330")
      final reservationId = '${shortDate}_${juniorMemberId}_$startTimeStr';
      
      // 현재 시간 생성
      final timeStamp = DateFormat('yyyy-MM-dd HH:mm:ss.000').format(DateTime.now());
      
      // 이용 시간 계산 (분)
      final startMinutes = _timeToMinutes(startTime);
      final endMinutes = _timeToMinutes(endTime);
      final durationMinutes = endMinutes - startMinutes;
      
      // 주니어 레슨은 항상 55분 단위로 진행됨 (15분 레슨 + 15분 자율연습 + 15분 레슨 + 10분 마무리)
      final adjustedDuration = 55;
      
      print('🔢 계산된 값들');
      print('- 날짜 형식 변환: $lessonDate -> $shortDate');
      print('- 시간 형식 변환: $startTime -> $startTimeStr');
      print('- 예약 ID: $reservationId');
      print('- 이용 시간: $durationMinutes분 (조정된 시간: $adjustedDuration분)');
      
      // API 요청 데이터 구성
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final requestData = {
        'operation': 'add',
        'table': 'v2_priced_TS',
        'data': {
          'reservation_id': reservationId,
          'ts_id': teeingStationId,
          'ts_date': lessonDate,
          'ts_start': startTime,
          'ts_end': endTime,
          'ts_min': adjustedDuration,
          'ts_type': '주니어레슨',
          'ts_payment_method': '주니어회원권',
          'ts_status': '결제완료',
          'member_id': int.parse(juniorMemberId),
          'member_name': juniorName,
          'member_phone': '',  // 전화번호 정보 없음
          'total_amt': 0,
          'term_discount': 0,
          'member_discount': 0,
          'junior_discount': 0,
          'routine_discount': 0,
          'overtime_discount': 0,
          'revisit_discount': 0,
          'emergency_discount': 0,
          'emergency_reason': '0',
          'total_discount': 0,
          'net_amt': 0,
          'morning': 0,
          'normal': 0,
          'peak': 0,
          'night': 0,
          'time_stamp': timeStamp,
          'ts_duration': adjustedDuration,
          'branch_id': userProvider.currentBranchId, // branch_id 추가
        }
      };
      
      print('📡 [API 요청 데이터] ${jsonEncode(requestData)}');
      
      // API 엔드포인트
      final url = 'https://autofms.mycafe24.com/dynamic_api.php';
      
      // HTTP POST 요청 전송
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'FlutterApp/1.0'
        },
        body: jsonEncode(requestData),
      ).timeout(const Duration(seconds: 15));
      
      print('📡 [API 응답 상태 코드] ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        if (responseData['success'] == true) {
          print('✅ [타석 예약 시스템 데이터 추가 성공]');
          print('- 새 레코드 ID: ${responseData['insertId']}');
        } else {
          print('❌ [타석 예약 시스템 데이터 추가 실패]');
          print('- 오류: ${responseData['error'] ?? '알 수 없는 오류'}');
        }
      } else {
        print('❌ [API 요청 실패] 상태 코드: ${response.statusCode}');
        print('- 응답: ${response.body}');
      }
    } catch (e) {
      print('❌ 타석 예약 시스템 데이터 추가 중 오류: $e');
      print('❌ 스택 트레이스: ${StackTrace.current}');
    } finally {
      print('📝 [타석 예약 시스템 데이터 추가 종료]');
      print('==================================================\n');
    }
  }

  // 날짜를 yyyy-MM-dd 형식으로 포맷
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // 시간 문자열(HH:mm:ss)에 분 추가
  String _addMinutesToTimeString(String timeString, int minutes) {
    // 시간 문자열(HH:mm:ss 또는 HH:mm) 파싱
    List<String> parts = timeString.split(':');
    int hours = int.parse(parts[0]);
    int mins = int.parse(parts[1]);
    
    // 분 추가
    mins += minutes;
    
    // 시간 조정 (분이 60 이상인 경우)
    hours += mins ~/ 60;
    mins = mins % 60;
    
    // 24시간 형식으로 조정
    hours = hours % 24;
    
    // HH:mm:ss 형식으로 반환
    return '${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}:00';
  }

  // 폼 리셋 함수
  void _resetForm() {
    setState(() {
      _selectedJunior = null;
      _selectedContract = null;
      _selectedDate = DateTime.now(); // 오늘 날짜로 초기화
      _selectedTime = null;
      _selectedTimeSet = null;
      _selectedTS = null;
      _currentStep = 0;
    });
    
    // 주니어 관계 정보 다시 로드
    _loadJuniorRelations();
  }
} 