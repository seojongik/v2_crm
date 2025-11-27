import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/api_service.dart';
import '../../../services/upper_button_input_design.dart';
import '../../../constants/font_sizes.dart';
import '../../../widgets/scroll_service.dart';

class Tab1TsSettingWidget extends StatefulWidget {
  @override
  _Tab1TsSettingWidgetState createState() => _Tab1TsSettingWidgetState();
}

class _Tab1TsSettingWidgetState extends State<Tab1TsSettingWidget> {
  List<Map<String, dynamic>> tsInfoList = [];
  List<String> tsTypeOptions = []; // 타석유형 옵션 리스트 추가
  List<String> memberTypeOptions = []; // 회원유형 옵션 리스트 추가
  bool isLoading = false;
  bool isEditing = false;
  String? editingTsId; // 현재 수정 중인 타석 ID
  Map<String, TextEditingController> controllers = {};
  Map<int, String> selectedTsTypes = {}; // int 타입으로 변경
  Map<int, List<String>> selectedMemberTypeProhibited = {}; // int 타입으로 변경
  Map<int, bool> prohibitedEditing = {}; // 회원유형 제한 편집 상태
  Map<int, String?> selectedProhibitedType = {}; // 선택된 제한 유형
  Map<String, TextEditingController> textControllers = {}; // 텍스트 컨트롤러 맵 추가

  @override
  void initState() {
    super.initState();
    _loadTsInfo();
    _loadTsTypeOptions(); // 타석유형 옵션 로딩 추가
    _loadMemberTypeOptions(); // 회원유형 옵션 로딩 추가
  }

  @override
  void dispose() {
    controllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }

