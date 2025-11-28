import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:reservation_system/main_page.dart' as planner;

/// 핸드폰 모양 팝업 위젯
/// 골프 플래너 앱을 독립적인 팝업 형태로 표시
class PlannerAppPopup extends StatelessWidget {
  const PlannerAppPopup({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(20),
      child: Center(
        child: Container(
          width: 420,
          height: 900,
          constraints: BoxConstraints(
            maxWidth: 420,
            maxHeight: 900,
          ),
          decoration: BoxDecoration(
            color: Color(0xFF1E1E1E), // 폰 외관 색상 (다크 그레이)
            borderRadius: BorderRadius.circular(40),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 40,
                spreadRadius: 5,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              // 상단 노치 영역
              Container(
                height: 40,
                decoration: BoxDecoration(
                  color: Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(40),
                    topRight: Radius.circular(40),
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 150,
                    height: 25,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                    ),
                  ),
                ),
              ),

              // 화면 영역 (베젤)
              Expanded(
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      // 골프 플래너 앱 컨텐츠가 여기 들어감
                      _PlannerAppContent(),

                      // 닫기 버튼 (우측 상단)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => Navigator.of(context).pop(),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 하단 홈 바 영역
              Container(
                height: 30,
                decoration: BoxDecoration(
                  color: Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(40),
                    bottomRight: Radius.circular(40),
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 140,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 골프 플래너 앱의 실제 컨텐츠
class _PlannerAppContent extends StatefulWidget {
  @override
  _PlannerAppContentState createState() => _PlannerAppContentState();
}

class _PlannerAppContentState extends State<_PlannerAppContent> {
  bool _isSelectingMember = true;
  Map<String, dynamic>? _selectedMember;
  String? _branchId;

  @override
  void initState() {
    super.initState();
    // 현재 branch_id 가져오기
    _branchId = ApiService.getCurrentBranchId();
  }

  @override
  Widget build(BuildContext context) {
    if (_isSelectingMember) {
      // 회원 선택 화면
      return _MemberSelectScreen(
        branchId: _branchId ?? '',
        onMemberSelected: (member) {
          setState(() {
            _selectedMember = member;
            _isSelectingMember = false;
          });
        },
      );
    } else {
      // 골프 플래너 메인 화면 (추후 구현)
      return _PlannerMainScreen(
        member: _selectedMember!,
        branchId: _branchId!,
        onBack: () {
          setState(() {
            _isSelectingMember = true;
            _selectedMember = null;
          });
        },
      );
    }
  }
}

/// 회원 선택 화면
class _MemberSelectScreen extends StatefulWidget {
  final String branchId;
  final Function(Map<String, dynamic>) onMemberSelected;

  const _MemberSelectScreen({
    required this.branchId,
    required this.onMemberSelected,
  });

  @override
  _MemberSelectScreenState createState() => _MemberSelectScreenState();
}

class _MemberSelectScreenState extends State<_MemberSelectScreen> {
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _filteredMembers = [];
  bool _isLoading = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadMembers();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredMembers = List.from(_members);
      } else {
        _filteredMembers = _members.where((member) {
          final name = member['member_name']?.toString().toLowerCase() ?? '';
          final phone = member['member_phone']?.toString() ?? '';
          return name.contains(query) || phone.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _loadMembers() async {
    setState(() => _isLoading = true);

    try {
      final response = await ApiService.getDataList(
        table: 'v3_members',
        where: [
          {
            'field': 'branch_id',
            'operator': '=',
            'value': widget.branchId,
          }
        ],
        orderBy: [
          {'field': 'member_name', 'direction': 'ASC'}
        ],
      );

      setState(() {
        _members = response;
        _filteredMembers = response;
        _isLoading = false;
      });
    } catch (e) {
      print('회원 목록 로딩 오류: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          '회원 선택',
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Color(0xFF3B82F6),
        elevation: 0,
      ),
      body: Column(
        children: [
          // 검색 바
          Container(
            padding: EdgeInsets.all(16),
            color: Color(0xFF3B82F6),
            child: TextField(
              controller: _searchController,
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF000000),
                fontWeight: FontWeight.w500,
              ),
              cursorColor: Colors.black,
              decoration: InputDecoration(
                hintText: '이름 또는 전화번호로 검색',
                prefixIcon: Icon(Icons.search, color: Color(0xFF64748B)),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),

          // 회원 목록
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _filteredMembers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person_off, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              '회원이 없습니다',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.all(16),
                        itemCount: _filteredMembers.length,
                        itemBuilder: (context, index) {
                          final member = _filteredMembers[index];
                          return _buildMemberCard(member);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberCard(Map<String, dynamic> member) {
    final name = member['member_name']?.toString() ?? '이름 없음';
    final phone = member['member_phone']?.toString() ?? '';
    final memberType = member['member_type']?.toString() ?? '일반';

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => widget.onMemberSelected(member),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.person, color: Colors.white, size: 24),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          SizedBox(width: 8),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Color(0xFF3B82F6).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              memberType,
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF3B82F6),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (phone.isNotEmpty) ...[
                        SizedBox(height: 4),
                        Text(
                          phone,
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Color(0xFF94A3B8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 골프 플래너 메인 화면 (실제 앱)
class _PlannerMainScreen extends StatelessWidget {
  final Map<String, dynamic> member;
  final String branchId;
  final VoidCallback onBack;

  const _PlannerMainScreen({
    required this.member,
    required this.branchId,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    // MediaQuery를 핸드폰 크기로 제한하여 팝업이 핸드폰 안에서만 표시되도록 함
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        size: Size(400, 860), // 핸드폰 내부 크기 (베젤 제외)
      ),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: planner.MainPage(
          isAdminMode: true,  // 관리자 모드로 실행
          selectedMember: member,
          branchId: branchId,
        ),
      ),
    );
  }
}

/// 회원 페이지에서 직접 열리는 골프플래너 앱 팝업
/// 회원 선택 화면을 건너뛰고 바로 해당 회원의 메인 화면으로 이동
class MemberDirectPlannerAppPopup extends StatelessWidget {
  final Map<String, dynamic> member;
  final String branchId;

  const MemberDirectPlannerAppPopup({
    Key? key,
    required this.member,
    required this.branchId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(20),
      child: Center(
        child: Container(
          width: 420,
          height: 900,
          constraints: BoxConstraints(
            maxWidth: 420,
            maxHeight: 900,
          ),
          decoration: BoxDecoration(
            color: Color(0xFF1E1E1E), // 폰 외관 색상 (다크 그레이)
            borderRadius: BorderRadius.circular(40),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 40,
                spreadRadius: 5,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              // 상단 노치 영역
              Container(
                height: 40,
                decoration: BoxDecoration(
                  color: Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(40),
                    topRight: Radius.circular(40),
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 150,
                    height: 25,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                    ),
                  ),
                ),
              ),

              // 화면 영역 (베젤)
              Expanded(
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      // 골프 플래너 앱 메인 화면 (회원 선택 건너뛰고 바로 표시)
                      MediaQuery(
                        data: MediaQuery.of(context).copyWith(
                          size: Size(400, 860), // 핸드폰 내부 크기 (베젤 제외)
                        ),
                        child: MaterialApp(
                          debugShowCheckedModeBanner: false,
                          home: planner.MainPage(
                            isAdminMode: true,
                            selectedMember: member,
                            branchId: branchId,
                          ),
                        ),
                      ),

                      // 닫기 버튼 (우측 상단)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => Navigator.of(context).pop(),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 하단 홈 바 영역
              Container(
                height: 30,
                decoration: BoxDecoration(
                  color: Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(40),
                    bottomRight: Radius.circular(40),
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 140,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
