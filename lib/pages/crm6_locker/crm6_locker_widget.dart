import '/components/side_bar_nav/side_bar_nav_widget.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'locker_api_service.dart';
import '/services/api_service.dart';
import '/services/table_design.dart';
import 'crm6_locker_setting.dart';
import 'crm6_locker_filter.dart';
import 'crm6_locker_assign.dart';
import 'crm6_locker_monthly_billing.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'crm6_locker_model.dart';
export 'crm6_locker_model.dart';

class Crm6LockerWidget extends StatefulWidget {
  const Crm6LockerWidget({super.key, this.onNavigate});

  final Function(String)? onNavigate;

  static String routeName = 'crm6_locker';
  static String routePath = 'crm6Locker';

  @override
  State<Crm6LockerWidget> createState() => _Crm6LockerWidgetState();
}

class _Crm6LockerWidgetState extends State<Crm6LockerWidget> {
  late Crm6LockerModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => Crm6LockerModel());
    _loadLockerData();
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  // 화면 크기에 따른 타일 개수 계산 (오버플로우 방지)
  int _calculateCrossAxisCount(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    const double fixedTileSize = 200.0; // 고정 타일 크기
    const double spacing = 8.0; // 타일 간격
    const double containerPadding = 48.0; // 컨테이너 좌우 패딩 (추정)
    
    // GridView가 들어갈 수 있는 실제 너비 계산
    final availableWidth = screenWidth - containerPadding;
    
    // n개의 타일이 들어갈 때 필요한 총 너비 = (타일크기 × n) + (간격 × (n-1))
    // 역산해서 들어갈 수 있는 최대 타일 개수 계산
    // availableWidth = fixedTileSize * n + spacing * (n-1)
    // availableWidth = n * (fixedTileSize + spacing) - spacing
    // n = (availableWidth + spacing) / (fixedTileSize + spacing)
    
    final maxTiles = (availableWidth + spacing) / (fixedTileSize + spacing);
    final crossAxisCount = maxTiles.floor();
    
    // 최소 1개는 보장
    return crossAxisCount < 1 ? 1 : crossAxisCount;
  }

  // 락커 데이터 로드 (중복 호출 방지)
  Future<void> _loadLockerData() async {
    // 이미 로딩 중이면 중복 호출 방지
    if (_model.isLoading) return;
    
    final totalStartTime = DateTime.now();
    print('🚀 [전체 로딩] 시작 시간: ${totalStartTime.toIso8601String()}');
    
    setState(() {
      _model.isLoading = true;
    });

    try {
      print('락커 데이터 로딩 시작...');
      final startTime = DateTime.now();
      final data = await LockerApiService.getLockerStatus();
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);
      print('락커 데이터 로딩 완료: ${data.length}개 (소요시간: ${duration.inMilliseconds}ms)');
      
      // 모든 청구서 데이터를 한번에 가져오기
      print('청구서 데이터 로딩 시작...');
      final billStartTime = DateTime.now();
      final allBills = await LockerApiService.getAllLockerBills();
      final billEndTime = DateTime.now();
      final billDuration = billEndTime.difference(billStartTime);
      print('청구서 데이터 로딩 완료: ${allBills.length}개 (소요시간: ${billDuration.inMilliseconds}ms)');
      
      // 프론트엔드에서 결제 상태 계산
      print('결제 상태 계산 시작...');
      final calcStartTime = DateTime.now();
      _calculateAllPaymentStatusesLocally(data, allBills);
      final calcEndTime = DateTime.now();
      final calcDuration = calcEndTime.difference(calcStartTime);
      print('결제 상태 계산 완료 (소요시간: ${calcDuration.inMilliseconds}ms)');
      
      // 회원 정보 추가 조회 및 매핑
      print('회원 정보 조회 시작...');
      final memberStartTime = DateTime.now();
      await _loadMemberInfoForLockers(data);
      final memberEndTime = DateTime.now();
      final memberDuration = memberEndTime.difference(memberStartTime);
      print('회원 정보 조회 완료 (소요시간: ${memberDuration.inMilliseconds}ms)');
      
      final renderStartTime = DateTime.now();
      setState(() {
        _model.lockerData = data;
        _model.mainFilteredData = data; // 메인 테이블용 필터 데이터 초기화
        _model.isLoading = false;
        
        // 필터 성능 최적화를 위한 고유 속성 계산
        _model.updateUniqueProperties();
      });
      
      // setState 호출 후 다음 프레임에서 렌더링 시간 측정
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final renderEndTime = DateTime.now();
        final renderDuration = renderEndTime.difference(renderStartTime);
        print('🎨 [렌더링] 완료! 렌더링 소요시간: ${renderDuration.inMilliseconds}ms');
      });
      
      final totalEndTime = DateTime.now();
      final totalDuration = totalEndTime.difference(totalStartTime);
      print('🏁 [전체 로딩] 완료! 총 소요시간: ${totalDuration.inMilliseconds}ms');
    } catch (e) {
      print('락커 데이터 로딩 오류: $e');
      setState(() {
        _model.isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('데이터 로드 실패: $e')),
      );
    }
  }

  // 데이터 재활용 (이미 로드된 데이터가 있으면 그대로 사용, 없으면 로드)
  Future<List<Map<String, dynamic>>> _getOrLoadLockerData() async {
    if (_model.lockerData.isNotEmpty && !_model.isLoading) {
      return _model.lockerData;
    }
    await _loadLockerData();
    return _model.lockerData;
  }

  // 메인 필터 콜백 함수
  void _onMainFilterChanged(List<Map<String, dynamic>> filteredData) {
    setState(() {
      _model.mainFilteredData = filteredData;
    });
  }

  // 락커 배정 팝업 표시
  void _showAssignmentPopup(Map<String, dynamic> locker) {
    LockerAssignService.showAssignmentPopup(context, locker, _model, setState);
  }

  // 미납 결제 팝업 표시
  void _showUnpaidPaymentPopup(Map<String, dynamic> locker) {
    setState(() {
      _model.selectedLockerId = locker['locker_id'];
      _model.selectedLockerInfo = locker;
      _model.showAssignmentPopup = true; // 같은 팝업 UI 재사용
      _model.isUnpaidPaymentMode = true; // 미납 결제 모드 설정
      _model.clearAssignmentForm();
      
      // 미납 결제용 기본값 설정
      _setUnpaidPaymentDefaults(locker);
    });
  }

  // 미납 결제 기본값 설정
  void _setUnpaidPaymentDefaults(Map<String, dynamic> locker) {
    // 마지막 결제완료 기록의 다음날을 시작일로 설정
    final lastPaymentEndDate = _getLastPaymentEndDate(locker);
    final startDate = lastPaymentEndDate?.add(Duration(days: 1)) ?? DateTime.now();
    
    // 오늘을 종료일로 설정
    final now = DateTime.now();
    final endDate = now; // 오늘
    
    _model.startDateController?.text = startDate.toString().split(' ')[0];
    _model.endDateController?.text = endDate.toString().split(' ')[0];
    
    // 기존 할인 조건 유지
    _model.discountMinController?.text = locker['locker_discount_condition_min']?.toString() ?? '0';
    _model.discountRatioController?.text = locker['locker_discount_ratio']?.toString() ?? '0';
    
    // 미납 결제 기본값 설정
    _model.selectedPaymentMethod = '일시납부'; // 디폴트 납부방법
    _model.selectedPayMethod = '크레딧 결제'; // 디폴트 결제방법
    
    // 배정된 회원 정보 설정
    _model.selectedMember = {
      'member_id': locker['member_id'],
      'member_name': locker['member_name'] ?? '',
      'member_phone': locker['member_phone'] ?? '',
    };
    _model.memberSearchController?.text = locker['member_display'] ?? '${locker['member_name'] ?? ''} (${locker['member_phone'] ?? ''})';
    
    // 가격 자동 계산 (시작일-종료일 기반 일수 계산)
    _calculateUnpaidTotalPrice();
  }

  // 미납 결제용 총 가격 계산 (배정 로직과 동일)
  void _calculateUnpaidTotalPrice() {
    final startDateStr = _model.startDateController?.text;
    final endDateStr = _model.endDateController?.text;
    final basePrice = _model.selectedLockerInfo?['locker_price'] ?? 0;
    
    if (startDateStr != null && endDateStr != null && startDateStr.isNotEmpty && endDateStr.isNotEmpty) {
      try {
        final startDate = DateTime.parse(startDateStr);
        final endDate = DateTime.parse(endDateStr);
        final days = endDate.difference(startDate).inDays + 1; // 시작일 포함
        
        // 일할 계산 (월 기준 가격을 실제 일수로 비례)
        // 해당 월의 실제 일수를 구해서 정확하게 계산
        final year = startDate.year;
        final month = startDate.month;
        final daysInMonth = DateTime(year, month + 1, 0).day; // 해당 월의 실제 일수
        final totalPrice = (basePrice * days / daysInMonth).round();
        _model.totalPriceController?.text = totalPrice.toString();
        
        print('가격 자동 계산: ${days}일 × ${basePrice}원/${daysInMonth}일 = ${totalPrice}원');
      } catch (e) {
        print('날짜 파싱 오류: $e');
        _model.totalPriceController?.text = basePrice.toString();
      }
    } else {
      _model.totalPriceController?.text = basePrice.toString();
    }
  }

  // 마지막 결제완료 기록의 종료일 찾기
  DateTime? _getLastPaymentEndDate(Map<String, dynamic> locker) {
    final memberId = locker['member_id'];
    final branchId = locker['branch_id'];
    final lockerName = locker['locker_name']?.toString();
    
    if (memberId == null || branchId == null || lockerName == null) return null;
    
    // 전역 청구서 데이터에서 해당 락커의 결제완료 청구서 찾기
    DateTime? latestEndDate;
    
    // 결제상태 계산시 사용한 청구서 맵을 활용할 수 없으므로 API 호출 필요
    // 임시로 v2_Locker_status의 locker_end_date 사용
    final endDateStr = locker['locker_end_date'];
    if (endDateStr != null && endDateStr.toString().isNotEmpty) {
      try {
        latestEndDate = DateTime.parse(endDateStr);
        print('마지막 결제 종료일: $endDateStr');
      } catch (e) {
        print('종료일 파싱 오류: $e');
      }
    }
    
    // 종료일이 없으면 시작일을 기준으로 함 (최소한의 fallback)
    if (latestEndDate == null) {
      final startDateStr = locker['locker_start_date'];
      if (startDateStr != null) {
        try {
          latestEndDate = DateTime.parse(startDateStr);
          print('종료일이 없어서 시작일 사용: $startDateStr');
        } catch (e) {
          print('시작일 파싱 오류: $e');
        }
      }
    }
    
    return latestEndDate;
  }

  // 락커 배정 저장
  Future<void> _saveAssignment() async {
    await LockerAssignService.saveAssignment(context, _model, () async {
      // 배정 후 데이터 새로고침
      await _loadLockerData();
    }, setState);
  }

  // 락커 기본설정 팝업 표시
  void _showSettingsPopup() {
    setState(() {
      _model.showSettingsPopup = true;
      _model.totalCountController?.text = _model.lockerData.length.toString();
    });
  }

  // 락커 자동 채번
  Future<void> _autoNumberLockers() async {
    final totalCount = int.tryParse(_model.totalCountController?.text ?? '0') ?? 0;
    if (totalCount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('유효한 락커 수량을 입력해주세요.')),
      );
      return;
    }

    // 현재 상황 분석
    String analysisMessage;
    bool hasError = false;
    
    try {
      final existingLockers = await _getOrLoadLockerData();
      final currentCount = existingLockers.length;
      
      if (totalCount == currentCount) {
        analysisMessage = '현재 락커 개수: $currentCount개\n입력한 개수: $totalCount개\n\n변경사항이 없습니다.';
      } else if (totalCount > currentCount) {
        final addCount = totalCount - currentCount;
        
        // 어떤 번호를 추가할지 확인
        final existingNumbers = existingLockers.map((l) => int.tryParse(l['locker_name'].toString()) ?? 0).toSet();
        final missingNumbers = <int>[];
        for (int i = 1; i <= totalCount; i++) {
          if (!existingNumbers.contains(i)) {
            missingNumbers.add(i);
          }
        }
        
        analysisMessage = '현재 락커 개수: $currentCount개\n입력한 개수: $totalCount개\n\n추가될 락커: $addCount개\n락커 번호: ${missingNumbers.join(', ')}';
      } else {
        final deleteCount = currentCount - totalCount;
        
        // 삭제 대상 확인
        final lockersToDelete = existingLockers.where((locker) {
          final lockerNumber = int.tryParse(locker['locker_name'].toString());
          return lockerNumber != null && lockerNumber > totalCount;
        }).toList();
        
        final assignedLockers = lockersToDelete.where((locker) => locker['member_id'] != null).toList();
        
        if (assignedLockers.isNotEmpty) {
          final assignedNumbers = assignedLockers.map((l) => l['locker_name']).join(', ');
          analysisMessage = '현재 락커 개수: $currentCount개\n입력한 개수: $totalCount개\n\n❌ 삭제 불가능\n\n삭제 대상 락커에 배정된 회원이 있습니다.\n락커 번호: $assignedNumbers\n\n먼저 해당 락커들을 반납 처리해주세요.';
          hasError = true;
        } else {
          final deleteNumbers = lockersToDelete.map((l) => l['locker_name']).join(', ');
          analysisMessage = '현재 락커 개수: $currentCount개\n입력한 개수: $totalCount개\n\n삭제될 락커: $deleteCount개\n락커 번호: $deleteNumbers';
        }
      }
    } catch (e) {
      analysisMessage = '락커 정보를 불러오는 중 오류가 발생했습니다.\n$e';
      hasError = true;
    }

    // 확인 다이얼로그
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('락커 자동 채번 확인', style: TextStyle(color: Color(0xFF1E293B))),
        content: Text(analysisMessage, style: TextStyle(color: Color(0xFF1E293B))),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('취소'),
          ),
          if (!hasError)
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('확인'),
            ),
        ],
      ),
    );

    if (confirm != true || hasError) return;

    try {
      await LockerApiService.autoNumberLockers(totalCount, _model.lockerData);
      setState(() {
        _model.showSettingsPopup = false;
      });
      // 자동 채번은 내부에서 이미 데이터를 처리하므로 별도 로딩 불필요
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('락커 자동 채번이 완료되었습니다.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('락커 자동 채번 실패: $e')),
      );
    }
  }

  // 배정된 회원들의 정보 캐시
  List<Map<String, dynamic>> _assignedMembersCache = [];

  // 락커 설정 팝업 표시 (분리된 파일에서 관리)
  void _showLockerSettingsPopup() async {
    print('=== 락커 설정 팝업 열기 ===');
    print('전체 락커 데이터: ${_model.lockerData.length}개');
    
    // 배정된 회원 ID들 추출
    final assignedMemberIds = <int>{};
    for (final locker in _model.lockerData) {
      if (locker['member_id'] != null) {
        assignedMemberIds.add(locker['member_id'] as int);
      }
    }
    
    print('배정된 회원 ID: $assignedMemberIds');
    
    // 배정된 회원들의 정보 미리 로드
    if (assignedMemberIds.isNotEmpty) {
      try {
        _assignedMembersCache = await LockerApiService.getMembersByIds(assignedMemberIds.toList());
        print('회원 정보 캐시 완료: ${_assignedMembersCache.length}명');
        for (final member in _assignedMembersCache) {
          print('- ${member['member_id']}: ${member['member_name']} (${member['member_phone']})');
        }
      } catch (e) {
        print('회원 정보 로드 오류: $e');
        _assignedMembersCache = [];
      }
    } else {
      _assignedMembersCache = [];
    }
    
    setState(() {
      _model.showLockerSettingsPopup = true;
      _model.selectedLockerIds.clear();
      _model.lockerFilter = null;
      _model.rangeStart = null;
      _model.rangeEnd = null;
      _model.selectedUsageStatus = null; // 이용상태 필터 초기화
      _model.memberSearchInSettingsController?.clear(); // 회원 검색창 초기화
      _model.selectedZones.clear(); // 속성 필터 초기화
      _model.selectedTypes.clear();
      _model.selectedPrices.clear();
      _model.filteredSettingsLockers = _model.lockerData;
    });
  }


  // 범위 + 홀짝 필터 적용

  // 검색조건 초기화 (선택은 유지)
  void _resetLockerFilter() {
    setState(() {
      _model.lockerFilter = null;
      _model.rangeStart = null;
      _model.rangeEnd = null;
      _model.rangeStartController?.clear();
      _model.rangeEndController?.clear();
      _model.singleNumberController?.clear(); // 단일 번호 검색창도 초기화
      _model.selectedUsageStatus = null; // 이용상태 필터도 초기화
      _model.memberSearchInSettingsController?.clear(); // 회원 검색창도 초기화
      _model.selectedZones.clear();
      _model.selectedTypes.clear();
      _model.selectedPrices.clear();
      _model.filteredSettingsLockers = _model.lockerData;
    });
  }



  // 총수량 변경 팝업 표시
  void _showTotalCountPopup() {
    setState(() {
      _model.showSettingsPopup = true;
      _model.totalCountController?.text = _model.lockerData.length.toString();
    });
  }

  // 구역 개별 적용
  Future<void> _applyZoneOnly() async {
    if (_model.selectedLockerIds.isEmpty || _model.bulkZoneController?.text.isEmpty == true) return;
    
    try {
      final data = {'locker_zone': _model.bulkZoneController!.text};
      final newZone = _model.bulkZoneController!.text;
      
      await LockerApiService.updateMultipleLockers(
        lockerIds: _model.selectedLockerIds.toList(),
        data: data,
      );
      
      // 로컬 데이터 즉시 업데이트
      setState(() {
        for (var locker in _model.filteredSettingsLockers) {
          if (_model.selectedLockerIds.contains(locker['locker_id'])) {
            locker['locker_zone'] = newZone;
          }
        }
      });
      
      _model.bulkZoneController?.clear();
      // 일괄 구역 적용 후 데이터 새로고침
      await _loadLockerData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('구역이 적용되었습니다.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('구역 적용 실패: $e')),
      );
    }
  }

  // 종류 개별 적용
  Future<void> _applyTypeOnly() async {
    if (_model.selectedLockerIds.isEmpty || _model.bulkTypeController?.text.isEmpty == true) return;
    
    try {
      final data = {'locker_type': _model.bulkTypeController!.text};
      final newType = _model.bulkTypeController!.text;
      
      await LockerApiService.updateMultipleLockers(
        lockerIds: _model.selectedLockerIds.toList(),
        data: data,
      );
      
      // 로컬 데이터 즉시 업데이트
      setState(() {
        for (var locker in _model.filteredSettingsLockers) {
          if (_model.selectedLockerIds.contains(locker['locker_id'])) {
            locker['locker_type'] = newType;
          }
        }
      });
      
      _model.bulkTypeController?.clear();
      // 일괄 종류 적용 후 데이터 새로고침
      await _loadLockerData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('종류가 적용되었습니다.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('종류 적용 실패: $e')),
      );
    }
  }

  // 기본가격 개별 적용
  Future<void> _applyPriceOnly() async {
    if (_model.selectedLockerIds.isEmpty || _model.bulkPriceController?.text.isEmpty == true) return;
    
    try {
      final price = int.tryParse(_model.bulkPriceController!.text) ?? 0;
      final data = {'locker_price': price};
      
      await LockerApiService.updateMultipleLockers(
        lockerIds: _model.selectedLockerIds.toList(),
        data: data,
      );
      
      // 로컬 데이터 즉시 업데이트
      setState(() {
        for (var locker in _model.filteredSettingsLockers) {
          if (_model.selectedLockerIds.contains(locker['locker_id'])) {
            locker['locker_price'] = price;
          }
        }
      });
      
      _model.bulkPriceController?.clear();
      // 일괄 가격 적용 후 데이터 새로고침
      await _loadLockerData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('기본가격이 적용되었습니다.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('기본가격 적용 실패: $e')),
      );
    }
  }

  // 일괄 속성 부여 저장 (기존 - 제거 예정)
  Future<void> _saveBulkAssignment() async {
    print('일괄 속성 부여 시작: 선택된 락커 ${_model.selectedLockerIds.length}개');
    
    if (_model.selectedLockerIds.isEmpty) {
      print('선택된 락커가 없습니다.');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('락커를 선택해주세요.')),
      );
      return;
    }

    try {
      final data = <String, dynamic>{};
      
      if (_model.bulkZoneController?.text.isNotEmpty == true) {
        data['locker_zone'] = _model.bulkZoneController!.text;
        print('구역 설정: ${_model.bulkZoneController!.text}');
      }
      if (_model.bulkTypeController?.text.isNotEmpty == true) {
        data['locker_type'] = _model.bulkTypeController!.text;
        print('종류 설정: ${_model.bulkTypeController!.text}');
      }
      if (_model.bulkPriceController?.text.isNotEmpty == true) {
        data['locker_price'] = int.tryParse(_model.bulkPriceController!.text) ?? 0;
        print('가격 설정: ${_model.bulkPriceController!.text}');
      }

      print('업데이트할 데이터: $data');
      print('선택된 락커 ID들: ${_model.selectedLockerIds.toList()}');

      if (data.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('변경할 속성을 입력해주세요.')),
        );
        return;
      }

      await LockerApiService.updateMultipleLockers(
        lockerIds: _model.selectedLockerIds.toList(),
        data: data,
      );

      setState(() {
        _model.showBulkAssignPopup = false;
        _model.isSelectMode = false;
        _model.selectedLockerIds.clear();
      });

      // 일괄 속성 부여 후 데이터 새로고침
      await _loadLockerData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('일괄 속성 부여가 완료되었습니다.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('일괄 속성 부여 실패: $e')),
      );
    }
  }

  // 개별 편집 팝업 표시
  void _showIndividualEditPopup(Map<String, dynamic> locker) {
    setState(() {
      _model.showIndividualEditPopup = true;
      _model.editingLockerId = locker['locker_id'];
      _model.editZoneController?.text = locker['locker_zone'] ?? '';
      _model.editTypeController?.text = locker['locker_type'] ?? '';
      _model.editPriceController?.text = (locker['locker_price'] ?? 0).toString();
    });
  }

  // 개별 편집 저장
  Future<void> _saveIndividualEdit() async {
    if (_model.editingLockerId == null) return;

    try {
      final data = <String, dynamic>{};
      
      if (_model.editZoneController?.text.isNotEmpty == true) {
        data['locker_zone'] = _model.editZoneController!.text;
      }
      if (_model.editTypeController?.text.isNotEmpty == true) {
        data['locker_type'] = _model.editTypeController!.text;
      }
      if (_model.editPriceController?.text.isNotEmpty == true) {
        data['locker_price'] = int.tryParse(_model.editPriceController!.text) ?? 0;
      }

      if (data.isNotEmpty) {
        await LockerApiService.updateLocker(
          lockerId: _model.editingLockerId!,
          data: data,
        );

        setState(() {
          _model.showIndividualEditPopup = false;
        });

        // 개별 락커 수정 후 데이터 새로고침
        await _loadLockerData();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('락커 정보가 수정되었습니다.')),
        );
      } else {
        setState(() {
          _model.showIndividualEditPopup = false;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('락커 정보 수정 실패: $e')),
      );
    }
  }

  // 락커 반납 팝업 표시
  void _showReturnPopup(Map<String, dynamic> locker) {
    LockerAssignService.showReturnPopup(context, locker, _model, setState);
  }

  // 락커에 할당된 회원 정보 조회 및 매핑
  Future<void> _loadMemberInfoForLockers(List<Map<String, dynamic>> lockers) async {
    // 배정된 회원 ID들 수집
    final Set<int> memberIds = {};
    for (final locker in lockers) {
      if (locker['member_id'] != null) {
        memberIds.add(locker['member_id'] as int);
      }
    }
    
    if (memberIds.isEmpty) {
      print('배정된 회원이 없음');
      return;
    }
    
    print('배정된 회원 ID: $memberIds');
    
    try {
      // 회원 정보 일괄 조회
      final members = await LockerApiService.getMembersByIds(memberIds.toList());
      print('조회된 회원 정보: ${members.length}명');
      
      // 회원 ID를 키로 하는 맵 생성
      final Map<int, Map<String, dynamic>> memberMap = {};
      for (final member in members) {
        memberMap[member['member_id']] = member;
      }
      
      // 락커 데이터에 회원 정보 매핑
      for (final locker in lockers) {
        final memberId = locker['member_id'];
        if (memberId != null && memberMap.containsKey(memberId)) {
          final memberInfo = memberMap[memberId]!;
          locker['member_name'] = memberInfo['member_name'];
          locker['member_phone'] = memberInfo['member_phone'];
          locker['member_display'] = '${memberId}. ${memberInfo['member_name']} (${memberInfo['member_phone']})';
          print('락커 ${locker['locker_name']}: ${locker['member_display']}');
        }
      }
    } catch (e) {
      print('회원 정보 조회 오류: $e');
    }
  }


  // 락커 반납 처리
  Future<void> _processReturn() async {
    await LockerAssignService.processReturn(context, _model, () async {
      // 반납 후 데이터 새로고침
      await _loadLockerData();
    }, setState);
  }

  // 결제 정보 다시 조회
  Future<void> _refreshPaymentInfo() async {
    if (_model.selectedLockerInfo?['member_id'] != null && _model.returnDateController?.text.isNotEmpty == true) {
      try {
        final paymentInfo = await LockerApiService.getLockerPaymentInfo(
          memberId: _model.selectedLockerInfo!['member_id'],
          lockerName: _model.selectedLockerInfo!['locker_name'] ?? '',
          returnDate: _model.returnDateController?.text ?? DateTime.now().toString().split(' ')[0],
        );
        
        setState(() {
          _model.returnPaymentInfo = paymentInfo;
          if (paymentInfo['success'] == true) {
            _model.availableRefundMethods = List<String>.from(paymentInfo['available_refund_methods']);
            // 현재 선택된 환불 방법이 새 옵션에 없으면 초기화
            if (_model.selectedRefundMethod != null && !_model.availableRefundMethods.contains(_model.selectedRefundMethod)) {
              _model.selectedRefundMethod = null;
            }
          } else {
            _model.availableRefundMethods = ['현금', '환불불가'];
            _model.selectedRefundMethod = null;
          }
        });
      } catch (e) {
        print('결제 정보 조회 실패: $e');
        setState(() {
          _model.availableRefundMethods = ['현금', '환불불가'];
          _model.selectedRefundMethod = null;
        });
      }
    }
  }

  // 가격 계산 (일시납부 및 정기결제(월별))
  void _calculateTotalPrice() {
    if (_model.selectedPaymentMethod == null || 
        _model.startDateController?.text.isEmpty == true ||
        _model.selectedLockerInfo == null) {
      return;
    }

    try {
      final startDate = DateTime.parse(_model.startDateController!.text);
      DateTime endDate;
      
      if (_model.selectedPaymentMethod == '정기결제(월별)') {
        // 정기결제(월별)의 경우 해당 월의 마지막 날을 종료일로 설정
        endDate = DateTime(startDate.year, startDate.month + 1, 0);
        _model.endDateController?.text = DateFormat('yyyy-MM-dd').format(endDate);
      } else {
        // 일시납부의 경우 사용자가 입력한 종료일 사용
        if (_model.endDateController?.text.isEmpty == true) {
          return;
        }
        endDate = DateTime.parse(_model.endDateController!.text);
        
        if (endDate.isBefore(startDate)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('종료일은 시작일보다 뒤여야 합니다.')),
          );
          return;
        }
      }

      // 일수 계산
      final totalDays = endDate.difference(startDate).inDays + 1; // 시작일 포함
      final preciseMonths = _calculatePreciseMonthsBetween(startDate, endDate);
      final basePrice = _model.selectedLockerInfo?['locker_price'] ?? 0;
      
      // 할인 적용
      double discountAmount = 0;
      final discountMin = double.tryParse(_model.discountMinController?.text ?? '0') ?? 0;
      final discountRatio = double.tryParse(_model.discountRatioController?.text ?? '0') ?? 0;
      
      if (discountMin > 0) {
        discountAmount = discountMin;
      } else if (discountRatio > 0) {
        discountAmount = (basePrice * discountRatio / 100);
      }
      
      // 일할계산: (월 가격 / 30일) × 총 일수
      final dailyPrice = basePrice / 30.0;
      final baseAmount = (dailyPrice * totalDays);
      final totalPrice = (baseAmount - discountAmount).round(); // 할인 적용 후 원 단위로 반올림

      setState(() {
        _model.totalPriceController?.text = totalPrice.toString();
        _model.calculatedMonths = '${preciseMonths}개월 (${totalDays}일)';
      });

      print('납부방법: ${_model.selectedPaymentMethod}');
      print('기간: ${_model.startDateController?.text} ~ ${DateFormat('yyyy-MM-dd').format(endDate)}');
      print('총 일수: ${totalDays}일');
      print('정확한 개월수: $preciseMonths개월');
      print('월 가격: $basePrice원, 일 가격: ${dailyPrice.round()}원');
      print('기본금액: ${baseAmount.round()}원, 할인: ${discountAmount.round()}원, 최종가격: $totalPrice원');
      
    } catch (e) {
      print('날짜 파싱 오료: $e');
    }
  }

  // 두 날짜 사이의 정확한 개월수 계산 (소수점 포함)
  double _calculatePreciseMonthsBetween(DateTime startDate, DateTime endDate) {
    // 총 일수 계산
    final totalDays = endDate.difference(startDate).inDays + 1; // 시작일 포함
    
    // 평균 한 달을 30.44일로 계산 (365.25 / 12)
    final months = totalDays / 30.44;
    
    return double.parse(months.toStringAsFixed(1)); // 소수점 1자리
  }

  // 두 날짜 사이의 개월수 계산 (정수)
  int _calculateMonthsBetween(DateTime startDate, DateTime endDate) {
    final preciseMonths = _calculatePreciseMonthsBetween(startDate, endDate);
    return preciseMonths.ceil(); // 올림처리
  }

  // 실시간 회원 검색
  Future<void> _searchMembersRealtime(String keyword) async {
    if (keyword.isEmpty) {
      setState(() {
        _model.memberSearchResults.clear();
        _model.showMemberSearchResults = false;
      });
      return;
    }

    try {
      print('실시간 회원 검색: $keyword');
      final members = await LockerApiService.searchMembers(keyword);
      setState(() {
        _model.memberSearchResults = members;
        _model.showMemberSearchResults = members.isNotEmpty;
      });
    } catch (e) {
      print('회원 검색 오류: $e');
      setState(() {
        _model.memberSearchResults.clear();
        _model.showMemberSearchResults = false;
      });
    }
  }

  // 회원 선택
  void _selectMember(Map<String, dynamic> member) async {
    setState(() {
      _model.selectedMember = member;
      _model.memberSearchController?.text = '${member['member_name'] ?? ''} (ID: ${member['member_id']})';
      _model.showMemberSearchResults = false;
      _model.memberSearchResults.clear();
    });
    
    // 회원 선택 후 크레딧 정보 조회
    try {
      final creditInfo = await LockerApiService.getMemberCreditInfo(member['member_id']);
      setState(() {
        _model.memberCreditInfo = creditInfo;
      });
    } catch (e) {
      print('크레딧 정보 조회 실패: $e');
    }
  }

  // 기존 회원 검색 (다이얼로그 방식) - 호환성 유지
  Future<void> _searchMembers(String keyword) async {
    if (keyword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('검색할 회원명을 입력해주세요.')),
      );
      return;
    }

    try {
      print('회원 검색 시작: $keyword');
      final members = await LockerApiService.searchMembers(keyword);
      print('검색 결과: ${members.length}명');
      
      if (members.isNotEmpty) {
        // 회원 선택 다이얼로그 표시
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.white,
            title: Text('회원 선택 (${members.length}명)', style: TextStyle(color: Color(0xFF1E293B), fontSize: 16)),
            content: Container(
              width: 300,
              height: 200,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: members.length,
                itemBuilder: (context, index) {
                  final member = members[index];
                  return ListTile(
                    dense: true,
                    title: Text(member['member_name'] ?? '', style: TextStyle(color: Color(0xFF1E293B), fontSize: 14)),
                    subtitle: Text('ID: ${member['member_id']} | ${member['member_phone'] ?? '-'}', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                    onTap: () async {
                      setState(() {
                        _model.selectedMember = member;
                        _model.memberSearchController?.text = '${member['member_name'] ?? ''} (ID: ${member['member_id']})';
                      });
                      Navigator.of(context).pop();
                      
                      // 회원 선택 후 크레딧 정보 조회
                      try {
                        final creditInfo = await LockerApiService.getMemberCreditInfo(member['member_id']);
                        setState(() {
                          _model.memberCreditInfo = creditInfo;
                        });
                      } catch (e) {
                        print('크레딧 정보 조회 실패: $e');
                      }
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('취소', style: TextStyle(color: Color(0xFF475569))),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('검색된 회원이 없습니다.')),
        );
      }
    } catch (e) {
      print('회원 검색 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('회원 검색 실패: $e')),
      );
    }
  }

  // 프론트엔드에서 모든 결제 상태를 로컬 계산 (API 호출 없음)
  void _calculateAllPaymentStatusesLocally(
    List<Map<String, dynamic>> lockers, 
    List<Map<String, dynamic>> allBills
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day); // 시간 제거, 날짜만 비교
    
    // 청구서 데이터를 key-value 형태로 그룹핑 (branch_id_locker_name_member_id -> 청구서 리스트)
    Map<String, List<Map<String, dynamic>>> billsMap = {};
    
    for (var bill in allBills) {
      final branchId = bill['branch_id'];
      final lockerName = bill['locker_name']?.toString();
      final memberId = bill['member_id'];
      
      if (branchId != null && lockerName != null && lockerName.isNotEmpty && memberId != null) {
        final key = "${branchId}_${lockerName}_${memberId}";
        billsMap[key] = billsMap[key] ?? [];
        billsMap[key]!.add(bill);
      }
    }
    
    print('청구서 맵 생성 완료: ${billsMap.length}개 락커-회원 조합의 청구서');
    
    // 각 락커의 결제 상태 계산
    for (var locker in lockers) {
      if (locker['member_id'] != null) {
        locker['payment_status'] = _calculateSinglePaymentStatusLocally(locker, billsMap, today);
      } else {
        locker['payment_status'] = ''; // 비어있는 락커는 빈칸
      }
    }
  }

  // 개별 락커의 결제 상태 계산 (최적화된 3단계 로직)
  String _calculateSinglePaymentStatusLocally(
    Map<String, dynamic> locker, 
    Map<String, List<Map<String, dynamic>>> billsMap,
    DateTime today,
  ) {
    final memberId = locker['member_id'];
    final lockerName = locker['locker_name']?.toString();
    final branchId = locker['branch_id'];
    
    // 회원이 배정되지 않은 경우
    if (memberId == null) {
      return '';
    }
    
    // branch_id + locker_name + member_id 조합으로 청구서 찾기
    final key = "${branchId}_${lockerName}_${memberId}";
    final bills = billsMap[key] ?? [];
    
    // 청구서가 없으면 락커 시작일로부터 미납 계산
    if (bills.isEmpty) {
      final startDate = locker['locker_start_date'];
      if (startDate != null) {
        try {
          final start = DateTime.parse(startDate);
          final overdueDays = today.difference(start).inDays;
          return '미납(${overdueDays}일)';
        } catch (e) {
          print('시작일 파싱 오류: $e');
        }
      }
      return '미납';
    }
    
    // 한 번의 루프로 모든 상태 정보 수집
    bool hasTodayPaidBill = false;        // 오늘 포함 기간의 결제완료 청구서 존재
    bool hasUnpaidChargeableBills = false; // 과금대상 미결제 청구서 존재  
    DateTime? oldestUnpaidDate;            // 가장 오래된 미결제 시작일
    
    for (var bill in bills) {
      final billStart = bill['locker_bill_start'];
      final billEnd = bill['locker_bill_end'];
      final billStatus = bill['locker_bill_status']?.toString();
      
      if (billStart != null && billEnd != null) {
        try {
          final start = DateTime.parse(billStart);
          final end = DateTime.parse(billEnd);
          
          // 1. 결제완료 청구서가 있는지 확인 (현재 또는 미래)
          if (billStatus == '결제완료') {
            // 디버깅 로그 추가
            print('🔍 결제완료 청구서 체크: ${locker['locker_name']}번 - ${billStart}~${billEnd}, 오늘: ${today.toString().split(' ')[0]}');
            print('  - start.isBefore(today): ${start.isBefore(today)}');
            print('  - today.isAfter(end): ${today.isAfter(end)}');
            print('  - start.isAfter(today): ${start.isAfter(today)}');
            
            // 오늘이 청구서 기간 내에 있거나, 미래의 결제완료 건이면 유효
            if ((!today.isBefore(start) && !today.isAfter(end)) || start.isAfter(today)) {
              hasTodayPaidBill = true;
              print('  → 유효한 결제완료 청구서로 인정');
            } else {
              print('  → 유효하지 않은 결제완료 청구서');
            }
          }
          
          // 2. 과금대상 미결제 청구서 확인 (반납완료 제외)
          if (billStatus != '반납완료') {
            // 결제완료 청구서도 기간이 지났으면 미납 대상
            if (billStatus != '결제완료' || end.isBefore(today)) {
              hasUnpaidChargeableBills = true;
              
              // 결제완료 청구서가 기간이 지났으면 종료일 다음날부터 미납 계산
              DateTime unpaidStartDate = start;
              if (billStatus == '결제완료' && end.isBefore(today)) {
                unpaidStartDate = end.add(Duration(days: 1));
              }
              
              // 가장 오래된 미결제 시작일 추적
              if (oldestUnpaidDate == null || unpaidStartDate.isBefore(oldestUnpaidDate)) {
                oldestUnpaidDate = unpaidStartDate;
              }
            }
          }
          
        } catch (e) {
          print('청구서 날짜 파싱 오류: $e');
        }
      }
    }
    
    // 3단계 상태 결정
    if (hasTodayPaidBill) {
      return '결제완료';
    } else if (hasUnpaidChargeableBills) {
      final referenceDate = oldestUnpaidDate ?? today;
      final overdueDays = today.difference(referenceDate).inDays;
      return '미납(${overdueDays}일)';
    } else {
      return '미확인';
    }
  }

  @override
  Widget build(BuildContext context) {
    print('🎨 [Widget] build() 메서드 호출됨 - isLoading: ${_model.isLoading}, 락커 수: ${_model.lockerData.length}');
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: Color(0xFFF8FAFC),
        body: Stack(
          children: [
            Row(
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
                      currentPage: 'crm6_locker',
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
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  blurRadius: 8.0,
                                  color: Color(0x1A000000),
                                  offset: Offset(0.0, 2.0),
                                )
                              ],
                              borderRadius: BorderRadius.circular(16.0),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.max,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 헤더 섹션
                                Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(16.0),
                                      topRight: Radius.circular(16.0),
                                    ),
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.all(24.0),
                                    child: Column(
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.max,
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Column(
                                              mainAxisSize: MainAxisSize.max,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '락커관리',
                                                  style: TextStyle(
                                                    fontFamily: 'Pretendard',
                                                    color: Color(0xFF1E293B),
                                                    fontSize: 28.0,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                Padding(
                                                  padding: EdgeInsetsDirectional.fromSTEB(0.0, 8.0, 0.0, 0.0),
                                                  child: Text(
                                                    '락커 사용 현황을 관리하고 배정할 수 있습니다.',
                                                    style: TextStyle(
                                                      fontFamily: 'Pretendard',
                                                      color: Color(0xFF64748B),
                                                      fontSize: 16.0,
                                                      fontWeight: FontWeight.w400,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Row(
                                              mainAxisSize: MainAxisSize.max,
                                              children: [
                                              ],
                                            ),
                                          ],
                                        ),
                                        // 버튼 섹션
                                        Padding(
                                          padding: EdgeInsetsDirectional.fromSTEB(0.0, 16.0, 0.0, 0.0),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.max,
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            children: [
                                              // 선택 모드 토글 버튼
                                              Padding(
                                                padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 8.0, 0.0),
                                                child: ElevatedButton.icon(
                                                  onPressed: _showLockerSettingsPopup,
                                                  icon: Icon(
                                                    Icons.settings,
                                                    size: 20.0,
                                                    color: Colors.white,
                                                  ),
                                                  label: Text(
                                                    '락커 설정',
                                                    style: TextStyle(
                                                      fontFamily: 'Pretendard',
                                                      color: Colors.white,
                                                      fontSize: 14.0,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Color(0xFF3B82F6),
                                                    elevation: 2,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(8.0),
                                                    ),
                                                    padding: EdgeInsetsDirectional.fromSTEB(16.0, 10.0, 16.0, 10.0),
                                                  ),
                                                ),
                                              ),
                                              // 월별과금 버튼 추가
                                              Padding(
                                                padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 8.0, 0.0),
                                                child: ElevatedButton.icon(
                                                  onPressed: () {
                                                    showDialog(
                                                      context: context,
                                                      barrierDismissible: false,
                                                      builder: (BuildContext context) {
                                                        return LockerMonthlyBillingDialog();
                                                      },
                                                    );
                                                  },
                                                  icon: Icon(
                                                    Icons.calculate,
                                                    size: 20.0,
                                                    color: Colors.white,
                                                  ),
                                                  label: Text(
                                                    '월별과금',
                                                    style: TextStyle(
                                                      fontFamily: 'Pretendard',
                                                      color: Colors.white,
                                                      fontSize: 14.0,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Color(0xFF10B981),
                                                    elevation: 2,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(8.0),
                                                    ),
                                                    padding: EdgeInsetsDirectional.fromSTEB(16.0, 10.0, 16.0, 10.0),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                // 필터 섹션
                                Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Color(0xFFF8FAFC),
                                    border: Border(
                                      bottom: BorderSide(
                                        color: Color(0xFFE2E8F0),
                                        width: 1.0,
                                      ),
                                    ),
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 16.0),
                                    child: Row(
                                      children: [
                                        // 필터 아이콘과 제목
                                        Icon(
                                          Icons.filter_alt,
                                          size: 20.0,
                                          color: Color(0xFF3B82F6),
                                        ),
                                        SizedBox(width: 8.0),
                                        Text(
                                          '필터',
                                          style: TextStyle(
                                            fontFamily: 'Pretendard',
                                            color: Color(0xFF1E293B),
                                            fontSize: 16.0,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Spacer(),
                                        // 필터 결과 표시
                                        Text(
                                          '총 ${_model.mainFilteredData.length}개의 락커',
                                          style: TextStyle(
                                            fontFamily: 'Pretendard',
                                            color: Color(0xFF64748B),
                                            fontSize: 14.0,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                // 필터 위젯 (항상 표시)
                                Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border(
                                      bottom: BorderSide(
                                        color: Color(0xFFE2E8F0),
                                        width: 1.0,
                                      ),
                                    ),
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.all(24.0),
                                    child: LockerFilter(
                                      model: _model,
                                      lockerData: _model.lockerData,
                                      onFilterChanged: _onMainFilterChanged,
                                      isMainFilter: true,
                                    ),
                                  ),
                                ),
                                // 테이블 섹션
                                Expanded(
                                  child: Padding(
                                    padding: EdgeInsets.all(24.0),
                                    child: Container(
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12.0),
                                        border: Border.all(
                                          color: Color(0xFFE2E8F0),
                                          width: 1.0,
                                        ),
                                      ),
                                      child: _model.isLoading
                                          ? Center(child: CircularProgressIndicator())
                                          : Column(
                                              children: [
                                                // 데이터 테이블
                                                Expanded(
                                                  child: _model.isLoading
                                                    ? Center(
                                                        child: CircularProgressIndicator(),
                                                      )
                                                    : TableDesign.buildTableContainer(
                                                        child: Column(
                                                          children: [
                                                            // 헤더
                                                            TableDesign.buildTableHeader(
                                                              children: [
                                                                TableDesign.buildHeaderColumn(text: '락커번호', flex: 2),
                                                                TableDesign.buildHeaderColumn(text: '구역', flex: 1),
                                                                TableDesign.buildHeaderColumn(text: '종류', flex: 1),
                                                                TableDesign.buildHeaderColumn(text: '기본가격', flex: 2),
                                                                TableDesign.buildHeaderColumn(text: '회원', flex: 2),
                                                                TableDesign.buildHeaderColumn(text: '납부주기', flex: 2),
                                                                TableDesign.buildHeaderColumn(text: '결제방법', flex: 2),
                                                                TableDesign.buildHeaderColumn(text: '사용기간', flex: 3),
                                                                TableDesign.buildHeaderColumn(text: '할인조건', flex: 2),
                                                                TableDesign.buildHeaderColumn(text: '비고', flex: 2),
                                                                TableDesign.buildHeaderColumn(text: '결제상태', flex: 2),
                                                                TableDesign.buildHeaderColumn(text: '작업', flex: 2),
                                                              ],
                                                            ),
                                                            // 본문
                                                            Expanded(
                                                              child: TableDesign.buildTableBody(
                                                                itemCount: _model.mainFilteredData.length,
                                                                itemBuilder: (context, index) {
                                                                  final locker = _model.mainFilteredData[index];
                                                                  final lockerId = locker['locker_id'] as int;
                                                                  final isAssigned = locker['member_id'] != null;

                                                                  return TableDesign.buildTableRow(
                                                                    children: [
                                                                      // 락커번호
                                                                      Expanded(
                                                                        flex: 2,
                                                                        child: Text(
                                                                          locker['locker_name'] ?? '',
                                                                          style: TextStyle(
                                                                            fontFamily: 'Pretendard',
                                                                            color: Color(0xFF1E293B),
                                                                            fontSize: 14,
                                                                          ),
                                                                          textAlign: TextAlign.center,
                                                                        ),
                                                                      ),
                                                                      // 구역
                                                                      Expanded(
                                                                        flex: 1,
                                                                        child: Text(
                                                                          locker['locker_zone'] ?? '-',
                                                                          style: TextStyle(
                                                                            fontFamily: 'Pretendard',
                                                                            color: Color(0xFF64748B),
                                                                            fontSize: 14,
                                                                          ),
                                                                          textAlign: TextAlign.center,
                                                                        ),
                                                                      ),
                                                                      // 종류
                                                                      Expanded(
                                                                        flex: 1,
                                                                        child: Text(
                                                                          locker['locker_type'] ?? '-',
                                                                          style: TextStyle(
                                                                            fontFamily: 'Pretendard',
                                                                            color: Color(0xFF64748B),
                                                                            fontSize: 14,
                                                                          ),
                                                                          textAlign: TextAlign.center,
                                                                        ),
                                                                      ),
                                                                      // 기본가격
                                                                      Expanded(
                                                                        flex: 2,
                                                                        child: Text(
                                                                          locker['locker_price'] != null
                                                                            ? NumberFormat('#,###').format(locker['locker_price']) + '원'
                                                                            : '-',
                                                                          style: TextStyle(
                                                                            fontFamily: 'Pretendard',
                                                                            color: Color(0xFF64748B),
                                                                            fontSize: 14,
                                                                          ),
                                                                          textAlign: TextAlign.center,
                                                                        ),
                                                                      ),
                                                                      // 회원
                                                                      Expanded(
                                                                        flex: 2,
                                                                        child: Center(
                                                                          child: Container(
                                                                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                                            decoration: BoxDecoration(
                                                                              color: isAssigned ? Color(0xFFDCFCE7) : Color(0xFFF1F5F9),
                                                                              borderRadius: BorderRadius.circular(4),
                                                                            ),
                                                                            child: Text(
                                                                              isAssigned ? (locker['member_display'] ?? 'ID: ${locker['member_id']}') : '비어있음',
                                                                              style: TextStyle(
                                                                                fontFamily: 'Pretendard',
                                                                                color: isAssigned ? Color(0xFF16A34A) : Color(0xFF64748B),
                                                                                fontSize: 12,
                                                                                fontWeight: FontWeight.w500,
                                                                              ),
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      ),
                                                                      // 납부주기
                                                                      Expanded(
                                                                        flex: 2,
                                                                        child: Text(
                                                                          locker['payment_frequency'] ?? '-',
                                                                          style: TextStyle(
                                                                            fontFamily: 'Pretendard',
                                                                            color: Color(0xFF64748B),
                                                                            fontSize: 14,
                                                                          ),
                                                                          textAlign: TextAlign.center,
                                                                        ),
                                                                      ),
                                                                      // 결제방법
                                                                      Expanded(
                                                                        flex: 2,
                                                                        child: Text(
                                                                          locker['payment_method'] ?? '-',
                                                                          style: TextStyle(
                                                                            fontFamily: 'Pretendard',
                                                                            color: Color(0xFF64748B),
                                                                            fontSize: 14,
                                                                          ),
                                                                          textAlign: TextAlign.center,
                                                                        ),
                                                                      ),
                                                                      // 사용기간
                                                                      Expanded(
                                                                        flex: 3,
                                                                        child: Text(
                                                                          () {
                                                                            final startDate = locker['locker_start_date'];
                                                                            final endDate = locker['locker_end_date'];
                                                                            final paymentFreq = locker['payment_frequency'];

                                                                            if (startDate != null) {
                                                                              if (paymentFreq == '정기결제(월별)') {
                                                                                return '$startDate ~';
                                                                              } else if (endDate != null) {
                                                                                return '$startDate ~ $endDate';
                                                                              } else {
                                                                                return '$startDate ~';
                                                                              }
                                                                            }
                                                                            return '-';
                                                                          }(),
                                                                          style: TextStyle(
                                                                            fontFamily: 'Pretendard',
                                                                            color: Color(0xFF64748B),
                                                                            fontSize: 14,
                                                                          ),
                                                                          textAlign: TextAlign.center,
                                                                        ),
                                                                      ),
                                                                      // 할인조건
                                                                      Expanded(
                                                                        flex: 2,
                                                                        child: Text(
                                                                          locker['locker_discount_condition_min'] != null && locker['locker_discount_ratio'] != null
                                                                              ? '${locker['locker_discount_condition_min']}분 이상 ${((double.tryParse(locker['locker_discount_ratio'].toString()) ?? 0) * 100).toStringAsFixed(0)}%'
                                                                              : '-',
                                                                          style: TextStyle(
                                                                            fontFamily: 'Pretendard',
                                                                            color: Color(0xFF64748B),
                                                                            fontSize: 14,
                                                                          ),
                                                                          textAlign: TextAlign.center,
                                                                        ),
                                                                      ),
                                                                      // 비고
                                                                      Expanded(
                                                                        flex: 2,
                                                                        child: Text(
                                                                          locker['locker_remark'] ?? '-',
                                                                          style: TextStyle(
                                                                            fontFamily: 'Pretendard',
                                                                            color: Color(0xFF64748B),
                                                                            fontSize: 14,
                                                                          ),
                                                                          textAlign: TextAlign.center,
                                                                        ),
                                                                      ),
                                                                      // 결제상태
                                                                      Expanded(
                                                                        flex: 2,
                                                                        child: Center(
                                                                          child: Builder(
                                                                            builder: (context) {
                                                                              final status = locker['payment_status'] ?? '';

                                                                              // 미배정 락커는 빈칸으로 표시
                                                                              if (status.isEmpty) {
                                                                                return Text('');
                                                                              }

                                                                              final isUnpaid = status.startsWith('미납');

                                                                              if (isUnpaid) {
                                                                                // 미납 상태는 클릭 가능한 버튼으로 표시
                                                                                return InkWell(
                                                                                  onTap: () => _showUnpaidPaymentPopup(locker),
                                                                                  child: Container(
                                                                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                                                    decoration: BoxDecoration(
                                                                                      color: Color(0xFFFEE2E2),
                                                                                      borderRadius: BorderRadius.circular(4),
                                                                                      border: Border.all(color: Color(0xFFDC2626), width: 1),
                                                                                    ),
                                                                                    child: Text(
                                                                                      status,
                                                                                      style: TextStyle(
                                                                                        fontFamily: 'Pretendard',
                                                                                        color: Color(0xFFDC2626),
                                                                                        fontSize: 12,
                                                                                        fontWeight: FontWeight.w600,
                                                                                      ),
                                                                                    ),
                                                                                  ),
                                                                                );
                                                                              } else {
                                                                                // 결제완료는 기존과 동일
                                                                                return Container(
                                                                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                                                  decoration: BoxDecoration(
                                                                                    color: Color(0xFFDCFCE7),
                                                                                    borderRadius: BorderRadius.circular(4),
                                                                                  ),
                                                                                  child: Text(
                                                                                    status,
                                                                                    style: TextStyle(
                                                                                      fontFamily: 'Pretendard',
                                                                                      color: Color(0xFF16A34A),
                                                                                      fontSize: 12,
                                                                                      fontWeight: FontWeight.w500,
                                                                                    ),
                                                                                  ),
                                                                                );
                                                                              }
                                                                            },
                                                                          ),
                                                                        ),
                                                                      ),
                                                                      // 작업
                                                                      Expanded(
                                                                        flex: 2,
                                                                        child: Center(
                                                                          child: isAssigned
                                                                            ? ElevatedButton(
                                                                                onPressed: () => _showReturnPopup(locker),
                                                                                child: Text('반납', style: TextStyle(color: Colors.white)),
                                                                                style: ElevatedButton.styleFrom(
                                                                                  backgroundColor: Color(0xFFEF4444),
                                                                                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                                                  textStyle: TextStyle(fontSize: 12),
                                                                                ),
                                                                              )
                                                                            : ElevatedButton(
                                                                                onPressed: () => _showAssignmentPopup(locker),
                                                                                child: Text('배정', style: TextStyle(color: Colors.white)),
                                                                                style: ElevatedButton.styleFrom(
                                                                                  backgroundColor: Color(0xFF10B981),
                                                                                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                                                  textStyle: TextStyle(fontSize: 12),
                                                                                ),
                                                                              ),
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  );
                                                                },
                                                                isLoading: false,
                                                                hasError: false,
                                                              ),
                                                            ),
                                                          ],
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
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // 락커 배정 팝업
            if (_model.showAssignmentPopup)
              Container(
                color: Colors.black54,
                child: Center(
                  child: Container(
                    width: 500,
                    padding: EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _model.isUnpaidPaymentMode 
                                    ? '미납락커 결제 - ${_model.selectedLockerInfo?['locker_name'] ?? ''}번'
                                    : '락커 배정 - ${_model.selectedLockerInfo?['locker_name'] ?? ''}번',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.close),
                                onPressed: () {
                                  setState(() {
                                    _model.showAssignmentPopup = false;
                                    _model.isUnpaidPaymentMode = false; // 모드 초기화
                                  });
                                },
                              ),
                            ],
                          ),
                          SizedBox(height: 20),
                          // 회원 검색
                          Text('회원', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                          SizedBox(height: 8),
                          Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _model.memberSearchController,
                                      enabled: !_model.isUnpaidPaymentMode && _model.selectedMember == null,
                                      onChanged: (_model.isUnpaidPaymentMode || _model.selectedMember != null) ? null : _searchMembersRealtime,
                                      onFieldSubmitted: (_model.isUnpaidPaymentMode || _model.selectedMember != null) ? null : (value) {
                                        if (_model.memberSearchResults.isNotEmpty) {
                                          _selectMember(_model.memberSearchResults.first);
                                        }
                                      },
                                      style: TextStyle(
                                        color: _model.selectedMember != null 
                                          ? Color(0xFF3B82F6) 
                                          : (_model.isUnpaidPaymentMode ? Color(0xFF94A3B8) : Color(0xFF1E293B)),
                                        fontWeight: _model.selectedMember != null ? FontWeight.w600 : FontWeight.normal,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: _model.selectedMember != null 
                                          ? '회원이 선택되었습니다'
                                          : (_model.isUnpaidPaymentMode ? '배정된 회원 (수정불가)' : '회원명 또는 회원번호 검색'),
                                        hintStyle: TextStyle(color: Color(0xFF94A3B8)),
                                        prefixIcon: Icon(
                                          _model.selectedMember != null ? Icons.person : Icons.search,
                                          color: _model.selectedMember != null ? Color(0xFF3B82F6) : Color(0xFF94A3B8),
                                          size: 20,
                                        ),
                                        border: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: _model.selectedMember != null ? Color(0xFF3B82F6) : Color(0xFFE2E8F0), 
                                            width: _model.selectedMember != null ? 2.0 : 1.0,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: _model.selectedMember != null ? Color(0xFF3B82F6) : Color(0xFFE2E8F0), 
                                            width: _model.selectedMember != null ? 2.0 : 1.0,
                                          ),
                                        ),
                                        disabledBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: _model.selectedMember != null ? Color(0xFF3B82F6) : Color(0xFFE2E8F0), 
                                            width: _model.selectedMember != null ? 2.0 : 1.0,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderSide: BorderSide(color: Color(0xFF3B82F6), width: 2.0),
                                        ),
                                        fillColor: _model.selectedMember != null 
                                          ? Color(0xFFF0F8FF)
                                          : (_model.isUnpaidPaymentMode ? Color(0xFFF8FAFC) : Colors.white),
                                        filled: true,
                                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      ),
                                    ),
                                  ),
                                  if (_model.selectedMember != null && !_model.isUnpaidPaymentMode) ...[
                                    SizedBox(width: 8),
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        setState(() {
                                          _model.selectedMember = null;
                                          _model.memberSearchController?.clear();
                                          _model.memberCreditInfo = null;
                                          _model.memberSearchResults.clear();
                                          _model.showMemberSearchResults = false;
                                        });
                                      },
                                      icon: Icon(Icons.link_off, size: 16),
                                      label: Text('연결해제', style: TextStyle(fontSize: 12)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Color(0xFFF1F5F9),
                                        foregroundColor: Color(0xFF64748B),
                                        elevation: 0,
                                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              // 실시간 검색 결과 목록 (회원이 선택되지 않았을 때만 표시)
                              if (_model.selectedMember == null && _model.showMemberSearchResults && _model.memberSearchResults.isNotEmpty) ...[
                                SizedBox(height: 8),
                                Container(
                                  constraints: BoxConstraints(maxHeight: 200),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Color(0xFFE2E8F0)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Color(0x0A000000),
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: ListView.separated(
                                    shrinkWrap: true,
                                    padding: EdgeInsets.zero,
                                    itemCount: _model.memberSearchResults.length,
                                    separatorBuilder: (context, index) => Divider(height: 1, color: Color(0xFFE2E8F0)),
                                    itemBuilder: (context, index) {
                                      final member = _model.memberSearchResults[index];
                                      return InkWell(
                                        onTap: () => _selectMember(member),
                                        child: Padding(
                                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                          child: Row(
                                            children: [
                                              Icon(Icons.person, size: 16, color: Color(0xFF64748B)),
                                              SizedBox(width: 8),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      member['member_name'] ?? '',
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.w500,
                                                        color: Color(0xFF1E293B),
                                                      ),
                                                    ),
                                                    SizedBox(height: 2),
                                                    Text(
                                                      'ID: ${member['member_id']} | ${member['member_phone'] ?? '-'}',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Color(0xFF64748B),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Icon(Icons.arrow_forward_ios, size: 12, color: Color(0xFF94A3B8)),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ],
                          ),
                          SizedBox(height: 16),
                          // 납부방법
                          Text('납부방법', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                          SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(right: 4),
                                  child: ElevatedButton(
                                    onPressed: () {
                                      setState(() {
                                        _model.selectedPaymentMethod = '일시납부';
                                        // 납부방법 변경 시 관련 없는 필드들 초기화
                                        _model.discountMinController?.clear();
                                        _model.discountRatioController?.clear();
                                      });
                                      // 일시납부 선택 시 가격 자동 계산
                                      _calculateTotalPrice();
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _model.selectedPaymentMethod == '일시납부' 
                                          ? Color(0xFF3B82F6) 
                                          : Colors.white,
                                      foregroundColor: _model.selectedPaymentMethod == '일시납부' 
                                          ? Colors.white 
                                          : Color(0xFF475569),
                                      side: BorderSide(
                                        color: _model.selectedPaymentMethod == '일시납부' 
                                            ? Color(0xFF3B82F6) 
                                            : Color(0xFFE2E8F0),
                                        width: 1.0,
                                      ),
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: EdgeInsets.symmetric(vertical: 12),
                                    ),
                                    child: Text('일시납부', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(left: 4),
                                  child: ElevatedButton(
                                    onPressed: () {
                                      setState(() {
                                        _model.selectedPaymentMethod = '정기결제(월별)';
                                        // 납부방법 변경 시 관련 없는 필드들 초기화
                                        _model.endDateController?.clear();
                                        _model.calculatedMonths = null;
                                        _model.totalPriceController?.clear();
                                      });
                                      // 정기결제(월별) 선택 시 가격 자동 계산
                                      _calculateTotalPrice();
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _model.selectedPaymentMethod == '정기결제(월별)' 
                                          ? Color(0xFF3B82F6) 
                                          : Colors.white,
                                      foregroundColor: _model.selectedPaymentMethod == '정기결제(월별)' 
                                          ? Colors.white 
                                          : Color(0xFF475569),
                                      side: BorderSide(
                                        color: _model.selectedPaymentMethod == '정기결제(월별)' 
                                            ? Color(0xFF3B82F6) 
                                            : Color(0xFFE2E8F0),
                                        width: 1.0,
                                      ),
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: EdgeInsets.symmetric(vertical: 12),
                                    ),
                                    child: Text('정기결제(월별)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),
                          // 결제방법
                          Text('결제방법', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                          SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(right: 4),
                                  child: ElevatedButton(
                                    onPressed: () {
                                      setState(() {
                                        _model.selectedPayMethod = '현금결제';
                                      });
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _model.selectedPayMethod == '현금결제' 
                                          ? Color(0xFF10B981) 
                                          : Colors.white,
                                      foregroundColor: _model.selectedPayMethod == '현금결제' 
                                          ? Colors.white 
                                          : Color(0xFF475569),
                                      side: BorderSide(
                                        color: _model.selectedPayMethod == '현금결제' 
                                            ? Color(0xFF10B981) 
                                            : Color(0xFFE2E8F0),
                                        width: 1.0,
                                      ),
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: EdgeInsets.symmetric(vertical: 12),
                                    ),
                                    child: Text('현금결제', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 4),
                                  child: ElevatedButton(
                                    onPressed: () {
                                      setState(() {
                                        _model.selectedPayMethod = '크레딧 결제';
                                      });
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _model.selectedPayMethod == '크레딧 결제' 
                                          ? Color(0xFF10B981) 
                                          : Colors.white,
                                      foregroundColor: _model.selectedPayMethod == '크레딧 결제' 
                                          ? Colors.white 
                                          : Color(0xFF475569),
                                      side: BorderSide(
                                        color: _model.selectedPayMethod == '크레딧 결제' 
                                            ? Color(0xFF10B981) 
                                            : Color(0xFFE2E8F0),
                                        width: 1.0,
                                      ),
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: EdgeInsets.symmetric(vertical: 12),
                                    ),
                                    child: Text('크레딧 결제', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(left: 4),
                                  child: ElevatedButton(
                                    onPressed: () {
                                      setState(() {
                                        _model.selectedPayMethod = '카드결제';
                                      });
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _model.selectedPayMethod == '카드결제' 
                                          ? Color(0xFF10B981) 
                                          : Colors.white,
                                      foregroundColor: _model.selectedPayMethod == '카드결제' 
                                          ? Colors.white 
                                          : Color(0xFF475569),
                                      side: BorderSide(
                                        color: _model.selectedPayMethod == '카드결제' 
                                            ? Color(0xFF10B981) 
                                            : Color(0xFFE2E8F0),
                                        width: 1.0,
                                      ),
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: EdgeInsets.symmetric(vertical: 12),
                                    ),
                                    child: Text('카드결제', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),
                          // 정기결제(월별)일 때만 할인 설정 표시
                          if (_model.selectedPaymentMethod == '정기결제(월별)') ...[
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('할인설정', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF475569), fontSize: 16)),
                                SizedBox(height: 12),
                                
                                
                                // 할인 설정 문장
                                Container(
                                  padding: EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Color(0xFFE2E8F0)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text('기간권 타석이용을 ', style: TextStyle(color: Color(0xFF475569), fontSize: 14)),
                                          Container(
                                            width: 80,
                                            height: 40,
                                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                            decoration: BoxDecoration(
                                              border: Border.all(color: Color(0xFFE2E8F0)),
                                              borderRadius: BorderRadius.circular(6),
                                              color: Colors.white,
                                            ),
                                            alignment: Alignment.center,
                                            child: DropdownButtonHideUnderline(
                                              child: DropdownButton<String>(
                                                value: _model.selectedDiscountIncludeOption,
                                                hint: Center(child: Text('선택', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13))),
                                                items: ['포함', '제외'].map((String value) {
                                                  Color textColor = value == '포함' ? Color(0xFF3B82F6) : Color(0xFFEF4444);
                                                  return DropdownMenuItem<String>(
                                                    value: value,
                                                    child: Container(
                                                      width: double.infinity,
                                                      color: Colors.white,
                                                      alignment: Alignment.center,
                                                      child: Text(value, style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w600)),
                                                    ),
                                                  );
                                                }).toList(),
                                                onChanged: (String? value) {
                                                  setState(() {
                                                    _model.selectedDiscountIncludeOption = value;
                                                  });
                                                },
                                                isDense: true,
                                                style: TextStyle(
                                                  color: _model.selectedDiscountIncludeOption == '포함' ? Color(0xFF3B82F6) : Color(0xFFEF4444), 
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                dropdownColor: Colors.white,
                                                alignment: AlignmentDirectional.center,
                                                isExpanded: true,
                                              ),
                                            ),
                                          ),
                                          Text('한 직전월 타석이용 시간이 ', style: TextStyle(color: Color(0xFF475569), fontSize: 14)),
                                        ],
                                      ),
                                      SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Container(
                                            width: 80,
                                            height: 40,
                                            child: TextFormField(
                                              controller: _model.discountMinController,
                                              keyboardType: TextInputType.number,
                                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: _model.selectedDiscountIncludeOption == '포함' ? Color(0xFF3B82F6) : Color(0xFFEF4444),
                                                fontWeight: FontWeight.w600,
                                              ),
                                              decoration: InputDecoration(
                                                hintText: '분',
                                                hintStyle: TextStyle(color: Color(0xFF94A3B8)),
                                                filled: true,
                                                fillColor: Colors.white,
                                                border: OutlineInputBorder(
                                                  borderSide: BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
                                                  borderRadius: BorderRadius.circular(6.0),
                                                ),
                                                enabledBorder: OutlineInputBorder(
                                                  borderSide: BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
                                                  borderRadius: BorderRadius.circular(6.0),
                                                ),
                                                focusedBorder: OutlineInputBorder(
                                                  borderSide: BorderSide(color: Color(0xFF3B82F6), width: 2.0),
                                                  borderRadius: BorderRadius.circular(6.0),
                                                ),
                                                contentPadding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
                                                isDense: false,
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          Text('분 이상인 경우', style: TextStyle(color: Color(0xFF475569))),
                                          SizedBox(width: 12),
                                          Container(
                                            width: 60,
                                            height: 40,
                                            child: TextFormField(
                                              controller: _model.discountRatioController,
                                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: _model.selectedDiscountIncludeOption == '포함' ? Color(0xFF3B82F6) : Color(0xFFEF4444),
                                                fontWeight: FontWeight.w600,
                                              ),
                                              decoration: InputDecoration(
                                                hintText: '%',
                                                hintStyle: TextStyle(color: Color(0xFF94A3B8)),
                                                filled: true,
                                                fillColor: Colors.white,
                                                border: OutlineInputBorder(
                                                  borderSide: BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
                                                  borderRadius: BorderRadius.circular(6.0),
                                                ),
                                                enabledBorder: OutlineInputBorder(
                                                  borderSide: BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
                                                  borderRadius: BorderRadius.circular(6.0),
                                                ),
                                                focusedBorder: OutlineInputBorder(
                                                  borderSide: BorderSide(color: Color(0xFF3B82F6), width: 2.0),
                                                  borderRadius: BorderRadius.circular(6.0),
                                                ),
                                                contentPadding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
                                                isDense: false,
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          Text('% 할인 적용', style: TextStyle(color: Color(0xFF475569))),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 16),
                          ],
                          // 사용 기간 (일시납부면 시작일/종료일, 정기결제(월별)면 시작일만)
                          if (_model.selectedPaymentMethod == '일시납부') ...[
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('시작일', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                                      SizedBox(height: 8),
                                      TextFormField(
                                        controller: _model.startDateController,
                                        style: TextStyle(color: Color(0xFF1E293B)),
                                        decoration: InputDecoration(
                                          hintText: 'YYYY-MM-DD',
                                          hintStyle: TextStyle(color: Color(0xFF94A3B8)),
                                          border: OutlineInputBorder(
                                            borderSide: BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderSide: BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderSide: BorderSide(color: Color(0xFF3B82F6), width: 2.0),
                                          ),
                                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        ),
                                        onTap: () async {
                                          final date = await showDatePicker(
                                            context: context,
                                            initialDate: DateTime.now(),
                                            firstDate: DateTime(2020),
                                            lastDate: DateTime(2030),
                                          );
                                          if (date != null) {
                                            _model.startDateController?.text = DateFormat('yyyy-MM-dd').format(date);
                                            // 날짜 변경 시 가격 자동 계산
                                            _calculateTotalPrice();
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('종료일', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                                      SizedBox(height: 8),
                                      TextFormField(
                                        controller: _model.endDateController,
                                        style: TextStyle(color: Color(0xFF1E293B)),
                                        decoration: InputDecoration(
                                          hintText: 'YYYY-MM-DD',
                                          hintStyle: TextStyle(color: Color(0xFF94A3B8)),
                                          border: OutlineInputBorder(
                                            borderSide: BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderSide: BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderSide: BorderSide(color: Color(0xFF3B82F6), width: 2.0),
                                          ),
                                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        ),
                                        onTap: () async {
                                          final date = await showDatePicker(
                                            context: context,
                                            initialDate: DateTime.now(),
                                            firstDate: DateTime(2020),
                                            lastDate: DateTime(2030),
                                          );
                                          if (date != null) {
                                            _model.endDateController?.text = DateFormat('yyyy-MM-dd').format(date);
                                            // 날짜 변경 시 가격 자동 계산
                                            _calculateTotalPrice();
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            // 계산된 개월수 표시
                            if (_model.calculatedMonths != null) ...[
                              SizedBox(height: 8),
                              Text(
                                '계산된 기간: ${_model.calculatedMonths}',
                                style: TextStyle(
                                  color: Color(0xFF3B82F6),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ] else if (_model.selectedPaymentMethod == '정기결제(월별)') ...[
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('시작일', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                                SizedBox(height: 8),
                                TextFormField(
                                  controller: _model.startDateController,
                                  style: TextStyle(color: Color(0xFF1E293B)),
                                  decoration: InputDecoration(
                                    hintText: 'YYYY-MM-DD',
                                    hintStyle: TextStyle(color: Color(0xFF94A3B8)),
                                    border: OutlineInputBorder(
                                      borderSide: BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderSide: BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderSide: BorderSide(color: Color(0xFF3B82F6), width: 2.0),
                                    ),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  onTap: () async {
                                    final date = await showDatePicker(
                                      context: context,
                                      initialDate: DateTime.now(),
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime(2030),
                                    );
                                    if (date != null) {
                                      _model.startDateController?.text = DateFormat('yyyy-MM-dd').format(date);
                                      // 정기결제(월별) 시작일 변경 시 가격 자동 계산
                                      _calculateTotalPrice();
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                          // 가격 (일시납부 및 정기결제(월별) 모두 표시)
                          if (_model.selectedPaymentMethod != null) ...[
                            Text('총 가격', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                            SizedBox(height: 8),
                            TextFormField(
                              controller: _model.totalPriceController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              style: TextStyle(color: Color(0xFF1E293B)),
                              decoration: InputDecoration(
                                hintText: '자동 계산된 가격 (수정 가능)',
                                hintStyle: TextStyle(color: Color(0xFF94A3B8)),
                                border: OutlineInputBorder(
                                  borderSide: BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Color(0xFF3B82F6), width: 2.0),
                                ),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                suffixText: '원',
                              ),
                            ),
                            SizedBox(height: 16),
                          ],
                          // 비고
                          Text('비고', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                          SizedBox(height: 8),
                          TextFormField(
                            controller: _model.remarkController,
                            maxLines: 3,
                            style: TextStyle(color: Color(0xFF1E293B)),
                            decoration: InputDecoration(
                              hintText: '메모사항을 입력하세요',
                              hintStyle: TextStyle(color: Color(0xFF94A3B8)),
                              border: OutlineInputBorder(
                                borderSide: BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Color(0xFF3B82F6), width: 2.0),
                              ),
                              contentPadding: EdgeInsets.all(12),
                            ),
                          ),
                          SizedBox(height: 24),
                          // 버튼
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _model.showAssignmentPopup = false;
                                  });
                                },
                                child: Text('취소'),
                              ),
                              SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: _saveAssignment,
                                child: Text('저장'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFF3B82F6),
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            // 락커 기본설정 팝업
            if (_model.showSettingsPopup)
              Container(
                color: Colors.black54,
                child: Center(
                  child: Container(
                    width: 400,
                    padding: EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '락커 기본설정',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.close),
                              onPressed: () {
                                setState(() {
                                  _model.showSettingsPopup = false;
                                });
                              },
                            ),
                          ],
                        ),
                        SizedBox(height: 20),
                        Text('총 락커 수량', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                        SizedBox(height: 8),
                        TextFormField(
                          controller: _model.totalCountController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          style: TextStyle(color: Color(0xFF1E293B)),
                          decoration: InputDecoration(
                            hintText: '락커 개수를 입력하세요',
                            hintStyle: TextStyle(color: Color(0xFF94A3B8)),
                            border: OutlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFF3B82F6), width: 2.0),
                            ),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          '※ 자동 채번은 입력한 수량에 맞춰 락커를 스마트하게 추가/삭제합니다.',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                        SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _model.showSettingsPopup = false;
                                });
                              },
                              child: Text('취소'),
                            ),
                            SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _autoNumberLockers,
                              child: Text('자동 채번'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFF3B82F6),
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            // 개별 편집 팝업
            if (_model.showIndividualEditPopup)
              Container(
                color: Colors.black54,
                child: Center(
                  child: Container(
                    width: 400,
                    padding: EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '락커 정보 수정 (${_model.editingLockerId}번)',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.close),
                              onPressed: () {
                                setState(() {
                                  _model.showIndividualEditPopup = false;
                                });
                              },
                            ),
                          ],
                        ),
                        SizedBox(height: 20),
                        Text('구역', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                        SizedBox(height: 8),
                        TextFormField(
                          controller: _model.editZoneController,
                          style: TextStyle(color: Color(0xFF1E293B)),
                          decoration: InputDecoration(
                            hintText: '예: 매장앞, 매장옆, 매장뒤',
                            hintStyle: TextStyle(color: Color(0xFF94A3B8)),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Color(0xFF3B82F6), width: 2),
                            ),
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                        SizedBox(height: 16),
                        Text('종류', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                        SizedBox(height: 8),
                        TextFormField(
                          controller: _model.editTypeController,
                          style: TextStyle(color: Color(0xFF1E293B)),
                          decoration: InputDecoration(
                            hintText: '예: 일반, VIP, 프리미엄',
                            hintStyle: TextStyle(color: Color(0xFF94A3B8)),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Color(0xFF3B82F6), width: 2),
                            ),
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                        SizedBox(height: 16),
                        Text('기본가격', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                        SizedBox(height: 8),
                        TextFormField(
                          controller: _model.editPriceController,
                          style: TextStyle(color: Color(0xFF1E293B)),
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: '예: 50000',
                            hintStyle: TextStyle(color: Color(0xFF94A3B8)),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Color(0xFF3B82F6), width: 2),
                            ),
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                        SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () {
                                  setState(() {
                                    _model.showIndividualEditPopup = false;
                                  });
                                },
                                child: Text('취소'),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _saveIndividualEdit,
                                child: Text('저장'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFF3B82F6),
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
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
              ),
            // 일괄 속성 부여 팝업
            if (_model.showBulkAssignPopup)
              Container(
                color: Colors.black54,
                child: Center(
                  child: Container(
                    width: 400,
                    padding: EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '속성 설정 (${_model.selectedLockerIds.length}개 선택)',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.close),
                              onPressed: () {
                                setState(() {
                                  _model.showBulkAssignPopup = false;
                                });
                              },
                            ),
                          ],
                        ),
                        SizedBox(height: 20),
                        Text('구역', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _model.bulkZoneController,
                                style: TextStyle(color: Color(0xFF1E293B)),
                                decoration: InputDecoration(
                                  hintText: '예: 매장앞, 매장옆, 매장뒤',
                                  hintStyle: TextStyle(color: Color(0xFF94A3B8)),
                                  border: OutlineInputBorder(
                                    borderSide: BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: Color(0xFF3B82F6), width: 2.0),
                                  ),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _applyZoneOnly,
                              child: Text('적용'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFF3B82F6),
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        Text('종류', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _model.bulkTypeController,
                                style: TextStyle(color: Color(0xFF1E293B)),
                                decoration: InputDecoration(
                                  hintText: '예: 상부장, 하부장',
                                  hintStyle: TextStyle(color: Color(0xFF94A3B8)),
                                  border: OutlineInputBorder(
                                    borderSide: BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: Color(0xFF3B82F6), width: 2.0),
                                  ),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _applyTypeOnly,
                              child: Text('적용'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFF059669),
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        Text('기본가격', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _model.bulkPriceController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                style: TextStyle(color: Color(0xFF1E293B)),
                                decoration: InputDecoration(
                                  hintText: '예: 30000',
                                  hintStyle: TextStyle(color: Color(0xFF94A3B8)),
                                  border: OutlineInputBorder(
                                    borderSide: BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: Color(0xFF3B82F6), width: 2.0),
                                  ),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _applyPriceOnly,
                              child: Text('적용'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFFDC2626),
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        Text(
                          '※ 각 필드의 적용 버튼을 눌러 해당 속성만 변경할 수 있습니다.',
                          style: TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 12,
                          ),
                        ),
                        SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _model.showBulkAssignPopup = false;
                                });
                              },
                              child: Text('닫기'),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            // 락커 반납 팝업
            if (_model.showReturnPopup)
              Container(
                color: Colors.black54,
                child: Center(
                  child: Container(
                    width: 400,
                    padding: EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '락커 반납 - ${_model.selectedLockerInfo?['locker_name'] ?? ''}번',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.close),
                              onPressed: () {
                                setState(() {
                                  _model.showReturnPopup = false;
                                });
                              },
                            ),
                          ],
                        ),
                        SizedBox(height: 20),
                        Text(
                          '현재 사용자: ${_model.selectedLockerInfo?['member_name'] ?? 'ID: ${_model.selectedLockerInfo?['member_id']}'}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569),
                          ),
                        ),
                        SizedBox(height: 16),
                        
                        // 결제 정보 요약 표시
                        if (_model.returnPaymentInfo != null && _model.returnPaymentInfo!['success'] == true) ...[
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '취소 대상 청구서 정보',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                                SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '결제방법: ${_model.returnPaymentInfo!['bill_summary']['payment_method'] ?? ''}',
                                      style: TextStyle(color: Color(0xFF1E293B)),
                                    ),
                                    Text(
                                      '금액: ${_model.returnPaymentInfo!['bill_summary']['locker_bill_netamt']?.toString() ?? '0'}원',
                                      style: TextStyle(color: Color(0xFF1E293B)),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 4),
                                Text(
                                  '기간: ${_model.returnPaymentInfo!['bill_summary']['locker_bill_start']} ~ ${_model.returnPaymentInfo!['bill_summary']['locker_bill_end']}',
                                  style: TextStyle(color: Color(0xFF1E293B)),
                                ),
                                if (_model.returnPaymentInfo!['bill_summary']['locker_remark']?.isNotEmpty == true) ...[
                                  SizedBox(height: 4),
                                  Text(
                                    '비고: ${_model.returnPaymentInfo!['bill_summary']['locker_remark']}',
                                    style: TextStyle(color: Color(0xFF1E293B)),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          SizedBox(height: 16),
                        ],
                        
                        SizedBox(height: 4),
                        Text('반납일자', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                        SizedBox(height: 8),
                        TextField(
                          controller: _model.returnDateController,
                          style: TextStyle(color: Color(0xFF1E293B)),
                          onChanged: (value) {
                            // 반납일자 변경시 결제 정보 다시 조회
                            if (_model.selectedLockerInfo?['member_id'] != null && value.length == 10) {
                              _refreshPaymentInfo();
                            }
                          },
                          decoration: InputDecoration(
                            hintText: 'YYYY-MM-DD',
                            hintStyle: TextStyle(color: Color(0xFF94A3B8)),
                            border: OutlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFF3B82F6), width: 2.0),
                            ),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            suffixIcon: IconButton(
                              icon: Icon(Icons.calendar_today, size: 20),
                              onPressed: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now().add(Duration(days: 365)),
                                );
                                if (date != null) {
                                  _model.returnDateController?.text = 
                                    DateFormat('yyyy-MM-dd').format(date);
                                  // 날짜 선택 후 결제 정보 다시 조회
                                  _refreshPaymentInfo();
                                }
                              },
                            ),
                          ),
                        ),
                        SizedBox(height: 20),
                        Text('환불 수단', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                        SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: (_model.availableRefundMethods.isNotEmpty 
                              ? _model.availableRefundMethods 
                              : ['현금', '카드취소', '크레딧환불', '환불불가']).map((method) {
                            final isSelected = _model.selectedRefundMethod == method;
                            return InkWell(
                              onTap: () {
                                setState(() {
                                  _model.selectedRefundMethod = method;
                                  if (method == '환불불가') {
                                    _model.refundAmountController?.clear();
                                  }
                                });
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected ? Color(0xFF3B82F6) : Colors.white,
                                  border: Border.all(
                                    color: isSelected ? Color(0xFF3B82F6) : Color(0xFFE2E8F0),
                                    width: 1.0,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  method,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : Color(0xFF1E293B),
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        SizedBox(height: 16),
                        if (_model.selectedRefundMethod != null && _model.selectedRefundMethod != '환불불가') ...[
                          Text('환불 금액', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                          SizedBox(height: 8),
                          TextFormField(
                            controller: _model.refundAmountController,
                            keyboardType: TextInputType.number,
                            style: TextStyle(color: Color(0xFF1E293B)),
                            decoration: InputDecoration(
                              hintText: '환부할 금액을 입력하세요',
                              hintStyle: TextStyle(color: Color(0xFF94A3B8)),
                              border: OutlineInputBorder(
                                borderSide: BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Color(0xFF3B82F6), width: 2.0),
                              ),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              suffixText: '원',
                            ),
                          ),
                          SizedBox(height: 16),
                        ],
                        Text(
                          '※ 반납 후 락커는 비어있음 상태로 변경됩니다.',
                          style: TextStyle(
                            color: Colors.orange,
                            fontSize: 12,
                          ),
                        ),
                        SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _model.showReturnPopup = false;
                                });
                              },
                              child: Text('취소'),
                            ),
                            SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _processReturn,
                              child: Text('반납 처리'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFFEF4444),
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            // 락커 설정 팝업
            if (_model.showLockerSettingsPopup)
              Container(
                color: Colors.black.withOpacity(0.5),
                child: Center(
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.75,
                    height: MediaQuery.of(context).size.height * 0.85,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // 상단 헤더
                        Container(
                          padding: EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.settings, color: Color(0xFF3B82F6), size: 28),
                              SizedBox(width: 12),
                              Text(
                                '락커 설정',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              Spacer(),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Color(0xFFEBF8FF),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '총 ${_model.lockerData.length}개 락커',
                                  style: TextStyle(
                                    color: Color(0xFF3B82F6),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              SizedBox(width: 16),
                              ElevatedButton.icon(
                                onPressed: _showTotalCountPopup,
                                icon: Icon(Icons.edit, size: 18),
                                label: Text('총수량 변경'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFF10B981),
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  elevation: 2,
                                ),
                              ),
                              SizedBox(width: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Color(0xFFE2E8F0)),
                                ),
                                child: IconButton(
                                  icon: Icon(Icons.close, color: Color(0xFF64748B)),
                                  onPressed: () {
                                    setState(() {
                                      _model.showLockerSettingsPopup = false;
                                      _model.selectedLockerIds.clear();
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        // 메인 컨텐츠 (좌우 분할)
                        Expanded(
                          child: Row(
                            children: [
                              // 왼쪽: 락커 선택 영역 (60%)
                              Expanded(
                                flex: 6,
                                child: Container(
                                  padding: EdgeInsets.all(24),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // 범위 설정 - 심플 버전
                                      Container(
                                        padding: EdgeInsets.all(12),
                                        margin: EdgeInsets.only(bottom: 16),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Color(0xFFE2E8F0)),
                                        ),
                                        child: LockerFilter(
                                          model: _model,
                                          lockerData: _model.lockerData,
                                          onFilterChanged: (filteredData) {
                                            setState(() {
                                              _model.filteredSettingsLockers = filteredData;
                                            });
                                          },
                                          onResetFilters: () {
                                            setState(() {
                                              _model.filteredSettingsLockers = _model.lockerData;
                                            });
                                          },
                                        ),
                                      ),
                                      // 락커 선택 타이틀 (타일 컨테이너 위로 이동)
                                      Row(
                                        children: [
                                          Icon(Icons.grid_view, color: Color(0xFF3B82F6), size: 20),
                                          SizedBox(width: 8),
                                          Text(
                                            '락커 선택',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF1E293B),
                                            ),
                                          ),
                                          Spacer(),
                                          Container(
                                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: _model.selectedLockerIds.isNotEmpty 
                                                  ? Color(0xFFDCFCE7) 
                                                  : Color(0xFFF1F5F9),
                                              borderRadius: BorderRadius.circular(15),
                                            ),
                                            child: Text(
                                              '${_model.selectedLockerIds.length}개 선택됨',
                                              style: TextStyle(
                                                color: _model.selectedLockerIds.isNotEmpty 
                                                    ? Color(0xFF16A34A) 
                                                    : Color(0xFF64748B),
                                                fontWeight: FontWeight.w600,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 12),
                                      Expanded(
                                        child: Container(
                                          padding: EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: Color(0xFFE2E8F0)),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.05),
                                                blurRadius: 10,
                                                offset: Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: _model.filteredSettingsLockers.isEmpty 
                                              ? Center(
                                                  child: Column(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      Icon(Icons.inbox, size: 48, color: Color(0xFF9CA3AF)),
                                                      SizedBox(height: 12),
                                                      Text(
                                                        '조건에 맞는 락커가 없습니다',
                                                        style: TextStyle(
                                                          color: Color(0xFF64748B),
                                                          fontSize: 16,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                )
                                              : GridView.builder(
                                                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                                    crossAxisCount: _calculateCrossAxisCount(context),
                                                    crossAxisSpacing: 8,
                                                    mainAxisSpacing: 8,
                                                    childAspectRatio: 1.0,
                                                  ),
                                                  itemCount: _model.filteredSettingsLockers.length,
                                                  itemBuilder: (context, index) {
                                                    final locker = _model.filteredSettingsLockers[index];
                                                    final lockerId = locker['locker_id'] as int;
                                                    final isSelected = _model.selectedLockerIds.contains(lockerId);
                                                    final lockerName = locker['locker_name'] ?? '';
                                                    final isAssigned = locker['member_id'] != null;
                                                    
                                                    return InkWell(
                                                      onTap: () {
                                                        setState(() {
                                                          if (isSelected) {
                                                            _model.selectedLockerIds.remove(lockerId);
                                                          } else {
                                                            _model.selectedLockerIds.add(lockerId);
                                                          }
                                                        });
                                                      },
                                                      onDoubleTap: () {
                                                        _showIndividualEditPopup(locker);
                                                      },
                                                      borderRadius: BorderRadius.circular(8),
                                                      child: Container(
                                                        decoration: BoxDecoration(
                                                          color: isSelected 
                                                              ? Color(0xFF3B82F6) 
                                                              : isAssigned 
                                                                  ? Color(0xFFFEF3C7)
                                                                  : Colors.white,
                                                          borderRadius: BorderRadius.circular(8),
                                                          border: Border.all(
                                                            color: isSelected 
                                                                ? Color(0xFF3B82F6) 
                                                                : Color(0xFFE2E8F0),
                                                            width: isSelected ? 2 : 1,
                                                          ),
                                                          boxShadow: isSelected 
                                                              ? [
                                                                  BoxShadow(
                                                                    color: Color(0xFF3B82F6).withOpacity(0.3),
                                                                    blurRadius: 4,
                                                                    offset: Offset(0, 2),
                                                                  ),
                                                                ]
                                                              : [
                                                                  BoxShadow(
                                                                    color: Colors.black.withOpacity(0.05),
                                                                    blurRadius: 2,
                                                                    offset: Offset(0, 1),
                                                                  ),
                                                                ],
                                                        ),
                                                        child: Stack(
                                                          children: [
                                                            // 락커번호 뱃지 (좌측상단)
                                                            Positioned(
                                                              top: 0,
                                                              left: 0,
                                                              child: Container(
                                                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                                                decoration: BoxDecoration(
                                                                  gradient: LinearGradient(
                                                                    colors: isSelected 
                                                                        ? [Colors.white.withOpacity(0.3), Colors.white.withOpacity(0.2)]
                                                                        : [Color(0xFF6B7280), Color(0xFF4B5563)],
                                                                    begin: Alignment.topLeft,
                                                                    end: Alignment.bottomRight,
                                                                  ),
                                                                  borderRadius: BorderRadius.only(
                                                                    topLeft: Radius.circular(8),
                                                                    bottomRight: Radius.circular(6),
                                                                  ),
                                                                  boxShadow: [
                                                                    BoxShadow(
                                                                      color: Colors.black.withOpacity(0.2),
                                                                      blurRadius: 3,
                                                                      offset: Offset(0, 1),
                                                                    ),
                                                                  ],
                                                                ),
                                                                child: Text(
                                                                  lockerName,
                                                                  style: TextStyle(
                                                                    color: isSelected ? Colors.white : Colors.white,
                                                                    fontSize: 11,
                                                                    fontWeight: FontWeight.bold,
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                            // 선택 체크 아이콘 (우측상단)
                                                            if (isSelected)
                                                              Positioned(
                                                                top: 4,
                                                                right: 4,
                                                                child: Icon(
                                                                  Icons.check_circle,
                                                                  color: Colors.white,
                                                                  size: 16,
                                                                ),
                                                              ),
                                                            // 메인 콘텐츠 (속성 3줄)
                                                            Positioned.fill(
                                                              child: Padding(
                                                                padding: EdgeInsets.only(top: 22, left: 8, right: isSelected ? 24 : 8, bottom: 8),
                                                                child: Column(
                                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                                  children: [
                                                                    // 구역
                                                                    Row(
                                                                      children: [
                                                                        Icon(
                                                                          Icons.location_on,
                                                                          size: 10,
                                                                          color: isSelected ? Colors.white : Color(0xFF6B7280),
                                                                        ),
                                                                        SizedBox(width: 2),
                                                                        Expanded(
                                                                          child: Text(
                                                                            locker['locker_zone'] ?? '미지정',
                                                                            style: TextStyle(
                                                                              fontSize: 9,
                                                                              color: isSelected ? Colors.white : Color(0xFF374151),
                                                                              fontWeight: FontWeight.w500,
                                                                            ),
                                                                            maxLines: 1,
                                                                            overflow: TextOverflow.ellipsis,
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                    SizedBox(height: 3),
                                                                    // 종류
                                                                    Row(
                                                                      children: [
                                                                        Icon(
                                                                          Icons.category,
                                                                          size: 10,
                                                                          color: isSelected ? Colors.white : Color(0xFF6B7280),
                                                                        ),
                                                                        SizedBox(width: 2),
                                                                        Expanded(
                                                                          child: Text(
                                                                            locker['locker_type'] ?? '일반',
                                                                            style: TextStyle(
                                                                              fontSize: 9,
                                                                              color: isSelected ? Colors.white : Color(0xFF374151),
                                                                              fontWeight: FontWeight.w500,
                                                                            ),
                                                                            maxLines: 1,
                                                                            overflow: TextOverflow.ellipsis,
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                    SizedBox(height: 3),
                                                                    // 기본가격
                                                                    Row(
                                                                      children: [
                                                                        Icon(
                                                                          Icons.attach_money,
                                                                          size: 10,
                                                                          color: isSelected ? Colors.white : Color(0xFF6B7280),
                                                                        ),
                                                                        SizedBox(width: 2),
                                                                        Expanded(
                                                                          child: Text(
                                                                            locker['locker_price'] != null && locker['locker_price'] > 0
                                                                                ? '${(locker['locker_price']).toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}' 
                                                                                : '0',
                                                                            style: TextStyle(
                                                                              fontSize: 9,
                                                                              color: isSelected 
                                                                                  ? Colors.white 
                                                                                  : (locker['locker_price'] != null && locker['locker_price'] > 0)
                                                                                      ? Color(0xFF059669)
                                                                                      : Color(0xFF6B7280),
                                                                              fontWeight: FontWeight.w600,
                                                                            ),
                                                                            maxLines: 1,
                                                                            overflow: TextOverflow.ellipsis,
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                                                            // 사용중 뱃지 (하단)
                                                            if (isAssigned && !isSelected)
                                                              Positioned(
                                                                bottom: 4,
                                                                right: 4,
                                                                child: Container(
                                                                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                                  decoration: BoxDecoration(
                                                                    color: Color(0xFFEAB308),
                                                                    borderRadius: BorderRadius.circular(4),
                                                                  ),
                                                                  child: Text(
                                                                    '사용중',
                                                                    style: TextStyle(
                                                                      fontSize: 8,
                                                                      color: Colors.white,
                                                                      fontWeight: FontWeight.w600,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                          ],
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // 구분선
                              Container(
                                width: 1,
                                color: Color(0xFFE2E8F0),
                              ),
                              // 오른쪽: 속성 설정 영역 (40%)
                              Expanded(
                                flex: 4,
                                child: Container(
                                  padding: EdgeInsets.all(24),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.tune, color: Color(0xFF3B82F6), size: 20),
                                          SizedBox(width: 8),
                                          Text(
                                            '속성 설정',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF1E293B),
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        '선택된 락커에 일괄 적용할 속성을 설정하세요',
                                        style: TextStyle(
                                          color: Color(0xFF64748B),
                                          fontSize: 14,
                                        ),
                                      ),
                                      SizedBox(height: 24),
                                      Expanded(
                                        child: Column(
                                          children: [
                                            // 구역 설정 카드
                                            Container(
                                              padding: EdgeInsets.all(20),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: Color(0xFFE2E8F0)),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black.withOpacity(0.05),
                                                    blurRadius: 8,
                                                    offset: Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Icon(Icons.location_on, color: Color(0xFF3B82F6), size: 20),
                                                      SizedBox(width: 8),
                                                      Text(
                                                        '구역',
                                                        style: TextStyle(
                                                          fontWeight: FontWeight.w700,
                                                          color: Color(0xFF374151),
                                                          fontSize: 16,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  SizedBox(height: 12),
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: TextFormField(
                                                          controller: _model.bulkZoneController,
                                                          style: TextStyle(
                                                            fontSize: 16,
                                                            color: Colors.black,
                                                          ),
                                                          decoration: InputDecoration(
                                                            hintText: '구역명을 입력하세요',
                                                            hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
                                                            border: OutlineInputBorder(
                                                              borderRadius: BorderRadius.circular(8),
                                                              borderSide: BorderSide(color: Color(0xFFE2E8F0)),
                                                            ),
                                                            enabledBorder: OutlineInputBorder(
                                                              borderRadius: BorderRadius.circular(8),
                                                              borderSide: BorderSide(color: Color(0xFFE2E8F0)),
                                                            ),
                                                            focusedBorder: OutlineInputBorder(
                                                              borderRadius: BorderRadius.circular(8),
                                                              borderSide: BorderSide(color: Color(0xFF3B82F6), width: 2),
                                                            ),
                                                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                                            filled: true,
                                                            fillColor: Color(0xFFFAFAFA),
                                                          ),
                                                        ),
                                                      ),
                                                      SizedBox(width: 12),
                                                      ElevatedButton(
                                                        onPressed: _applyZoneOnly,
                                                        child: Text(
                                                          '적용',
                                                          style: TextStyle(
                                                            fontSize: 14,
                                                            fontWeight: FontWeight.w600,
                                                          ),
                                                        ),
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: Color(0xFF3B82F6),
                                                          foregroundColor: Colors.white,
                                                          shape: RoundedRectangleBorder(
                                                            borderRadius: BorderRadius.circular(8),
                                                          ),
                                                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                                          elevation: 2,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            SizedBox(height: 16),
                                            // 종류 설정 카드
                                            Container(
                                              padding: EdgeInsets.all(20),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: Color(0xFFE2E8F0)),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black.withOpacity(0.05),
                                                    blurRadius: 8,
                                                    offset: Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Icon(Icons.category, color: Color(0xFF3B82F6), size: 20),
                                                      SizedBox(width: 8),
                                                      Text(
                                                        '종류',
                                                        style: TextStyle(
                                                          fontWeight: FontWeight.w700,
                                                          color: Color(0xFF374151),
                                                          fontSize: 16,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  SizedBox(height: 12),
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: TextFormField(
                                                          controller: _model.bulkTypeController,
                                                          style: TextStyle(
                                                            fontSize: 16,
                                                            color: Colors.black,
                                                          ),
                                                          decoration: InputDecoration(
                                                            hintText: '락커 종류를 입력하세요',
                                                            hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
                                                            border: OutlineInputBorder(
                                                              borderRadius: BorderRadius.circular(8),
                                                              borderSide: BorderSide(color: Color(0xFFE2E8F0)),
                                                            ),
                                                            enabledBorder: OutlineInputBorder(
                                                              borderRadius: BorderRadius.circular(8),
                                                              borderSide: BorderSide(color: Color(0xFFE2E8F0)),
                                                            ),
                                                            focusedBorder: OutlineInputBorder(
                                                              borderRadius: BorderRadius.circular(8),
                                                              borderSide: BorderSide(color: Color(0xFF3B82F6), width: 2),
                                                            ),
                                                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                                            filled: true,
                                                            fillColor: Color(0xFFFAFAFA),
                                                          ),
                                                        ),
                                                      ),
                                                      SizedBox(width: 12),
                                                      ElevatedButton(
                                                        onPressed: _applyTypeOnly,
                                                        child: Text(
                                                          '적용',
                                                          style: TextStyle(
                                                            fontSize: 14,
                                                            fontWeight: FontWeight.w600,
                                                          ),
                                                        ),
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: Color(0xFF3B82F6),
                                                          foregroundColor: Colors.white,
                                                          shape: RoundedRectangleBorder(
                                                            borderRadius: BorderRadius.circular(8),
                                                          ),
                                                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                                          elevation: 2,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            SizedBox(height: 16),
                                            // 기본가격 설정 카드
                                            Container(
                                              padding: EdgeInsets.all(20),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: Color(0xFFE2E8F0)),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black.withOpacity(0.05),
                                                    blurRadius: 8,
                                                    offset: Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Icon(Icons.attach_money, color: Color(0xFF3B82F6), size: 20),
                                                      SizedBox(width: 8),
                                                      Text(
                                                        '기본가격',
                                                        style: TextStyle(
                                                          fontWeight: FontWeight.w700,
                                                          color: Color(0xFF374151),
                                                          fontSize: 16,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  SizedBox(height: 12),
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: TextFormField(
                                                          controller: _model.bulkPriceController,
                                                          keyboardType: TextInputType.number,
                                                          style: TextStyle(
                                                            fontSize: 16,
                                                            color: Colors.black,
                                                          ),
                                                          decoration: InputDecoration(
                                                            hintText: '월 사용료를 입력하세요',
                                                            hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
                                                            border: OutlineInputBorder(
                                                              borderRadius: BorderRadius.circular(8),
                                                              borderSide: BorderSide(color: Color(0xFFE2E8F0)),
                                                            ),
                                                            enabledBorder: OutlineInputBorder(
                                                              borderRadius: BorderRadius.circular(8),
                                                              borderSide: BorderSide(color: Color(0xFFE2E8F0)),
                                                            ),
                                                            focusedBorder: OutlineInputBorder(
                                                              borderRadius: BorderRadius.circular(8),
                                                              borderSide: BorderSide(color: Color(0xFF3B82F6), width: 2),
                                                            ),
                                                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                                            filled: true,
                                                            fillColor: Color(0xFFFAFAFA),
                                                            suffixText: '원',
                                                            suffixStyle: TextStyle(
                                                              color: Color(0xFF64748B),
                                                              fontWeight: FontWeight.w500,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      SizedBox(width: 12),
                                                      ElevatedButton(
                                                        onPressed: _applyPriceOnly,
                                                        child: Text(
                                                          '적용',
                                                          style: TextStyle(
                                                            fontSize: 14,
                                                            fontWeight: FontWeight.w600,
                                                          ),
                                                        ),
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: Color(0xFF3B82F6),
                                                          foregroundColor: Colors.white,
                                                          shape: RoundedRectangleBorder(
                                                            borderRadius: BorderRadius.circular(8),
                                                          ),
                                                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                                          elevation: 2,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Spacer(),
                                          ],
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
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 속성 필터 적용 (이용상태, 회원 검색 포함)

  // 아이콘이 있는 속성 태그
  Widget _buildPropertyTagWithIcon(String label, String category, IconData icon) {
    Set<String> selectedSet;
    switch (category) {
      case 'zone':
        selectedSet = _model.selectedZones;
        break;
      case 'type':
        selectedSet = _model.selectedTypes;
        break;
      case 'price':
        selectedSet = _model.selectedPrices;
        break;
      default:
        selectedSet = <String>{};
    }
    
    final isSelected = selectedSet.contains(label);
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            if (isSelected) {
              selectedSet.remove(label);
            } else {
              selectedSet.add(label);
            }
          });
          // Filter logic moved to LockerFilter widget
        },
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected ? Color(0xFFDCFCE7) : Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected ? Color(0xFF22C55E) : Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 11,
                color: isSelected ? Color(0xFF16A34A) : Color(0xFF6B7280),
              ),
              SizedBox(width: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: isSelected ? Color(0xFF16A34A) : Color(0xFF374151),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 깔끔한 속성 태그 (색상 없음)
  Widget _buildCleanPropertyTag(String label, String category) {
    Set<String> selectedSet;
    switch (category) {
      case 'zone':
        selectedSet = _model.selectedZones;
        break;
      case 'type':
        selectedSet = _model.selectedTypes;
        break;
      case 'price':
        selectedSet = _model.selectedPrices;
        break;
      default:
        selectedSet = <String>{};
    }
    
    final isSelected = selectedSet.contains(label);
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            if (isSelected) {
              selectedSet.remove(label);
            } else {
              selectedSet.add(label);
            }
          });
          // Filter logic moved to LockerFilter widget
        },
        borderRadius: BorderRadius.circular(6),
        child: Container(
          height: 32,
          padding: EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: isSelected ? Color(0xFF1E293B) : Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected ? Color(0xFF1E293B) : Color(0xFFE2E8F0), 
              width: 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : Color(0xFF1E293B),
              ),
            ),
          ),
        ),
      ),
    );
  }
}