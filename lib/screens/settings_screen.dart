import 'package:flutter/material.dart';
import '../utils/constants.dart';
import 'package:provider/provider.dart';
import '../providers/user_data_provider.dart';
import '../screens/profile_screen.dart' as profile;
import '../utils/tdee_calculator.dart';
import '../services/auth_service.dart';
import '../screens/auth/auth_screen.dart' as auth;

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final userDataProvider = Provider.of<UserDataProvider>(context);
    final authService = Provider.of<AuthService>(context);
    
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
                        onTap: () {
                          // Navigate to profile update flow for units
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => profile.ProfileUpdateFlow(initialStep: 'units'),
                            ),
                          );
                        },
                        isLast: true,
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
                      isLast: true,
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
                      value: "Hoạt động vừa p...",
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
                      value: "Không có",
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
                      value: "Trí tuệ nhân tạo",
                      icon: Icons.arrow_forward_ios,
                      onTap: () {
                        if (!authService.isPremiumUser()) {
                          _showPremiumFeatureDialog(context);
                        }
                      },
                    ),
                    _buildSettingItem(
                      leadingIcon: Icons.favorite,
                      title: "Tình trạng sức khỏe",
                      value: "Không có",
                      icon: Icons.arrow_forward_ios,
                      onTap: () {
                        if (!authService.isPremiumUser()) {
                          _showPremiumFeatureDialog(context);
                        }
                      },
                    ),
                    _buildSwitchItem(
                      leadingIcon: Icons.fitness_center,
                      title: "Thêm calo từ bài tập vào mục tiêu hàng ngày",
                      value: true,
                      onChanged: (value) {
                        if (!authService.isPremiumUser()) {
                          _showPremiumFeatureDialog(context);
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
                    _buildPromotionItem(
                      leadingIcon: Icons.stars,
                      title: "Dùng thử FitAI miễn phí! Giảm giá 80% cho bạn!",
                      icon: Icons.arrow_forward_ios,
                      onTap: () {},
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
                        // Navigate to upgrade page
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
                        // Navigate to lifetime deals page
                      },
                    ),
                    _buildSettingItem(
                      leadingIcon: Icons.star,
                      title: "Đánh giá chúng tôi",
                      icon: Icons.arrow_forward_ios,
                      onTap: () {},
                    ),
                    _buildSettingItem(
                      leadingIcon: Icons.email,
                      title: "Liên hệ chúng tôi",
                      icon: Icons.arrow_forward_ios,
                      onTap: () {},
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
                        // Navigate to subscription management
                      },
                    ),
                    _buildSettingItem(
                      leadingIcon: Icons.description,
                      title: "Điều khoản dịch vụ",
                      icon: Icons.arrow_forward_ios,
                      onTap: () {},
                    ),
                    _buildSettingItem(
                      leadingIcon: Icons.security,
                      title: "Chính sách bảo mật",
                      icon: Icons.arrow_forward_ios,
                      onTap: () {},
                    ),
                    _buildSettingItem(
                      leadingIcon: Icons.language,
                      title: "Ngôn ngữ",
                      value: "Tiếng Việt",
                      icon: Icons.arrow_forward_ios,
                      onTap: () {},
                    ),
                    _buildSettingItem(
                      leadingIcon: Icons.flag,
                      title: "Quốc gia",
                      value: "Việt Nam",
                      icon: Icons.arrow_forward_ios,
                      onTap: () {},
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
                    "Phiên bản 1.2.2",
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 14,
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
  
  // Section title widget
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }
  
  // Account Header with user icon and login button
  Widget _buildAccountHeader(BuildContext context, AuthService authService) {
    if (authService.isAuthenticated) {
      return ListTile(
        leading: authService.user?.photoURL != null
            ? CircleAvatar(
                backgroundImage: NetworkImage(authService.user!.photoURL!),
                radius: 20,
              )
            : Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blue.shade100,
                ),
                alignment: Alignment.center,
                child: Text(
                  authService.user?.email?.isNotEmpty == true 
                      ? authService.user!.email![0].toUpperCase()
                      : "U",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),
              ),
        title: Text(
          authService.user?.displayName ?? authService.user?.email?.split('@').first ?? "Người dùng",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: authService.user?.isAnonymous == true
            ? Text(
                "Chế độ khách",
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              )
            : Text(
                authService.user?.email ?? "",
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
        trailing: Container(
          height: 36,
          child: authService.user?.isAnonymous == true
              ? ElevatedButton.icon(
                  icon: Icon(Icons.upgrade, size: 18),
                  label: Text("Nâng cấp"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => auth.AuthScreen(isLoginMode: true),
                      ),
                    );
                  },
                )
              : null,
        ),
      );
    } else {
      return ListTile(
        leading: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          child: Icon(Icons.person, color: Colors.black),
        ),
        title: Text(
          "Tài khoản",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: Container(
          height: 36,
          child: ElevatedButton.icon(
            icon: Icon(Icons.login, size: 18),
            label: Text("Đăng nhập"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: EdgeInsets.symmetric(horizontal: 16),
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => auth.AuthScreen(isLoginMode: true),
                ),
              );
            },
          ),
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
    IconData? icon,
    Widget? trailingWidget,
    required VoidCallback onTap,
    bool isLast = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: leadingIcon != null
              ? Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  child: Icon(leadingIcon, color: Colors.black87),
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
                        ),
                      ),
                    )
                  : null,
          title: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          trailing: trailingWidget ??
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 180),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (value != null)
                      Text(
                        value,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    SizedBox(width: 8),
                    if (icon != null)
                      Icon(
                        icon,
                        size: 16,
                        color: Colors.grey.shade400,
                      ),
                  ],
                ),
              ),
          onTap: onTap,
        ),
        if (!isLast)
          Divider(
            height: 1,
            indent: 72,
            endIndent: 16,
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
          secondary: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            child: Icon(leadingIcon, color: Colors.black87),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
          value: value,
          onChanged: onChanged,
          activeColor: Colors.green,
        ),
        if (!isLast)
          Divider(
            height: 1,
            indent: 72,
            endIndent: 16,
          ),
      ],
    );
  }
  
  // Promotion setting item
  Widget _buildPromotionItem({
    required IconData leadingIcon,
    required String title,
    IconData? icon,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(4),
            ),
            alignment: Alignment.center,
            child: Icon(leadingIcon, color: Colors.white, size: 20),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
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
        Divider(
          height: 1,
          indent: 72,
          endIndent: 16,
        ),
      ],
    );
  }

  // Show dialog for premium features
  void _showPremiumFeatureDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Tính năng cao cấp'),
        content: Text('Tính năng này chỉ có sẵn cho người dùng đã đăng ký. Vui lòng đăng nhập với tài khoản đầy đủ để sử dụng.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => auth.AuthScreen(isLoginMode: true),
                ),
              );
            },
            child: Text('Đăng nhập'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFE65100),
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
        title: Text('Yêu cầu đăng nhập'),
        content: Text('Bạn cần đăng nhập để sử dụng tính năng này.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => auth.AuthScreen(isLoginMode: true),
                ),
              );
            },
            child: Text('Đăng nhập'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFE65100),
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
        title: Text('Đăng xuất'),
        content: Text('Bạn có chắc chắn muốn đăng xuất?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Đăng xuất'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
          ),
        ],
      ),
    );
  }
} 