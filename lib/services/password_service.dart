import 'package:crypto/crypto.dart';
import 'dart:convert';

class PasswordService {
  // SHA-256 해시 생성 (varchar(50)에 맞춤)
  static String hashPassword(String password) {
    final bytes = utf8.encode(password);
    final hash = sha256.convert(bytes);
    // SHA-256은 64자이지만, varchar(50)에 맞추기 위해 앞 50자만 사용
    return hash.toString().substring(0, 50);
  }

  // 비밀번호 검증
  static bool verifyPassword(String inputPassword, String storedPassword) {
    // 입력값 정규화
    final cleanInput = inputPassword.trim();
    final cleanStored = storedPassword.trim();

    print('🔐 비밀번호 검증:');
    print('  - 입력: "$cleanInput" (길이: ${cleanInput.length})');
    print('  - 저장: "$cleanStored" (길이: ${cleanStored.length})');

    // 해시 비밀번호인지 확인 (정확히 50자의 hex 문자열)
    final isHashedPassword = cleanStored.length == 50 &&
                             RegExp(r'^[a-f0-9]+$').hasMatch(cleanStored);

    print('  - 해시 여부: $isHashedPassword');

    if (isHashedPassword) {
      // 해시 비밀번호와 비교
      final hashedInput = hashPassword(cleanInput);
      print('  - 입력 해시: ${hashedInput.substring(0, 20)}...');
      final result = hashedInput == cleanStored;
      print('  - 해시 비교 결과: $result');
      return result;
    } else {
      // 평문 비밀번호와 직접 비교
      final result = cleanInput == cleanStored;
      print('  - 평문 비교: "$cleanInput" == "$cleanStored" → $result');
      return result;
    }
  }

  // 초기 비밀번호인지 확인 (핸드폰 번호 뒷 4자리 형태)
  static bool isInitialPassword(String password, String? phoneNumber) {
    if (phoneNumber == null || phoneNumber.isEmpty) {
      return false;
    }

    // 해시 비밀번호면 초기 비밀번호가 아님
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
}
