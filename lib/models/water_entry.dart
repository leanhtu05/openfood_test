class WaterEntry {
  final String id;
  final DateTime timestamp;
  final int amount; // mL

  WaterEntry({
    required this.id,
    required this.timestamp,
    required this.amount,
  });

  // Convert to Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'amount': amount,
    };
  }

  // Create from Map
  factory WaterEntry.fromMap(Map<String, dynamic> map) {
    return WaterEntry(
      id: map['id'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
      amount: map['amount'],
    );
  }
} 