import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _token;
  User? _user;

  // 게터
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get token => _token;
  User? get user => _user;

  // 자동 로그인 시도
  Future<void> tryAutoLogin() async {
    _setLoading(true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final authDataString = prefs.getString('authData');
      
      if (authDataString == null) return;
      
      final authData = jsonDecode(authDataString);
      final token = authData['token'];
      final userId = authData['userId'];

      if (token != null && userId != null) {
        final user = await ApiService.getUserProfile(userId);
        if (user != null) {
          // Map<String, dynamic>을 User 객체로 변환
          _user = User(
            id: user['member_id'].toString(),
            name: user['member_name'] ?? '',
            phone: user['member_phone'] ?? '',
            email: user['member_email'] ?? '',
            profileImage: user['member_profile_image'],
          );
          _token = token;
          _isAuthenticated = true;
          notifyListeners();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('자동 로그인 오류: $e');
      }
    } finally {
      _setLoading(false);
    }
  }

  // 로그인
  Future<bool> login(String phone, String password) async {
    _setLoading(true);
    try {
      // 전화번호 형식 변환 (하이픈이 없는 경우 추가)
      final formattedPhone = formatPhoneNumber(phone);
      
      // 로그인 시도 - ApiService 사용
      final user = await ApiService.login(phone: formattedPhone, password: password);
      
      if (user != null) {
        // 임시 토큰 생성 (실제로는 서버에서 받아야 함)
        final token = base64Encode(utf8.encode('${user.id}:${DateTime.now().millisecondsSinceEpoch}'));
        
        // 인증 정보 저장
        _token = token;
        _user = user;
        _isAuthenticated = true;
        
        // 로컬 스토리지에 저장
        await _saveAuthData(token, user.id);
        
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('로그인 오류: $e');
      }
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // 전화번호 형식 변환
  String formatPhoneNumber(String phone) {
    // 하이픈 제거
    final digitsOnly = phone.replaceAll('-', '');
    
    // 11자리 전화번호인 경우 (01012345678)
    if (digitsOnly.length == 11) {
      return '${digitsOnly.substring(0, 3)}-${digitsOnly.substring(3, 7)}-${digitsOnly.substring(7)}';
    }
    // 10자리 전화번호인 경우 (0101234567)
    else if (digitsOnly.length == 10) {
      return '${digitsOnly.substring(0, 3)}-${digitsOnly.substring(3, 6)}-${digitsOnly.substring(6)}';
    }
    
    // 형식이 맞지 않으면 원본 반환
    return phone;
  }

  // 전화번호 중복 체크
  Future<bool> checkPhoneExists(String phone) async {
    _setLoading(true);
    try {
      final formattedPhone = formatPhoneNumber(phone);
      return await ApiService.checkPhoneExists(formattedPhone);
    } catch (e) {
      if (kDebugMode) {
        print('전화번호 확인 오류: $e');
      }
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // 회원가입
  Future<bool> registerUser({
    required String name,
    required String phone,
    required String password,
    String? gender,
    String? address,
    String? birthday,
  }) async {
    _setLoading(true);
    try {
      // 전화번호 형식 변환
      final formattedPhone = formatPhoneNumber(phone);
      
      // 전화번호 중복 확인
      final isPhoneExists = await checkPhoneExists(formattedPhone);
      if (isPhoneExists) {
        return false;
      }
      
      // 회원가입 시도 - ApiService 사용
      final user = await ApiService.registerUser(
        name: name,
        phone: formattedPhone,
        password: password,
        gender: gender,
        address: address,
        birthday: birthday,
        userType: 'member', // 기본값으로 'member' 설정
        branchId: 'test', // 기본 branch_id 추가 (필요시 동적으로 변경)
      );
      
      // 임시 토큰 생성
      final token = base64Encode(utf8.encode('${user.id}:${DateTime.now().millisecondsSinceEpoch}'));
      
      // 인증 정보 저장
      _token = token;
      _user = user;
      _isAuthenticated = true;
      
      // 로컬 스토리지에 저장
      await _saveAuthData(token, user.id);
      
      notifyListeners();
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('회원가입 오류: $e');
      }
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // 로그아웃
  Future<void> logout() async {
    _setLoading(true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('authData');
      
      _token = null;
      _user = null;
      _isAuthenticated = false;
      
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('로그아웃 오류: $e');
      }
    } finally {
      _setLoading(false);
    }
  }

  // 인증 데이터 저장
  Future<void> _saveAuthData(String token, String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final authData = jsonEncode({
      'token': token,
      'userId': userId,
    });
    await prefs.setString('authData', authData);
  }

  // 로딩 상태 설정
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
} 