import 'package:flutter/material.dart';
import '/services/api_service.dart';
import '/constants/font_sizes.dart';

class AddMemberDialog extends StatefulWidget {
  final VoidCallback onMemberAdded;

  const AddMemberDialog({
    super.key,
    required this.onMemberAdded,
  });

  @override
  State<AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends State<AddMemberDialog> {
  final _formKey = GlobalKey<FormState>();
  
  // 폼 컨트롤러들
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _birthdateController = TextEditingController();
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _channelKeywordController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  
  String? _selectedGender; // null로 변경하여 기본 선택 없음
  String? _selectedMemberType; // DB에서 가져온 후 설정
  bool _isLoading = false;

  // 회원유형 관련 변수들
  List<String> _memberTypes = [];
  bool _isMemberTypeLoading = false;

  // 전화번호 중복체크 관련 변수들
  bool _isPhoneChecked = false;
  bool _isPhoneCheckLoading = false;
  String? _lastCheckedPhone;

  @override
  void initState() {
    super.initState();
    _loadMemberTypes();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _birthdateController.dispose();
    _nicknameController.dispose();
    _channelKeywordController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  // 회원유형 로드
  Future<void> _loadMemberTypes() async {
    setState(() {
      _isMemberTypeLoading = true;
    });

    try {
      final types = await ApiService.getBaseOptionSettings(
        category: '회원유형',
        tableName: '',
        fieldName: 'member_type',
      );

      if (mounted) {
        setState(() {
          // DB에서 가져온 값이 없으면 기본값으로 '일반' 사용
          _memberTypes = types.isEmpty ? ['일반'] : types;
          // 첫 번째 회원유형을 기본값으로 설정
          _selectedMemberType = _memberTypes.first;
          _isMemberTypeLoading = false;
        });
      }
    } catch (e) {
      // 에러 발생 시에도 기본값으로 '일반' 사용
      if (mounted) {
        setState(() {
          _memberTypes = ['일반'];
          _selectedMemberType = '일반';
          _isMemberTypeLoading = false;
        });
      }
    }
  }

  // 전화번호 포맷팅 함수
  String _formatPhoneNumber(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.length == 11) {
      return '${cleaned.substring(0, 3)}-${cleaned.substring(3, 7)}-${cleaned.substring(7)}';
    } else if (cleaned.length == 10) {
      return '${cleaned.substring(0, 3)}-${cleaned.substring(3, 6)}-${cleaned.substring(6)}';
    }
    return phone;
  }

  // 전화번호 중복체크 함수
  Future<void> _checkPhoneDuplicate() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('전화번호를 입력해주세요'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    setState(() {
      _isPhoneCheckLoading = true;
    });

    try {
      final formattedPhone = _formatPhoneNumber(phone);
      
      // v3_members 테이블에서 해당 전화번호 검색
      final result = await ApiService.getMemberData(
        fields: ['member_id', 'member_phone'],
        where: [
          {
            'field': 'member_phone',
            'operator': '=',
            'value': formattedPhone,
          }
        ],
        limit: 1,
      );

      if (result.isNotEmpty) {
        // 중복된 전화번호 발견
        setState(() {
          _isPhoneChecked = false;
          _lastCheckedPhone = null;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('이미 등록된 전화번호입니다. (회원번호: ${result[0]['member_id']})'),
              backgroundColor: Color(0xFFEF4444),
              duration: Duration(seconds: 4),
            ),
          );
        }
      } else {
        // 사용 가능한 전화번호
        setState(() {
          _isPhoneChecked = true;
          _lastCheckedPhone = formattedPhone;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('사용 가능한 전화번호입니다'),
              backgroundColor: Color(0xFF10B981),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isPhoneChecked = false;
        _lastCheckedPhone = null;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('전화번호 중복체크 중 오류가 발생했습니다: $e'),
            backgroundColor: Color(0xFFEF4444),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPhoneCheckLoading = false;
        });
      }
    }
  }

