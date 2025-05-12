class Exercise {
  final String name;
  final String icon;
  final int minutes;
  final String intensity;
  final int calories;
  final double caloriesPerMinute;
  final String date;
  final bool isSelected;
  final String? id;

  Exercise({
    required this.name,
    required this.icon,
    this.minutes = 30,
    this.intensity = 'Vừa phải',
    this.calories = 0,
    this.date = '',
    this.isSelected = false,
    this.caloriesPerMinute = 5.0,
    this.id,
  });

  String generateId() {
    return '${name}_${DateTime.now().millisecondsSinceEpoch}';
  }

  int get calculatedCalories {
    double multiplier = 1.0;
    if (intensity == 'Nhẹ') {
      multiplier = 0.8;
    } else if (intensity == 'Cao') {
      multiplier = 1.3;
    }
    
    return (minutes * caloriesPerMinute * multiplier).round();
  }

  Exercise copyWith({
    String? name,
    String? icon,
    int? minutes,
    String? intensity,
    int? calories,
    String? date,
    bool? isSelected,
    double? caloriesPerMinute,
    String? id,
  }) {
    return Exercise(
      name: name ?? this.name,
      icon: icon ?? this.icon,
      minutes: minutes ?? this.minutes,
      intensity: intensity ?? this.intensity,
      calories: calories ?? this.calories,
      date: date ?? this.date,
      isSelected: isSelected ?? this.isSelected,
      caloriesPerMinute: caloriesPerMinute ?? this.caloriesPerMinute,
      id: id ?? this.id,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'icon': icon,
      'minutes': minutes,
      'intensity': intensity,
      'calories': calculatedCalories,
      'date': date,
      'isSelected': isSelected,
      'caloriesPerMinute': caloriesPerMinute,
      'id': id ?? generateId(),
    };
  }

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      name: json['name'] as String,
      icon: json['icon'] as String,
      minutes: json['minutes'] as int,
      intensity: json['intensity'] as String,
      calories: json['calories'] as int,
      date: json['date'] as String,
      isSelected: json['isSelected'] as bool? ?? false,
      caloriesPerMinute: (json['caloriesPerMinute'] as num?)?.toDouble() ?? 5.0,
      id: json['id'] as String?,
    );
  }
}
