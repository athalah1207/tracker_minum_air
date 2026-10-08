import 'dart:convert';

class WaterLog {
  final String id;
  final int amountMl;
  final DateTime timestamp;
  final String drinkType;

  WaterLog({
    required this.id,
    required this.amountMl,
    required this.timestamp,
    this.drinkType = 'Air Putih',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amountMl': amountMl,
      'timestamp': timestamp.toIso8601String(),
      'drinkType': drinkType,
    };
  }

  factory WaterLog.fromMap(Map<String, dynamic> map) {
    return WaterLog(
      id: map['id'],
      amountMl: map['amountMl'],
      timestamp: DateTime.parse(map['timestamp']),
      drinkType: map['drinkType'] ?? 'Air Putih',
    );
  }

  String toJson() => json.encode(toMap());

  factory WaterLog.fromJson(String source) => WaterLog.fromMap(json.decode(source));
}