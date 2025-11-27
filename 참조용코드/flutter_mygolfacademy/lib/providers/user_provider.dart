import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/api_service.dart';

class UserProvider with ChangeNotifier {
  User? _user;
  bool _isLoggedIn = false;
  bool _isLoading = false;
  String? _token;
  String? _error;

  // 게터
  User? get user => _user;
  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get token => _token;
  
  // 현재 로그인한 사용자의 branchId 반환
  String? get currentBranchId => _user?.branchId;

  // 초기화
  Future<void> init() async {
    await loadUserFromPrefs();
  }

  // SharedPreferences에서 사용자 정보 불러오기
  Future<void> loadUserFromPrefs() async {
    _setLoading(true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final userData = prefs.getString('userData');
      final authData = prefs.getString('authData');
      
      if (userData != null && authData != null) {
        final decodedUser = json.decode(userData);
        final decodedAuth = json.decode(authData);
        
        // 토큰 만료 확인 (30일)
        final tokenCreatedAt = decodedAuth['createdAt'] as int?;
        if (tokenCreatedAt != null) {
          final tokenAge = DateTime.now().millisecondsSinceEpoch - tokenCreatedAt;
          final thirtyDaysInMs = 30 * 24 * 60 * 60 * 1000; // 30일
          
          if (tokenAge > thirtyDaysInMs) {
            // 토큰이 만료됨 - 저장된 데이터 삭제
            await clearUser();
            if (kDebugMode) {
              print('토큰이 만료되어 자동로그인 데이터를 삭제했습니다.');
            }
            return;
          }
        }
        
        _user = User.fromJson(decodedUser);
        _token = decodedAuth['token'];
        _isLoggedIn = true;
        
        // 서버에서 최신 데이터로 업데이트
        await refreshUserProfile();
      }
    } catch (e) {
      if (kDebugMode) {
        print('사용자 데이터 로드 오류: $e');
      }
    } finally {
      _setLoading(false);
    }
  }

