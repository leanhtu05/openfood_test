import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:openfood/screens/home_screen.dart';
import 'package:openfood/screens/meal_screen.dart';
import 'package:openfood/screens/exercise_log_screen.dart';
import 'package:openfood/screens/exercise_history_screen.dart';
import 'package:openfood/screens/water_history_screen.dart';
import 'package:openfood/screens/combined_history_screen.dart';
import 'package:openfood/providers/exercise_provider.dart';
import 'package:openfood/providers/water_provider.dart';
import 'package:openfood/providers/food_provider.dart';
import 'package:openfood/routes.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:openfood/services/food_recognition_service.dart';
import 'package:openfood/services/food_database_service.dart';
import 'package:openfood/services/onboarding_service.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'providers/user_data_provider.dart';
import 'providers/meal_plan_provider.dart';

void main() async {
  // Đảm bảo WidgetsFlutterBinding được khởi tạo
  WidgetsFlutterBinding.ensureInitialized();

  // Khởi tạo Firebase
  try {
    await Firebase.initializeApp();
    print('Firebase đã được khởi tạo thành công');
  } catch (e) {
    print('Lỗi khi khởi tạo Firebase: $e');
  }

  // Khởi tạo ngôn ngữ tiếng Việt cho định dạng ngày tháng
  await initializeDateFormatting('vi_VN', null);

  // Khởi tạo Hive
  final appDocumentDir = await getApplicationDocumentsDirectory();
  await Hive.initFlutter(appDocumentDir.path);

  // Khởi tạo các service
  await initializeServices();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ExerciseProvider()),
        ChangeNotifierProvider(create: (_) => WaterProvider()),
        ChangeNotifierProvider(create: (_) => FoodProvider()),
        ChangeNotifierProvider(create: (context) => UserDataProvider()),
        ChangeNotifierProvider(create: (_) => MealPlanProvider()),
      ],
      child: MyApp(),
    ),
  );
}

// Khởi tạo các service cần thiết
Future<void> initializeServices() async {
  // Khởi tạo Food Recognition Service
  final foodRecognitionService = FoodRecognitionService();
  await foodRecognitionService.initialize();

  // Khởi tạo Food Database Service
  final foodDatabaseService = FoodDatabaseService();
  await foodDatabaseService.initialize();
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'DietAI',
      theme: ThemeData(
        primarySwatch: Colors.green,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: FutureBuilder<bool>(
        future: OnboardingService.hasCompletedOnboarding(),
        builder: (context, snapshot) {
          // Hiển thị màn hình loading trong khi đang kiểm tra
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }
          
          // Kiểm tra xem người dùng đã hoàn thành onboarding chưa
          final hasCompletedOnboarding = snapshot.data ?? false;
          
          // Nếu đã hoàn thành, chuyển đến màn hình chính
          // Nếu chưa, chuyển đến màn hình onboarding
          return hasCompletedOnboarding ? HomeScreen() : const OnboardingScreen();
        },
      ),
      routes: routes,
      onGenerateRoute: generateRoute,
      // Hỗ trợ hiển thị tiếng Việt
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [
        const Locale('vi', 'VN'),
        const Locale('en', 'US'),
      ],
      locale: const Locale('vi', 'VN'),
    );
  }
}
