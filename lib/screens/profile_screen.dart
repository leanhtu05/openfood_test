import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../utils/constants.dart';
import 'package:provider/provider.dart';
import '../providers/user_data_provider.dart' as udp;
import '../utils/tdee_calculator.dart';
import '../services/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as Math;
// Add imports for onboarding pages
import '../screens/onboarding/activity_level_page.dart';
import '../screens/onboarding/health_condition_page.dart';
import '../screens/onboarding/target_weight_page.dart';
import '../screens/onboarding/weight_gain_pace_page.dart';
import '../screens/onboarding/diet_goal_page.dart';
import '../screens/onboarding/weight_selection_page.dart';
import '../screens/onboarding/height_selection_page.dart';
import '../screens/onboarding/age_selection_page.dart';
import '../screens/onboarding/gender_selection_page.dart';
import '../screens/onboarding/event_selection_page.dart';
import '../screens/onboarding/event_date_page.dart';
import '../screens/onboarding/onboarding_screen.dart' show MaterialOnboardingPage;
import '../styles/onboarding_styles.dart';
import '../screens/settings_screen.dart';
import '../services/auth_service.dart';

// Helper methods for UserDataProvider
class ProfileScreenHelpers {
  static String getUserDisplayName(udp.UserDataProvider provider) {
    return provider.name.isNotEmpty ? provider.name : "Người dùng";
  }

  static double getInitialWeight(udp.UserDataProvider provider) {
    return provider.weightKg;
  }

