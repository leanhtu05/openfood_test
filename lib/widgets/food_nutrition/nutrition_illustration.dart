import 'package:flutter/material.dart';
import 'nutrition_circle_detail.dart';
import 'dart:math' as math;
import 'nutrition_circle.dart';

// Custom painter to draw arc at top of nutrition card
class CircleArcPainter extends CustomPainter {
  final double progress;
  final Color color;
  
  CircleArcPainter(this.progress, this.color);
  
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(size.width * 0.1, 0, size.width * 0.8, 12);
    final backgroundPaint = Paint()
      ..color = Colors.grey.shade200
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    
    final progressPaint = Paint()
      ..color = color
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    
    // Draw background arc
    canvas.drawArc(rect, -math.pi, math.pi, false, backgroundPaint);
    
    // Draw progress arc
    if (progress > 0) {
      canvas.drawArc(rect, -math.pi, math.pi * progress, false, progressPaint);
    }
  }
  
  @override
  bool shouldRepaint(CircleArcPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

class NutritionIllustration extends StatelessWidget {
  final double totalCalories;
  final double totalProtein;
  final double totalFat;
  final double totalCarbs;
  
  final double caloriesGoal;
  final double proteinGoal;
  final double fatGoal;
  final double carbsGoal;
  
  // Vi chất dinh dưỡng
  final Map<String, dynamic> nutritionInfo;
  
  // Mục tiêu vi chất
  final double cholesterolGoal;
  final double omega3Goal;
  final double fiberGoal;
  final double waterGoal;
  
  final double sugarGoal;
  final double saturatedFatGoal;
  final double caffeineGoal;
  final double alcoholGoal;
  
  final double vitaminDGoal;
  final double vitaminB12Goal;
  final double vitaminCGoal;
  final double vitaminBGoal;
  
  final double ironGoal;
  final double calciumGoal;
  final double magnesiumGoal;
  final double potassiumGoal;
  
  // Tham số để sử dụng layout nhỏ gọn hơn
  final bool useCompactLayout;
  
  // Thêm tham số mới
  final bool useRadialGradient;
  final Color backgroundColor;
  final bool showDetailedLabels;
  final bool showMacroMainSummary;

  const NutritionIllustration({
    Key? key,
    required this.totalCalories,
    required this.totalProtein,
    required this.totalFat,
    required this.totalCarbs,
    required this.caloriesGoal,
    required this.proteinGoal,
    required this.fatGoal,
    required this.carbsGoal,
    required this.nutritionInfo,
    required this.cholesterolGoal,
    required this.omega3Goal,
    required this.fiberGoal,
    required this.waterGoal,
    required this.sugarGoal,
    required this.saturatedFatGoal,
    required this.caffeineGoal,
    required this.alcoholGoal,
    required this.vitaminDGoal,
    required this.vitaminB12Goal,
    required this.vitaminCGoal,
    required this.vitaminBGoal,
    required this.ironGoal,
    required this.calciumGoal,
    required this.magnesiumGoal,
    required this.potassiumGoal,
    this.useCompactLayout = false,
    this.useRadialGradient = false,
    this.backgroundColor = const Color(0xFFEEEEEE),
    this.showDetailedLabels = false,
    this.showMacroMainSummary = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Tính toán giá trị dinh dưỡng một lần duy nhất
    double protein = totalProtein;
    double fat = totalFat;
    double carbs = totalCarbs;
    
    // Tính toán phần trăm cho vòng tròn dinh dưỡng
    double proteinPercentage = proteinGoal > 0 ? (protein / proteinGoal) * 100 : 0;
    double fatPercentage = fatGoal > 0 ? (fat / fatGoal) * 100 : 0;
    double carbsPercentage = carbsGoal > 0 ? (carbs / carbsGoal) * 100 : 0;
    
    // Đảm bảo giá trị không vượt quá 100%
    proteinPercentage = math.min(proteinPercentage, 100);
    fatPercentage = math.min(fatPercentage, 100);
    carbsPercentage = math.min(carbsPercentage, 100);
    
    // Tính calo còn lại
    int remainingCalories = caloriesGoal.toInt() - totalCalories.toInt();
    
    // Hiển thị tùy chỉnh dựa vào layout
    final size = useCompactLayout ? 58.0 : 68.0;
    
    // Lấy thông tin từ nutritionInfo nếu có
    double cholesterol = nutritionInfo['cholesterol'] ?? 0;
    double omega3 = nutritionInfo['omega3'] ?? 0;
    double fiber = nutritionInfo['fiber'] ?? 0;
    double water = nutritionInfo['water'] ?? 0;
    
    double sugar = nutritionInfo['sugar'] ?? 0;
    double saturatedFat = nutritionInfo['saturatedFat'] ?? 0;
    double caffeine = nutritionInfo['caffeine'] ?? 0;
    double alcohol = nutritionInfo['alcohol'] ?? 0;
    
    double vitaminD = nutritionInfo['vitaminD'] ?? 0;
    double vitaminB12 = nutritionInfo['vitaminB12'] ?? 0;
    double vitaminC = nutritionInfo['vitaminC'] ?? 0;
    double vitaminB = nutritionInfo['vitaminB'] ?? 0;
    
    double iron = nutritionInfo['iron'] ?? 0;
    double calcium = nutritionInfo['calcium'] ?? 0;
    double magnesium = nutritionInfo['magnesium'] ?? 0;
    double potassium = nutritionInfo['potassium'] ?? 0;
    double sodium = nutritionInfo['sodium'] ?? 0;
    double zinc = nutritionInfo['zinc'] ?? 0;
    
    // Tính phần trăm
    double cholesterolPercent = cholesterolGoal > 0 ? (cholesterol / cholesterolGoal) * 100 : 0;
    double omega3Percent = omega3Goal > 0 ? (omega3 / omega3Goal) * 100 : 0;
    double fiberPercent = fiberGoal > 0 ? (fiber / fiberGoal) * 100 : 0;
    double waterPercent = waterGoal > 0 ? (water / waterGoal) * 100 : 0;
    
    double sugarPercent = sugarGoal > 0 ? (sugar / sugarGoal) * 100 : 0;
    double saturatedFatPercent = saturatedFatGoal > 0 ? (saturatedFat / saturatedFatGoal) * 100 : 0;
    double caffeinePercent = caffeineGoal > 0 ? (caffeine / caffeineGoal) * 100 : 0;
    double alcoholPercent = alcoholGoal > 0 ? (alcohol / alcoholGoal) * 100 : 0;
    
    double vitaminDPercent = vitaminDGoal > 0 ? (vitaminD / vitaminDGoal) * 100 : 0;
    double vitaminB12Percent = vitaminB12Goal > 0 ? (vitaminB12 / vitaminB12Goal) * 100 : 0;
    double vitaminCPercent = vitaminCGoal > 0 ? (vitaminC / vitaminCGoal) * 100 : 0;
    double vitaminBPercent = vitaminBGoal > 0 ? (vitaminB / vitaminBGoal) * 100 : 0;
    
    double ironPercent = ironGoal > 0 ? (iron / ironGoal) * 100 : 0;
    double calciumPercent = calciumGoal > 0 ? (calcium / calciumGoal) * 100 : 0;
    double magnesiumPercent = magnesiumGoal > 0 ? (magnesium / magnesiumGoal) * 100 : 0;
    double potassiumPercent = potassiumGoal > 0 ? (potassium / potassiumGoal) * 100 : 0;
    double sodiumPercent = 100.0; // Default for sodium
    double zincPercent = 100.0; // Default for zinc
    
    return Container(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSection(
            "Tổng quan về Dinh dưỡng",
            [
              _buildCalorieCircle(
                totalCalories.toInt(), 
                caloriesGoal.toInt(),
                size: size,
                useRadialGradient: useRadialGradient,
                backgroundColor: backgroundColor,
                showDetailLabels: showDetailedLabels,
              ),
              _buildNutritionCircle(
                "Protein",
                proteinPercentage,
                "${protein.toInt()}g",
                Colors.blue,
                size: size,
                useLargerFonts: !useCompactLayout,
                useRadialGradient: useRadialGradient,
                showDetailLabels: showDetailedLabels,
                backgroundColor: backgroundColor,
              ),
              _buildNutritionCircle(
                "Chất béo",
                fatPercentage,
                "${fat.toInt()}g",
                Colors.orange,
                size: size,
                useLargerFonts: !useCompactLayout,
                useRadialGradient: useRadialGradient,
                showDetailLabels: showDetailedLabels,
                backgroundColor: backgroundColor,
              ),
              _buildNutritionCircle(
                "Carbs",
                carbsPercentage,
                "${carbs.toInt()}g",
                Colors.green,
                size: size,
                useLargerFonts: !useCompactLayout,
                useRadialGradient: useRadialGradient,
                showDetailLabels: showDetailedLabels,
                backgroundColor: backgroundColor,
              ),
            ],
            icon: Icons.pie_chart_outline,
            iconColor: Colors.amber.shade700,
          ),
          
          _buildSection(
            "Sức khỏe tim mạch",
            [
              _buildNutritionCircle(
                "Cholesterol",
                cholesterolPercent,
                "${cholesterol.toInt()}mg",
                Colors.deepOrange,
                size: size,
                useLargerFonts: !useCompactLayout,
                useRadialGradient: useRadialGradient,
                showDetailLabels: showDetailedLabels,
                backgroundColor: backgroundColor,
              ),
              _buildNutritionCircle(
                "Omega-3",
                omega3Percent,
                "${omega3.toInt()}mg",
                Colors.blueAccent.shade700,
                size: size,
                useLargerFonts: !useCompactLayout,
                useRadialGradient: useRadialGradient,
                showDetailLabels: showDetailedLabels,
                backgroundColor: backgroundColor,
              ),
              _buildNutritionCircle(
                "Chất xơ",
                fiberPercent,
                "${fiber.toInt()}g",
                Colors.brown.shade600,
                size: size,
                useLargerFonts: !useCompactLayout,
                useRadialGradient: useRadialGradient,
                showDetailLabels: showDetailedLabels,
                backgroundColor: backgroundColor,
              ),
              _buildNutritionCircle(
                "Nước",
                waterPercent,
                "${water.toInt()}ml",
                Colors.lightBlue,
                size: size,
                useLargerFonts: !useCompactLayout,
                useRadialGradient: useRadialGradient,
                showDetailLabels: showDetailedLabels,
                backgroundColor: backgroundColor,
              ),
            ],
            icon: Icons.favorite_outline,
            iconColor: Colors.red,
          ),
          
          _buildSection(
            "Các chất cần kiểm soát",
            [
              _buildNutritionCircle(
                "Đường",
                sugarPercent,
                "${sugar.toInt()}g",
                Colors.pink.shade400,
                size: size,
                useLargerFonts: !useCompactLayout,
                useRadialGradient: useRadialGradient,
                showDetailLabels: showDetailedLabels,
                backgroundColor: backgroundColor,
              ),
              _buildNutritionCircle(
                "Chất béo bão hòa",
                saturatedFatPercent,
                "${saturatedFat.toInt()}g",
                Colors.deepOrange.shade300,
                size: size,
                useLargerFonts: !useCompactLayout,
                useRadialGradient: useRadialGradient,
                showDetailLabels: showDetailedLabels,
                backgroundColor: backgroundColor,
              ),
              _buildNutritionCircle(
                "Caffeine",
                caffeinePercent,
                "${caffeine.toInt()}mg",
                Colors.brown,
                size: size,
                useLargerFonts: !useCompactLayout,
                useRadialGradient: useRadialGradient,
                showDetailLabels: showDetailedLabels,
                backgroundColor: backgroundColor,
              ),
              _buildNutritionCircle(
                "Sodium",
                sodiumPercent,
                "${sodium.toInt()}mg",
                Colors.indigo.shade300,
                size: size,
                useLargerFonts: !useCompactLayout,
                useRadialGradient: useRadialGradient,
                showDetailLabels: showDetailedLabels,
                backgroundColor: backgroundColor,
              ),
            ],
            icon: Icons.warning_amber_outlined,
            iconColor: Colors.orange,
          ),
          
          _buildSection(
            "Khoáng chất quan trọng",
            [
              _buildNutritionCircle(
                "Canxi",
                calciumPercent,
                "${calcium.toInt()}mg",
                Colors.blue.shade400,
                size: size,
                useLargerFonts: !useCompactLayout,
                useRadialGradient: useRadialGradient,
                showDetailLabels: showDetailedLabels,
                backgroundColor: backgroundColor,
              ),
              _buildNutritionCircle(
                "Sắt",
                ironPercent,
                "${iron.toInt()}mg",
                Colors.red.shade700,
                size: size,
                useLargerFonts: !useCompactLayout,
                useRadialGradient: useRadialGradient,
                showDetailLabels: showDetailedLabels,
                backgroundColor: backgroundColor,
              ),
              _buildNutritionCircle(
                "Kali",
                potassiumPercent,
                "${potassium.toInt()}mg",
                Colors.purple,
                size: size,
                useLargerFonts: !useCompactLayout,
                useRadialGradient: useRadialGradient,
                showDetailLabels: showDetailedLabels,
                backgroundColor: backgroundColor,
              ),
              _buildNutritionCircle(
                "Magiê",
                magnesiumPercent,
                "${magnesium.toInt()}mg",
                Colors.teal,
                size: size,
                useLargerFonts: !useCompactLayout,
                useRadialGradient: useRadialGradient,
                showDetailLabels: showDetailedLabels,
                backgroundColor: backgroundColor,
              ),
              _buildNutritionCircle(
                "Kẽm",
                zincPercent, 
                "${zinc.toInt()}mg",
                Colors.blueGrey.shade600,
                size: size,
                useLargerFonts: !useCompactLayout,
                useRadialGradient: useRadialGradient,
                showDetailLabels: showDetailedLabels,
                backgroundColor: backgroundColor,
              ),
            ],
            icon: Icons.science_outlined,
            iconColor: Colors.blue,
          ),
          
          _buildSection(
            "Vitamin thiết yếu",
            [
              _buildNutritionCircle(
                "Vitamin D",
                vitaminDPercent,
                "${vitaminD.toInt()}mcg",
                Colors.amber.shade400,
                size: size,
                useLargerFonts: !useCompactLayout,
                useRadialGradient: useRadialGradient,
                showDetailLabels: showDetailedLabels,
                backgroundColor: backgroundColor,
              ),
              _buildNutritionCircle(
                "Vitamin C",
                vitaminCPercent,
                "${vitaminC.toInt()}mg",
                Colors.orange.shade700,
                size: size,
                useLargerFonts: !useCompactLayout,
                useRadialGradient: useRadialGradient,
                showDetailLabels: showDetailedLabels,
                backgroundColor: backgroundColor,
              ),
              _buildNutritionCircle(
                "Vitamin B12",
                vitaminB12Percent,
                "${vitaminB12.toInt()}mcg",
                Colors.blue.shade800,
                size: size,
                useLargerFonts: !useCompactLayout,
                useRadialGradient: useRadialGradient,
                showDetailLabels: showDetailedLabels,
                backgroundColor: backgroundColor,
              ),
              _buildNutritionCircle(
                "Vitamin B",
                vitaminBPercent,
                "${vitaminB.toInt()}mg",
                Colors.green.shade800,
                size: size,
                useLargerFonts: !useCompactLayout,
                useRadialGradient: useRadialGradient,
                showDetailLabels: showDetailedLabels,
                backgroundColor: backgroundColor,
              ),
            ],
            icon: Icons.bolt_outlined,
            iconColor: Colors.amber,
          ),
        ],
      ),
    );
  }
  
  Widget _buildSection(String title, List<Widget> widgets, {IconData? icon, Color iconColor = Colors.black}) {
    // Kích thước nhỏ hơn khi useCompactLayout là true
    final iconSize = useCompactLayout ? 16.0 : 20.0;
    final titleFontSize = useCompactLayout ? 14.0 : 16.0;
    final horizontalMargin = useCompactLayout ? 12.0 : 16.0;
    final verticalPadding = useCompactLayout ? 8.0 : 12.0;
    final horizontalPadding = useCompactLayout ? 10.0 : 14.0;
    
    // Trả về widget với context để có thể truy cập MediaQuery 
    return LayoutBuilder(
      builder: (context, constraints) {
        // Tính toán khoảng cách giữa các vòng tròn
        final availableWidth = constraints.maxWidth;
        final circleSize = useCompactLayout ? 58.0 : 68.0;
        final itemCount = widgets.length;
        
        // Khoảng cách cố định giữa các vòng tròn để đảm bảo đều nhau
        final spacing = 20.0; // Tăng khoảng cách cố định giữa các vòng tròn
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: EdgeInsets.only(left: horizontalMargin, bottom: useCompactLayout ? 6.0 : 10.0),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: iconSize, color: iconColor),
                    SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Card for nutrition circles
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(useCompactLayout ? 20.0 : 28.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 6,
                    spreadRadius: 0,
                    offset: Offset(0, 2),
                  ),
                ],
                // Thêm gradient nhẹ nhàng cho container
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white,
                    Colors.grey.shade50,
                  ],
                ),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: BouncingScrollPhysics(),
                clipBehavior: Clip.none,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: widgets.asMap().entries.map((entry) {
                      final index = entry.key;
                      final child = entry.value;
                      
                      // Padding cố định và đồng nhất
                      // Khoảng cách cố định giữa các vòng tròn
                      return Padding(
                        padding: EdgeInsets.only(
                          left: index == 0 ? 0 : 0,
                          right: index == widgets.length - 1 ? 0 : spacing, 
                        ),
                        child: child,
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
            SizedBox(height: useCompactLayout ? 12.0 : 16.0), // Tăng khoảng cách giữa các phần
          ],
        );
      },
    );
  }
  
  Widget _buildNutritionCircle(String label, double percentage, String value, Color color, {double size = 68.0, bool useLargerFonts = false, bool useRadialGradient = false, bool showDetailLabels = false, Color backgroundColor = const Color(0xFFEEEEEE)}) {
    // Lấy giá trị và mục tiêu từ value string (VD: "120mg" -> 120)
    double actualValue = 0;
    try {
      // Trích xuất số từ chuỗi value
      final numericValue = RegExp(r'(\d+)').firstMatch(value)?.group(1);
      if (numericValue != null) {
        actualValue = double.parse(numericValue);
      }
    } catch (e) {
      print("Lỗi khi trích xuất giá trị từ chuỗi: $e");
    }
    
    // Tính mục tiêu dựa trên phần trăm
    double goalValue = actualValue / (percentage / 100);
    if (percentage <= 0) {
      goalValue = 100; // Giá trị mặc định nếu không thể tính
    }
    
    // Làm tròn goalValue
    goalValue = goalValue.roundToDouble();
    
    // Trích xuất đơn vị từ chuỗi value (VD: "120mg" -> "mg")
    String unit = "";
    final unitMatch = RegExp(r'[a-zA-Z]+').firstMatch(value);
    if (unitMatch != null) {
      unit = unitMatch.group(0) ?? "";
    }
    
    // Tính toán phần trăm và text hiển thị
    double progress = percentage / 100;
    if (progress > 1.0) progress = 1.0;
    if (progress < 0.0) progress = 0.0;
    
    // Sử dụng kích thước nhỏ hơn khi useCompactLayout là true
    final circleSize = useCompactLayout ? 58.0 : 68.0;
    
    // Tạo remaining text dạng "65/132g"
    final remainingText = "${actualValue.toInt()}/${goalValue.toInt()}$unit";
    
    return NutritionCircle(
      size: circleSize,
      value: percentage,
      max: 100.0,
      color: color,
      label: label,
      remainingText: remainingText,
      backgroundColor: color.withOpacity(0.2),
      useRadialGradient: false,
      showPercentage: true,
      icon: _getIconForLabel(label),
    );
  }
  
  Widget _buildCalorieCircle(int value, int goal, {double size = 68.0, bool useRadialGradient = false, Color backgroundColor = const Color(0xFFEEEEEE), bool showDetailLabels = false}) {
    // Tính toán phần trăm
    double percentage = value / goal * 100;
    if (percentage > 100.0) percentage = 100.0;
    if (percentage < 0.0) percentage = 0.0;
    
    // Tham số màu sắc
    final color = Colors.amber.shade600;
    
    // Sử dụng kích thước nhỏ hơn khi useCompactLayout là true
    final circleSize = useCompactLayout ? 58.0 : 68.0;
    
    // Tạo remaining text dạng "130/2000"
    final remainingText = "${value}/${goal}";
    
    return NutritionCircle(
      size: circleSize,
      value: percentage,
      max: 100.0,
      color: color,
      label: "Calo",
      remainingText: remainingText,
      backgroundColor: color.withOpacity(0.2),
      useRadialGradient: false,
      showPercentage: true,
      icon: Icons.local_fire_department,
    );
  }
  
  // Helper method để có icon phù hợp với mỗi loại dinh dưỡng
  IconData? _getIconForLabel(String label) {
    switch (label.toLowerCase()) {
      case "calo":
        return Icons.local_fire_department;
      case "chất béo":
        return Icons.water_drop;
      case "protein":
        return Icons.fitness_center;
      case "carbs":
        return Icons.eco;
      case "cholesterol":
        return Icons.healing;
      case "omega-3":
        return Icons.spa;
      case "chất xơ":
        return Icons.grass;
      case "nước":
        return Icons.water;
      case "đường":
        return Icons.cake;
      case "caffeine":
        return Icons.coffee;
      case "vitamin d":
        return Icons.wb_sunny_outlined;
      case "vitamin c":
        return Icons.local_florist;
      case "sắt":
        return Icons.power;
      case "canxi":
        return Icons.fitness_center;
      default:
        return null;
    }
  }
  
  Widget _buildBasicCircle(double value, double goal, String label, Color color, {String unit = "", bool useLargerFonts = false}) {
    double progress = value / goal;
    if (progress > 1.0) progress = 1.0;
    if (progress < 0.0) progress = 0.0;
    
    // Sử dụng kích thước nhỏ hơn khi useCompactLayout là true
    final circleSize = useCompactLayout ? 58.0 : 68.0;
    final valueFontSize = useLargerFonts ? 20.0 : 24.0;
    final goalFontSize = useLargerFonts ? 10.0 : 12.0;
    final labelFontSize = useLargerFonts ? 12.0 : 14.0;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Circle container
        Container(
          width: circleSize,
          height: circleSize,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 4,
                spreadRadius: 0,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Value
              Text(
                value.round().toString(),
                style: TextStyle(
                  fontSize: valueFontSize,
                  fontWeight: FontWeight.bold,
                  color: color,
                  height: 1.0,
                ),
              ),
              
              // Goal
              Text(
                "/${goal.round()}${unit}",
                style: TextStyle(
                  fontSize: goalFontSize,
                  color: Colors.grey.shade500,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
        
        // Label
        SizedBox(height: 4.0),
        Text(
          label,
          style: TextStyle(
            fontSize: labelFontSize,
            fontWeight: FontWeight.w500,
            color: color,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
} 