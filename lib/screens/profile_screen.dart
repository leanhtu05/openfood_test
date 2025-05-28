import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../utils/constants.dart';
import 'package:provider/provider.dart';
import '../providers/user_data_provider.dart';
import '../utils/tdee_calculator.dart';
import '../services/firestore_service.dart';
// Add imports for onboarding pages
import '../screens/onboarding/activity_level_page.dart';
import '../screens/onboarding/health_condition_page.dart';
import '../screens/onboarding/target_weight_page.dart';
import '../screens/onboarding/weight_gain_pace_page.dart';
import '../styles/onboarding_styles.dart';
import '../screens/settings_screen.dart';
import 'onboarding/gender_selection_page.dart';
import 'onboarding/age_selection_page.dart';
import 'onboarding/height_selection_page.dart';
import 'onboarding/weight_selection_page.dart';
import 'onboarding/activity_level_page.dart';
import 'onboarding/diet_goal_page.dart';
import '../services/auth_service.dart';

// Add extension to add custom properties to UserDataProvider
extension UserDataProviderExtension on UserDataProvider {
  String get name => "Lê Anh Tú"; // Default name if not available
  double get initialWeight => weightKg; // Use current weight if initial not set
  double get targetWeight => targetWeightKg; // Use the proper getter from UserDataProvider
  
