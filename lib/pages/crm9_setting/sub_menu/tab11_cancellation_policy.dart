import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../services/api_service.dart';
import '../../../services/upper_button_input_design.dart';
import '../../../constants/font_sizes.dart';
import '/services/supabase_adapter.dart';

class Tab11CancellationPolicyWidget extends StatefulWidget {
  const Tab11CancellationPolicyWidget({super.key});

  @override
  State<Tab11CancellationPolicyWidget> createState() => _Tab11CancellationPolicyWidgetState();
}

class _Tab11CancellationPolicyWidgetState extends State<Tab11CancellationPolicyWidget> {
  bool _isLoading = false;
  Map<String, List<Map<String, dynamic>>> _policiesByCategory = {};
  
  // 고정된 카테고리 설정 (모든 지점에서 동일)
  final Map<String, Map<String, dynamic>> _fixedCategories = {
    '선불크레딧': {
      'icon': '💳',
      'color': Color(0xFF3B82F6),
      'db_table': 'v2_bills'
    },
    '시간권': {
      'icon': '⏰',
      'color': Color(0xFF10B981),
      'db_table': 'v2_bill_times'
    },
    '게임권': {
      'icon': '🎮',
      'color': Color(0xFF8B5CF6),
      'db_table': 'v2_bill_games'
    },
    '레슨권': {
      'icon': '🎓',
      'color': Color(0xFFF59E0B),
      'db_table': 'v2_LS_contracts'
    },
    '프로그램': {
      'icon': '📋',
      'color': Color(0xFFEF4444),
      'db_table': 'v2_program_settings'
    },
  };
  
  @override
  void initState() {
    super.initState();
    _initializeDefaultPolicies().then((_) => _loadPolicies());
  }
  
