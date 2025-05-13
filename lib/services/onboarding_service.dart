import 'package:shared_preferences/shared_preferences.dart';

class OnboardingService {
  static const String _hasCompletedOnboardingKey = 'has_completed_onboarding';

  // Lưu trạng thái đã hoàn thành onboarding
  static Future<void> setOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasCompletedOnboardingKey, true);
  }

  // Kiểm tra xem người dùng đã hoàn thành onboarding chưa
  static Future<bool> hasCompletedOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hasCompletedOnboardingKey) ?? false;
  }

  // Reset trạng thái onboarding (cho mục đích testing)
  static Future<void> resetOnboardingStatus() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasCompletedOnboardingKey, false);
  }
} 