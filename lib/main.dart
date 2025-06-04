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
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:openfood/services/api_service.dart';
import 'screens/admin/firestore_admin_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

bool isFirebaseInitialized = false;
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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
    // Thêm timeout cho việc khởi tạo Firebase
    bool initializationComplete = false;
    
    // Tạo một Future với timeout
    await Future.any([
      Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).then((_) {
        isFirebaseInitialized = true;
        initializationComplete = true;
        print('Firebase đã được khởi tạo thành công');
      }),
      
      // Timeout sau 5 giây
      Future.delayed(Duration(seconds: 5)).then((_) {
        if (!initializationComplete) {
          print('⚠️ Timeout khi khởi tạo Firebase, tiếp tục với chế độ offline');
          isFirebaseInitialized = false;
          throw Exception('Firebase initialization timeout');
        }
      })
    ]);
    
    // Thêm đăng nhập ẩn danh tự động - chỉ thực hiện khi Firebase đã khởi tạo thành công
    if (isFirebaseInitialized) {
      try {
        // Kiểm tra xem người dùng đã đăng nhập chưa
        User? currentUser = FirebaseAuth.instance.currentUser;
        
        if (currentUser == null) {
          // Nếu chưa đăng nhập, thực hiện đăng nhập ẩn danh với timeout
          bool loginComplete = false;
          
          await Future.any([
            FirebaseAuth.instance.signInAnonymously().then((userCredential) {
              loginComplete = true;
              print('Đăng nhập ẩn danh thành công: ${userCredential.user?.uid}');
            }),
            
            // Timeout sau 3 giây
            Future.delayed(Duration(seconds: 3)).then((_) {
              if (!loginComplete) {
                print('⚠️ Timeout khi đăng nhập ẩn danh, tiếp tục với chế độ offline');
                throw Exception('Anonymous login timeout');
              }
            })
          ]);
        } else {
          print('Người dùng đã đăng nhập với ID: ${currentUser.uid}');
        }
      } catch (authError) {
        print('Lỗi đăng nhập ẩn danh: $authError');
        // Thử đăng nhập lại một lần nữa sau khi gặp lỗi
        try {
          await Future.delayed(Duration(seconds: 1));
          
          bool retryComplete = false;
          await Future.any([
            FirebaseAuth.instance.signInAnonymously().then((userCredential) {
              retryComplete = true;
              print('Đăng nhập ẩn danh lần 2 thành công: ${userCredential.user?.uid}');
            }),
            
            // Timeout sau 3 giây
            Future.delayed(Duration(seconds: 3)).then((_) {
              if (!retryComplete) {
                print('⚠️ Timeout khi đăng nhập ẩn danh lần 2, tiếp tục với chế độ offline');
                throw Exception('Anonymous login retry timeout');
              }
            })
          ]);
        } catch (retryError) {
          print('Lỗi đăng nhập ẩn danh lần 2: $retryError');
          // Đặt lại trạng thái firebase để ứng dụng biết rằng chúng ta không có firebase
          isFirebaseInitialized = false;
        }
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

  // Sau khi app khởi động, tự động đồng bộ dữ liệu
  // Cần delay để context và provider sẵn sàng
  Future.delayed(Duration(seconds: 2), () async {
    final context = navigatorKey.currentContext;
    if (context != null) {
      // Lấy UserDataProvider
      final userDataProvider = Provider.of<UserDataProvider>(context, listen: false);
      
      // Kiểm tra giá trị TDEE trước
      print('🔍 Kiểm tra TDEE: ${userDataProvider.tdeeCalories} kcal');
      
      // Kiểm tra giá trị TDEE và khắc phục nếu không hợp lệ
      bool needRecalculation = false;
      
      // Kiểm tra xem TDEE có bằng giá trị mặc định hoặc giá trị cố định không
      double tdeeCalories = userDataProvider.tdeeCalories;
      double nutritionGoalsCalories = userDataProvider.nutritionGoals['calories'] ?? 0.0;
      
      if (tdeeCalories <= 0 || 
          (tdeeCalories - 2000.0).abs() < 1.0 || 
          (tdeeCalories - 2468.0).abs() < 1.0 ||
          nutritionGoalsCalories <= 0 ||
          (nutritionGoalsCalories - 2000.0).abs() < 1.0 || 
          (nutritionGoalsCalories - 2468.0).abs() < 1.0) {
        
        print('⚠️ Phát hiện TDEE không hợp lệ ($tdeeCalories kcal), cố gắng khắc phục tự động...');
        needRecalculation = true;
      }
      
      if (needRecalculation) {
        try {
          // Bước 1: Đặt lại cờ đồng bộ
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('data_loaded_from_firestore');
          await prefs.setBool('data_loaded_from_firestore', false);
          await prefs.setBool('use_firebase_data', false);
          await prefs.setBool('data_changed', true);
          await prefs.setString('last_local_update', DateTime.now().toIso8601String());
          
          // Bước 2: Tính toán lại TDEE
          await userDataProvider.forceRecalculateTDEE();
          
          // Bước 3: Tải lại dữ liệu từ local
          await userDataProvider.loadUserData();
          
          // Bước 4: Lưu giá trị mới vào local storage
          await userDataProvider.saveUserData();
          
          print('✅ Đã tự động khắc phục TDEE. Giá trị mới: ${userDataProvider.tdeeCalories} kcal');
        } catch (e) {
          print('❌ Lỗi khi khắc phục TDEE: $e');
        }
      } else {
        print('✅ TDEE hợp lệ: $tdeeCalories kcal');
        
        // Cập nhật lại giá trị trong SharedPreferences để đảm bảo
        try {
          await userDataProvider.saveUserData();
        } catch (e) {
          print('❌ Lỗi khi lưu TDEE hợp lệ: $e');
        }
      }
      
      // Tự động tính toán TDEE nếu cần
      await userDataProvider.autoCalculateTDEE();
      
      // Đồng bộ dữ liệu với server
      syncAllDataToServer(context);
    }
  });
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
    
    // Cập nhật URL server cho API calls
    try {
      // Nếu bạn đang gặp vấn đề với kết nối, có thể thay đổi địa chỉ IP server ở đây
      // ApiService.baseUrl = 'http://192.168.1.5:8000';
      // ApiService.authBaseUrl = 'http://192.168.1.5:8000';
      print('Sử dụng địa chỉ server mặc định');
    } catch (e) {
      print('Lỗi khi cập nhật địa chỉ server: $e');
    }
    
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
      navigatorKey: navigatorKey,
      routes: routes,
      onGenerateRoute: generateRoute,
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
          print('🏠 Khởi tạo màn hình chính: ${hasCompletedOnboarding ? "HomeScreen" : "OnboardingScreen"}');
          return hasCompletedOnboarding ? HomeScreen() : const OnboardingScreen();
        },
      ),
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