  void updateWeight(double weight) {
    // Call the setWeight method from UserDataProvider
    setWeight(weight);
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Biến để lưu trữ dữ liệu người dùng
  double _weight = 54.0;
  String _name = "Lê Anh Tú";
  int _age = 23;
  double _tdee = 2275;
  double _targetCalories = 2782;
  double _weeklyWeightChange = 0.46;
  List<FlSpot> _weightHistory = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // Tải dữ liệu người dùng từ Provider
  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final userDataProvider = Provider.of<UserDataProvider>(context, listen: false);
      final authService = Provider.of<AuthService>(context, listen: false);
      
      // Kiểm tra và đồng bộ dữ liệu từ Firebase nếu cần
      if (authService.isAuthenticated) {
        // Đồng bộ dữ liệu từ Firebase vào UserDataProvider
        try {
          await authService.syncUserDataToProvider(userDataProvider);
          print('✅ Đã đồng bộ dữ liệu từ Firebase vào UserDataProvider trong ProfileScreen');
        } catch (e) {
          print('⚠️ Lỗi khi đồng bộ dữ liệu từ Firebase: $e');
          // Tiếp tục sử dụng dữ liệu hiện có trong UserDataProvider
        }
      }
      
      // Cập nhật thông tin cá nhân từ Provider
      final weight = userDataProvider.weightKg;
      final height = userDataProvider.heightCm;
      final age = userDataProvider.age;
      final gender = userDataProvider.gender;
      final activity = userDataProvider.activityLevel;
      final goal = userDataProvider.goal;
      final pace = userDataProvider.pace;
      final userName = userDataProvider.name;
      
      // Tính toán TDEE và các giá trị dinh dưỡng
      final calculator = TDEECalculator(
        gender: gender,
        age: age,
        heightCm: height,
        weightKg: weight,
        activityLevel: activity,
        goal: goal,
        pace: pace,
      );
      
      // Tính toán TDEE và nhu cầu calo hàng ngày
      final tdee = calculator.calculateBaseTDEE();
      
      // Sử dụng giá trị từ getConsistentCalorieGoal() để đảm bảo tính nhất quán
      final dailyCalories = userDataProvider.getConsistentCalorieGoal();
      
      // Tạo giả lịch sử cân nặng nếu không có dữ liệu thực
      final spotList = <FlSpot>[];
      // Lịch sử 7 ngày từ hiện tại (giả lập)
      final baseWeight = weight;
      double changeRate = pace;
      
      if (goal == "Giảm cân") {
        changeRate = -changeRate;
      } else if (goal == "Duy trì cân nặng") {
        changeRate = 0;
      }
      
      // Tạo lịch sử cân nặng trong 7 tuần gần đây (mô phỏng)
      final weeklyChange = changeRate / 7.0;
      for (int i = 0; i < 7; i++) {
        final weekWeight = baseWeight - (weeklyChange * (6 - i) * 7);
        spotList.add(FlSpot(i.toDouble(), weekWeight));
      }
        
      // Cập nhật dữ liệu
      setState(() {
        _weight = weight;
        _age = age;
        _name = userName.isNotEmpty ? userName : "Người dùng";
        _tdee = tdee;
        _targetCalories = dailyCalories.toDouble();
        _weeklyWeightChange = pace;
        _weightHistory = spotList;
        _isLoading = false;
      });
      
      print('✅ Đã tải dữ liệu người dùng thành công trong ProfileScreen');
      print('👤 Tên: $_name, Tuổi: $_age, Cân nặng: $_weight kg');
      print('🔥 TDEE: $_tdee kcal, Mục tiêu: $_targetCalories kcal');
    } catch (e) {
      print('❌ Lỗi khi tải dữ liệu người dùng: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
        ),
      );
    }
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildUserInfoHeader(),
          SizedBox(height: 24),
          _buildGoalOverview(),
          SizedBox(height: 24),
          _buildWeightUpdateNotification(),
          SizedBox(height: 24),
          _buildWeightHistoryChart(),
        ],
      ),
    );
  }

  // Card thông tin người dùng
  Widget _buildUserInfoHeader() {
    // Tính toán phần trăm hoàn thành dựa trên mục tiêu
    final userDataProvider = Provider.of<UserDataProvider>(context, listen: false);
    final targetWeight = userDataProvider.targetWeight;
    
    double progressValue = 0.7; // Giá trị mặc định
    
    if (targetWeight > 0) {
      final startWeight = userDataProvider.initialWeight > 0 ? 
          userDataProvider.initialWeight : userDataProvider.weightKg;
      
      final totalChange = targetWeight - startWeight;
      final currentChange = _weight - startWeight;
      
      if (totalChange != 0) {
        progressValue = currentChange / totalChange;
        
        // Giới hạn giá trị từ 0 đến 1
        progressValue = progressValue.clamp(0.0, 1.0);
      }
    }
    
    return Card(
      elevation: 4,
      shadowColor: Colors.black.withAlpha(51),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Weight info
                Flexible(
                  flex: 1,
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.scale, size: 32, color: AppColors.textPrimary),
                    SizedBox(height: 4),
                    Text(
                      "${_weight.toStringAsFixed(1)} kg",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                  ),
                ),
                
                // User info with avatar
                Flexible(
                  flex: 2,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.grey.shade300,
                      child: Icon(Icons.person, size: 24, color: Colors.grey.shade700),
                    ),
                    SizedBox(width: 12),
                      Flexible(
                        child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "$_name,",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                              overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          "$_age",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                        ),
                    ),
                  ],
                  ),
                ),
                
                // Settings button
                IconButton(
                  icon: Icon(Icons.settings, color: AppColors.textSecondary),
                  onPressed: () {
                    // Navigate to settings screen
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => SettingsScreen(),
                      ),
                    ).then((_) => _loadUserData());
                  },
                ),
              ],
            ),
            SizedBox(height: 16),
            
            // Progress indicator
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progressValue,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00BFA6)),
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Tổng quan mục tiêu
  Widget _buildGoalOverview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.restaurant_menu, size: 24, color: AppColors.textPrimary),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  "Tổng quan mục tiêu",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _navigateToProfileUpdate(),
                icon: Icon(Icons.edit, size: 16),
                label: Text("Cập nhật"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size(0, 0),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 12),
        
        // Three cards in a row
        Row(
          children: [
            Expanded(
              child: _buildInfoCard(
                icon: Icons.local_fire_department,
                iconColor: Colors.orange,
                title: "TDEE",
                value: "${_tdee.round()} kcal",
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _buildInfoCard(
                icon: Icons.speed,
                iconColor: Colors.blue,
                title: _getWeightChangeText(),
                value: "${_weeklyWeightChange} kg/tuần",
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _buildInfoCard(
                icon: Icons.whatshot,
                iconColor: Colors.deepOrange,
                title: "Mục tiêu",
                value: "${_targetCalories.round()} kcal",
              ),
            ),
          ],
        ),
        SizedBox(height: 24),
        
        // Weight trend line chart
        Container(
          height: 220,
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(13),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              _buildWeightTrendChart(),
              Positioned(
                top: 70,
                right: 40,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withAlpha(26),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withAlpha(128), width: 1),
                  ),
                  child: Text(
                    'Thế a chiui',
                    style: TextStyle(
                      color: Colors.blue,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Helper to format weight change text
  String _getWeightChangeText() {
    final userDataProvider = Provider.of<UserDataProvider>(context, listen: false);
    final goal = userDataProvider.goal;
    
    if (goal == "Tăng cân") {
      return "Tăng cân";
    } else if (goal == "Giảm cân") {
      return "Giảm cân";
    } else {
      return "Duy trì";
    }
  }

  // Helper method to build info cards
  Widget _buildInfoCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: iconColor, size: 24),
            SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // Weight trend chart
  Widget _buildWeightTrendChart() {
    // Tính toán min và max cho biểu đồ
    double minY = 50.0;
    double maxY = 56.0;
    
    if (_weightHistory.isNotEmpty) {
      // Tìm giá trị min và max từ dữ liệu
      final values = _weightHistory.map((spot) => spot.y).toList();
      minY = values.reduce((min, val) => min < val ? min : val) - 2;
      maxY = values.reduce((max, val) => max > val ? max : val) + 2;
    }
    
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: 1,
          verticalInterval: 1,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.shade200,
              strokeWidth: 1,
            );
          },
          getDrawingVerticalLine: (value) {
            return FlLine(
              color: Colors.grey.shade200,
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1,
              getTitlesWidget: (value, meta) {
                const titles = ['tháng 5 10', '', 'Th6', '', 'Th7', '', 'Th8 09'];
                int index = value.toInt();
                if (index >= 0 && index < titles.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      titles[index],
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 10,
                      ),
                    ),
                  );
                }
                return const SizedBox();
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toInt()} kg',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 10,
                  ),
                );
              },
              reservedSize: 42,
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.grey.shade300, width: 1),
        ),
        minX: 0,
        maxX: 6,
        minY: minY,
        maxY: maxY,
        // Add a special line for the "Thế a chiui" point
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y: _weightHistory.isNotEmpty ? _weightHistory[4].y : 53.5,
              color: Colors.blue.withAlpha(128),
              strokeWidth: 1,
              dashArray: [5, 5],
            ),
          ],
        ),
        lineBarsData: [
          LineChartBarData(
            spots: _weightHistory.isEmpty ? [
              FlSpot(0, 52),
              FlSpot(1, 52.5),
              FlSpot(2, 53),
              FlSpot(3, 52.8),
              FlSpot(4, 53.5),
              FlSpot(5, 53.8),
              FlSpot(6, 54),
            ] : _weightHistory,
            isCurved: true,
            gradient: LinearGradient(
              colors: [Colors.orange, Colors.green],
            ),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: Colors.white,
                  strokeWidth: 2,
                  strokeColor: index == 4 ? Colors.blue : barData.gradient!.colors[1],
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  Colors.orange.withAlpha(77),
                  Colors.green.withAlpha(77),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Thông báo cập nhật cân nặng
  Widget _buildWeightUpdateNotification() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.auto_awesome,
            color: Color(0xFF1565C0),
            size: 24,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "AI muốn bạn cập nhật cân nặng",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1565C0),
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  "Để trí tuệ nhân tạo tính toán nhu cầu calo và chất dinh dưỡng hàng ngày của bạn, vui lòng cập nhật cân nặng của bạn",
                  style: TextStyle(
                    color: Color(0xFF1565C0),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Biểu đồ lịch sử cân nặng
  Widget _buildWeightHistoryChart() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    "Cân nặng của bạn",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    // Show weight update dialog
                    _showWeightUpdateDialog();
                  },
                  icon: Icon(Icons.add, size: 16),
                  label: Text("Cập nhật"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Color(0xFF00BFA6),
                    side: BorderSide(color: Color(0xFF00BFA6)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size(0, 0),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: _buildAreaChart(),
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "🏖️ Kỳ nghỉ",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            // Thêm nút tính toán lại TDEE
            ListTile(
              leading: Icon(Icons.refresh, color: Colors.green),
              title: Text('Tính toán lại TDEE'),
              subtitle: Text('Cập nhật lại mục tiêu calo dựa trên thông tin hiện tại'),
              onTap: () async {
                // Hiển thị dialog xác nhận
                final shouldRecalculate = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('Tính toán lại TDEE'),
                    content: Text(
                      'Bạn có muốn tính toán lại mục tiêu calo dựa trên thông tin hiện tại không?\n\n'
                      'Thao tác này sẽ cập nhật mục tiêu calo và các chỉ số dinh dưỡng của bạn.'
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: Text('Hủy'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: Text('Tính toán lại'),
                      ),
                    ],
                  ),
                ) ?? false;
                
                if (shouldRecalculate) {
                  // Lấy UserDataProvider
                  final userDataProvider = Provider.of<UserDataProvider>(context, listen: false);
                  
                  // Hiển thị loading indicator
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                  
                  // Tính toán lại TDEE
                  await _recalculateTDEEAfterWeightUpdate(userDataProvider, _weight);
                  
                  // Đóng loading indicator
                  Navigator.of(context).pop();
                  
                  // Hiển thị kết quả
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Đã cập nhật mục tiêu calo: ${userDataProvider.tdeeCalories.round()} kcal'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // Dialog cập nhật cân nặng
  void _showWeightUpdateDialog() {
    double newWeight = _weight;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cập nhật cân nặng'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Cân nặng hiện tại: $_weight kg'),
            SizedBox(height: 16),
            TextField(
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Cân nặng mới (kg)',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                try {
                  newWeight = double.parse(value);
                } catch (e) {
                  // Không làm gì nếu giá trị không hợp lệ
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              // Cập nhật cân nặng mới
              final userDataProvider = Provider.of<UserDataProvider>(context, listen: false);
              userDataProvider.updateWeight(newWeight);
              
              // Lưu lên Firestore nếu có thể
              try {
                FirestoreService().saveUserProfile({'weightKg': newWeight});
              } catch (e) {
                print('Không thể lưu cân nặng lên Firestore: $e');
              }
              
              // Recalculate TDEE after weight update
              _recalculateTDEEAfterWeightUpdate(userDataProvider, newWeight);
              
              // Cập nhật lại dữ liệu trên giao diện
              _loadUserData();
              
              Navigator.pop(context);
              
              // Hiển thị thông báo thành công
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Đã cập nhật cân nặng thành công!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            child: Text('Cập nhật'),
          ),
        ],
      ),
    );
  }

  // Recalculate TDEE after weight update
  Future<void> _recalculateTDEEAfterWeightUpdate(UserDataProvider userDataProvider, double newWeight) async {
    // Sử dụng phương thức forceRecalculateTDEE để tính toán lại TDEE từ đầu
    await userDataProvider.forceRecalculateTDEE();
    
    // Đồng bộ dữ liệu đầy đủ với backend sau khi cập nhật TDEE
    await userDataProvider.sendToApi();
    
    // Lấy giá trị calo mục tiêu nhất quán
    final consistentCalorieGoal = userDataProvider.getConsistentCalorieGoal();
    
    // Hiển thị thông báo về mục tiêu calo mới
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã cập nhật mục tiêu calo: $consistentCalorieGoal kcal'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // Area chart for weight history
  Widget _buildAreaChart() {
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: 5,
          verticalInterval: 1,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.shade200,
              strokeWidth: 1,
            );
          },
          getDrawingVerticalLine: (value) {
            return FlLine(
              color: Colors.grey.shade200,
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1,
              getTitlesWidget: (value, meta) {
                const days = ["T2", "T3", "T4", "T5", "T6", "T7", "CN"];
                int index = value.toInt();
                if (index >= 0 && index < days.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      days[index],
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 10,
                      ),
                    ),
                  );
                }
                return const SizedBox();
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 5,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toInt()} kg',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 10,
                  ),
                );
              },
              reservedSize: 40,
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.grey.shade300, width: 1),
        ),
        minX: 0,
        maxX: 6,
        minY: 40,
        maxY: 60,
        lineBarsData: [
          LineChartBarData(
            spots: _weightHistory.isEmpty ? [
              FlSpot(0, 54),
              FlSpot(1, 54),
              FlSpot(2, 54.2),
              FlSpot(3, 54.3),
              FlSpot(4, 54.2),
              FlSpot(5, 54.4),
              FlSpot(6, 54.5),
            ] : _weightHistory,
            isCurved: true,
            gradient: LinearGradient(
              colors: [Color(0xFF00BFA6), Color(0xFF00BFA6).withAlpha(128)],
            ),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  Color(0xFF00BFA6).withAlpha(102),
                  Color(0xFF00BFA6).withAlpha(0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Function to navigate through the profile update flow
  void _navigateToProfileUpdate() async {
    // Start the sequential navigation flow through onboarding pages
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ProfileUpdateFlow(initialStep: 'name'),
      ),
    );
    
    // If we got a result back, refresh the profile data
    if (result == true) {
      _loadUserData();
    }
  }

  // Save goal settings
  Future<void> _saveGoalSettings() async {
    final userDataProvider = Provider.of<UserDataProvider>(context, listen: false);
    
    // Lấy giá trị hiện tại từ userDataProvider thay vì sử dụng biến không tồn tại
    String goal = userDataProvider.goal;
    double pace = userDataProvider.pace;
    
    // Cập nhật mục tiêu và tốc độ sử dụng phương thức mới
    await userDataProvider.updateUserGoal(
      goal: goal,
      pace: pace,
    );
    
    // Hiển thị thông báo
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Mục tiêu đã được cập nhật thành công'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
    
    // Đóng dialog
    Navigator.of(context).pop();
  }

  // Phương thức cập nhật thông tin người dùng thông qua API
  Future<bool> _updateUserProfileViaApi(Map<String, dynamic> userData) async {
    try {
      // Hiển thị loading indicator
      setState(() {
        _isLoading = true;
      });
      
      // Lấy AuthService từ Provider
      final authService = Provider.of<AuthService>(context, listen: false);
      
      // Gọi phương thức updateFullUserProfile từ AuthService để cập nhật trực tiếp với Firestore
      final success = await authService.updateFullUserProfile(
        // Chuyển đổi các trường từ userData sang tham số riêng lẻ
        displayName: userData['display_name'],
        photoURL: userData['photo_url'],
        age: userData['age'],
        gender: userData['gender'],
        heightCm: userData['height_cm'],
        weightKg: userData['weight_kg'],
        targetWeightKg: userData['target_weight_kg'],
        activityLevel: userData['activity_level'],
        goal: userData['goal'],
        pace: userData['pace'],
        dietRestrictions: userData['diet_restrictions'] != null ? 
          List<String>.from(userData['diet_restrictions']) : null,
        healthConditions: userData['health_conditions'] != null ? 
          List<String>.from(userData['health_conditions']) : null,
        measurementSystem: userData['measurement_system'],
        nutritionGoals: userData['nutrition_goals'],
      );
      
      // Ẩn loading indicator
      setState(() {
        _isLoading = false;
      });
      
      // Hiển thị thông báo kết quả
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cập nhật thông tin thành công'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cập nhật thông tin thất bại: ${authService.errorMessage}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      
      return success;
    } catch (e) {
      // Ẩn loading indicator
      setState(() {
        _isLoading = false;
      });
      
      // Hiển thị thông báo lỗi
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi cập nhật thông tin: $e'),
          backgroundColor: Colors.red,
        ),
      );
      
      return false;
    }
  }

  // Phương thức cập nhật toàn bộ thông tin người dùng
  Future<bool> _updateFullUserProfile({
    String? displayName,
    String? photoURL,
    int? age,
    String? gender,
    double? heightCm,
    double? weightKg,
    double? targetWeightKg,
    String? activityLevel,
    String? goal,
    double? pace,
    List<String>? dietRestrictions,
    List<String>? healthConditions,
    String? measurementSystem,
    Map<String, dynamic>? nutritionGoals,
  }) async {
    try {
      // Hiển thị loading indicator
      setState(() {
        _isLoading = true;
      });
      
      // Lấy AuthService từ Provider
      final authService = Provider.of<AuthService>(context, listen: false);
      
      // Gọi phương thức updateFullUserProfile từ AuthService
      final success = await authService.updateFullUserProfile(
        displayName: displayName,
        photoURL: photoURL,
        age: age,
        gender: gender,
        heightCm: heightCm,
        weightKg: weightKg,
        targetWeightKg: targetWeightKg,
        activityLevel: activityLevel,
        goal: goal,
        pace: pace,
        dietRestrictions: dietRestrictions,
        healthConditions: healthConditions,
        measurementSystem: measurementSystem,
        nutritionGoals: nutritionGoals,
      );
      
      // Ẩn loading indicator
      setState(() {
        _isLoading = false;
      });
      
      // Hiển thị thông báo kết quả
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cập nhật thông tin thành công'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cập nhật thông tin thất bại: ${authService.errorMessage}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      
      return success;
    } catch (e) {
      // Ẩn loading indicator
      setState(() {
        _isLoading = false;
      });
      
      // Hiển thị thông báo lỗi
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi cập nhật thông tin: $e'),
          backgroundColor: Colors.red,
        ),
      );
      
      return false;
    }
  }
}

