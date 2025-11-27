import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../models/branch.dart';
import '../providers/user_provider.dart';
import './menu_screen.dart';
import './password_change_screen.dart';

class LoginBranchSelectionScreen extends StatefulWidget {
  final String phone;
  final String password;
  final List<Branch> branches;
  final List<Map<String, dynamic>> userBranches;

  const LoginBranchSelectionScreen({
    Key? key,
    required this.phone,
    required this.password,
    required this.branches,
    required this.userBranches,
  }) : super(key: key);

  @override
  _LoginBranchSelectionScreenState createState() => _LoginBranchSelectionScreenState();
}

class _LoginBranchSelectionScreenState extends State<LoginBranchSelectionScreen> {
  bool _isLoading = false;

  // 특정 branch로 로그인 처리
  Future<void> _loginWithBranch(String branchId) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      
      // 선택된 branch로 로그인 시도
      final user = await userProvider.loginWithBranch(
        phone: widget.phone,
        password: widget.password,
        branchId: branchId,
      );
      
      if (!mounted) return;
      
      if (user != null) {
        // 비밀번호가 전화번호 뒤 4자리인지 확인
        final phoneLastFour = widget.phone.replaceAll('-', '').substring(7); // 뒤 4자리
        
        if (kDebugMode) {
          print('🔍 [비밀번호 검사] 전화번호: ${widget.phone}');
          print('🔍 [비밀번호 검사] 비밀번호: ${widget.password}');
          print('🔍 [비밀번호 검사] 전화번호 뒤 4자리: $phoneLastFour');
          print('🔍 [비밀번호 검사] 일치 여부: ${widget.password == phoneLastFour}');
        }
        
        if (widget.password == phoneLastFour) {
          // 비밀번호 변경 안내 다이얼로그 표시
          _showPasswordChangeDialog();
        } else {
          // 로그인 성공 - 메뉴 화면으로 이동
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const MenuScreen()),
          );
        }
      } else {
        // 로그인 실패
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('로그인에 실패했습니다. 다시 시도해주세요.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Branch 로그인 오류: $e');
      }
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('로그인 중 오류가 발생했습니다: ${e.toString()}'),
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

  void _showPasswordChangeDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
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
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const MenuScreen()),
                );
              },
              child: const Text('나중에'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const PasswordChangeScreen(),
                  ),
                );
              },
              child: const Text('지금 변경'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('지점 선택'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  
                  // 안내 메시지
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info, color: Colors.blue.shade600),
                            const SizedBox(width: 8),
                            Text(
                              '지점 선택',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '여러 지점에 등록되어 있습니다.\n로그인할 지점을 선택해주세요.',
                          style: TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // 지점 목록
                  Expanded(
                    child: ListView.builder(
                      itemCount: widget.branches.length,
                      itemBuilder: (context, index) {
                        final branch = widget.branches[index];
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          child: InkWell(
                            onTap: () => _loginWithBranch(branch.id),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 지점명 (메인)
                                  Text(
                                    branch.name,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  
                                  const SizedBox(height: 8),
                                  
                                  // 주소
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.location_on,
                                        size: 16,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          branch.address,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  
                                  const SizedBox(height: 4),
                                  
                                  // 전화번호
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.phone,
                                        size: 16,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        branch.phone,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                  
                                  const SizedBox(height: 12),
                                  
                                  // 선택 버튼 표시
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).primaryColor,
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: const Text(
                                          '선택하기',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }
} 