  // 기본 취소 정책 초기화
  Future<void> _initializeDefaultPolicies() async {
    try {
      final branchId = ApiService.getCurrentBranchId();
      if (branchId == null || branchId.isEmpty) return;
      
      // 현재 지점의 취소 정책이 있는지 확인
      final data = await SupabaseAdapter.getData(
        table: 'v2_cancellation_policy',
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
        ],
      );

      if (data.isNotEmpty) {
        // 각 카테고리별로 기본 정책이 있는지 확인하고 없으면 생성
        for (var categoryEntry in _fixedCategories.entries) {
          final category = categoryEntry.key;
          final dbTable = categoryEntry.value['db_table'];

          final hasPolicy = data.any((policy) => policy['service_category'] == category);

          if (!hasPolicy) {
            // 기본 취소 정책 생성
            await _createDefaultPolicy(branchId, category, dbTable);
          }
        }
      }
    } catch (e) {
      print('기본 정책 초기화 오류: $e');
    }
  }
  
  Future<void> _createDefaultPolicy(String branchId, String category, String dbTable) async {
    try {
      final policyData = {
        'branch_id': branchId,
        'service_category': category,
        'db_table': dbTable,
        '_min_before_use': 0, // 시작시간 초과를 위한 0분
        'penalty_percent': 100, // 기본 100% 위약금
        'apply_sequence': 1, // 최우선 순위
      };
      
      await SupabaseAdapter.addData(
        table: 'v2_cancellation_policy',
        data: policyData,
      );
    } catch (e) {
      print('기본 정책 생성 오류: $e');
    }
  }
  
  Future<void> _loadPolicies() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final branchId = ApiService.getCurrentBranchId();
      if (branchId == null || branchId.isEmpty) {
        throw Exception('branch_id가 설정되지 않았습니다.');
      }
      
      final data = await SupabaseAdapter.getData(
        table: 'v2_cancellation_policy',
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
        ],
        orderBy: [
          {'field': 'service_category', 'direction': 'ASC'},
          {'field': 'apply_sequence', 'direction': 'ASC'},
        ],
      );

      // 카테고리별로 정책 데이터 그룹화
      final Map<String, List<Map<String, dynamic>>> policiesByCategory = {};

      for (var policy in data) {
        final category = policy['service_category'];
        if (!policiesByCategory.containsKey(category)) {
          policiesByCategory[category] = [];
        }
        policiesByCategory[category]!.add(policy);
      }

      setState(() {
        _policiesByCategory = policiesByCategory;
      });
    } catch (e) {
      _showErrorSnackBar('데이터를 불러오는데 실패했습니다: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _addPolicy(String category, int minBeforeUse, int penaltyPercent) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final branchId = ApiService.getCurrentBranchId();
      
      // 동일한 카테고리에서 같은 시간이 있는지 확인
      final existingPolicies = _policiesByCategory[category] ?? [];
      final hasSameTime = existingPolicies.any((policy) {
        final existingTime = policy['_min_before_use'] is int 
            ? policy['_min_before_use'] 
            : int.tryParse(policy['_min_before_use'].toString()) ?? 0;
        return existingTime == minBeforeUse;
      });
      
      if (hasSameTime) {
        _showErrorSnackBar('같은 카테고리에 동일한 취소 기준 시간이 이미 존재합니다.');
        return;
      }
      
      // 해당 카테고리의 다음 sequence 번호 계산
      final nextSequence = existingPolicies.length + 1;
      
      final policyData = {
        'branch_id': branchId,
        'service_category': category,
        'db_table': _fixedCategories[category]?['db_table'] ?? 'v2_contracts',
        '_min_before_use': minBeforeUse,
        'penalty_percent': penaltyPercent,
        'apply_sequence': nextSequence,
      };
      
      await SupabaseAdapter.addData(
        table: 'v2_cancellation_policy',
        data: policyData,
      );

      _showSuccessSnackBar('취소규정이 저장되었습니다.');
      _loadPolicies();
    } catch (e) {
      _showErrorSnackBar('취소규정 저장에 실패했습니다: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _updatePolicy(Map<String, dynamic> originalPolicy, String category, int minBeforeUse, int penaltyPercent) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final branchId = ApiService.getCurrentBranchId();
      
      // 동일한 카테고리에서 같은 시간이 있는지 확인 (자기 자신 제외)
      final existingPolicies = _policiesByCategory[category] ?? [];
      final hasSameTime = existingPolicies.any((policy) {
        // 기존 값과 같으면 자기 자신으로 간주
        if (policy['_min_before_use'].toString() == originalPolicy['_min_before_use'].toString() &&
            policy['penalty_percent'].toString() == originalPolicy['penalty_percent'].toString()) {
          return false;
        }
        final existingTime = policy['_min_before_use'] is int 
            ? policy['_min_before_use'] 
            : int.tryParse(policy['_min_before_use'].toString()) ?? 0;
        return existingTime == minBeforeUse;
      });
      
      if (hasSameTime) {
        _showErrorSnackBar('같은 카테고리에 동일한 취소 기준 시간이 이미 존재합니다.');
        return;
      }
      
      final updateData = {
        '_min_before_use': minBeforeUse,
        'penalty_percent': penaltyPercent,
        'db_table': _fixedCategories[category]?['db_table'] ?? 'v2_contracts',
      };
      
      await SupabaseAdapter.updateData(
        table: 'v2_cancellation_policy',
        data: updateData,
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'service_category', 'operator': '=', 'value': originalPolicy['service_category']},
          {'field': '_min_before_use', 'operator': '=', 'value': originalPolicy['_min_before_use'].toString()},
          {'field': 'penalty_percent', 'operator': '=', 'value': originalPolicy['penalty_percent'].toString()},
        ],
      );

      _showSuccessSnackBar('취소규정이 수정되었습니다.');
      _loadPolicies();
    } catch (e) {
      _showErrorSnackBar('취소규정 수정에 실패했습니다: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _deletePolicy(Map<String, dynamic> policy) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final branchId = ApiService.getCurrentBranchId();
      
      await SupabaseAdapter.deleteData(
        table: 'v2_cancellation_policy',
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'service_category', 'operator': '=', 'value': policy['service_category']},
          {'field': '_min_before_use', 'operator': '=', 'value': policy['_min_before_use'].toString()},
          {'field': 'penalty_percent', 'operator': '=', 'value': policy['penalty_percent'].toString()},
        ],
      );

      _showSuccessSnackBar('취소규정이 삭제되었습니다.');
      await _reorderSequence(policy['service_category']);
      _loadPolicies();
    } catch (e) {
      _showErrorSnackBar('취소규정 삭제에 실패했습니다: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // 삭제 후 sequence 번호 재정렬
  Future<void> _reorderSequence(String category) async {
    try {
      final branchId = ApiService.getCurrentBranchId();
      
      // 해당 카테고리의 남은 정책들을 가져와서 sequence 재정렬
      final policies = await SupabaseAdapter.getData(
        table: 'v2_cancellation_policy',
        where: [
          {'field': 'branch_id', 'operator': '=', 'value': branchId},
          {'field': 'service_category', 'operator': '=', 'value': category},
        ],
        orderBy: [
          {'field': 'penalty_percent', 'direction': 'DESC'},
          {'field': '_min_before_use', 'direction': 'DESC'},
        ],
      );

      if (policies.isNotEmpty) {
        // 각 정책에 새로운 sequence 번호 할당
        for (int i = 0; i < policies.length; i++) {
          final policy = policies[i];
          final newSequence = i + 1;

          await SupabaseAdapter.updateData(
            table: 'v2_cancellation_policy',
            data: {'apply_sequence': newSequence},
            where: [
              {'field': 'branch_id', 'operator': '=', 'value': branchId},
              {'field': 'service_category', 'operator': '=', 'value': category},
              {'field': '_min_before_use', 'operator': '=', 'value': policy['_min_before_use'].toString()},
              {'field': 'penalty_percent', 'operator': '=', 'value': policy['penalty_percent'].toString()},
            ],
          );
        }
      }
    } catch (e) {
      print('Sequence 재정렬 오류: $e');
    }
  }
  
  void _showAddPolicyDialog(String category) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AddPolicyDialog(
          category: category,
          categoryMeta: _fixedCategories[category]!,
          onSave: (minBeforeUse, penaltyPercent) async {
            await _addPolicy(category, minBeforeUse, penaltyPercent);
          },
        );
      },
    );
  }
  
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: Duration(seconds: 4),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: Duration(seconds: 3),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 헤더
        Container(
          padding: EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16.0),
              topRight: Radius.circular(16.0),
            ),
          ),
          child: Row(
            children: [
              ButtonDesignUpper.buildHelpTooltip(
                message: '취소정책에 따라 고객이 예약취소시 환불처리 됩니다',
                iconSize: 20.0,
              ),
            ],
          ),
        ),
        
        SizedBox(height: 16),
        
        // 메인 컨텐츠
        Expanded(
          child: _isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF1F2937),
                  ),
                )
              : Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Color(0xFFE5E7EB)),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final crossAxisCount = (constraints.maxWidth / 300).floor().clamp(1, 5);
                      return GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          mainAxisExtent: 280, // 고정 높이 설정
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: _fixedCategories.length,
                        itemBuilder: (context, index) {
                          final category = _fixedCategories.keys.elementAt(index);
                          final categoryMeta = _fixedCategories[category]!;
                          final policies = _policiesByCategory[category] ?? [];
                          
                          return CategorySection(
                            category: category,
                            icon: categoryMeta['icon'],
                            color: categoryMeta['color'],
                            policies: policies,
                            onUpdate: _updatePolicy,
                            onDelete: _deletePolicy,
                            onAdd: () => _showAddPolicyDialog(category),
                          );
                        },
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

