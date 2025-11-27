import 'package:flutter/material.dart';
import 'locker_api_service.dart';
import 'crm6_locker_model.dart';

class LockerSettingPopup extends StatefulWidget {
  final Crm6LockerModel model;
  final Function(VoidCallback) setState;
  final Function() loadLockerData;

  const LockerSettingPopup({
    Key? key,
    required this.model,
    required this.setState,
    required this.loadLockerData,
  }) : super(key: key);

  @override
  State<LockerSettingPopup> createState() => _LockerSettingPopupState();
}

class _LockerSettingPopupState extends State<LockerSettingPopup> {
  
  // 락커 설정 팝업 표시
  void _showLockerSettingsPopup() {
    widget.setState(() {
      widget.model.showLockerSettingsPopup = true;
      widget.model.selectedLockerIds.clear();
      widget.model.lockerFilter = null;
      widget.model.rangeStart = null;
      widget.model.rangeEnd = null;
      widget.model.filteredSettingsLockers = widget.model.lockerData;
    });
  }

  // 락커 필터 적용
  void _applyLockerFilter(String? filterType, {String? start, String? end}) {
    widget.setState(() {
      widget.model.lockerFilter = filterType;
      
      if (filterType == 'all') {
        widget.model.filteredSettingsLockers = widget.model.lockerData;
      } else if (filterType == 'even') {
        widget.model.filteredSettingsLockers = widget.model.lockerData.where((locker) {
          final num = int.tryParse(locker['locker_name'] ?? '0') ?? 0;
          return num % 2 == 0 && num > 0;
        }).toList();
      } else if (filterType == 'odd') {
        widget.model.filteredSettingsLockers = widget.model.lockerData.where((locker) {
          final num = int.tryParse(locker['locker_name'] ?? '0') ?? 0;
          return num % 2 == 1;
        }).toList();
      } else if (filterType == 'range' && start != null && end != null) {
        final startNum = int.tryParse(start) ?? 0;
        final endNum = int.tryParse(end) ?? 0;
        if (startNum <= endNum) {
          widget.model.filteredSettingsLockers = widget.model.lockerData.where((locker) {
            final num = int.tryParse(locker['locker_name'] ?? '0') ?? 0;
            return num >= startNum && num <= endNum;
          }).toList();
        }
      }
    });
  }

  // 범위 선택
  void _selectRange(String start, String end) {
    if (start.isNotEmpty && end.isNotEmpty) {
      final startNum = int.tryParse(start) ?? 0;
      final endNum = int.tryParse(end) ?? 0;
      
      if (startNum <= endNum) {
        widget.setState(() {
          widget.model.lockerFilter = 'range';
          widget.model.rangeStart = start;
          widget.model.rangeEnd = end;
          
          widget.model.filteredSettingsLockers = widget.model.lockerData.where((locker) {
            final num = int.tryParse(locker['locker_name'] ?? '0') ?? 0;
            final inRange = num >= startNum && num <= endNum;
            return inRange;
          }).toList();
        });
      }
    }
  }

  // 필터 초기화
  void _clearFilters() {
    widget.setState(() {
      widget.model.lockerFilter = null;
      widget.model.rangeStart = null;
      widget.model.rangeEnd = null;
      widget.model.rangeStartController?.clear();
      widget.model.rangeEndController?.clear();
      widget.model.selectedZones.clear();
      widget.model.selectedTypes.clear();
      widget.model.selectedPrices.clear();
      widget.model.filteredSettingsLockers = widget.model.lockerData;
    });
  }

  // 구역 일괄 변경
  Future<void> _bulkUpdateZone(String newZone) async {
    try {
      // 선택된 락커들을 개별적으로 업데이트
      for (final lockerId in widget.model.selectedLockerIds) {
        await LockerApiService.updateLocker(
          lockerId: lockerId,
          data: {'locker_zone': newZone},
        );
      }
      
      // 로컬 데이터 즉시 업데이트
      widget.setState(() {
        for (var locker in widget.model.filteredSettingsLockers) {
          if (widget.model.selectedLockerIds.contains(locker['locker_id'])) {
            locker['locker_zone'] = newZone;
          }
        }
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('구역이 성공적으로 변경되었습니다.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('구역 변경 중 오류가 발생했습니다: $e')),
      );
    }
  }

  // 종류 일괄 변경
  Future<void> _bulkUpdateType(String newType) async {
    try {
      // 선택된 락커들을 개별적으로 업데이트
      for (final lockerId in widget.model.selectedLockerIds) {
        await LockerApiService.updateLocker(
          lockerId: lockerId,
          data: {'locker_type': newType},
        );
      }
      
      // 로컬 데이터 즉시 업데이트
      widget.setState(() {
        for (var locker in widget.model.filteredSettingsLockers) {
          if (widget.model.selectedLockerIds.contains(locker['locker_id'])) {
            locker['locker_type'] = newType;
          }
        }
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('종류가 성공적으로 변경되었습니다.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('종류 변경 중 오류가 발생했습니다: $e')),
      );
    }
  }

  // 가격 일괄 변경
  Future<void> _bulkUpdatePrice(int price) async {
    try {
      // 선택된 락커들을 개별적으로 업데이트
      for (final lockerId in widget.model.selectedLockerIds) {
        await LockerApiService.updateLocker(
          lockerId: lockerId,
          data: {'locker_price': price},
        );
      }
      
      // 로컬 데이터 즉시 업데이트
      widget.setState(() {
        for (var locker in widget.model.filteredSettingsLockers) {
          if (widget.model.selectedLockerIds.contains(locker['locker_id'])) {
            locker['locker_price'] = price;
          }
        }
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('가격이 성공적으로 변경되었습니다.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('가격 변경 중 오류가 발생했습니다: $e')),
      );
    }
  }

  // 속성 필터 적용
  void _applyPropertyFilters() {
    widget.setState(() {
      List<Map<String, dynamic>> filteredList = List.from(widget.model.lockerData);

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
          return widget.model.selectedPrices.contains(price.toString());
        }).toList();
      }
      
      widget.model.filteredSettingsLockers = filteredList;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 락커 설정 팝업 UI는 여기에 구현
    // 기존의 락커 설정 팝업 UI 코드를 여기로 이동해야 합니다.
    return Container();
  }
}