import 'package:crypto/crypto.dart';
import 'package:bcrypt/bcrypt.dart';
import 'dart:convert';

class PasswordService {
  // ========== 새로운 bcrypt 해싱 (권장) ==========
  
  /// bcrypt로 비밀번호 해싱
  static String hashPassword(String password) {
    // bcrypt 사용 (Salt 자동 생성)
    final salt = BCrypt.gensalt();
    return BCrypt.hashpw(password, salt);
  }
  
  /// 비밀번호 검증 (bcrypt 및 기존 SHA-256 호환)
  static bool verifyPassword(String inputPassword, String storedPassword) {
    // 입력값 정규화
    final cleanInput = inputPassword.trim();
    final cleanStored = storedPassword.trim();
    
    print('🔐 비밀번호 검증:');
    print('  - 입력: "$cleanInput" (길이: ${cleanInput.length})');
    print('  - 저장: "$cleanStored" (길이: ${cleanStored.length})');
    
    // 1. bcrypt 해시 확인 ($2a$, $2b$, $2y$로 시작)
    if (cleanStored.startsWith('\$2')) {
      try {
        final result = BCrypt.checkpw(cleanInput, cleanStored);
        print('  - bcrypt 검증 결과: $result');
        return result;
      } catch (e) {
        print('  - bcrypt 검증 오류: $e');
        return false;
      }
    }
    
    // 2. 기존 SHA-256 해시 확인 (50자 hex 문자열)
    final isSha256Hash = cleanStored.length == 50 &&
                         RegExp(r'^[a-f0-9]+$').hasMatch(cleanStored);
    
    if (isSha256Hash) {
      // SHA-256 해시와 비교 (하위 호환성)
      final hashedInput = _hashPasswordSha256(cleanInput);
      print('  - SHA-256 검증 결과: ${hashedInput == cleanStored}');
      return hashedInput == cleanStored;
    }
    
    // 3. 평문 비밀번호와 직접 비교 (하위 호환성 - 점진적 제거 권장)
    final result = cleanInput == cleanStored;
    print('  - 평문 비교: "$cleanInput" == "$cleanStored" → $result');
    return result;
  }
  
  // ========== 기존 SHA-256 해싱 (하위 호환성용) ==========
  
  /// SHA-256 해시 생성 (기존 시스템 호환성용)
  static String _hashPasswordSha256(String password) {
    final bytes = utf8.encode(password);
    final hash = sha256.convert(bytes);
    // SHA-256은 64자이지만, varchar(50)에 맞추기 위해 앞 50자만 사용
    return hash.toString().substring(0, 50);
  }
  
  /// 기존 SHA-256 해시로 변환 (마이그레이션용)
  static String hashPasswordSha256(String password) {
    return _hashPasswordSha256(password);
  }
  
  // ========== 유틸리티 메서드 ==========
  
  /// 초기 비밀번호인지 확인 (핸드폰 번호 뒷 4자리 형태)
  static bool isInitialPassword(String password, String? phoneNumber) {
    if (phoneNumber == null || phoneNumber.isEmpty) {
      return false;
    }
    
    // bcrypt 해시면 초기 비밀번호가 아님
    if (password.startsWith('\$2')) {
      return false;
    }
    
    // SHA-256 해시면 초기 비밀번호가 아님
    final hashPattern = RegExp(r'^[a-f0-9]{50}$');
    final isHashedPassword = password.length == 50 && hashPattern.hasMatch(password);
    
    if (isHashedPassword) {
      return false;
    }
    
    // 핸드폰 번호 뒷 4자리와 비교
    final last4Digits = phoneNumber.length >= 4
        ? phoneNumber.substring(phoneNumber.length - 4)
        : phoneNumber;
    
    return password == last4Digits;
  }
  
  /// 해시 타입 확인
  static String getHashType(String password) {
    if (password.startsWith('\$2')) {
      return 'bcrypt';
    } else if (password.length == 50 && RegExp(r'^[a-f0-9]+$').hasMatch(password)) {
      return 'sha256';
    } else {
      return 'plain';
    }
  }
}
