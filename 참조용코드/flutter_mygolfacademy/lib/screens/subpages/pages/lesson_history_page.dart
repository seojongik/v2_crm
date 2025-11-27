import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:famd_clientapp/models/lesson_feedback.dart';
import 'package:famd_clientapp/services/api_service.dart';
import 'package:provider/provider.dart';
import 'package:famd_clientapp/providers/user_provider.dart';

class LessonHistoryPage extends StatefulWidget {
  const LessonHistoryPage({Key? key}) : super(key: key);

  @override
  State<LessonHistoryPage> createState() => _LessonHistoryPageState();
}

class _LessonHistoryPageState extends State<LessonHistoryPage> {
  List<LessonFeedback> _lessonFeedbacks = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLessonData();
  }

  // 레슨 데이터 로드
  Future<void> _loadLessonData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (kDebugMode) {
        print('레슨 피드백 데이터 로드 시작');
      }
      
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      
      // 사용자가 로그인되어 있는지 확인
      if (userProvider.user == null) {
        if (kDebugMode) {
          print('로그인되지 않은 상태: 로그인 필요 예외 발생');
        }
        throw Exception('로그인이 필요합니다.');
      }

      if (kDebugMode) {
        print('로그인된 사용자 정보: ID=${userProvider.user!.id}, 이름=${userProvider.user!.name}');
      }

      // 피드백 데이터 가져오기
      final lessonFeedbacks = await ApiService.getLessonFeedbacks(
        userProvider.user!.id,
        branchId: userProvider.currentBranchId,
      );
      
      if (kDebugMode) {
        print('레슨 피드백 API 호출 완료 - 조회된 레코드 수: ${lessonFeedbacks.length}');
        if (lessonFeedbacks.isNotEmpty) {
          print('첫 번째 레코드 샘플: lsId=${lessonFeedbacks.first.lsId}, 프로=${lessonFeedbacks.first.staffName}');
        }
      }
      
      setState(() {
        _lessonFeedbacks = lessonFeedbacks;
        _isLoading = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print('레슨 데이터 로드 오류: $e');
      }

      setState(() {
        _error = '데이터를 불러오는 중 오류가 발생했습니다: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('레슨피드백'),
        actions: [
          // 새로고침 버튼
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLessonData,
            tooltip: '새로고침',
          ),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorView()
              : _buildFeedbackList(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 60,
            color: Colors.red.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            '데이터를 불러올 수 없습니다',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _error ?? '알 수 없는 오류가 발생했습니다.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadLessonData,
            icon: const Icon(Icons.refresh),
            label: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFeedbackList() {
    if (_lessonFeedbacks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.feedback_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              '레슨 피드백이 없습니다',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      );
    }
    
    // 날짜별로 그룹화하기 위한 맵 생성
    Map<String, List<LessonFeedback>> groupedFeedbacks = {};
    
    for (var feedback in _lessonFeedbacks) {
      // 날짜를 yyyy-MM-dd 형식의 문자열로 변환하여 키로 사용
      String dateKey = DateFormat('yyyy-MM-dd').format(feedback.lsDate);
      
      if (!groupedFeedbacks.containsKey(dateKey)) {
        groupedFeedbacks[dateKey] = [];
      }
      
      groupedFeedbacks[dateKey]!.add(feedback);
    }
    
    // 날짜 키 목록을 역순으로 정렬 (최신순)
    List<String> sortedDates = groupedFeedbacks.keys.toList()
      ..sort((a, b) => b.compareTo(a));
    
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: sortedDates.length,
      itemBuilder: (context, index) {
        String dateKey = sortedDates[index];
        List<LessonFeedback> dayFeedbacks = groupedFeedbacks[dateKey]!;
        
        // 날짜 표시 포맷 변경 (yyyy-MM-dd -> yyyy년 MM월 dd일)
        DateTime date = DateTime.parse(dateKey);
        String formattedDate = DateFormat('yyyy년 MM월 dd일').format(date);
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 8, left: 8),
              child: Text(
                formattedDate,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
            ...dayFeedbacks.map((feedback) => _buildFeedbackItem(feedback)).toList(),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }
  
  Widget _buildFeedbackItem(LessonFeedback feedback) {
    // 시간 형식화
    String timeRange = '${feedback.lsStartTime.substring(0, 5)} ~ ${feedback.lsEndTime.substring(0, 5)}';
    
    // 피드백 파싱
    List<String> feedbackParts = feedback.parseFeedback();
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더 (시간, 프로)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      timeRange,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${feedback.staffName} 프로',  // lsConfirmedBy 대신 staffName 사용
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
            
            // 피드백이 있는 경우에만 표시
            if (feedback.hasFeedback()) ...[
              const Divider(height: 16),
              ...feedbackParts.map((part) {
                final List<String> keyValue = part.split(':');
                final String key = keyValue[0].trim();
                final String value = keyValue.length > 1 ? keyValue[1].trim() : '';
                
                // 피드백 섹션 키에 따른 아이콘 지정
                IconData sectionIcon;
                Color iconColor;
                
                if (key.contains('피드백')) {
                  sectionIcon = Icons.star;
                  iconColor = Colors.amber;
                } else if (key.contains('숙제')) {
                  sectionIcon = Icons.assignment;
                  iconColor = Colors.blue;
                } else if (key.contains('다음레슨')) {
                  sectionIcon = Icons.next_plan;
                  iconColor = Colors.green;
                } else {
                  sectionIcon = Icons.message;
                  iconColor = Colors.grey;
                }
                
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    sectionIcon,
                    color: iconColor,
                    size: 20,
                  ),
                  title: Text(
                    key,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 14,
                    ),
                  ),
                  dense: true,
                );
              }).toList(),
            ] else ...[
              const Divider(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.info_outline,
                  color: Colors.grey.shade400,
                  size: 20,
                ),
                title: Text(
                  '피드백 없음',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
                subtitle: Text(
                  feedback.lsFeedbackBypro.replaceAll('피드백제외 : ', ''),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                dense: true,
              ),
            ],
          ],
        ),
      ),
    );
  }
} 