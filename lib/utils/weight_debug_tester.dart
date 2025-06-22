import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_data_provider.dart' as udp;

/// Utility class để debug và test giá trị cân nặng
class WeightDebugTester {
  
  /// Test và hiển thị tất cả giá trị cân nặng liên quan
  static void debugWeightValues(BuildContext context) {
    final userDataProvider = Provider.of<udp.UserDataProvider>(context, listen: false);
    
    print('=== 🔍 WEIGHT DEBUG TEST ===');
    print('UserDataProvider.weightKg: ${userDataProvider.weightKg} kg');
    print('UserDataProvider.targetWeightKg: ${userDataProvider.targetWeightKg} kg');
    print('UserDataProvider.goal: ${userDataProvider.goal}');
    print('UserDataProvider.pace: ${userDataProvider.pace} kg/tuần');
    print('UserDataProvider.name: ${userDataProvider.name}');
    print('UserDataProvider.age: ${userDataProvider.age}');
    print('UserDataProvider.heightCm: ${userDataProvider.heightCm} cm');
    print('UserDataProvider.gender: ${userDataProvider.gender}');
    print('UserDataProvider.activityLevel: ${userDataProvider.activityLevel}');
    print('UserDataProvider.tdeeCalories: ${userDataProvider.tdeeCalories} kcal');
    print('=== END WEIGHT DEBUG ===');
  }
  
  /// Kiểm tra xem có sự khác biệt giữa dữ liệu lưu trữ và hiển thị không
  static Future<void> compareStoredVsDisplayedWeight(BuildContext context) async {
    final userDataProvider = Provider.of<udp.UserDataProvider>(context, listen: false);
    
    print('=== 🔍 WEIGHT COMPARISON TEST ===');
    
    // Lấy dữ liệu từ SharedPreferences
    await userDataProvider.loadUserData();
    
    print('Sau khi load từ SharedPreferences:');
    print('- weightKg: ${userDataProvider.weightKg} kg');
    print('- targetWeightKg: ${userDataProvider.targetWeightKg} kg');
    
    // Kiểm tra xem có phải 63.1 kg không
    if (userDataProvider.weightKg == 63.1) {
      print('✅ Cân nặng ĐÚNG: 63.1 kg');
    } else {
      print('❌ Cân nặng SAI: Expected 63.1 kg, Got ${userDataProvider.weightKg} kg');
    }
    
    print('=== END COMPARISON ===');
  }
  
  /// Cập nhật cân nặng thành 63.1 kg nếu cần
  static Future<void> fixWeightTo63Point1(BuildContext context) async {
    final userDataProvider = Provider.of<udp.UserDataProvider>(context, listen: false);
    
    print('=== 🔧 FIXING WEIGHT TO 63.1 KG ===');
    
    // Cập nhật cân nặng
    userDataProvider.setWeight(63.1);
    
    // Lưu dữ liệu
    await userDataProvider.saveUserData();
    
    print('✅ Đã cập nhật cân nặng thành 63.1 kg');
    print('Kiểm tra lại: ${userDataProvider.weightKg} kg');
    
    print('=== END FIX ===');
  }
  
  /// Widget để hiển thị debug info trực tiếp trên UI
  static Widget buildDebugWidget(BuildContext context) {
    return Consumer<udp.UserDataProvider>(
      builder: (context, userDataProvider, child) {
        return Container(
          padding: EdgeInsets.all(16),
          margin: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.yellow[100],
            border: Border.all(color: Colors.orange),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '🔍 WEIGHT DEBUG INFO',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.red[700],
                ),
              ),
              SizedBox(height: 8),
              Text('Current Weight: ${userDataProvider.weightKg} kg'),
              Text('Target Weight: ${userDataProvider.targetWeightKg} kg'),
              Text('Goal: ${userDataProvider.goal}'),
              Text('Pace: ${userDataProvider.pace} kg/week'),
              Text('TDEE: ${userDataProvider.tdeeCalories} kcal'),
              SizedBox(height: 8),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: () => debugWeightValues(context),
                    child: Text('Debug Log'),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => compareStoredVsDisplayedWeight(context),
                    child: Text('Compare'),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => fixWeightTo63Point1(context),
                    child: Text('Fix to 63.1'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