  // 사용자 프로필 새로 고침
  Future<bool> refreshUserProfile() async {
    if (_user == null || _token == null) return false;
    
    _setLoading(true);
    try {
      // 현재 사용자의 branchId와 함께 최신 프로필 조회
      final updatedProfile = await ApiService.getUserProfile(_user!.id, branchId: _user!.branchId);
      
      if (updatedProfile != null) {
        // 업데이트된 프로필로 User 객체 생성
        _user = User.fromJson({
          'id': updatedProfile['member_id']?.toString() ?? _user!.id,
          'name': updatedProfile['member_name'] ?? _user!.name,
          'phone': updatedProfile['member_phone'] ?? _user!.phone,
          'nickname': updatedProfile['member_nickname'],
          'gender': updatedProfile['member_gender'],
          'address': updatedProfile['member_address'],
          'birthday': updatedProfile['member_birthday'],
          'memo': updatedProfile['member_memo'],
          'email': updatedProfile['member_email'],
          'profileImage': updatedProfile['member_profile_image'],
          'branchId': updatedProfile['branch_id']?.toString() ?? _user!.branchId,
        });
        
        await _saveUserToPrefs();
        notifyListeners();
        return true;
      }
      
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('사용자 프로필 새로 고침 오류: $e');
      }
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // 사용자 정보 설정
  Future<void> setUser(User user, String token) async {
    _user = user;
    _token = token;
    await _saveUserToPrefs();
    await _saveAuthDataToPrefs(token, user.id, DateTime.now().millisecondsSinceEpoch);
    notifyListeners();
  }

  // 로그인 메서드 (기존 메서드 수정 - branch 선택 지원)
  Future<User?> login({required String phone, required String password}) async {
    _setLoading(true);
    try {
      // 먼저 사용자의 모든 branch 정보를 조회
      final userBranches = await ApiService.getUserBranches(phone: phone, password: password);
      
      if (userBranches == null || userBranches.isEmpty) {
        // 로그인 실패
        return null;
      }
      
      // 단일 branch인 경우 바로 로그인
      if (userBranches.length == 1) {
        final branchId = userBranches[0]['branch_id']?.toString();
        final user = await ApiService.login(phone: phone, password: password, branchId: branchId);
        
        if (user != null) {
          _user = user;
          _isLoggedIn = true;
          
          // 토큰 생성 시간 포함하여 토큰 생성
          final now = DateTime.now().millisecondsSinceEpoch;
          final token = 'token_${user.id}_$now';
          _token = token;
          
          // 사용자 정보와 인증 정보를 SharedPreferences에 저장
          await _saveUserToPrefs();
          await _saveAuthDataToPrefs(token, user.id, now);
          
          notifyListeners();
          return user;
        }
      }
      
      // 여러 branch인 경우 null 반환 (branch 선택 필요)
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('로그인 오류: $e');
      }
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Branch 선택을 위한 사용자 branch 정보 조회
  Future<Map<String, dynamic>?> getUserBranchesForSelection({required String phone, required String password}) async {
    _setLoading(true);
    try {
      // 사용자의 모든 branch 정보를 조회
      final userBranches = await ApiService.getUserBranches(phone: phone, password: password);
      
      if (userBranches == null || userBranches.isEmpty) {
        return null;
      }
      
      // Branch ID 목록 추출
      final branchIds = userBranches.map((ub) => ub['branch_id']?.toString()).where((id) => id != null).cast<String>().toList();
      
      if (branchIds.isEmpty) {
        return null;
      }
      
      // Branch 정보 조회
      final branches = await ApiService.getBranchInfo(branchIds);
      
      return {
        'userBranches': userBranches,
        'branches': branches,
      };
    } catch (e) {
      if (kDebugMode) {
        print('사용자 Branch 조회 오류: $e');
      }
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // 특정 branch로 로그인
  Future<User?> loginWithBranch({required String phone, required String password, required String branchId}) async {
    _setLoading(true);
    try {
      final user = await ApiService.login(phone: phone, password: password, branchId: branchId);
      if (user != null) {
        _user = user;
        _isLoggedIn = true;
        
        // 토큰 생성 시간 포함하여 토큰 생성
        final now = DateTime.now().millisecondsSinceEpoch;
        final token = 'token_${user.id}_$now';
        _token = token;
        
        // 사용자 정보와 인증 정보를 SharedPreferences에 저장
        await _saveUserToPrefs();
        await _saveAuthDataToPrefs(token, user.id, now);
        
        notifyListeners();
        return user;
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Branch 로그인 오류: $e');
      }
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // 회원가입 메서드 추가
  Future<bool> registerUser({
    required String name,
    required String phone,
    required String password,
    String? gender,
    String? address,
    String? birthday,
    required String userType,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      // 실제 서버에 회원가입 요청
      final user = await ApiService.registerUser(
        name: name,
        phone: phone,
        password: password,
        gender: gender,
        address: address,
        birthday: birthday,
        userType: userType,
        branchId: currentBranchId,
      );
      _user = user;
      _isLoggedIn = true;
      await _saveUserData();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // 전화번호 중복 확인 메서드 추가
  Future<bool> checkPhoneExists(String phone) async {
    _setLoading(true);
    try {
      final exists = await ApiService.checkPhoneExists(phone);
      return exists;
    } catch (e) {
      if (kDebugMode) {
        print('전화번호 중복 확인 오류: $e');
      }
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // 사용자 정보 업데이트
  Future<bool> updateUserProfile({
    String? name,
    String? phone,
    String? nickname,
    String? gender,
    String? address,
    String? birthday,
    String? memo,
  }) async {
    if (_user == null || _token == null) return false;
    
    _setLoading(true);
    try {
      // 업데이트할 데이터 구성
      final updateData = <String, dynamic>{};
      if (name != null) updateData['member_name'] = name;
      if (phone != null) updateData['member_phone'] = phone;
      if (nickname != null) updateData['member_nickname'] = nickname;
      if (gender != null) updateData['member_gender'] = gender;
      if (address != null) updateData['member_address'] = address;
      if (birthday != null) updateData['member_birthday'] = birthday;
      if (memo != null) updateData['member_memo'] = memo;
      
      // 현재 사용자의 branchId와 함께 프로필 업데이트
      final updatedProfile = await ApiService.updateUserProfile(
        memberId: _user!.id,
        branchId: _user!.branchId,
        updateData: updateData,
      );
      
      if (updatedProfile != null) {
        // 업데이트된 프로필로 User 객체 생성
        _user = User.fromJson({
          'id': updatedProfile['member_id']?.toString() ?? _user!.id,
          'name': updatedProfile['member_name'] ?? _user!.name,
          'phone': updatedProfile['member_phone'] ?? _user!.phone,
          'nickname': updatedProfile['member_nickname'],
          'gender': updatedProfile['member_gender'],
          'address': updatedProfile['member_address'],
          'birthday': updatedProfile['member_birthday'],
          'memo': updatedProfile['member_memo'],
          'email': updatedProfile['member_email'],
          'profileImage': updatedProfile['member_profile_image'],
          'branchId': updatedProfile['branch_id']?.toString() ?? _user!.branchId,
        });
        
        await _saveUserToPrefs();
        notifyListeners();
        return true;
      }
      
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('사용자 프로필 업데이트 오류: $e');
      }
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // 비밀번호 변경
  Future<bool> changePassword(String oldPassword, String newPassword) async {
    if (_user == null || _token == null) return false;
    
    _setLoading(true);
    try {
      // 현재 사용자의 branchId와 함께 비밀번호 변경
      final success = await ApiService.updatePassword(
        memberId: _user!.id,
        branchId: _user!.branchId,
        newPassword: newPassword,
      );
      
      return success;
    } catch (e) {
      if (kDebugMode) {
        print('비밀번호 변경 오류: $e');
      }
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // 계정 삭제
  Future<bool> deleteAccount(String password) async {
    if (_user == null || _token == null) return false;
    
    _setLoading(true);
    try {
      // ApiService에 deleteAccount 메서드 호출
      // 참고: 아직 ApiService에 이 메서드가 없으므로 임시로 true 반환
      // 실제로는 서버 API 호출 필요
      // final success = await ApiService.deleteAccount(
      //   userId: _user!.id,
      //   token: _token,
      //   password: password,
      // );
      
      // 임시로 성공 처리
      final success = true;
      
      if (success) {
        await clearUser();
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('계정 삭제 오류: $e');
      }
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // 로그아웃 시 사용자 정보 삭제
  Future<void> clearUser() async {
    _user = null;
    _token = null;
    _isLoggedIn = false;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userData');
    await prefs.remove('authData');
    
    notifyListeners();
  }

  // SharedPreferences에 사용자 정보 저장
  Future<void> _saveUserToPrefs() async {
    if (_user == null) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final userData = json.encode(_user!.toJson());
      await prefs.setString('userData', userData);
    } catch (e) {
      if (kDebugMode) {
        print('사용자 데이터 저장 오류: $e');
      }
    }
  }

  // 사용자 데이터 저장 (회원가입 후 호출)
  Future<void> _saveUserData() async {
    if (_user == null) return;
    
    await _saveUserToPrefs();
    // 토큰이 있는 경우 인증 데이터도 저장
    if (_token != null) {
      await _saveAuthDataToPrefs(_token!, _user!.id, DateTime.now().millisecondsSinceEpoch);
    }
  }

  // SharedPreferences에 인증 정보 저장
  Future<void> _saveAuthDataToPrefs(String token, String userId, int createdAt) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authData = json.encode({
        'token': token,
        'userId': userId,
        'createdAt': createdAt,
      });
      await prefs.setString('authData', authData);
    } catch (e) {
      if (kDebugMode) {
        print('인증 데이터 저장 오류: $e');
      }
    }
  }

  // 로딩 상태 설정
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
} 