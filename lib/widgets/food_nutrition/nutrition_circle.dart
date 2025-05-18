import 'package:flutter/material.dart';
import 'dart:math';

class NutritionCircle extends StatefulWidget {
  final double size;
  final double value;
  final double max;
  final Color color;
  final String label;
  final String remainingText;
  final Color backgroundColor;
  final bool showLabel;
  final bool useRadialGradient;
  final bool showPercentage;
  final IconData? icon;
  final Key? circleKey;
  final String? tooltipMessage;
  final bool hideWhenZero;
  final bool showTotalValue;
  final String? unitLabel;
  final String? tdeeGoal;

  const NutritionCircle({
    Key? key,
    required this.value,
    required this.max,
    required this.color,
    required this.label,
    this.size = 70,
    this.remainingText = '',
    this.backgroundColor = const Color(0xFFEEEEEE),
    this.showLabel = true,
    this.useRadialGradient = false,
    this.showPercentage = true,
    this.icon,
    this.circleKey,
    this.tooltipMessage,
    this.hideWhenZero = false,
    this.showTotalValue = false,
    this.unitLabel,
    this.tdeeGoal,
  }) : super(key: key);

  @override
  State<NutritionCircle> createState() => _NutritionCircleState();
}

class _NutritionCircleState extends State<NutritionCircle> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _progressAnimation;
  late Animation<double> _fadeAnimation;
  late double _percentage;
  bool _isCompleted = false;
  Animation<double>? _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _percentage = widget.max > 0 ? (widget.value / widget.max).clamp(0.0, 1.0) : 0.0;
    
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500),
    );
    
    _progressAnimation = Tween<double>(
      begin: 0,
      end: _percentage,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Interval(0.0, 0.6, curve: Curves.easeIn),
    ));
    
    _setupPulseAnimation();
    
    _animationController.forward();
    
    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _isCompleted = true;
        });
      }
    });
  }
  
  void _setupPulseAnimation() {
    if (widget.value / widget.max >= 0.85) {
      _pulseAnimation = TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween<double>(begin: 1.0, end: 1.05)
              .chain(CurveTween(curve: Curves.easeInOut)),
          weight: 50,
        ),
        TweenSequenceItem(
          tween: Tween<double>(begin: 1.05, end: 1.0)
              .chain(CurveTween(curve: Curves.easeInOut)),
          weight: 50,
        ),
      ]).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Interval(0.8, 1.0),
        ),
      );
    }
  }
  
  @override
  void didUpdateWidget(NutritionCircle oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (oldWidget.value != widget.value || oldWidget.max != widget.max) {
      final newPercentage = widget.max > 0 ? (widget.value / widget.max).clamp(0.0, 1.0) : 0.0;
      
      _progressAnimation = Tween<double>(
        begin: _percentage,
        end: newPercentage,
      ).animate(CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutBack,
      ));
      
      _percentage = newPercentage;
      _isCompleted = false;
      _setupPulseAnimation();
      _animationController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final percentage = widget.max > 0 ? (widget.value / widget.max).clamp(0.0, 1.0) : 0.0;
    final percentText = '${(percentage * 100).round()}%';
    
    if (widget.hideWhenZero && widget.value == 0) {
      return SizedBox.shrink();
    }
    
    if (widget.value == 0 && !widget.hideWhenZero) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                widget.label,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (widget.tooltipMessage != null)
              Padding(
                padding: const EdgeInsets.only(left: 4.0),
                child: Tooltip(
                  message: widget.tooltipMessage!,
                  child: Icon(Icons.info_outline, size: 14, color: Colors.grey[400]),
                ),
              ),
            Text(
              ": 0",
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }
    
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SizedBox(
        height: 120,
        child: SingleChildScrollView(
          physics: NeverScrollableScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  final scaleFactor = _isCompleted && _pulseAnimation != null 
                      ? _pulseAnimation!.value 
                      : 1.0;
                  
                  return Transform.scale(
                    scale: scaleFactor,
                    child: SizedBox(
                      width: widget.size,
                      height: widget.size,
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: widget.size,
                            height: widget.size,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.transparent,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                          
                          CustomPaint(
                            size: Size(widget.size, widget.size),
                            painter: CircleBackgroundPainter(
                              backgroundColor: widget.backgroundColor.withOpacity(0.3),
                              strokeWidth: 8.0,
                            ),
                          ),
                          
                          CustomPaint(
                            key: widget.circleKey,
                            size: Size(widget.size, widget.size),
                            painter: CircleProgressPainter(
                              percentage: _progressAnimation.value,
                              color: widget.color,
                              useRadialGradient: widget.useRadialGradient,
                              strokeWidth: 8.0,
                            ),
                          ),
                          
                          Container(
                            width: widget.size * 0.80,
                            height: widget.size * 0.80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: widget.color.withOpacity(0.1),
                                  blurRadius: 2,
                                  spreadRadius: 0,
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (widget.icon != null) Icon(
                                  widget.icon,
                                  size: widget.size * 0.28,
                                  color: widget.color,
                                ),
                                
                                if (widget.showPercentage) Text(
                                  percentText,
                                  style: TextStyle(
                                    fontSize: widget.size * 0.24,
                                    fontWeight: FontWeight.bold,
                                    color: widget.color,
                                    height: 1.0,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                
                                if (!widget.showPercentage) Text(
                                  widget.value.round().toString(),
                                  style: TextStyle(
                                    fontSize: widget.size * 0.22,
                                    fontWeight: FontWeight.bold,
                                    color: widget.color,
                                    height: 1.1,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                
                                if (widget.icon != null)
                                  Padding(
                                    padding: EdgeInsets.only(top: 2),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: List.generate(
                                        3,
                                        (index) => Container(
                                          width: 3,
                                          height: 3,
                                          margin: EdgeInsets.symmetric(horizontal: 1),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: widget.color.withOpacity(0.4),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
              ),
              
              if (widget.showLabel)
                Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          widget.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                          softWrap: true,
                        ),
                      ),
                      if (widget.tooltipMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 4.0),
                          child: Tooltip(
                            message: widget.tooltipMessage!,
                            child: Icon(Icons.info_outline, size: 12, color: Colors.grey[400]),
                          ),
                        ),
                    ],
                  ),
                ),
                
              if (widget.showTotalValue)
                Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Container(
                    width: widget.size * 1.8,
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: widget.color.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${widget.value.round()} / ${widget.max.round()}${widget.unitLabel != null ? ' ${widget.unitLabel}' : ''}',
                      style: TextStyle(
                        fontSize: 11,
                        color: widget.color,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                      softWrap: true,
                    ),
                  ),
                ),
                
              if (widget.tdeeGoal != null)
                Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Container(
                    width: widget.size * 1.5,
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: widget.color.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'TDEE: ${widget.tdeeGoal}',
                      style: TextStyle(
                        fontSize: 10,
                        color: widget.color,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                
              if (widget.remainingText.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Container(
                    width: widget.size * 1.5,
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: widget.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: widget.color.withOpacity(0.2),
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      widget.remainingText,
                      style: TextStyle(
                        fontSize: 10,
                        color: widget.color,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                      softWrap: true,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class CircleBackgroundPainter extends CustomPainter {
  final Color backgroundColor;
  final double strokeWidth;
  
  CircleBackgroundPainter({
    required this.backgroundColor,
    this.strokeWidth = 4.0,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
      
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - (paint.strokeWidth / 2);
    
    canvas.drawCircle(center, radius, paint);
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CircleProgressPainter extends CustomPainter {
  final double percentage;
  final Color color;
  final bool useRadialGradient;
  final double strokeWidth;
  
  CircleProgressPainter({
    required this.percentage,
    required this.color,
    this.useRadialGradient = false,
    this.strokeWidth = 4.0,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    
    if (useRadialGradient) {
      final Color brighterColor = Color.lerp(color, Colors.white, 0.3)!;
      
      paint.shader = SweepGradient(
        colors: [brighterColor, color],
        stops: [0.0, 1.0],
        startAngle: -pi / 2,
        endAngle: 3 * pi / 2,
        tileMode: TileMode.clamp,
      ).createShader(Rect.fromCircle(
        center: Offset(size.width / 2, size.height / 2),
        radius: size.width / 2,
      ));
    } else {
      paint.color = color;
    }
    
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - (paint.strokeWidth / 2);
    
    const startAngle = -pi / 2;
    
    final sweepAngle = 2 * pi * percentage;
    
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      paint,
    );
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class ShimmerCircle extends StatefulWidget {
  final double size;
  
  const ShimmerCircle({
    Key? key,
    this.size = 70,
  }) : super(key: key);
  
  @override
  _ShimmerCircleState createState() => _ShimmerCircleState();
}

class _ShimmerCircleState extends State<ShimmerCircle> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    
    _animation = Tween<double>(begin: 0.0, end: 2 * pi).animate(_controller);
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(widget.size, widget.size),
                painter: CircleBackgroundPainter(
                  backgroundColor: Colors.grey.shade200,
                  strokeWidth: 6.0,
                ),
              ),
              
              AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return CustomPaint(
                    size: Size(widget.size, widget.size),
                    painter: ShimmerCirclePainter(
                      animationValue: _animation.value,
                      strokeWidth: 6.0,
                    ),
                  );
                },
              ),
              
              Container(
                width: widget.size * 0.75,
                height: widget.size * 0.75,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        
        Padding(
          padding: EdgeInsets.only(top: 6),
          child: Container(
            width: widget.size * 0.8,
            height: 12,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
      ],
    );
  }
}

class ShimmerCirclePainter extends CustomPainter {
  final double animationValue;
  final double strokeWidth;
  
  ShimmerCirclePainter({
    required this.animationValue,
    this.strokeWidth = 4.0,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
      
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - (paint.strokeWidth / 2);
    
    paint.shader = SweepGradient(
      colors: [
        Colors.grey.shade300,
        Colors.grey.shade100,
        Colors.grey.shade300,
      ],
      stops: [0.0, 0.5, 1.0],
      startAngle: animationValue,
      endAngle: animationValue + pi,
      tileMode: TileMode.clamp,
    ).createShader(Rect.fromCircle(
      center: center,
      radius: radius,
    ));
    
    canvas.drawCircle(center, radius, paint);
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
} 