  Future<void> _loadTsInfo() async {
    setState(() {
      isLoading = true;
    });

    try {
      final data = await ApiService.getTsInfoData(
        orderBy: [
          {'field': 'ts_id', 'direction': 'ASC'}
        ],
      );
      setState(() {
        tsInfoList = data;
        _initializeControllers();
      });
    } catch (e) {
      _showErrorSnackBar('타석 정보 조회 실패: ${e.toString()}');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadTsTypeOptions() async {
    try {
      final data = await ApiService.getTsTypeOptions();
      setState(() {
        tsTypeOptions = data.map((item) => item['option_value'].toString()).toList();
      });
    } catch (e) {
      print('타석유형 옵션 로딩 실패: $e');
      // 기본값 설정
      setState(() {
        tsTypeOptions = ['연습타석', '스크린'];
      });
    }
  }

  Future<void> _loadMemberTypeOptions() async {
    print('회원유형 옵션 로딩 시작...');
    try {
      final data = await ApiService.getMemberTypeOptions();
      print('회원유형 옵션 로딩 성공: $data');
      setState(() {
        memberTypeOptions = data.map((item) => item['option_value'].toString()).toList();
      });
      print('회원유형 옵션 설정 완료: $memberTypeOptions');
    } catch (e) {
      print('회원유형 옵션 로딩 실패: $e');
      // 기본값 설정
      setState(() {
        memberTypeOptions = ['일반', '주니어', '웰빙클럽', '아이코젠', '리프레쉬', '김캐디'];
      });
      print('기본 회원유형 옵션 설정: $memberTypeOptions');
    }
  }

  void _initializeControllers() {
    controllers.clear();
    selectedTsTypes.clear(); // 선택된 타석유형 초기화
    selectedMemberTypeProhibited.clear(); // 선택된 회원유형 제한 초기화
    for (var tsInfo in tsInfoList) {
      final tsId = tsInfo['ts_id'].toString();
      final tsIdInt = tsInfo['ts_id'] as int; // int 타입 추가
      controllers['${tsId}_type'] = TextEditingController(text: tsInfo['ts_type']?.toString() ?? '');
      controllers['${tsId}_description'] = TextEditingController(text: tsInfo['ts_description']?.toString() ?? '');
      controllers['${tsId}_base_price'] = TextEditingController(text: tsInfo['base_price']?.toString() ?? '');
      controllers['${tsId}_discount_price'] = TextEditingController(text: tsInfo['discount_price']?.toString() ?? '');
      controllers['${tsId}_extracharge_price'] = TextEditingController(text: tsInfo['extracharge_price']?.toString() ?? '');
      controllers['${tsId}_min_base'] = TextEditingController(text: tsInfo['ts_min_base']?.toString() ?? '');
      controllers['${tsId}_min_minimum'] = TextEditingController(text: tsInfo['ts_min_minimum']?.toString() ?? '');
      controllers['${tsId}_min_maximum'] = TextEditingController(text: tsInfo['ts_min_maximum']?.toString() ?? '');
      controllers['${tsId}_buffer'] = TextEditingController(text: tsInfo['ts_buffer']?.toString() ?? '');
      controllers['${tsId}_max_person'] = TextEditingController(text: tsInfo['max_person']?.toString() ?? '');
      
      // 타석유형 선택값 초기화
      selectedTsTypes[tsIdInt] = tsInfo['ts_type']?.toString() ?? '';
      
      // 회원유형 제한 선택값 초기화 (콤마로 구분된 문자열을 리스트로 변환)
      final memberTypeProhibited = tsInfo['member_type_prohibited']?.toString() ?? '';
      selectedMemberTypeProhibited[tsIdInt] = memberTypeProhibited.isEmpty 
        ? [] 
        : memberTypeProhibited.split(',').where((type) => type.trim().isNotEmpty).toList();
    }
  }

  int _getNextTsId() {
    if (tsInfoList.isEmpty) return 1;
    final maxId = tsInfoList.map((ts) => int.tryParse(ts['ts_id'].toString()) ?? 0).reduce((a, b) => a > b ? a : b);
    return maxId + 1;
  }

  void _addNewTsRow() {
    final newTsId = _getNextTsId();
    final newTsInfo = {
      'ts_id': newTsId,
      'ts_type': '',
      'ts_description': '',
      'ts_status': '예약가능', // 기본값: 예약가능
      'base_price': 0,
      'discount_price': 0,
      'extracharge_price': 0,
      'ts_min_base': null,
      'ts_min_minimum': null,
      'ts_min_maximum': null,
      'ts_buffer': null,
      'max_person': null,
      'member_type_prohibited': '',
      '_isNew': true,
    };

    setState(() {
      tsInfoList.add(newTsInfo);
      isEditing = true;
      
      // 새 행의 컨트롤러 추가
      controllers['${newTsId}_type'] = TextEditingController();
      controllers['${newTsId}_description'] = TextEditingController();
      controllers['${newTsId}_base_price'] = TextEditingController();
      controllers['${newTsId}_discount_price'] = TextEditingController();
      controllers['${newTsId}_extracharge_price'] = TextEditingController();
      controllers['${newTsId}_min_base'] = TextEditingController();
      controllers['${newTsId}_min_minimum'] = TextEditingController();
      controllers['${newTsId}_min_maximum'] = TextEditingController();
      controllers['${newTsId}_buffer'] = TextEditingController();
      controllers['${newTsId}_max_person'] = TextEditingController();
      
      // 타석유형 선택값 초기화
      selectedTsTypes[newTsId] = '';
      // 회원유형 제한 선택값 초기화
      selectedMemberTypeProhibited[newTsId] = [];
    });
  }

  void _showCopySettingsDialog(int targetTsId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.6,
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 헤더
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Color(0xFF6366F1),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.copy, color: Colors.white, size: 24),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '설정 복사하기',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                
                // 타석 리스트
                Flexible(
                  child: Container(
                    padding: EdgeInsets.all(20),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: tsInfoList.where((ts) => ts['ts_id'] != targetTsId).length,
                      itemBuilder: (context, index) {
                        final availableTs = tsInfoList.where((ts) => ts['ts_id'] != targetTsId).toList();
                        final tsInfo = availableTs[index];
                        
                        return Container(
                          margin: EdgeInsets.only(bottom: 8),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                _copySettings(tsInfo, targetTsId);
                                Navigator.of(context).pop();
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Color(0xFFE5E7EB)),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Color(0xFF6366F1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${tsInfo['ts_id']}번',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            tsInfo['ts_type'] ?? '',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          if (tsInfo['ts_description'] != null && tsInfo['ts_description'].toString().isNotEmpty)
                                            Text(
                                              tsInfo['ts_description'],
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Color(0xFF6B7280),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFF9CA3AF)),
                                  ],
                                ),
                              ),
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
        );
      },
    );
  }

  void _copySettings(Map<String, dynamic> sourceTsInfo, int targetTsId) {
    final targetTsIdStr = targetTsId.toString();
    
    controllers['${targetTsIdStr}_description']?.text = sourceTsInfo['ts_description']?.toString() ?? '';
    controllers['${targetTsIdStr}_base_price']?.text = sourceTsInfo['base_price']?.toString() ?? '';
    controllers['${targetTsIdStr}_discount_price']?.text = sourceTsInfo['discount_price']?.toString() ?? '';
    controllers['${targetTsIdStr}_extracharge_price']?.text = sourceTsInfo['extracharge_price']?.toString() ?? '';
    controllers['${targetTsIdStr}_min_base']?.text = sourceTsInfo['ts_min_base']?.toString() ?? '';
    controllers['${targetTsIdStr}_min_minimum']?.text = sourceTsInfo['ts_min_minimum']?.toString() ?? '';
    controllers['${targetTsIdStr}_min_maximum']?.text = sourceTsInfo['ts_min_maximum']?.toString() ?? '';
    controllers['${targetTsIdStr}_buffer']?.text = sourceTsInfo['ts_buffer']?.toString() ?? ''; // 버퍼시간 복사 추가
    controllers['${targetTsIdStr}_max_person']?.text = sourceTsInfo['max_person']?.toString() ?? ''; // 최대인원 복사 추가
    
    // 타석유형도 복사 - int 타입으로 수정
    selectedTsTypes[targetTsId] = sourceTsInfo['ts_type']?.toString() ?? '';
    
    // 회원유형제한도 복사 추가
    final memberTypeProhibited = sourceTsInfo['member_type_prohibited']?.toString() ?? '';
    selectedMemberTypeProhibited[targetTsId] = memberTypeProhibited.isEmpty 
      ? [] 
      : memberTypeProhibited.split(',').where((type) => type.trim().isNotEmpty).toList();

    _showSuccessSnackBar('${sourceTsInfo['ts_id']}번 타석 설정이 복사되었습니다');
  }

  Future<void> _toggleTsStatus(Map<String, dynamic> tsInfo) async {
    final tsId = tsInfo['ts_id'].toString();
    final currentStatus = tsInfo['ts_status'] ?? '예약가능';
    final newStatus = currentStatus == '예약가능' ? '예약중지' : '예약가능';

    // 예약중지로 변경할 때 기존 예약 확인 및 표시
    if (newStatus == '예약중지') {
      // 기존 예약 리스트 조회
      List<Map<String, dynamic>> existingReservations = [];
      try {
        final reservationData = await ApiService.getPricedTsData(
          where: [
            {'field': 'ts_id', 'operator': '=', 'value': tsId},
            {'field': 'branch_id', 'operator': '=', 'value': 'famd'},
            {'field': 'ts_date', 'operator': '>=', 'value': DateTime.now().toIso8601String().split('T')[0]},
            {'field': 'ts_status', 'operator': '=', 'value': '결제완료'},
          ],
          orderBy: [
            {'field': 'ts_date', 'direction': 'ASC'},
            {'field': 'ts_start', 'direction': 'ASC'},
          ],
        );
        existingReservations = reservationData;
      } catch (e) {
        print('기존 예약 조회 실패: $e');
      }

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.7,
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 헤더
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Color(0xFFF59E0B),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber, color: Colors.white, size: 24),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '예약 중지 확인',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          icon: Icon(Icons.close, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  
                  // 내용
                  Flexible(
                    child: Container(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '해당 타석의 기존예약은 유지되며, 신규예약이 중지됩니다.',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF374151),
                            ),
                          ),
                          
                          if (existingReservations.isNotEmpty) ...[
                            SizedBox(height: 20),
                            Text(
                              '기존 예약 현황 (${existingReservations.length}건)',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF6366F1),
                              ),
                            ),
                            SizedBox(height: 12),
                            Container(
                              height: 300,
                              decoration: BoxDecoration(
                                border: Border.all(color: Color(0xFFE5E7EB)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ListView.builder(
                                itemCount: existingReservations.length,
                                itemBuilder: (context, index) {
                                  final reservation = existingReservations[index];
                                  return Container(
                                    padding: EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: Color(0xFFE5E7EB),
                                          width: index < existingReservations.length - 1 ? 1 : 0,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        // 날짜
                                        Container(
                                          width: 80,
                                          child: Text(
                                            reservation['ts_date'] ?? '',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF6366F1),
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 12),
                                        // 시간
                                        Container(
                                          width: 100,
                                          child: Text(
                                            '${reservation['ts_start']?.substring(0, 5) ?? ''} - ${reservation['ts_end']?.substring(0, 5) ?? ''}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF374151),
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 12),
                                        // 회원정보
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                reservation['member_name'] ?? '',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF374151),
                                                ),
                                              ),
                                              Text(
                                                '회원번호: ${reservation['member_id'] ?? ''}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Color(0xFF6B7280),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                            SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.of(context).pop(false);
                                  _showNotificationDialog();
                                },
                                icon: Icon(Icons.notifications, size: 16),
                                label: Text('안내 발송'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFF10B981),
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: 8),
                          ] else ...[
                            SizedBox(height: 20),
                            Container(
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Color(0xFFF0F9FF),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Color(0xFFBFDBFE)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info, color: Color(0xFF3B82F6), size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    '현재 기존 예약이 없습니다.',
                                    style: TextStyle(
                                      color: Color(0xFF3B82F6),
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 20),
                          ],
                          
                          Text(
                            '계속하시겠습니까?',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // 버튼
                  Container(
                    padding: EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: Text('취소'),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: Text('확인', style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFFF59E0B),
                              padding: EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
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
          );
        },
      );

      if (confirmed != true) return;
    }

    try {
      await ApiService.updateTsInfoData(
        {'ts_status': newStatus},
        [{'field': 'ts_id', 'operator': '=', 'value': tsId}],
      );

      setState(() {
        tsInfo['ts_status'] = newStatus;
      });

      _showSuccessSnackBar(newStatus == '예약가능' ? '타석예약이 활성화 되었습니다.' : '예약이 중지되었습니다');
    } catch (e) {
      _showErrorSnackBar('상태 변경 실패: ${e.toString()}');
    }
  }

  void _showNotificationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.info, color: Color(0xFF6366F1), size: 24),
              SizedBox(width: 8),
              Text('안내'),
            ],
          ),
          content: Text('예약타석 이용불가 안내 기능은 준비중입니다.'),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('확인', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF6366F1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveTsInfo(Map<String, dynamic> tsInfo) async {
    final tsId = tsInfo['ts_id'].toString();
    final tsIdInt = tsInfo['ts_id'] as int; // int 타입으로 추가
    final isNew = tsInfo['_isNew'] == true;

    try {
      final data = {
        'ts_id': tsId,
        'ts_type': selectedTsTypes[tsIdInt] ?? '', // int 타입 사용
        'ts_description': controllers['${tsId}_description']?.text ?? '',
        'ts_status': tsInfo['ts_status'] ?? '예약가능',
        'base_price': int.tryParse(controllers['${tsId}_base_price']?.text ?? '0') ?? 0,
        'discount_price': int.tryParse(controllers['${tsId}_discount_price']?.text ?? '0') ?? 0,
        'extracharge_price': int.tryParse(controllers['${tsId}_extracharge_price']?.text ?? '0') ?? 0,
        'ts_min_base': controllers['${tsId}_min_base']?.text.isEmpty == true ? null : int.tryParse(controllers['${tsId}_min_base']?.text ?? ''),
        'ts_min_minimum': controllers['${tsId}_min_minimum']?.text.isEmpty == true ? null : int.tryParse(controllers['${tsId}_min_minimum']?.text ?? ''),
        'ts_min_maximum': controllers['${tsId}_min_maximum']?.text.isEmpty == true ? null : int.tryParse(controllers['${tsId}_min_maximum']?.text ?? ''),
        'ts_buffer': controllers['${tsId}_buffer']?.text.isEmpty == true ? null : controllers['${tsId}_buffer']?.text,
        'max_person': controllers['${tsId}_max_person']?.text.isEmpty == true ? null : int.tryParse(controllers['${tsId}_max_person']?.text ?? ''),
        'member_type_prohibited': selectedMemberTypeProhibited[tsIdInt]?.join(',') ?? '', // int 타입 사용
      };

      if (data['ts_type'].toString().isEmpty) {
        _showErrorSnackBar('타석 종류는 필수 입력 항목입니다');
        return;
      }

      if (isNew) {
        await ApiService.addTsInfoData(data);
        _showSuccessSnackBar('새로운 타석이 추가되었습니다');
      } else {
        await ApiService.updateTsInfoData(
          data,
          [{'field': 'ts_id', 'operator': '=', 'value': tsId}],
        );
        _showSuccessSnackBar('타석 정보가 수정되었습니다');
      }

      // 편집 상태 초기화
      setState(() {
        isEditing = false;
        editingTsId = null;
      });
      
      // 데이터 다시 로드
      _loadTsInfo();
    } catch (e) {
      _showErrorSnackBar('저장 실패: ${e.toString()}');
    }
  }

  Future<void> _deleteTsInfo(String tsId) async {
    try {
      await ApiService.deleteTsInfoData([
        {'field': 'ts_id', 'operator': '=', 'value': tsId}
      ]);
      _showSuccessSnackBar('타석이 삭제되었습니다');
      _loadTsInfo();
    } catch (e) {
      _showErrorSnackBar('삭제 실패: ${e.toString()}');
    }
  }

  void _startEdit(String tsId) {
    setState(() {
      isEditing = true;
      editingTsId = tsId;
    });
  }

  void _cancelEdit() {
    setState(() {
      isEditing = false;
      editingTsId = null;
      // 새로 추가된 행 제거
      tsInfoList.removeWhere((ts) => ts['_isNew'] == true);
      _initializeControllers();
    });
  }

  Widget _buildTsTypeDropdown(int tsId) {
    return Container(
      height: 36, // 내부 컨테이너 높이
      padding: EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedTsTypes[tsId],
          hint: Text(
            '선택',
            style: AppTextStyles.cardBody.copyWith(
              color: Color(0xFF9CA3AF),
            ),
          ),
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down, size: 20, color: Color(0xFF6B7280)),
          dropdownColor: Colors.white, // 드롭다운 메뉴 배경색을 흰색으로 설정
          items: tsTypeOptions.map((option) {
            return DropdownMenuItem<String>(
              value: option,
              child: Container(
                color: Colors.white, // 각 항목의 배경색을 흰색으로 설정
                child: Text(
                  option,
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF374151),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                selectedTsTypes[tsId] = value;
              });
            }
          },
        ),
      ),
    );
  }

  Widget _buildEditableCell({
    required String controllerId,
    TextInputType keyboardType = TextInputType.text,
    String? suffix,
    Color? textColor,
  }) {
    return Container(
      height: 36, // 내부 컨테이너 높이
      child: TextFormField(
        controller: controllers[controllerId],
        keyboardType: keyboardType,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13,
          color: textColor ?? Color(0xFF374151),
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Color(0xFFE5E7EB)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Color(0xFFE5E7EB)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Color(0xFF6366F1), width: 2),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          suffixText: suffix,
          suffixStyle: TextStyle(
            fontSize: 11,
            color: Color(0xFF6B7280),
            fontWeight: FontWeight.w500,
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildTimeCell({
    required String controllerId,
    required bool isEditing,
    required String displayValue,
    bool isBold = false,
  }) {
    if (isEditing) {
      return Container(
        height: 36, // 내부 컨테이너 높이
        child: TextFormField(
          controller: controllers[controllerId],
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF374151),
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
          ),
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Color(0xFF6366F1), width: 2),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            suffixText: '분',
            suffixStyle: TextStyle(
              fontSize: 11,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
            ),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
      );
    } else {
      return Text(
        displayValue,
        style: TextStyle(
          fontSize: 13,
          color: Color(0xFF374151),
          fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
        ),
        textAlign: TextAlign.center,
      );
    }
  }

  Widget _buildMemberTypeProhibitedSelector(int tsId) {
    final selectedTypes = selectedMemberTypeProhibited[tsId] ?? [];
    final displayText = selectedTypes.isEmpty ? '제한없음' : selectedTypes.join(', ');
    
    return Text(
      displayText,
      style: TextStyle(
        fontSize: 13,
        color: selectedTypes.isEmpty ? Color(0xFF10B981) : Color(0xFF374151),
        fontWeight: FontWeight.w500,
      ),
      textAlign: TextAlign.center,
    );
  }

  void _showMemberTypeSelectionDialog(String tsId) {
    final tsIdInt = int.parse(tsId); // 문자열을 정수로 변환
    final selectedTypes = selectedMemberTypeProhibited[tsIdInt] ?? [];
    List<String> tempSelected = List.from(selectedTypes);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                width: 400,
                constraints: BoxConstraints(maxHeight: 500),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 헤더
                    Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Color(0xFF6366F1),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.block, color: Colors.white, size: 20),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '${tsId}번 타석 - 회원유형 제한 설정',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: Icon(Icons.close, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    
                    // 내용
                    Flexible(
                      child: Container(
                        padding: EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '예약을 제한할 회원유형을 선택하세요:',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF374151),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 16),
                            
                            // 전체 선택/해제 버튼
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () {
                                      setDialogState(() {
                                        tempSelected.clear();
                                      });
                                    },
                                    child: Text('전체 해제'),
                                    style: OutlinedButton.styleFrom(
                                      padding: EdgeInsets.symmetric(vertical: 12),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () {
                                      setDialogState(() {
                                        tempSelected = List.from(memberTypeOptions);
                                      });
                                    },
                                    child: Text('전체 선택'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Color(0xFF6366F1),
                                      foregroundColor: Colors.white,
                                      padding: EdgeInsets.symmetric(vertical: 12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 16),
                            
                            // 체크박스 리스트
                            Flexible(
                              child: memberTypeOptions.isEmpty
                                ? Center(
                                    child: Text(
                                      '회원유형 옵션을 불러오는 중...',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF6B7280),
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: memberTypeOptions.length,
                                    itemBuilder: (context, index) {
                                      final memberType = memberTypeOptions[index];
                                      final isSelected = tempSelected.contains(memberType);
                                      
                                      return Container(
                                        margin: EdgeInsets.only(bottom: 8),
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: () {
                                              setDialogState(() {
                                                if (isSelected) {
                                                  tempSelected.remove(memberType);
                                                } else {
                                                  tempSelected.add(memberType);
                                                }
                                              });
                                            },
                                            borderRadius: BorderRadius.circular(8),
                                            child: Container(
                                              padding: EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: isSelected 
                                                    ? Color(0xFFE0F2FE)
                                                    : Colors.white,
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: isSelected 
                                                      ? Color(0xFF0EA5E9)
                                                      : Color(0xFFE5E7EB),
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    width: 20,
                                                    height: 20,
                                                    decoration: BoxDecoration(
                                                      color: isSelected 
                                                          ? Color(0xFF0EA5E9)
                                                          : Colors.transparent,
                                                      border: Border.all(
                                                        color: isSelected 
                                                            ? Color(0xFF0EA5E9)
                                                            : Color(0xFFD1D5DB),
                                                        width: 2,
                                                      ),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: isSelected 
                                                        ? Icon(
                                                            Icons.check,
                                                            size: 14,
                                                            color: Colors.white,
                                                          )
                                                        : null,
                                                  ),
                                                  SizedBox(width: 12),
                                                  Text(
                                                    memberType,
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w500,
                                                      color: Color(0xFF374151),
                                                    ),
                                                  ),
                                                ],
                                              ),
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
                    
                    // 하단 버튼
                    Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white, // 하단 버튼 영역 배경을 흰색으로 설정
                        border: Border(
                          top: BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: Text('취소'),
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  selectedMemberTypeProhibited[tsIdInt] = List.from(tempSelected);
                                });
                                Navigator.of(context).pop();
                              },
                              child: Text('확인'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFF6366F1),
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: 12),
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
          },
        );
      },
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error, color: Colors.white),
            SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  String _formatPrice(dynamic price) {
    if (price == null) return '0원';
    final priceInt = price is int ? price : int.tryParse(price.toString()) ?? 0;
    return '${priceInt.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}원';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 헤더
        Container(
          padding: EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16.0),
              topRight: Radius.circular(16.0),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 왼쪽: 타석 추가, 타석유형 관리 버튼 (편집 중이 아닐 때)
              if (!isEditing)
                Row(
                  children: [
                    ButtonDesignUpper.buildIconButton(
                      text: '타석 추가',
                      icon: Icons.sports_golf,
                      onPressed: _addNewTsRow,
                      color: 'green',
                      size: 'large',
                    ),
                    SizedBox(width: 12.0),
                    ButtonDesignUpper.buildIconButton(
                      text: '타석유형 관리',
                      icon: Icons.category,
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => TsTypeManagementDialog(
                            onChanged: () {
                              setState(() {});
                            },
                          ),
                        );
                      },
                      color: 'gray',
                      size: 'large',
                    ),
                  ],
                )
              else
                // 편집 중일 때: 취소 버튼
                ButtonDesignUpper.buildIconButton(
                  text: '취소',
                  icon: Icons.close,
                  onPressed: _cancelEdit,
                  color: 'gray',
                  size: 'large',
                ),
            ],
          ),
        ),
        
        SizedBox(height: 16),
        
        // 컨텐츠 - 테이블 영역 확장
        Expanded(
          child: isLoading
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                      ),
                      SizedBox(height: 16),
                      Text(
                        '타석 정보를 불러오는 중...',
                        style: TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : tsInfoList.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Color(0xFF6366F1).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(
                              Icons.sports_golf,
                              size: 64,
                              color: Color(0xFF6366F1),
                            ),
                          ),
                          SizedBox(height: 24),
                          Text(
                            '등록된 타석이 없습니다',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '새로운 타석을 추가해보세요',
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        // 최소 컬럼 너비 계산 (텍스트가 3줄로 넘어가지 않을 정도)
                        final columnWidths = [
                          50.0,  // 번호
                          80.0,  // 종류
                          90.0,  // 예약상태
                          70.0,  // 할인
                          70.0,  // 기본
                          70.0,  // 추가
                          90.0,  // 최소예약(분)
                          90.0,  // 기본예약(분)
                          90.0,  // 최대예약(분)
                          80.0,  // 버퍼시간
                          70.0,  // 최대인원
                          120.0, // 회원유형제한
                          100.0, // 관리
                        ];

                        final totalMinWidth = ScrollServiceUtils.calculateTableWidth(columnWidths, padding: 40.0);
                        final needsScroll = ScrollServiceUtils.needsScroll(constraints.maxWidth, totalMinWidth);

                        final tableWidget = Container(
                          width: double.infinity,
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
                          child: Column(
                            children: [
                              // 고정 헤더
                              Container(
                                decoration: BoxDecoration(
                                  color: Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(12),
                                    topRight: Radius.circular(12),
                                  ),
                                ),
                                child: Table(
                                  columnWidths: needsScroll ? {
                                    0: FixedColumnWidth(columnWidths[0]), // 번호
                                    1: FixedColumnWidth(columnWidths[1]), // 종류
                                    2: FixedColumnWidth(columnWidths[2]), // 예약상태
                                    3: FixedColumnWidth(columnWidths[3]), // 할인가격
                                    4: FixedColumnWidth(columnWidths[4]), // 기본가격
                                    5: FixedColumnWidth(columnWidths[5]), // 추가가격
                                    6: FixedColumnWidth(columnWidths[6]), // 최소예약
                                    7: FixedColumnWidth(columnWidths[7]), // 기본예약
                                    8: FixedColumnWidth(columnWidths[8]), // 최대예약
                                    9: FixedColumnWidth(columnWidths[9]), // 버퍼시간
                                    10: FixedColumnWidth(columnWidths[10]), // 최대인원
                                    11: FixedColumnWidth(columnWidths[11]), // 회원유형제한
                                    12: FixedColumnWidth(columnWidths[12]), // 관리
                                  } : {
                                    0: FlexColumnWidth(0.5), // 번호
                                    1: FlexColumnWidth(0.8), // 종류
                                    2: FlexColumnWidth(1.0), // 예약상태
                                    3: FlexColumnWidth(0.8), // 할인가격
                                    4: FlexColumnWidth(0.8), // 기본가격
                                    5: FlexColumnWidth(0.8), // 추가가격
                                    6: FlexColumnWidth(0.7), // 최소예약
                                    7: FlexColumnWidth(0.7), // 기본예약
                                    8: FlexColumnWidth(0.7), // 최대예약
                                    9: FlexColumnWidth(0.7), // 버퍼시간
                                    10: FlexColumnWidth(0.7), // 최대인원
                                    11: FlexColumnWidth(1.2), // 회원유형제한
                                    12: FlexColumnWidth(1.0), // 관리
                                  },
                              children: [
                                TableRow(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(16),
                                      child: Text(
                                        '번호',
                                        style: AppTextStyles.formLabel.copyWith(
                                          fontFamily: 'Pretendard',
                                          color: Color(0xFF475569),
                                          fontWeight: FontWeight.w600,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    Container(
                                      padding: EdgeInsets.all(16),
                                      child: Text(
                                        '종류',
                                        style: AppTextStyles.formLabel.copyWith(
                                          fontFamily: 'Pretendard',
                                          color: Color(0xFF475569),
                                          fontWeight: FontWeight.w600,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    Container(
                                      padding: EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          right: BorderSide(
                                            color: Color(0xFFD1D5DB),
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        '예약상태',
                                        style: AppTextStyles.formLabel.copyWith(
                                          fontFamily: 'Pretendard',
                                          color: Color(0xFF475569),
                                          fontWeight: FontWeight.w600,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    Container(
                                      padding: EdgeInsets.all(16),
                                      child: Text(
                                        '할인',
                                        style: AppTextStyles.formLabel.copyWith(
                                          fontFamily: 'Pretendard',
                                          color: Color(0xFF475569),
                                          fontWeight: FontWeight.w600,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    Container(
                                      padding: EdgeInsets.all(16),
                                      child: Text(
                                        '기본',
                                        style: AppTextStyles.formLabel.copyWith(
                                          fontFamily: 'Pretendard',
                                          color: Color(0xFF475569),
                                          fontWeight: FontWeight.w600,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    Container(
                                      padding: EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          right: BorderSide(
                                            color: Color(0xFFD1D5DB),
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        '할증',
                                        style: AppTextStyles.formLabel.copyWith(
                                          fontFamily: 'Pretendard',
                                          color: Color(0xFF475569),
                                          fontWeight: FontWeight.w600,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    Container(
                                      padding: EdgeInsets.all(16),
                                      child: Text(
                                        '최소예약(분)',
                                        style: AppTextStyles.formLabel.copyWith(
                                          fontFamily: 'Pretendard',
                                          color: Color(0xFF475569),
                                          fontWeight: FontWeight.w600,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    Container(
                                      padding: EdgeInsets.all(16),
                                      child: Text(
                                        '기본예약(분)',
                                        style: AppTextStyles.formLabel.copyWith(
                                          fontFamily: 'Pretendard',
                                          color: Color(0xFF475569),
                                          fontWeight: FontWeight.w600,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    Container(
                                      padding: EdgeInsets.all(16),
                                      child: Text(
                                        '최대예약(분)',
                                        style: AppTextStyles.formLabel.copyWith(
                                          fontFamily: 'Pretendard',
                                          color: Color(0xFF475569),
                                          fontWeight: FontWeight.w600,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    Container(
                                      padding: EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          right: BorderSide(
                                            color: Color(0xFFD1D5DB),
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        '버퍼시간',
                                        style: AppTextStyles.formLabel.copyWith(
                                          fontFamily: 'Pretendard',
                                          color: Color(0xFF475569),
                                          fontWeight: FontWeight.w600,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    Container(
                                      padding: EdgeInsets.all(16),
                                      child: Text(
                                        '최대인원',
                                        style: AppTextStyles.formLabel.copyWith(
                                          fontFamily: 'Pretendard',
                                          color: Color(0xFF475569),
                                          fontWeight: FontWeight.w600,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    Container(
                                      padding: EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          right: BorderSide(
                                            color: Color(0xFFD1D5DB),
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        '회원유형제한',
                                        style: AppTextStyles.formLabel.copyWith(
                                          fontFamily: 'Pretendard',
                                          color: Color(0xFF475569),
                                          fontWeight: FontWeight.w600,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    Container(
                                      padding: EdgeInsets.all(16),
                                      child: Text(
                                        '관리',
                                        style: AppTextStyles.formLabel.copyWith(
                                          fontFamily: 'Pretendard',
                                          color: Color(0xFF475569),
                                          fontWeight: FontWeight.w600,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                              // 스크롤 가능한 바디
                              Expanded(
                                child: SingleChildScrollView(
                                  child: Table(
                                    columnWidths: needsScroll ? {
                                      0: FixedColumnWidth(columnWidths[0]), // 번호
                                      1: FixedColumnWidth(columnWidths[1]), // 종류
                                      2: FixedColumnWidth(columnWidths[2]), // 예약상태
                                      3: FixedColumnWidth(columnWidths[3]), // 할인가격
                                      4: FixedColumnWidth(columnWidths[4]), // 기본가격
                                      5: FixedColumnWidth(columnWidths[5]), // 추가가격
                                      6: FixedColumnWidth(columnWidths[6]), // 최소예약
                                      7: FixedColumnWidth(columnWidths[7]), // 기본예약
                                      8: FixedColumnWidth(columnWidths[8]), // 최대예약
                                      9: FixedColumnWidth(columnWidths[9]), // 버퍼시간
                                      10: FixedColumnWidth(columnWidths[10]), // 최대인원
                                      11: FixedColumnWidth(columnWidths[11]), // 회원유형제한
                                      12: FixedColumnWidth(columnWidths[12]), // 관리
                                    } : {
                                      0: FlexColumnWidth(0.5), // 번호
                                      1: FlexColumnWidth(0.8), // 종류
                                      2: FlexColumnWidth(1.0), // 예약상태
                                      3: FlexColumnWidth(0.8), // 할인가격
                                      4: FlexColumnWidth(0.8), // 기본가격
                                      5: FlexColumnWidth(0.8), // 추가가격
                                      6: FlexColumnWidth(0.7), // 최소예약
                                      7: FlexColumnWidth(0.7), // 기본예약
                                      8: FlexColumnWidth(0.7), // 최대예약
                                      9: FlexColumnWidth(0.7), // 버퍼시간
                                      10: FlexColumnWidth(0.7), // 최대인원
                                      11: FlexColumnWidth(1.2), // 회원유형제한
                                      12: FlexColumnWidth(1.0), // 관리
                                    },
                                children: tsInfoList.map((tsInfo) {
                                  final tsId = tsInfo['ts_id'].toString();
                                  final isNew = tsInfo['_isNew'] == true;
                                  final isCurrentlyEditing = editingTsId == tsId || (isNew && isEditing);
                                  final tsStatus = tsInfo['ts_status'] ?? '예약가능';
                                  
                                  return TableRow(
                                    decoration: BoxDecoration(
                                      color: isNew ? Color(0xFFF0F9FF) : 
                                             isCurrentlyEditing ? Color(0xFFFFF7ED) : null,
                                    ),
                                    children: [
                                      // 번호
                                      Container(
                                        height: 60, // 통일된 높이
                                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        decoration: BoxDecoration(
                                          border: Border(
                                            bottom: BorderSide(
                                              color: Color(0xFFE5E7EB),
                                              width: 1,
                                            ),
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${tsInfo['ts_id']}번',
                                            style: AppTextStyles.cardBody.copyWith(
                                              color: Color(0xFF374151),
                                              fontWeight: FontWeight.w600,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                      // 종류
                                      Container(
                                        height: 60, // 통일된 높이
                                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        decoration: BoxDecoration(
                                          border: Border(
                                            bottom: BorderSide(
                                              color: Color(0xFFE5E7EB),
                                              width: 1,
                                            ),
                                          ),
                                        ),
                                        child: Center(
                                          child: isCurrentlyEditing
                                              ? _buildTsTypeDropdown(tsInfo['ts_id'])
                                              : Text(
                                                  selectedTsTypes[int.parse(tsInfo['ts_id'].toString())] ?? tsInfo['ts_type'] ?? '',
                                                  style: AppTextStyles.cardBody.copyWith(
                                                    color: Color(0xFF374151),
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                        ),
                                      ),
                                      // 예약상태 (기본정보 그룹 마지막 - 오른쪽 경계선)
                                      Container(
                                        height: 60, // 통일된 높이
                                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        decoration: BoxDecoration(
                                          border: Border(
                                            bottom: BorderSide(
                                              color: Color(0xFFE5E7EB),
                                              width: 1,
                                            ),
                                            right: BorderSide(
                                              color: Color(0xFFD1D5DB),
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                        child: Center(
                                          child: InkWell(
                                            onTap: () => _toggleTsStatus(tsInfo),
                                            borderRadius: BorderRadius.circular(20),
                                            child: Container(
                                              constraints: BoxConstraints(maxWidth: 80),
                                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: tsStatus == '예약가능' ? Color(0xFF10B981) : Color(0xFFEF4444),
                                                borderRadius: BorderRadius.circular(16),
                                              ),
                                              child: Text(
                                                tsStatus,
                                                style: AppTextStyles.cardMeta.copyWith(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      // 할인가격
                                      Container(
                                        height: 60, // 통일된 높이
                                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        decoration: BoxDecoration(
                                          border: Border(
                                            bottom: BorderSide(
                                              color: Color(0xFFE5E7EB),
                                              width: 1,
                                            ),
                                          ),
                                        ),
                                        child: Center(
                                          child: isCurrentlyEditing
                                              ? _buildEditableCell(
                                                  controllerId: '${tsId}_discount_price',
                                                  keyboardType: TextInputType.number,
                                                  suffix: '원',
                                                  textColor: Color(0xFF374151),
                                                )
                                              : Text(
                                                  _formatPrice(tsInfo['discount_price']),
                                                  style: AppTextStyles.cardBody.copyWith(
                                                    fontWeight: FontWeight.w500,
                                                    color: Color(0xFF374151),
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                        ),
                                      ),
                                      // 기본가격
                                      Container(
                                        height: 60, // 통일된 높이
                                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        decoration: BoxDecoration(
                                          border: Border(
                                            bottom: BorderSide(
                                              color: Color(0xFFE5E7EB),
                                              width: 1,
                                            ),
                                          ),
                                        ),
                                        child: Center(
                                          child: isCurrentlyEditing
                                              ? _buildEditableCell(
                                                  controllerId: '${tsId}_base_price',
                                                  keyboardType: TextInputType.number,
                                                  suffix: '원',
                                                  textColor: Color(0xFF374151),
                                                )
                                              : Text(
                                                  _formatPrice(tsInfo['base_price']),
                                                  style: AppTextStyles.cardBody.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF374151),
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                        ),
                                      ),
                                      // 추가가격 (가격정보 그룹 마지막 - 오른쪽 경계선)
                                      Container(
                                        height: 60, // 통일된 높이
                                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        decoration: BoxDecoration(
                                          border: Border(
                                            bottom: BorderSide(
                                              color: Color(0xFFE5E7EB),
                                              width: 1,
                                            ),
                                            right: BorderSide(
                                              color: Color(0xFFD1D5DB),
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                        child: Center(
                                          child: isCurrentlyEditing
                                              ? _buildEditableCell(
                                                  controllerId: '${tsId}_extracharge_price',
                                                  keyboardType: TextInputType.number,
                                                  suffix: '원',
                                                  textColor: Color(0xFF374151),
                                                )
                                              : Text(
                                                  _formatPrice(tsInfo['extracharge_price']),
                                                  style: AppTextStyles.cardBody.copyWith(
                                                    fontWeight: FontWeight.w500,
                                                    color: Color(0xFF374151),
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                        ),
                                      ),
                                      // 최소예약
                                      Container(
                                        height: 60, // 통일된 높이
                                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        decoration: BoxDecoration(
                                          border: Border(
                                            bottom: BorderSide(
                                              color: Color(0xFFE5E7EB),
                                              width: 1,
                                            ),
                                          ),
                                        ),
                                        child: Center(
                                          child: _buildTimeCell(
                                            controllerId: '${tsId}_min_minimum',
                                            isEditing: isCurrentlyEditing,
                                            displayValue: tsInfo['ts_min_minimum'] != null
                                                ? '${tsInfo['ts_min_minimum']}분'
                                                : '-',
                                          ),
                                        ),
                                      ),
                                      // 기본예약
                                      Container(
                                        height: 60, // 통일된 높이
                                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        decoration: BoxDecoration(
                                          border: Border(
                                            bottom: BorderSide(
                                              color: Color(0xFFE5E7EB),
                                              width: 1,
                                            ),
                                          ),
                                        ),
                                        child: Center(
                                          child: _buildTimeCell(
                                            controllerId: '${tsId}_min_base',
                                            isEditing: isCurrentlyEditing,
                                            displayValue: tsInfo['ts_min_base'] != null
                                                ? '${tsInfo['ts_min_base']}분'
                                                : '-',
                                            isBold: true,
                                          ),
                                        ),
                                      ),
                                      // 최대예약
                                      Container(
                                        height: 60, // 통일된 높이
                                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        decoration: BoxDecoration(
                                          border: Border(
                                            bottom: BorderSide(
                                              color: Color(0xFFE5E7EB),
                                              width: 1,
                                            ),
                                          ),
                                        ),
                                        child: Center(
                                          child: _buildTimeCell(
                                            controllerId: '${tsId}_min_maximum',
                                            isEditing: isCurrentlyEditing,
                                            displayValue: tsInfo['ts_min_maximum'] != null
                                                ? '${tsInfo['ts_min_maximum']}분'
                                                : '-',
                                          ),
                                        ),
                                      ),
                                      // 버퍼시간 (시간설정 그룹 마지막 - 오른쪽 경계선)
                                      Container(
                                        height: 60, // 통일된 높이
                                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        decoration: BoxDecoration(
                                          border: Border(
                                            bottom: BorderSide(
                                              color: Color(0xFFE5E7EB),
                                              width: 1,
                                            ),
                                            right: BorderSide(
                                              color: Color(0xFFD1D5DB),
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                        child: Center(
                                          child: _buildTimeCell(
                                            controllerId: '${tsId}_buffer',
                                            isEditing: isCurrentlyEditing,
                                            displayValue: tsInfo['ts_buffer'] != null
                                                ? '${tsInfo['ts_buffer']}분'
                                                : '-',
                                          ),
                                        ),
                                      ),
                                      // 최대인원
                                      Container(
                                        height: 60, // 통일된 높이
                                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        decoration: BoxDecoration(
                                          border: Border(
                                            bottom: BorderSide(
                                              color: Color(0xFFE5E7EB),
                                              width: 1,
                                            ),
                                          ),
                                        ),
                                        child: Center(
                                          child: isCurrentlyEditing
                                              ? _buildEditableCell(
                                                  controllerId: '${tsId}_max_person',
                                                  keyboardType: TextInputType.number,
                                                  suffix: '명',
                                                  textColor: Color(0xFF374151),
                                                )
                                              : Text(
                                                  tsInfo['max_person'] != null
                                                      ? '${tsInfo['max_person']}명'
                                                      : '-',
                                                  style: AppTextStyles.cardBody.copyWith(
                                                    color: Color(0xFF374151),
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                        ),
                                      ),
                                      // 회원유형제한 (제한설정 그룹 - 오른쪽 경계선)
                                      Container(
                                        height: 60, // 통일된 높이
                                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        decoration: BoxDecoration(
                                          border: Border(
                                            bottom: BorderSide(
                                              color: Color(0xFFE5E7EB),
                                              width: 1,
                                            ),
                                            right: BorderSide(
                                              color: Color(0xFFD1D5DB),
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                        child: Center(
                                          child: isCurrentlyEditing 
                                              ? InkWell(
                                                  onTap: () => _showMemberTypeSelectionDialog(tsId),
                                                  borderRadius: BorderRadius.circular(4),
                                                  child: Container(
                                                    width: double.infinity,
                                                    padding: EdgeInsets.symmetric(vertical: 8),
                                                    child: _buildMemberTypeProhibitedSelector(tsInfo['ts_id']),
                                                  ),
                                                )
                                              : _buildMemberTypeProhibitedSelector(tsInfo['ts_id']),
                                        ),
                                      ),
                                      // 관리
                                      Container(
                                        height: 60, // 통일된 높이
                                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        decoration: BoxDecoration(
                                          border: Border(
                                            bottom: BorderSide(
                                              color: Color(0xFFE5E7EB),
                                              width: 1,
                                            ),
                                          ),
                                        ),
                                        child: Center(
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (isCurrentlyEditing) ...[
                                                Tooltip(
                                                  message: '설정 복사',
                                                  child: InkWell(
                                                    onTap: () => _showCopySettingsDialog(tsInfo['ts_id']),
                                                    borderRadius: BorderRadius.circular(4),
                                                    child: Container(
                                                      padding: EdgeInsets.all(6),
                                                      child: Icon(Icons.copy, size: 18, color: Color(0xFF10B981)),
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(width: 4),
                                                Tooltip(
                                                  message: '저장',
                                                  child: InkWell(
                                                    onTap: () => _saveTsInfo(tsInfo),
                                                    borderRadius: BorderRadius.circular(4),
                                                    child: Container(
                                                      padding: EdgeInsets.all(6),
                                                      child: Icon(Icons.save, size: 18, color: Color(0xFF6366F1)),
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(width: 4),
                                                Tooltip(
                                                  message: '취소',
                                                  child: InkWell(
                                                    onTap: _cancelEdit,
                                                    borderRadius: BorderRadius.circular(4),
                                                    child: Container(
                                                      padding: EdgeInsets.all(6),
                                                      child: Icon(Icons.close, size: 18, color: Color(0xFF6B7280)),
                                                    ),
                                                  ),
                                                ),
                                                if (!isNew) ...[
                                                  SizedBox(width: 4),
                                                  Tooltip(
                                                    message: '삭제',
                                                    child: InkWell(
                                                      onTap: () => _deleteTsInfo(tsId),
                                                      borderRadius: BorderRadius.circular(4),
                                                      child: Container(
                                                        padding: EdgeInsets.all(6),
                                                        child: Icon(Icons.delete, size: 18, color: Color(0xFFEF4444)),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ] else ...[
                                                Tooltip(
                                                  message: '수정',
                                                  child: InkWell(
                                                    onTap: () => _startEdit(tsId),
                                                    borderRadius: BorderRadius.circular(4),
                                                    child: Container(
                                                      padding: EdgeInsets.all(6),
                                                      child: Icon(Icons.edit, size: 18, color: Color(0xFF6366F1)),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );

                        // ScrollService 적용 여부에 따라 반환
                        if (needsScroll) {
                          // 디버깅 로그 출력
                          ScrollServiceUtils.debugLog('타석설정', constraints.maxWidth, totalMinWidth, needsScroll);

                          return ScrollService(
                            child: Container(
                              width: totalMinWidth,
                              child: tableWidget,
                            ),
                            contentWidth: totalMinWidth,
                            enableScrollbar: true,
                            scrollbarHeight: 8.0,
                            trackColor: Color(0xFFE5E7EB),
                            thumbColor: Color(0xFF6B7280),
                            scrollbarMargin: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                            sensitivity: 2.0,
                          );
                        } else {
                          return tableWidget;
                        }
                      },
                    ),
        ),
      ],
    );
  }
}

// 타석유형 관리 다이얼로그
class TsTypeManagementDialog extends StatefulWidget {
  final Function? onChanged;

  const TsTypeManagementDialog({Key? key, this.onChanged}) : super(key: key);

  @override
  _TsTypeManagementDialogState createState() => _TsTypeManagementDialogState();
}

class _TsTypeManagementDialogState extends State<TsTypeManagementDialog> {
  List<Map<String, dynamic>> _tsTypes = [];
  bool _isLoading = true;
  final TextEditingController _newTypeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTsTypes();
  }

  @override
  void dispose() {
    _newTypeController.dispose();
    super.dispose();
  }

  Future<void> _loadTsTypes() async {
    try {
      setState(() => _isLoading = true);
      final types = await ApiService.getTsTypeOptions();
      setState(() {
        _tsTypes = types;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      print('타석유형 로드 오류: $e'); // 디버깅용
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('타석유형 로드 실패: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _addTsType() async {
    final newType = _newTypeController.text.trim();
    if (newType.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('타석유형을 입력해주세요.')),
      );
      return;
    }

    // 중복 체크
    if (_tsTypes.any((type) => type['option_value'] == newType)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('이미 존재하는 타석유형입니다.')),
      );
      return;
    }

    try {
      await ApiService.addTsTypeOption(newType);
      _newTypeController.clear();
      await _loadTsTypes();
      widget.onChanged?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('타석유형이 추가되었습니다.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('타석유형 추가 실패: $e')),
      );
    }
  }

  Future<void> _editTsType(String oldValue) async {
    final controller = TextEditingController(text: oldValue);
    
    final newValue = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('타석유형 수정'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: '타석유형',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text('수정'),
          ),
        ],
      ),
    );

    if (newValue != null && newValue.isNotEmpty && newValue != oldValue) {
      // 중복 체크
      if (_tsTypes.any((type) => type['option_value'] == newValue)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('이미 존재하는 타석유형입니다.')),
        );
        return;
      }

      try {
        await ApiService.updateTsTypeOption(oldValue, newValue);
        await _loadTsTypes();
        widget.onChanged?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('타석유형이 수정되었습니다.')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('타석유형 수정 실패: $e')),
        );
      }
    }
  }

  Future<void> _deleteTsType(String optionValue) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('타석유형 삭제'),
        content: Text('\'$optionValue\' 타석유형을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ApiService.deleteTsTypeOption(optionValue);
        await _loadTsTypes();
        widget.onChanged?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('타석유형이 삭제되었습니다.')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('타석유형 삭제 실패: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        height: 600,
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '타석유형 관리',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close),
                ),
              ],
            ),
            SizedBox(height: 20),
            
            // 새 타석유형 추가
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newTypeController,
                    decoration: InputDecoration(
                      labelText: '새 타석유형',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onSubmitted: (_) => _addTsType(),
                  ),
                ),
                SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _addTsType,
                  child: Text('추가'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            
            // 타석유형 목록
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : _tsTypes.isEmpty
                      ? Center(
                          child: Text(
                            '등록된 타석유형이 없습니다.',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _tsTypes.length,
                          itemBuilder: (context, index) {
                            final tsType = _tsTypes[index];
                            final optionValue = tsType['option_value'] ?? '';
                            
                            return Card(
                              margin: EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                title: Text(
                                  optionValue,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      onPressed: () => _editTsType(optionValue),
                                      icon: Icon(Icons.edit, color: Colors.blue),
                                      tooltip: '수정',
                                    ),
                                    IconButton(
                                      onPressed: () => _deleteTsType(optionValue),
                                      icon: Icon(Icons.delete, color: Colors.red),
                                      tooltip: '삭제',
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
} 
