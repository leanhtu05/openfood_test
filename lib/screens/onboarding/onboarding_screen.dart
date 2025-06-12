import 'package:flutter/material.dart';
import 'welcome_page.dart';
import 'gender_selection_page.dart';
import 'height_selection_page.dart';
import 'age_selection_page.dart';
import 'weight_selection_page.dart';
import 'diet_goal_page.dart';
import 'target_weight_page.dart';
import 'event_selection_page.dart';
import 'event_date_page.dart';
import 'activity_level_page.dart';
import 'weight_gain_pace_page.dart';
import 'diet_restriction_page.dart';
import 'diet_preference_page.dart';
import 'health_condition_page.dart';
import 'name_input_page.dart';
import '../../services/onboarding_service.dart';
import 'package:provider/provider.dart';
import '../../providers/user_data_provider.dart';
import '../../screens/home_screen.dart';
import '../../utils/constants.dart';

// Lớp wrapper cho các trang onboarding khi ở chế độ updateMode
class MaterialOnboardingPage extends StatelessWidget {
  final Widget child;
  final String title;
  final Color? backgroundColor;
  final Color? appBarColor;
  
  const MaterialOnboardingPage({
    Key? key,
    required this.child,
    required this.title,
    this.backgroundColor,
    this.appBarColor,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: appBarColor ?? OnboardingStyles.primaryColor,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Material(
        color: backgroundColor ?? Colors.white,
        child: child,
      ),
    );
  }
}

// Định nghĩa các hằng số cho UI
class OnboardingStyles {
  // Colors
  static const Color primaryColor = Color(0xFF4CAF50); // Xanh lá đậm
  static const Color primaryColorLight = Color(0xFFE8F5E9); // Xanh lá nhạt
  static const Color accentColor = Color(0xFF4CAF50); // Xanh lá đậm
  static const Color titleColor = Color(0xFF1A1A45); // Tím đậm gần như đen
  static const Color textColor = Color(0xFF1A1A45); // Tím đậm gần như đen
  static const Color textSecondaryColor = Color(0xFF757575); // Xám đậm
  static const Color backgroundColor = Colors.white;
  static const Color cardColor = Color(0xFFF5F5F5); // Màu xám nhạt cho card
  static const Color selectedCardBorder = Color(0xFF4CAF50); // Viền xanh lá khi chọn
  static const Color buttonTextColor = Colors.white; // Màu chữ nút
  
  // Text styles
  static const TextStyle appTitleStyle = TextStyle(
    fontSize: 40,
    fontWeight: FontWeight.bold,
    color: titleColor,
    letterSpacing: -0.5,
  );
  
  static const TextStyle pageTitleStyle = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: textColor,
    letterSpacing: -0.5,
  );
  
  static const TextStyle bodyTextStyle = TextStyle(
    fontSize: 16,
    color: textColor,
    height: 1.5,
  );
  
  static const TextStyle captionStyle = TextStyle(
    fontSize: 14,
    color: textSecondaryColor,
    height: 1.5,
  );
  
  // Button styles
  static ButtonStyle primaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: primaryColor,
    foregroundColor: buttonTextColor,
    padding: const EdgeInsets.symmetric(vertical: 16),
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(30),
    ),
  );
  
  // Selection styles
  static BoxDecoration selectedItemDecoration = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: selectedCardBorder, width: 2),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.05),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ],
  );
  
  static BoxDecoration unselectedItemDecoration = BoxDecoration(
    color: cardColor,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: Colors.transparent),
  );
  
  // Padding
  static const EdgeInsets screenPadding = EdgeInsets.all(24.0);
  
  // Sizes
  static const double iconSize = 120.0;
  static const double progressHeight = 6.0;
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => OnboardingScreenState();
}

class OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  
  final List<Widget> _pages = [
    const WelcomePage(),
    const GenderSelectionPage(),
    const HeightSelectionPage(),
    const AgeSelectionPage(),
    const WeightSelectionPage(),
    const DietGoalPage(),
    const TargetWeightPage(),
    const EventSelectionPage(),
    const EventDatePage(),
    const ActivityLevelPage(),
    const WeightGainPacePage(),
    const DietRestrictionPage(),
    const DietPreferencePage(),
    const HealthConditionPage(),
    const NameInputPage(),
  ];
  
  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // Phương thức để hoàn thành onboarding
  Future<void> _completeOnboarding() async {
    // Lưu trạng thái đã hoàn thành onboarding
    await OnboardingService.setOnboardingComplete();
    
    // Đảm bảo dữ liệu người dùng đã được lưu
    final userData = Provider.of<UserDataProvider>(context, listen: false);
    
    // Kiểm tra xem tên đã được nhập chưa
    if (userData.name.isEmpty) {
      // Hiển thị thông báo nếu chưa nhập tên
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Vui lòng nhập tên của bạn để hoàn thành'),
          backgroundColor: Colors.orange,
        ),
      );
      return; // Không tiếp tục nếu chưa nhập tên
    }
    
    // Lưu tất cả dữ liệu người dùng
    await userData.saveUserData();
    
    // In ra thông tin xác nhận
    print('✅ Onboarding hoàn tất! Tên người dùng: ${userData.name}');
    
    // Chuyển đến màn hình chính
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen()),
      );
    }
  }

  // Public methods for navigation that can be accessed by other pages
  void goToNextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Hoàn thành onboarding
      _completeOnboarding();
    }
  }

  void goToPreviousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  // Xử lý khi người dùng nhấn nút back của thiết bị
  Future<bool> _onWillPop() async {
    if (_currentPage == 0) {
      // Nếu ở trang đầu tiên, hiển thị dialog xác nhận thoát
      final shouldExit = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Thoát khỏi thiết lập'),
          content: const Text('Bạn có muốn thoát khỏi quá trình thiết lập không?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Thoát'),
            ),
          ],
        ),
      ) ?? false;
      return shouldExit;
    } else {
      // Nếu không phải trang đầu tiên, quay lại trang trước đó
      goToPreviousPage();
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          leading: _currentPage > 0
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  color: Colors.black54,
                  onPressed: goToPreviousPage,
                )
              : null,
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Progress indicator
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: LinearProgressIndicator(
                  value: (_currentPage + 1) / _pages.length,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(OnboardingStyles.primaryColor),
                  minHeight: OnboardingStyles.progressHeight,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              
              // Nội dung các trang
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const ClampingScrollPhysics(),
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  children: _pages,
                ),
              ),
              
              // Nút Tiếp tục
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton(
                  onPressed: goToNextPage,
                  style: OnboardingStyles.primaryButtonStyle,
                  child: Text(
                    _currentPage < _pages.length - 1 ? 'Tiếp tục' : 'Hoàn thành',
                    style: const TextStyle(
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
} 