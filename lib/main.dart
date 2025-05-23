import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
import 'package:openfood/providers/user_auth_provider.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'screens/settings_screen.dart';

bool isFirebaseInitialized = false;

Future<void> main() async {
  // Đảm bảo WidgetsFlutterBinding được khởi tạo
  WidgetsFlutterBinding.ensureInitialized();

  // Khởi tạo Hive trước Firebase để đảm bảo ứng dụng luôn hoạt động ngay cả khi Firebase gặp lỗi
  try {
    final appDocumentDir = await getApplicationDocumentsDirectory();
    await Hive.initFlutter(appDocumentDir.path);
    print('Hive đã được khởi tạo thành công');
  } catch (e) {
    print('Lỗi khi khởi tạo Hive: $e');
  }

  // Khởi tạo ngôn ngữ tiếng Việt cho định dạng ngày tháng
  await initializeDateFormatting('vi_VN', null);

  // Khởi tạo Firebase với error handling cải tiến
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    isFirebaseInitialized = true;
    print('Firebase đã được khởi tạo thành công');
    
    // Thêm đăng nhập ẩn danh tự động - chỉ thực hiện khi Firebase đã khởi tạo thành công
    try {
      // Kiểm tra xem người dùng đã đăng nhập chưa
      User? currentUser = FirebaseAuth.instance.currentUser;
      
      if (currentUser == null) {
        // Nếu chưa đăng nhập, thực hiện đăng nhập ẩn danh
        UserCredential userCredential = await FirebaseAuth.instance.signInAnonymously();
        print('Đăng nhập ẩn danh thành công: ${userCredential.user?.uid}');
      } else {
        print('Người dùng đã đăng nhập với ID: ${currentUser.uid}');
      }
    } catch (authError) {
      print('Lỗi đăng nhập ẩn danh: $authError');
      // Thử đăng nhập lại một lần nữa sau khi gặp lỗi
      try {
        await Future.delayed(Duration(seconds: 1));
        UserCredential userCredential = await FirebaseAuth.instance.signInAnonymously();
        print('Đăng nhập ẩn danh lần 2 thành công: ${userCredential.user?.uid}');
      } catch (retryError) {
        print('Lỗi đăng nhập ẩn danh lần 2: $retryError');
        // Đặt lại trạng thái firebase để ứng dụng biết rằng chúng ta không có firebase
        isFirebaseInitialized = false;
      }
    }
  } catch (e) {
    isFirebaseInitialized = false;
    print('Lỗi khi khởi tạo Firebase: $e');
    // Tiếp tục thực thi để app có thể khởi động mà không cần Firebase
  }

  // Khởi tạo các service
  await initializeServices();

  runApp(
    MultiProvider(
      providers: [
        // Đặt UserAuthProvider và firebase flag trước để UserDataProvider có thể truy cập
        ChangeNotifierProvider(create: (_) => UserAuthProvider()),
        Provider<bool>.value(value: isFirebaseInitialized),
        
        // Các provider khác
        ChangeNotifierProvider(create: (_) => ExerciseProvider()),
        ChangeNotifierProvider(create: (_) => WaterProvider()),
        ChangeNotifierProvider(create: (_) => FoodProvider()),
        
        // UserDataProvider cần truy cập đến isFirebaseInitialized
        ChangeNotifierProxyProvider<bool, UserDataProvider>(
          create: (_) => UserDataProvider(),
          update: (_, firebaseInitialized, previousProvider) {
            return previousProvider ?? UserDataProvider();
          },
        ),
        
        ChangeNotifierProvider(create: (_) => MealPlanProvider()),
        ChangeNotifierProvider(create: (_) => AuthService()),
      ],
      child: MyApp(),
    ),
  );
}

// Khởi tạo các service cần thiết
Future<void> initializeServices() async {
  try {
    // Khởi tạo Food Recognition Service
    final foodRecognitionService = FoodRecognitionService();
    await foodRecognitionService.initialize();

    // Khởi tạo Food Database Service
    final foodDatabaseService = FoodDatabaseService();
    await foodDatabaseService.initialize();
    
    print('Đã khởi tạo các service thành công');
  } catch (e) {
    print('Lỗi khi khởi tạo các service: $e');
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Lấy trạng thái khởi tạo Firebase
    final firebaseInitialized = Provider.of<bool>(context);
    
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
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Đang khởi động ứng dụng...'),
                    if (!firebaseInitialized)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'Đang chạy ở chế độ offline',
                          style: TextStyle(color: Colors.orange),
                        ),
                      ),
                  ],
                ),
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

// Thêm một ví dụ về cách điều hướng đến MealScreen với tham số mealId
// Đặt đoạn code này trong một hàm hoặc sự kiện nào đó trong ứng dụng của bạn

void navigateToMealDetail(BuildContext context, String mealId) {
  // Cách 1: Sử dụng named route với arguments
  Navigator.pushNamed(
    context,
    '/meal_detail',
    arguments: mealId,
  );
  
  // Cách 2: Sử dụng MaterialPageRoute trực tiếp
  // Navigator.push(
  //   context,
  //   MaterialPageRoute(
  //     builder: (context) => MealScreen(mealId: mealId),
  //   ),
  // );
}
