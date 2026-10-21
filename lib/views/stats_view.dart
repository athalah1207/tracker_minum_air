import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../controllers/water_controller.dart';

class StatsView extends StatefulWidget {
  final WaterController waterController;

  const StatsView({
    super.key,
    required this.waterController,
  });

  @override
  State<StatsView> createState() => _StatsViewState();
}

class _StatsViewState extends State<StatsView> {
  // 0 = minggu ini, -1 = minggu lalu, -2 = dua minggu lalu, dst.
  int _weekOffset = 0;

  DateTime _weekStart() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return today.subtract(Duration(days: today.weekday - 1 + (_weekOffset.abs() * 7)));
  }

  List<DateTime> _weekDates(DateTime start) {
    return List.generate(7, (index) => start.add(Duration(days: index)));
  }

  String _dayLabel(DateTime date) {
    const days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    return days[date.weekday - 1];
  }

  String _monthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    return months[month - 1];
  }

  String _dateRange(DateTime start, DateTime end) {
    if (start.year != end.year) {
      return '${start.day} ${_monthName(start.month)} ${start.year} – ${end.day} ${_monthName(end.month)} ${end.year}';
    }
    if (start.month == end.month) {
      return '${start.day}–${end.day} ${_monthName(end.month)} ${end.year}';
    }
    return '${start.day} ${_monthName(start.month)} – ${end.day} ${_monthName(end.month)} ${end.year}';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.waterController,
      builder: (context, child) {
        final start = _weekStart();
        final dates = _weekDates(start);
        final goal = widget.waterController.dailyGoalMl;
        final weeklyData = dates
            .map((date) => widget.waterController.totalForDate(date))
            .toList();
        final total = weeklyData.fold<int>(0, (sum, value) => sum + value);
        final average = (total / 7).round();
        final achievedDays = weeklyData.where((value) => value >= goal).length;
        final maxData = weeklyData.fold<int>(0, (max, value) => value > max ? value : max);
        final double maxChartY = (maxData > goal ? maxData : goal).toDouble() + 500;

        return Scaffold(
          backgroundColor: AppColors.lightBlue,
          appBar: AppBar(
            title: const Text(
              'Statistik Hidrasi',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Minggu sebelumnya',
                        onPressed: () => setState(() => _weekOffset--),
                        icon: const Icon(Icons.chevron_left_rounded),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              _weekOffset == 0
                                  ? 'Minggu Ini'
                                  : '${_weekOffset.abs()} Minggu Sebelumnya',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _dateRange(dates.first, dates.last),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Minggu berikutnya',
                        onPressed: _weekOffset < 0
                            ? () => setState(() => _weekOffset++)
                            : null,
                        icon: const Icon(Icons.chevron_right_rounded),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard(
                        'Rata-rata Harian',
                        '$average ml',
                        Icons.equalizer_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSummaryCard(
                        'Total 7 Hari',
                        '${(total / 1000).toStringAsFixed(1)} L',
                        Icons.water_drop_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildSummaryCard(
                  'Hari Mencapai Target',
                  '$achievedDays dari 7 hari',
                  Icons.emoji_events_rounded,
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Konsumsi Air per Hari',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Garis putus-putus menunjukkan target $goal ml',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        height: 230,
                        child: BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY: maxChartY,
                            minY: 0,
                            gridData: const FlGridData(show: false),
                            borderData: FlBorderData(show: false),
                            titlesData: FlTitlesData(
                              topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              leftTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    final index = value.toInt();
                                    if (index < 0 || index >= dates.length) {
                                      return const SizedBox.shrink();
                                    }
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        _dayLabel(dates[index]),
                                        style: const TextStyle(
                                          color: AppColors.textMuted,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            extraLinesData: ExtraLinesData(
                              horizontalLines: [
                                HorizontalLine(
                                  y: goal.toDouble(),
                                  color: AppColors.accent,
                                  strokeWidth: 2,
                                  dashArray: [6, 4],
                                ),
                              ],
                            ),
                            barGroups: List.generate(weeklyData.length, (index) {
                              final value = weeklyData[index];
                              final isGoalReached = value >= goal;
                              return BarChartGroupData(
                                x: index,
                                barRods: [
                                  BarChartRodData(
                                    toY: value.toDouble(),
                                    color: isGoalReached
                                        ? AppColors.primary
                                        : AppColors.primary.withValues(alpha: 0.35),
                                    width: 18,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ],
                              );
                            }),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (total == 0)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text(
                      'Belum ada catatan minum pada rentang minggu ini.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 24),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }
}
