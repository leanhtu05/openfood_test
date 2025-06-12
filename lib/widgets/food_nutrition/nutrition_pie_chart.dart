import 'package:flutter/material.dart';
import 'dart:math';

class NutritionPieChart extends StatelessWidget {
  final double protein;
  final double carbs;
  final double fat;

  const NutritionPieChart({
    Key? key,
    required this.protein,
    required this.carbs,
    required this.fat,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(200, 200),
      painter: PieChartPainter(protein: protein, carbs: carbs, fat: fat),
    );
  }
}

class PieChartPainter extends CustomPainter {
  final double protein;
  final double carbs;
  final double fat;

  PieChartPainter({
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;

    final total = protein + carbs + fat;
    
    if (total <= 0) {
      // Nếu không có dữ liệu, vẽ một vòng tròn xám
      final paint = Paint()
        ..color = Colors.grey.shade300
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(center, radius, paint);
      return;
    }

    // Vẽ biểu đồ tròn
    var startAngle = -pi / 2; // Bắt đầu từ phía trên
    
    // Vẽ phần protein
    if (protein > 0) {
      final proteinSweepAngle = 2 * pi * (protein / total);
      final proteinPaint = Paint()
        ..color = Colors.blue
        ..style = PaintingStyle.fill;
      
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        proteinSweepAngle,
        true,
        proteinPaint,
      );
      
      startAngle += proteinSweepAngle;
    }
    
    // Vẽ phần carbs
    if (carbs > 0) {
      final carbsSweepAngle = 2 * pi * (carbs / total);
      final carbsPaint = Paint()
        ..color = Colors.orange
        ..style = PaintingStyle.fill;
      
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        carbsSweepAngle,
        true,
        carbsPaint,
      );
      
      startAngle += carbsSweepAngle;
    }
    
    // Vẽ phần fat
    if (fat > 0) {
      final fatSweepAngle = 2 * pi * (fat / total);
      final fatPaint = Paint()
        ..color = Colors.green
        ..style = PaintingStyle.fill;
      
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        fatSweepAngle,
        true,
        fatPaint,
      );
    }
    
    // Vẽ một vòng tròn trắng ở giữa để tạo hiệu ứng donut
    final innerCirclePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(center, radius * 0.6, innerCirclePaint);

    // Vẽ các chỉ số phần trăm
    _drawPercentages(canvas, center, size);
  }

  void _drawPercentages(Canvas canvas, Offset center, Size size) {
    final total = protein + carbs + fat;
    if (total <= 0) return;

    final proteinPercent = (protein / total * 100).round();
    final carbsPercent = (carbs / total * 100).round();
    final fatPercent = (fat / total * 100).round();
    
    final textStyle = TextStyle(
      color: Colors.black,
      fontSize: 14,
      fontWeight: FontWeight.bold,
    );
    
    // Vẽ phần trăm protein
    _drawText(canvas, center, 'Đạm\n$proteinPercent%', textStyle, 0, size.width * 0.3);
    
    // Vẽ phần trăm carbs
    _drawText(canvas, center, 'Carbs\n$carbsPercent%', textStyle, 2 * pi / 3, size.width * 0.3);
    
    // Vẽ phần trăm fat
    _drawText(canvas, center, 'Béo\n$fatPercent%', textStyle, 4 * pi / 3, size.width * 0.3);
  }

  void _drawText(Canvas canvas, Offset center, String text, TextStyle style, double angle, double distance) {
    final textSpan = TextSpan(text: text, style: style);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    
    textPainter.layout();
    
    final x = center.dx + cos(angle) * distance - textPainter.width / 2;
    final y = center.dy + sin(angle) * distance - textPainter.height / 2;
    
    textPainter.paint(canvas, Offset(x, y));
  }

  @override
  bool shouldRepaint(covariant PieChartPainter oldDelegate) {
    return oldDelegate.protein != protein ||
           oldDelegate.carbs != carbs ||
           oldDelegate.fat != fat;
  }
} 