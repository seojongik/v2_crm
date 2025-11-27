import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class SalesTrendChart extends StatelessWidget {
  final List<Map<String, dynamic>> trendData;
  final String selectedChartItem;
  final int chartYear;
  final NumberFormat numberFormat;
  final Function(String) onChartItemChanged;
  final Function(int) onYearChanged;

  const SalesTrendChart({
    super.key,
    required this.trendData,
    required this.selectedChartItem,
    required this.chartYear,
    required this.numberFormat,
    required this.onChartItemChanged,
    required this.onYearChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: Color(0xFFE2E8F0),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '매출 트렌드',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  color: Color(0xFF1E293B),
                  fontSize: 18.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Spacer(),
              _buildYearNavigation(),
            ],
          ),
          SizedBox(height: 16.0),
          // 선택 버튼들
          _buildChartSelectionButtons(),
          SizedBox(height: 16.0),
          Expanded(
            child: _buildChart(),
          ),
          // 크레딧 또는 레슨권 선택 시 범례 표시
          if (selectedChartItem == 'totalCredit' || selectedChartItem == 'totalLSMin') ...[
            SizedBox(height: 12.0),
            _buildLegend(),
          ],
        ],
      ),
    );
  }

  Widget _buildYearNavigation() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(Icons.chevron_left, color: Color(0xFF64748B)),
          onPressed: () => onYearChanged(chartYear - 1),
        ),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: Text(
            '${chartYear}년',
            style: TextStyle(
              fontFamily: 'Pretendard',
              color: Color(0xFF1E293B),
              fontSize: 15.0,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        IconButton(
          icon: Icon(Icons.chevron_right, color: Color(0xFF64748B)),
          onPressed: () => onYearChanged(chartYear + 1),
        ),
      ],
    );
  }

  Widget _buildChartSelectionButtons() {
    final items = [
      {'id': 'totalPrice', 'label': '매출', 'color': Color(0xFF10B981)},
      {'id': 'totalCredit', 'label': '크레딧', 'color': Color(0xFF8B5CF6)},
      {'id': 'totalLSMin', 'label': '레슨권', 'color': Color(0xFFF59E0B)},
      {'id': 'totalGames', 'label': '게임권', 'color': Color(0xFF3B82F6)},
      {'id': 'totalTSMin', 'label': '시간권', 'color': Color(0xFFEC4899)},
      {'id': 'totalTermMonth', 'label': '기간권', 'color': Color(0xFF06B6D4)},
    ];

    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: items.map((item) {
        final isSelected = selectedChartItem == item['id'];
        return GestureDetector(
          onTap: () => onChartItemChanged(item['id'] as String),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: isSelected ? (item['color'] as Color) : Colors.white,
              borderRadius: BorderRadius.circular(20.0),
              border: Border.all(
                color: isSelected ? (item['color'] as Color) : Color(0xFFE2E8F0),
                width: 1.0,
              ),
            ),
            child: Text(
              item['label'] as String,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 16.0,
                color: isSelected ? Colors.white : Color(0xFF64748B),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (selectedChartItem == 'totalCredit') ...[
            _buildLegendItem('크레딧 판매', Color(0xFF8B5CF6)),
            SizedBox(width: 24.0),
            _buildLegendItem('크레딧 사용', Color(0xFFEF4444)),
          ] else if (selectedChartItem == 'totalLSMin') ...[
            _buildLegendItem('레슨권 판매', Color(0xFFF59E0B)),
            SizedBox(width: 24.0),
            _buildLegendItem('레슨 사용', Color(0xFFEF4444)),
          ],
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12.0,
          height: 12.0,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2.0),
          ),
        ),
        SizedBox(width: 6.0),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Pretendard',
            color: Color(0xFF64748B),
            fontSize: 12.0,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildChart() {
    if (trendData.isEmpty) {
      return Center(
        child: Text(
          '트렌드 데이터가 없습니다',
          style: TextStyle(
            fontFamily: 'Pretendard',
            color: Color(0xFF64748B),
            fontSize: 14.0,
          ),
        ),
      );
    }

    // 크레딧 선택 시에는 크레딧 + 청구 두 개 막대, 레슨권 선택 시에는 레슨권 + 레슨사용 두 개 막대, 다른 경우는 하나만
    final activeData = selectedChartItem == 'totalCredit'
        ? ['totalCredit', 'totalBills']
        : selectedChartItem == 'totalLSMin'
        ? ['totalLSMin', 'totalLessonUsage']
        : [selectedChartItem];
    final maxY = _getMaxValueForMixed(activeData);

    return Container(
      margin: EdgeInsets.only(left: 15, right: 15, top: 15, bottom: 25),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY,
          minY: 0,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                if (rodIndex >= activeData.length) {
                  return null;
                }

                final dataKey = activeData[rodIndex];
                final monthData = trendData[groupIndex];
                final rawValue = (monthData[dataKey] as num?)?.toDouble() ?? 0;

                String tooltipText = '';
                switch (dataKey) {
                  case 'totalPrice':
                    // 매출 합계를 먼저 표시
                    tooltipText = '매출: ${numberFormat.format(rawValue / 10000)}만원';
                    // 계약 타입별 매출 표시 (금액 큰 순으로 정렬)
                    if (monthData['contractTypeBreakdown'] != null) {
                      final typeBreakdown = monthData['contractTypeBreakdown'] as Map<String, dynamic>;
                      if (typeBreakdown.isNotEmpty) {
                        final sortedEntries = typeBreakdown.entries.toList()
                          ..sort((a, b) => (b.value as num).compareTo(a.value as num));
                        for (var entry in sortedEntries) {
                          tooltipText += '\n  ${entry.key}: ${numberFormat.format(entry.value / 10000)}만원';
                        }
                      }
                    }
                    break;
                  case 'totalCredit':
                    tooltipText = '크레딧 판매: ${numberFormat.format(rawValue / 10000)}만원';
                    break;
                  case 'totalBills':
                    tooltipText = '크레딧 사용: ${numberFormat.format(rawValue / 10000)}만원';
                    break;
                  case 'totalLSMin':
                    // 레슨권 판매 합계를 먼저 표시
                    tooltipText = '레슨권 판매: ${numberFormat.format(rawValue)}분';
                    // 프로별 레슨권 판매 시간 표시 (시간 큰 순으로 정렬)
                    if (monthData['proSalesBreakdown'] != null) {
                      final proBreakdown = monthData['proSalesBreakdown'] as Map<String, dynamic>;
                      if (proBreakdown.isNotEmpty) {
                        final sortedEntries = proBreakdown.entries.toList()
                          ..sort((a, b) => (b.value as num).compareTo(a.value as num));
                        for (var entry in sortedEntries) {
                          tooltipText += '\n  ${entry.key}: ${numberFormat.format(entry.value)}분';
                        }
                      }
                    }
                    break;
                  case 'totalLessonUsage':
                    // 레슨 사용 합계를 먼저 표시
                    tooltipText = '레슨 사용: ${numberFormat.format(rawValue)}분';
                    // 프로별 레슨 사용 시간 표시 (시간 큰 순으로 정렬)
                    if (monthData['proUsageBreakdown'] != null) {
                      final proBreakdown = monthData['proUsageBreakdown'] as Map<String, dynamic>;
                      if (proBreakdown.isNotEmpty) {
                        final sortedEntries = proBreakdown.entries.toList()
                          ..sort((a, b) => (b.value as num).compareTo(a.value as num));
                        for (var entry in sortedEntries) {
                          tooltipText += '\n  ${entry.key}: ${numberFormat.format(entry.value)}분';
                        }
                      }
                    }
                    break;
                  case 'recordCount':
                    tooltipText = '계약 건수: ${numberFormat.format(rawValue)}건';
                    break;
                  case 'totalGames':
                    tooltipText = '게임권: ${numberFormat.format(rawValue)}게임';
                    break;
                  case 'totalTSMin':
                    tooltipText = '시간권: ${numberFormat.format(rawValue)}분';
                    break;
                  case 'totalTermMonth':
                    tooltipText = '기간권: ${numberFormat.format(rawValue)}개월';
                    break;
                  default:
                    tooltipText = '기타: ${numberFormat.format(rawValue)}';
                }

                return BarTooltipItem(
                  '${monthData['monthLabel']}\n$tooltipText',
                  TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14.0,
                    fontFamily: 'Pretendard',
                  ),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < trendData.length) {
                    final monthData = trendData[index];
                    final month = monthData['month'] ?? (index + 1);
                    return Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        '${month}월',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 13.0,
                          fontFamily: 'Pretendard',
                        ),
                      ),
                    );
                  }
                  return Text('');
                },
                reservedSize: 35,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: _getGridInterval(activeData),
                getTitlesWidget: (value, meta) {
                  if (value == maxY) return Text('');
                  return Text(
                    _formatYAxisLabel(value),
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 14.0,
                      fontFamily: 'Pretendard',
                    ),
                  );
                },
                reservedSize: 50,
              ),
            ),
          ),
          gridData: FlGridData(
            show: true,
            horizontalInterval: _getGridInterval(activeData),
            verticalInterval: 1,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Color(0xFFE5E7EB),
                strokeWidth: 1,
              );
            },
            getDrawingVerticalLine: (value) {
              return FlLine(
                color: Color(0xFFE5E7EB),
                strokeWidth: 1,
              );
            },
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: Color(0xFFE5E7EB)),
          ),
          barGroups: _buildAllBarGroups(activeData),
        ),
      ),
    );
  }

  double _getMaxValue(List<String> dataKeys) {
    if (trendData.isEmpty || dataKeys.isEmpty) return 1000;

    double maxValue = 0;
    for (final data in trendData) {
      for (final key in dataKeys) {
        double value = (data[key] as num?)?.toDouble() ?? 0;
        // 매출액, 크레딧, 청구는 모두 만원 단위로 변환
        if (key == 'totalPrice' || key == 'totalCredit' || key == 'totalBills') {
          value = value / 10000;
        }
        if (value > maxValue) maxValue = value;
      }
    }

    if (maxValue == 0) return 1000;
    return (maxValue * 1.1).ceilToDouble();
  }

  double _getMaxValueForMixed(List<String> dataKeys) {
    if (trendData.isEmpty || dataKeys.isEmpty) return 1000;

    double maxValue = 0;
    for (final data in trendData) {
      for (final key in dataKeys) {
        double value = (data[key] as num?)?.toDouble() ?? 0;
        // 매출액, 크레딧, 청구는 모두 만원 단위로 변환
        if (key == 'totalPrice' || key == 'totalCredit' || key == 'totalBills') {
          value = value / 10000;
        }
        if (value > maxValue) maxValue = value;
      }
    }

    if (maxValue == 0) return 1000;
    return (maxValue * 1.1).ceilToDouble();
  }

  double _getGridInterval(List<String> dataKeys) {
    final maxValue = _getMaxValue(dataKeys);
    final interval = maxValue / 5;
    return interval > 0 ? interval : 200;
  }

  String _formatYAxisLabel(double value) {
    if (value >= 10000) {
      return '${(value / 10000).toStringAsFixed(0)}만';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}천';
    } else {
      return value.toStringAsFixed(0);
    }
  }

  List<BarChartGroupData> _buildAllBarGroups(List<String> dataKeys) {
    final groups = <BarChartGroupData>[];

    for (int i = 0; i < trendData.length; i++) {
      final data = trendData[i];
      final bars = <BarChartRodData>[];

      // 모든 데이터를 막대 차트로
      for (int j = 0; j < dataKeys.length; j++) {
        final key = dataKeys[j];
        final rawValue = (data[key] as num?)?.toDouble() ?? 0;
        // 매출액, 크레딧, 청구는 모두 만원 단위로 변환
        final value = (key == 'totalPrice' || key == 'totalCredit' || key == 'totalBills')
            ? rawValue / 10000
            : rawValue;

        Color barColor;
        switch (key) {
          case 'totalPrice':
            barColor = Color(0xFF10B981);
            break;
          case 'totalCredit':
            barColor = Color(0xFF8B5CF6);
            break;
          case 'totalBills':
            barColor = Color(0xFFEF4444);
            break;
          case 'totalLSMin':
            barColor = Color(0xFFF59E0B);
            break;
          case 'totalLessonUsage':
            barColor = Color(0xFFEF4444);
            break;
          case 'totalGames':
            barColor = Color(0xFF3B82F6);
            break;
          case 'totalTSMin':
            barColor = Color(0xFFEC4899);
            break;
          case 'totalTermMonth':
            barColor = Color(0xFF06B6D4);
            break;
          default:
            barColor = Color(0xFF64748B);
        }

        bars.add(
          BarChartRodData(
            toY: value,
            color: barColor,
            width: 12,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }

      groups.add(
        BarChartGroupData(
          x: i,
          barRods: bars,
          barsSpace: 4,
        ),
      );
    }

    return groups;
  }
}