import 'package:flutter/material.dart';
import '../utils/constants.dart';
import 'package:provider/provider.dart';
import '../providers/user_data_provider.dart';
import '../screens/profile_screen.dart' as profile;
import '../utils/tdee_calculator.dart';
import '../services/auth_service.dart';
import '../screens/auth/auth_screen.dart' as auth;
import '../services/api_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _showBackToTopButton = false;
  bool _isLoading = false;
  bool _isCheckingApi = false;
  Map<String, dynamic>? _apiStatus;
  
  // Auth service
  late AuthService authService;
  
  @override
  void initState() {
    super.initState();
    authService = Provider.of<AuthService>(context, listen: false);
  }

  // Phương thức cập nhật thông tin người dùng thông qua API
  Future<bool> updateUserProfileViaApi(Map<String, dynamic> userData) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Gọi phương thức từ AuthService
      final success = await authService.updateUserProfileViaApi(userData);
      
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
      setState(() {
        _isLoading = false;
      });
      
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
  Future<bool> updateFullUserProfile({
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
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Gọi phương thức từ AuthService
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
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi cập nhật thông tin: $e'),
          backgroundColor: Colors.red,
        ),
      );
      
      return false;
    }
  }

  Future<void> _checkApiConnection() async {
    setState(() {
      _isCheckingApi = true;
      _apiStatus = null;
    });

    try {
      final result = await ApiService.checkApiConnectionDetailed();
      
      setState(() {
        _apiStatus = result;
        _isCheckingApi = false;
      });
    } catch (e) {
      setState(() {
        _apiStatus = {
          'success': false,
          'message': 'Lỗi không xác định: $e',
        };
        _isCheckingApi = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final userDataProvider = Provider.of<UserDataProvider>(context);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.settings, size: 24),
            SizedBox(width: 8),
            Text("Cài đặt"),
          ],
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Account Section
              _buildSectionTitle("Tài khoản"),
              Card(
                elevation: 0,
                color: Colors.grey.shade50,
                margin: EdgeInsets.only(bottom: 24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAccountHeader(context, authService),
                    if (authService.isPremiumUser()) ...[
                      _buildSettingItem(
                        leadingText: "Tt",
                        title: "Tên",
                        value: userDataProvider.name,
                        icon: Icons.arrow_forward_ios,
                        onTap: () {
                          // Navigate to profile update flow for name
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => profile.ProfileUpdateFlow(initialStep: 'name'),
                            ),
                          );
                        },
                      ),
                      _buildSettingItem(
                        leadingIcon: Icons.cake,
                        title: "Tuổi",
                        value: "${userDataProvider.age}",
                        icon: Icons.arrow_forward_ios,
                        onTap: () {
                          // Navigate to profile update flow for age
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => profile.ProfileUpdateFlow(initialStep: 'age'),
                            ),
                          );
                        },
                      ),
                      _buildSettingItem(
                        leadingIcon: Icons.person,
                        title: "Giới tính",
                        value: userDataProvider.gender,
                        icon: Icons.arrow_forward_ios,
                        onTap: () {
                          // Navigate to profile update flow for gender
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => profile.ProfileUpdateFlow(initialStep: 'gender'),
                            ),
                          );
                        },
                      ),
                      _buildSettingItem(
                        leadingIcon: Icons.height,
                        title: "Chiều cao",
                        value: "${userDataProvider.heightCm} cm",
                        icon: Icons.arrow_forward_ios,
                        onTap: () {
                          // Navigate to profile update flow for height
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => profile.ProfileUpdateFlow(initialStep: 'height'),
                            ),
                          );
                        },
                      ),
                      _buildSettingItem(
                        leadingIcon: Icons.monitor_weight,
                        title: "Cân nặng",
                        value: "${userDataProvider.weightKg} kg",
                        icon: Icons.arrow_forward_ios,
                        onTap: () {
                          // Navigate to profile update flow for weight
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => profile.ProfileUpdateFlow(initialStep: 'weight'),
                            ),
                          );
                        },
                      ),
                      _buildSettingItem(
                        leadingIcon: Icons.straighten,
                        title: "Đơn vị",
                        value: "Hệ mét(kg, cm)",
                        icon: Icons.arrow_forward_ios,
                        onTap: () async {
                          // Hiển thị dialog chọn đơn vị
                          final selectedUnit = await showDialog<String>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text('Chọn đơn vị đo lường'),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ListTile(
                                    title: Text('Hệ mét (kg, cm)'),
                                    onTap: () => Navigator.of(context).pop('metric'),
                                  ),
                                  ListTile(
                                    title: Text('Hệ Anh (lb, in)'),
                                    onTap: () => Navigator.of(context).pop('imperial'),
                                  ),
                                ],
                              ),
                            ),
                          );
                          
                          if (selectedUnit != null) {
                            // Cập nhật đơn vị đo lường
                            await updateFullUserProfile(
                              measurementSystem: selectedUnit,
                            );
                          }
                        },
                        isLast: !authService.isAuthenticated, // Adjusted isLast logic
                      ),
                    ],
                    _buildSettingItem(
                      leadingIcon: Icons.sync,
                      title: "Tích hợp",
                      trailingWidget: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: 200),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              authService.isPremiumUser()
                                  ? Icons.check_circle
                                  : Icons.warning,
                              color: authService.isPremiumUser()
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                            SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                authService.isPremiumUser()
                                    ? "Đã kết nối"
                                    : "Chưa kết nối",
                                style: TextStyle(color: Colors.grey.shade600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: Colors.grey.shade400,
                            ),
                          ],
                        ),
                      ),
                      onTap: () {
                        // Navigate to integration settings
                        if (!authService.isPremiumUser()) {
                          _showPremiumFeatureDialog(context);
                        } else {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => profile.ProfileUpdateFlow(initialStep: 'integration'),
                            ),
                          );
                        }
                      },
                      isLast: !authService.isAuthenticated && !authService.isPremiumUser(),
                    ),
                    if (authService.isAuthenticated)
                      _buildSettingItem(
                        leadingIcon: Icons.logout,
                        title: "Đăng xuất",
                        icon: Icons.arrow_forward_ios,
                        onTap: () async {
                          final confirm = await _showLogoutConfirmationDialog(context);
                          if (confirm == true) {
                            await authService.logout();
                            // Optionally navigate or update UI after logout
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(builder: (context) => auth.AuthScreen(isLoginMode: true)),
                                  (Route<dynamic> route) => false,
                            );
                          }
                        },
                        isLast: true,
                      ),
                  ],
                ),
              ),

              // Diet Section
              _buildSectionTitle("Chế độ ăn"),
              Card(
                elevation: 0,
                color: Colors.grey.shade50,
                margin: EdgeInsets.only(bottom: 24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSettingItem(
                      leadingIcon: Icons.track_changes,
                      title: "Mục tiêu",
                      trailingWidget: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: 200),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade100,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                "Cập nhật",
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: Colors.grey.shade400,
                            ),
                          ],
                        ),
                      ),
                      onTap: () {
                        // Navigate to profile update flow for updating goals
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => profile.ProfileUpdateFlow(initialStep: 'goal'),
                          ),
                        );
                      },
                    ),
                    _buildSettingItem(
                      leadingIcon: Icons.directions_run,
                      title: "Mức độ hoạt động",
                      value: userDataProvider.activityLevel.isNotEmpty
                          ? activityLevelToString(userDataProvider.activityLevel)
                          : "Chưa đặt", // Provide a default or placeholder
                      icon: Icons.arrow_forward_ios,
                      onTap: () {
                        // Navigate to profile update flow starting from activity level
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => profile.ProfileUpdateFlow(initialStep: 'activity'),
                          ),
                        );
                      },
                    ),
                    _buildSettingItem(
                      leadingIcon: Icons.block,
                      title: "Hạn chế",
                      value: userDataProvider.dietaryRestrictions.isEmpty
                          ? "Không có"
                          : userDataProvider.dietaryRestrictions.join(', '),
                      icon: Icons.arrow_forward_ios,
                      onTap: () {
                        if (!authService.isPremiumUser()) {
                          _showPremiumFeatureDialog(context);
                          return;
                        }

                        // Navigate to profile update flow
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => profile.ProfileUpdateFlow(initialStep: 'restrictions'),
                          ),
                        );
                      },
                    ),
                    _buildSettingItem(
                      leadingIcon: Icons.restaurant_menu,
                      title: "Chế độ ăn",
                      value: "Trí tuệ nhân tạo", // Placeholder, update as needed
                      icon: Icons.arrow_forward_ios,
                      onTap: () {
                        if (!authService.isPremiumUser()) {
                          _showPremiumFeatureDialog(context);
                        } else {
                          // TODO: Navigate to AI diet settings if available
                        }
                      },
                    ),
                    _buildSettingItem(
                      leadingIcon: Icons.favorite,
                      title: "Tình trạng sức khỏe",
                      value: userDataProvider.healthConditions.isEmpty
                          ? "Không có"
                          : userDataProvider.healthConditions.join(', '),
                      icon: Icons.arrow_forward_ios,
                      onTap: () {
                        if (!authService.isPremiumUser()) {
                          _showPremiumFeatureDialog(context);
                        } else {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => profile.ProfileUpdateFlow(initialStep: 'healthConditions'),
                            ),
                          );
                        }
                      },
                    ),
                    _buildSwitchItem(
                      leadingIcon: Icons.fitness_center,
                      title: "Thêm calo từ bài tập vào mục tiêu hàng ngày",
                      value: userDataProvider.addExerciseCaloriesToGoal, // Assuming this exists in UserDataProvider
                      onChanged: (value) {
                        if (!authService.isPremiumUser()) {
                          _showPremiumFeatureDialog(context);
                          // Reset switch if not premium and tries to change
                          // This requires the switch to be stateful or UserDataProvider to notify listeners
                        } else {
                          userDataProvider.updateAddExerciseCaloriesToGoal(value);
                        }
                      },
                      isLast: true,
                    ),
                  ],
                ),
              ),

              // App Section
              _buildSectionTitle("Ứng dụng"),
              Card(
                elevation: 0,
                color: Colors.grey.shade50,
                margin: EdgeInsets.only(bottom: 24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!authService.isPremiumUser()) // Show promo only if not premium
                      _buildPromotionItem(
                        leadingIcon: Icons.stars,
                        title: "Dùng thử FitAI miễn phí! Giảm giá 80% cho bạn!",
                        icon: Icons.arrow_forward_ios,
                        onTap: () {
                          // TODO: Navigate to Promotion Screen
                        },
                      ),
                    _buildSettingItem(
                      leadingIcon: Icons.workspace_premium,
                      title: "Nâng cấp lên PRO",
                      icon: Icons.arrow_forward_ios,
                      onTap: () {
                        if (!authService.isAuthenticated) {
                          _showAuthRequiredDialog(context);
                          return;
                        }
                        // TODO: Navigate to upgrade page
                      },
                    ),
                    _buildSettingItem(
                      leadingIcon: Icons.all_inclusive,
                      title: "Ưu đãi trọn đời",
                      icon: Icons.arrow_forward_ios,
                      onTap: () {
                        if (!authService.isAuthenticated) {
                          _showAuthRequiredDialog(context);
                          return;
                        }
                        // TODO: Navigate to lifetime deals page
                      },
                    ),
                    _buildSettingItem(
                      leadingIcon: Icons.star,
                      title: "Đánh giá chúng tôi",
                      icon: Icons.arrow_forward_ios,
                      onTap: () {
                        // TODO: Implement app review functionality
                      },
                    ),
                    _buildSettingItem(
                      leadingIcon: Icons.email,
                      title: "Liên hệ chúng tôi",
                      icon: Icons.arrow_forward_ios,
                      onTap: () {
                        // TODO: Implement contact us functionality (e.g., mailto link)
                      },
                    ),
                    _buildSettingItem(
                      leadingIcon: Icons.manage_accounts,
                      title: "Quản lý đăng ký",
                      icon: Icons.arrow_forward_ios,
                      onTap: () {
                        if (!authService.isAuthenticated) {
                          _showAuthRequiredDialog(context);
                          return;
                        }
                        // TODO: Navigate to subscription management
                      },
                    ),
                    _buildSettingItem(
                      leadingIcon: Icons.description,
                      title: "Điều khoản dịch vụ",
                      icon: Icons.arrow_forward_ios,
                      onTap: () {
                        // TODO: Navigate to Terms of Service page/URL
                      },
                    ),
                    _buildSettingItem(
                      leadingIcon: Icons.security,
                      title: "Chính sách bảo mật",
                      icon: Icons.arrow_forward_ios,
                      onTap: () {
                        // TODO: Navigate to Privacy Policy page/URL
                      },
                    ),
                    _buildSettingItem(
                      leadingIcon: Icons.language,
                      title: "Ngôn ngữ",
                      value: "Tiếng Việt", // This could be dynamic in the future
                      icon: Icons.arrow_forward_ios,
                      onTap: () {
                        // TODO: Implement language selection
                      },
                    ),
                    _buildSettingItem(
                      leadingIcon: Icons.flag,
                      title: "Quốc gia",
                      value: "Việt Nam", // This could be dynamic or from user profile
                      icon: Icons.arrow_forward_ios,
                      onTap: () {
                        // TODO: Implement country selection if needed
                      },
                      isLast: true,
                    ),
                  ],
                ),
              ),

              // Version info
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    "Phiên bản 1.2.3", // Example, fetch from package_info_plus if needed
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),

              // System Section
              _buildSectionTitle("Hệ thống"),
              Card(
                elevation: 0,
                color: Colors.grey.shade50,
                margin: EdgeInsets.only(bottom: 24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSettingItem(
                      leadingIcon: Icons.cloud,
                      title: "Kiểm tra kết nối API",
                      trailingWidget: _isCheckingApi
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                              ),
                            )
                          : Icon(
                              Icons.refresh,
                              size: 20,
                              color: Colors.grey.shade600,
                            ),
                      onTap: _isCheckingApi ? () {} : _checkApiConnection,
                    ),
                    
                    if (_apiStatus != null)
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _apiStatus!['success'] == true
                                ? Colors.green.withOpacity(0.1)
                                : Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _apiStatus!['success'] == true
                                  ? Colors.green
                                  : Colors.red,
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    _apiStatus!['success'] == true
                                        ? Icons.check_circle
                                        : Icons.error,
                                    color: _apiStatus!['success'] == true
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _apiStatus!['message'] ?? 'Không có thông báo',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (_apiStatus!['status_code'] != null) ...[
                                SizedBox(height: 8),
                                Text('Mã trạng thái: ${_apiStatus!['status_code']}'),
                              ],
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Section title widget
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8, top: 16), // Added top padding
      child: Text(
        title,
        style: TextStyle(
          fontSize: 28, // Slightly reduced size for better balance
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  // Account Header with user icon and login button
  Widget _buildAccountHeader(BuildContext context, AuthService authService) {
    final user = authService.currentUser; // Use getter if available, or authService.user

    if (authService.isAuthenticated && user != null) {
      return ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        leading: user.photoURL != null && user.photoURL!.isNotEmpty
            ? CircleAvatar(
          backgroundImage: NetworkImage(user.photoURL!),
          radius: 24, // Increased radius
        )
            : Container(
          width: 48, // Increased size
          height: 48, // Increased size
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.blue.shade100,
          ),
          alignment: Alignment.center,
          child: Text(
            user.email?.isNotEmpty == true
                ? user.email![0].toUpperCase()
                : (user.displayName?.isNotEmpty == true ? user.displayName![0].toUpperCase() : "U"),
            style: TextStyle(
              fontSize: 20, // Adjusted size
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade800,
            ),
          ),
        ),
        title: Text(
          user.displayName ?? user.email?.split('@').first ?? "Người dùng",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600, // Slightly bolder
          ),
        ),
        subtitle: Text(
          user.isAnonymous == true ? "Chế độ khách" : (user.email ?? "Chưa có email"),
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 14,
          ),
        ),
        trailing: user.isAnonymous == true
            ? ElevatedButton.icon(
          icon: Icon(Icons.login, size: 18), // Changed icon to login
          label: Text("Đăng nhập"),       // Changed text to login
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange.shade700, // Changed color for better CTA
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          onPressed: () {
            Navigator.of(context).pushReplacement( // Use pushReplacement
              MaterialPageRoute(
                builder: (context) => auth.AuthScreen(isLoginMode: true),
              ),
            );
          },
        )
            : null, // No button if fully authenticated and not anonymous
      );
    } else {
      // User not authenticated
      return ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey.shade300,
          ),
          alignment: Alignment.center,
          child: Icon(Icons.person_outline, color: Colors.grey.shade700, size: 28),
        ),
        title: Text(
          "Tài khoản",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: ElevatedButton.icon(
          icon: Icon(Icons.login, size: 18),
          label: Text("Đăng nhập"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade600,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => auth.AuthScreen(isLoginMode: true),
              ),
            );
          },
        ),
      );
    }
  }

  // Regular settings item
  Widget _buildSettingItem({
    IconData? leadingIcon,
    String? leadingText,
    required String title,
    String? value,
    IconData? icon = Icons.arrow_forward_ios, // Default icon
    Widget? trailingWidget,
    required VoidCallback onTap,
    bool isLast = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0), // Adjusted padding
          leading: leadingIcon != null
              ? Container(
            width: 40, // Standardized width
            height: 40, // Standardized height
            alignment: Alignment.center,
            child: Icon(leadingIcon, color: Colors.black87, size: 24), // Standardized icon size
          )
              : leadingText != null
              ? Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            child: Text(
              leadingText,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87
              ),
            ),
          )
              : SizedBox(width: 40), // Placeholder if no leading icon/text
          title: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          trailing: trailingWidget ??
              Row( // Removed ConstrainedBox, relying on Flexible and ListTile's handling
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (value != null)
                    Flexible( // Ensures text truncates if too long
                      child: Text(
                        value,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end, // Align text to the end
                      ),
                    ),
                  if (value != null && icon != null) SizedBox(width: 8), // Add space only if value exists
                  if (icon != null)
                    Icon(
                      icon,
                      size: 16,
                      color: Colors.grey.shade400,
                    ),
                ],
              ),
          onTap: onTap,
        ),
        if (!isLast)
          Divider(
            height: 1,
            indent: 72, // Aligns with title start after leading widget (40 + 16 + 16 approx)
            endIndent: 16,
            color: Colors.grey.shade300,
          ),
      ],
    );
  }

  // Switch setting item
  Widget _buildSwitchItem({
    required IconData leadingIcon,
    required String title,
    required bool value,
    required Function(bool) onChanged,
    bool isLast = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          secondary: Container( // Used secondary for better alignment with ListTile items
            width: 40,
            height: 40,
            alignment: Alignment.center,
            child: Icon(leadingIcon, color: Colors.black87, size: 24),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2, // Allow for two lines for longer titles
          ),
          value: value,
          onChanged: onChanged,
          activeColor: Colors.green,
          activeTrackColor: Colors.green.shade100,
        ),
        if (!isLast)
          Divider(
            height: 1,
            indent: 72,
            endIndent: 16,
            color: Colors.grey.shade300,
          ),
      ],
    );
  }

  // Promotion setting item
  Widget _buildPromotionItem({
    required IconData leadingIcon,
    required String title,
    IconData? icon = Icons.arrow_forward_ios,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.orange.shade600, // Changed color for promo
              borderRadius: BorderRadius.circular(8), // Rounded corners
            ),
            alignment: Alignment.center,
            child: Icon(leadingIcon, color: Colors.white, size: 20),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.orange.shade800, // Promo text color
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
          trailing: icon != null
              ? Icon(
            icon,
            size: 16,
            color: Colors.grey.shade400,
          )
              : null,
          onTap: onTap,
        ),
        if (!authService.isPremiumUser()) // Assuming you only show one promo, so divider is conditional or handled by isLast on next item
          Divider(
            height: 1,
            indent: 72,
            endIndent: 16,
            color: Colors.grey.shade300,
          ),
      ],
    );
  }

  // Show dialog for premium features
  void _showPremiumFeatureDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.lock_outline, color: Colors.orange.shade700),
            SizedBox(width: 8),
            Text('Tính năng PRO'),
          ],
        ),
        content: Text('Nâng cấp lên tài khoản PRO để sử dụng tính năng này và nhiều lợi ích khác!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Hủy', style: TextStyle(color: Colors.grey.shade700)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Navigate to your PRO upgrade screen
              // For now, it navigates to login if not authenticated, assuming premium needs auth.
              final authService = Provider.of<AuthService>(context, listen: false);
              if (!authService.isAuthenticated) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => auth.AuthScreen(isLoginMode: true),
                  ),
                );
              } else {
                // Navigate to actual PRO screen
              }
            },
            child: Text('Nâng cấp ngay'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  // Show dialog for auth required
  void _showAuthRequiredDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.login, color: Colors.blue.shade700),
            SizedBox(width: 8),
            Text('Yêu cầu đăng nhập'),
          ],
        ),
        content: Text('Bạn cần đăng nhập hoặc đăng ký tài khoản để sử dụng tính năng này.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Hủy', style: TextStyle(color: Colors.grey.shade700)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => auth.AuthScreen(isLoginMode: true), // Or isLoginMode: false for sign up
                ),
              );
            },
            child: Text('Đăng nhập / Đăng ký'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  // Show logout confirmation dialog
  Future<bool?> _showLogoutConfirmationDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.logout, color: Colors.red.shade700),
            SizedBox(width: 8),
            Text('Đăng xuất'),
          ],
        ),
        content: Text('Bạn có chắc chắn muốn đăng xuất khỏi tài khoản này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Hủy', style: TextStyle(color: Colors.grey.shade700)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Đăng xuất'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  // Helper to convert activity level key to string (example)
  String activityLevelToString(String levelKey) {
    // This should ideally come from your constants or a utility function
    switch (levelKey) {
      case 'sedentary':
        return 'Ít vận động';
      case 'light':
        return 'Vận động nhẹ';
      case 'moderate':
        return 'Vận động vừa';
      case 'active':
        return 'Năng động';
      case 'very_active':
        return 'Rất năng động';
      default:
        return levelKey; // Or "Không xác định"
    }
  }
}

// Dummy UserDataProvider for illustration - replace with your actual provider
// Make sure it has the fields being accessed, e.g., addExerciseCaloriesToGoal
// and methods like updateAddExerciseCaloriesToGoal.
// class UserDataProvider with ChangeNotifier {
//   String name = "Test User";
//   int age = 30;
//   String gender = "Nam";
//   double heightCm = 175;
//   double weightKg = 70;
//   String activityLevel = "moderate";
//   List<String> dietaryRestrictions = ["nuts"];
//   List<String> healthConditions = [];
//   bool addExerciseCaloriesToGoal = true;

//   void updateAddExerciseCaloriesToGoal(bool value) {
//     addExerciseCaloriesToGoal = value;
//     notifyListeners();
//   }
//   // ... other methods and properties
// }