  // 회원 등록 처리
  Future<void> _saveMember() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // 주니어가 아닌 경우 전화번호 중복체크 확인
    if (_selectedMemberType != '주니어') {
      final currentPhone = _formatPhoneNumber(_phoneController.text.trim());
      if (!_isPhoneChecked || _lastCheckedPhone != currentPhone) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('전화번호 중복체크를 먼저 진행해주세요'),
            backgroundColor: Color(0xFFEF4444),
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 현재 날짜를 YYYY-MM-DD HH:mm:ss 형식으로 생성
      final now = DateTime.now();
      final registerDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

      // 전화번호가 있는 경우 맨 뒤 4자리를 비밀번호로 설정
      String? memberPassword;
      final phoneText = _phoneController.text.trim();
      if (phoneText.isNotEmpty) {
        final cleanedPhone = phoneText.replaceAll(RegExp(r'[^0-9]'), '');
        if (cleanedPhone.length >= 4) {
          memberPassword = cleanedPhone.substring(cleanedPhone.length - 4);
        }
      }

      // 지점별 회원번호 채번
      final memberNoBranch = await ApiService.getNextMemberNoBranch();

      final memberData = {
        'member_name': _nameController.text.trim(),
        'member_no_branch': memberNoBranch,
        'member_phone': _phoneController.text.trim().isEmpty ? null : _formatPhoneNumber(_phoneController.text.trim()),
        'member_gender': _selectedGender, // null일 수 있음
        'member_birthday': _birthdateController.text.trim().isEmpty ? null : _birthdateController.text.trim(),
        'member_nickname': _nicknameController.text.trim().isEmpty ? null : _nicknameController.text.trim(),
        'member_chn_keyword': _channelKeywordController.text.trim().isEmpty ? null : _channelKeywordController.text.trim(),
        'member_address': _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        'member_type': _selectedMemberType, // 선택된 회원 타입 사용
        'member_password': memberPassword, // 전화번호 뒤 4자리 또는 null
        'member_status_memo': null, // 기본값
        'member_register': registerDate,
        'member_update': registerDate,
      };

      final result = await ApiService.addMember(memberData);

      if (result['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '회원이 성공적으로 등록되었습니다. (회원번호: ${result['member_id']})',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              backgroundColor: Color(0xFF10B981),
              duration: Duration(seconds: 3),
            ),
          );
          
          Navigator.of(context).pop();
          widget.onMemberAdded();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '회원 등록 중 오류가 발생했습니다: $e',
              style: TextStyle(
                fontFamily: 'Pretendard',
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            backgroundColor: Color(0xFFEF4444),
            duration: Duration(seconds: 4),
          ),
        );
      }
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
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(20.0),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.6,
        constraints: BoxConstraints(
          maxWidth: 800.0,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.0),
          boxShadow: [
            BoxShadow(
              blurRadius: 24.0,
              color: Color(0x1A000000),
              offset: Offset(0.0, 8.0),
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 헤더
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16.0),
                  topRight: Radius.circular(16.0),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8.0),
                      decoration: BoxDecoration(
                        color: Color(0x20FFFFFF),
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      child: Icon(
                        Icons.person_add,
                        color: Colors.white,
                        size: 24.0,
                      ),
                    ),
                    SizedBox(width: 12.0),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '신규회원 등록',
                            style: AppTextStyles.titleH3.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                          ),
                          SizedBox(height: 4.0),
                          Text(
                            '새로운 회원 정보를 입력해주세요',
                            style: TextStyle(
                              fontFamily: 'Pretendard',
                              color: Color(0xFFD1FAE5),
                              fontSize: 14.0,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 24.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 폼 내용
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 첫 번째 행
                      Row(
                        children: [
                          Expanded(
                            child: _buildFormField(
                              label: '이름',
                              controller: _nameController,
                              icon: Icons.person_outline,
                              isRequired: true,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return '이름을 입력해주세요';
                                }
                                return null;
                              },
                            ),
                          ),
                          SizedBox(width: 16.0),
                          Expanded(
                            child: _buildPhoneField(),
                          ),
                        ],
                      ),
                      SizedBox(height: 16.0),
                      // 두 번째 행
                      Row(
                        children: [
                          Expanded(
                            child: _buildMemberTypeField(),
                          ),
                          SizedBox(width: 16.0),
                          Expanded(
                            child: _buildGenderField(),
                          ),
                        ],
                      ),
                      SizedBox(height: 16.0),
                      // 세 번째 행
                      Row(
                        children: [
                          Expanded(
                            child: _buildFormField(
                              label: '생년월일',
                              controller: _birthdateController,
                              icon: Icons.calendar_today_outlined,
                              hintText: 'YYYY-MM-DD',
                            ),
                          ),
                          SizedBox(width: 16.0),
                          Expanded(
                            child: _buildFormField(
                              label: '닉네임',
                              controller: _nicknameController,
                              icon: Icons.badge_outlined,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16.0),
                      // 네 번째 행
                      Row(
                        children: [
                          Expanded(
                            child: _buildFormField(
                              label: '채널키워드',
                              controller: _channelKeywordController,
                              icon: Icons.tag_outlined,
                            ),
                          ),
                          SizedBox(width: 16.0),
                          Expanded(
                            child: _buildFormField(
                              label: '주소',
                              controller: _addressController,
                              icon: Icons.location_on_outlined,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // 버튼 영역
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(16.0),
                  bottomRight: Radius.circular(16.0),
                ),
                border: Border(
                  top: BorderSide(
                    color: Color(0xFFE2E8F0),
                    width: 1.0,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF64748B),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                    ),
                    child: Text(
                      '취소',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ),
                  SizedBox(width: 12.0),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveMember,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                    ),
                    child: _isLoading
                        ? SizedBox(
                            width: 16.0,
                            height: 16.0,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.0,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            '등록',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 폼 필드 빌더
  Widget _buildFormField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    bool isRequired = false,
    String? hintText,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 16.0,
              color: Color(0xFF10B981),
            ),
            SizedBox(width: 6.0),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Pretendard',
                color: Color(0xFF374151),
                fontSize: 14.0,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (isRequired) ...[
              SizedBox(width: 4.0),
              Text(
                '*',
                style: TextStyle(
                  color: Color(0xFFEF4444),
                  fontSize: 14.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
        SizedBox(height: 8.0),
        TextFormField(
          controller: controller,
          validator: validator,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(
              fontFamily: 'Pretendard',
              color: Color(0xFF94A3B8),
              fontSize: 14.0,
              fontWeight: FontWeight.w400,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.0),
              borderSide: BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.0),
              borderSide: BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.0),
              borderSide: BorderSide(color: Color(0xFF10B981), width: 2.0),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.0),
              borderSide: BorderSide(color: Color(0xFFEF4444), width: 1.0),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.0),
              borderSide: BorderSide(color: Color(0xFFEF4444), width: 2.0),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          ),
          style: AppTextStyles.formLabel.copyWith(
            color: Color(0xFF1F2937),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // 회원 타입 필드 빌더
  Widget _buildMemberTypeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.group_outlined,
              size: 16.0,
              color: Color(0xFF10B981),
            ),
            SizedBox(width: 6.0),
            Text(
              '회원 타입',
              style: TextStyle(
                fontFamily: 'Pretendard',
                color: Color(0xFF374151),
                fontSize: 14.0,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(width: 4.0),
            Text(
              '*',
              style: TextStyle(
                color: Color(0xFFEF4444),
                fontSize: 14.0,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        SizedBox(height: 8.0),
        _isMemberTypeLoading
            ? Container(
                height: 48.0,
                decoration: BoxDecoration(
                  border: Border.all(color: Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.circular(10.0),
                  color: Colors.white,
                ),
                child: Center(
                  child: SizedBox(
                    width: 20.0,
                    height: 20.0,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.0,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                    ),
                  ),
                ),
              )
            : DropdownButtonFormField<String>(
                value: _selectedMemberType,
                dropdownColor: Colors.white, // 드롭다운 배경색을 흰색으로 설정
                decoration: InputDecoration(
                  hintText: _memberTypes.isEmpty ? '회원유형이 없습니다' : '회원유형을 선택해주세요',
                  hintStyle: TextStyle(
                    fontFamily: 'Pretendard',
                    color: Color(0xFF94A3B8),
                    fontSize: 14.0,
                    fontWeight: FontWeight.w400,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    borderSide: BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    borderSide: BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    borderSide: BorderSide(color: Color(0xFF10B981), width: 2.0),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                ),
                items: _memberTypes.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(
                      value,
                      style: AppTextStyles.formLabel.copyWith(
                        color: Color(0xFF1F2937),
                        fontWeight: FontWeight.w500, // 텍스트 색상을 어두운 회색으로 설정
                      ),
                    ),
                  );
                }).toList(),
                onChanged: _memberTypes.isEmpty ? null : (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedMemberType = newValue;
                    });
                  }
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '회원유형을 선택해주세요';
                  }
                  return null;
                },
                style: AppTextStyles.formLabel.copyWith(
                  color: Color(0xFF1F2937),
                  fontWeight: FontWeight.w500, // 선택된 값의 텍스트 색상
                ),
              ),
      ],
    );
  }

  // 성별 필드 빌더
  Widget _buildGenderField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.wc_outlined,
              size: 16.0,
              color: Color(0xFF10B981),
            ),
            SizedBox(width: 6.0),
            Text(
              '성별',
              style: TextStyle(
                fontFamily: 'Pretendard',
                color: Color(0xFF374151),
                fontSize: 14.0,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        SizedBox(height: 8.0),
        DropdownButtonFormField<String>(
          value: _selectedGender,
          dropdownColor: Colors.white, // 드롭다운 배경색을 흰색으로 설정
          decoration: InputDecoration(
            hintText: '성별을 선택해주세요', // 힌트 텍스트 추가
            hintStyle: TextStyle(
              fontFamily: 'Pretendard',
              color: Color(0xFF94A3B8),
              fontSize: 14.0,
              fontWeight: FontWeight.w400,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.0),
              borderSide: BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.0),
              borderSide: BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.0),
              borderSide: BorderSide(color: Color(0xFF10B981), width: 2.0),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          ),
          items: ['남성', '여성'].map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(
                value,
                style: AppTextStyles.formLabel.copyWith(
                  color: Color(0xFF1F2937),
                  fontWeight: FontWeight.w500, // 텍스트 색상을 어두운 회색으로 설정
                ),
              ),
            );
          }).toList(),
          onChanged: (String? newValue) {
            setState(() {
              _selectedGender = newValue;
            });
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return '성별을 선택해주세요';
            }
            return null;
          },
          style: AppTextStyles.formLabel.copyWith(
            color: Color(0xFF1F2937),
            fontWeight: FontWeight.w500, // 선택된 값의 텍스트 색상
          ),
        ),
      ],
    );
  }

  // 전화번호 필드 빌더 (중복체크 버튼 포함)
  Widget _buildPhoneField() {
    final isJunior = _selectedMemberType == '주니어';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.phone_outlined,
              size: 16.0,
              color: Color(0xFF10B981),
            ),
            SizedBox(width: 6.0),
            Text(
              '전화번호',
              style: TextStyle(
                fontFamily: 'Pretendard',
                color: Color(0xFF374151),
                fontSize: 14.0,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (!isJunior) ...[
              SizedBox(width: 4.0),
              Text(
                '*',
                style: TextStyle(
                  color: Color(0xFFEF4444),
                  fontSize: 14.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (isJunior) ...[
              SizedBox(width: 4.0),
              Text(
                '(선택)',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 12.0,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ],
        ),
        SizedBox(height: 8.0),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _phoneController,
                validator: (value) {
                  if (!isJunior) {
                    // 주니어가 아닌 경우 필수 입력
                    if (value == null || value.trim().isEmpty) {
                      return '전화번호를 입력해주세요';
                    }
                    String cleaned = value.replaceAll(RegExp(r'[^0-9]'), '');
                    if (cleaned.length < 10 || cleaned.length > 11) {
                      return '올바른 전화번호를 입력해주세요';
                    }
                  } else {
                    // 주니어인 경우 입력했다면 형식 검증
                    if (value != null && value.trim().isNotEmpty) {
                      String cleaned = value.replaceAll(RegExp(r'[^0-9]'), '');
                      if (cleaned.length < 10 || cleaned.length > 11) {
                        return '올바른 전화번호를 입력해주세요';
                      }
                    }
                  }
                  return null;
                },
                onChanged: (value) {
                  // 전화번호가 변경되면 중복체크 상태 초기화
                  if (_isPhoneChecked) {
                    setState(() {
                      _isPhoneChecked = false;
                      _lastCheckedPhone = null;
                    });
                  }
                },
                decoration: InputDecoration(
                  hintText: '010-1234-5678',
                  hintStyle: TextStyle(
                    fontFamily: 'Pretendard',
                    color: Color(0xFF94A3B8),
                    fontSize: 14.0,
                    fontWeight: FontWeight.w400,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    borderSide: BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    borderSide: BorderSide(
                      color: _isPhoneChecked ? Color(0xFF10B981) : Color(0xFFE2E8F0), 
                      width: _isPhoneChecked ? 2.0 : 1.0,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    borderSide: BorderSide(color: Color(0xFF10B981), width: 2.0),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    borderSide: BorderSide(color: Color(0xFFEF4444), width: 1.0),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    borderSide: BorderSide(color: Color(0xFFEF4444), width: 2.0),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  suffixIcon: _isPhoneChecked 
                    ? Icon(
                        Icons.check_circle,
                        color: Color(0xFF10B981),
                        size: 20.0,
                      )
                    : null,
                ),
                style: AppTextStyles.formLabel.copyWith(
                  color: Color(0xFF1F2937),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (!isJunior) ...[
              SizedBox(width: 8.0),
              SizedBox(
                height: 48.0,
                child: ElevatedButton(
                  onPressed: _isPhoneCheckLoading ? null : _checkPhoneDuplicate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isPhoneChecked ? Color(0xFF10B981) : Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 12.0),
                  ),
                  child: _isPhoneCheckLoading
                      ? SizedBox(
                          width: 16.0,
                          height: 16.0,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.0,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          _isPhoneChecked ? '확인완료' : '중복체크',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
} 