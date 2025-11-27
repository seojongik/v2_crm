import 'package:flutter/material.dart';
import '/pages/crm5_hr/tab4_staff_pro_register/tab2_1_manager_contract_list.dart';
import '/pages/crm5_hr/tab4_staff_pro_register/tab2_2_pro_contract_list.dart';

class Tab2StaffManagementTab extends StatefulWidget {
  const Tab2StaffManagementTab({super.key});

  @override
  State<Tab2StaffManagementTab> createState() => _Tab2StaffManagementTabState();
}

class _Tab2StaffManagementTabState extends State<Tab2StaffManagementTab> {
  
  // 콜백 함수들 (더미 함수로 초기화하여 버튼이 처음부터 활성화되도록 함)
  VoidCallback? _toggleManagerFilter = () {};
  VoidCallback? _toggleProFilter = () {};
  VoidCallback? _openNewManager = () {};
  VoidCallback? _openNewPro = () {};
  VoidCallback? _toggleProSalaryView = () {};
  
  // 프로 급여/시간 보기 상태
  bool _showProSalaryView = true;
  
  // 섹션 표시 상태
  bool _showEmployeeSection = true;
  bool _showProSection = true;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // 단순한 제목 헤더
          Container(
            margin: EdgeInsets.fromLTRB(16, 16, 16, 8),
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.groups_outlined,
                  color: Color(0xFF374151),
                  size: 24,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '직원 관리',
                        style: TextStyle(
                          color: Color(0xFF1F2937),
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '직원과 프로의 계약 정보를 통합 관리하세요',
                        style: TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // 섹션 토글 버튼들
                Row(
                  children: [
                    // 프로 섹션 토글
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _showProSection = !_showProSection;
                        });
                      },
                      icon: Icon(
                        _showProSection ? Icons.sports : Icons.sports_outlined,
                        color: _showProSection ? Color(0xFF6B7280) : Color(0xFF6B7280),
                        size: 16,
                      ),
                      label: Text(
                        '프로',
                        style: TextStyle(
                          color: Color(0xFF1F2937),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: _showProSection 
                            ? Color(0xFF6B7280).withOpacity(0.1)
                            : Colors.transparent,
                        side: BorderSide(
                          color: _showProSection ? Color(0xFF6B7280) : Color(0xFFD1D5DB)
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    // 직원 섹션 토글
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _showEmployeeSection = !_showEmployeeSection;
                        });
                      },
                      icon: Icon(
                        _showEmployeeSection ? Icons.person : Icons.person_outline,
                        color: _showEmployeeSection ? Color(0xFF3B82F6) : Color(0xFF6B7280),
                        size: 16,
                      ),
                      label: Text(
                        '직원',
                        style: TextStyle(
                          color: _showEmployeeSection ? Color(0xFF3B82F6) : Color(0xFF6B7280),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: _showEmployeeSection 
                            ? Color(0xFF3B82F6).withOpacity(0.1)
                            : Colors.transparent,
                        side: BorderSide(
                          color: _showEmployeeSection ? Color(0xFF3B82F6) : Color(0xFFD1D5DB)
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // 동적 컨텐츠 영역
          Expanded(
            child: Container(
              margin: EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  // 왼쪽: 프로 계약 관리 (조건부 표시)
                  if (_showProSection)
                    Expanded(
                      flex: _showEmployeeSection ? 1 : 2,
                      child: Container(
                        margin: EdgeInsets.only(right: _showEmployeeSection ? 8 : 0),
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
                            // 프로 액션 헤더
                            Container(
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Color(0xFF3B82F6).withOpacity(0.08), Color(0xFF1D4ED8).withOpacity(0.04)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(12),
                                  topRight: Radius.circular(12),
                                ),
                                border: Border(
                                  bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Color(0xFF3B82F6).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          Icons.person_outline,
                                          color: Color(0xFF3B82F6),
                                          size: 20,
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '프로 계약 관리',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF1F2937),
                                              ),
                                            ),
                                            Text(
                                              '프로별 계약 조건 및 차수별 계약 내역',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFF6B7280),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      // 재직/퇴직 필터 토글 버튼
                                      OutlinedButton.icon(
                                        onPressed: () {
                                          print('🔘 프로 필터 버튼 클릭됨');
                                          if (_toggleProFilter != null) {
                                            _toggleProFilter!();
                                          }
                                        },
                                        icon: Icon(
                                          Icons.visibility,
                                          color: Color(0xFF1F2937),
                                          size: 14,
                                        ),
                                        label: Text(
                                          '재직/퇴직',
                                          style: TextStyle(
                                            color: Color(0xFF1F2937),
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          backgroundColor: Colors.white,
                                          side: BorderSide(color: Color(0xFF3B82F6)),
                                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          minimumSize: Size(0, 32),
                                        ),
                                      ),
                                      SizedBox(width: 6),
                                      // 급여/시간 보기 필터 토글 버튼
                                      OutlinedButton.icon(
                                        onPressed: () {
                                          setState(() {
                                            _showProSalaryView = !_showProSalaryView;
                                          });
                                          if (_toggleProSalaryView != null) {
                                            _toggleProSalaryView!();
                                          }
                                        },
                                        icon: Icon(
                                          _showProSalaryView ? Icons.attach_money : Icons.schedule,
                                          color: Color(0xFF3B82F6),
                                          size: 14,
                                        ),
                                        label: Text(
                                          _showProSalaryView ? '급여' : '시간',
                                          style: TextStyle(
                                            color: Color(0xFF1F2937),
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          side: BorderSide(color: Color(0xFF3B82F6).withOpacity(0.3)),
                                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          minimumSize: Size(0, 32),
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      // 새 프로 등록 버튼
                                      ElevatedButton.icon(
                                        onPressed: () {
                                          print('🔘 새 프로 등록 버튼 클릭됨');
                                          if (_openNewPro != null) {
                                            _openNewPro!();
                                          }
                                        },
                                        icon: Icon(Icons.person_add_outlined, color: Colors.white, size: 14),
                                        label: Text(
                                          '새 프로 등록',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Color(0xFF3B82F6),
                                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          elevation: 0,
                                          minimumSize: Size(0, 32),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            
                            // 직원 계약 리스트 위젯
                            Expanded(
                              child: Tab2ProContractListWidget(
                                showHeader: false,
                                onToggleFilter: (callback) {
                                  print('🔍 프로 필터 콜백 등록됨');
                                  _toggleProFilter = callback;
                                },
                                onOpenNew: (callback) {
                                  print('🔍 새 프로 등록 콜백 등록됨');
                                  _openNewPro = callback;
                                },
                                onToggleSalaryView: (callback) {
                                  print('🔍 프로 급여/시간 토글 콜백 등록됨');
                                  _toggleProSalaryView = callback;
                                },
                                initialSalaryView: _showProSalaryView,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  
                  // 오른쪽: 직원 계약 관리 (조건부 표시)
                  if (_showEmployeeSection)
                    Expanded(
                      flex: _showProSection ? 1 : 2,
                      child: Container(
                        margin: EdgeInsets.only(left: _showProSection ? 8 : 0),
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
                            // 직원 액션 헤더
                            Container(
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Color(0xFF3B82F6).withOpacity(0.08), Color(0xFF1D4ED8).withOpacity(0.04)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(12),
                                  topRight: Radius.circular(12),
                                ),
                                border: Border(
                                  bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Color(0xFF3B82F6).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          Icons.person_outline,
                                          color: Color(0xFF3B82F6),
                                          size: 20,
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '직원 계약 관리',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF1F2937),
                                              ),
                                            ),
                                            Text(
                                              '직원별 계약 조건 및 차수별 계약 내역',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFF6B7280),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      // 재직/퇴직 필터 토글 버튼
                                      OutlinedButton.icon(
                                        onPressed: () {
                                          print('🔘 직원 필터 버튼 클릭됨');
                                          if (_toggleManagerFilter != null) {
                                            _toggleManagerFilter!();
                                          }
                                        },
                                        icon: Icon(
                                          Icons.visibility,
                                          color: Color(0xFF1F2937),
                                          size: 14,
                                        ),
                                        label: Text(
                                          '재직/퇴직',
                                          style: TextStyle(
                                            color: Color(0xFF1F2937),
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          backgroundColor: Colors.white,
                                          side: BorderSide(color: Color(0xFF3B82F6)),
                                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          minimumSize: Size(0, 32),
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      // 새 프로 등록 버튼
                                      ElevatedButton.icon(
                                        onPressed: () {
                                          print('🔘 새 직원 등록 버튼 클릭됨');
                                          if (_openNewManager != null) {
                                            _openNewManager!();
                                          }
                                        },
                                        icon: Icon(Icons.person_add_outlined, color: Colors.white, size: 14),
                                        label: Text(
                                          '새 직원 등록',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Color(0xFF3B82F6),
                                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          elevation: 0,
                                          minimumSize: Size(0, 32),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            
                            // 직원 계약 리스트 위젯
                            Expanded(
                              child: Tab2ManagerContractListWidget(
                                showHeader: false,
                                onToggleFilter: (callback) {
                                  print('🔍 직원 필터 콜백 등록됨');
                                  _toggleManagerFilter = callback;
                                },
                                onOpenNew: (callback) {
                                  print('🔍 새 직원 등록 콜백 등록됨');
                                  _openNewManager = callback;
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          SizedBox(height: 16),
        ],
      ),
    );
  }
}