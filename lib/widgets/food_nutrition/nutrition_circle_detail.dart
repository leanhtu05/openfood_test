import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import '../../providers/food_provider.dart';
import '../../providers/user_data_provider.dart';
import '../../utils/tdee_calculator.dart';

class NutritionCircleDetail extends StatefulWidget {
  final String value;
  final String total;
  final Color color;
  final String remaining;
  final double progress;
  final Key? circleKey;
  final String label;
  final String? tooltipMessage;
  final Function(Map<String, double>)? onNutritionChanged;
  final bool showEmptyValues;
  final String nutrientType;

  const NutritionCircleDetail({
    Key? key,
    required this.value,
    required this.total,
    required this.color,
    required this.remaining,
    required this.progress,
    this.circleKey,
    this.label = '',
    this.tooltipMessage,
    this.onNutritionChanged,
    this.showEmptyValues = true,
    this.nutrientType = '',
  }) : super(key: key);

  @override
  State<NutritionCircleDetail> createState() => _NutritionCircleDetailState();
}

class _NutritionCircleDetailState extends State<NutritionCircleDetail> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _progressAnimation;
  late Animation<double> _fadeAnimation;
  
  double _syncedGoal = 0;
  double _calculatedProgress = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500),
    );
    
    _calculatedProgress = widget.progress > 1.0 ? 1.0 : widget.progress;
    
    _progressAnimation = Tween<double>(
      begin: 0,
      end: _calculatedProgress,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Interval(0.0, 0.5, curve: Curves.easeIn),
    ));
    
    _animationController.forward();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncWithTDEEGoals();
  }

  @override
  void didUpdateWidget(NutritionCircleDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nutrientType != widget.nutrientType) {
      _syncWithTDEEGoals();
    }
    
    if (oldWidget.progress != widget.progress || _calculatedProgress != widget.progress) {
      _calculatedProgress = widget.progress > 1.0 ? 1.0 : widget.progress;
      
      _progressAnimation = Tween<double>(
        begin: oldWidget.progress > 1.0 ? 1.0 : oldWidget.progress,
        end: _calculatedProgress,
      ).animate(CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ));
      
      _animationController.forward(from: 0.0);
    }
  }

  void _syncWithTDEEGoals() {
    if (widget.nutrientType.isEmpty) return;
    
    final userDataProvider = Provider.of<UserDataProvider>(context, listen: false);
    final calculator = TDEECalculator(
      gender: userDataProvider.gender,
      age: userDataProvider.age,
      heightCm: userDataProvider.heightCm,
      weightKg: userDataProvider.weightKg,
      activityLevel: userDataProvider.activityLevel,
      goal: userDataProvider.goal,
      pace: userDataProvider.pace,
    );
    
    final dailyCalories = calculator.calculateDailyCalories();
    
    final macros = calculator.calculateMacroDistribution();
    
    switch (widget.nutrientType) {
      case 'calories':
        _syncedGoal = dailyCalories;
        break;
      case 'protein':
        _syncedGoal = macros['protein'] ?? 0;
        break;
      case 'carbs':
        _syncedGoal = macros['carbs'] ?? 0;
        break;
      case 'fat':
        _syncedGoal = macros['fat'] ?? 0;
        break;
      default:
        return;
    }
    
    if (_syncedGoal > 0 && _syncedGoal != double.tryParse(widget.total)) {
      print('Synced ${widget.nutrientType} goal: $_syncedGoal');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool showCircle = widget.showEmptyValues || double.tryParse(widget.value) != 0;

    final Color brighterColor = Color.lerp(widget.color, Colors.white, 0.3)!;
    
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.label.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 2.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade700,
                      ),
                      softWrap: true,
                    ),
                  ),
                  if (widget.tooltipMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 4.0),
                      child: Tooltip(
                        message: widget.tooltipMessage!,
                        child: Icon(Icons.info_outline, 
                                size: 16, 
                                color: Colors.grey.shade500),
                      ),
                    ),
                ],
              ),
            ),

          AnimatedBuilder(
            animation: _progressAnimation,
            builder: (context, child) {
              return LayoutBuilder(
                builder: (context, constraints) {
                  final circleSize = constraints.maxWidth * 0.5;
                  
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      if (showCircle) ... [
                        Container(
                          width: circleSize,
                          height: circleSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                        
                        Container(
                          width: circleSize - 2,
                          height: circleSize - 2,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(
                              color: Colors.grey.shade200,
                              width: 1,
                            ),
                          ),
                        ),
                        
                        CustomPaint(
                          key: widget.circleKey,
                          size: Size(circleSize - 2, circleSize - 2),
                          painter: CircleProgressPainter(
                            progress: _progressAnimation.value,
                            color: widget.color,
                            brighterColor: brighterColor,
                            strokeWidth: circleSize * 0.1,
                          ),
                        ),
                        
                        if (_progressAnimation.value > 0.05)
                          Positioned(
                            left: (circleSize / 2) + ((circleSize - 10) / 2 - 5) * math.cos((_progressAnimation.value * 2 * math.pi) - math.pi/2),
                            top: (circleSize / 2) + ((circleSize - 10) / 2 - 5) * math.sin((_progressAnimation.value * 2 * math.pi) - math.pi/2),
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: widget.color,
                                boxShadow: [
                                  BoxShadow(
                                    color: widget.color.withOpacity(0.7),
                                    blurRadius: 3,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.value,
                              style: TextStyle(
                                fontSize: circleSize * 0.22,
                                fontWeight: FontWeight.bold,
                                color: widget.color,
                              ),
                            ),
                            Text(
                              widget.total,
                              style: TextStyle(
                                fontSize: circleSize * 0.13,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                              softWrap: true,
                            ),
                          ],
                        ),
                      ],
                      if (!showCircle)
                        Text(
                          "${widget.label}: ${widget.value}/${widget.total}",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                    ],
                  );
                },
              );
            },
          ),
          SizedBox(height: 2),
          if (showCircle && widget.remaining.isNotEmpty)
            LayoutBuilder(
              builder: (context, constraints) {
                return Container(
                  width: constraints.maxWidth * 1.2,
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: widget.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: widget.color.withOpacity(0.2),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    widget.remaining,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: widget.color,
                    ),
                    softWrap: true,
                    textAlign: TextAlign.center,
                  ),
                );
              }
            ),
        ],
      ),
    );
  }

  double getSyncedGoal() {
    return _syncedGoal;
  }

  void updateWithNutritionInfo(Map<String, double> nutritionInfo) {
    setState(() {
      // ... code hiện tại ...
    });
    
    if (widget.onNutritionChanged != null) {
      widget.onNutritionChanged!(nutritionInfo);
      
      // Nếu NutritionCircleDetail có truy cập vào FoodProvider
      // thì cần thêm dòng sau:
      // final foodProvider = Provider.of<FoodProvider>(context, listen: false);
      // foodProvider.clearNutritionCache();
    }
  }
}

class CircleProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color brighterColor;
  final double strokeWidth;

  CircleProgressPainter({
    required this.progress,
    required this.color,
    required this.brighterColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final Rect rect = Rect.fromCircle(center: center, radius: radius);
    final gradient = SweepGradient(
      colors: [brighterColor, color],
      startAngle: -math.pi / 2,
      endAngle: 3 * math.pi / 2,
      tileMode: TileMode.clamp,
    );

    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      progress * 2 * math.pi,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(CircleProgressPainter oldDelegate) {
    return oldDelegate.progress != progress || 
           oldDelegate.color != color ||
           oldDelegate.strokeWidth != strokeWidth;
  }
} 