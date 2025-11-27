import 'package:flutter/material.dart';
import 'main_page.dart';
import 'services/api_service.dart';

class LoginGroupMasterOptionPage extends StatefulWidget {
  final Map<String, dynamic> memberData;
  final Map<String, dynamic> branchData;
  final String branchId;

  const LoginGroupMasterOptionPage({
    Key? key,
    required this.memberData,
    required this.branchData,
    required this.branchId,
  }) : super(key: key);

  @override
  _LoginGroupMasterOptionPageState createState() => _LoginGroupMasterOptionPageState();
}

class _LoginGroupMasterOptionPageState extends State<LoginGroupMasterOptionPage> 
    with TickerProviderStateMixin {
  List<Map<String, dynamic>> _groupMembers = [];
  bool _isLoading = false;
  
  // 애니메이션 컨트롤러
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late List<Animation<Offset>> _cardAnimations;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadGroupMembers();
  }

  void _initAnimations() {
    _fadeController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _fadeController.forward();
  }

  void _initCardAnimations() {
    _cardAnimations = List.generate(
      _groupMembers.length,
      (index) => Tween<Offset>(
        begin: Offset(0, 0.5),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _slideController,
        curve: Interval(
          index * 0.1,
          (index * 0.1) + 0.5,
          curve: Curves.easeOutCubic,
        ),
      )),
    );
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _loadGroupMembers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final currentMemberPhone = widget.memberData['member_phone']?.toString();
      if (currentMemberPhone == null) {
        throw Exception('회원 전화번호 정보가 없습니다.');
      }

      print('현재 로그인한 회원 전화번호: $currentMemberPhone');
      
      // v2_group 테이블에서 _is_master 컬럼에 현재 회원 번호가 있는 데이터 조회
      final response = await ApiService.getData(
        table: 'v2_group',
        where: [
          {
            'field': '_is_master',
            'operator': '=', 
            'value': widget.memberData['member_id']?.toString() ?? '',
          },
          {
            'field': 'branch_id',
            'operator': '=',
            'value': widget.branchId,
          }
        ],
      );

      print('v2_group 조회 결과: $response');
      
      if (response.isNotEmpty) {
        final List<Map<String, dynamic>> groupData = response;
        
        // 본인 계정과 관련 계정들 모두 포함
        List<Map<String, dynamic>> allAccounts = [];
        Set<String> addedMemberIds = {};
        
        // 본인 계정 추가
        final currentMemberId = widget.memberData['member_id']?.toString();
        allAccounts.add({
          'member_id': widget.memberData['member_id'],
          'member_name': widget.memberData['member_name'],
          'member_phone': widget.memberData['member_phone'],
          'member_type': widget.memberData['member_type'],
          'relation': '본인',
          'is_master': true,
        });
        addedMemberIds.add(currentMemberId ?? '');
        
        // 관련 계정들 추가
        for (var group in groupData) {
          final groupMemberId = group['member_id']?.toString();
          final relatedMemberId = group['related_member_id']?.toString();
          final relatedMemberName = group['related_member_name']?.toString();
          final relatedMemberPhone = group['related_member_phone']?.toString();
          
          // 현재 마스터가 아닌 계정만 추가 (related_member)
          if (relatedMemberId != null && 
              relatedMemberName != null && 
              relatedMemberId != currentMemberId &&
              !addedMemberIds.contains(relatedMemberId)) {
            
            // related_member의 관계를 찾기 위해 해당 member_id로 된 레코드 찾기
            String relationForRelated = '관련';
            for (var groupRecord in groupData) {
              if (groupRecord['member_id']?.toString() == relatedMemberId) {
                relationForRelated = groupRecord['relation']?.toString() ?? '관련';
                break;
              }
            }
            
            // 관련 회원의 상세 정보 조회 (member_type 등)
            final memberDetailResponse = await ApiService.getData(
              table: 'v3_members',
              where: [
                {
                  'field': 'member_id',
                  'operator': '=',
                  'value': relatedMemberId,
                },
                {
                  'field': 'branch_id',
                  'operator': '=',
                  'value': widget.branchId,
                }
              ],
            );
            
            String memberType = '일반';
            if (memberDetailResponse.isNotEmpty) {
              memberType = memberDetailResponse[0]['member_type']?.toString() ?? '일반';
            }
            
            allAccounts.add({
              'member_id': relatedMemberId,
              'member_name': relatedMemberName,
              'member_phone': relatedMemberPhone,
              'member_type': memberType,
              'relation': relationForRelated,
              'is_master': false,
            });
            
            addedMemberIds.add(relatedMemberId);
          }
        }
        
        setState(() {
          _groupMembers = allAccounts;
          _isLoading = false;
        });

        // 카드 애니메이션 초기화
        _initCardAnimations();
        
      } else {
        // 그룹 멤버가 없으면 본인 계정만 표시하고 바로 로그인 진행
        _proceedWithSingleAccount();
      }
      
    } catch (e) {
      print('그룹 멤버 조회 오류: $e');
      setState(() {
        _isLoading = false;
      });
      
      // 오류 발생 시 본인 계정으로 바로 진행
      _proceedWithSingleAccount();
    }
  }

  void _proceedWithSingleAccount() {
    // 그룹 멤버가 없거나 오류 발생 시 본인 계정으로 바로 로그인 진행
    ApiService.setCurrentUser(widget.memberData);
    ApiService.setCurrentBranch(widget.branchId, widget.branchData);
    
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => MainPage(
          isAdminMode: false,
          selectedMember: widget.memberData,
          branchId: widget.branchId,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: Duration(milliseconds: 300),
      ),
    );
  }

  void _selectAccount(Map<String, dynamic> selectedAccount) {
    final memberName = selectedAccount['member_name']?.toString() ?? '사용자';
    final relation = selectedAccount['relation']?.toString() ?? '';
    
    String message;
    if (selectedAccount['is_master'] == true) {
      message = '본인 계정($memberName)으로 로그인하시겠습니까?';
    } else {
      message = '$relation 계정($memberName)으로 로그인하시겠습니까?';
    }
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Color(0xFF00704A).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.person, color: Color(0xFF00704A), size: 24),
            ),
            SizedBox(width: 12),
            Text('계정 선택 확인', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(fontSize: 16, color: Color(0xFF4A5568)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('취소', style: TextStyle(color: Color(0xFF718096))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _proceedWithSelectedAccount(selectedAccount);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF00704A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('로그인', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _proceedWithSelectedAccount(Map<String, dynamic> selectedAccount) async {
    try {
      // 선택된 계정의 전체 정보 조회
      Map<String, dynamic> fullMemberData;
      
      if (selectedAccount['is_master'] == true) {
        // 본인 계정인 경우 기존 데이터 사용
        fullMemberData = widget.memberData;
      } else {
        // 관련 계정인 경우 전체 정보 다시 조회
        final memberDetailResponse = await ApiService.getData(
          table: 'v3_members',
          where: [
            {
              'field': 'member_id',
              'operator': '=',
              'value': selectedAccount['member_id']?.toString(),
            },
            {
              'field': 'branch_id',
              'operator': '=',
              'value': widget.branchId,
            }
          ],
        );
        
        if (memberDetailResponse.isNotEmpty) {
          fullMemberData = memberDetailResponse[0];
        } else {
          throw Exception('선택된 계정의 정보를 불러올 수 없습니다.');
        }
      }
      
      // ApiService에 선택된 사용자 및 지점 설정
      ApiService.setCurrentUser(fullMemberData);
      ApiService.setCurrentBranch(widget.branchId, widget.branchData);
      
      print('선택된 계정으로 로그인: ${fullMemberData['member_name']} (${fullMemberData['member_id']})');
      
      // 메인 페이지로 이동
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => MainPage(
            isAdminMode: false,
            selectedMember: fullMemberData,
            branchId: widget.branchId,
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: Duration(milliseconds: 300),
        ),
      );
      
    } catch (e) {
      print('계정 로그인 처리 오류: $e');
      _showErrorSnackBar('선택한 계정으로 로그인하는 중 오류가 발생했습니다: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: Color(0xFFD32F2F),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.all(16),
        elevation: 8,
        duration: Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final memberName = widget.memberData['member_name']?.toString() ?? '사용자';
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isTablet = screenWidth > 600;
    final isMobile = screenWidth < 600;
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF00704A),
              Color(0xFF00704A).withOpacity(0.8),
              Colors.white,
            ],
            stops: [0.0, 0.3, 1.0],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                // 상단 헤더
                _buildHeader(memberName, screenWidth, screenHeight, isMobile),
                
                // 계정 목록
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(isMobile ? 24 : 32),
                        topRight: Radius.circular(isMobile ? 24 : 32),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: Offset(0, -5),
                        ),
                      ],
                    ),
                    child: _buildAccountList(screenWidth, isMobile),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String memberName, double screenWidth, double screenHeight, bool isMobile) {
    final headerPadding = isMobile ? 20.0 : 32.0;
    final titleSize = isMobile ? 20.0 : 24.0;
    final welcomeSize = isMobile ? 16.0 : 18.0;
    final descSize = isMobile ? 12.0 : 14.0;
    final badgeSize = isMobile ? 10.0 : 12.0;
    
    return Container(
      padding: EdgeInsets.all(headerPadding),
      child: Column(
        children: [
          // 뒤로가기 버튼과 타이틀
          Row(
            children: [
              Container(
                width: isMobile ? 40 : 48,
                height: isMobile ? 40 : 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.arrow_back_ios, 
                    color: Colors.white, 
                    size: isMobile ? 16 : 20
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Expanded(
                child: Text(
                  '계정 선택',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: titleSize,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              SizedBox(width: isMobile ? 40 : 48), // 균형을 위한 공간
            ],
          ),
          
          SizedBox(height: isMobile ? 16 : 24),
          
          // 사용자 정보 카드
          Container(
            padding: EdgeInsets.all(isMobile ? 16 : 20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isMobile ? 10 : 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
                  ),
                  child: Icon(
                    Icons.group,
                    color: Color(0xFF00704A),
                    size: isMobile ? 20 : 24,
                  ),
                ),
                SizedBox(width: isMobile ? 12 : 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '로그인할 계정을 선택하세요',
                          style: TextStyle(
                            fontSize: welcomeSize,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(height: isMobile ? 2 : 4),
                      Text(
                        '관리 권한이 있는 계정들입니다',
                        style: TextStyle(
                          fontSize: descSize,
                          color: Colors.white.withOpacity(0.8),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 8 : 12, 
                    vertical: isMobile ? 4 : 6
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
                  ),
                  child: Text(
                    '${_groupMembers.length}개 계정',
                    style: TextStyle(
                      fontSize: badgeSize,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountList(double screenWidth, bool isMobile) {
    if (_isLoading) {
      return _buildLoadingState(isMobile);
    }

    if (_groupMembers.isEmpty) {
      return _buildEmptyState(isMobile);
    }

    final listPadding = isMobile ? 16.0 : 24.0;

    return ListView.builder(
      padding: EdgeInsets.all(listPadding),
      physics: BouncingScrollPhysics(),
      itemCount: _groupMembers.length,
      itemBuilder: (context, index) {
        final account = _groupMembers[index];
        
        return SlideTransition(
          position: _cardAnimations.isNotEmpty && index < _cardAnimations.length
              ? _cardAnimations[index]
              : AlwaysStoppedAnimation(Offset.zero),
          child: _buildAccountCard(account, index, screenWidth, isMobile),
        );
      },
    );
  }

  Widget _buildLoadingState(bool isMobile) {
    final titleSize = isMobile ? 16.0 : 18.0;
    final descSize = isMobile ? 12.0 : 14.0;
    final iconSize = isMobile ? 20.0 : 24.0;
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(iconSize),
            decoration: BoxDecoration(
              color: Color(0xFF00704A).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: CircularProgressIndicator(
              color: Color(0xFF00704A),
              strokeWidth: 3,
            ),
          ),
          SizedBox(height: isMobile ? 16 : 24),
          Text(
            '관련 계정을 확인하는 중...',
            style: TextStyle(
              fontSize: titleSize,
              fontWeight: FontWeight.w500,
              color: Color(0xFF4A5568),
            ),
          ),
          SizedBox(height: 8),
          Text(
            '잠시만 기다려주세요',
            style: TextStyle(
              fontSize: descSize,
              color: Color(0xFF718096),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isMobile) {
    final titleSize = isMobile ? 18.0 : 20.0;
    final descSize = isMobile ? 12.0 : 14.0;
    final iconSize = isMobile ? 40.0 : 48.0;
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(isMobile ? 20 : 24),
            decoration: BoxDecoration(
              color: Color(0xFFF7FAFC),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.person_outline,
              size: iconSize,
              color: Color(0xFF9CA3AF),
            ),
          ),
          SizedBox(height: isMobile ? 16 : 24),
          Text(
            '본인 계정으로 로그인합니다',
            style: TextStyle(
              fontSize: titleSize,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4A5568),
            ),
          ),
          SizedBox(height: 8),
          Text(
            '관련 계정이 없습니다',
            style: TextStyle(
              fontSize: descSize,
              color: Color(0xFF718096),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountCard(Map<String, dynamic> account, int index, double screenWidth, bool isMobile) {
    final memberId = account['member_id']?.toString() ?? '';
    final memberName = account['member_name']?.toString() ?? '사용자';
    final memberPhone = account['member_phone']?.toString() ?? '';
    final memberType = account['member_type']?.toString() ?? '일반';
    final relation = account['relation']?.toString() ?? '';
    final isMaster = account['is_master'] == true;

    // 반응형 크기 설정
    final cardPadding = isMobile ? 16.0 : 24.0;
    final iconSize = isMobile ? 48.0 : 64.0;
    final iconRadius = isMobile ? 12.0 : 16.0;
    final titleSize = isMobile ? 16.0 : 20.0;
    final typeSize = isMobile ? 13.0 : 15.0;
    final phoneSize = isMobile ? 12.0 : 14.0;
    final spacing = isMobile ? 12.0 : 20.0;
    final arrowSize = isMobile ? 12.0 : 16.0;
    final arrowPadding = isMobile ? 8.0 : 12.0;

    // 계정 타입별 색상 및 아이콘
    Color primaryColor;
    Color accentColor;
    IconData accountIcon;
    
    if (isMaster) {
      primaryColor = Color(0xFF00704A);
      accentColor = Color(0xFF4CAF50);
      accountIcon = Icons.person;
    } else {
      switch (relation) {
        case '가족':
          primaryColor = Color(0xFF1565C0);
          accentColor = Color(0xFF42A5F5);
          accountIcon = Icons.family_restroom;
          break;
        case '부모':
          primaryColor = Color(0xFF8E24AA);
          accentColor = Color(0xFFBA68C8);
          accountIcon = Icons.elderly;
          break;
        case '자녀':
          primaryColor = Color(0xFFFF7043);
          accentColor = Color(0xFFFFAB91);
          accountIcon = Icons.child_care;
          break;
        default:
          primaryColor = Color(0xFF546E7A);
          accentColor = Color(0xFF90A4AE);
          accountIcon = Icons.person_outline;
      }
    }

    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
        border: isMaster ? Border.all(color: Color(0xFF00704A).withOpacity(0.3), width: 2) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
          onTap: () => _selectAccount(account),
          child: Container(
            padding: EdgeInsets.all(cardPadding),
            child: Row(
              children: [
                // 계정 아이콘
                Container(
                  width: iconSize,
                  height: iconSize,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [primaryColor, accentColor],
                    ),
                    borderRadius: BorderRadius.circular(iconRadius),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    accountIcon,
                    color: Colors.white,
                    size: isMobile ? 24 : 28,
                  ),
                ),
                
                SizedBox(width: spacing),
                
                // 계정 정보
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 이름과 관계
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              memberName,
                              style: TextStyle(
                                fontSize: titleSize,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2D3748),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: 8),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isMobile ? 6 : 8,
                              vertical: isMobile ? 2 : 4,
                            ),
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              relation,
                              style: TextStyle(
                                fontSize: isMobile ? 10 : 12,
                                color: primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      SizedBox(height: isMobile ? 4 : 6),
                      
                      // 회원 타입
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(isMobile ? 3 : 4),
                            decoration: BoxDecoration(
                              color: accentColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Icon(
                              Icons.badge,
                              size: isMobile ? 12 : 14,
                              color: accentColor,
                            ),
                          ),
                          SizedBox(width: isMobile ? 6 : 8),
                          Text(
                            memberType,
                            style: TextStyle(
                              fontSize: typeSize,
                              color: Color(0xFF4A5568),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      
                      SizedBox(height: isMobile ? 4 : 6),
                      
                      // 전화번호
                      if (memberPhone.isNotEmpty) ...[
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(isMobile ? 3 : 4),
                              decoration: BoxDecoration(
                                color: Color(0xFFF7FAFC),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Icon(
                                Icons.phone,
                                size: isMobile ? 12 : 14,
                                color: Color(0xFF718096),
                              ),
                            ),
                            SizedBox(width: isMobile ? 6 : 8),
                            Flexible(
                              child: Text(
                                memberPhone,
                                style: TextStyle(
                                  fontSize: phoneSize,
                                  color: Color(0xFF718096),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                
                SizedBox(width: isMobile ? 8 : 12),
                
                // 선택 버튼
                Container(
                  padding: EdgeInsets.all(arrowPadding),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios,
                    color: primaryColor,
                    size: arrowSize,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}