  static double getTargetWeight(udp.UserDataProvider provider) {
    return provider.targetWeightKg;
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
  bool _isShowingWeightUpdateMessage = false; // Để tránh hiển thị thông báo liên tục

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // Tải dữ liệu người dùng từ Firebase hoặc Provider
  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userDataProvider = Provider.of<udp.UserDataProvider>(context, listen: false);
      final authService = Provider.of<AuthService>(context, listen: false);

      // Kiểm tra xác thực người dùng
      if (authService.isAuthenticated) {
        final userId = authService.currentUser?.uid;
        print('🔍 Tải dữ liệu cho người dùng ID: $userId');
        
        // ƯU TIÊN: Lấy dữ liệu trực tiếp từ Firestore
        try {
          print('🔍 Đang tìm kiếm dữ liệu người dùng từ Firestore...');
          final firestoreData = await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();
          
          if (firestoreData.exists && firestoreData.data() != null) {
            print('✅ Đã tìm thấy dữ liệu người dùng trong Firestore');
            // Cập nhật UserDataProvider với dữ liệu từ Firestore
            await userDataProvider.loadFromFirestoreData(firestoreData.data()!);
            print('✅ Đã cập nhật UserDataProvider với dữ liệu từ Firestore');
          } else {
            print('⚠️ Không tìm thấy dữ liệu trong Firestore, sử dụng phương thức đồng bộ');
            // Thử phương thức đồng bộ nếu không tìm thấy dữ liệu trực tiếp
            await authService.syncUserDataToProvider(userDataProvider);
          }
        } catch (firestoreError) {
          print('⚠️ Lỗi khi truy cập Firestore: $firestoreError');
          // Thử phương thức đồng bộ của AuthService nếu truy cập Firestore thất bại
          try {
            await authService.syncUserDataToProvider(userDataProvider);
            print('✅ Đã đồng bộ dữ liệu thông qua AuthService');
          } catch (syncError) {
            print('❌ Lỗi khi đồng bộ dữ liệu từ Firebase: $syncError');
            // Tiếp tục sử dụng dữ liệu hiện có trong UserDataProvider
          }
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
      final targetWeight = userDataProvider.targetWeightKg;

      // Lấy TDEE trực tiếp từ UserDataProvider thay vì tính lại
      final tdee = userDataProvider.tdeeCalories;

      // Sử dụng giá trị từ getConsistentCalorieGoal() để đảm bảo tính nhất quán
      final dailyCalories = userDataProvider.getConsistentCalorieGoal();

      // Tạo lịch sử cân nặng dựa trên dữ liệu thật của người dùng
      final spotList = <FlSpot>[];
      final currentWeight = weight;

      // Tính cân nặng ban đầu dựa trên mục tiêu thực tế
      double startWeight;
      if (goal == "Giảm cân") {
        if (targetWeight > 0) {
          // Có mục tiêu cụ thể - tính dựa trên target weight
          double weightDifference = currentWeight - targetWeight;
          double estimatedWeeks = pace > 0 ? weightDifference / pace : 6;
          startWeight = currentWeight + (pace * Math.min(estimatedWeeks, 6)); // Tối đa 6 tuần
          print('📊 Giảm cân (có mục tiêu): Hiện tại=$currentWeight, Mục tiêu=$targetWeight, Tốc độ=$pace, Bắt đầu=$startWeight');
        } else {
          // Không có mục tiêu cụ thể - giả định giảm trong 6 tuần
          startWeight = currentWeight + (pace * 6);
          print('📊 Giảm cân (không có mục tiêu): Hiện tại=$currentWeight, Tốc độ=$pace, Bắt đầu=$startWeight');
        }
      } else if (goal == "Tăng cân") {
        if (targetWeight > 0) {
          // Có mục tiêu cụ thể - tính dựa trên target weight
          double weightDifference = targetWeight - currentWeight;
          double estimatedWeeks = pace > 0 ? weightDifference / pace : 6;
          startWeight = currentWeight - (pace * Math.min(estimatedWeeks, 6)); // Tối đa 6 tuần
          print('📊 Tăng cân (có mục tiêu): Hiện tại=$currentWeight, Mục tiêu=$targetWeight, Tốc độ=$pace, Bắt đầu=$startWeight');
        } else {
          // Không có mục tiêu cụ thể - giả định tăng trong 6 tuần
          startWeight = currentWeight - (pace * 6);
          print('📊 Tăng cân (không có mục tiêu): Hiện tại=$currentWeight, Tốc độ=$pace, Bắt đầu=$startWeight');
        }
      } else {
        // Duy trì cân nặng - biến động nhẹ
        startWeight = currentWeight + 0.5;
        print('📊 Duy trì: Hiện tại=$currentWeight, Bắt đầu=$startWeight');
      }

      // Tạo lịch sử cân nặng thực tế trong 7 điểm thời gian
      for (int i = 0; i < 7; i++) {
        double progressWeight;
        if (i == 0) {
          // Điểm bắt đầu
          progressWeight = startWeight;
        } else if (i == 6) {
          // Điểm hiện tại
          progressWeight = currentWeight;
        } else {
          // Các điểm trung gian - tính toán dựa trên tiến độ tuyến tính
          final progress = i / 6.0; // Tiến độ từ 0 đến 1
          progressWeight = startWeight + (currentWeight - startWeight) * progress;

          // Thêm một chút biến động tự nhiên nhỏ
          final variation = (i % 2 == 0 ? 0.1 : -0.1);
          progressWeight += variation;
        }

        spotList.add(FlSpot(i.toDouble(), progressWeight));
      }

      // Cập nhật dữ liệu với thông tin thật từ UserDataProvider
      setState(() {
        _weight = weight;
        _age = age;
        _name = userName.isNotEmpty ? userName : "Người dùng";
        _tdee = tdee > 0 ? tdee : 2000; // Fallback nếu TDEE chưa được tính
        _targetCalories = dailyCalories.toDouble();
        _weeklyWeightChange = pace;
        _weightHistory = spotList;
        _isLoading = false;
      });

      print('✅ Đã tải dữ liệu người dùng thành công trong ProfileScreen');
      print('👤 Tên: $_name, Tuổi: $_age, Cân nặng: $_weight kg');
      print('🎯 Mục tiêu: $goal, Tốc độ: $pace kg/tuần');
      print('📏 Chiều cao: $height cm, Giới tính: $gender');
      print('🔥 TDEE: $_tdee kcal, Mục tiêu calo: $_targetCalories kcal');
      print('📊 Lịch sử cân nặng: ${spotList.length} điểm dữ liệu');
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
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // Weight info with scale icon
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(Icons.monitor_weight, size: 24, color: Colors.grey[600]),
                SizedBox(height: 4),
                Text(
                  'Cân nặng',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  '${_weight.toStringAsFixed(1)} kg',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(width: 16),

          // User info with avatar
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey.shade300,
                  child: Icon(Icons.person, size: 20, color: Colors.grey.shade700),
                ),
                SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _name.isNotEmpty ? _name : 'Người dùng',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      'T$_age',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Spacer(),

          // Settings button
          Container(
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(Icons.settings, color: Colors.blue[600], size: 20),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => SettingsScreen(),
                  ),
                ).then((_) => _loadUserData());
              },
            ),
          ),
        ],
      ),
    );
  }

  // Tổng quan mục tiêu
  Widget _buildGoalOverview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with title and update button
        Row(
          children: [
            Icon(Icons.track_changes, size: 20, color: Colors.black87),
            SizedBox(width: 8),
            Text(
              "Tổng quan mục tiêu",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            Spacer(),
            OutlinedButton.icon(
              onPressed: () => _navigateToProfileUpdate(),
              icon: Icon(Icons.edit, size: 14),
              label: Text("Cập nhật"),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.blue[600],
                side: BorderSide(color: Colors.blue[300]!),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size(0, 0),
              ),
            ),
          ],
        ),

        SizedBox(height: 16),

        // Three cards in a row
        Row(
          children: [
            Expanded(
              child: _buildInfoCard(
                icon: Icons.home,
                iconColor: Colors.black87,
                title: "TDEE",
                value: "${_tdee.round()}kcal",
                subtitle: "",
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _buildInfoCard(
                icon: Icons.face,
                iconColor: Colors.black87,
                title: _getWeightChangeText(),
                value: "${_weeklyWeightChange.toStringAsFixed(1)} kg/tuần",
                subtitle: "",
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _buildInfoCard(
                icon: Icons.local_fire_department,
                iconColor: Colors.black87,
                title: "Mục tiêu Calo",
                value: "${_targetCalories.round()}kcal",
                subtitle: "",
              ),
            ),
          ],
        ),
        SizedBox(height: 24),

        // Weight trend chart - simplified design
        Container(
          height: 280,
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: _buildSimplifiedWeightChart(),
        ),
      ],
    );
  }

  // Helper to format weight change text
  String _getWeightChangeText() {
    final userDataProvider = Provider.of<udp.UserDataProvider>(context, listen: false);
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
    String? subtitle,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle != null && subtitle.isNotEmpty) ...[
            SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[500],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Simplified weight chart matching the design
  Widget _buildSimplifiedWeightChart() {
    // Lấy dữ liệu thật từ UserDataProvider
    final userDataProvider = Provider.of<udp.UserDataProvider>(context, listen: false);
    final currentWeight = userDataProvider.weightKg; // Cân nặng hiện tại thật
    final targetWeight = userDataProvider.targetWeightKg; // Cân nặng mục tiêu thật
    final goal = userDataProvider.goal; // Mục tiêu thật
    final pace = userDataProvider.pace; // Tốc độ thật (kg/tuần)

    // Tính cân nặng ban đầu dựa trên mục tiêu thực tế
    double startWeight;
    if (_weightHistory.isNotEmpty) {
      startWeight = _weightHistory.first.y;
    } else {
      // Tính toán cân nặng ban đầu dựa trên mục tiêu và tốc độ thực tế
      if (goal == "Giảm cân") {
        if (targetWeight > 0) {
          // Có mục tiêu cụ thể
          double weightDifference = currentWeight - targetWeight;
          double estimatedWeeks = pace > 0 ? weightDifference / pace : 6;
          startWeight = currentWeight + (pace * Math.min(estimatedWeeks, 6)); // Tối đa 6 tuần
        } else {
          // Không có mục tiêu cụ thể - giả định giảm trong 6 tuần
          startWeight = currentWeight + (pace * 6);
        }
      } else if (goal == "Tăng cân") {
        if (targetWeight > 0) {
          // Có mục tiêu cụ thể
          double weightDifference = targetWeight - currentWeight;
          double estimatedWeeks = pace > 0 ? weightDifference / pace : 6;
          startWeight = currentWeight - (pace * Math.min(estimatedWeeks, 6)); // Tối đa 6 tuần
        } else {
          // Không có mục tiêu cụ thể - giả định tăng trong 6 tuần
          startWeight = currentWeight - (pace * 6);
        }
      } else {
        // Duy trì cân nặng - biến động nhẹ
        startWeight = currentWeight + 0.5;
      }
    }

    // Tính toán ngày tháng hiện tại
    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: 30)); // 30 ngày trước
    final endDate = now;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hôm qua',
          style: TextStyle(
            fontSize: 14,
            color: Colors.red[400],
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8),

        // Chart area
        Expanded(
          child: Stack(
            children: [
              // Chart background
              Container(
                width: double.infinity,
                height: double.infinity,
                child: CustomPaint(
                  painter: WeightChartPainter(
                    weightHistory: _weightHistory.isNotEmpty ? _weightHistory : () {
                      // Tạo dữ liệu mẫu dựa trên mục tiêu thực tế
                      if (goal == "Giảm cân" && pace > 0) {
                        return [
                          FlSpot(0, startWeight),
                          FlSpot(1, startWeight - pace),
                          FlSpot(2, startWeight - (pace * 2)),
                          FlSpot(3, startWeight - (pace * 3)),
                          FlSpot(4, startWeight - (pace * 4)),
                          FlSpot(5, startWeight - (pace * 5)),
                          FlSpot(6, currentWeight),
                        ];
                      } else if (goal == "Tăng cân" && pace > 0) {
                        return [
                          FlSpot(0, startWeight),
                          FlSpot(1, startWeight + pace),
                          FlSpot(2, startWeight + (pace * 2)),
                          FlSpot(3, startWeight + (pace * 3)),
                          FlSpot(4, startWeight + (pace * 4)),
                          FlSpot(5, startWeight + (pace * 5)),
                          FlSpot(6, currentWeight),
                        ];
                      } else {
                        // Duy trì cân nặng
                        return [
                          FlSpot(0, startWeight),
                          FlSpot(1, startWeight - 0.1),
                          FlSpot(2, startWeight + 0.2),
                          FlSpot(3, startWeight - 0.1),
                          FlSpot(4, startWeight + 0.1),
                          FlSpot(5, startWeight - 0.2),
                          FlSpot(6, currentWeight),
                        ];
                      }
                    }(),
                  ),
                ),
              ),

              // Weight labels positioned above the chart với dữ liệu thật
              Positioned(
                top: 0,
                left: 20,
                child: _buildWeightLabel(
                  '${startWeight.toStringAsFixed(1)} kg',
                  'Bắt đầu',
                  Colors.red[400]!
                ),
              ),

              Positioned(
                top: 40,
                right: 80,
                child: _buildWeightLabel(
                  '${((startWeight + currentWeight) / 2).toStringAsFixed(1)} kg',
                  'Kỳ nghỉ',
                  Colors.orange[400]!
                ),
              ),

              Positioned(
                top: 0,
                right: 20,
                child: _buildWeightLabel(
                  '${currentWeight.toStringAsFixed(1)} kg',
                  'Mục tiêu',
                  Colors.green[400]!
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: 16),

        // Bottom date labels với ngày thật
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'thg ${startDate.month} ${startDate.day.toString().padLeft(2, '0')}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            Text(
              'thg ${endDate.month} ${endDate.day.toString().padLeft(2, '0')}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Weight label widget
  Widget _buildWeightLabel(String weight, String label, Color color) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            weight,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
      ],
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
      minY = values.reduce((min, val) => min < val ? min : val);
      maxY = values.reduce((max, val) => max > val ? max : val);
      
      // Thêm padding để tránh chart chạm vào đường biên (15% khoảng cách)
      double range = maxY - minY;
      if (range < 2) range = 2; // Đảm bảo range tối thiểu là 2kg để chart không quá nén
      
      minY = minY - range * 0.15;
      maxY = maxY + range * 0.15;
      
      // Làm tròn để có giá trị đẹp hơn
      minY = (minY / 0.5).floor() * 0.5;
      maxY = (maxY / 0.5).ceil() * 0.5;
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
              interval: (maxY - minY) / 4 > 1 ? 2 : 1,  // Điều chỉnh interval dựa vào phạm vi
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toStringAsFixed(1)} kg',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 10,
                  ),
                );
              },
              reservedSize: 48, // Tăng khoảng trống cho nhãn dài hơn
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
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            tooltipRoundedRadius: 8,
            getTooltipItems: (List<LineBarSpot> touchedSpots) {
              return touchedSpots.map((LineBarSpot touchedSpot) {
                return LineTooltipItem(
                  '${touchedSpot.y.toStringAsFixed(1)} kg',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  // AI suggestion notification với thông tin cá nhân hóa
  Widget _buildWeightUpdateNotification() {
    // Lấy thông tin từ UserDataProvider để cá nhân hóa thông báo
    final userDataProvider = Provider.of<udp.UserDataProvider>(context, listen: false);
    final goal = userDataProvider.goal;
    final targetWeight = userDataProvider.targetWeightKg;

    // Tạo thông báo cá nhân hóa dựa trên mục tiêu
    String personalizedMessage = "";
    if (goal == "Giảm cân") {
      if (targetWeight > 0) {
        final remainingWeight = _weight - targetWeight;
        personalizedMessage = "Bạn còn ${remainingWeight.toStringAsFixed(1)} kg nữa để đạt mục tiêu ${targetWeight.toStringAsFixed(1)} kg. ";
      } else {
        personalizedMessage = "Bạn đang trong quá trình giảm cân với tốc độ ${userDataProvider.pace.toStringAsFixed(1)} kg/tuần. ";
      }
    } else if (goal == "Tăng cân") {
      if (targetWeight > 0) {
        final remainingWeight = targetWeight - _weight;
        personalizedMessage = "Bạn cần tăng thêm ${remainingWeight.toStringAsFixed(1)} kg để đạt mục tiêu ${targetWeight.toStringAsFixed(1)} kg. ";
      } else {
        personalizedMessage = "Bạn đang trong quá trình tăng cân với tốc độ ${userDataProvider.pace.toStringAsFixed(1)} kg/tuần. ";
      }
    } else if (goal == "Duy trì cân nặng") {
      personalizedMessage = "Bạn đang duy trì cân nặng ở mức ${_weight.toStringAsFixed(1)} kg. ";
    }

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sparkle icons
          Column(
            children: [
              Icon(
                Icons.auto_awesome,
                color: Color(0xFF1565C0),
                size: 20,
              ),
              SizedBox(height: 4),
              Icon(
                Icons.auto_awesome,
                color: Color(0xFF1565C0),
                size: 16,
              ),
            ],
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "AI muốn bạn cập nhật cân nặng của mình!",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1565C0),
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  "${personalizedMessage}Để trí tuệ nhân tạo tính toán nhu cầu calo và chất dinh dưỡng hàng ngày của bạn, vui lòng cập nhật cân nặng của bạn hàng ngày, lý tưởng nhất là vào buổi sáng. Tôi thiết kế, cập nhật hàng tuần là cần thiết để duy trì toàn bộ calo AI",
                  style: TextStyle(
                    color: Color(0xFF1565C0),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 12),
                // Thêm buttons để cập nhật cân nặng và cân nặng mục tiêu
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          _showWeightUpdateDialog();
                        },
                        icon: Icon(Icons.scale, size: 16),
                        label: Text("Cập nhật cân nặng"),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Color(0xFF1565C0),
                          side: BorderSide(color: Color(0xFF1565C0)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProfileUpdateFlow(initialStep: 'target_weight'),
                            ),
                          );
                        },
                        icon: Icon(Icons.flag, size: 16),
                        label: Text("Cân nặng mục tiêu"),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Color(0xFF1565C0),
                          side: BorderSide(color: Color(0xFF1565C0)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Biểu đồ lịch sử cân nặng - Bar Chart Style
  Widget _buildWeightHistoryChart() {
    return Card(
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.2),
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
                Row(
                  children: [
                    Icon(Icons.equalizer, color: Colors.black87, size: 20),
                    SizedBox(width: 4),
                    Text(
                      "Cân nặng của bạn ?",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    // Show weight update dialog
                    _showWeightUpdateDialog();
                  },
                  icon: Icon(Icons.add, size: 12),
                  label: Text("Cập nhật cân nặng"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue[600],
                    side: BorderSide(color: Colors.blue[300]!),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size(0, 0),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Container(
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey[50],
              ),
              padding: EdgeInsets.all(16),
              child: Stack(
                children: [
                  _buildBarChart(),
                  // Nút giảm giá ở góc phải
                  Positioned(
                    bottom: 10,
                    right: 10,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(20),
                      ),

                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            // Thêm chú thích
            Wrap(
              spacing: 16,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _buildLegendItem("Bắt đầu", Colors.red.shade400),
                _buildLegendItem("Kỳ nghỉ 🏖️", Colors.orange.shade400),
                _buildLegendItem("Hiện tại ✅", Colors.green.shade400),
              ],
            ),
          ],
        ),
      ),
    );
  }
  // Tạo widget chú thích cho biểu đồ
  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade700,
          ),
        ),
      ],
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
              final userDataProvider = Provider.of<udp.UserDataProvider>(context, listen: false);
              userDataProvider.setWeight(newWeight);

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
  Future<void> _recalculateTDEEAfterWeightUpdate(udp.UserDataProvider userDataProvider, double newWeight) async {
    try {
      // Sử dụng phương thức forceRecalculateTDEE để tính toán lại TDEE từ đầu
      await userDataProvider.forceRecalculateTDEE();

      // Đồng bộ dữ liệu đầy đủ với backend sau khi cập nhật TDEE
      await userDataProvider.sendToApi();

      // Lấy giá trị calo mục tiêu nhất quán
      final consistentCalorieGoal = userDataProvider.getConsistentCalorieGoal();

      // Chỉ hiển thị thông báo một lần và kiểm tra mounted
      if (context.mounted && !_isShowingWeightUpdateMessage) {
        _isShowingWeightUpdateMessage = true;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã cập nhật cân nặng và mục tiêu calo: $consistentCalorieGoal kcal'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        ).closed.then((_) {
          _isShowingWeightUpdateMessage = false;
        });
      }
    } catch (e) {
      print('Lỗi khi tính toán lại TDEE: $e');
    }
  }

  // Bar chart for weight history - giống như trong ảnh
  Widget _buildBarChart() {
    // Lấy dữ liệu thật từ UserDataProvider
    final userDataProvider = Provider.of<udp.UserDataProvider>(context, listen: false);
    final currentWeight = userDataProvider.weightKg; // Cân nặng hiện tại thật
    final targetWeight = userDataProvider.targetWeightKg; // Cân nặng mục tiêu thật
    final goal = userDataProvider.goal; // Mục tiêu thật
    final pace = userDataProvider.pace; // Tốc độ thật (kg/tuần)

    // Tính toán dữ liệu mẫu dựa trên thông tin thực tế của người dùng
    List<FlSpot> mockData = [];
    if (goal == "Giảm cân") {
      if (targetWeight > 0) {
        // Có mục tiêu cụ thể
        double weightDifference = currentWeight - targetWeight;
        double estimatedWeeks = pace > 0 ? weightDifference / pace : 6;
        double startWeight = currentWeight + (pace * Math.min(estimatedWeeks, 6));

        for (int i = 0; i < 7; i++) {
          double weightAtWeek = startWeight - (pace * i);
          mockData.add(FlSpot(i.toDouble(), weightAtWeek));
        }
      } else {
        // Không có mục tiêu cụ thể - giả định giảm trong 6 tuần
        double startWeight = currentWeight + (pace * 6);
        for (int i = 0; i < 7; i++) {
          double weightAtWeek = startWeight - (pace * i);
          mockData.add(FlSpot(i.toDouble(), weightAtWeek));
        }
      }
    } else if (goal == "Tăng cân") {
      if (targetWeight > 0) {
        // Có mục tiêu cụ thể
        double weightDifference = targetWeight - currentWeight;
        double estimatedWeeks = pace > 0 ? weightDifference / pace : 6;
        double startWeight = currentWeight - (pace * Math.min(estimatedWeeks, 6));

        for (int i = 0; i < 7; i++) {
          double weightAtWeek = startWeight + (pace * i);
          mockData.add(FlSpot(i.toDouble(), weightAtWeek));
        }
      } else {
        // Không có mục tiêu cụ thể - giả định tăng trong 6 tuần
        double startWeight = currentWeight - (pace * 6);
        for (int i = 0; i < 7; i++) {
          double weightAtWeek = startWeight + (pace * i);
          mockData.add(FlSpot(i.toDouble(), weightAtWeek));
        }
      }
    } else {
      // Duy trì cân nặng - biến động nhẹ quanh cân nặng hiện tại
      mockData = [
        FlSpot(0, currentWeight + 0.3),
        FlSpot(1, currentWeight - 0.2),
        FlSpot(2, currentWeight + 0.1),
        FlSpot(3, currentWeight - 0.1),
        FlSpot(4, currentWeight + 0.2),
        FlSpot(5, currentWeight - 0.1),
        FlSpot(6, currentWeight),
      ];
    }

    final chartData = _weightHistory.isNotEmpty ? _weightHistory : mockData;

    // Tính min/max cho trục Y
    final weights = chartData.map((e) => e.y).toList();
    final minWeight = weights.reduce((a, b) => a < b ? a : b);
    final maxWeight = weights.reduce((a, b) => a > b ? a : b);
    final range = maxWeight - minWeight;
    final paddedMin = (minWeight - range * 0.1).floorToDouble();
    final paddedMax = (maxWeight + range * 0.1).ceilToDouble();

    // Tạo nhãn cho trục Y (20kg intervals)
    final yLabels = <double>[];
    for (double i = 40; i <= 120; i += 20) {
      if (i >= paddedMin && i <= paddedMax) {
        yLabels.add(i);
      }
    }

    // Tạo nhãn cho trục X (ngày tháng)
    final now = DateTime.now();
    final xLabels = <String>[];
    for (int i = 0; i < chartData.length; i++) {
      final date = now.subtract(Duration(days: (chartData.length - 1 - i) * 4));
      xLabels.add('thg ${date.month} ${date.day}');
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: paddedMax,
        minY: paddedMin,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${rod.toY.toStringAsFixed(1)} kg',
                TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double value, TitleMeta meta) {
                final index = value.toInt();
                if (index >= 0 && index < xLabels.length) {
                  return Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      xLabels[index],
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 10,
                      ),
                    ),
                  );
                }
                return Text('');
              },
              reservedSize: 30,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 20,
              getTitlesWidget: (double value, TitleMeta meta) {
                return Text(
                  '${value.toInt()} kg',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 10,
                  ),
                );
              },
              reservedSize: 40,
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 20,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey[300]!,
              strokeWidth: 1,
            );
          },
        ),
        barGroups: chartData.asMap().entries.map((entry) {
          final index = entry.key;
          final spot = entry.value;

          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: spot.y,
                color: index == chartData.length - 1
                    ? Colors.blue[400] // Cột cuối cùng màu xanh dương
                    : Colors.grey[300], // Các cột khác màu xám nhạt
                width: 20,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  // Area chart for weight history (giữ lại cho tương thích)
  Widget _buildAreaChart() {
    // Tính toán min và max cho biểu đồ dựa trên dữ liệu
    double minY = 40.0;
    double maxY = 60.0;

    if (_weightHistory.isNotEmpty) {
      // Lấy giá trị min và max từ dữ liệu
      final values = _weightHistory.map((spot) => spot.y).toList();
      minY = values.reduce((min, val) => min < val ? min : val);
      maxY = values.reduce((max, val) => max > val ? max : val);
      
      // Thêm padding để tránh chart chạm vào đường biên (20% khoảng cách)
      double range = maxY - minY;
      if (range < 3) range = 3; // Đảm bảo range tối thiểu là 3kg
      
      minY = minY - range * 0.2;
      maxY = maxY + range * 0.2;
      
      // Làm tròn để có giá trị đẹp hơn
      minY = (minY / 1).floor() * 1;
      maxY = (maxY / 1).ceil() * 1;
    }

    return Container(
      height: 220, // Fixed height để tránh overflow
      child: Stack(
        children: [
          // Biểu đồ fl_chart (giữ nguyên chức năng)
          Container(
            margin: EdgeInsets.only(top: 35, left: 5, right: 5, bottom: 10),
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: (maxY - minY) > 10 ? 5 : 2,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey.shade200,
                      strokeWidth: 1,
                      dashArray: [5, 5],
                    );
                  },
                  getDrawingVerticalLine: (value) {
                    return FlLine(
                      color: Colors.transparent,
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
                      reservedSize: 35,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        // Chỉ hiển thị 3 nhãn chính để tránh chồng chéo
                        if (value == 0) return Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text('Bắt đầu',
                            style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
                            textAlign: TextAlign.center,
                          ),
                        );
                        if (value == 3) return Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text('Kỳ nghỉ',
                            style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
                            textAlign: TextAlign.center,
                          ),
                        );
                        if (value == 6) return Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text('Hiện tại',
                            style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
                            textAlign: TextAlign.center,
                          ),
                        );
                        return const SizedBox();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: (maxY - minY) > 10 ? 5 : 2,
                      getTitlesWidget: (value, meta) {
                        return Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Text(
                            '${value.toInt()}',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 9,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        );
                      },
                      reservedSize: 28,
                    ),
                  ),
                ),
                borderData: FlBorderData(
                  show: false,
                ),
                minX: 0,
                maxX: 6,
                minY: minY,
                maxY: maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: _weightHistory.isEmpty ? () {
                      // Lấy dữ liệu thật từ UserDataProvider
                      final userDataProvider = Provider.of<udp.UserDataProvider>(context, listen: false);
                      final currentWeight = userDataProvider.weightKg;
                      final targetWeight = userDataProvider.targetWeightKg;
                      final goal = userDataProvider.goal;
                      final pace = userDataProvider.pace;

                      if (goal == "Giảm cân") {
                        if (targetWeight > 0) {
                          // Có mục tiêu cụ thể
                          double weightDifference = currentWeight - targetWeight;
                          double estimatedWeeks = pace > 0 ? weightDifference / pace : 6;
                          double startWeight = currentWeight + (pace * Math.min(estimatedWeeks, 6));

                          return [
                            FlSpot(0, startWeight),
                            FlSpot(1, startWeight - pace),
                            FlSpot(2, startWeight - (pace * 2)),
                            FlSpot(3, startWeight - (pace * 3)), // Kỳ nghỉ
                            FlSpot(4, startWeight - (pace * 4)),
                            FlSpot(5, startWeight - (pace * 5)),
                            FlSpot(6, currentWeight), // Hiện tại
                          ];
                        } else {
                          // Không có mục tiêu cụ thể - giả định giảm trong 6 tuần
                          double startWeight = currentWeight + (pace * 6);
                          return [
                            FlSpot(0, startWeight),
                            FlSpot(1, startWeight - pace),
                            FlSpot(2, startWeight - (pace * 2)),
                            FlSpot(3, startWeight - (pace * 3)), // Kỳ nghỉ
                            FlSpot(4, startWeight - (pace * 4)),
                            FlSpot(5, startWeight - (pace * 5)),
                            FlSpot(6, currentWeight), // Hiện tại
                          ];
                        }
                      } else if (goal == "Tăng cân") {
                        if (targetWeight > 0) {
                          // Có mục tiêu cụ thể
                          double weightDifference = targetWeight - currentWeight;
                          double estimatedWeeks = pace > 0 ? weightDifference / pace : 6;
                          double startWeight = currentWeight - (pace * Math.min(estimatedWeeks, 6));

                          return [
                            FlSpot(0, startWeight),
                            FlSpot(1, startWeight + pace),
                            FlSpot(2, startWeight + (pace * 2)),
                            FlSpot(3, startWeight + (pace * 3)), // Kỳ nghỉ
                            FlSpot(4, startWeight + (pace * 4)),
                            FlSpot(5, startWeight + (pace * 5)),
                            FlSpot(6, currentWeight), // Hiện tại
                          ];
                        } else {
                          // Không có mục tiêu cụ thể - giả định tăng trong 6 tuần
                          double startWeight = currentWeight - (pace * 6);
                          return [
                            FlSpot(0, startWeight),
                            FlSpot(1, startWeight + pace),
                            FlSpot(2, startWeight + (pace * 2)),
                            FlSpot(3, startWeight + (pace * 3)), // Kỳ nghỉ
                            FlSpot(4, startWeight + (pace * 4)),
                            FlSpot(5, startWeight + (pace * 5)),
                            FlSpot(6, currentWeight), // Hiện tại
                          ];
                        }
                      } else {
                        // Duy trì cân nặng
                        return [
                          FlSpot(0, currentWeight + 0.3),
                          FlSpot(1, currentWeight + 0.1),
                          FlSpot(2, currentWeight - 0.1),
                          FlSpot(3, currentWeight + 0.2), // Kỳ nghỉ
                          FlSpot(4, currentWeight - 0.2),
                          FlSpot(5, currentWeight + 0.1),
                          FlSpot(6, currentWeight), // Hiện tại
                        ];
                      }
                    }() : _weightHistory,
                    isCurved: true,
                    curveSmoothness: 0.35, // Làm đường cong mượt hơn
                    // Gradient theo tiến trình (đỏ -> cam -> vàng -> xanh lá)
                    gradient: LinearGradient(
                      colors: [
                        Colors.red.shade400,
                        Colors.orange.shade400,
                        Colors.yellow.shade600,
                        Colors.green.shade400,
                      ],
                      stops: [0.0, 0.35, 0.7, 1.0],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    barWidth: 5,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        // Điểm đặc biệt tại kỳ nghỉ và hiện tại
                        Color dotColor = Colors.orange;
                        double dotSize = 7.0;
                        
                        if (index == 0) { // Bắt đầu
                          dotColor = Colors.red.shade400;
                        } else if (index == 3) { // Kỳ nghỉ
                          dotColor = Colors.orange.shade500;
                        } else if (index == 6 || index == _weightHistory.length - 1) { // Hiện tại
                          dotColor = Colors.green.shade500;
                        } else {
                          return FlDotCirclePainter(
                            radius: 0, // Ẩn các điểm khác
                            color: Colors.transparent,
                            strokeWidth: 0,
                            strokeColor: Colors.transparent,
                          );
                        }
                        
                        return FlDotCirclePainter(
                          radius: dotSize,
                          color: dotColor,
                          strokeWidth: 3,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          Colors.green.shade400.withOpacity(0.3),
                          Colors.orange.shade400.withOpacity(0.2),
                          Colors.red.shade400.withOpacity(0.1),
                        ],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                  
                    tooltipRoundedRadius: 12,
                    fitInsideHorizontally: true,
                    getTooltipItems: (List<LineBarSpot> touchedSpots) {
                      return touchedSpots.map((LineBarSpot touchedSpot) {
                        return LineTooltipItem(
                          '${touchedSpot.y.toStringAsFixed(1)} kg',
                          const TextStyle(
                            color: Colors.white, 
                            fontSize: 14,
                            fontWeight: FontWeight.bold
                          ),
                        );
                      }).toList();
                    },
                  ),
                  touchCallback: (FlTouchEvent event, LineTouchResponse? touchResponse) {},
                  handleBuiltInTouches: true,
                ),
              ),
            ),
          ),
          
          // Nhãn cân nặng bắt đầu - responsive positioning
          _buildChartLabel(
            top: 5,
            left: 10,
            title: _weightHistory.isEmpty ? () {
              final userDataProvider = Provider.of<udp.UserDataProvider>(context, listen: false);
              final currentWeight = userDataProvider.weightKg;
              final targetWeight = userDataProvider.targetWeightKg;
              final goal = userDataProvider.goal;
              final pace = userDataProvider.pace;

              if (goal == "Giảm cân") {
                if (targetWeight > 0) {
                  // Có mục tiêu cụ thể
                  double weightDifference = currentWeight - targetWeight;
                  double estimatedWeeks = pace > 0 ? weightDifference / pace : 6;
                  double startWeight = currentWeight + (pace * Math.min(estimatedWeeks, 6));
                  return '${startWeight.toStringAsFixed(1)} kg';
                } else {
                  // Không có mục tiêu cụ thể - giả định giảm trong 6 tuần
                  double startWeight = currentWeight + (pace * 6);
                  return '${startWeight.toStringAsFixed(1)} kg';
                }
              } else if (goal == "Tăng cân") {
                if (targetWeight > 0) {
                  // Có mục tiêu cụ thể
                  double weightDifference = targetWeight - currentWeight;
                  double estimatedWeeks = pace > 0 ? weightDifference / pace : 6;
                  double startWeight = currentWeight - (pace * Math.min(estimatedWeeks, 6));
                  return '${startWeight.toStringAsFixed(1)} kg';
                } else {
                  // Không có mục tiêu cụ thể - giả định tăng trong 6 tuần
                  double startWeight = currentWeight - (pace * 6);
                  return '${startWeight.toStringAsFixed(1)} kg';
                }
              } else {
                return '${(currentWeight + 0.3).toStringAsFixed(1)} kg';
              }
            }() : '${_weightHistory.first.y.toStringAsFixed(1)} kg',
            subtitle: "Bắt đầu",
            alignment: CrossAxisAlignment.start,
            color: Colors.red.shade400,
          ),

          // Nhãn cân nặng hiện tại - chỉ hiển thị 2 nhãn chính để tránh chồng chéo
          _buildChartLabel(
            top: 5,
            right: 10,
            title: _weightHistory.isEmpty ? () {
              final userDataProvider = Provider.of<udp.UserDataProvider>(context, listen: false);
              return '${userDataProvider.weightKg.toStringAsFixed(1)} kg';
            }() : '${_weightHistory.last.y.toStringAsFixed(1)} kg',
            subtitle: "Hiện tại ✅",
            alignment: CrossAxisAlignment.end,
            color: Colors.green.shade500,
          ),
        ],
      ),
    );
  }
  
  // Widget phụ trợ để tạo các nhãn thông tin trên biểu đồ - responsive version
  Widget _buildChartLabel({
    double? top,
    double? left,
    double? right,
    required String title,
    required String subtitle,
    required CrossAxisAlignment alignment,
    required Color color,
  }) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      child: Column(
        crossAxisAlignment: alignment,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                )
              ],
              border: Border.all(color: color.withOpacity(0.3), width: 1),
            ),
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 9,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // Function to navigate through the profile update flow
  void _navigateToProfileUpdate() async {
    // Navigate to full onboarding flow for updating profile
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => OnboardingUpdateFlow(),
      ),
    );

    // If we got a result back, refresh the profile data
    if (result == true) {
      _loadUserData();

      // Lấy UserDataProvider để cập nhật mục tiêu
      final userDataProvider = Provider.of<udp.UserDataProvider>(context, listen: false);

      // Lấy giá trị hiện tại từ userDataProvider
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
          content: Text('Thông tin cá nhân đã được cập nhật thành công'),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    }
  }

  // Save goal settings
  Future<void> _saveGoalSettings() async {
    final userDataProvider = Provider.of<udp.UserDataProvider>(context, listen: false);

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

// Custom painter for the weight chart
class WeightChartPainter extends CustomPainter {
  final List<FlSpot> weightHistory;

  WeightChartPainter({required this.weightHistory});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    // Create gradient colors
    final gradient = LinearGradient(
      colors: [
        Colors.red.shade400,
        Colors.orange.shade400,
        Colors.yellow.shade600,
        Colors.green.shade400,
      ],
      stops: [0.0, 0.35, 0.7, 1.0],
    );

    // Calculate chart dimensions
    final chartRect = Rect.fromLTWH(0, 40, size.width, size.height - 80);

    if (weightHistory.isEmpty) return;

    // Find min and max values for scaling
    final minWeight = weightHistory.map((e) => e.y).reduce((a, b) => a < b ? a : b);
    final maxWeight = weightHistory.map((e) => e.y).reduce((a, b) => a > b ? a : b);
    final weightRange = maxWeight - minWeight;

    // Create path for the curve
    final path = Path();
    final points = <Offset>[];

    for (int i = 0; i < weightHistory.length; i++) {
      final spot = weightHistory[i];
      final x = chartRect.left + (spot.x / (weightHistory.length - 1)) * chartRect.width;
      final y = chartRect.bottom - ((spot.y - minWeight) / weightRange) * chartRect.height;
      points.add(Offset(x, y));

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        // Create smooth curve
        final prevPoint = points[i - 1];
        final controlPoint1 = Offset(prevPoint.dx + (x - prevPoint.dx) * 0.5, prevPoint.dy);
        final controlPoint2 = Offset(prevPoint.dx + (x - prevPoint.dx) * 0.5, y);
        path.cubicTo(controlPoint1.dx, controlPoint1.dy, controlPoint2.dx, controlPoint2.dy, x, y);
      }
    }

    // Apply gradient to the path
    final gradientPaint = Paint()
      ..shader = gradient.createShader(chartRect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, gradientPaint);

    // Draw dots at key points
    final dotPaint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < points.length; i++) {
      Color dotColor;
      if (i == 0) {
        dotColor = Colors.red.shade400;
      } else if (i == 3 && points.length > 3) {
        dotColor = Colors.orange.shade400;
      } else if (i == points.length - 1) {
        dotColor = Colors.green.shade400;
      } else {
        continue; // Skip intermediate points
      }

      // Draw white border
      canvas.drawCircle(points[i], 8, Paint()..color = Colors.white);
      // Draw colored dot
      canvas.drawCircle(points[i], 6, Paint()..color = dotColor);
    }

    // Draw area under curve
    final areaPath = Path.from(path);
    areaPath.lineTo(chartRect.right, chartRect.bottom);
    areaPath.lineTo(chartRect.left, chartRect.bottom);
    areaPath.close();

    final areaPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.green.shade400.withOpacity(0.2),
          Colors.orange.shade400.withOpacity(0.1),
          Colors.red.shade400.withOpacity(0.05),
        ],
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
      ).createShader(chartRect)
      ..style = PaintingStyle.fill;

    canvas.drawPath(areaPath, areaPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// OnboardingUpdateFlow - Flow cập nhật thông tin cá nhân qua các màn hình onboarding
class OnboardingUpdateFlow extends StatefulWidget {
  @override
  _OnboardingUpdateFlowState createState() => _OnboardingUpdateFlowState();
}

class _OnboardingUpdateFlowState extends State<OnboardingUpdateFlow> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Danh sách các màn hình onboarding cho việc cập nhật
  final List<Widget> _pages = [
    const AgeSelectionPage(updateMode: true),
    const HeightSelectionPage(updateMode: true),
    const WeightSelectionPage(updateMode: true),
    const DietGoalPage(updateMode: true),
    const ActivityLevelPage(updateMode: true),
    const WeightGainPacePage(),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      setState(() {
        _currentPage++;
      });
      _pageController.nextPage(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Hoàn thành flow, trả về true để báo hiệu cập nhật thành công
      Navigator.of(context).pop(true);
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      setState(() {
        _currentPage--;
      });
      _pageController.previousPage(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Nếu đang ở trang đầu tiên, thoát khỏi flow
      Navigator.of(context).pop(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: _previousPage,
        ),
        title: Text(
          'Cập nhật thông tin',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Progress indicator
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                Text(
                  '${_currentPage + 1}/${_pages.length}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: LinearProgressIndicator(
                    value: (_currentPage + 1) / _pages.length,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(OnboardingStyles.primaryColor),
                  ),
                ),
              ],
            ),
          ),

          // Page content
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemCount: _pages.length,
              itemBuilder: (context, index) {
                return _pages[index];
              },
            ),
          ),

          // Navigation buttons
          Container(
            padding: EdgeInsets.all(20),
            child: Row(
              children: [
                if (_currentPage > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _previousPage,
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: OnboardingStyles.primaryColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: Text(
                        'Quay lại',
                        style: TextStyle(
                          color: OnboardingStyles.primaryColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                if (_currentPage > 0) SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _nextPage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: OnboardingStyles.primaryColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Text(
                      _currentPage == _pages.length - 1 ? 'Hoàn thành' : 'Tiếp tục',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
    final userDataProvider = Provider.of<udp.UserDataProvider>(context);
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
      case 'target_weight':
        pageTitle = 'Cập nhật cân nặng mục tiêu';
        pageContent = _buildTargetWeightUpdatePage(context, userDataProvider, _profileScreenState);
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
  Widget _buildNameUpdatePage(BuildContext context, udp.UserDataProvider userDataProvider, _ProfileScreenState? profileScreenState) {
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
  Widget _buildAgeUpdatePage(BuildContext context, udp.UserDataProvider userDataProvider, _ProfileScreenState? profileScreenState) {
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
  Widget _buildGenderUpdatePage(BuildContext context, udp.UserDataProvider userDataProvider, _ProfileScreenState? profileScreenState) {
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
                  userDataProvider.gender = selectedGender;

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
  Widget _buildHeightUpdatePage(BuildContext context, udp.UserDataProvider userDataProvider, _ProfileScreenState? profileScreenState) {
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
  Widget _buildWeightUpdatePage(BuildContext context, udp.UserDataProvider userDataProvider, _ProfileScreenState? profileScreenState) {
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

  // Page to update target weight
  Widget _buildTargetWeightUpdatePage(BuildContext context, udp.UserDataProvider userDataProvider, _ProfileScreenState? profileScreenState) {
    final TextEditingController targetWeightController = TextEditingController(text: userDataProvider.targetWeightKg.toString());

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cập nhật cân nặng mục tiêu của bạn',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Nhập cân nặng mục tiêu mà bạn muốn đạt được',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 24),
            TextField(
              controller: targetWeightController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Cân nặng mục tiêu (kg)',
                border: OutlineInputBorder(),
                suffixText: 'kg',
              ),
            ),
            SizedBox(height: 32),
            Container(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  if (targetWeightController.text.isNotEmpty) {
                    try {
                      final double newTargetWeight = double.parse(targetWeightController.text);

                      if (newTargetWeight > 20 && newTargetWeight < 300) {
                        // Cập nhật cân nặng mục tiêu trong UserDataProvider
                        userDataProvider.targetWeightKg = newTargetWeight;

                        // Cập nhật thông tin người dùng thông qua API
                        if (profileScreenState != null) {
                          await profileScreenState._updateFullUserProfile(
                            targetWeightKg: newTargetWeight,
                          );
                        }

                        // Hiển thị thông báo thành công
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Đã cập nhật cân nặng mục tiêu thành công!'),
                            backgroundColor: Colors.green,
                          ),
                        );

                        Navigator.of(context).pop();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Vui lòng nhập cân nặng mục tiêu hợp lệ (20-300 kg)'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Vui lòng nhập số hợp lệ'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
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