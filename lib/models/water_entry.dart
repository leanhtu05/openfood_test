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

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'amount': amount,
    };
  }

  // Create from JSON (for Firestore)
  factory WaterEntry.fromJson(Map<String, dynamic> json) {
    return WaterEntry(
      id: json['id'],
      timestamp: json['timestamp'] is String 
          ? DateTime.parse(json['timestamp']) 
          : DateTime.fromMillisecondsSinceEpoch(json['timestamp']),
      amount: json['amount'],
    );
  }

  // Tạo bản sao với các thuộc tính mới
  WaterEntry copyWith({
    String? id,
    DateTime? timestamp,
    int? amount,
  }) {
    return WaterEntry(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      amount: amount ?? this.amount,
    );
  }
  
  // Tạo một bản sao của WaterEntry với ID mới
  WaterEntry updateId(String newId) {
    return copyWith(id: newId);
  }
} 