Future<void> syncAllDataToServer(BuildContext context) async {
  final foodProvider = Provider.of<FoodProvider>(context, listen: false);
  final userDataProvider = Provider.of<UserDataProvider>(context, listen: false);
  final exerciseProvider = Provider.of<ExerciseProvider>(context, listen: false);
  final waterProvider = Provider.of<WaterProvider>(context, listen: false);

  final foodData = foodProvider.getAllEntriesAsJson();
  final userData = userDataProvider.toJson();
  final exerciseData = exerciseProvider.getAllExercisesAsJson();
  final waterData = waterProvider.getAllWaterLogsAsJson();

  final data = {
    'user': userData,
    'meals': foodData,
    'exercises': exerciseData,
    'water_logs': waterData,
  };

  try {
    // Lấy user ID từ Firebase nếu có
    String userId = "default";
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser != null) {
        userId = firebaseUser.uid;
      }
    } catch (e) {
      print('Không thể lấy Firebase user ID: $e');
    }
    
    // Sử dụng URL từ ApiService nếu có, ngược lại sử dụng URL mặc định
    final apiUrl = '${ApiService.baseUrl}/sync?user_id=$userId';
    
    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    ).timeout(
      Duration(seconds: 8), // Timeout sau 8 giây
      onTimeout: () {
        print('⏱️ Timeout khi đồng bộ dữ liệu');
        throw TimeoutException('Không thể kết nối đến server');
      },
    );
    
    if (response.statusCode == 200) {
      print('Đồng bộ dữ liệu local lên server thành công!');
      print('Response: ${response.body}');
    } else {
      print('Lỗi đồng bộ (${response.statusCode}): ${response.body}');
    }
  } catch (e) {
    print('Lỗi khi gửi dữ liệu lên server: $e');
  }
}
