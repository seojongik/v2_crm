import 'package:flutter/material.dart';
import 'package:famd_clientapp/models/notice.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class NoticeProvider extends ChangeNotifier {
  List<Notice> _notices = [];
  bool _isLoading = false;
  
  List<Notice> get notices => _notices;
  bool get isLoading => _isLoading;
  
  // 공지사항 로드 메서드
  Future<void> loadNotices() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      // Board 테이블에서 회원공지 데이터 가져오기
      final response = await http.post(
        Uri.parse('https://autofms.mycafe24.com/dynamic_api.php'),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'FlutterApp/1.0'
        },
        body: jsonEncode({
          'operation': 'get',
          'table': 'Board',
          'fields': ['board_id', 'title', 'content', 'created_at', 'staff_id'],
          'where': [
            {
              'field': 'board_type',
              'operator': '=',
              'value': '회원공지'
            }
          ],
          'orderBy': [
            {
              'field': 'created_at',
              'direction': 'DESC'
            }
          ],
          'limit': 20
        }),
      );
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        if (responseData['success'] == true && responseData['data'] != null) {
          final List<dynamic> boardData = responseData['data'];
          
          _notices = boardData.map((item) {
            return Notice.fromBoard(Map<String, dynamic>.from(item));
          }).toList();
        } else {
          _notices = [];
        }
      } else {
        throw Exception('공지사항 로드 실패: ${response.statusCode}');
      }
    } catch (e) {
      print('공지사항 로드 중 오류: $e');
      _notices = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // 공지사항 상세 조회 메서드
  Notice? getNoticeById(int id) {
    try {
      return _notices.firstWhere((notice) => notice.id == id);
    } catch (e) {
      return null;
    }
  }
} 