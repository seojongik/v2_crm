class Notice {
  final int id;
  final String title;
  final String content;
  final DateTime date;
  final bool isImportant;

  Notice({
    required this.id,
    required this.title,
    required this.content,
    required this.date,
    this.isImportant = false,
  });

  // JSON에서 Notice 객체로 변환
  factory Notice.fromJson(Map<String, dynamic> json) {
    return Notice(
      id: json['id'],
      title: json['title'],
      content: json['content'],
      date: DateTime.parse(json['date']),
      isImportant: json['isImportant'] ?? false,
    );
  }

  // Board 테이블 데이터에서 Notice 객체로 변환
  factory Notice.fromBoard(Map<String, dynamic> boardData) {
    // content에서 ¶ 문자를 줄바꿈으로 변환
    String formattedContent = boardData['content']?.toString().replaceAll('¶', '\n') ?? '';
    
    // 날짜 파싱
    DateTime noticeDate;
    try {
      noticeDate = DateTime.parse(boardData['created_at']);
    } catch (e) {
      noticeDate = DateTime.now();
    }
    
    // 중요 공지 판단 (staff_id가 1인 경우 또는 특정 키워드가 포함된 경우)
    bool isImportant = boardData['staff_id'] == 1 || 
                      boardData['title']?.toString().contains('중요') == true ||
                      boardData['title']?.toString().contains('긴급') == true;
    
    return Notice(
      id: boardData['board_id'] ?? 0,
      title: boardData['title'] ?? '',
      content: formattedContent,
      date: noticeDate,
      isImportant: isImportant,
    );
  }

  // Notice 객체를 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'date': date.toIso8601String(),
      'isImportant': isImportant,
    };
  }
} 