class CategorySection extends StatelessWidget {
  final String category;
  final String icon;
  final Color color;
  final List<Map<String, dynamic>> policies;
  final Function(Map<String, dynamic>, String, int, int) onUpdate;
  final Function(Map<String, dynamic>) onDelete;
  final Function() onAdd;

  const CategorySection({
    super.key,
    required this.category,
    required this.icon,
    required this.color,
    required this.policies,
    required this.onUpdate,
    required this.onDelete,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          // 카테고리 헤더
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Text(
                  icon,
                  style: TextStyle(fontSize: 20),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    category,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.add, color: Colors.white, size: 20),
                  onPressed: onAdd,
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          ),
          
          // 정책 리스트 (고정 높이)
          Expanded(
            child: Container(
              child: policies.isEmpty
                  ? Center(
                      child: Text(
                        '설정된 규정이 없습니다',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    )
                  : Scrollbar(
                      thumbVisibility: policies.length > 4, // 4개 이상일 때 스크롤바 표시
                      child: ListView.builder(
                        padding: EdgeInsets.all(8),
                        itemCount: policies.length,
                        physics: policies.length > 4 
                            ? AlwaysScrollableScrollPhysics() 
                            : NeverScrollableScrollPhysics(),
                        itemBuilder: (context, index) {
                          final policy = policies[index];
                          return PolicyRow(
                            policy: policy,
                            category: category,
                            color: color,
                            index: index + 1, // 1부터 시작하는 번호
                            onUpdate: onUpdate,
                            onDelete: onDelete,
                          );
                        },
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class PolicyRow extends StatefulWidget {
  final Map<String, dynamic> policy;
  final String category;
  final Color color;
  final int index;
  final Function(Map<String, dynamic>, String, int, int) onUpdate;
  final Function(Map<String, dynamic>) onDelete;

  const PolicyRow({
    super.key,
    required this.policy,
    required this.category,
    required this.color,
    required this.index,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  State<PolicyRow> createState() => _PolicyRowState();
}

class _PolicyRowState extends State<PolicyRow> {
  late int _currentTime;
  late int _currentPenalty;

  @override
  void initState() {
    super.initState();
    _currentTime = widget.policy['_min_before_use'] is int
        ? widget.policy['_min_before_use']
        : int.tryParse(widget.policy['_min_before_use'].toString()) ?? 0;
    _currentPenalty = widget.policy['penalty_percent'] is int
        ? widget.policy['penalty_percent']
        : int.tryParse(widget.policy['penalty_percent'].toString()) ?? 0;
  }


  void _showEditDialog() {
    final tempTimeController = TextEditingController(text: _currentTime.toString());
    final tempPenaltyController = TextEditingController(text: _currentPenalty.toString());
    int tempTime = _currentTime;
    int tempPenalty = _currentPenalty;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.edit,
                  color: widget.color,
                  size: 20,
                ),
              ),
              SizedBox(width: 8),
              Text('취소규정 수정'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 시간 입력
              Row(
                children: [
                  Expanded(
                    child: Text('취소 기준 (분)'),
                  ),
                  Container(
                    width: 120,
                    decoration: BoxDecoration(
                      border: Border.all(color: widget.color),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: tempTimeController,
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.all(8),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (value) {
                              tempTime = int.tryParse(value) ?? tempTime;
                            },
                          ),
                        ),
                        Column(
                          children: [
                            GestureDetector(
                              onTap: () {
                                setDialogState(() {
                                  tempTime += 10;
                                  tempTimeController.text = tempTime.toString();
                                });
                              },
                              child: Container(
                                width: 24,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: widget.color.withOpacity(0.2),
                                  borderRadius: BorderRadius.only(topRight: Radius.circular(4)),
                                ),
                                child: Icon(Icons.keyboard_arrow_up, size: 16),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                setDialogState(() {
                                  final minValue = (widget.policy['apply_sequence'] ?? widget.index) == 1 ? 0 : 10;
                                  if (tempTime > minValue) {
                                    tempTime -= 10;
                                    tempTimeController.text = tempTime.toString();
                                  }
                                });
                              },
                              child: Container(
                                width: 24,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: widget.color.withOpacity(0.2),
                                  borderRadius: BorderRadius.only(bottomRight: Radius.circular(4)),
                                ),
                                child: Icon(Icons.keyboard_arrow_down, size: 16),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: 16),
              
              // 위약금 입력
              Row(
                children: [
                  Expanded(
                    child: Text('위약금 (%)'),
                  ),
                  Container(
                    width: 120,
                    decoration: BoxDecoration(
                      border: Border.all(color: Color(0xFFDC2626)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: tempPenaltyController,
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.all(8),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (value) {
                              tempPenalty = int.tryParse(value) ?? tempPenalty;
                            },
                          ),
                        ),
                        Column(
                          children: [
                            GestureDetector(
                              onTap: () {
                                setDialogState(() {
                                  if (tempPenalty < 100) {
                                    tempPenalty += 5;
                                    tempPenaltyController.text = tempPenalty.toString();
                                  }
                                });
                              },
                              child: Container(
                                width: 24,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: Color(0xFFDC2626).withOpacity(0.2),
                                  borderRadius: BorderRadius.only(topRight: Radius.circular(4)),
                                ),
                                child: Icon(Icons.keyboard_arrow_up, size: 16),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                setDialogState(() {
                                  if (tempPenalty > 0) {
                                    tempPenalty -= 5;
                                    tempPenaltyController.text = tempPenalty.toString();
                                  }
                                });
                              },
                              child: Container(
                                width: 24,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: Color(0xFFDC2626).withOpacity(0.2),
                                  borderRadius: BorderRadius.only(bottomRight: Radius.circular(4)),
                                ),
                                child: Icon(Icons.keyboard_arrow_down, size: 16),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                final newTime = int.tryParse(tempTimeController.text) ?? tempTime;
                final newPenalty = int.tryParse(tempPenaltyController.text) ?? tempPenalty;
                
                // 기본 정책이 아닌 경우 0분 설정 방지
                if ((widget.policy['apply_sequence'] ?? widget.index) != 1 && newTime == 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('시작시간 초과는 기본 정책에서만 설정 가능합니다.'),
                      backgroundColor: Color(0xFFDC2626),
                    ),
                  );
                  return;
                }
                
                widget.onUpdate(widget.policy, widget.category, newTime, newPenalty);
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.color,
                foregroundColor: Colors.white,
              ),
              child: Text('저장'),
            ),
          ],
        ),
      ),
    ).then((_) {
      tempTimeController.dispose();
      tempPenaltyController.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 6),
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: widget.color.withOpacity(0.3)),
      ),
      child: _buildDisplayRow(),
    );
  }

  Widget _buildDisplayRow() {
    return GestureDetector(
      onTap: () => _showEditDialog(),
      child: Row(
        children: [
          // 번호 표시
          Container(
            width: 24,
            height: 24,
            margin: EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${widget.policy['apply_sequence'] ?? widget.index}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF4B5563),
                ),
                children: [
                  TextSpan(
                    text: _currentTime == 0 ? '시작시간 초과' : '${_currentTime}분',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: widget.color,
                    ),
                  ),
                  TextSpan(text: _currentTime == 0 ? '시 ' : ' 이내 취소시 '),
                  TextSpan(
                    text: '${_currentPenalty}%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                  TextSpan(text: ' 차감'),
                ],
              ),
            ),
          ),
          // 기본 정책(apply_sequence 1)은 삭제 불가
          if ((widget.policy['apply_sequence'] ?? widget.index) != 1)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Color(0xFFDC2626).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: GestureDetector(
                    onTap: () => widget.onDelete(widget.policy),
                    child: Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

}

class AddPolicyDialog extends StatefulWidget {
  final String category;
  final Map<String, dynamic> categoryMeta;
  final Function(int, int) onSave;

  const AddPolicyDialog({
    super.key,
    required this.category,
    required this.categoryMeta,
    required this.onSave,
  });

  @override
  State<AddPolicyDialog> createState() => _AddPolicyDialogState();
}

class _AddPolicyDialogState extends State<AddPolicyDialog> {
  int _minBeforeUse = 180;
  int _penaltyPercent = 30;
  final TextEditingController _timeController = TextEditingController(text: '180');
  final TextEditingController _penaltyController = TextEditingController(text: '30');

  @override
  void dispose() {
    _timeController.dispose();
    _penaltyController.dispose();
    super.dispose();
  }

  void _incrementTime() {
    setState(() {
      _minBeforeUse += 10;
      _timeController.text = _minBeforeUse.toString();
    });
  }

  void _decrementTime() {
    setState(() {
      if (_minBeforeUse > 10) {
        _minBeforeUse -= 10;
        _timeController.text = _minBeforeUse.toString();
      }
    });
  }

  void _incrementPenalty() {
    setState(() {
      if (_penaltyPercent < 100) {
        _penaltyPercent += 5;
        _penaltyController.text = _penaltyPercent.toString();
      }
    });
  }

  void _decrementPenalty() {
    setState(() {
      if (_penaltyPercent > 0) {
        _penaltyPercent -= 5;
        _penaltyController.text = _penaltyPercent.toString();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Text(widget.categoryMeta['icon'], style: TextStyle(fontSize: 20)),
          SizedBox(width: 8),
          Text('${widget.category} 취소규정 추가'),
        ],
      ),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            
            // 취소 기준 시간
            Row(
              children: [
                Expanded(
                  child: Text('취소 기준 (분)'),
                ),
                Container(
                  width: 120,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _timeController,
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.all(8),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            _minBeforeUse = int.tryParse(value) ?? _minBeforeUse;
                          },
                        ),
                      ),
                      Column(
                        children: [
                          GestureDetector(
                            onTap: _incrementTime,
                            child: Container(
                              width: 24,
                              height: 20,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.only(topRight: Radius.circular(4)),
                              ),
                              child: Icon(Icons.keyboard_arrow_up, size: 16),
                            ),
                          ),
                          GestureDetector(
                            onTap: _decrementTime,
                            child: Container(
                              width: 24,
                              height: 20,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.only(bottomRight: Radius.circular(4)),
                              ),
                              child: Icon(Icons.keyboard_arrow_down, size: 16),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 16),
            
            // 위약금 비율
            Row(
              children: [
                Expanded(
                  child: Text('위약금 (%)'),
                ),
                Container(
                  width: 120,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _penaltyController,
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.all(8),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            _penaltyPercent = int.tryParse(value) ?? _penaltyPercent;
                          },
                        ),
                      ),
                      Column(
                        children: [
                          GestureDetector(
                            onTap: _incrementPenalty,
                            child: Container(
                              width: 24,
                              height: 20,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.only(topRight: Radius.circular(4)),
                              ),
                              child: Icon(Icons.keyboard_arrow_up, size: 16),
                            ),
                          ),
                          GestureDetector(
                            onTap: _decrementPenalty,
                            child: Container(
                              width: 24,
                              height: 20,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.only(bottomRight: Radius.circular(4)),
                              ),
                              child: Icon(Icons.keyboard_arrow_down, size: 16),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('취소'),
        ),
        ElevatedButton(
          onPressed: () {
            // 0분 설정 방지 (기본 정책용)
            if (_minBeforeUse == 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('시작시간 초과는 기본 정책에서만 설정됩니다.'),
                  backgroundColor: Color(0xFFDC2626),
                ),
              );
              return;
            }
            
            widget.onSave(_minBeforeUse, _penaltyPercent);
            Navigator.of(context).pop();
          },
          child: Text('저장'),
        ),
      ],
    );
  }
}