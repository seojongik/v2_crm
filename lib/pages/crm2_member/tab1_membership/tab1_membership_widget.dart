import '/components/common_tag_filter/common_tag_filter_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/services/api_service.dart';
import '/services/tab_design_upper.dart';
import '/services/upper_button_input_design.dart';
import '/services/table_design.dart';
import '/constants/ui_constants.dart';
import 'member_page/member_main.dart';
import 'crm2_member_new.dart';
import '/constants/font_sizes.dart';
import 'package:flutter/material.dart';
import 'tab1_membership_model.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:html' as html;
export 'tab1_membership_model.dart';

class Tab1MembershipWidget extends StatefulWidget {
  const Tab1MembershipWidget({super.key, this.onNavigate});

  final Function(String)? onNavigate;

  @override
  State<Tab1MembershipWidget> createState() => _Tab1MembershipWidgetState();
}

class _Tab1MembershipWidgetState extends State<Tab1MembershipWidget>
    with TickerProviderStateMixin {
  late Tab1MembershipModel _model;
  TabController? _tagTabController;


  // 크레딧 위젯 생성 함수
  Widget _buildCreditWidget(Map<String, dynamic>? creditInfo) {
    if (creditInfo == null) {
      return Text(
        '-',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Pretendard',
          color: Color(0xFF64748B),
          fontSize: 14.0,
          fontWeight: FontWeight.w400,
        ),
      );
    }

    int totalBalance = creditInfo['total_balance'] ?? 0;
    int contractCount = creditInfo['contract_count'] ?? 0;
    String? nearestExpiryDateStr = creditInfo['nearest_expiry_date'];

    if (totalBalance == 0) {
      return Text(
        '-',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Pretendard',
          color: Color(0xFF64748B),
          fontSize: 14.0,
          fontWeight: FontWeight.w400,
        ),
      );
    }

    String formattedCredit = totalBalance.abs().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );

    String balanceText = totalBalance < 0 ? '-$formattedCredit' : formattedCredit;
    String mainText = contractCount > 0 ? '$balanceText(${contractCount}건)' : balanceText;

    List<Widget> creditWidgets = [];

    // 메인 크레딧 표시
    creditWidgets.add(
      Text(
        mainText,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Pretendard',
          color: totalBalance < 0 ? Color(0xFFDC2626) : Color(0xFF1E293B),
          fontSize: 14.0,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    // 만료일자 표시
    if (nearestExpiryDateStr != null && nearestExpiryDateStr.isNotEmpty) {
      try {
        DateTime expiryDate = DateTime.parse(nearestExpiryDateStr);
        DateTime now = DateTime.now();
        DateTime nowDate = DateTime(now.year, now.month, now.day); // 시간 제거
        DateTime expiryDateOnly = DateTime(expiryDate.year, expiryDate.month, expiryDate.day); // 시간 제거
        int remainingDays = expiryDateOnly.difference(nowDate).inDays;

        Color dateColor;
        if (remainingDays <= 7) {
          dateColor = Color(0xFFDC2626); // 빨간색
        } else if (remainingDays <= 30) {
          dateColor = Color(0xFFD97706); // 주황색
        } else {
          dateColor = Color(0xFF64748B); // 기본 회색
        }

        creditWidgets.add(SizedBox(height: 2.0));
        creditWidgets.add(
          Text(
            '(남은일수: ${remainingDays}일)',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Pretendard',
              color: dateColor,
              fontSize: 11.0,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      } catch (e) {
        // 날짜 파싱 실패 시 무시
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: creditWidgets,
    );
  }


  // 크레딧 스타일 가져오기 함수
  Map<String, dynamic> _getCreditStyle(Map<String, dynamic>? creditInfo) {
    if (creditInfo == null) {
      return {
        'textColor': Color(0xFF64748B),
        'backgroundColor': Colors.transparent,
        'fontWeight': FontWeight.w400,
      };
    }

    int totalBalance = creditInfo['total_balance'] ?? 0;

    if (totalBalance < 0) {
      return {
        'textColor': Color(0xFFDC2626), // 빨간색 텍스트
        'backgroundColor': Color(0xFFFCE7F3), // 분홍색 배경
        'fontWeight': FontWeight.w700, // 굵은 글씨
      };
    } else {
      return {
        'textColor': Color(0xFF1E293B), // 기본 텍스트 색상
        'backgroundColor': Colors.transparent, // 투명 배경
        'fontWeight': FontWeight.w600, // 일반 굵기
      };
    }
  }

  // 레슨권 포맷팅 함수 (총분(건수) 형식)
  String _formatLessonTickets(Map<String, dynamic>? lessonInfo) {
    if (lessonInfo == null) return '-';

    int totalBalance = lessonInfo['total_balance'] ?? 0;
    int contractCount = lessonInfo['contract_count'] ?? 0;

    if (totalBalance == 0) return '-';

    String balanceText = '${totalBalance}분';

    if (contractCount > 0) {
      return '$balanceText(${contractCount}건)';
    } else {
      return balanceText;
    }
  }

  // 레슨권 위젯 생성 함수
  Widget _buildLessonTicketsWidget(Map<String, dynamic>? lessonInfo) {
    if (lessonInfo == null) {
      return Text(
        '-',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Pretendard',
          color: Color(0xFF64748B),
          fontSize: 14.0,
          fontWeight: FontWeight.w400,
        ),
      );
    }

    int totalBalance = lessonInfo['total_balance'] ?? 0;
    int contractCount = lessonInfo['contract_count'] ?? 0;
    String? nearestExpiryDateStr = lessonInfo['nearest_expiry_date'];

    if (totalBalance == 0) {
      return Text(
        '-',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Pretendard',
          color: Color(0xFF64748B),
          fontSize: 14.0,
          fontWeight: FontWeight.w400,
        ),
      );
    }

    List<Widget> lessonWidgets = [];

    // 메인 레슨권 표시
    lessonWidgets.add(
      Text(
        '${totalBalance}분(${contractCount}건)',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Pretendard',
          color: Color(0xFF1E293B),
          fontSize: 14.0,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    // 만료일자 표시
    if (nearestExpiryDateStr != null && nearestExpiryDateStr.isNotEmpty) {
      try {
        DateTime expiryDate = DateTime.parse(nearestExpiryDateStr);
        DateTime now = DateTime.now();
        DateTime nowDate = DateTime(now.year, now.month, now.day); // 시간 제거
        DateTime expiryDateOnly = DateTime(expiryDate.year, expiryDate.month, expiryDate.day); // 시간 제거
        int remainingDays = expiryDateOnly.difference(nowDate).inDays;

        Color dateColor;
        if (remainingDays <= 7) {
          dateColor = Color(0xFFDC2626); // 빨간색
        } else if (remainingDays <= 30) {
          dateColor = Color(0xFFD97706); // 주황색
        } else {
          dateColor = Color(0xFF64748B); // 기본 회색
        }

        lessonWidgets.add(SizedBox(height: 2.0));
        lessonWidgets.add(
          Text(
            '(남은일수: ${remainingDays}일)',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Pretendard',
              color: dateColor,
              fontSize: 11.0,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      } catch (e) {
        // 날짜 파싱 실패 시 무시
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: lessonWidgets,
    );
  }

  // 시간권 위젯 생성 함수
  Widget _buildTimeTicketsWidget(Map<String, dynamic>? timeInfo) {
    if (timeInfo == null) {
      return Text(
        '-',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Pretendard',
          color: Color(0xFF64748B),
          fontSize: 14.0,
          fontWeight: FontWeight.w400,
        ),
      );
    }

    int totalBalance = timeInfo['total_balance'] ?? 0;
    int contractCount = timeInfo['contract_count'] ?? 0;
    String? nearestExpiryDateStr = timeInfo['nearest_expiry_date'];

    if (totalBalance == 0) {
      return Text(
        '-',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Pretendard',
          color: Color(0xFF64748B),
          fontSize: 14.0,
          fontWeight: FontWeight.w400,
        ),
      );
    }

    List<Widget> timeWidgets = [];

    // 메인 시간권 표시
    timeWidgets.add(
      Text(
        '${totalBalance}분(${contractCount}건)',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Pretendard',
          color: Color(0xFF1E293B),
          fontSize: 14.0,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    // 만료일자 표시
    if (nearestExpiryDateStr != null && nearestExpiryDateStr.isNotEmpty) {
      try {
        DateTime expiryDate = DateTime.parse(nearestExpiryDateStr);
        DateTime now = DateTime.now();
        DateTime nowDate = DateTime(now.year, now.month, now.day); // 시간 제거
        DateTime expiryDateOnly = DateTime(expiryDate.year, expiryDate.month, expiryDate.day); // 시간 제거
        int remainingDays = expiryDateOnly.difference(nowDate).inDays;

        Color dateColor;
        if (remainingDays <= 7) {
          dateColor = Color(0xFFDC2626); // 빨간색
        } else if (remainingDays <= 30) {
          dateColor = Color(0xFFD97706); // 주황색
        } else {
          dateColor = Color(0xFF64748B); // 기본 회색
        }

        timeWidgets.add(SizedBox(height: 2.0));
        timeWidgets.add(
          Text(
            '(남은일수: ${remainingDays}일)',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Pretendard',
              color: dateColor,
              fontSize: 11.0,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      } catch (e) {
        // 날짜 파싱 실패 시 무시
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: timeWidgets,
    );
  }

  // 기간권 위젯 생성 함수
  Widget _buildTermTicketsWidget(Map<String, dynamic>? termInfo) {
    if (termInfo == null) {
      return Text(
        '-',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Pretendard',
          color: Color(0xFF64748B),
          fontSize: 14.0,
          fontWeight: FontWeight.w400,
        ),
      );
    }

    List<Map<String, dynamic>> termTypes = (termInfo['term_types'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

    if (termTypes.isEmpty) {
      return Text(
        '-',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Pretendard',
          color: Color(0xFF64748B),
          fontSize: 14.0,
          fontWeight: FontWeight.w400,
        ),
      );
    }

    List<Widget> termWidgets = [];

    for (int i = 0; i < termTypes.length && i < 2; i++) {
      var termType = termTypes[i];
      String billText = termType['bill_text'] ?? '';
      int remainingDays = termType['remaining_days'] ?? 0;

      if (i > 0) {
        termWidgets.add(SizedBox(height: 4.0));
      }

      // 남은 일수에 따른 색상 결정
      Color textColor;
      if (remainingDays <= 7) {
        textColor = Color(0xFFDC2626); // 빨간색 (7일 이하)
      } else if (remainingDays <= 30) {
        textColor = Color(0xFFD97706); // 주황색 (30일 이하)
      } else {
        textColor = Color(0xFF1E293B); // 기본 색상
      }

      termWidgets.add(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              billText,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Pretendard',
                color: Color(0xFF1E293B),
                fontSize: 14.0,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 2.0),
            Text(
              '(남은일수: ${remainingDays}일)',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Pretendard',
                color: textColor,
                fontSize: 11.0,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    // 2개 이상일 경우 '+N개' 표시
    if (termTypes.length > 2) {
      termWidgets.add(SizedBox(height: 4.0));
      termWidgets.add(
        Text(
          '+${termTypes.length - 2}개',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Pretendard',
            color: Color(0xFF94A3B8),
            fontSize: 10.0,
            fontWeight: FontWeight.w400,
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: termWidgets,
    );
  }

  // 프로 위젯 생성 함수
  Widget _buildProWidget(Map<String, dynamic>? lessonInfo) {
    if (lessonInfo == null) {
      return Text(
        '-',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Pretendard',
          color: Color(0xFF64748B),
          fontSize: 14.0,
          fontWeight: FontWeight.w400,
        ),
      );
    }

    List<String> proNames = (lessonInfo['pro_names'] as List<dynamic>?)?.cast<String>() ?? [];

    if (proNames.isEmpty) {
      return Text(
        '-',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Pretendard',
          color: Color(0xFF64748B),
          fontSize: 14.0,
          fontWeight: FontWeight.w400,
        ),
      );
    }

    return Text(
      proNames.join(', '),
      textAlign: TextAlign.center,
      style: TextStyle(
        fontFamily: 'Pretendard',
        color: Color(0xFF1E293B),
        fontSize: 14.0,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  // 계층적 회원 데이터를 평면화하는 함수
  List<Map<String, dynamic>> _buildFlattenedMemberList() {
    List<Map<String, dynamic>> flattenedList = [];
    
    for (var memberDisplayData in _model.hierarchicalMemberData) {
      // 부모 회원 추가
      flattenedList.add({
        'member': memberDisplayData.memberData,
        'isJunior': false,
      });
      
      // 주니어 회원들 추가
      for (var child in memberDisplayData.children) {
        flattenedList.add({
          'member': child.memberData,
          'isJunior': true,
        });
      }
    }
    
    return flattenedList;
  }

  // 신규회원 등록 다이얼로그 표시
  void _showAddMemberDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AddMemberDialog(
          onMemberAdded: () {
            // 회원 추가 후 목록 새로고침
            _model.loadMemberData();
          },
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => Tab1MembershipModel());

    _model.textController ??= TextEditingController();
    _model.textFieldFocusNode ??= FocusNode();

    // 상태 변경 콜백 설정
    _model.setStateCallback(() {
      if (mounted) {
        safeSetState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tagTabController?.dispose();
    _model.dispose();
    super.dispose();
  }

  // TabController 업데이트 또는 생성
  void _updateTabController() {
    final tags = _model.getAvailableTags();
    final selectedTags = _model.getSelectedTags();
    final currentIndex = selectedTags.isNotEmpty
        ? tags.indexOf(selectedTags.first)
        : 0;
    final safeIndex = currentIndex >= 0 && currentIndex < tags.length ? currentIndex : 0;

    if (_tagTabController == null || _tagTabController!.length != tags.length) {
      _tagTabController?.dispose();
      _tagTabController = TabController(
        length: tags.length,
        vsync: this,
        initialIndex: safeIndex,
      );
      _tagTabController!.addListener(() {
        if (!_tagTabController!.indexIsChanging) {
          final selectedTag = tags[_tagTabController!.index];
          _model.updateTagFilter([selectedTag]);
        }
      });
    }
  }

  // 태그에 맞는 아이콘 반환
  IconData _getIconForTag(String tag) {
    switch (tag) {
      case '최근등록':
        return Icons.fiber_new; // NEW 아이콘
      case '전체':
        return Icons.grid_view; // 전체 보기 아이콘
      case '기간권':
        return Icons.calendar_month; // 달력 아이콘
      case '레슨회원':
        return Icons.school; // 학교/레슨 아이콘
      case '관계':
        return Icons.family_restroom; // 가족 관계 아이콘
      default:
        // 프로 이름인 경우
        return Icons.person; // 사람 아이콘
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
                          mainAxisSize: MainAxisSize.max,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 헤더 섹션 (검색 및 버튼만)
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
                                child: Row(
                                  mainAxisSize: MainAxisSize.max,
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    // 신규등록 버튼 - member_registration 권한 체크 (왼쪽)
                                    if (ApiService.hasPermission('member_registration'))
                                      ButtonDesignUpper.buildIconButton(
                                        text: '신규등록',
                                        icon: Icons.person_add,
                                        onPressed: () {
                                          _showAddMemberDialog();
                                        },
                                        color: 'green',
                                        size: 'large',
                                      )
                                    else
                                      SizedBox.shrink(), // 권한 없으면 빈 공간
                                    // 검색 영역 (오른쪽)
                                    ButtonDesignUpper.buildSearchBar(
                                      controller: _model.textController!,
                                      focusNode: _model.textFieldFocusNode,
                                      hintText: '회원명 또는 연락처로 검색',
                                      onSearch: () async {
                                        await _model.performSearch();
                                      },
                                      searchFieldWidth: 300.0,
                                      buttonSize: 'large',
                                      buttonColor: 'cyan',
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // 태그 필터 섹션 - 중간 사이즈 탭
                            Builder(
                              builder: (context) {
                                _updateTabController();
                                final tags = _model.getAvailableTags();

                                if (_tagTabController == null || tags.isEmpty) {
                                  return SizedBox.shrink();
                                }

                                return Padding(
                                  padding: EdgeInsets.fromLTRB(24.0, 0.0, 24.0, 8.0),
                                  child: TabDesignUpper.buildStyledTabBar(
                                    controller: _tagTabController!,
                                    themeNumber: 1,
                                    size: 'medium',
                                    tabs: tags.map((tag) =>
                                      TabDesignUpper.buildTabItem(
                                        _getIconForTag(tag),
                                        tag,
                                        size: 'medium',
                                      )
                                    ).toList(),
                                  ),
                                );
                              },
                            ),
                            // 테이블 섹션
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.all(24.0),
                                child: TableDesign.buildTableContainer(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.max,
                                    children: [
                                      // 테이블 헤더 (고정)
                                      TableDesign.buildTableHeader(
                                        children: [
                                          TableDesign.buildHeaderColumn(text: '#', width: 50.0),
                                          TableDesign.buildHeaderColumn(text: '이름', flex: 2),
                                          TableDesign.buildHeaderColumn(text: '전화번호', flex: 3),
                                          TableDesign.buildHeaderColumn(text: '구분', flex: 1),
                                          TableDesign.buildHeaderColumn(text: '크레딧', flex: 3),
                                          TableDesign.buildHeaderColumn(text: '레슨권', flex: 3),
                                          TableDesign.buildHeaderColumn(text: '시간권', flex: 3),
                                          TableDesign.buildHeaderColumn(text: '기간권', flex: 3),
                                          TableDesign.buildHeaderColumn(text: '프로', flex: 3),
                                        ],
                                      ),
                                      // 테이블 데이터 (스크롤 가능)
                                      Expanded(
                                        child: TableDesign.buildTableBody(
                                          itemCount: _buildFlattenedMemberList().length,
                                          itemBuilder: (context, index) {
                                            final memberItem = _buildFlattenedMemberList()[index];
                                            final member = memberItem['member'];
                                            final isJunior = memberItem['isJunior'] as bool;
                                            final memberTypeBadge = ApiService.getMemberTypeBadge(member['member_type']);

                                            return _MemberRowWidget(
                                              member: member,
                                              isJunior: isJunior,
                                              memberTypeBadge: memberTypeBadge,
                                              model: _model,
                                              buildCreditWidget: _buildCreditWidget,
                                              buildLessonTicketsWidget: _buildLessonTicketsWidget,
                                              buildTimeTicketsWidget: _buildTimeTicketsWidget,
                                              buildTermTicketsWidget: _buildTermTicketsWidget,
                                              buildProWidget: _buildProWidget,
                                            );
                                          },
                                          isLoading: _model.isLoading,
                                          hasError: _model.errorMessage != null,
                                          emptyWidget: Center(
                                            child: Text(
                                              '조회된 회원이 없습니다.',
                                              style: TextStyle(
                                                fontFamily: 'Pretendard',
                                                color: Color(0xFF64748B),
                                                fontSize: 16.0,
                                              ),
                                            ),
                                          ),
                                          errorWidget: Center(
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.error_outline,
                                                  size: 48.0,
                                                  color: Color(0xFFEF4444),
                                                ),
                                                SizedBox(height: 16.0),
                                                Text(
                                                  _model.errorMessage ?? '오류가 발생했습니다.',
                                                  style: TextStyle(
                                                    fontFamily: 'Pretendard',
                                                    color: Color(0xFFEF4444),
                                                    fontSize: 14.0,
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
    );
  }
}

class _MemberRowWidget extends StatefulWidget {
  final Map<String, dynamic> member;
  final bool isJunior;
  final Map<String, dynamic> memberTypeBadge;
  final Tab1MembershipModel model;
  final Widget Function(Map<String, dynamic>?) buildCreditWidget;
  final Widget Function(Map<String, dynamic>?) buildLessonTicketsWidget;
  final Widget Function(Map<String, dynamic>?) buildTimeTicketsWidget;
  final Widget Function(Map<String, dynamic>?) buildTermTicketsWidget;
  final Widget Function(Map<String, dynamic>?) buildProWidget;

  const _MemberRowWidget({
    required this.member,
    required this.isJunior,
    required this.memberTypeBadge,
    required this.model,
    required this.buildCreditWidget,
    required this.buildLessonTicketsWidget,
    required this.buildTimeTicketsWidget,
    required this.buildTermTicketsWidget,
    required this.buildProWidget,
  });

  @override
  _MemberRowWidgetState createState() => _MemberRowWidgetState();
}

class _MemberRowWidgetState extends State<_MemberRowWidget> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          showDialog(
            context: context,
            barrierDismissible: true,
            builder: (BuildContext context) {
              return Dialog(
                backgroundColor: Colors.transparent,
                insetPadding: EdgeInsets.all(20.0),
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.75,
                  height: MediaQuery.of(context).size.height * 0.95,
                  decoration: BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16.0),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 24.0,
                        color: Color(0x1A000000),
                        offset: Offset(0.0, 8.0),
                      )
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16.0),
                    child: MemberMainWidget(
                      memberId: widget.member['member_id'],
                      memberData: widget.member,
                    ),
                  ),
                ),
              );
            },
          ).then((_) {
            // 다이얼로그 닫힐 때 회원 목록 새로고침
            widget.model.loadMemberData();
          });
        },
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(
            minHeight: 60.0,
          ),
          decoration: BoxDecoration(
            color: isHovered
              ? Color(0xFFF1F5F9)
              : (widget.isJunior ? Color(0xFFF8FAFC) : Colors.white),
            border: Border(
              bottom: BorderSide(
                color: Color(0xFFF1F5F9),
                width: 1.0,
              ),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              widget.isJunior ? 32.0 : 16.0, // 주니어는 들여쓰기
              16.0,
              16.0,
              16.0,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.max,
              children: [
                Container(
                  width: 50.0,
                  child: Row(
                    children: [
                      if (widget.isJunior) ...[
                        Icon(
                          Icons.subdirectory_arrow_right,
                          size: 16.0,
                          color: Color(0xFF94A3B8),
                        ),
                        SizedBox(width: 4.0),
                      ],
                      Expanded(
                        child: Text(
                          '${widget.member['member_no_branch'] ?? '-'}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            color: widget.isJunior ? Color(0xFF64748B) : Color(0xFF1E293B),
                            fontSize: 14.0,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Row(
                    children: [
                      if (widget.isJunior) ...[
                        Container(
                          padding: EdgeInsetsDirectional.fromSTEB(4.0, 2.0, 4.0, 2.0),
                          decoration: BoxDecoration(
                            color: Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(4.0),
                          ),
                          child: Text(
                            'Jr',
                            style: TextStyle(
                              fontFamily: 'Pretendard',
                              color: Color(0xFFD97706),
                              fontSize: 10.0,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        SizedBox(width: 6.0),
                      ],
                      Expanded(
                        child: Text(
                          widget.member['member_name'] ?? '-',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            color: widget.isJunior ? Color(0xFF64748B) : Color(0xFF1E293B),
                            fontSize: 14.0,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    ApiService.formatPhoneNumber(widget.member['member_phone']),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      color: Color(0xFF64748B),
                      fontSize: 14.0,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Center(
                    child: Container(
                      padding: EdgeInsetsDirectional.fromSTEB(8.0, 4.0, 8.0, 4.0),
                      decoration: BoxDecoration(
                        color: widget.memberTypeBadge['backgroundColor'],
                        borderRadius: BorderRadius.circular(6.0),
                      ),
                      child: Text(
                        widget.memberTypeBadge['text'],
                        style: AppTextStyles.cardBody.copyWith(color: widget.memberTypeBadge['color'], fontWeight: FontWeight.w500, fontSize: 12.0),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(8.0, 0.0, 8.0, 0.0),
                    child: widget.buildCreditWidget(widget.model.memberCredits[widget.member['member_id']]),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(8.0, 0.0, 8.0, 0.0),
                    child: widget.buildLessonTicketsWidget(widget.model.memberLessonTickets[widget.member['member_id']]),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(8.0, 0.0, 8.0, 0.0),
                    child: widget.buildTimeTicketsWidget(widget.model.memberTimeTickets[widget.member['member_id']]),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(8.0, 0.0, 8.0, 0.0),
                    child: widget.buildTermTicketsWidget(widget.model.memberTermTickets[widget.member['member_id']]),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: widget.buildProWidget(widget.model.memberLessonTickets[widget.member['member_id']]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
