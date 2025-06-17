import 'package:flutter/material.dart';
import '../../models/meal_plan.dart';
import '../../services/progressive_meal_plan_service.dart';

class ProgressiveStatusWidget extends StatelessWidget {
  final MealPlan? mealPlan;
  final VoidCallback? onGenerateMore;

  const ProgressiveStatusWidget({
    Key? key,
    this.mealPlan,
    this.onGenerateMore,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final statusMessage = ProgressiveMealPlanService.getStatusMessage(mealPlan);
    final shouldGenerateMore = ProgressiveMealPlanService.shouldGenerateMore(mealPlan);
    final availableDays = _getAvailableDaysCount();

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: shouldGenerateMore 
            ? [Colors.orange.shade50, Colors.orange.shade100]
            : [Colors.green.shade50, Colors.green.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: shouldGenerateMore 
            ? Colors.orange.shade200
            : Colors.green.shade200,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                shouldGenerateMore ? Icons.schedule : Icons.check_circle,
                color: shouldGenerateMore ? Colors.orange.shade600 : Colors.green.shade600,
                size: 20,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  statusMessage,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: shouldGenerateMore ? Colors.orange.shade800 : Colors.green.shade800,
                  ),
                ),
              ),
            ],
          ),
          
          if (availableDays > 0) ...[
            SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: Colors.grey.shade600,
                ),
                SizedBox(width: 6),
                Text(
                  'Có sẵn: $availableDays ngày',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                Spacer(),
                if (shouldGenerateMore && onGenerateMore != null)
                  TextButton.icon(
                    onPressed: onGenerateMore,
                    icon: Icon(Icons.add, size: 16),
                    label: Text('Tạo thêm'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.orange.shade700,
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    ),
                  ),
              ],
            ),
          ],
          
          if (shouldGenerateMore) ...[
            SizedBox(height: 8),
            _buildProgressBar(),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    final availableDays = _getAvailableDaysCount();
    final progress = availableDays / 7.0; // 7 ngày tối đa
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Tiến độ kế hoạch',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${(progress * 100).toInt()}%',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        SizedBox(height: 4),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.grey.shade300,
          valueColor: AlwaysStoppedAnimation<Color>(
            progress >= 1.0 ? Colors.green.shade600 : Colors.orange.shade600,
          ),
          minHeight: 6,
        ),
      ],
    );
  }

  int _getAvailableDaysCount() {
    if (mealPlan == null) return 0;
    
    final today = DateTime.now();
    int count = 0;
    
    // Kiểm tra 7 ngày tới
    for (int i = 0; i < 7; i++) {
      final checkDate = today.add(Duration(days: i));
      final dayName = _getDayName(checkDate);
      
      if (mealPlan!.weeklyPlan.containsKey(dayName) && 
          mealPlan!.weeklyPlan[dayName] != null &&
          mealPlan!.weeklyPlan[dayName]!.meals.isNotEmpty) {
        count++;
      }
    }
    
    return count;
  }

  String _getDayName(DateTime date) {
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 
      'Friday', 'Saturday', 'Sunday'
    ];
    return days[date.weekday - 1];
  }
}

// Widget hiển thị loading cho progressive planning
class ProgressivePlanningLoader extends StatefulWidget {
  final String message;
  final int currentDay;
  final int totalDays;

  const ProgressivePlanningLoader({
    Key? key,
    required this.message,
    this.currentDay = 1,
    this.totalDays = 2,
  }) : super(key: key);

  @override
  State<ProgressivePlanningLoader> createState() => _ProgressivePlanningLoaderState();
}

class _ProgressivePlanningLoaderState extends State<ProgressivePlanningLoader>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    )..repeat();
    _animation = Tween<double>(begin: 0, end: 1).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: CircularProgressIndicator(
                      value: _animation.value,
                      strokeWidth: 4,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
                      backgroundColor: Colors.blue.shade100,
                    ),
                  ),
                  Icon(
                    Icons.restaurant_menu,
                    color: Colors.blue.shade600,
                    size: 24,
                  ),
                ],
              );
            },
          ),
          SizedBox(height: 16),
          Text(
            widget.message,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade800,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            'Ngày ${widget.currentDay}/${widget.totalDays}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.flash_on, color: Colors.orange, size: 16),
              SizedBox(width: 4),
              Text(
                'Tạo nhanh, trải nghiệm tốt hơn',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
