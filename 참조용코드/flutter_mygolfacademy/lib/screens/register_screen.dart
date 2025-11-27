import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _addressController = TextEditingController();
  final _birthdayController = TextEditingController();
  
  String? _selectedGender;
  String _selectedUserType = '일반회원';
  bool _isObscurePassword = true;
  bool _isObscureConfirmPassword = true;
  bool _isLoading = false;
  bool _phoneExists = false;
  bool _isPhoneChecked = false; // 중복확인 성공 여부
  String? _phoneCheckMessage; // 중복확인 메시지
  bool _phoneCheckMessageShown = false; // 중복확인 메시지 표시 여부

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _addressController.dispose();
    _birthdayController.dispose();
    super.dispose();
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
  
  // 생년월일 포맷팅
  void _formatBirthday() {
    final text = _birthdayController.text.replaceAll('-', '');
    if (text.length > 8) {
      _birthdayController.text = text.substring(0, 8);
    }

    // 생년월일 포맷팅 (하이픈 추가)
    String formattedBirthday = text;
    if (text.length > 4) {
      formattedBirthday = text.substring(0, 4) + '-' + text.substring(4);
    }
    if (text.length > 6) {
      formattedBirthday = formattedBirthday.substring(0, 7) + '-' + formattedBirthday.substring(7);
    }
    
    // 커서 위치 저장
    final cursorPos = _birthdayController.selection.baseOffset;
    
    // 현재 값과 다른 경우에만 업데이트
    if (formattedBirthday != _birthdayController.text) {
      _birthdayController.text = formattedBirthday;
      
      // 포맷팅 후 커서 위치 조정
      int newCursorPos = cursorPos;
      if (cursorPos == 5 || cursorPos == 8) newCursorPos++;
      if (newCursorPos > formattedBirthday.length) {
        newCursorPos = formattedBirthday.length;
      }
      
      _birthdayController.selection = TextSelection.fromPosition(
        TextPosition(offset: newCursorPos),
      );
    }
  }

  // 전화번호 중복 체크
  Future<void> _checkPhoneExists() async {
    final phone = _phoneController.text.replaceAll('-', '');
    if (phone.length == 11) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final exists = await userProvider.checkPhoneExists(phone);
      
      setState(() {
        _phoneExists = exists;
      });
    }
  }

  // 회원가입 처리
  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final name = _nameController.text.trim();
    final phone = _phoneController.text.replaceAll('-', '');
    final password = _passwordController.text;
    final address = _addressController.text.trim();
    final birthday = _birthdayController.text.trim();
    
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    try {
      final user = await userProvider.registerUser(
        name: name,
        phone: phone,
        password: password,
        gender: _selectedGender,
        address: address.isNotEmpty ? address : null,
        birthday: birthday.isNotEmpty ? birthday : null,
        userType: _selectedUserType,
      );
      
      if (!mounted) return;
      
      // 회원가입 성공
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('회원가입이 완료되었습니다. 로그인해주세요.'),
          backgroundColor: Colors.green,
        ),
      );
      
      // 로그인 화면으로 이동
      Navigator.of(context).pop();
        } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('회원가입 중 오류가 발생했습니다: ${e.toString()}'),
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
        title: const Text('프렌즈 아카데미 목동'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Consumer<UserProvider>(
              builder: (context, userProvider, child) {
                // userProvider.isLoading이 true일 때 로딩 표시
                if (userProvider.isLoading) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 24),
                    
                    // 이름 입력 필드
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: '이름',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '이름을 입력해주세요';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // 전화번호 입력 필드 + 중복확인 버튼
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _phoneController,
                            decoration: InputDecoration(
                              labelText: '전화번호',
                              hintText: '010-0000-0000',
                              prefixIcon: const Icon(Icons.phone),
                              border: const OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[0-9-]')),
                            ],
                            onChanged: (_) {
                              _formatPhoneNumber();
                              // setState를 최소화: 실제로 값이 바뀔 때만 호출
                              if (_isPhoneChecked || _phoneCheckMessage != null) {
                                setState(() {
                                  _isPhoneChecked = false;
                                  _phoneCheckMessage = null;
                                });
                              }
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return '전화번호를 입력해주세요';
                              }
                              final cleanedValue = value.replaceAll('-', '');
                              if (cleanedValue.length != 11) {
                                return '올바른 전화번호 형식이 아닙니다';
                              }
                              if (_phoneExists) {
                                return '이미 등록된 전화번호입니다';
                              }
                              if (!_isPhoneChecked) {
                                return '전화번호 중복확인을 해주세요';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            final phone = _phoneController.text;
                            final cleanedPhone = phone.replaceAll('-', '');
                            if (cleanedPhone.length != 11) {
                              setState(() {
                                _phoneCheckMessage = '전화번호 11자리를 입력하세요';
                                _isPhoneChecked = false;
                                _phoneExists = false;
                              });
                              return;
                            }
                            final userProvider = Provider.of<UserProvider>(context, listen: false);
                            final exists = await userProvider.checkPhoneExists(phone);
                            setState(() {
                              _isPhoneChecked = !exists;
                              _phoneExists = exists;
                              _phoneCheckMessage = exists
                                  ? '이미 등록된 전화번호입니다'
                                  : '사용 가능한 전화번호입니다';
                            });
                          },
                          child: const Text('중복확인'),
                        ),
                      ],
                    ),
                    if (_phoneCheckMessage != null && !(_phoneExists && _phoneCheckMessage == '이미 등록된 전화번호입니다' && _phoneCheckMessageShown))
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0, left: 4.0),
                        child: Text(
                          _phoneCheckMessage!,
                          style: TextStyle(
                            color: _isPhoneChecked ? Colors.green : Colors.red,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    
                    // 성별 선택 필드
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: '성별 (선택)',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                      value: _selectedGender,
                      items: const [
                        DropdownMenuItem(value: '남', child: Text('남')),
                        DropdownMenuItem(value: '여', child: Text('여')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedGender = value;
                        });
                      },
                      hint: const Text('성별 선택'),
                    ),
                    
                    const SizedBox(height: 16),

                    // 회원유형 선택 필드
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: '회원유형',
                        prefixIcon: Icon(Icons.group),
                        border: OutlineInputBorder(),
                      ),
                      value: _selectedUserType,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(value: '일반회원', child: Text('일반회원')),
                        DropdownMenuItem(value: '아이코젠', child: Text('아이코젠')),
                        DropdownMenuItem(value: '웰빙클럽', child: Text('웰빙클럽')),
                        DropdownMenuItem(value: '리프레쉬', child: Text('리프레쉬')),
                        DropdownMenuItem(value: '김캐디', child: Text('김캐디')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedUserType = value!;
                        });
                      },
                    ),
                    
                    if (_selectedUserType != '일반회원')
                      const Padding(
                        padding: EdgeInsets.only(top: 8.0, left: 8.0, right: 8.0),
                        child: Text(
                          '※ 주의 : 기업복지 회원님은 타석시작 30분전 예약만 가능합니다',
                          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    
                    const SizedBox(height: 16),
                    
                    // 주소 입력 필드
                    TextFormField(
                      controller: _addressController,
                      decoration: const InputDecoration(
                        labelText: '주소 (선택)',
                        prefixIcon: Icon(Icons.home),
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // 생년월일 입력 필드
                    TextFormField(
                      controller: _birthdayController,
                      decoration: const InputDecoration(
                        labelText: '생년월일 (선택)',
                        hintText: 'YYYY-MM-DD',
                        prefixIcon: Icon(Icons.calendar_today),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9-]')),
                      ],
                      onChanged: (_) => _formatBirthday(),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return null; // 선택적 필드
                        }
                        
                        final cleanedValue = value.replaceAll('-', '');
                        if (cleanedValue.length != 8) {
                          return '올바른 생년월일 형식이 아닙니다 (YYYY-MM-DD)';
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
                            _isObscurePassword ? Icons.visibility_off : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() {
                              _isObscurePassword = !_isObscurePassword;
                            });
                          },
                        ),
                      ),
                      obscureText: _isObscurePassword,
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '비밀번호를 입력해주세요';
                        }
                        if (value.length < 6) {
                          return '비밀번호는의 길이는 6자 이상이어야 합니다';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // 비밀번호 확인 입력 필드
                    TextFormField(
                      controller: _confirmPasswordController,
                      decoration: InputDecoration(
                        labelText: '비밀번호 확인',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isObscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() {
                              _isObscureConfirmPassword = !_isObscureConfirmPassword;
                            });
                          },
                        ),
                      ),
                      obscureText: _isObscureConfirmPassword,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '비밀번호 확인을 입력해주세요';
                        }
                        if (value != _passwordController.text) {
                          return '비밀번호가 일치하지 않습니다';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // 회원가입 버튼
                    ElevatedButton(
                      onPressed: (_isLoading || !_isPhoneChecked) ? null : _register,
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
                              '회원가입',
                              style: TextStyle(fontSize: 16),
                            ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // 로그인 링크
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text(
                        '이미 계정이 있으신가요? 로그인',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.secondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
} 