// Widget to handle navigation to specific onboarding screens for updating user profile data
class ProfileUpdateFlow extends StatelessWidget {
  final String initialStep;
  
  const ProfileUpdateFlow({
    Key? key, 
    required this.initialStep,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final userDataProvider = Provider.of<UserDataProvider>(context);
    final _profileScreenState = context.findAncestorStateOfType<_ProfileScreenState>();
    
    // Map initialStep to the appropriate page
    Widget pageContent;
    String pageTitle;
    
    switch (initialStep) {
      case 'name':
        pageTitle = 'Cập nhật tên';
        pageContent = _buildNameUpdatePage(context, userDataProvider, _profileScreenState);
        break;
      case 'age':
        pageTitle = 'Cập nhật tuổi';
        pageContent = _buildAgeUpdatePage(context, userDataProvider, _profileScreenState);
        break;
      case 'gender':
        pageTitle = 'Cập nhật giới tính';
        pageContent = _buildGenderUpdatePage(context, userDataProvider, _profileScreenState);
        break;
      case 'height':
        pageTitle = 'Cập nhật chiều cao';
        pageContent = _buildHeightUpdatePage(context, userDataProvider, _profileScreenState);
        break;
      case 'weight':
        pageTitle = 'Cập nhật cân nặng';
        pageContent = _buildWeightUpdatePage(context, userDataProvider, _profileScreenState);
        break;
      case 'activity':
        pageTitle = 'Cập nhật mức độ hoạt động';
        pageContent = ActivityLevelPage(updateMode: true);
        break;
      case 'goal':
        pageTitle = 'Cập nhật mục tiêu';
        pageContent = DietGoalPage(updateMode: true);
        break;
      default:
        pageTitle = 'Cập nhật thông tin';
        pageContent = _buildDefaultUpdatePage(context);
    }
    
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(pageTitle),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
      ),
      body: SafeArea(
        child: pageContent,
      ),
    );
  }
  
  // Page to update user name
  Widget _buildNameUpdatePage(BuildContext context, UserDataProvider userDataProvider, _ProfileScreenState? profileScreenState) {
    final TextEditingController nameController = TextEditingController(text: userDataProvider.name);
    
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nhập tên của bạn',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Tên này sẽ được hiển thị trong ứng dụng.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 24),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Tên',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            SizedBox(height: 32), // Fixed height instead of Spacer
            Container(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  if (nameController.text.trim().isNotEmpty) {
                    final newName = nameController.text.trim();
                    
                    // Cập nhật tên trong UserDataProvider
                    userDataProvider.setName(newName);
                    
                    // Cập nhật thông tin người dùng thông qua API
                    if (profileScreenState != null) {
                      // Sử dụng phương thức cập nhật toàn bộ thông tin
                      await profileScreenState._updateFullUserProfile(
                        displayName: newName,
                      );
                    }
                    
                    Navigator.of(context).pop();
                  }
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
                  'Cập nhật',
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
    );
  }
  
  // Page to update user age
  Widget _buildAgeUpdatePage(BuildContext context, UserDataProvider userDataProvider, _ProfileScreenState? profileScreenState) {
    final TextEditingController ageController = TextEditingController(text: userDataProvider.age.toString());
    
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cập nhật tuổi của bạn',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Tuổi của bạn giúp chúng tôi tính toán nhu cầu dinh dưỡng phù hợp.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 24),
            TextField(
              controller: ageController,
              decoration: InputDecoration(
                labelText: 'Tuổi',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 32),
            Container(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  if (ageController.text.isNotEmpty) {
                    try {
                      final int newAge = int.parse(ageController.text);
                      
                      if (newAge > 0 && newAge < 120) {
                        // Cập nhật tuổi trong UserDataProvider
                        userDataProvider.setAge(newAge);
                        
                        // Cập nhật thông tin người dùng thông qua API
                        if (profileScreenState != null) {
                          await profileScreenState._updateFullUserProfile(
                            age: newAge,
                          );
                        }
                        
                        Navigator.of(context).pop();
                      } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                            content: Text('Vui lòng nhập tuổi hợp lệ (1-120)'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Vui lòng nhập tuổi hợp lệ'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
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
                  'Cập nhật',
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
                    );
  }
  
  // Page to update user gender
  Widget _buildGenderUpdatePage(BuildContext context, UserDataProvider userDataProvider, _ProfileScreenState? profileScreenState) {
    String selectedGender = userDataProvider.gender;
    
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cập nhật giới tính của bạn',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Giới tính sinh học giúp chúng tôi tính toán nhu cầu dinh dưỡng phù hợp.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 24),
            StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  children: [
                    RadioListTile<String>(
                      title: Text('Nam'),
                      value: 'Nam',
                      groupValue: selectedGender,
                      onChanged: (value) {
                        setState(() {
                          selectedGender = value!;
                        });
                      },
                    ),
                    RadioListTile<String>(
                      title: Text('Nữ'),
                      value: 'Nữ',
                      groupValue: selectedGender,
                      onChanged: (value) {
                        setState(() {
                          selectedGender = value!;
                        });
                      },
                    ),
                  ],
                );
              }
            ),
            SizedBox(height: 32),
            Container(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  // Cập nhật giới tính trong UserDataProvider
                  userDataProvider.setGender(selectedGender);
                  
                  // Cập nhật thông tin người dùng thông qua API
                  if (profileScreenState != null) {
                    await profileScreenState._updateFullUserProfile(
                      gender: selectedGender,
                    );
                  }
                  
                  Navigator.of(context).pop();
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
                  'Cập nhật',
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
    );
  }
  
  // Page to update user height
  Widget _buildHeightUpdatePage(BuildContext context, UserDataProvider userDataProvider, _ProfileScreenState? profileScreenState) {
    final TextEditingController heightController = TextEditingController(text: userDataProvider.heightCm.toString());
    
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cập nhật chiều cao của bạn',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Chiều cao của bạn giúp chúng tôi tính toán nhu cầu dinh dưỡng phù hợp.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 24),
            TextField(
              controller: heightController,
              decoration: InputDecoration(
                labelText: 'Chiều cao (cm)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 32),
            Container(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  if (heightController.text.isNotEmpty) {
                    try {
                      final double newHeight = double.parse(heightController.text);
                      
                      if (newHeight > 50 && newHeight < 250) {
                        // Cập nhật chiều cao trong UserDataProvider
                        userDataProvider.setHeight(newHeight);
                        
                        // Cập nhật thông tin người dùng thông qua API
                        if (profileScreenState != null) {
                          await profileScreenState._updateFullUserProfile(
                            heightCm: newHeight,
                          );
                        }
                        
                        Navigator.of(context).pop();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Vui lòng nhập chiều cao hợp lệ (50-250 cm)'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Vui lòng nhập chiều cao hợp lệ'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
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
                  'Cập nhật',
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
    );
  }
  
  // Page to update user weight
  Widget _buildWeightUpdatePage(BuildContext context, UserDataProvider userDataProvider, _ProfileScreenState? profileScreenState) {
    final TextEditingController weightController = TextEditingController(text: userDataProvider.weightKg.toString());
    
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cập nhật cân nặng của bạn',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Cân nặng của bạn giúp chúng tôi tính toán nhu cầu dinh dưỡng phù hợp.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 24),
            TextField(
              controller: weightController,
              decoration: InputDecoration(
                labelText: 'Cân nặng (kg)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 32),
            Container(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  if (weightController.text.isNotEmpty) {
                    try {
                      final double newWeight = double.parse(weightController.text);
                      
                      if (newWeight > 20 && newWeight < 300) {
                        // Cập nhật cân nặng trong UserDataProvider
                        userDataProvider.setWeight(newWeight);
                        
                        // Cập nhật thông tin người dùng thông qua API
                        if (profileScreenState != null) {
                          await profileScreenState._updateFullUserProfile(
                            weightKg: newWeight,
                          );
                          
                          // Tính toán lại TDEE sau khi cập nhật cân nặng
                          await profileScreenState._recalculateTDEEAfterWeightUpdate(userDataProvider, newWeight);
                        }
                        
                        Navigator.of(context).pop();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Vui lòng nhập cân nặng hợp lệ (20-300 kg)'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Vui lòng nhập cân nặng hợp lệ'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
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
                  'Cập nhật',
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
    );
  }
  
  // Default update page if no specific page is defined
  Widget _buildDefaultUpdatePage(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.construction,
                size: 80,
                color: Colors.orange,
              ),
              SizedBox(height: 16),
              Text(
                'Chức năng đang được phát triển',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'Vui lòng thử lại sau.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Quay lại'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
