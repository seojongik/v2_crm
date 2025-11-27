import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'common_tag_filter_model.dart';
export 'common_tag_filter_model.dart';

class CommonTagFilterWidget extends StatefulWidget {
  const CommonTagFilterWidget({
    super.key,
    required this.tags,
    this.selectedTags = const [],
    this.maxSelection,
    this.onTagSelected,
  });

  final List<String> tags;
  final List<String> selectedTags;
  final int? maxSelection;
  final Function(List<String>)? onTagSelected;

  @override
  State<CommonTagFilterWidget> createState() => _CommonTagFilterWidgetState();
}

class _CommonTagFilterWidgetState extends State<CommonTagFilterWidget> {
  late CommonTagFilterModel _model;
  late List<String> _selectedTags;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => CommonTagFilterModel());
    _selectedTags = List.from(widget.selectedTags);
  }

  @override
  void didUpdateWidget(CommonTagFilterWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 부모에서 전달된 selectedTags가 변경되었을 때 내부 상태 업데이트
    if (oldWidget.selectedTags != widget.selectedTags) {
      setState(() {
        _selectedTags = List.from(widget.selectedTags);
      });
    }
  }

  @override
  void dispose() {
    _model.maybeDispose();
    super.dispose();
  }

  void _toggleTag(String tag) {
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        if (widget.maxSelection != null && _selectedTags.length >= widget.maxSelection!) {
          if (widget.maxSelection == 1) {
            _selectedTags.clear();
            _selectedTags.add(tag);
          }
        } else {
          _selectedTags.add(tag);
        }
      }
    });
    widget.onTagSelected?.call(_selectedTags);
  }

  // 선택된 태그의 색상 (진한 색상)
  Color _getSelectedTagColor(int index) {
    final colors = [
      Color(0xFF3B82F6), // 파란색
      Color(0xFF10B981), // 초록색
      Color(0xFFF59E0B), // 주황색
      Color(0xFFEF4444), // 빨간색
      Color(0xFF8B5CF6), // 보라색
      Color(0xFF06B6D4), // 청록색
      Color(0xFFEC4899), // 핑크색
      Color(0xFF84CC16), // 라임색
    ];
    return colors[index % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            SizedBox(width: 16),
            ...widget.tags.asMap().entries.map((entry) {
              final index = entry.key;
              final tag = entry.value;
              final isSelected = _selectedTags.contains(tag);
              
              return Padding(
                padding: EdgeInsetsDirectional.fromSTEB(0, 0, 8, 0),
                child: GestureDetector(
                  onTap: () => _toggleTag(tag),
                  child: Container(
                    height: 32,
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? _getSelectedTagColor(index)  // 선택된 태그: 진한 색상
                          : Color(0xFFF1F5F9),           // 선택되지 않은 태그: 연한 회색
                      borderRadius: BorderRadius.circular(8),
                      border: isSelected 
                          ? null 
                          : Border.all(
                              color: Color(0xFFE2E8F0),
                              width: 1,
                            ),
                    ),
                    child: Align(
                      alignment: AlignmentDirectional(0, 0),
                      child: Padding(
                        padding: EdgeInsetsDirectional.fromSTEB(12, 0, 12, 0),
                        child: Text(
                          '#$tag',
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            color: isSelected 
                                ? Colors.white              // 선택된 태그: 흰색 글씨
                                : Color(0xFF64748B),        // 선택되지 않은 태그: 회색 글씨
                            fontSize: 15.0,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
            SizedBox(width: 16),
          ],
        ),
      ),
    );
  }
} 