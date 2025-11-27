import 'package:flutter/material.dart';
import '../../../services/api_service.dart';
import '../../../services/upper_button_input_design.dart';
import '../../../constants/font_sizes.dart';

class CategoryManagementWidget extends StatefulWidget {
  const CategoryManagementWidget({super.key});

  @override
  State<CategoryManagementWidget> createState() => _CategoryManagementWidgetState();
}

class _CategoryManagementWidgetState extends State<CategoryManagementWidget> {
  // 회원 유형 관리
  List<Map<String, dynamic>> memberTypes = [];
  bool isLoading = false;
  final TextEditingController _newTypeController = TextEditingController();

  // 회원권 유형 관리
  List<Map<String, dynamic>> membershipTypes = [];
  bool isLoadingMembershipTypes = false;
  final TextEditingController _newMembershipTypeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadMemberTypes();
    _loadMembershipTypes();
  }

  @override
  void dispose() {
    _newTypeController.dispose();
    _newMembershipTypeController.dispose();
    super.dispose();
  }

  // 회원유형 목록 로드
  Future<void> _loadMemberTypes() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    try {
      final data = await ApiService.getMemberTypeOptions();
      if (!mounted) return;

      setState(() {
        memberTypes = data;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });
      _showErrorSnackBar('회원유형 조회 실패: ${e.toString()}');
    }
  }

  // 유효한 회원유형 개수
  int get _validMemberTypeCount {
    return memberTypes.where((type) => type['setting_status'] == '유효').length;
  }

  // 회원유형 추가
  Future<void> _addMemberType() async {
    final newType = _newTypeController.text.trim();
    if (newType.isEmpty) {
      _showErrorSnackBar('회원유형을 입력해주세요');
      return;
    }

    // 중복 검사 (유효/만료 모두 포함)
    final existingTypes = memberTypes.map((item) => item['option_value'].toString()).toList();
    if (existingTypes.contains(newType)) {
      _showErrorSnackBar('이미 존재하는 회원유형입니다');
      return;
    }

    try {
      await ApiService.addMemberTypeOption(newType);
      if (!mounted) return;

      _newTypeController.clear();
      await _loadMemberTypes();
      if (!mounted) return;

      _showSuccessSnackBar('회원유형이 추가되었습니다');
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('회원유형 추가 실패: ${e.toString()}');
    }
  }

  // 회원유형 만료 처리
  Future<void> _expireMemberType(String type) async {
    // 마지막 유효한 회원유형인지 확인
    if (_validMemberTypeCount <= 1) {
      _showErrorSnackBar('최소 1개 이상의 유효한 회원유형이 필요합니다');
      return;
    }

    // 확인 다이얼로그 표시
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            '회원유형 만료',
            style: AppTextStyles.titleH3.copyWith(
              color: Color(0xFF1E293B),
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            '\'$type\' 회원유형을 만료 처리하시겠습니까?\n\n만료된 회원유형은 비활성화되며, 필요시 다시 되살릴 수 있습니다.',
            style: AppTextStyles.bodyText.copyWith(
              color: Color(0xFF475569),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                '취소',
                style: AppTextStyles.bodyText.copyWith(
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFEF4444),
                foregroundColor: Colors.white,
              ),
              child: Text(
                '만료',
                style: AppTextStyles.bodyText.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      if (!mounted) return;

      try {
        await ApiService.deleteMemberTypeOption(type);
        if (!mounted) return;

        await _loadMemberTypes();
        if (!mounted) return;

        _showSuccessSnackBar('회원유형이 만료 처리되었습니다');
      } catch (e) {
        if (!mounted) return;
        _showErrorSnackBar('회원유형 만료 처리 실패: ${e.toString()}');
      }
    }
  }

  // 회원유형 순서 업데이트
  Future<void> _updateMemberTypeSequence() async {
    try {
      // 현재 리스트 순서대로 option_sequence 업데이트
      final sequenceUpdates = <Map<String, String>>[];
      for (int i = 0; i < memberTypes.length; i++) {
        final type = memberTypes[i]['option_value'].toString();
        sequenceUpdates.add({
          'option_value': type,
          'sequence': '${i + 1}',
        });
      }

      await ApiService.updateMemberTypeSequence(sequenceUpdates);
      if (!mounted) return;

      // 목록 다시 로드하여 DB와 동기화
      await _loadMemberTypes();
      if (!mounted) return;

      _showSuccessSnackBar('순서가 저장되었습니다');
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('순서 저장 실패: ${e.toString()}');
      // 실패 시 목록 다시 로드하여 원래 순서로 복구
      await _loadMemberTypes();
    }
  }

  // 회원유형 되살리기
  Future<void> _restoreMemberType(String type) async {
    // 확인 다이얼로그 표시
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            '회원유형 되살리기',
            style: AppTextStyles.titleH3.copyWith(
              color: Color(0xFF1E293B),
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            '\'$type\' 회원유형을 다시 활성화하시겠습니까?',
            style: AppTextStyles.bodyText.copyWith(
              color: Color(0xFF475569),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                '취소',
                style: AppTextStyles.bodyText.copyWith(
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF10B981),
                foregroundColor: Colors.white,
              ),
              child: Text(
                '되살리기',
                style: AppTextStyles.bodyText.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      if (!mounted) return;

      try {
        await ApiService.restoreMemberTypeOption(type);
        if (!mounted) return;

        await _loadMemberTypes();
        if (!mounted) return;

        _showSuccessSnackBar('회원유형이 활성화되었습니다');
      } catch (e) {
        if (!mounted) return;
        _showErrorSnackBar('회원유형 활성화 실패: ${e.toString()}');
      }
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Color(0xFF10B981),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Color(0xFFEF4444),
        duration: Duration(seconds: 3),
      ),
    );
  }

  // 회원권 유형 목록 로드
  Future<void> _loadMembershipTypes() async {
    if (!mounted) return;

    setState(() {
      isLoadingMembershipTypes = true;
    });

    try {
      final data = await ApiService.getMembershipTypeOptions();
      if (!mounted) return;

      setState(() {
        membershipTypes = data;
        isLoadingMembershipTypes = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoadingMembershipTypes = false;
      });
      _showErrorSnackBar('회원권 유형 조회 실패: ${e.toString()}');
    }
  }

  // 유효한 회원권 유형 개수
  int get _validMembershipTypeCount {
    return membershipTypes.where((type) => type['setting_status'] == '유효').length;
  }

  // 회원권 유형 추가
  Future<void> _addMembershipType() async {
    final newType = _newMembershipTypeController.text.trim();
    if (newType.isEmpty) {
      _showErrorSnackBar('회원권 유형을 입력해주세요');
      return;
    }

    // 중복 검사 (유효/만료 모두 포함)
    final existingTypes = membershipTypes.map((item) => item['option_value'].toString()).toList();
    if (existingTypes.contains(newType)) {
      _showErrorSnackBar('이미 존재하는 회원권 유형입니다');
      return;
    }

    try {
      await ApiService.addMembershipTypeOption(newType);
      if (!mounted) return;

      _newMembershipTypeController.clear();
      await _loadMembershipTypes();
      if (!mounted) return;

      _showSuccessSnackBar('회원권 유형이 추가되었습니다');
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('회원권 유형 추가 실패: ${e.toString()}');
    }
  }

  // 회원권 유형 만료 처리
  Future<void> _expireMembershipType(String type) async {
    // 마지막 유효한 회원권 유형인지 확인
    if (_validMembershipTypeCount <= 1) {
      _showErrorSnackBar('최소 1개 이상의 유효한 회원권 유형이 필요합니다');
      return;
    }

    // 확인 다이얼로그 표시
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            '회원권 유형 만료',
            style: AppTextStyles.titleH3.copyWith(
              color: Color(0xFF1E293B),
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            '\'$type\' 회원권 유형을 만료 처리하시겠습니까?\n\n만료된 회원권 유형은 비활성화되며, 필요시 다시 되살릴 수 있습니다.',
            style: AppTextStyles.bodyText.copyWith(
              color: Color(0xFF475569),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                '취소',
                style: AppTextStyles.bodyText.copyWith(
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFEF4444),
                foregroundColor: Colors.white,
              ),
              child: Text(
                '만료',
                style: AppTextStyles.bodyText.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      if (!mounted) return;

      try {
        await ApiService.deleteMembershipTypeOption(type);
        if (!mounted) return;

        await _loadMembershipTypes();
        if (!mounted) return;

        _showSuccessSnackBar('회원권 유형이 만료 처리되었습니다');
      } catch (e) {
        if (!mounted) return;
        _showErrorSnackBar('회원권 유형 만료 처리 실패: ${e.toString()}');
      }
    }
  }

  // 회원권 유형 순서 업데이트
  Future<void> _updateMembershipTypeSequence() async {
    try {
      // 현재 리스트 순서대로 option_sequence 업데이트
      final sequenceUpdates = <Map<String, String>>[];
      for (int i = 0; i < membershipTypes.length; i++) {
        final type = membershipTypes[i]['option_value'].toString();
        sequenceUpdates.add({
          'option_value': type,
          'sequence': '${i + 1}',
        });
      }

      await ApiService.updateMembershipTypeSequence(sequenceUpdates);
      if (!mounted) return;

      // 목록 다시 로드하여 DB와 동기화
      await _loadMembershipTypes();
      if (!mounted) return;

      _showSuccessSnackBar('순서가 저장되었습니다');
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('순서 저장 실패: ${e.toString()}');
      // 실패 시 목록 다시 로드하여 원래 순서로 복구
      await _loadMembershipTypes();
    }
  }

  // 회원권 유형 되살리기
  Future<void> _restoreMembershipType(String type) async {
    // 확인 다이얼로그 표시
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            '회원권 유형 되살리기',
            style: AppTextStyles.titleH3.copyWith(
              color: Color(0xFF1E293B),
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            '\'$type\' 회원권 유형을 다시 활성화하시겠습니까?',
            style: AppTextStyles.bodyText.copyWith(
              color: Color(0xFF475569),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                '취소',
                style: AppTextStyles.bodyText.copyWith(
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF10B981),
                foregroundColor: Colors.white,
              ),
              child: Text(
                '되살리기',
                style: AppTextStyles.bodyText.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      if (!mounted) return;

      try {
        await ApiService.restoreMembershipTypeOption(type);
        if (!mounted) return;

        await _loadMembershipTypes();
        if (!mounted) return;

        _showSuccessSnackBar('회원권 유형이 활성화되었습니다');
      } catch (e) {
        if (!mounted) return;
        _showErrorSnackBar('회원권 유형 활성화 실패: ${e.toString()}');
      }
    }
  }

  // 회원 유형 관리 위젯 빌드
  Widget _buildMemberTypeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.max,
      children: [
        // 헤더
        Row(
          children: [
            Icon(
              Icons.people_outline,
              size: 28.0,
              color: Color(0xFF6366F1),
            ),
            SizedBox(width: 12.0),
            Text(
              '회원 유형 관리',
              style: TextStyle(
                fontFamily: 'Pretendard',
                color: Color(0xFF1E293B),
                fontSize: 20.0,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        SizedBox(height: 24.0),

        // 새 회원유형 추가 섹션
        Container(
          padding: EdgeInsets.all(20.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(
              color: Color(0xFFE2E8F0),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 4.0,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newTypeController,
                  decoration: InputDecoration(
                    hintText: '새 회원유형 입력',
                    hintStyle: TextStyle(
                      fontFamily: 'Pretendard',
                      color: Color(0xFF94A3B8),
                      fontSize: 14.0,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: BorderSide(color: Color(0xFF6366F1), width: 2.0),
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  ),
                  style: AppTextStyles.bodyText.copyWith(
                    color: Color(0xFF1F2937),
                  ),
                  onSubmitted: (_) => _addMemberType(),
                ),
              ),
              SizedBox(width: 12.0),
              ButtonDesignUpper.buildIconButton(
                text: '추가',
                icon: Icons.add,
                onPressed: _addMemberType,
                color: 'blue',
                size: 'medium',
              ),
            ],
          ),
        ),
        SizedBox(height: 24.0),

        // 회원유형 목록
        Flexible(
          child: Container(
            padding: EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(
                color: Color(0xFFE2E8F0),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 4.0,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '등록된 회원유형',
                  style: AppTextStyles.titleH4.copyWith(
                    color: Color(0xFF1E293B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 16.0),
                Divider(color: Color(0xFFE2E8F0), height: 1.0),
                SizedBox(height: 16.0),
                Expanded(
                  child: isLoading
                      ? Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF6366F1),
                          ),
                        )
                      : memberTypes.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.inbox_outlined,
                                    size: 64.0,
                                    color: Color(0xFFCBD5E1),
                                  ),
                                  SizedBox(height: 16.0),
                                  Text(
                                    '등록된 회원유형이 없습니다',
                                    style: AppTextStyles.bodyText.copyWith(
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ReorderableListView.builder(
                              itemCount: memberTypes.length,
                              onReorder: (oldIndex, newIndex) {
                                if (newIndex > oldIndex) {
                                  newIndex -= 1;
                                }
                                setState(() {
                                  final item = memberTypes.removeAt(oldIndex);
                                  memberTypes.insert(newIndex, item);
                                });
                                _updateMemberTypeSequence();
                              },
                              itemBuilder: (context, index) {
                                final typeData = memberTypes[index];
                                final type = typeData['option_value'].toString();
                                final status = typeData['setting_status']?.toString() ?? '';
                                final isValid = status == '유효';

                                return ReorderableDragStartListener(
                                  key: ValueKey(type),
                                  index: index,
                                  child: Container(
                                    margin: EdgeInsets.only(bottom: 8.0),
                                    padding: EdgeInsets.all(16.0),
                                    decoration: BoxDecoration(
                                      color: isValid ? Color(0xFFF8FAFC) : Color(0xFFFEF2F2),
                                      borderRadius: BorderRadius.circular(8.0),
                                      border: Border.all(
                                        color: isValid ? Color(0xFFE2E8F0) : Color(0xFFFECACA),
                                        width: 1.0,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        // 드래그 핸들 아이콘
                                        Icon(
                                          Icons.drag_handle,
                                          color: Color(0xFF94A3B8),
                                          size: 20.0,
                                        ),
                                        SizedBox(width: 12.0),
                                        // 순번
                                        Container(
                                          width: 32.0,
                                          height: 32.0,
                                          decoration: BoxDecoration(
                                            color: (isValid ? Color(0xFF6366F1) : Color(0xFF94A3B8)).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(6.0),
                                          ),
                                          child: Center(
                                            child: Text(
                                              '${index + 1}',
                                              style: AppTextStyles.bodyText.copyWith(
                                                color: isValid ? Color(0xFF6366F1) : Color(0xFF64748B),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 16.0),
                                        // 회원유형 이름
                                        Expanded(
                                          child: Row(
                                            children: [
                                              Text(
                                                type,
                                                style: AppTextStyles.bodyText.copyWith(
                                                  color: isValid ? Color(0xFF1F2937) : Color(0xFF64748B),
                                                  fontWeight: FontWeight.w500,
                                                  decoration: isValid ? TextDecoration.none : TextDecoration.lineThrough,
                                                ),
                                              ),
                                              SizedBox(width: 8.0),
                                              // 상태 배지
                                              Container(
                                                padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                                decoration: BoxDecoration(
                                                  color: isValid ? Color(0xFFDCFCE7) : Color(0xFFFEE2E2),
                                                  borderRadius: BorderRadius.circular(4.0),
                                                ),
                                                child: Text(
                                                  status,
                                                  style: TextStyle(
                                                    fontFamily: 'Pretendard',
                                                    fontSize: 12.0,
                                                    fontWeight: FontWeight.w500,
                                                    color: isValid ? Color(0xFF15803D) : Color(0xFFDC2626),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        SizedBox(width: 12.0),
                                        // 액션 버튼
                                        if (isValid) ...[
                                          IconButton(
                                            onPressed: () => _expireMemberType(type),
                                            icon: Icon(Icons.block_outlined, color: Color(0xFFEF4444)),
                                            tooltip: '만료',
                                          ),
                                        ] else ...[
                                          IconButton(
                                            onPressed: () => _restoreMemberType(type),
                                            icon: Icon(Icons.restore_outlined, color: Color(0xFF10B981)),
                                            tooltip: '되살리기',
                                          ),
                                        ],
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
        ),
      ],
    );
  }

  // 회원권 유형 관리 위젯 빌드
  Widget _buildMembershipTypeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.max,
      children: [
        // 헤더
        Row(
          children: [
            Icon(
              Icons.card_membership,
              size: 28.0,
              color: Color(0xFF8B5CF6),
            ),
            SizedBox(width: 12.0),
            Text(
              '회원권 유형 관리',
              style: TextStyle(
                fontFamily: 'Pretendard',
                color: Color(0xFF1E293B),
                fontSize: 20.0,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        SizedBox(height: 24.0),

        // 새 회원권 유형 추가 섹션
        Container(
          padding: EdgeInsets.all(20.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(
              color: Color(0xFFE2E8F0),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 4.0,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newMembershipTypeController,
                  decoration: InputDecoration(
                    hintText: '새 회원권 유형 입력',
                    hintStyle: TextStyle(
                      fontFamily: 'Pretendard',
                      color: Color(0xFF94A3B8),
                      fontSize: 14.0,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: BorderSide(color: Color(0xFF8B5CF6), width: 2.0),
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  ),
                  style: AppTextStyles.bodyText.copyWith(
                    color: Color(0xFF1F2937),
                  ),
                  onSubmitted: (_) => _addMembershipType(),
                ),
              ),
              SizedBox(width: 12.0),
              ButtonDesignUpper.buildIconButton(
                text: '추가',
                icon: Icons.add,
                onPressed: _addMembershipType,
                color: 'green',
                size: 'medium',
              ),
            ],
          ),
        ),
        SizedBox(height: 24.0),

        // 회원권 유형 목록
        Flexible(
          child: Container(
            padding: EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(
                color: Color(0xFFE2E8F0),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 4.0,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '등록된 회원권 유형',
                  style: AppTextStyles.titleH4.copyWith(
                    color: Color(0xFF1E293B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 16.0),
                Divider(color: Color(0xFFE2E8F0), height: 1.0),
                SizedBox(height: 16.0),
                Expanded(
                  child: isLoadingMembershipTypes
                      ? Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF8B5CF6),
                          ),
                        )
                      : membershipTypes.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.inbox_outlined,
                                    size: 64.0,
                                    color: Color(0xFFCBD5E1),
                                  ),
                                  SizedBox(height: 16.0),
                                  Text(
                                    '등록된 회원권 유형이 없습니다',
                                    style: AppTextStyles.bodyText.copyWith(
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ReorderableListView.builder(
                              itemCount: membershipTypes.length,
                              onReorder: (oldIndex, newIndex) {
                                if (newIndex > oldIndex) {
                                  newIndex -= 1;
                                }
                                setState(() {
                                  final item = membershipTypes.removeAt(oldIndex);
                                  membershipTypes.insert(newIndex, item);
                                });
                                _updateMembershipTypeSequence();
                              },
                              itemBuilder: (context, index) {
                                final typeData = membershipTypes[index];
                                final type = typeData['option_value'].toString();
                                final status = typeData['setting_status']?.toString() ?? '';
                                final isValid = status == '유효';

                                return ReorderableDragStartListener(
                                  key: ValueKey(type),
                                  index: index,
                                  child: Container(
                                    margin: EdgeInsets.only(bottom: 8.0),
                                    padding: EdgeInsets.all(16.0),
                                    decoration: BoxDecoration(
                                      color: isValid ? Color(0xFFF8FAFC) : Color(0xFFFEF2F2),
                                      borderRadius: BorderRadius.circular(8.0),
                                      border: Border.all(
                                        color: isValid ? Color(0xFFE2E8F0) : Color(0xFFFECACA),
                                        width: 1.0,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        // 드래그 핸들 아이콘
                                        Icon(
                                          Icons.drag_handle,
                                          color: Color(0xFF94A3B8),
                                          size: 20.0,
                                        ),
                                        SizedBox(width: 12.0),
                                        // 순번
                                        Container(
                                          width: 32.0,
                                          height: 32.0,
                                          decoration: BoxDecoration(
                                            color: (isValid ? Color(0xFF8B5CF6) : Color(0xFF94A3B8)).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(6.0),
                                          ),
                                          child: Center(
                                            child: Text(
                                              '${index + 1}',
                                              style: AppTextStyles.bodyText.copyWith(
                                                color: isValid ? Color(0xFF8B5CF6) : Color(0xFF64748B),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 16.0),
                                        // 회원권 유형 이름
                                        Expanded(
                                          child: Row(
                                            children: [
                                              Text(
                                                type,
                                                style: AppTextStyles.bodyText.copyWith(
                                                  color: isValid ? Color(0xFF1F2937) : Color(0xFF64748B),
                                                  fontWeight: FontWeight.w500,
                                                  decoration: isValid ? TextDecoration.none : TextDecoration.lineThrough,
                                                ),
                                              ),
                                              SizedBox(width: 8.0),
                                              // 상태 배지
                                              Container(
                                                padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                                decoration: BoxDecoration(
                                                  color: isValid ? Color(0xFFDCFCE7) : Color(0xFFFEE2E2),
                                                  borderRadius: BorderRadius.circular(4.0),
                                                ),
                                                child: Text(
                                                  status,
                                                  style: TextStyle(
                                                    fontFamily: 'Pretendard',
                                                    fontSize: 12.0,
                                                    fontWeight: FontWeight.w500,
                                                    color: isValid ? Color(0xFF15803D) : Color(0xFFDC2626),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        SizedBox(width: 12.0),
                                        // 액션 버튼
                                        if (isValid) ...[
                                          IconButton(
                                            onPressed: () => _expireMembershipType(type),
                                            icon: Icon(Icons.block_outlined, color: Color(0xFFEF4444)),
                                            tooltip: '만료',
                                          ),
                                        ] else ...[
                                          IconButton(
                                            onPressed: () => _restoreMembershipType(type),
                                            icon: Icon(Icons.restore_outlined, color: Color(0xFF10B981)),
                                            tooltip: '되살리기',
                                          ),
                                        ],
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
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 왼쪽: 회원 유형 관리
          Expanded(
            child: _buildMemberTypeSection(),
          ),
          SizedBox(width: 24.0),
          // 오른쪽: 회원권 유형 관리
          Expanded(
            child: _buildMembershipTypeSection(),
          ),
        ],
      ),
    );
  }
}

