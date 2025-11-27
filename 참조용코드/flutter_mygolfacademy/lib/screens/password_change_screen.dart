import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../services/api_service.dart';
import 'package:flutter/foundation.dart';

class PasswordChangeScreen extends StatefulWidget {
  const PasswordChangeScreen({Key? key}) : super(key: key);

  @override
  State<PasswordChangeScreen> createState() => _PasswordChangeScreenState();
}

class _PasswordChangeScreenState extends State<PasswordChangeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isCurrentPasswordObscure = true;
  bool _isNewPasswordObscure = true;
  bool _isConfirmPasswordObscure = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final user = userProvider.user;
      
      if (user == null) {
        throw Exception('사용자 정보를 찾을 수 없습니다.');
      }

      // 현재 비밀번호 확인
      final loginResult = await ApiService.login(
        phone: user.phone,
        password: _currentPasswordController.text,
      );

      if (loginResult == null) {
        throw Exception('현재 비밀번호가 올바르지 않습니다.');
      }

      // 새 비밀번호로 업데이트
      final success = await ApiService.updatePassword(
        memberId: user.id,
        newPassword: _newPasswordController.text,
      );

      if (success) {
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('비밀번호가 성공적으로 변경되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
        
        Navigator.of(context).pop();
      } else {
        throw Exception('비밀번호 변경에 실패했습니다.');
      }
    } catch (e) {
      if (kDebugMode) {
        print('비밀번호 변경 오류: $e');
      }
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('비밀번호 변경'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                
                // 안내 메시지
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info, color: Colors.blue),
                          SizedBox(width: 8),
                          Text(
                            '비밀번호 변경 안내',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text('• 6자리 이상 입력해주세요'),
                      Text('• 영문, 숫자, 특수문자 조합을 권장합니다'),
                      Text('• 전화번호나 생년월일 등 개인정보는 피해주세요'),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // 현재 비밀번호
                TextFormField(
                  controller: _currentPasswordController,
                  decoration: InputDecoration(
                    labelText: '현재 비밀번호',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isCurrentPasswordObscure ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _isCurrentPasswordObscure = !_isCurrentPasswordObscure;
                        });
                      },
                    ),
                  ),
                  obscureText: _isCurrentPasswordObscure,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '현재 비밀번호를 입력해주세요';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 16),
                
                // 새 비밀번호
                TextFormField(
                  controller: _newPasswordController,
                  decoration: InputDecoration(
                    labelText: '새 비밀번호',
                    prefixIcon: const Icon(Icons.lock),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isNewPasswordObscure ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _isNewPasswordObscure = !_isNewPasswordObscure;
                        });
                      },
                    ),
                  ),
                  obscureText: _isNewPasswordObscure,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '새 비밀번호를 입력해주세요';
                    }
                    if (value.length < 6) {
                      return '비밀번호는 6자리 이상이어야 합니다';
                    }
                    if (value == _currentPasswordController.text) {
                      return '현재 비밀번호와 다른 비밀번호를 입력해주세요';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 16),
                
                // 새 비밀번호 확인
                TextFormField(
                  controller: _confirmPasswordController,
                  decoration: InputDecoration(
                    labelText: '새 비밀번호 확인',
                    prefixIcon: const Icon(Icons.lock_clock),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isConfirmPasswordObscure ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _isConfirmPasswordObscure = !_isConfirmPasswordObscure;
                        });
                      },
                    ),
                  ),
                  obscureText: _isConfirmPasswordObscure,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '새 비밀번호를 다시 입력해주세요';
                    }
                    if (value != _newPasswordController.text) {
                      return '새 비밀번호가 일치하지 않습니다';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 32),
                
                // 변경 버튼
                ElevatedButton(
                  onPressed: _isLoading ? null : _changePassword,
                  style: Theme.of(context).elevatedButtonTheme.style,
                  child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        '비밀번호 변경',
                        style: TextStyle(fontSize: 16),
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 