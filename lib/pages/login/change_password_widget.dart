import 'package:flutter/material.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/services/api_service.dart';
import '/services/password_service.dart';
import '/main.dart';

class ChangePasswordWidget extends StatefulWidget {
  const ChangePasswordWidget({
    super.key,
    required this.staffAccessId,
    required this.isInitialPasswordChange,
  });

  final String staffAccessId;
  final bool isInitialPasswordChange;

  @override
  State<ChangePasswordWidget> createState() => _ChangePasswordWidgetState();
}

class _ChangePasswordWidgetState extends State<ChangePasswordWidget> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isCurrentPasswordVisible = false;
  bool _isNewPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // 비밀번호 변경 처리
  Future<void> _handlePasswordChange() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final currentPassword = _currentPasswordController.text.trim();
      final newPassword = _newPasswordController.text.trim();

      // 1. 현재 비밀번호 확인
      final currentUser = ApiService.getCurrentUser();
      final currentRole = ApiService.getCurrentStaffRole();

      if (currentUser == null || currentRole == null) {
        throw Exception('사용자 정보를 찾을 수 없습니다.');
      }

      // 현재 저장된 비밀번호 가져오기
      final storedPassword = currentUser['staff_access_password']?.toString() ?? '';

      // PasswordService를 사용한 비밀번호 검증 (bcrypt, SHA-256, 평문 모두 지원)
      final isCurrentPasswordCorrect = PasswordService.verifyPassword(
        currentPassword,
        storedPassword,
      );

      if (!isCurrentPasswordCorrect) {
        throw Exception('현재 비밀번호가 일치하지 않습니다.');
      }

      // 2. 새 비밀번호 해시화
      final hashedNewPassword = PasswordService.hashPassword(newPassword);

      // 3. 데이터베이스 업데이트
      final table = currentRole == 'pro' ? 'v2_staff_pro' : 'v2_staff_manager';
      final idField = currentRole == 'pro' ? 'pro_id' : 'manager_id';
      final userId = currentRole == 'pro'
          ? currentUser['pro_id']?.toString()
          : currentUser['manager_id']?.toString();

      if (userId == null) {
        throw Exception('사용자 ID를 찾을 수 없습니다.');
      }

      final result = await ApiService.updateData(
        table: table,
        data: {
          'staff_access_password': hashedNewPassword,
        },
        where: [
          {
            'field': idField,
            'operator': '=',
            'value': userId,
          }
        ],
      );

      if (result['success'] != true) {
        throw Exception('비밀번호 변경에 실패했습니다.');
      }

      // 4. 현재 사용자 정보 업데이트
      currentUser['staff_access_password'] = hashedNewPassword;
      ApiService.setCurrentStaff(
        widget.staffAccessId,
        currentRole,
        currentUser,
      );

      setState(() {
        _isLoading = false;
      });

      // 성공 메시지 표시 후 다이얼로그 닫기
      if (mounted) {
        // 비밀번호 변경 다이얼로그 닫기
        Navigator.of(context).pop();

        // 성공 다이얼로그 표시
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Color(0xFF10B981),
                    size: 48.0,
                  ),
                  SizedBox(height: 16.0),
                  Text(
                    '비밀번호가 성공적으로\n변경되었습니다.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 16.0,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // 성공 다이얼로그 닫기
                    if (widget.isInitialPasswordChange) {
                      // 초기 비밀번호 변경인 경우 메인페이지로 이동
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (context) => NavBarPage(initialPage: 'crm1_board'),
                        ),
                      );
                    }
                  },
                  child: Text(
                    '확인',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 16.0,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF3B82F6),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Color(0xFFEF4444),
                    size: 48.0,
                  ),
                  SizedBox(height: 16.0),
                  Text(
                    e.toString().replaceAll('Exception: ', ''),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 16.0,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    '확인',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 16.0,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF3B82F6),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: double.maxFinite,
        constraints: BoxConstraints(maxWidth: 500),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.0),
          boxShadow: [
            BoxShadow(
              blurRadius: 24.0,
              color: Color(0x1A000000),
              offset: Offset(0.0, 8.0),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 헤더
                Row(
                  children: [
                    Icon(
                      Icons.lock_reset,
                      color: Color(0xFF3B82F6),
                      size: 32.0,
                    ),
                    SizedBox(width: 12.0),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '비밀번호 변경',
                            style: TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 24.0,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          if (widget.isInitialPasswordChange) ...[
                            SizedBox(height: 4.0),
                            Text(
                              '보안을 위해 초기 비밀번호를 변경해주세요.',
                              style: TextStyle(
                                fontFamily: 'Pretendard',
                                fontSize: 14.0,
                                color: Color(0xFFEF4444),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (!widget.isInitialPasswordChange)
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.close, color: Color(0xFF64748B)),
                      ),
                  ],
                ),
                SizedBox(height: 32.0),

                // 현재 비밀번호
                Text(
                  '현재 비밀번호',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 14.0,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
                  ),
                ),
                SizedBox(height: 8.0),
                TextFormField(
                  controller: _currentPasswordController,
                  obscureText: !_isCurrentPasswordVisible,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    color: Colors.black,
                  ),
                  decoration: InputDecoration(
                    hintText: '현재 비밀번호를 입력하세요',
                    hintStyle: TextStyle(
                      fontFamily: 'Pretendard',
                      color: Color(0xFF94A3B8),
                    ),
                    filled: true,
                    fillColor: Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                      borderSide: BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                      borderSide: BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                      borderSide: BorderSide(color: Color(0xFF3B82F6), width: 2.0),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isCurrentPasswordVisible ? Icons.visibility : Icons.visibility_off,
                        color: Color(0xFF64748B),
                      ),
                      onPressed: () {
                        setState(() {
                          _isCurrentPasswordVisible = !_isCurrentPasswordVisible;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '현재 비밀번호를 입력해주세요.';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 20.0),

                // 새 비밀번호
                Text(
                  '새 비밀번호',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 14.0,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
                  ),
                ),
                SizedBox(height: 8.0),
                TextFormField(
                  controller: _newPasswordController,
                  obscureText: !_isNewPasswordVisible,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    color: Colors.black,
                  ),
                  decoration: InputDecoration(
                    hintText: '새 비밀번호를 입력하세요',
                    hintStyle: TextStyle(
                      fontFamily: 'Pretendard',
                      color: Color(0xFF94A3B8),
                    ),
                    filled: true,
                    fillColor: Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                      borderSide: BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                      borderSide: BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                      borderSide: BorderSide(color: Color(0xFF3B82F6), width: 2.0),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isNewPasswordVisible ? Icons.visibility : Icons.visibility_off,
                        color: Color(0xFF64748B),
                      ),
                      onPressed: () {
                        setState(() {
                          _isNewPasswordVisible = !_isNewPasswordVisible;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '새 비밀번호를 입력해주세요.';
                    }
                    if (value.length < 4) {
                      return '비밀번호는 최소 4자 이상이어야 합니다.';
                    }
                    if (value == _currentPasswordController.text) {
                      return '현재 비밀번호와 다른 비밀번호를 입력해주세요.';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 20.0),

                // 비밀번호 확인
                Text(
                  '새 비밀번호 확인',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 14.0,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
                  ),
                ),
                SizedBox(height: 8.0),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: !_isConfirmPasswordVisible,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    color: Colors.black,
                  ),
                  decoration: InputDecoration(
                    hintText: '새 비밀번호를 다시 입력하세요',
                    hintStyle: TextStyle(
                      fontFamily: 'Pretendard',
                      color: Color(0xFF94A3B8),
                    ),
                    filled: true,
                    fillColor: Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                      borderSide: BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                      borderSide: BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                      borderSide: BorderSide(color: Color(0xFF3B82F6), width: 2.0),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
                        color: Color(0xFF64748B),
                      ),
                      onPressed: () {
                        setState(() {
                          _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '비밀번호 확인을 입력해주세요.';
                    }
                    if (value != _newPasswordController.text) {
                      return '비밀번호가 일치하지 않습니다.';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 32.0),

                // 버튼
                Row(
                  children: [
                    if (!widget.isInitialPasswordChange) ...[
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFFF1F5F9),
                            foregroundColor: Color(0xFF64748B),
                            padding: EdgeInsets.symmetric(vertical: 16.0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            '취소',
                            style: TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 16.0,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12.0),
                    ],
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handlePasswordChange,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF3B82F6),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? SizedBox(
                                height: 20.0,
                                width: 20.0,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.0,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                '변경하기',
                                style: TextStyle(
                                  fontFamily: 'Pretendard',
                                  fontSize: 16.0,
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
        ),
      ),
    );
  }
}
