import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../../../services/api_service.dart';
import '../../../services/chat_service.dart';
import '../../../services/upper_button_input_design.dart';
import '../../../models/chat_models.dart';
import '/services/supabase_adapter.dart';

class Tab3MessageSendWidget extends StatefulWidget {
  @override
  _Tab3MessageSendWidgetState createState() => _Tab3MessageSendWidgetState();
}

class _Tab3MessageSendWidgetState extends State<Tab3MessageSendWidget> {
  List<Map<String, dynamic>> _messageData = [];
  List<Map<String, dynamic>> _filteredData = [];
  bool _isLoading = false;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();
  String _searchKeyword = '';
  
  // 1:1채팅 일괄전송 관련 변수
  List<Map<String, dynamic>> _allMembers = []; // 전체 멤버 데이터
  List<Map<String, dynamic>> _memberList = []; // 현재 표시되는 멤버 데이터
  List<Map<String, dynamic>> _selectedMembers = [];
  final TextEditingController _memberSearchController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  String _selectedMsgType = '일반안내';
  bool _isScheduled = false;
  DateTime? _scheduledDate;
  TimeOfDay? _scheduledTime;
  Timer? _searchTimer;
  bool _isLoadingMembers = false;

  @override
  void initState() {
    super.initState();
    _loadMessageData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _memberSearchController.dispose();
    _messageController.dispose();
    _searchTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchKeyword = _searchController.text.toLowerCase();
      _filterData();
    });
  }

  void _filterData() {
    if (_searchKeyword.isEmpty) {
      _filteredData = List.from(_messageData);
    } else {
      _filteredData = _messageData.where((message) {
        final memberName = (message['member_name'] ?? '').toString().toLowerCase();
        final memberId = (message['member_id'] ?? '').toString().toLowerCase();
        final memberPhone = (message['member_phone'] ?? '').toString();
        final msgContent = (message['msg'] ?? '').toString().toLowerCase();
        final msgType = (message['msg_type'] ?? '').toString().toLowerCase();
        final msgStatus = (message['msg_status'] ?? '').toString().toLowerCase();
        final msgDate = (message['msg_date'] ?? '').toString().toLowerCase();
        
        // 전화번호 검색: 하이픈 제거하고 비교
        final phoneWithoutHyphen = memberPhone.replaceAll('-', '').toLowerCase();
        final searchWithoutHyphen = _searchKeyword.replaceAll('-', '');
        final phoneMatches = phoneWithoutHyphen.contains(searchWithoutHyphen) ||
                           memberPhone.toLowerCase().contains(_searchKeyword);
        
        // 날짜 검색: 다양한 형태 지원 (2025-08-15, 2025/08/15, 08-15, 0815 등)
        final dateWithoutSeparators = msgDate.replaceAll(RegExp(r'[-/\s:]'), '');
        final searchDateWithoutSeparators = _searchKeyword.replaceAll(RegExp(r'[-/\s:]'), '');
        final dateMatches = msgDate.contains(_searchKeyword) ||
                          dateWithoutSeparators.contains(searchDateWithoutSeparators);
        
        return memberName.contains(_searchKeyword) ||
               memberId.contains(_searchKeyword) ||
               phoneMatches ||
               msgContent.contains(_searchKeyword) ||
               msgType.contains(_searchKeyword) ||
               msgStatus.contains(_searchKeyword) ||
               dateMatches;
      }).toList();
    }
  }

  Future<void> _loadMessageData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final branchId = ApiService.getCurrentBranchId() ?? 'test';
      
      print('=== 메시지 데이터 로드 시작 ===');
      print('Branch ID: $branchId');
      
      final data = await SupabaseAdapter.getData(
        table: 'v2_message',
        fields: ['msg_id', 'msg_type', 'member_id', 'member_name', 'member_phone', 'msg', 'msg_status', 'msg_sent_at', 'message_read_at', 'msg_date', 'msg_plantime', 'push_status', 'push_timestamp', 'push_agreement'],
        where: [
          {
            'field': 'branch_id',
            'operator': '=',
            'value': branchId
          }
        ],
        orderBy: [
          {
            'field': 'msg_id',
            'direction': 'DESC'
          }
        ],
      );

      setState(() {
        _messageData = data;
        _filterData();
        _isLoading = false;
      });
      print('데이터 로드 성공: ${_messageData.length}개의 메시지');
    } catch (e, stackTrace) {
      setState(() {
        _errorMessage = '오류가 발생했습니다: $e';
        _isLoading = false;
      });
      print('Exception: $e');
      print('Stack Trace: $stackTrace');
    }
    
    print('=== 메시지 데이터 로드 완료 ===');
  }

  String _getDisplayDate(Map<String, dynamic> message) {
    // 일괄발송완료 상태일 때 msg_sent_at 표시
    if (message['msg_status'] == '발송완료' && message['msg_sent_at'] != null) {
      final sentAt = message['msg_sent_at'].toString();
      // 타임스탬프가 있으면 yyyy-mm-dd hh:mm:ss 형식으로 표시
      if (sentAt.length >= 19) {
        return sentAt.substring(0, 19);
      }
      return sentAt;
    }
    // 그 외의 경우 msg_date 표시
    return message['msg_date'] ?? '-';
  }

  Widget _buildStatusChip(String? status) {
    Color statusColor = Colors.grey;
    if (status == '발송완료') {
      statusColor = Colors.green;
    } else if (status == '읽음확인') {
      statusColor = Colors.blue;
    } else if (status == '발송대기') {
      statusColor = Colors.orange;
    }
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        border: Border.all(color: statusColor),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status ?? '',
        style: TextStyle(color: statusColor, fontSize: 12),
      ),
    );
  }

  Widget _buildPushStatus(String? status) {
    if (status == null || status.isEmpty) {
      return Text('-', style: TextStyle(color: Colors.grey));
    }
    Color pushColor = Colors.grey;
    if (status == '성공') {
      pushColor = Colors.green;
    } else if (status == '실패') {
      pushColor = Colors.red;
    }
    return Text(
      status,
      style: TextStyle(color: pushColor, fontSize: 12),
    );
  }

  Widget _buildDataTable() {
    // 화면 너비에서 패딩 제외한 실제 사용 가능 너비
    final availableWidth = MediaQuery.of(context).size.width - 64;
    
    // 각 컬럼 너비 설정
    final dateWidth = 160.0;  // 두 배로 증가
    final typeWidth = 80.0;
    final receiverWidth = 90.0;
    final statusWidth = 80.0;
    final pushAgreeWidth = 70.0;
    final pushStatusWidth = 70.0;
    
    // 고정 컬럼들의 너비 합계
    final fixedColumnsWidth = dateWidth + typeWidth + receiverWidth + statusWidth + pushAgreeWidth + pushStatusWidth;
    
    // 컬럼 간격 및 마진
    final spacingAndMargin = (20 * 6) + 40; // 160px
    
    // 1:1채팅 메시지 내용이 차지할 수 있는 너비 (나머지 공간 모두)
    final messageContentWidth = (availableWidth - fixedColumnsWidth - spacingAndMargin).clamp(300.0, 800.0);
    
    return Container(
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: availableWidth),
          child: DataTable(
            headingRowColor: MaterialStateProperty.all(Colors.grey[100]),
            columnSpacing: 20,
            horizontalMargin: 20,
            showCheckboxColumn: false,
            columns: [
              DataColumn(
                label: Container(
                  width: dateWidth,
                  child: Center(child: Text('일자/발송시간', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87))),
                ),
              ),
              DataColumn(
                label: Container(
                  width: typeWidth,
                  child: Center(child: Text('구분', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87))),
                ),
              ),
              DataColumn(
                label: Container(
                  width: receiverWidth,
                  child: Center(child: Text('수신자', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87))),
                ),
              ),
              DataColumn(
                label: Container(
                  width: statusWidth,
                  child: Center(child: Text('상태', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87))),
                ),
              ),
              DataColumn(
                label: Container(
                  width: pushAgreeWidth,
                  child: Center(child: Text('푸쉬동의', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87))),
                ),
              ),
              DataColumn(
                label: Container(
                  width: pushStatusWidth,
                  child: Center(child: Text('푸쉬상태', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87))),
                ),
              ),
              DataColumn(
                label: Container(
                  width: messageContentWidth,
                  child: Text('1:1채팅 메시지', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)),
                ),
              ),
            ],
            rows: _filteredData.map((message) {
              final pushAgreement = message['push_agreement'] ?? '미확인';
              return DataRow(
                cells: [
                  DataCell(Container(
                    width: dateWidth,
                    child: Center(
                      child: Text(
                        _getDisplayDate(message),
                        style: TextStyle(fontSize: 13, color: Colors.black87),
                      ),
                    ),
                  )),
                  DataCell(Container(
                    width: typeWidth,
                    child: Center(child: Text(message['msg_type'] ?? '-', style: TextStyle(fontSize: 13, color: Colors.black87))),
                  )),
                  DataCell(Container(
                    width: receiverWidth,
                    child: Center(child: Text(message['member_name'] ?? '-', style: TextStyle(fontSize: 13, color: Colors.black87))),
                  )),
                  DataCell(Container(
                    width: statusWidth,
                    child: Center(child: _buildStatusChip(message['msg_status'])),
                  )),
                  DataCell(Container(
                    width: pushAgreeWidth,
                    child: Center(
                      child: Icon(
                        pushAgreement == '수신' ? Icons.check_circle 
                          : pushAgreement == '수신거부' ? Icons.cancel 
                          : Icons.help_outline,
                        color: pushAgreement == '수신' ? Colors.green 
                          : pushAgreement == '수신거부' ? Colors.red 
                          : Colors.orange,
                        size: 18,
                      ),
                    ),
                  )),
                  DataCell(Container(
                    width: pushStatusWidth,
                    child: Center(child: _buildPushStatus(message['push_status'])),
                  )),
                  DataCell(Container(
                    width: messageContentWidth,
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      message['msg'] ?? '-',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                      style: TextStyle(fontSize: 13, height: 1.4, color: Colors.black87),
                    ),
                  )),
                ],
                onSelectChanged: (_) => _showMessageDetail(message),
              );
            }).toList(),
          ),
        ),
      ),
    );
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
              // 왼쪽: 일괄발송 등록 버튼
              ButtonDesignUpper.buildIconButton(
                text: '일괄발송 등록',
                icon: Icons.dynamic_feed,
                onPressed: _showMessageCreateDialog,
                color: 'orange',
                size: 'large',
              ),

              // 오른쪽: 새로고침 + 검색창
              Row(
                children: [
                  // 새로고침 버튼
                  ButtonDesignUpper.buildIconButton(
                    text: '새로고침',
                    icon: Icons.refresh,
                    onPressed: _loadMessageData,
                    color: 'gray',
                    size: 'large',
                  ),

                  SizedBox(width: 12.0),

                  // 검색창
                  ButtonDesignUpper.buildSearchField(
                    controller: _searchController,
                    hintText: '수신자, 회원ID, 전화번호, 날짜, 1:1채팅 메시지 내용 등으로 검색',
                    width: 400.0,
                  ),
                ],
              ),
            ],
          ),
        ),
        
        SizedBox(height: 16),
        
        // 컨텐츠
        Container(
          height: 570,
          child: _isLoading
              ? Center(child: CircularProgressIndicator())
              : _errorMessage != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                          SizedBox(height: 16),
                          Text(_errorMessage!, style: TextStyle(color: Colors.red[700])),
                          SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadMessageData,
                            child: Text('다시 시도'),
                          ),
                        ],
                      ),
                    )
                  : _filteredData.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Color(0xFFF59E0B).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Icon(
                                  Icons.inbox,
                                  size: 64,
                                  color: Color(0xFFF59E0B),
                                ),
                              ),
                              SizedBox(height: 24),
                              Text(
                                _searchKeyword.isNotEmpty
                                    ? '검색 결과가 없습니다'
                                    : '발송된 메시지가 없습니다',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                _searchKeyword.isNotEmpty
                                    ? "'키워드: $_searchKeyword'"
                                    : '1:1채팅 일괄발송 후 내역이 여기에 표시됩니다',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Container(
                          margin: EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                spreadRadius: 1,
                                blurRadius: 3,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: _buildDataTable(),
                          ),
                        ),
        ),
      ],
    );
  }

  void _showMessageDetail(Map<String, dynamic> message) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.7,
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.0),
              boxShadow: [
                BoxShadow(
                  blurRadius: 8.0,
                  color: Color(0x1A000000),
                  offset: Offset(0.0, 2.0),
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
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16.0),
                      topRight: Radius.circular(16.0),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Row(
                      children: [
                        Container(
                          width: 40.0,
                          height: 40.0,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF06B6D4), Color(0xFF0891B2)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          child: Icon(
                            Icons.message,
                            color: Colors.white,
                            size: 20.0,
                          ),
                        ),
                        SizedBox(width: 12.0),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '메시지 상세 정보',
                                style: TextStyle(
                                  color: Color(0xFF1E293B),
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '일괄발송된 1:1채팅의 상세 내역을 확인할 수 있습니다',
                                style: TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: Icon(Icons.close, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // 구분선
                Container(
                  width: double.infinity,
                  height: 1.0,
                  color: Color(0xFFE2E8F0),
                ),
                
                // 콘텐츠
                Flexible(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Color(0xFFF8FAFC),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 기본 정보 4개 타일 가로 배치
                            Row(
                              children: [
                                Expanded(child: _buildInfoTile('일괄발송일시', message['msg_date'] ?? '-', Icons.access_time)),
                                SizedBox(width: 12),
                                Expanded(child: _buildInfoTile('메시지 구분', message['msg_type'] ?? '-', Icons.label)),
                                SizedBox(width: 12),
                                Expanded(child: _buildInfoTile('수신자', message['member_name'] ?? '-', Icons.person)),
                                SizedBox(width: 12),
                                Expanded(child: _buildInfoTile('회원 ID', message['member_id']?.toString() ?? '-', Icons.badge)),
                              ],
                            ),
                            
                            SizedBox(height: 16),
                            
                            // 1:1채팅 메시지 내용 섹션
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.chat_bubble_outline, 
                                           color: Color(0xFF06B6D4), size: 18),
                                      SizedBox(width: 8),
                                      Text(
                                        '1:1채팅 메시지 내용',
                                        style: TextStyle(
                                          color: Color(0xFF1E293B),
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 12),
                                  Container(
                                    width: double.infinity,
                                    padding: EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Color(0xFFE2E8F0)),
                                    ),
                                    child: Text(
                                      message['msg'] ?? '내용 없음',
                                      style: TextStyle(
                                        color: Color(0xFF374151),
                                        fontSize: 14,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            SizedBox(height: 16),
                            
                            // 일괄발송 상태 정보 2열 배치
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _buildSendStatusTile(message),
                                ),
                                SizedBox(width: 16),
                                Expanded(
                                  child: _buildPushStatusTile(message),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                
                // 하단 버튼
                Container(
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(16.0),
                      bottomRight: Radius.circular(16.0),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        child: Text(
                          '닫기',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
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
  }

  Widget _buildInfoTile(String label, String value, IconData icon) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Color(0xFF06B6D4), size: 16),
              SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF1E293B),
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSendStatusTile(Map<String, dynamic> message) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '일괄발송 상태 정보',
            style: TextStyle(
              color: Color(0xFF1E293B),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 16),
          _buildSimpleStatusRow('일괄발송 상태', message['msg_status'] ?? '-'),
          _buildSimpleStatusRow('발송 시간', message['msg_sent_at'] ?? '-'),
          _buildSimpleStatusRow('읽음 시간', message['message_read_at'] ?? '-'),
        ],
      ),
    );
  }

  Widget _buildPushStatusTile(Map<String, dynamic> message) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '푸쉬 알림 정보',
            style: TextStyle(
              color: Color(0xFF1E293B),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 16),
          _buildSimpleStatusRow('푸쉬 동의', message['push_agreement'] ?? '-'),
          _buildSimpleStatusRow('푸쉬 상태', message['push_status'] ?? '-'),
          _buildSimpleStatusRow('푸쉬 발송시간', message['push_timestamp'] ?? '-'),
        ],
      ),
    );
  }

  Widget _buildSimpleStatusRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF1E293B),
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 멤버 검색 기능
  Future<void> _loadMembers([String searchKeyword = '', StateSetter? dialogSetState]) async {
    print('=== 회원 데이터 로드 시작 ===');
    print('검색 키워드: "$searchKeyword"');
    
    try {
      final branchId = ApiService.getCurrentBranchId() ?? 'test';
      print('Branch ID: $branchId');
      
      // 전체 데이터 먼저 로드
      final allMembersData = await SupabaseAdapter.getData(
        table: 'v3_members',
        fields: ['member_id', 'member_name', 'member_phone', 'member_type', 'member_nickname', 'member_gender'],
        where: [
          {
            'field': 'branch_id',
            'operator': '=',
            'value': branchId
          }
        ],
        orderBy: [
          {
            'field': 'member_name',
            'direction': 'ASC'
          }
        ],
      );

      // 검색 키워드가 있는 경우 필터링
      if (searchKeyword.isNotEmpty) {
        print('검색 모드: 메모리에서 필터링');

        // 필터링
        final filteredMembers = allMembersData.where((member) {
          final memberName = (member['member_name'] ?? '').toString().toLowerCase();
          final memberPhone = (member['member_phone'] ?? '').toString();
          final memberId = (member['member_id'] ?? '').toString();

          final searchLower = searchKeyword.toLowerCase();
          final phoneWithoutHyphen = memberPhone.replaceAll('-', '').toLowerCase();
          final searchWithoutHyphen = searchKeyword.replaceAll('-', '');

          return memberName.contains(searchLower) ||
                 memberPhone.toLowerCase().contains(searchLower) ||
                 phoneWithoutHyphen.contains(searchWithoutHyphen) ||
                 memberId.contains(searchKeyword);
        }).toList();

        print('검색 결과: ${filteredMembers.length}개');
        final updateState = dialogSetState ?? setState;
        updateState(() {
          _allMembers = allMembersData;
          _memberList = filteredMembers;
        });
      } else {
        // 검색어가 없으면 전체 표시
        print('전체 데이터 표시');
        final updateState = dialogSetState ?? setState;
        updateState(() {
          _allMembers = allMembersData;
          _memberList = allMembersData;
        });
      }
      print('회원 데이터 로드 성공: ${_memberList.length}개');
    } catch (e, stackTrace) {
      print('Error loading members: $e');
      print('Stack Trace: $stackTrace');
    }
    
    print('=== 회원 데이터 로드 완료 ===');
  }

  // 1:1채팅 일괄전송 메시지 작성 팝업
  void _showMessageCreateDialog() {
    // 초기화
    setState(() {
      _allMembers = [];
      _memberList = [];
      _selectedMembers = [];
      _memberSearchController.clear();
      _messageController.clear();
      _selectedMsgType = '일반안내'; // 고정값
      _isScheduled = false;
      _scheduledDate = null;
      _scheduledTime = null;
    });
    
    // 초기 멤버 로드는 팝업 내에서 수행
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // 초기 멤버 로드 (팝업이 열릴 때 한 번만)
            if (_memberList.isEmpty && _allMembers.isEmpty) {
              _loadMembers('', setDialogState);
            }
            
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.85,
                height: MediaQuery.of(context).size.height * 0.85,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16.0),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 8.0,
                      color: Color(0x1A000000),
                      offset: Offset(0.0, 2.0),
                    )
                  ],
                ),
                child: Column(
                  children: [
                    // 헤더 섹션 - 게시판 스타일 적용
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
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 40.0,
                                  height: 40.0,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Color(0xFF06B6D4), Color(0xFF0891B2)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(10.0),
                                  ),
                                  child: Icon(
                                    Icons.send,
                                    color: Colors.white,
                                    size: 20.0,
                                  ),
                                ),
                                SizedBox(width: 12.0),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '새 1:1채팅 일괄전송 설정',
                                      style: TextStyle(
                                        color: Color(0xFF1E293B),
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      '수신자를 선택하고 1:1채팅 메시지를 작성해주세요',
                                      style: TextStyle(
                                        color: Color(0xFF64748B),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Container(
                              width: 36.0,
                              height: 36.0,
                              decoration: BoxDecoration(
                                color: Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8.0),
                                  onTap: () => Navigator.of(context).pop(),
                                  child: Icon(
                                    Icons.close,
                                    color: Color(0xFF64748B),
                                    size: 20.0,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // 구분선
                    Container(
                      width: double.infinity,
                      height: 1.0,
                      color: Color(0xFFE2E8F0),
                    ),
                    
                    // 메인 콘텐츠
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Color(0xFFF8FAFC),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Column(
                            children: [
                              // 회원 선택 및 1:1채팅 메시지 작성 영역
                              Expanded(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // 왼쪽: 수신자 선택
                                    Expanded(
                                      flex: 1,
                                      child: _buildMemberSelectionSection(setDialogState),
                                    ),
                                    
                                    SizedBox(width: 24),
                                    
                                    // 오른쪽: 선택된 수신자 + 1:1채팅 메시지 작성
                                    Expanded(
                                      flex: 1,
                                      child: Column(
                                        children: [
                                          // 선택된 수신자 목록
                                          Expanded(
                                            flex: 1,
                                            child: _buildSelectedMembersSection(setDialogState),
                                          ),
                                          
                                          SizedBox(height: 16),
                                          
                                          // 1:1채팅 메시지 작성 영역
                                          Expanded(
                                            flex: 1,
                                            child: _buildMessageComposingSection(setDialogState),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              // 하단 버튼 영역
                              SizedBox(height: 24),
                              _buildActionButtons(setDialogState),
                            ],
                          ),
                        ),
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

  // 액션 버튼 섹션 (게시판 스타일)
  Widget _buildActionButtons(StateSetter setDialogState) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // 취소 버튼
          Container(
            height: 44.0,
            decoration: BoxDecoration(
              color: Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(color: Color(0xFFE2E8F0)),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8.0),
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 80.0,
                  height: 44.0,
                  child: Center(
                    child: Text(
                      '취소',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          SizedBox(width: 12),
          
          // 발송 버튼 (게시판 스타일 그라데이션)
          Container(
            height: 44.0,
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
                onTap: () => _handleSendMessage(setDialogState),
                child: Container(
                  width: 120.0,
                  height: 44.0,
                  child: Center(
                    child: Text(
                      _isScheduled ? '예약 등록' : '즉시 발송',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 회원 선택 영역 UI (게시판 스타일)
  Widget _buildMemberSelectionSection(StateSetter setDialogState) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12.0),
                topRight: Radius.circular(12.0),
              ),
              border: Border(
                bottom: BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.people,
                  color: Color(0xFF64748B),
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  '수신자 선택',
                  style: TextStyle(
                    color: Color(0xFF1E293B),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Spacer(),
                if (_allMembers.isNotEmpty)
                  Text(
                    '총 ${_allMembers.length}명',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 14,
                    ),
                  ),
              ],
            ),
          ),
          
          // 검색 영역
          Container(
            padding: EdgeInsets.all(16),
            child: TextFormField(
              controller: _memberSearchController,
              onChanged: (value) => _searchMembers(value, setDialogState),
              decoration: InputDecoration(
                hintText: '이름 또는 전화번호로 검색',
                hintStyle: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 14,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: Color(0xFF64748B),
                  size: 20,
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: Color(0xFFE2E8F0),
                    width: 1.0,
                  ),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: Color(0xFF06B6D4),
                    width: 2.0,
                  ),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              style: TextStyle(
                color: Color(0xFF1E293B),
                fontSize: 14,
              ),
            ),
          ),
          
          // 회원 목록
          Expanded(
            child: Container(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 전체 선택 체크박스
                  Container(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Checkbox(
                          value: _allMembers.isNotEmpty && _selectedMembers.length == _allMembers.length,
                          onChanged: (value) {
                            setDialogState(() {
                              if (value == true) {
                                _selectedMembers.clear();
                                _selectedMembers.addAll(_allMembers);
                              } else {
                                _selectedMembers.clear();
                              }
                            });
                          },
                          activeColor: Color(0xFF06B6D4),
                        ),
                        SizedBox(width: 8),
                        Text(
                          '전체 선택',
                          style: TextStyle(
                            color: Color(0xFF1E293B),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // 구분선
                  Divider(color: Color(0xFFE2E8F0)),
                  
                  // 회원 목록
                  Expanded(
                    child: _isLoadingMembers
                        ? Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF06B6D4),
                            ),
                          )
                        : _memberList.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.search_off,
                                      color: Color(0xFF94A3B8),
                                      size: 48,
                                    ),
                                    SizedBox(height: 12),
                                    Text(
                                      '검색 결과가 없습니다',
                                      style: TextStyle(
                                        color: Color(0xFF64748B),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                itemCount: _memberList.length,
                                itemBuilder: (context, index) {
                                  final member = _memberList[index];
                                  final isSelected = _selectedMembers.any((m) => m['member_id'] == member['member_id']);
                                  
                                  return Container(
                                    margin: EdgeInsets.only(bottom: 8),
                                    decoration: BoxDecoration(
                                      color: isSelected ? Color(0xFFF0F9FF) : Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isSelected ? Color(0xFF06B6D4) : Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(8),
                                        onTap: () {
                                          setDialogState(() {
                                            if (isSelected) {
                                              _selectedMembers.removeWhere((m) => m['member_id'] == member['member_id']);
                                            } else {
                                              _selectedMembers.add(member);
                                            }
                                          });
                                        },
                                        child: Padding(
                                          padding: EdgeInsets.all(12),
                                          child: Row(
                                            children: [
                                              Checkbox(
                                                value: isSelected,
                                                onChanged: (value) {
                                                  setDialogState(() {
                                                    if (value == true) {
                                                      if (!isSelected) _selectedMembers.add(member);
                                                    } else {
                                                      _selectedMembers.removeWhere((m) => m['member_id'] == member['member_id']);
                                                    }
                                                  });
                                                },
                                                activeColor: Color(0xFF06B6D4),
                                              ),
                                              SizedBox(width: 8),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Text(
                                                          member['member_name'] ?? '',
                                                          style: TextStyle(
                                                            color: Color(0xFF1E293B),
                                                            fontSize: 14,
                                                            fontWeight: FontWeight.w600,
                                                          ),
                                                        ),
                                                        SizedBox(width: 8),
                                                        Container(
                                                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                          decoration: BoxDecoration(
                                                            color: Color(0xFFF1F5F9),
                                                            borderRadius: BorderRadius.circular(4),
                                                          ),
                                                          child: Text(
                                                            '#${member['member_id']}',
                                                            style: TextStyle(
                                                              color: Color(0xFF64748B),
                                                              fontSize: 12,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    SizedBox(height: 4),
                                                    Text(
                                                      member['member_phone'] ?? '',
                                                      style: TextStyle(
                                                        color: Color(0xFF64748B),
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                    if (member['member_type'] != null) ...[
                                                      SizedBox(height: 2),
                                                      Text(
                                                        member['member_type'],
                                                        style: TextStyle(
                                                          color: Color(0xFF06B6D4),
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                      ),
                                                    ],
                                                  ],
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
        ],
      ),
    );
  }

  // 선택된 수신자 목록 섹션
  Widget _buildSelectedMembersSection(StateSetter setDialogState) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12.0),
                topRight: Radius.circular(12.0),
              ),
              border: Border(
                bottom: BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.inbox,
                  color: Color(0xFF64748B),
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  '선택된 수신자',
                  style: TextStyle(
                    color: Color(0xFF1E293B),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Color(0xFF06B6D4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_selectedMembers.length}명',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (_selectedMembers.isNotEmpty) ...[
                  SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: () {
                          setDialogState(() {
                            _selectedMembers.clear();
                          });
                        },
                        child: Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(
                            Icons.clear_all,
                            color: Color(0xFF64748B),
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // 선택된 회원 목록
          Expanded(
            child: Container(
              padding: EdgeInsets.all(16),
              child: _selectedMembers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person_add,
                            color: Color(0xFF94A3B8),
                            size: 48,
                          ),
                          SizedBox(height: 12),
                          Text(
                            '수신자를 선택해주세요',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _selectedMembers.length,
                      itemBuilder: (context, index) {
                        final member = _selectedMembers[index];
                        return Container(
                          margin: EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Color(0xFFF0F9FF),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Color(0xFF06B6D4)),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: Color(0xFF06B6D4),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Icon(
                                    Icons.person,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            member['member_name'] ?? '',
                                            style: TextStyle(
                                              color: Color(0xFF1E293B),
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          SizedBox(width: 6),
                                          Text(
                                            '#${member['member_id']}',
                                            style: TextStyle(
                                              color: Color(0xFF64748B),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        member['member_phone'] ?? '',
                                        style: TextStyle(
                                          color: Color(0xFF64748B),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(6),
                                      onTap: () {
                                        setDialogState(() {
                                          _selectedMembers.removeAt(index);
                                        });
                                      },
                                      child: Padding(
                                        padding: EdgeInsets.all(6),
                                        child: Icon(
                                          Icons.close,
                                          color: Color(0xFF64748B),
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // 1:1채팅 메시지 작성 섹션
  Widget _buildMessageComposingSection(StateSetter setDialogState) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12.0),
                topRight: Radius.circular(12.0),
              ),
              border: Border(
                bottom: BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.edit,
                  color: Color(0xFF64748B),
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  '1:1채팅 메시지 작성',
                  style: TextStyle(
                    color: Color(0xFF1E293B),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '일반안내',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // 메시지 입력 영역
          Expanded(
            child: Container(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1:1채팅 메시지 내용 입력
                  Expanded(
                    child: TextFormField(
                      controller: _messageController,
                      maxLines: null,
                      expands: true,
                      decoration: InputDecoration(
                        hintText: '1:1채팅 메시지 내용을 입력해주세요...',
                        hintStyle: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 14,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Color(0xFFE2E8F0),
                            width: 1.0,
                          ),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Color(0xFF06B6D4),
                            width: 2.0,
                          ),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: EdgeInsets.all(12),
                      ),
                      style: TextStyle(
                        color: Color(0xFF1E293B),
                        fontSize: 14,
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 16),
                  
                  // 발송 옵션
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '발송 옵션',
                        style: TextStyle(
                          color: Color(0xFF1E293B),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 12),
                      
                      // 즉시/예약 발송 라디오 버튼
                      Row(
                        children: [
                          Radio<bool>(
                            value: false,
                            groupValue: _isScheduled,
                            onChanged: (value) {
                              setDialogState(() {
                                _isScheduled = value!;
                              });
                            },
                            activeColor: Color(0xFF06B6D4),
                          ),
                          Text(
                            '즉시 발송',
                            style: TextStyle(
                              color: Color(0xFF1E293B),
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(width: 24),
                          Radio<bool>(
                            value: true,
                            groupValue: _isScheduled,
                            onChanged: (value) {
                              setDialogState(() {
                                _isScheduled = value!;
                              });
                            },
                            activeColor: Color(0xFF06B6D4),
                          ),
                          Text(
                            '예약 발송',
                            style: TextStyle(
                              color: Color(0xFF1E293B),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      
                      // 예약 시간 선택
                      if (_isScheduled) ...[
                        SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8.0),
                              border: Border.all(color: Color(0xFFE2E8F0)),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8.0),
                                onTap: () => _selectDateTime(setDialogState),
                                child: Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.schedule,
                                        color: Color(0xFF64748B),
                                        size: 20,
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _scheduledDate != null && _scheduledTime != null
                                              ? '${_scheduledDate!.year}-${_scheduledDate!.month.toString().padLeft(2, '0')}-${_scheduledDate!.day.toString().padLeft(2, '0')} ${_scheduledTime!.format(context)}'
                                              : '날짜와 시간을 선택해주세요',
                                          style: TextStyle(
                                            color: _scheduledDate != null && _scheduledTime != null
                                                ? Color(0xFF1E293B)
                                                : Color(0xFF94A3B8),
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      Icon(
                                        Icons.arrow_forward_ios,
                                        color: Color(0xFF94A3B8),
                                        size: 16,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  // 발송 확인 다이얼로그
  Future<void> _showSendConfirmDialog(StateSetter setDialogState) async {
    final now = DateTime.now();
    String sendTimeText = '';
    
    if (_isScheduled) {
      final scheduledDateTime = DateTime(
        _scheduledDate!.year,
        _scheduledDate!.month,
        _scheduledDate!.day,
        _scheduledTime!.hour,
        _scheduledTime!.minute,
      );
      sendTimeText = '${_scheduledDate!.year}-${_scheduledDate!.month.toString().padLeft(2, '0')}-${_scheduledDate!.day.toString().padLeft(2, '0')} ${_scheduledTime!.format(context)}';
    } else {
      sendTimeText = '즉시 발송 (${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')})';
    }
    
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.6,
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.0),
            boxShadow: [
              BoxShadow(
                blurRadius: 8.0,
                color: Color(0x1A000000),
                offset: Offset(0.0, 2.0),
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 헤더 섹션 - 게시판 스타일
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
                    children: [
                      Container(
                        width: 40.0,
                        height: 40.0,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _isScheduled 
                                ? [Color(0xFFF59E0B), Color(0xFFD97706)]
                                : [Color(0xFF06B6D4), Color(0xFF0891B2)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                        child: Icon(
                          _isScheduled ? Icons.schedule : Icons.send,
                          color: Colors.white,
                          size: 20.0,
                        ),
                      ),
                      SizedBox(width: 12.0),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '1:1채팅 일괄발송 확인',
                              style: TextStyle(
                                color: Color(0xFF1E293B),
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '발송 전에 내용을 다시 한번 확인해주세요',
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // 구분선
              Container(
                width: double.infinity,
                height: 1.0,
                color: Color(0xFFE2E8F0),
              ),
              
              // 메인 콘텐츠
              Flexible(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Color(0xFFF8FAFC),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 발송 시점 정보 카드
                          _buildConfirmInfoCard('발송 시점', sendTimeText, Icons.access_time),
                          SizedBox(height: 24),
                          
                          // 수신자 목록
                          _buildRecipientsList(),
                          SizedBox(height: 24),
                          
                          // 1:1채팅 메시지 내용
                          _buildMessagePreview(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              
              // 하단 버튼
              Container(
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // 취소 버튼
                    Container(
                      height: 44.0,
                      decoration: BoxDecoration(
                        color: Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(color: Color(0xFFE2E8F0)),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8.0),
                          onTap: () => Navigator.of(context).pop(false),
                          child: Container(
                            width: 80.0,
                            height: 44.0,
                            child: Center(
                              child: Text(
                                '취소',
                                style: TextStyle(
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    SizedBox(width: 12),
                    
                    // 확인 버튼
                    Container(
                      height: 44.0,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _isScheduled 
                              ? [Color(0xFFF59E0B), Color(0xFFD97706)]
                              : [Color(0xFF06B6D4), Color(0xFF0891B2)],
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
                          onTap: () => Navigator.of(context).pop(true),
                          child: Container(
                            width: 120.0,
                            height: 44.0,
                            child: Center(
                              child: Text(
                                _isScheduled ? '예약 등록' : '발송 확인',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
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
      ),
    );
    
    if (confirmed == true) {
      await _sendMessage(setDialogState);
    }
  }

  // 확인 다이얼로그 정보 카드
  Widget _buildConfirmInfoCard(String label, String value, IconData icon) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Color(0xFFF0F9FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: Color(0xFF06B6D4),
              size: 20,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: Color(0xFF1E293B),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 수신자 목록 표시
  Widget _buildRecipientsList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border(
                bottom: BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.people,
                  color: Color(0xFF64748B),
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  '수신자 목록',
                  style: TextStyle(
                    color: Color(0xFF1E293B),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Color(0xFF06B6D4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_selectedMembers.length}명',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.all(16),
            constraints: BoxConstraints(maxHeight: 160),
            child: SingleChildScrollView(
              child: Column(
                children: _selectedMembers.map((member) {
                  return Container(
                    margin: EdgeInsets.only(bottom: 8),
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Color(0xFF06B6D4),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    member['member_name'] ?? '',
                                    style: TextStyle(
                                      color: Color(0xFF1E293B),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    '#${member['member_id']}',
                                    style: TextStyle(
                                      color: Color(0xFF64748B),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 2),
                              Text(
                                member['member_phone'] ?? '',
                                style: TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 메시지 미리보기
  Widget _buildMessagePreview() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border(
                bottom: BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.message,
                  color: Color(0xFF64748B),
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  '1:1채팅 메시지 내용',
                  style: TextStyle(
                    color: Color(0xFF1E293B),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.all(16),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Color(0xFFE2E8F0)),
              ),
              child: Text(
                _messageController.text.isEmpty ? '1:1채팅 메시지 내용이 없습니다.' : _messageController.text,
                style: TextStyle(
                  color: _messageController.text.isEmpty ? Color(0xFF94A3B8) : Color(0xFF1E293B),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  

  // 1:1채팅 일괄발송 전 검증 및 확인
  Future<void> _handleSendMessage(StateSetter setDialogState) async {
    // 1. 수신자 선택 검증
    if (_selectedMembers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('수신자를 선택해주세요'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // 2. 1:1채팅 메시지 내용 검증
    if (_messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('1:1채팅 메시지 내용을 입력해주세요'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // 3. 예약 발송 날짜/시간 검증
    if (_isScheduled && (_scheduledDate == null || _scheduledTime == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('예약 발송을 위해 날짜와 시간을 선택해주세요'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // 4. 확인 다이얼로그 표시
    await _showSendConfirmDialog(setDialogState);
  }

  // 발송 확인 다이얼로그 (이미 완성된 함수가 위에 있음)

  // 1:1채팅 일괄발송
  Future<void> _sendMessage(StateSetter setDialogState) async {
    print('=== 1:1채팅 일괄발송 시작 ===');
    print('선택된 멤버 수: ${_selectedMembers.length}');
    print('1:1채팅 메시지 내용: ${_messageController.text}');
    
    try {
      final branchId = ApiService.getCurrentBranchId() ?? 'test';
      final now = DateTime.now();
      print('Branch ID: $branchId');
      print('예약 발송 여부: $_isScheduled');
      
      for (int i = 0; i < _selectedMembers.length; i++) {
        final member = _selectedMembers[i];
        print('--- 멤버 ${i + 1}/${_selectedMembers.length} 처리 시작 ---');
        print('멤버 정보: ${member['member_name']} (ID: ${member['member_id']})');
        
        // push_agreement 확인
        print('Push agreement 확인 시작...');
        final agreementData = await SupabaseAdapter.getData(
          table: 'v2_message_agreement',
          fields: ['push_agreement'],
          where: [
            {'field': 'branch_id', 'operator': '=', 'value': branchId},
            {'field': 'member_id', 'operator': '=', 'value': member['member_id']},
            {'field': 'msg_type', 'operator': '=', 'value': _selectedMsgType},
          ],
        );

        String pushAgreement = '미확인'; // 기본값
        if (agreementData.isNotEmpty) {
          pushAgreement = agreementData[0]['push_agreement'] ?? '미확인';
        }
        print('Push Agreement: $pushAgreement');
        
        // 1:1채팅 메시지 등록 데이터 준비
        String msgDate = '';
        String? msgPlantime;
        String? msgSentAt;
        String msgStatus = '발송대기';
        
        if (_isScheduled) {
          final scheduledDateTime = DateTime(
            _scheduledDate!.year,
            _scheduledDate!.month,
            _scheduledDate!.day,
            _scheduledTime!.hour,
            _scheduledTime!.minute,
          );
          msgDate = '${_scheduledDate!.year}-${_scheduledDate!.month.toString().padLeft(2, '0')}-${_scheduledDate!.day.toString().padLeft(2, '0')}';
          msgPlantime = '${_scheduledTime!.hour.toString().padLeft(2, '0')}:${_scheduledTime!.minute.toString().padLeft(2, '0')}';
          msgSentAt = null; // 예약 발송일 때는 null
        } else {
          msgDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
          msgPlantime = null; // 즉시 발송일 때는 null
          msgSentAt = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
          msgStatus = '발송완료';
        }
        
        // 기존 API 서비스와 동일한 패턴 사용
        await SupabaseAdapter.addData(
          table: 'v2_message',
          data: {
            'branch_id': branchId,
            'msg_type': _selectedMsgType,
            'member_id': member['member_id'],
            'member_name': member['member_name'],
            'member_phone': member['member_phone'],
            'msg': _messageController.text,
            'msg_status': msgStatus,
            'msg_date': msgDate,
            'msg_plantime': msgPlantime,
            'msg_sent_at': msgSentAt,
            'push_agreement': pushAgreement,
            'msg_registered_at': '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}',
            'sent_by': ApiService.getCurrentBranch()?['branch_name'] ?? '',
          },
        );

        print('멤버 ${member['member_name']} 1:1채팅 메시지 등록 성공!');

        // Firebase 1:1 채팅으로도 메시지 전송 (즉시 발송인 경우에만)
        if (!_isScheduled) {
          try {
            print('🔥 Firebase 채팅 메시지 전송 시작...');

            // 채팅방 생성 또는 가져오기
            final chatRoom = await ChatService.getOrCreateChatRoom(
              member['member_id'].toString(),
              member['member_name'] ?? '고객',
              member['member_phone'] ?? '',
              member['member_type'] ?? '일반',
            );

            print('📬 채팅방 ID: ${chatRoom.id}');

            // 메시지 타입에 따라 1:1채팅 메시지 내용 포맷팅
            String formattedMessage = _messageController.text;
            if (_selectedMsgType != '일반안내') {
              formattedMessage = '[$_selectedMsgType]\n${_messageController.text}';
            }

            // 메시지 전송
            await ChatService.sendMessage(
              chatRoom.id,
              member['member_id'].toString(),
              formattedMessage,
            );

            print('✅ Firebase 채팅 메시지 전송 성공! 타입: $_selectedMsgType');
          } catch (e) {
            print('❌ Firebase 채팅 메시지 전송 실패: $e');
            // Firebase 전송 실패는 무시하고 계속 진행 (기존 API는 성공했으므로)
          }
        }
        
        print('--- 멤버 ${i + 1}/${_selectedMembers.length} 처리 완료 ---');
      }
      
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('1:1채팅 메시지가 ${_isScheduled ? '예약 등록' : '일괄발송'}되었습니다')),
      );
      _loadMessageData(); // 목록 새로고침
      
    } catch (e, stackTrace) {
      print('1:1채팅 일괄발송 예외 발생: $e');
      print('Stack Trace: $stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('1:1채팅 일괄발송 실패: $e')),
      );
    }
    
    print('=== 1:1첄팅 일괄발송 완료 ===');
  }

  // 회원 검색 함수
  void _searchMembers(String keyword, StateSetter setDialogState) {
    _searchTimer?.cancel();
    _searchTimer = Timer(Duration(milliseconds: 300), () {
      _loadMembers(keyword, setDialogState);
    });
  }

  // 날짜/시간 선택 함수
  Future<void> _selectDateTime(StateSetter setDialogState) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _scheduledDate ?? DateTime.now().add(Duration(hours: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365)),
    );
    
    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: _scheduledTime ?? TimeOfDay.now(),
      );
      
      if (pickedTime != null) {
        setDialogState(() {
          _scheduledDate = pickedDate;
          _scheduledTime = pickedTime;
        });
      }
    }
  }
}
