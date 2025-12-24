class WeightLog {
  final int? id;
  final double weight;
  final DateTime createdAt;
  final String account; // 【新增】

  const WeightLog({
    this.id,
    required this.weight,
    required this.createdAt,
    required this.account, // 【新增】
  });

  WeightLog copyWith({
    int? id,
    double? weight,
    DateTime? createdAt,
    String? account, // 【新增】
  }) {
    return WeightLog(
      id: id ?? this.id,
      weight: weight ?? this.weight,
      createdAt: createdAt ?? this.createdAt,
      account: account ?? this.account, // 【新增】
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'weight': weight,
      'createdAt': createdAt.toIso8601String(),
      'account': account, // 【新增】
    };
  }

  factory WeightLog.fromMap(Map<String, dynamic> map) {
    return WeightLog(
      id: map['id'],
      weight: map['weight'],
      createdAt: DateTime.parse(map['createdAt']),
      account: map['account'] ?? 'unknown', // 【新增】
    );
  }
}