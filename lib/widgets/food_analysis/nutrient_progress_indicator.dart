import 'package:flutter/material.dart';

class NutrientProgressIndicator extends StatelessWidget {
  final double value;
  final double maxValue;
  final String label;
  final String unit;
  final Color color;
  final double height;
  final double width;

  const NutrientProgressIndicator({
    Key? key,
    required this.value,
    required this.maxValue,
    required this.label,
    required this.unit,
    required this.color,
    this.height = 120,
    this.width = 80,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Đảm bảo tỉ lệ không vượt quá 1.0
    final progressRatio = (value / maxValue).clamp(0.0, 1.0);
    
    return Container(
      width: width,
      child: Column(
        children: [
          // Thông tin giá trị
          Text(
            '${value.toStringAsFixed(1)}$unit',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 6),
          
          // Nhãn
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 8),
          
          // Thanh tiến trình
          Stack(
            alignment: Alignment.center,
            children: [
              // Vỏ ngoài
              Container(
                height: height,
                width: 24,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              
              // Phần đã hoàn thành
              Positioned(
                bottom: 0,
                child: Container(
                  height: height * progressRatio,
                  width: 24,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.4),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Các vạch chia
              ...List.generate(5, (index) {
                final position = index * 0.25; // 0.0, 0.25, 0.5, 0.75, 1.0
                final isAtProgress = (progressRatio >= position && 
                                     progressRatio < position + 0.25);
                
                return Positioned(
                  bottom: height * position,
                  child: Container(
                    height: 1,
                    width: 18,
                    color: isAtProgress 
                        ? Colors.white.withOpacity(0.8)
                        : Colors.grey.withOpacity(0.3),
                  ),
                );
              }),
              
              // Kiểm tra nếu giá trị gần đạt mục tiêu (>90%)
              if (progressRatio > 0.9)
                Positioned(
                  top: 4,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.4),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.check,
                      color: color,
                      size: 12,
                    ),
                  ),
                ),
            ],
          ),
          
          SizedBox(height: 4),
          
          // Hiển thị phần trăm
          Text(
            '${(progressRatio * 100).toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
} 