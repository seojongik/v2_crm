import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/common_widgets.dart';
import 'package:google_fonts/google_fonts.dart';

class LoginByAdminPage extends StatefulWidget {
  final String? branchId;
  
  const LoginByAdminPage({
    Key? key,
    this.branchId,
  }) : super(key: key);

  @override
  _LoginByAdminPageState createState() => _LoginByAdminPageState();
}

class _LoginByAdminPageState extends State<LoginByAdminPage> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _filteredMembers = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _currentBranchId; // 실제 사용할 브랜치 ID

  @override
  void initState() {
    super.initState();
    
    // 개발중 팝업 표시
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DevelopmentPopup.show(
        context,
        title: '골프 플래너 앱',
        message: '골프 플래너 앱은 별도 프로젝트로 분리되어\n현재 개발 중입니다.\n조금만 기다려주세요!',
      );
    });
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
      print('CRM API로 회원 목록 조회 시작 - 브랜치 ID: $_currentBranchId');
      
      // CRM의 API 서비스 사용 (getMemberData 메서드)
      final members = await ApiService.getMemberData(
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': _currentBranchId}
        ],
        limit: 100,
        orderBy: [
          {'field': 'member_name', 'direction': 'ASC'}
        ],
      );
      
      setState(() {
        _members = members;
        _filteredMembers = members;
        _isLoading = false;
      });
      
      print('CRM API 회원 목록 로딩 완료: ${members.length}명 (브랜치: $_currentBranchId)');
      
      // 샘플 데이터 출력
      for (int i = 0; i < (members.length > 5 ? 5 : members.length); i++) {
        final member = members[i];
        print('회원 $i: ${member['member_name']} (ID: ${member['member_id']}, Branch: ${member['branch_id']})');
      }
      
    } catch (e) {
      print('CRM API 회원 목록 로딩 오류: $e');
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
    // 개발중 팝업만 표시
    DevelopmentPopup.show(
      context,
      title: '골프 플래너 앱',
      message: '골프 플래너 앱은 별도 프로젝트로 분리되어\n현재 개발 중입니다.\n조금만 기다려주세요!',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      // 골프 플래너 앱의 테마 적용
      data: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        fontFamily: GoogleFonts.notoSans().fontFamily, // Google Fonts 사용
        textTheme: GoogleFonts.notoSansTextTheme(
          Theme.of(context).textTheme,
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        appBarTheme: AppBarTheme(
          elevation: 0,
          centerTitle: true,
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          titleTextStyle: GoogleFonts.notoSans(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 2,
            textStyle: GoogleFonts.notoSans(
              fontWeight: FontWeight.w600,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
      child: Scaffold(
        backgroundColor: Color(0xFFF8F9FA),
        appBar: AppBar(
          title: Text(
            '골프 플래너 - 회원 선택',
            style: GoogleFonts.notoSans(
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: Color(0xFF00A86B),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: _isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00A86B)),
                    ),
                    SizedBox(height: 16),
                    Text(
                      '회원 목록을 불러오는 중...',
                      style: GoogleFonts.notoSans(
                        fontSize: 16,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ],
                ),
              )
            : _members.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person_off,
                          size: 64,
                          color: Color(0xFF8E8E8E),
                        ),
                        SizedBox(height: 16),
                        Text(
                          '등록된 회원이 없습니다.',
                          style: GoogleFonts.notoSans(
                            fontSize: 18,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.all(16),
                    itemCount: _members.length,
                    itemBuilder: (context, index) {
                      final member = _members[index];
                      return Card(
                        margin: EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          contentPadding: EdgeInsets.all(16),
                          leading: CircleAvatar(
                            backgroundColor: Color(0xFF00A86B),
                            child: Text(
                              member['member_name']?.toString().substring(0, 1) ?? '?',
                              style: GoogleFonts.notoSans(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            member['member_name']?.toString() ?? '이름 없음',
                            style: GoogleFonts.notoSans(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(height: 4),
                              Text(
                                'ID: ${member['member_id']?.toString() ?? 'N/A'}',
                                style: GoogleFonts.notoSans(
                                  color: Color(0xFF8E8E8E),
                                ),
                              ),
                              if (member['branch_id'] != null)
                                Text(
                                  '브랜치: ${member['branch_id']}',
                                  style: GoogleFonts.notoSans(
                                    color: Color(0xFF00A86B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                            ],
                          ),
                          trailing: Icon(
                            Icons.arrow_forward_ios,
                            color: Color(0xFF00A86B),
                            size: 16,
                          ),
                          onTap: () => _selectMember(member),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
} 