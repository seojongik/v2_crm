import 'package:flutter/material.dart';
import 'main_page.dart';
import 'lib/services/api_service.dart';
import '../../constants/font_sizes.dart';

class LoginByAdminPage extends StatefulWidget {
  const LoginByAdminPage({Key? key}) : super(key: key);

  @override
  _LoginByAdminPageState createState() => _LoginByAdminPageState();
}

class _LoginByAdminPageState extends State<LoginByAdminPage> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _filteredMembers = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // API 서비스 초기화
    ApiService.initializeReservationSystem(branchId: 'test');
    _loadMembers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      print('회원 목록 조회 시작');
      
      // 새로운 API 서비스 사용
      final members = await ApiService.getMembers(limit: 100);
      
      setState(() {
        _members = members;
        _filteredMembers = members;
        _isLoading = false;
      });
      
      print('회원 목록 로딩 완료: ${members.length}명');
    } catch (e) {
      print('회원 목록 로딩 오류: $e');
      setState(() {
        _errorMessage = '회원 목록을 불러오는데 실패했습니다: $e';
        _isLoading = false;
      });
    }
  }

  void _filterMembers(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredMembers = _members;
      } else {
        _filteredMembers = _members.where((member) {
          final name = member['member_name']?.toString().toLowerCase() ?? '';
          final phone = member['member_phone']?.toString().replaceAll('-', '') ?? '';
          final searchQuery = query.toLowerCase().replaceAll('-', '');
          
          return name.contains(searchQuery) || phone.contains(searchQuery);
        }).toList();
      }
    });
  }

  void _selectMember(Map<String, dynamic> member) {
    print('회원 선택됨: ${member['member_name']} (ID: ${member['member_id']})');
    
    // 선택된 회원 정보를 메인 페이지로 전달하며 이동
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MainPage(
          isAdminMode: true,
          selectedMember: member,
          branchId: member['branch_id'] ?? 'test',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    final horizontalPadding = isSmallScreen ? 16.0 : 32.0;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          '회원 선택',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.blue,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadMembers,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 검색 헤더
            _buildSearchHeader(horizontalPadding),
            
            // 회원 목록
            Expanded(
              child: _buildMemberList(horizontalPadding),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchHeader(double horizontalPadding) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.all(horizontalPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 안내 메시지
          Container(
            padding: EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.admin_panel_settings,
                  color: Colors.blue,
                  size: 24.0,
                ),
                SizedBox(width: 12.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '관리자 모드',
                        style: AppTextStyles.bodyText.copyWith(color: Colors.blue, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4.0),
                      Text(
                        '접근하려는 회원을 선택해주세요',
                        overflow: TextOverflow.ellipsis,
          maxLines: 1,
          style: $1),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.0),
          
          // 검색 필드
          TextField(
            controller: _searchController,
            onChanged: _filterMembers,
            decoration: InputDecoration(
              hintText: '회원명 또는 전화번호로 검색',
              prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: Colors.grey[600]),
                      onPressed: () {
                        _searchController.clear();
                        _filterMembers('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: BorderSide.none,
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
            ),
          ),
          SizedBox(height: 8.0),
          
          // 결과 개수
          Text(
            '총 ${_filteredMembers.length}명의 회원',
            overflow: TextOverflow.ellipsis,
          maxLines: 1,
          style: $1),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberList(double horizontalPadding) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16.0),
            Text(
              '회원 목록을 불러오는 중...',
              overflow: TextOverflow.ellipsis,
          maxLines: 1,
          style: $1),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64.0,
              color: Colors.red,
            ),
            SizedBox(height: 16.0),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyText.copyWith(color: Colors.red),
            ),
            SizedBox(height: 16.0),
            ElevatedButton(
              onPressed: _loadMembers,
              child: Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    if (_filteredMembers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_search,
              size: 64.0,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16.0),
            Text(
              _searchController.text.isNotEmpty
                  ? '검색 결과가 없습니다'
                  : '등록된 회원이 없습니다',
              overflow: TextOverflow.ellipsis,
          maxLines: 1,
          style: $1),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 8.0),
      itemCount: _filteredMembers.length,
      itemBuilder: (context, index) {
        final member = _filteredMembers[index];
        return _buildMemberCard(member);
      },
    );
  }

  Widget _buildMemberCard(Map<String, dynamic> member) {
    final memberId = member['member_id']?.toString() ?? '';
    final memberName = member['member_name']?.toString() ?? '이름 없음';
    final memberPhone = member['member_phone']?.toString() ?? '전화번호 없음';

    return Container(
      margin: EdgeInsets.only(bottom: 8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8.0,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12.0),
          onTap: () => _selectMember(member),
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Row(
              children: [
                // 회원 아이콘
                Container(
                  width: 48.0,
                  height: 48.0,
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(24.0),
                  ),
                  child: Icon(
                    Icons.person,
                    color: Colors.blue,
                    size: 24.0,
                  ),
                ),
                SizedBox(width: 16.0),
                
                // 회원 정보
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        memberName,
                        style: AppTextStyles.bodyText.copyWith(color: Colors.black87, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4.0),
                      Text(
                        memberPhone,
                        overflow: TextOverflow.ellipsis,
          maxLines: 1,
          style: $1),
                      ),
                      SizedBox(height: 2.0),
                      Text(
                        'ID: $memberId',
                        overflow: TextOverflow.ellipsis,
          maxLines: 1,
          style: $1),
                      ),
                    ],
                  ),
                ),
                
                // 선택 아이콘
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.grey[400],
                  size: 16.0,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 