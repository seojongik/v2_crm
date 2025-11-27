import 'package:flutter/material.dart';
import 'locker_api_service.dart';
import 'crm6_locker_model.dart';

class LockerFilter extends StatefulWidget {
  final Crm6LockerModel model;
  final List<Map<String, dynamic>> lockerData;
  final Function(List<Map<String, dynamic>>) onFilterChanged;
  final VoidCallback? onResetFilters;
  final bool isMainFilter;

  const LockerFilter({
    Key? key,
    required this.model,
    required this.lockerData,
    required this.onFilterChanged,
    this.onResetFilters,
    this.isMainFilter = false,
  }) : super(key: key);

  @override
  State<LockerFilter> createState() => _LockerFilterState();
}

class _LockerFilterState extends State<LockerFilter> {
  // 배정된 회원들의 정보 캐시
  List<Map<String, dynamic>> _assignedMembersCache = [];
  
  // 로컬 필터 상태 관리
  String? _lockerFilter; // 'even', 'odd', 'range', 'single', null
  String? _rangeStart;
  String? _rangeEnd;
  Set<String> _selectedZones = {};
  Set<String> _selectedTypes = {};  
  Set<String> _selectedPrices = {};
  String? _selectedUsageStatus; // 'unpaid', 'used', 'empty', null
  
