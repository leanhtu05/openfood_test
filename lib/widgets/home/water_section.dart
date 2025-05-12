import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/water_provider.dart';
import '../../utils/constants.dart';
import '../../utils/water_utils.dart';

class WaterSection extends StatelessWidget {
  const WaterSection({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<WaterProvider>(
      builder: (context, waterProvider, child) {
        final totalWater = waterProvider.totalWaterToday;
        
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header với icon và title
              Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.water.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.water_drop_rounded,
                        color: AppColors.water,
                        size: 18,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Nước uống',
                      style: AppTextStyles.heading3.copyWith(fontSize: 16),
                    ),
                    Spacer(),
                    if (totalWater > 0)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.water.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.water_drop, size: 14, color: AppColors.water),
                            SizedBox(width: 4),
                            Text(
                              '${_formatAmount(totalWater)}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.water,
                              ),
                            ),
                            Text(
                              ' mL',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.water,
                              ),
                            ),
                          ],
                        ),
                      ),
                    SizedBox(width: 8),
                    InkWell(
                      onTap: () {
                        Navigator.pushNamed(
                          context, 
                          '/combined_history',
                          arguments: {'filter': 'water'}
                        );
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Phần nội dung
              totalWater > 0
                ? _buildWaterContent(context, waterProvider)
                : _buildEmptyWaterContent(context, waterProvider),
                
              // Nút thêm nước
              Container(
                width: double.infinity,
                margin: EdgeInsets.all(16),
                child: ElevatedButton(
                  onPressed: () {
                    showWaterInputDialog(context, (int ml) async {
                      // Tạo timestamp cho ngày đã chọn
                      final now = DateTime.now();
                      final selectedDate = waterProvider.selectedDate;
                      final selectedDateTime = DateTime.parse(selectedDate);
                      final timestamp = DateTime(
                        selectedDateTime.year,
                        selectedDateTime.month,
                        selectedDateTime.day,
                        now.hour,
                        now.minute,
                        now.second,
                      );
                      
                      // Thêm dữ liệu bằng provider với timestamp tương ứng
                      await waterProvider.addWaterEntry(ml, timestamp: timestamp);
                      
                      // Thông báo để hiển thị
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Đã ghi lại uống thêm $ml mL nước'),
                          backgroundColor: AppColors.water,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      );
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.water,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Thêm nước',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }
    );
  }
  
  // Helper to format water amount with commas
  String _formatAmount(int amount) {
    return amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), 
      (Match m) => '${m[1]},'
    );
  }
  
  // Hiển thị khi không có dữ liệu nước
  Widget _buildEmptyWaterContent(BuildContext context, WaterProvider waterProvider) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 30, horizontal: 16),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.water.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.water_drop_outlined,
                size: 36,
                color: AppColors.water,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Chưa ghi nhận uống nước hôm nay',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Để duy trì sức khỏe tốt, bạn nên uống ít nhất 2 lít nước mỗi ngày',
              style: AppTextStyles.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
  
  // Hiển thị khi có dữ liệu nước
  Widget _buildWaterContent(BuildContext context, WaterProvider waterProvider) {
    final totalWater = waterProvider.totalWaterToday;
    final waterGoal = waterProvider.waterGoal;
    final lastWaterTime = waterProvider.lastWaterTime;
    
    // Định dạng thời gian lần cuối ghi nhận
    String lastRecordTime = lastWaterTime != null 
        ? '${lastWaterTime.hour.toString().padLeft(2, '0')}:${lastWaterTime.minute.toString().padLeft(2, '0')}'
        : '--:--';
    
    // Tính phần trăm đạt được
    final double percentage = totalWater / waterGoal;
    final bool isExceeded = percentage > 1.0;
    
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Water goal display
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              RichText(
                text: TextSpan(
                  style: AppTextStyles.bodyMedium,
                  children: [
                    TextSpan(
                      text: '${_formatAmount(totalWater)} ',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.water,
                      ),
                    ),
                    TextSpan(
                      text: '/ ${_formatAmount(waterGoal)} mL',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isExceeded ? Colors.green.shade50 : AppColors.water.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${(percentage * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isExceeded ? Colors.green : AppColors.water,
                  ),
                ),
              ),
            ],
          ),
          
          SizedBox(height: 12),
          
          // Thanh tiến độ
          Container(
            height: 10,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Stack(
              children: [
                FractionallySizedBox(
                  widthFactor: percentage > 1.0 ? 1.0 : percentage,
                  child: Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: isExceeded ? Colors.green : AppColors.water,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          
          // Water bottle visualization
          Container(
            height: 112,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: (totalWater / 250).ceil(),
              physics: BouncingScrollPhysics(),
              itemBuilder: (context, index) {
                return Container(
                  margin: EdgeInsets.only(right: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Icon(
                        index < (totalWater / 250).floor() 
                            ? Icons.water_drop
                            : Icons.water_drop_outlined,
                        color: AppColors.water,
                        size: 28,
                      ),
                      SizedBox(height: 3),
                      Container(
                        width: 24,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.water.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              height: index < (totalWater / 250).floor() 
                                  ? 56
                                  : (totalWater % 250) / 250 * 56,
                              decoration: BoxDecoration(
                                color: AppColors.water,
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        '250',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          
          SizedBox(height: 8),
          
          // Last record time
          Center(
            child: Text(
              'Lần cuối ghi nhận: $lastRecordTime',
              style: AppTextStyles.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
} 