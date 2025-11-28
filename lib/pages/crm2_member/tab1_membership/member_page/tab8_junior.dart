import 'package:flutter/material.dart';
import '/services/api_service.dart';
import '/services/supabase_adapter.dart';
import '/constants/font_sizes.dart';

class Tab8JuniorWidget extends StatefulWidget {
  const Tab8JuniorWidget({
    super.key,
    required this.memberId,
  });

  final int memberId;

  @override
  State<Tab8JuniorWidget> createState() => _Tab8JuniorWidgetState();
}

class _Tab8JuniorWidgetState extends State<Tab8JuniorWidget> {
  List<Map<String, dynamic>> _relations = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadRelations();
  }

  // 관계 정보 로드
  Future<void> _loadRelations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await SupabaseAdapter.getData(
        table: 'v2_group',
        where: [
          {'field': 'member_id', 'operator': '=', 'value': widget.memberId},
        ],
      );

      setState(() {
        _relations = result;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 관계 등록 다이얼로그
  void _showAddRelationDialog() {
    showDialog(
      context: context,
      builder: (context) => _AddRelationDialog(
        memberId: widget.memberId,
        onRelationAdded: _loadRelations,
      ),
    );
  }

  // 관계 삭제
  Future<void> _deleteRelation(int relationId) async {
    try {
      await SupabaseAdapter.deleteData(
        table: 'v2_group',
        where: [
          {'field': 'id', 'operator': '=', 'value': relationId},
        ],
      );

      _loadRelations();
      _showSnackBar('관계가 삭제되었습니다.', Colors.green);
    } catch (e) {
      _showSnackBar('관계 삭제 중 오류가 발생했습니다: $e', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Color(0xFFF8FAFC),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더 섹션
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
              padding: EdgeInsets.all(12.0),
              child: Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    height: 36.0,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF06B6D4), Color(0xFF0891B2)],
                        stops: [0.0, 1.0],
                        begin: AlignmentDirectional(0.0, -1.0),
                        end: AlignmentDirectional(0, 1.0),
                      ),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8.0),
                        onTap: _showAddRelationDialog,
                        child: Container(
                          width: 110.0,
                          height: 36.0,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.max,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.group_add,
                                color: Colors.white,
                                size: 16.0,
                              ),
                              Padding(
                                padding: EdgeInsetsDirectional.fromSTEB(6.0, 0.0, 0.0, 0.0),
                                child: Text(
                                  '관계 등록',
                                  style: AppTextStyles.tagMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // 관계 목록 섹션
          Expanded(
            child: Container(
              width: double.infinity,
              color: Colors.white,
              child: _buildRelationsList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRelationsList() {
    if (_isLoading) {
      return Container(
        height: 400.0,
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              Color(0xFF3B82F6),
            ),
          ),
        ),
      );
    }
    
    if (_errorMessage != null) {
      return Container(
        height: 400.0,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64.0,
                color: Color(0xFFEF4444),
              ),
              SizedBox(height: 16.0),
              Text(
                '데이터를 불러오는 중 오류가 발생했습니다.',
                style: AppTextStyles.cardTitle.copyWith(
                  color: Color(0xFF1E293B),
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 8.0),
              Text(
                _errorMessage!,
                style: AppTextStyles.bodyTextSmall.copyWith(
                  color: Color(0xFF64748B),
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16.0),
              ElevatedButton(
                onPressed: _loadRelations,
                child: Text('다시 시도'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    if (_relations.isEmpty) {
      return Container(
        height: 400.0,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.group_outlined,
                size: 64.0,
                color: Color(0xFF94A3B8),
              ),
              SizedBox(height: 16.0),
              Text(
                '등록된 관계가 없습니다.',
                style: AppTextStyles.cardTitle.copyWith(
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 8.0),
              Text(
                '첫 번째 관계를 등록해보세요.',
                style: AppTextStyles.bodyTextSmall.copyWith(
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _loadRelations,
      child: ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: _relations.length,
        itemBuilder: (context, index) {
          final relation = _relations[index];
          return _buildRelationItem(relation);
        },
      ),
    );
  }

  Widget _buildRelationItem(Map<String, dynamic> relation) {
    // 로그인한 사람 기준으로 관계를 표시하기 위해 역관계로 변환
    final originalRelation = relation['relation'] ?? '';
    final relationText = _getDisplayRelation(originalRelation);
    final relatedMemberName = relation['related_member_name'] ?? '';
    final relatedMemberPhone = relation['related_member_phone'] ?? '';
    final isMaster = relation['_is_master'] != null;
    final registeredAt = relation['registered_at'] ?? '';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFF1F5F9),
            width: 1.0,
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(24.0),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 관계 타입 아이콘
            Container(
              width: 65.0,
              height: 65.0,
              padding: EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: _getRelationColor(relationText),
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _getRelationIcon(relationText),
                    color: _getRelationIconColor(relationText),
                    size: 24.0,
                  ),
                  SizedBox(height: 2.0),
                  Text(
                    relationText,
                    style: AppTextStyles.cardMeta.copyWith(
                      color: _getRelationIconColor(relationText),
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            SizedBox(width: 16.0),
            
            // 관계 정보
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Expanded(
                        child: Text(
                          relatedMemberName,
                          style: AppTextStyles.cardTitle.copyWith(
                            color: Color(0xFF1E293B),
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isMaster)
                        Container(
                          padding: EdgeInsetsDirectional.fromSTEB(8.0, 4.0, 8.0, 4.0),
                          decoration: BoxDecoration(
                            color: Color(0xFFEF4444),
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          child: Text(
                            '예약권한',
                            style: AppTextStyles.overline.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 8.0),
                  if (relatedMemberPhone.isNotEmpty)
                    Text(
                      relatedMemberPhone,
                      style: AppTextStyles.bodyTextSmall.copyWith(
                        color: Color(0xFF64748B),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  SizedBox(height: 12.0),
                  
                  // 등록일과 삭제 버튼
                  Row(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                        decoration: BoxDecoration(
                          color: Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(6.0),
                          border: Border.all(
                            color: Color(0xFFE2E8F0),
                            width: 1.0,
                          ),
                        ),
                        child: Text(
                          '등록일',
                          style: AppTextStyles.cardMeta.copyWith(
                            color: Color(0xFF475569),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      SizedBox(width: 8.0),
                      Text(
                        _formatDate(registeredAt),
                        style: AppTextStyles.cardSubtitle.copyWith(
                          color: Color(0xFF475569),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Spacer(),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8.0),
                          onTap: () => _confirmDeleteRelation(relation),
                          child: Container(
                            padding: EdgeInsets.all(8.0),
                            child: Icon(
                              Icons.delete_outline,
                              color: Color(0xFFEF4444),
                              size: 20.0,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getRelationColor(String relation) {
    switch (relation) {
      case '배우자':
        return Color(0xFFFCE4EC);
      case '부모':
        return Color(0xFFE8F5E8);
      case '자녀':
        return Color(0xFFE3F2FD);
      case '친구':
        return Color(0xFFFFF3E0);
      case '동료':
        return Color(0xFFF3E5F5);
      case '기타':
        return Color(0xFFF1F5F9);
      default:
        return Color(0xFFF1F5F9);
    }
  }

  IconData _getRelationIcon(String relation) {
    switch (relation) {
      case '배우자':
        return Icons.favorite;
      case '부모':
        return Icons.elderly;
      case '자녀':
        return Icons.child_friendly;
      case '친구':
        return Icons.group;
      case '동료':
        return Icons.work;
      case '기타':
        return Icons.person;
      default:
        return Icons.person;
    }
  }

  Color _getRelationIconColor(String relation) {
    switch (relation) {
      case '배우자':
        return Color(0xFFE91E63);
      case '부모':
        return Color(0xFF4CAF50);
      case '자녀':
        return Color(0xFF2196F3);
      case '친구':
        return Color(0xFFFF9800);
      case '동료':
        return Color(0xFF9C27B0);
      case '기타':
        return Color(0xFF64748B);
      default:
        return Color(0xFF64748B);
    }
  }

  String _formatDate(String dateString) {
    if (dateString.isEmpty) return '';
    
    try {
      DateTime date = DateTime.parse(dateString);
      return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }

  // 로그인한 사람 기준으로 관계를 표시하기 위한 변환 함수
  String _getDisplayRelation(String relation) {
    switch (relation) {
      case '부모':
        return '자녀'; // 내가 부모면 상대방은 자녀
      case '자녀':
        return '부모'; // 내가 자녀면 상대방은 부모
      case '배우자':
        return '배우자'; // 배우자는 동일
      case '친구':
        return '친구'; // 친구는 동일
      case '동료':
        return '동료'; // 동료는 동일
      case '기타':
        return '기타'; // 기타는 동일
      case '가족':
        return '가족'; // 가족은 동일
      default:
        return relation; // 기본값은 원래 관계
    }
  }

  void _confirmDeleteRelation(Map<String, dynamic> relation) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('관계 삭제'),
          content: Text('${relation['related_member_name']}님과의 관계를 삭제하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('취소'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteRelation(relation['id']);
              },
              child: Text('삭제'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
            ),
          ],
        );
      },
    );
  }
}

// 관계 등록 다이얼로그
class _AddRelationDialog extends StatefulWidget {
  final int memberId;
  final VoidCallback onRelationAdded;

  const _AddRelationDialog({
    required this.memberId,
    required this.onRelationAdded,
  });

  @override
  _AddRelationDialogState createState() => _AddRelationDialogState();
}

class _AddRelationDialogState extends State<_AddRelationDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  Map<String, dynamic>? _selectedMember;
  Map<String, dynamic>? _currentMember;
  String _selectedRelation = '부모';
  bool _isMaster = true; // 부모 관계가 기본이므로 예약권한도 기본 체크
  bool _isSearching = false;

  final List<String> _relationTypes = ['부모', '자녀', '배우자', '친구', '동료', '기타'];

  @override
  void initState() {
    super.initState();
    _loadCurrentMember();
  }

  Future<void> _loadCurrentMember() async {
    try {
      final result = await SupabaseAdapter.getData(
        table: 'v3_members',
        fields: ['member_id', 'member_name', 'member_phone', 'member_type'],
        where: [
          {'field': 'member_id', 'operator': '=', 'value': widget.memberId},
        ],
      );

      if (result.isNotEmpty) {
        setState(() {
          _currentMember = result[0];
        });
      }
    } catch (e) {
      print('현재 회원 정보 로드 오류: $e');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchMembers() async {
    final searchText = _searchController.text.trim();
    if (searchText.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final phoneSearchText = searchText.replaceAll('-', '');

      final result = await SupabaseAdapter.getData(
        table: 'v3_members',
        fields: ['member_id', 'member_name', 'member_phone', 'member_type'],
        limit: 50,
      );

      // 클라이언트 사이드에서 이름 또는 전화번호로 필터링
      final filteredMembers = result.where((member) {
        // 자기 자신 제외
        if (member['member_id'] == widget.memberId) {
          return false;
        }

        final memberName = (member['member_name'] ?? '').toString().toLowerCase();
        final memberPhone = (member['member_phone'] ?? '').toString().replaceAll('-', '');
        final searchLower = searchText.toLowerCase();

        return memberName.contains(searchLower) ||
            memberPhone.contains(phoneSearchText);
      }).toList();

      setState(() {
        _searchResults = filteredMembers;
      });
    } catch (e) {
      print('검색 오류: $e');
      setState(() {
        _searchResults = [];
      });
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  Future<void> _addRelation() async {
    if (_selectedMember == null) {
      _showSnackBar('회원을 선택해주세요.', Colors.red);
      return;
    }

    if (_currentMember == null) {
      _showSnackBar('현재 회원 정보를 불러올 수 없습니다.', Colors.red);
      return;
    }

    try {
      // 역관계 매핑
      String reverseRelation = _getReverseRelation(_selectedRelation);

      // 첫 번째 관계 추가 (현재 회원 -> 선택된 회원)
      final relation1 = {
        'member_id': widget.memberId,
        'member_name': _currentMember!['member_name'],
        'member_phone': _currentMember!['member_phone'],
        'member_type': _currentMember!['member_type'],
        'relation': _selectedRelation,
        'related_member_id': _selectedMember!['member_id'],
        'related_member_name': _selectedMember!['member_name'],
        'related_member_phone': _selectedMember!['member_phone'],
        '_is_master': _isMaster ? widget.memberId : null, // 현재 회원이 마스터면 현재 회원 ID, 아니면 null
        'registered_at': DateTime.now().toIso8601String(),
      };

      // 두 번째 관계 추가 (선택된 회원 -> 현재 회원)
      final relation2 = {
        'member_id': _selectedMember!['member_id'],
        'member_name': _selectedMember!['member_name'],
        'member_phone': _selectedMember!['member_phone'],
        'member_type': _selectedMember!['member_type'],
        'relation': reverseRelation,
        'related_member_id': widget.memberId,
        'related_member_name': _currentMember!['member_name'],
        'related_member_phone': _currentMember!['member_phone'],
        '_is_master': _isMaster ? widget.memberId : null, // 현재 회원이 마스터면 현재 회원 ID, 아니면 null
        'registered_at': DateTime.now().toIso8601String(),
      };

      // 첫 번째 관계 저장
      await SupabaseAdapter.addData(
        table: 'v2_group',
        data: relation1,
      );

      // 두 번째 관계 저장
      await SupabaseAdapter.addData(
        table: 'v2_group',
        data: relation2,
      );

      Navigator.of(context).pop();
      widget.onRelationAdded();
      _showSnackBar('관계가 등록되었습니다.', Colors.green);
    } catch (e) {
      _showSnackBar('관계 등록 중 오류가 발생했습니다: $e', Colors.red);
    }
  }

  String _getReverseRelation(String relation) {
    switch (relation) {
      case '부모':
        return '자녀';
      case '자녀':
        return '부모';
      case '배우자':
        return '배우자';
      case '친구':
        return '친구';
      case '동료':
        return '동료';
      case '기타':
        return '기타';
      default:
        return '기타';
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 700.0,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
          maxWidth: 700.0,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.0),
          boxShadow: [
            BoxShadow(
              blurRadius: 24.0,
              color: Color(0x1A000000),
              offset: Offset(0.0, 8.0),
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 헤더
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF06B6D4), Color(0xFF0891B2)],
                  stops: [0.0, 1.0],
                  begin: AlignmentDirectional(-1.0, 0.0),
                  end: AlignmentDirectional(1.0, 0.0),
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16.0),
                  topRight: Radius.circular(16.0),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40.0,
                          height: 40.0,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          child: Icon(
                            Icons.group_add,
                            color: Colors.white,
                            size: 24.0,
                          ),
                        ),
                        SizedBox(width: 16.0),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '관계 등록',
                              style: AppTextStyles.titleH3.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                            ),
                            Text(
                              '회원 관계를 등록하세요',
                              style: AppTextStyles.bodyTextSmall.copyWith(
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20.0),
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 40.0,
                          height: 40.0,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20.0),
                          ),
                          child: Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 20.0,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // 내용
            Flexible(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 회원 검색
                      Text(
                        '회원 검색',
                        style: AppTextStyles.bodyText.copyWith(
                          color: Color(0xFF1E293B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 8.0),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12.0),
                                border: Border.all(
                                  color: Color(0xFFE2E8F0),
                                  width: 1.0,
                                ),
                              ),
                              child: TextField(
                                controller: _searchController,
                                style: AppTextStyles.bodyText.copyWith(
                                  color: Color(0xFF1E293B),
                                ),
                                decoration: InputDecoration(
                                  hintText: '이름 또는 전화번호를 입력하세요',
                                  hintStyle: AppTextStyles.bodyText.copyWith(
                                    color: Color(0xFF94A3B8),
                                  ),
                                  prefixIcon: Icon(
                                    Icons.search,
                                    color: Color(0xFF94A3B8),
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.all(16.0),
                                ),
                                onSubmitted: (_) => _searchMembers(),
                              ),
                            ),
                          ),
                          SizedBox(width: 12.0),
                          ElevatedButton(
                            onPressed: _searchMembers,
                            child: Text('검색'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF06B6D4),
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            ),
                          ),
                        ],
                      ),
                      
                      // 검색 결과
                      if (_isSearching)
                        Container(
                          height: 100.0,
                          child: Center(
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (_searchResults.isNotEmpty)
                        Container(
                          height: 200.0,
                          margin: EdgeInsets.only(top: 16.0),
                          decoration: BoxDecoration(
                            border: Border.all(color: Color(0xFFE2E8F0)),
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: ListView.builder(
                            itemCount: _searchResults.length,
                            itemBuilder: (context, index) {
                              final member = _searchResults[index];
                              final isSelected = _selectedMember?['member_id'] == member['member_id'];
                              
                              return ListTile(
                                selected: isSelected,
                                selectedTileColor: Color(0xFFE3F2FD),
                                title: Text(
                                  member['member_name'] ?? '',
                                  style: AppTextStyles.bodyText.copyWith(
                                    color: Color(0xFF1E293B),
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                  ),
                                ),
                                subtitle: Text(
                                  '${member['member_phone'] ?? ''} • ${member['member_type'] ?? ''}',
                                  style: AppTextStyles.bodyTextSmall.copyWith(
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                trailing: isSelected
                                    ? Icon(Icons.check_circle, color: Colors.blue)
                                    : null,
                                onTap: () {
                                  setState(() {
                                    _selectedMember = member;
                                    // 부모 관계일 경우에만 예약권한 기본 체크
                                    _isMaster = (_selectedRelation == '부모');
                                  });
                                },
                              );
                            },
                          ),
                        )
                      else if (_searchController.text.trim().isNotEmpty && _searchResults.isEmpty)
                        Container(
                          height: 100.0,
                          margin: EdgeInsets.only(top: 16.0),
                          decoration: BoxDecoration(
                            border: Border.all(color: Color(0xFFE2E8F0)),
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search_off,
                                  color: Color(0xFF94A3B8),
                                  size: 32.0,
                                ),
                                SizedBox(height: 8.0),
                                Text(
                                  '검색 결과가 없습니다',
                                  style: AppTextStyles.bodyTextSmall.copyWith(
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      
                      SizedBox(height: 24.0),
                      
                      // 관계 선택
                      if (_currentMember != null && _selectedMember != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '관계 설정',
                              style: AppTextStyles.bodyText.copyWith(
                                color: Color(0xFF1E293B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 4.0),
                            Text(
                              '${_currentMember!['member_name']} 님은 ${_selectedMember!['member_name']} 님의',
                              style: AppTextStyles.bodyTextSmall.copyWith(
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        )
                      else
                        Text(
                          '관계',
                          style: AppTextStyles.cardTitle.copyWith(
                            color: Color(0xFF1E293B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      SizedBox(height: 8.0),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        decoration: BoxDecoration(
                          color: Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12.0),
                          border: Border.all(
                            color: Color(0xFFE2E8F0),
                            width: 1.0,
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedRelation,
                            isExpanded: true,
                            dropdownColor: Colors.white,
                            style: AppTextStyles.bodyText.copyWith(
                              color: Color(0xFF1E293B),
                            ),
                            items: _relationTypes.map((String type) {
                              return DropdownMenuItem<String>(
                                value: type,
                                child: Text(
                                  type,
                                  style: AppTextStyles.bodyText.copyWith(
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                _selectedRelation = newValue!;
                                // 부모 관계일 경우에만 예약권한 기본 체크
                                _isMaster = (_selectedRelation == '부모');
                              });
                            },
                          ),
                        ),
                      ),
                      
                      SizedBox(height: 24.0),
                      
                      // 마스터 권한 설정
                      if (_currentMember != null && _selectedMember != null)
                        Row(
                          children: [
                            Checkbox(
                              value: _isMaster,
                              onChanged: (bool? value) {
                                setState(() {
                                  _isMaster = value ?? false;
                                });
                              },
                            ),
                            SizedBox(width: 8.0),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '예약권한 부여',
                                    style: AppTextStyles.bodyText.copyWith(
                                      color: Color(0xFF1E293B),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '${_currentMember!['member_name']} 님이 ${_selectedMember!['member_name']} 님의 예약권한을 가집니다.',
                                    style: AppTextStyles.bodyTextSmall.copyWith(
                                      color: Color(0xFF64748B),
                                    ),
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
            ),
            
            // 하단 버튼
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(16.0),
                  bottomRight: Radius.circular(16.0),
                ),
                border: Border(
                  top: BorderSide(
                    color: Color(0xFFE2E8F0),
                    width: 1.0,
                  ),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text('취소'),
                    ),
                    SizedBox(width: 12.0),
                    ElevatedButton(
                      onPressed: _addRelation,
                      child: Text('등록'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF06B6D4),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}