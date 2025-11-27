import 'package:flutter/material.dart';
import '../../services/lesson_api_service.dart';
import '../../services/api_service.dart';

class LessonFeedbackDialog extends StatefulWidget {
  final Map<String, dynamic> lesson;
  final Function? onSaved;

  const LessonFeedbackDialog({
    super.key,
    required this.lesson,
    this.onSaved,
  });

  @override
  State<LessonFeedbackDialog> createState() => _LessonFeedbackDialogState();
}

class _LessonFeedbackDialogState extends State<LessonFeedbackDialog> {
  String selectedStatus = '';
  final TextEditingController goodController = TextEditingController();
  final TextEditingController homeworkController = TextEditingController();
  final TextEditingController nextLessonController = TextEditingController();
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    // 기존 데이터 로드
    selectedStatus = widget.lesson['LS_confirm'] ?? '';
    goodController.text = widget.lesson['LS_feedback_good'] ?? '';
    homeworkController.text = widget.lesson['LS_feedback_homework'] ?? '';
    nextLessonController.text = widget.lesson['LS_feedback_nextlesson'] ?? '';
  }

  @override
  void dispose() {
    goodController.dispose();
    homeworkController.dispose();
    nextLessonController.dispose();
    super.dispose();
  }
  
  // 피드백 입력 불가능한 상태인지 확인
  bool get _isFeedbackDisabled {
    return selectedStatus != '일반레슨';
  }
  
  // 안내 메시지 텍스트
  String _getInfoMessage() {
    switch (selectedStatus) {
      case '예약취소(환불)':
        return '레슨이 환불처리 되었습니다.';
      case '노쇼':
        return '노쇼처리 되었습니다(레슨시간 차감)';
      case '고객증정레슨':
        return '고객 서비스로 무료제공되는 레슨입니다.';
      case '신규체험레슨':
        return '신규고객 대상 체험레슨입니다.';
      case '일반레슨':
        return '피드백 입력시 고객에 전달됩니다.';
      default:
        return '';
    }
  }
  
  // 안내 메시지 배경색
  Color _getInfoMessageBgColor() {
    switch (selectedStatus) {
      case '예약취소(환불)':
        return Color(0xFFFEF2F2);
      case '노쇼':
        return Color(0xFFFEF3C7);
      case '고객증정레슨':
      case '신규체험레슨':
        return Color(0xFFF3F4F6);
      case '일반레슨':
        return Color(0xFFF0F9FF);
      default:
        return Color(0xFFF0F9FF);
    }
  }
  
  // 안내 메시지 테두리색
  Color _getInfoMessageBorderColor() {
    switch (selectedStatus) {
      case '예약취소(환불)':
        return Color(0xFFEF4444);
      case '노쇼':
        return Color(0xFFF59E0B);
      case '고객증정레슨':
      case '신규체험레슨':
        return Color(0xFF6B7280);
      case '일반레슨':
        return Color(0xFF0EA5E9);
      default:
        return Color(0xFF0EA5E9);
    }
  }
  
  // 안내 메시지 아이콘
  IconData _getInfoMessageIcon() {
    switch (selectedStatus) {
      case '예약취소(환불)':
        return Icons.cancel_outlined;
      case '노쇼':
        return Icons.warning_outlined;
      case '고객증정레슨':
      case '신규체험레슨':
        return Icons.money_off_outlined;
      case '일반레슨':
        return Icons.info_outline;
      default:
        return Icons.info_outline;
    }
  }

  Future<void> _saveFeedback() async {
    if (selectedStatus.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('레슨 상태를 선택해주세요.')),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final currentBranchId = ApiService.getCurrentBranchId();
      if (currentBranchId == null) {
        throw Exception('Branch ID를 찾을 수 없습니다.');
      }

      final success = await LessonApiService.updateLessonFeedback(
        branchId: currentBranchId,
        lessonId: widget.lesson['LS_id'],
        confirm: selectedStatus,
        feedbackGood: _isFeedbackDisabled ? '' : goodController.text,
        feedbackHomework: _isFeedbackDisabled ? '' : homeworkController.text,
        feedbackNextLesson: _isFeedbackDisabled ? '' : nextLessonController.text,
      );

      if (success) {
        // 예약취소(환불)인 경우 추가 환불 처리
        if (selectedStatus == '예약취소(환불)') {
          final refundSuccess = await LessonApiService.processLessonRefund(
            branchId: currentBranchId,
            lessonId: widget.lesson['LS_id'],
          );
          
          if (!refundSuccess) {
            throw Exception('환불 처리에 실패했습니다.');
          }
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('피드백이 저장되었습니다.')),
        );
        widget.onSaved?.call();
        Navigator.of(context).pop();
      } else {
        throw Exception('저장에 실패했습니다.');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류가 발생했습니다: $e')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: 600,
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Color(0xFF14B8A6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.feedback,
                    color: Color(0xFF14B8A6),
                    size: 20,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '레슨 상태',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      Text(
                        '${widget.lesson['member_name']} · ${widget.lesson['LS_start_time']?.substring(0, 5)}~${widget.lesson['LS_end_time']?.substring(0, 5)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close, color: Color(0xFF6B7280)),
                ),
              ],
            ),
            
            SizedBox(height: 24),
            
            SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 레슨진행 섹션
                Text(
                  '레슨진행',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151),
                  ),
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    _buildStatusButton(
                      '일반레슨', 
                      Color(0xFF10B981),
                      disabled: widget.lesson['LS_confirm'] == '예약취소(환불)' || widget.lesson['LS_confirm'] == '환불',
                    ),
                    SizedBox(width: 8),
                    _buildStatusButton(
                      '고객증정레슨', 
                      Color(0xFF8B5CF6),
                      disabled: widget.lesson['LS_confirm'] == '예약취소(환불)' || widget.lesson['LS_confirm'] == '환불',
                    ),
                    SizedBox(width: 8),
                    _buildStatusButton(
                      '신규체험레슨', 
                      Color(0xFF06B6D4),
                      disabled: widget.lesson['LS_confirm'] == '예약취소(환불)' || widget.lesson['LS_confirm'] == '환불',
                    ),
                  ],
                ),
                
                SizedBox(height: 16),
                
                // 레슨미진행 섹션
                Text(
                  '레슨미진행',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151),
                  ),
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    _buildStatusButton(
                      '노쇼', 
                      Color(0xFFF59E0B),
                      disabled: widget.lesson['LS_confirm'] == '예약취소(환불)' || widget.lesson['LS_confirm'] == '환불',
                    ),
                    SizedBox(width: 8),
                    _buildStatusButton('예약취소(환불)', Color(0xFFEF4444)),
                  ],
                ),
              ],
            ),
            
            SizedBox(height: 24),
            
            // 안내 메시지 (상태가 선택된 경우에만 표시)
            if (_getInfoMessage().isNotEmpty) ...[
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getInfoMessageBgColor(),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _getInfoMessageBorderColor().withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(_getInfoMessageIcon(), color: _getInfoMessageBorderColor(), size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _getInfoMessage(),
                        style: TextStyle(
                          fontSize: 14,
                          color: _getInfoMessageBorderColor(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
            ],
            
            // 피드백 입력 섹션 (레슨완료일 때만 표시)
            if (!_isFeedbackDisabled) ...[
              // 잘하고 있는 점
              _buildTextFieldSection(
                '잘하고 있는 점',
                goodController,
                '회원이 잘하고 있는 점을 입력해주세요',
              ),
              
              SizedBox(height: 16),
              
              // 숙제
              _buildTextFieldSection(
                '숙제',
                homeworkController,
                '다음 레슨까지의 연습 과제를 입력해주세요',
              ),
              
              SizedBox(height: 16),
              
              // 다음 레슨 주안점
              _buildTextFieldSection(
                '다음 레슨 주안점',
                nextLessonController,
                '다음 레슨에서 중점적으로 다룰 내용을 입력해주세요',
              ),
            ],
            
            SizedBox(height: 24),
            
            // 버튼
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: isLoading ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: Color(0xFFE5E7EB)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      '취소',
                      style: TextStyle(
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _saveFeedback,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF14B8A6),
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: isLoading
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            '저장',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusButton(String status, Color color, {bool disabled = false}) {
    final isSelected = selectedStatus == status;
    return Expanded(
      child: GestureDetector(
        onTap: disabled ? null : () async {
          if (status == '예약취소(환불)') {
            // 예약취소(환불) 확인 다이얼로그
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  backgroundColor: Color(0xFFF8F9FA),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  title: Row(
                    children: [
                      Icon(Icons.warning, color: Color(0xFFEF4444), size: 24),
                      SizedBox(width: 8),
                      Text(
                        '예약취소(환불)',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                    ],
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '레슨시간이 회원에게 반환됩니다.',
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF374151),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '환불은 취소할 수 없습니다.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFFEF4444),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text(
                        '취소',
                        style: TextStyle(
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFEF4444),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        '확인',
                        style: TextStyle(
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
              setState(() {
                selectedStatus = status;
                // 일반레슨이 아닌 경우 피드백 필드 클리어
                if (status != '일반레슨') {
                  goodController.clear();
                  homeworkController.clear();
                  nextLessonController.clear();
                }
              });
            }
          } else {
            setState(() {
              selectedStatus = status;
              // 일반레슨이 아닌 경우 피드백 필드 클리어
              if (status != '일반레슨') {
                goodController.clear();
                homeworkController.clear();
                nextLessonController.clear();
              }
            });
          }
        },
        child: Opacity(
          opacity: disabled ? 0.4 : 1.0,
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: disabled 
                ? Color(0xFFF3F4F6) 
                : (isSelected ? color : Colors.white),
              border: Border.all(
                color: disabled ? Color(0xFFD1D5DB) : color,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: disabled 
                  ? Color(0xFF9CA3AF)
                  : (isSelected ? Colors.white : color),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextFieldSection(String title, TextEditingController controller, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1F2937),
          ),
        ),
        SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: 3,
          style: TextStyle(
            color: Colors.black,
            fontSize: 14,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Color(0xFFD1D5DB), width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Color(0xFF14B8A6), width: 2),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Color(0xFFD1D5DB), width: 1),
            ),
            contentPadding: EdgeInsets.all(12),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
      ],
    );
  }
}