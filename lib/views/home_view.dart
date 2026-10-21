import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../controllers/water_controller.dart';
import 'alarm_dialog.dart';
import '../models/water_log.dart';

class HomeView extends StatefulWidget {
  final WaterController controller;

  const HomeView({
    super.key,
    required this.controller,
  });

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  late final WaterController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller;
  }
  // Helper format jam
  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, child) {
        if (_controller.isLoading) {
          return const Scaffold(
            backgroundColor: AppColors.lightBlue,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        double progress = (_controller.currentAmountMl / _controller.dailyGoalMl).clamp(0.0, 1.0);
        int percentage = (progress * 100).round();
        int remainingMl = (_controller.dailyGoalMl - _controller.currentAmountMl).clamp(0, _controller.dailyGoalMl);

        return Scaffold(
          backgroundColor: AppColors.lightBlue,
          appBar: AppBar(
            title: const Text(
              'HydroTracker',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            actions: [
              // 1. TAMBAHKAN TOMBOL ALARM DI SINI
              IconButton(
                icon: const Icon(Icons.alarm_rounded),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => const AlarmDialog(),
                  );
                },
              ),

              // 2. Badge Streak Hari (Kode bawaanmu yang sudah ada)
              Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_fire_department, color: Colors.orangeAccent, size: 20),
                    const SizedBox(width: 4),
                    Text(
                      '${_controller.streakDays} Hari',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () => _controller.loadData(),
            color: AppColors.primary,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Header Info Sisa Air
                  _buildHeaderCard(remainingMl),

                  const SizedBox(height: 24),

                  // 2. Ring Progres Interaktif
                  Center(child: _buildProgressRing(progress, percentage)),

                  const SizedBox(height: 32),

                  // 3. Tombol Quick Add
                  const Text(
                    'Tambah Air Minum',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildQuickAddButtons(),

                  const SizedBox(height: 32),

                  // 4. Riwayat Jam Minum
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Riwayat Hari Ini',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      Text(
                        '${_controller.logs.length} kali minum',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildLogList(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // --- Widget Komponen ---

  Widget _buildHeaderCard(int remainingMl) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.lightBlue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.water_drop, color: AppColors.primary, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  remainingMl == 0 ? 'Target Tercapai!' : 'Tetap Terhidrasi!',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  remainingMl == 0 ? 'Hebat, kamu minum cukup hari ini 🎉' : 'Sisa $remainingMl ml lagi',
                  style: TextStyle(
                    fontSize: remainingMl == 0 ? 15 : 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressRing(double progress, int percentage) {
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 220,
          height: 220,
          child: CircularProgressIndicator(
            value: progress,
            strokeWidth: 16,
            backgroundColor: Colors.white,
            color: AppColors.primary,
            strokeCap: StrokeCap.round,
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.water_drop_rounded, color: AppColors.accent, size: 36),
            const SizedBox(height: 4),
            Text(
              '$percentage%',
              style: const TextStyle(
                fontSize: 38,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            Text(
              '${_controller.currentAmountMl} / ${_controller.dailyGoalMl} ml',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickAddButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _quickAddCard(200, Icons.local_drink),
        _quickAddCard(300, Icons.water_drop),
        _quickAddCard(500, Icons.sports_bar_outlined),
      ],
    );
  }


Widget _quickAddCard(int amount, IconData icon) {
  final int remainingMl = (
    _controller.dailyGoalMl - _controller.currentAmountMl
  ).clamp(0, _controller.dailyGoalMl).toInt();

  return InkWell(
    onTap: () {
      if (remainingMl <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Target minum harian sudah tercapai!',
            ),
          ),
        );
        return;
      }

      // Jangan menambahkan air melebihi target harian.
      final int amountToAdd =
          amount > remainingMl ? remainingMl : amount;

      _controller.addWater(amountToAdd);

      if (amountToAdd < amount) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Sisa target hanya $remainingMl ml. '
              'Ditambahkan $amountToAdd ml.',
            ),
          ),
        );
      }
    },
    borderRadius: BorderRadius.circular(16),
    child: Container(
      width: 95,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 26),
          const SizedBox(height: 8),
          Text(
            '+$amount ml',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
              fontSize: 14,
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildLogList() {
    final logs = _controller.logs;

    if (logs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        child: const Text(
          'Belum ada catatan minum hari ini.',
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: logs.length,
      itemBuilder: (context, index) {
        final log = logs[index];
        return Dismissible(
          key: Key(log.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.red.shade400,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          onDismissed: (_) => _controller.deleteLog(log.id),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.lightBlue,
                  child: const Icon(Icons.water_drop, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        log.drinkType,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      Text(
                        _formatTime(log.timestamp),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '+${log.amountMl} ml',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}