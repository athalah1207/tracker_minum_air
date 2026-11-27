import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../controllers/water_controller.dart';
import 'alarm_dialog.dart';

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
  late WaterController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller;
  }

  @override
  void didUpdateWidget(covariant HomeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _controller = widget.controller;
    }
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  int get _remainingMl {
    return (_controller.dailyGoalMl - _controller.currentAmountMl)
        .clamp(0, _controller.dailyGoalMl)
        .toInt();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, child) {
        if (_controller.isLoading) {
          return Scaffold(
            backgroundColor: AppColors.lightBlue,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        // Mencegah pembagian dengan nol jika target belum valid.
        final dailyGoal = _controller.dailyGoalMl > 0
            ? _controller.dailyGoalMl
            : 2000;
        final progress =
            (_controller.currentAmountMl / dailyGoal).clamp(0.0, 1.0).toDouble();
        final percentage = (progress * 100).round();
        final remainingMl = _remainingMl;

        return Scaffold(
          backgroundColor: AppColors.lightBlue,
          appBar: AppBar(
            title: Text(
              'HydroTracker',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.alarm_rounded),
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    builder: (dialogContext) => AlarmDialog(),
                  );
                },
              ),
              Container(
                margin: EdgeInsets.only(right: 16),
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.local_fire_department,
                      color: Colors.orangeAccent,
                      size: 20,
                    ),
                    SizedBox(width: 4),
                    Text(
                      '${_controller.streakDays} Hari',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _controller.loadData,
            color: AppColors.primary,
            child: SingleChildScrollView(
              physics: AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderCard(remainingMl),
                  SizedBox(height: 24),
                  Center(child: _buildProgressRing(progress, percentage)),
                  SizedBox(height: 32),
                  Text(
                    'Tambah Air Minum',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  SizedBox(height: 12),
                  _buildQuickAddButtons(),
                  SizedBox(height: 20),
                  _buildCustomBottleCard(),
                  SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Riwayat Hari Ini',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      Text(
                        '${_controller.logs.length} kali minum',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  _buildLogList(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderCard(int remainingMl) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.lightBlue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.water_drop,
              color: AppColors.primary,
              size: 28,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  remainingMl == 0 ? 'Target Tercapai!' : 'Tetap Terhidrasi!',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textMuted,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  remainingMl == 0
                      ? 'Hebat, kamu minum cukup hari ini 🎉'
                      : 'Sisa $remainingMl ml lagi',
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
            backgroundColor: AppColors.softBlue,
            color: AppColors.primary,
            strokeCap: StrokeCap.round,
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.water_drop_rounded,
              color: AppColors.accent,
              size: 36,
            ),
            SizedBox(height: 4),
            Text(
              '$percentage%',
              style: TextStyle(
                fontSize: 38,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            Text(
              '${_controller.currentAmountMl} / ${_controller.dailyGoalMl} ml',
              style: TextStyle(
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
    return InkWell(
      onTap: () => _addWaterAmount(amount),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 95,
        padding: EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.15),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 26),
            SizedBox(height: 8),
            Text(
              '+$amount ml',
              style: TextStyle(
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

  Widget _buildCustomBottleCard() {
    final capacity = _controller.bottleCapacityMl;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.lightBlue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.local_drink,
                  color: AppColors.primary,
                  size: 30,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Botol Minum Saya',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.textDark,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Kapasitas $capacity ml',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Atur kapasitas botol',
                onPressed: _showBottleSettingsDialog,
                icon: Icon(
                  Icons.edit_outlined,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _addWaterAmount(
                capacity,
                drinkType: 'Botol Minum',
              ),
              icon: Icon(Icons.add),
              label: Text('Tambah 1 Botol ($capacity ml)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showBottleSettingsDialog() async {
    final textController = TextEditingController(
      text: _controller.bottleCapacityMl.toString(),
    );

    final newCapacity = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Atur Kapasitas Botol'),
          content: TextField(
            controller: textController,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Kapasitas botol',
              hintText: 'Contoh: 750',
              suffixText: 'ml',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                final capacity = int.tryParse(textController.text.trim());
                if (capacity == null || capacity < 50 || capacity > 5000) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Masukkan kapasitas 50 sampai 5000 ml.'),
                    ),
                  );
                  return;
                }
                Navigator.of(dialogContext).pop(capacity);
              },
              child: Text('Simpan'),
            ),
          ],
        );
      },
    );

    textController.dispose();

    if (!mounted || newCapacity == null) return;

    await _controller.updateBottleCapacity(newCapacity);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Kapasitas botol diatur menjadi $newCapacity ml.')),
    );
  }

  Future<void> _addWaterAmount(
    int requestedAmount, {
    String drinkType = 'Air Putih',
  }) async {
    final remainingMl = _remainingMl;

    if (remainingMl <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Target minum harian sudah tercapai!'),
        ),
      );
      return;
    }

    final amountToAdd = requestedAmount > remainingMl
        ? remainingMl
        : requestedAmount;

    if (amountToAdd <= 0) return;

    await _controller.addWater(amountToAdd, drinkType: drinkType);

    if (!mounted) return;

    if (amountToAdd < requestedAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Ditambahkan $amountToAdd ml karena sisa target hanya $remainingMl ml.',
          ),
        ),
      );
    }
  }

  Widget _buildLogList() {
    final logs = _controller.logs;

    if (logs.isEmpty) {
      return Container(
        padding: EdgeInsets.all(24),
        alignment: Alignment.center,
        child: Text(
          'Belum ada catatan minum hari ini.',
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: logs.length,
      itemBuilder: (context, index) {
        final log = logs[index];
        return Dismissible(
          key: ValueKey(log.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: EdgeInsets.only(right: 20),
            margin: EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.red.shade400,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.delete, color: Colors.white),
          ),
          onDismissed: (_) => _controller.deleteLog(log.id),
          child: Container(
            margin: EdgeInsets.only(bottom: 10),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.lightBlue,
                  child: Icon(
                    Icons.water_drop,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        log.drinkType,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      Text(
                        _formatTime(log.timestamp),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '+${log.amountMl} ml',
                  style: TextStyle(
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