  // 컨트롤러들
  final TextEditingController _rangeStartController = TextEditingController();
  final TextEditingController _rangeEndController = TextEditingController();
  final TextEditingController _singleNumberController = TextEditingController();
  final TextEditingController _memberSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAssignedMembers();
  }

  @override
  void dispose() {
    _rangeStartController.dispose();
    _rangeEndController.dispose(); 
    _singleNumberController.dispose();
    _memberSearchController.dispose();
    super.dispose();
  }

  // 배정된 회원들의 정보 미리 로드
  void _loadAssignedMembers() async {
    final assignedMemberIds = <int>{};
    for (final locker in widget.lockerData) {
      if (locker['member_id'] != null) {
        assignedMemberIds.add(locker['member_id'] as int);
      }
    }

    if (assignedMemberIds.isNotEmpty) {
      try {
        _assignedMembersCache = await LockerApiService.getMembersByIds(assignedMemberIds.toList());
        print('회원 정보 캐시 완료: ${_assignedMembersCache.length}명');
      } catch (e) {
        print('회원 정보 로드 오류: $e');
        _assignedMembersCache = [];
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12),
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 번호필터 줄
          _buildNumberFilterRow(),
          SizedBox(height: 12),
          // 속성필터 줄
          _buildPropertyFilterRow(),
          SizedBox(height: 12),
          // 이용상태 필터와 회원명 검색 줄
          _buildUsageStatusAndMemberSearchRow(),
        ],
      ),
    );
  }

  // 번호필터 UI
  Widget _buildNumberFilterRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 번호필터 제목
        Padding(
          padding: EdgeInsets.only(top: 3),
          child: Text(
            '번호필터',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
        ),
        SizedBox(width: 12),
        // 단일 번호 검색
        Container(
          width: 120,
          height: 32,
          child: TextField(
            controller: widget.model.singleNumberController,
            onChanged: (value) => _applyAllFilters(),
            decoration: InputDecoration(
              hintText: '락커 번호 검색',
              hintStyle: TextStyle(
                fontSize: 12,
                color: Color(0xFF94A3B8),
              ),
              prefixIcon: Icon(Icons.tag, size: 18, color: Color(0xFF64748B)),
              suffixIcon: widget.model.singleNumberController?.text.isNotEmpty == true
                  ? IconButton(
                      icon: Icon(Icons.clear, size: 16),
                      onPressed: () {
                        setState(() {
                          widget.model.singleNumberController?.clear();
                          _applyAllFilters();
                        });
                      },
                    )
                  : null,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
              filled: true,
              fillColor: Colors.white,
            ),
            style: TextStyle(fontSize: 12, color: Colors.black),
            keyboardType: TextInputType.number,
          ),
        ),
        SizedBox(width: 24),
        // 범위필터 레이블
        Padding(
          padding: EdgeInsets.only(top: 3),
          child: Text(
            '범위필터',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
        ),
        SizedBox(width: 12),
        // 범위 입력
        Container(
          width: 60,
          height: 32,
          child: TextField(
            controller: widget.model.rangeStartController,
            onChanged: (value) {
              widget.model.rangeStart = value;
              _applyRangeFilter();
            },
            decoration: _getInputDecoration('1'),
            style: TextStyle(fontSize: 12, color: Colors.black),
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text('~', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
        ),
        Container(
          width: 60,
          height: 32,
          child: TextField(
            controller: widget.model.rangeEndController,
            onChanged: (value) {
              widget.model.rangeEnd = value;
              _applyRangeFilter();
            },
            decoration: _getInputDecoration('100'),
            style: TextStyle(fontSize: 12, color: Colors.black),
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
          ),
        ),
        SizedBox(width: 16),
        // 홀짝 필터
        Container(
          height: 32,
          decoration: BoxDecoration(
            color: Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildUnifiedToggleButton('홀수', 'odd'),
              Container(width: 1, height: 20, color: Color(0xFFE2E8F0)),
              _buildUnifiedToggleButton('짝수', 'even'),
            ],
          ),
        ),
        SizedBox(width: 8),
        // 초기화 버튼 (독립)
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _resetAllFilters,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              height: 32,
              padding: EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Color(0xFFE2E8F0)),
              ),
              child: Center(
                child: Text(
                  '초기화',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // 속성필터 UI
  Widget _buildPropertyFilterRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 속성필터 제목
        Padding(
          padding: EdgeInsets.only(top: 3),
          child: Text(
            '속성필터',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
        ),
        SizedBox(width: 12),
        // 속성 태그들
        Expanded(
          child: _buildPropertyTags(),
        ),
      ],
    );
  }

  // 이용상태 필터와 회원명 검색 UI
  Widget _buildUsageStatusAndMemberSearchRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 이용상태 필터
        Padding(
          padding: EdgeInsets.only(top: 3),
          child: Text(
            '이용상태',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
        ),
        SizedBox(width: 12),
        // 이용상태 버튼들
        Row(
          children: [
            _buildUsageStatusButton('락커료 미납', 'unpaid'),
            SizedBox(width: 6),
            _buildUsageStatusButton('사용중', 'used'),
            SizedBox(width: 6),
            _buildUsageStatusButton('비어있음', 'empty'),
          ],
        ),
        SizedBox(width: 24),
        // 회원명 검색
        Expanded(
          child: Container(
            height: 32,
            child: TextField(
              controller: widget.model.memberSearchInSettingsController,
              onChanged: (value) => _applyAllFilters(),
              decoration: InputDecoration(
                hintText: '회원 ID, 이름, 전화번호로 검색',
                hintStyle: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF94A3B8),
                ),
                prefixIcon: Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                suffixIcon: widget.model.memberSearchInSettingsController?.text.isNotEmpty == true
                    ? IconButton(
                        icon: Icon(Icons.clear, size: 16),
                        onPressed: () {
                          setState(() {
                            widget.model.memberSearchInSettingsController?.clear();
                            _applyAllFilters();
                          });
                        },
                      )
                    : null,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                filled: true,
                fillColor: Colors.white,
              ),
              style: TextStyle(fontSize: 12, color: Colors.black),
            ),
          ),
        ),
      ],
    );
  }

  // 공통 input decoration
  InputDecoration _getInputDecoration(String hintText) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(
        fontSize: 12,
        color: Color(0xFF94A3B8),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
      filled: true,
      fillColor: Colors.white,
    );
  }

  // 이용상태 버튼 위젯
  Widget _buildUsageStatusButton(String label, String value) {
    final isSelected = widget.model.selectedUsageStatus == value;
    return InkWell(
      onTap: () {
        setState(() {
          if (widget.model.selectedUsageStatus == value) {
            widget.model.selectedUsageStatus = null;
          } else {
            widget.model.selectedUsageStatus = value;
          }
          _applyAllFilters();
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Color(0xFF3B82F6) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Color(0xFF3B82F6) : Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Color(0xFF64748B),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // 아이콘이 있는 속성 태그
  Widget _buildPropertyTagWithIcon(String label, String category, IconData icon) {
    Set<String> selectedSet;
    switch (category) {
      case 'zone':
        selectedSet = widget.model.selectedZones;
        break;
      case 'type':
        selectedSet = widget.model.selectedTypes;
        break;
      case 'price':
        selectedSet = widget.model.selectedPrices;
        break;
      default:
        selectedSet = <String>{};
    }
    
    final isSelected = selectedSet.contains(label);
    return InkWell(
      onTap: () {
        setState(() {
          if (isSelected) {
            selectedSet.remove(label);
          } else {
            selectedSet.add(label);
          }
          _applyAllFilters();
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Color(0xFF3B82F6) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Color(0xFF3B82F6) : Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.white : Color(0xFF64748B),
            ),
            SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Color(0xFF64748B),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 홀짝 토글 버튼
  Widget _buildUnifiedToggleButton(String label, String value) {
    final isSelected = widget.model.lockerFilter == value;
    
    return InkWell(
      onTap: () {
        setState(() {
          widget.model.lockerFilter = value;
        });
        _applyRangeFilter();
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Color(0xFF3B82F6) : Color(0xFF6B7280),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  // 고유한 구역, 종류, 가격 추출
  Widget _buildPropertyTags() {
    final allItems = <Map<String, dynamic>>[];
    
    // 모델에서 미리 계산된 속성들 사용
    widget.model.uniqueZones.forEach((zone) => 
      allItems.add({'type': 'zone', 'value': zone, 'icon': Icons.location_on}));
    widget.model.uniqueTypes.forEach((type) => 
      allItems.add({'type': 'type', 'value': type, 'icon': Icons.category}));
    widget.model.uniquePrices.forEach((price) => 
      allItems.add({'type': 'price', 'value': price, 'icon': Icons.attach_money}));
    
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: allItems.map((item) => 
        _buildPropertyTagWithIcon(item['value'], item['type'], item['icon'])
      ).toList(),
    );
  }

  // 범위 필터 적용 (홀짝 필터와 AND 조건으로 결합)
  void _applyRangeFilter() {
    List<Map<String, dynamic>> filteredList = List.from(widget.lockerData);
    
    // 범위 필터 적용
    if (widget.model.rangeStart != null && widget.model.rangeStart!.isNotEmpty &&
        widget.model.rangeEnd != null && widget.model.rangeEnd!.isNotEmpty) {
      final startNum = int.tryParse(widget.model.rangeStart!);
      final endNum = int.tryParse(widget.model.rangeEnd!);
      
      if (startNum != null && endNum != null && startNum <= endNum) {
        filteredList = filteredList.where((locker) {
          final lockerNum = int.tryParse(locker['locker_name'].toString());
          return lockerNum != null && lockerNum >= startNum && lockerNum <= endNum;
        }).toList();
      }
    }
    
    // 홀짝 필터 적용 (AND 조건)
    if (widget.model.lockerFilter != null && widget.model.lockerFilter != 'all') {
      filteredList = filteredList.where((locker) {
        final lockerNum = int.tryParse(locker['locker_name'].toString());
        if (lockerNum == null) return false;
        
        if (widget.model.lockerFilter == 'odd') {
          return lockerNum % 2 == 1;
        } else if (widget.model.lockerFilter == 'even') {
          return lockerNum % 2 == 0;
        }
        return true;
      }).toList();
    }
    
    // 모든 필터 적용
    _applyAllFilters();
  }

  // 속성 필터 적용 (이용상태, 회원 검색 포함)
  void _applyAllFilters() async {
    List<Map<String, dynamic>> filteredList = List.from(widget.lockerData);

    // 개별 검색이 우선
    if (widget.model.singleNumberController?.text.isNotEmpty == true) {
      final searchNum = int.tryParse(widget.model.singleNumberController!.text);
      if (searchNum != null) {
        filteredList = filteredList.where((locker) {
          final lockerNum = int.tryParse(locker['locker_name'] ?? '0') ?? 0;
          return lockerNum == searchNum;
        }).toList();
      }
    } else {
      // 범위 검색 (개별 검색이 없을 때만)
      if (widget.model.rangeStart != null && widget.model.rangeStart!.isNotEmpty &&
          widget.model.rangeEnd != null && widget.model.rangeEnd!.isNotEmpty) {
        final startNum = int.tryParse(widget.model.rangeStart!) ?? 0;
        final endNum = int.tryParse(widget.model.rangeEnd!) ?? 0;
        
        if (startNum <= endNum) {
          filteredList = filteredList.where((locker) {
            final lockerNum = int.tryParse(locker['locker_name'] ?? '0') ?? 0;
            return lockerNum >= startNum && lockerNum <= endNum;
          }).toList();
        }
      }
    }
    
    // 홀짝 필터 적용 (AND 조건)
    if (widget.model.lockerFilter != null && widget.model.lockerFilter != 'all') {
      if (widget.model.lockerFilter == 'even') {
        filteredList = filteredList.where((locker) {
          final num = int.tryParse(locker['locker_name'] ?? '0') ?? 0;
          return num % 2 == 0 && num > 0;
        }).toList();
      } else if (widget.model.lockerFilter == 'odd') {
        filteredList = filteredList.where((locker) {
          final num = int.tryParse(locker['locker_name'] ?? '0') ?? 0;
          return num % 2 == 1;
        }).toList();
      }
    }
    
    // 속성 필터 적용 (AND 조건)
    if (widget.model.selectedZones.isNotEmpty) {
      filteredList = filteredList.where((locker) {
        final zone = locker['locker_zone']?.toString() ?? '미지정';
        return widget.model.selectedZones.contains(zone);
      }).toList();
    }
    
    if (widget.model.selectedTypes.isNotEmpty) {
      filteredList = filteredList.where((locker) {
        final type = locker['locker_type']?.toString() ?? '일반';
        return widget.model.selectedTypes.contains(type);
      }).toList();
    }
    
    if (widget.model.selectedPrices.isNotEmpty) {
      filteredList = filteredList.where((locker) {
        final price = locker['locker_price'] ?? 0;
        final priceStr = price == 0 ? '0원' : '${price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}원';
        return widget.model.selectedPrices.contains(priceStr);
      }).toList();
    }
    
    // 이용상태 필터 적용
    if (widget.model.selectedUsageStatus != null) {
      if (widget.model.selectedUsageStatus == 'unpaid') {
        // 락커료 미납인 락커만
        filteredList = filteredList.where((locker) {
          final paymentStatus = locker['payment_status'] ?? '';
          return paymentStatus.startsWith('미납');
        }).toList();
      } else if (widget.model.selectedUsageStatus == 'used') {
        // 사용중인 락커만
        filteredList = filteredList.where((locker) {
          return locker['member_id'] != null;
        }).toList();
      } else if (widget.model.selectedUsageStatus == 'empty') {
        // 비어있는 락커만
        filteredList = filteredList.where((locker) {
          return locker['member_id'] == null;
        }).toList();
      }
    }
    
    // 회원 검색 필터 적용
    if (widget.model.memberSearchInSettingsController?.text.isNotEmpty == true) {
      final searchText = widget.model.memberSearchInSettingsController!.text;
      print('=== 회원 검색 시작 ===');
      print('검색어: $searchText');
      print('캐시된 회원 정보: ${_assignedMembersCache.length}명');
      
      // member_id로 직접 검색 (숫자만이고 3자리 이하일 때만)
      if (int.tryParse(searchText) != null && searchText.length <= 3 && !searchText.startsWith('0')) {
        final memberId = int.parse(searchText);
        print('member_id로 검색: $memberId');
        filteredList = filteredList.where((locker) {
          return locker['member_id'] == memberId;
        }).toList();
        print('member_id 검색 결과: ${filteredList.length}개');
      } else {
        // 캐시된 회원 정보에서 검색
        print('캐시에서 이름/전화번호 검색...');
        final cleanedSearch = searchText.replaceAll('-', '').toLowerCase();
        List<Map<String, dynamic>> matchingMembers = [];
        
        for (final member in _assignedMembersCache) {
          // 이름 검색
          final memberName = (member['member_name'] ?? '').toString().toLowerCase();
          final memberPhone = (member['member_phone'] ?? '').toString();
          print('검사 중: ${member['member_id']} - $memberName - $memberPhone');
          
          if (memberName.contains(searchText.toLowerCase())) {
            print('  -> 이름 매칭!');
            matchingMembers.add(member);
            continue;
          }
          
          // 전화번호 검색 (하이픈 제거 후 비교)
          final memberPhoneClean = memberPhone.replaceAll('-', '');
          if (memberPhoneClean.contains(cleanedSearch) || 
              memberPhone.contains(searchText)) {
            print('  -> 전화번호 매칭!');
            matchingMembers.add(member);
          }
        }
        
        print('매칭된 회원: ${matchingMembers.length}명');
        final foundMemberIds = matchingMembers.map((m) => m['member_id'] as int).toSet();
        
        filteredList = filteredList.where((locker) {
          return locker['member_id'] != null && foundMemberIds.contains(locker['member_id']);
        }).toList();
        print('최종 필터링된 락커: ${filteredList.length}개');
      }
    }
    
    // 필터링 결과 적용
    widget.onFilterChanged(filteredList);
  }

  // 모든 필터 초기화
  void _resetAllFilters() {
    setState(() {
      widget.model.lockerFilter = null;
      widget.model.rangeStart = null;
      widget.model.rangeEnd = null;
      widget.model.rangeStartController?.clear();
      widget.model.rangeEndController?.clear();
      widget.model.singleNumberController?.clear();
      widget.model.selectedUsageStatus = null;
      widget.model.memberSearchInSettingsController?.clear();
      widget.model.selectedZones.clear();
      widget.model.selectedTypes.clear();
      widget.model.selectedPrices.clear();
    });
    
    // 초기화 후 모든 데이터 표시
    widget.onFilterChanged(widget.lockerData);
    widget.onResetFilters?.call();
  }
}