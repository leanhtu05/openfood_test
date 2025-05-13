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
import '../../services/onboarding_service.dart';
import 'package:provider/provider.dart';
import '../../providers/user_data_provider.dart';
import '../../screens/home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
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
    await userData.saveUserData();
    
    // Chuyển đến màn hình chính
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen()),
      );
    }
  }

  void _goToNextPage() {
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

  void _goToPreviousPage() {
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
      _goToPreviousPage();
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
                  onPressed: _goToPreviousPage,
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
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                  minHeight: 6,
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
                  onPressed: _goToNextPage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
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