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
            title: Text(
              'Statistik Hidrasi',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          body: SingleChildScrollView(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Minggu sebelumnya',
                        onPressed: () => setState(() => _weekOffset--),
                        icon: Icon(Icons.chevron_left_rounded),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              _weekOffset == 0
                                  ? 'Minggu Ini'
                                  : '${_weekOffset.abs()} Minggu Sebelumnya',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              _dateRange(dates.first, dates.last),
                              textAlign: TextAlign.center,
                              style: TextStyle(
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
                        icon: Icon(Icons.chevron_right_rounded),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard(
                        'Rata-rata Harian',
                        '$average ml',
                        Icons.equalizer_rounded,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _buildSummaryCard(
                        'Total 7 Hari',
                        '${(total / 1000).toStringAsFixed(1)} L',
                        Icons.water_drop_rounded,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                _buildSummaryCard(
                  'Hari Mencapai Target',
                  '$achievedDays dari 7 hari',
                  Icons.emoji_events_rounded,
                ),
                SizedBox(height: 24),
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Konsumsi Air per Hari',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Garis putus-putus menunjukkan target $goal ml',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                      SizedBox(height: 28),
                      SizedBox(
                        height: 230,
                        child: BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY: maxChartY,
                            minY: 0,
                            gridData: FlGridData(show: false),
                            borderData: FlBorderData(show: false),
                            titlesData: FlTitlesData(
                              topTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    final index = value.toInt();
                                    if (index < 0 || index >= dates.length) {
                                      return SizedBox.shrink();
                                    }
                                    return Padding(
                                      padding: EdgeInsets.only(top: 8),
                                      child: Text(
                                        _dayLabel(dates[index]),
                                        style: TextStyle(
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
                SizedBox(height: 24),
                _buildBadgeSection([
                  _BadgeInfo(
                    title: 'Langkah Pertama',
                    description: 'Capai target minum harian sekali.',
                    icon: Icons.water_drop_rounded,
                    current: widget.waterController.totalGoalDays.toDouble(),
                    target: 1,
                    unit: 'hari',
                    unlocked: widget.waterController.unlockedBadgeIds
                        .contains('first_goal'),
                  ),
                  _BadgeInfo(
                    title: 'Mulai Konsisten',
                    description: 'Pertahankan streak selama 3 hari.',
                    icon: Icons.local_fire_department_rounded,
                    current: widget.waterController.longestStreakDays.toDouble(),
                    target: 3,
                    unit: 'hari',
                    unlocked: widget.waterController.unlockedBadgeIds
                        .contains('streak_3'),
                  ),
                  _BadgeInfo(
                    title: 'Seminggu Hebat',
                    description: 'Capai target 7 hari berturut-turut.',
                    icon: Icons.workspace_premium_rounded,
                    current: widget.waterController.longestStreakDays.toDouble(),
                    target: 7,
                    unit: 'hari',
                    unlocked: widget.waterController.unlockedBadgeIds
                        .contains('streak_7'),
                  ),
                  _BadgeInfo(
                    title: 'Pejuang Hidrasi',
                    description: 'Capai target harian sebanyak 30 hari.',
                    icon: Icons.emoji_events_rounded,
                    current: widget.waterController.totalGoalDays.toDouble(),
                    target: 30,
                    unit: 'hari',
                    unlocked: widget.waterController.unlockedBadgeIds
                        .contains('goal_30'),
                  ),
                  _BadgeInfo(
                    title: '100 Liter',
                    description: 'Catat konsumsi air hingga 100 liter.',
                    icon: Icons.sports_score_rounded,
                    current: widget.waterController.totalWaterMl / 1000,
                    target: 100,
                    unit: 'L',
                    unlocked: widget.waterController.unlockedBadgeIds
                        .contains('water_100_liters'),
                  ),
                ]),
                SizedBox(height: 16),
                if (total == 0)
                  Padding(
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

  Widget _buildBadgeSection(List<_BadgeInfo> badges) {
    final unlockedCount = badges.where((badge) => badge.isUnlocked).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Pencapaian & Badge',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.softBlue,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$unlockedCount/${badges.length} terbuka',
                style: TextStyle(
                  color: AppColors.primaryDark,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 5),
        Text(
          'Kumpulkan badge dengan menjaga kebiasaan minum air.',
          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
        SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: badges.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.82,
          ),
          itemBuilder: (context, index) => _buildBadgeCard(badges[index]),
        ),
      ],
    );
  }

  Widget _buildBadgeCard(_BadgeInfo badge) {
    final unlocked = badge.isUnlocked;
    final badgeColor =
        unlocked ? const Color(0xFFE69A20) : AppColors.textMuted;
    final progress = badge.isUnlocked
        ? 1.0
        : (badge.current / badge.target).clamp(0.0, 1.0).toDouble();

    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: unlocked ? const Color(0xFFFFD78A) : AppColors.borderBlue,
          width: unlocked ? 1.3 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: unlocked
                      ? const Color(0xFFFFF1D6)
                      : AppColors.softBlue,
                  shape: BoxShape.circle,
                ),
                child: Icon(badge.icon, color: badgeColor, size: 23),
              ),
              Icon(
                unlocked ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                color: unlocked ? badgeColor : AppColors.textMuted,
                size: 18,
              ),
            ],
          ),
          SizedBox(height: 10),
          Text(
            badge.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textDark,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 4),
          Expanded(
            child: Text(
              badge.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ),
          SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppColors.softBlue,
              valueColor: AlwaysStoppedAnimation<Color>(
                unlocked ? badgeColor : AppColors.primary,
              ),
            ),
          ),
          SizedBox(height: 7),
          Text(
            unlocked ? 'Badge terbuka!' : badge.progressText,
            style: TextStyle(
              color: unlocked ? badgeColor : AppColors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 24),
          SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
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


class _BadgeInfo {
  final String title;
  final String description;
  final IconData icon;
  final double current;
  final double target;
  final String unit;
  final bool unlocked;

  const _BadgeInfo({
    required this.title,
    required this.description,
    required this.icon,
    required this.current,
    required this.target,
    required this.unit,
    required this.unlocked,
  });

  bool get isUnlocked => unlocked;

  String get progressText {
    final shownCurrent = current >= target
        ? target
        : (unit == 'L'
            ? current.toStringAsFixed(1)
            : current.toInt().toString());
    final shownTarget = unit == 'L'
        ? target.toStringAsFixed(0)
        : target.toInt().toString();
    return '$shownCurrent / $shownTarget $unit';
  }
}
