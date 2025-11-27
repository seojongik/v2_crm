import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import './register_screen.dart';
import './menu_screen.dart';
import './password_change_screen.dart';
import './login_branch_selection.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isObscure = true;
  bool _isLoading = false;
  bool _isConnected = true; // 인터넷 연결 상태

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // 인터넷 연결 상태 확인 (웹/모바일 모두 작동하는 버전)
  Future<void> _checkConnectivity() async {
    try {
      // 웹에서 CORS 문제가 없는 자체 서버로 확인 요청 보내기
      final bool isWeb = identical(0, 0.0);
      
      if (isWeb) {
        // 웹에서는 Google 같은 외부 사이트로 직접 요청할 수 없음 (CORS 정책 때문)
        // 대신 _isConnected를 기본적으로 true로 설정
        setState(() {
          _isConnected = true;
        });
      } else {
        // 모바일 앱에서는 일반적인 방법으로 인터넷 연결 확인
        final response = await http.get(
          Uri.parse('https://www.google.com'),
        ).timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            throw Exception('네트워크 연결 시간 초과');
          },
        );
        
        if (kDebugMode) {
          print('인터넷 연결 확인: ${response.statusCode}');
        }
        
        setState(() {
          _isConnected = response.statusCode >= 200 && response.statusCode < 400;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('연결 상태 확인 오류: $e');
      }
      
      // XMLHttpRequest 오류는 CORS 문제일 가능성이 높음 - 웹이면 연결 있다고 간주
      final bool isWeb = identical(0, 0.0);
      setState(() {
        _isConnected = isWeb || !e.toString().contains('XMLHttpRequest error');
      });
    }
  }

  // 전화번호 입력 포맷팅
  void _formatPhoneNumber() {
    final text = _phoneController.text.replaceAll('-', '');
    if (text.length > 11) {
      _phoneController.text = text.substring(0, 11);
    }

    // 전화번호 포맷팅 (하이픈 추가)
    String formattedPhone = text;
    if (text.length > 3) {
      formattedPhone = text.substring(0, 3) + '-' + text.substring(3);
    }
    if (text.length > 7) {
      formattedPhone = formattedPhone.substring(0, 8) + '-' + formattedPhone.substring(8);
    }
    
    // 커서 위치 저장
    final cursorPos = _phoneController.selection.baseOffset;
    
    // 현재 값과 다른 경우에만 업데이트
    if (formattedPhone != _phoneController.text) {
      _phoneController.text = formattedPhone;
      
      // 포맷팅 후 커서 위치 조정
      int newCursorPos = cursorPos;
      if (cursorPos == 4 || cursorPos == 9) newCursorPos++;
      if (newCursorPos > formattedPhone.length) {
        newCursorPos = formattedPhone.length;
      }
      
      _phoneController.selection = TextSelection.fromPosition(
        TextPosition(offset: newCursorPos),
      );
    }
  }

  // 로그인 처리
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 웹에서는 인터넷 연결 확인을 건너뜀 (CORS 문제 때문)
      final bool isWeb = identical(0, 0.0);
      
      if (!isWeb) {
        // 모바일에서만 인터넷 연결 확인
        try {
          final internetResponse = await http.get(
            Uri.parse('https://www.google.com'),
          ).timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              throw Exception('인터넷 연결 시간 초과');
            },
          );
          
          if (internetResponse.statusCode < 200 || internetResponse.statusCode >= 400) {
            throw Exception('인터넷 연결 실패');
          }
        } catch (e) {
          // 웹에서 CORS 오류는 무시
          if (!isWeb || !e.toString().contains('XMLHttpRequest error')) {
            rethrow;
          }
        }
      }
      
      // 전화번호와 비밀번호 추출
      final phone = _phoneController.text.replaceAll('-', '');
      final password = _passwordController.text;
      final userProvider = Provider.of<UserProvider>(context, listen: false);

      // 로그인 시도
      final user = await userProvider.login(phone: phone, password: password);
      
      if (!mounted) return;
      
      if (user != null) {
        // 단일 branch 로그인 성공
        _handleSuccessfulLogin(phone, password);
      } else {
        // 로그인 실패이거나 여러 branch인 경우 확인
        try {
          final branchData = await userProvider.getUserBranchesForSelection(phone: phone, password: password);
          
          if (branchData != null && branchData['branches'] != null && branchData['branches'].isNotEmpty) {
            // 여러 branch가 있는 경우 - branch 선택 화면으로 이동
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => LoginBranchSelectionScreen(
                  phone: _phoneController.text,
                  password: password,
                  branches: branchData['branches'],
                  userBranches: branchData['userBranches'],
                ),
              ),
            );
          } else {
            // 로그인 실패 - 오류 메시지 표시
            _showLoginFailureDialog();
          }
        } catch (e) {
          // Branch 조회 실패 - 일반 로그인 실패로 처리
          _showLoginFailureDialog();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('로그인 오류 발생: $e');
      }
      
      if (!mounted) return;
      
      String errorMsg = '로그인 중 오류가 발생했습니다';
      if (e.toString().contains('인터넷 연결')) {
        errorMsg = '인터넷 연결이 없습니다. 네트워크 연결을 확인해주세요.';
        setState(() {
          _isConnected = false;
        });
      } else if (e.toString().contains('XMLHttpRequest error') || e.toString().contains('서버 연결에 실패')) {
        final bool isWeb = identical(0, 0.0);
        errorMsg = isWeb 
            ? '서버 연결에 실패했습니다.' 
            : '서버 연결에 실패했습니다. 인터넷 연결을 확인해주세요.';
      } else if (e.toString().contains('Connection refused')) {
        errorMsg = '서버에 연결할 수 없습니다. 잠시 후 다시 시도해주세요.';
      } else if (e.toString().contains('잘못된 자격 증명') || e.toString().contains('Invalid credentials')) {
        errorMsg = '전화번호 또는 비밀번호가 올바르지 않습니다.';
      } else {
        errorMsg = '로그인 오류: ${e.toString().replaceAll('Exception: ', '')}';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
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

  // 로그인 성공 처리
  void _handleSuccessfulLogin(String phone, String password) {
    // 비밀번호가 전화번호 뒤 4자리인지 확인
    final phoneLastFour = phone.replaceAll('-', '').substring(7); // 뒤 4자리
    
    if (kDebugMode) {
      print('🔍 [비밀번호 검사] 전화번호: $phone');
      print('🔍 [비밀번호 검사] 비밀번호: $password');
      print('🔍 [비밀번호 검사] 전화번호 뒤 4자리: $phoneLastFour');
      print('🔍 [비밀번호 검사] 일치 여부: ${password == phoneLastFour}');
    }
    
    if (password == phoneLastFour) {
      // 비밀번호 변경 안내 다이얼로그 표시
      _showPasswordChangeDialog();
    } else {
      // 로그인 성공 - 메뉴 화면으로 이동
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const MenuScreen()),
      );
    }
  }

  // 로그인 실패 다이얼로그 표시
  void _showLoginFailureDialog() {
    if (kDebugMode) {
      print('❌ [로그인] 로그인 실패 - 사용자에게 오류 메시지 표시');
    }
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error, color: Colors.red),
              SizedBox(width: 8),
              Text('로그인 실패'),
            ],
          ),
          content: const Text(
            '전화번호 또는 비밀번호를 확인하세요.\n\n입력하신 정보가 올바른지 다시 한번 확인해주세요.',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  void _showPasswordChangeDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // 다이얼로그 외부 터치로 닫기 방지
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.orange),
              SizedBox(width: 8),
              Text('보안 경고'),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '현재 비밀번호가 전화번호 뒤 4자리로 설정되어 있습니다.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              Text('보안을 위해 비밀번호를 변경하시기 바랍니다.'),
              SizedBox(height: 8),
              Text('• 6자리 이상'),
              Text('• 영문, 숫자, 특수문자 조합 권장'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // 메뉴 화면으로 이동
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const MenuScreen()),
                );
              },
              child: const Text('나중에'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _navigateToPasswordChange();
              },
              child: const Text('지금 변경'),
            ),
          ],
        );
      },
    );
  }

  void _navigateToPasswordChange() {
    // 비밀번호 변경 화면으로 이동
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const PasswordChangeScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('프렌즈아카데미 목동프리미엄점'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      ),
      body: Consumer<UserProvider>(
        builder: (context, userProvider, _) {
          // userProvider.isLoading이 true일 때 로딩 표시
          if (userProvider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
          
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 24),
                      
                      // 앱 로고 이미지
                      Center(
                        child: Image.asset(
                          'assets/images/logo.png',
                          width: 260,
                          height: 260,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            if (kDebugMode) {
                              print('로고 이미지 로드 오류: $error - 대체 이미지 사용');
                            }
                            // 이미지 로드 실패 시 기존 로고 사용
                            return Image.asset(
                              'assets/images/logo_backup.png',
                              width: 260, 
                              height: 260,
                              fit: BoxFit.contain,
                            );
                          },
                        ),
                      ),
                      
                      const SizedBox(height: 48),
                      
                      // 전화번호 입력 필드
                      TextFormField(
                        controller: _phoneController,
                        decoration: const InputDecoration(
                          labelText: '전화번호',
                          hintText: '010-0000-0000',
                          prefixIcon: Icon(Icons.phone),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.phone,
                        autofillHints: const [AutofillHints.telephoneNumber],
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9-]')),
                        ],
                        onChanged: (_) => _formatPhoneNumber(),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '전화번호를 입력해주세요';
                          }
                          
                          final cleanedValue = value.replaceAll('-', '');
                          if (cleanedValue.length != 11) {
                            return '올바른 전화번호 형식이 아닙니다';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // 비밀번호 입력 필드
                      TextFormField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: '비밀번호',
                          prefixIcon: const Icon(Icons.lock),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isObscure ? Icons.visibility_off : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() {
                                _isObscure = !_isObscure;
                              });
                            },
                          ),
                        ),
                        obscureText: _isObscure,
                        autofillHints: const [AutofillHints.password],
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '비밀번호를 입력해주세요';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // 로그인 버튼
                      ElevatedButton(
                        onPressed: _isLoading ? null : _login,
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
                              '로그인',
                              style: TextStyle(fontSize: 16),
                            ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // 회원가입 링크
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const RegisterScreen(),
                            ),
                          );
                        },
                        child: Text(
                          '계정이 없으신가요? 회원가입',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.secondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
} 