import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/tdee_calculator.dart';
import '../providers/user_data_provider.dart';
import '../services/onboarding_service.dart';
import 'home_screen.dart';

class TDEECalculatorScreen extends StatelessWidget {
  const TDEECalculatorScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final userData = Provider.of<UserDataProvider>(context);
    
    final calculator = TDEECalculator(
      gender: userData.gender,
      age: userData.age,
      heightCm: userData.heightCm,
      weightKg: userData.weightKg,
      activityLevel: userData.activityLevel,
      goal: userData.goal,
      pace: userData.pace,
    );

    final bmr = calculator.calculateBMR();
    final tdee = calculator.calculateBaseTDEE();
    final dailyCalories = calculator.calculateDailyCalories();
    final macros = calculator.calculateMacroDistribution();
    
    return WillPopScope(
      onWillPop: () async {
        // Hiển thị dialog xác nhận khi nhấn nút back
        final shouldComplete = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Hoàn thành thiết lập'),
            content: const Text(
              'Bạn có muốn hoàn thành thiết lập và chuyển đến màn hình chính không?'
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Quay lại'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Hoàn thành'),
              ),
            ],
          ),
        ) ?? false;
        
        if (shouldComplete) {
          // Đánh dấu onboarding đã hoàn thành
          await OnboardingService.setOnboardingComplete();
          
          if (!context.mounted) return false;
          // Chuyển đến màn hình chính
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => HomeScreen()),
          );
        }
        
        // Không cho phép back nếu người dùng không chọn hoàn thành
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Tính toán TDEE'),
          backgroundColor: Colors.green,
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () async {
              // Hiển thị dialog xác nhận khi nhấn nút back
              final shouldComplete = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Hoàn thành thiết lập'),
                  content: const Text(
                    'Bạn có muốn hoàn thành thiết lập và chuyển đến màn hình chính không?'
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Quay lại'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Hoàn thành'),
                    ),
                  ],
                ),
              ) ?? false;
              
              if (shouldComplete) {
                // Ensure TDEE values are saved first
                await userData.updateTDEEValues(
                  calories: dailyCalories,
                  protein: macros['protein']!,
                  carbs: macros['carbs']!,
                  fat: macros['fat']!,
                );
                
                // Đánh dấu onboarding đã hoàn thành
                await OnboardingService.setOnboardingComplete();
                
                if (!context.mounted) return;
                // Chuyển đến màn hình chính
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => HomeScreen()),
                );
              }
            },
          ),
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Kết quả chính
              _buildResultCard(
                title: 'Lượng calo cần tiêu thụ mỗi ngày',
                value: '${dailyCalories.round()} kcal',
                color: Colors.green,
                iconData: Icons.local_fire_department,
              ),
              
              SizedBox(height: 24),
              
              // Các thông số chi tiết
              Text(
                'Thông số dinh dưỡng chi tiết',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              
              SizedBox(height: 12),
              
              // Thông số BMR và TDEE  
              _buildInfoRow('BMR (Năng lượng cơ bản)', '${bmr.round()} kcal'),
              _buildInfoRow('TDEE (Năng lượng hàng ngày)', '${tdee.round()} kcal'),
              
              SizedBox(height: 24),
              
              // Phân chia macros
              Text(
                'Phân chia macros dinh dưỡng',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              
              SizedBox(height: 12),
              
              // Hiển thị macros
              Row(
                children: [
                  Expanded(
                    child: _buildMacroCard(
                      'Protein',
                      '${macros['protein']!.round()} g',
                      Colors.blue,
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: _buildMacroCard(
                      'Carbs',
                      '${macros['carbs']!.round()} g',
                      Colors.orange,
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: _buildMacroCard(
                      'Chất béo',
                      '${macros['fat']!.round()} g',
                      Colors.red,
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: 24),
              
              // Thông tin người dùng
              Text(
                'Thông tin cá nhân',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              
              SizedBox(height: 12),
              
              // Hiển thị các thông số người dùng đã nhập
              _buildInfoRow('Giới tính', userData.gender == 'male' ? 'Nam' : 'Nữ'),
              _buildInfoRow('Tuổi', '${userData.age}'),
              _buildInfoRow('Chiều cao', '${userData.heightCm} cm'),
              _buildInfoRow('Cân nặng', '${userData.weightKg} kg'),
              _buildInfoRow('Mức độ hoạt động', userData.activityLevel),
              _buildInfoRow('Mục tiêu', userData.goal),
              _buildInfoRow('Tốc độ tăng/giảm cân', '${userData.pace} kg/tuần'),
              
              SizedBox(height: 24),
              
              // Ghi chú về cách tính
              Text(
                'Lưu ý:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              
              SizedBox(height: 8),
              
              Text(
                '- Các tính toán dựa trên công thức Mifflin-St Jeor cho BMR\n'
                '- 1kg mỡ tương đương với khoảng 7700 kcal\n'
                '- Kết quả có thể thay đổi tùy theo cơ địa cá nhân',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
              
              SizedBox(height: 32),
              
              // Nút để chuyển đến màn hình Home
              Container(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    // Ensure TDEE values are saved first
                    await userData.updateTDEEValues(
                      calories: dailyCalories,
                      protein: macros['protein']!,
                      carbs: macros['carbs']!,
                      fat: macros['fat']!,
                    );
                    
                    // Đảm bảo onboarding đã hoàn thành
                    await OnboardingService.setOnboardingComplete();
                    
                    if (!context.mounted) return;
                    // Chuyển đến màn hình Home
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => HomeScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Text(
                    'Hoàn thành và đến màn hình chính',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildResultCard({
    required String title,
    required String value,
    required Color color,
    required IconData iconData,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              iconData,
              size: 48,
              color: color,
            ),
            SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
          SizedBox(width: 8),
          Flexible(
            flex: 1,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMacroCard(String title, String value, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
} 