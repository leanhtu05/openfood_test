// Cấu hình toàn cục cho ứng dụng
// Tham số về API endpoints và các cấu hình chung

// API URL
// Khi phát triển trên máy cục bộ, bạn có thể sử dụng URL localhost
// const String apiBaseUrl = 'http://10.0.2.2:8000'; // Dùng khi chạy trên Emulator
// const String apiBaseUrl = 'http://localhost:8000'; // Dùng khi chạy trên máy thật thông qua USB
// const String apiBaseUrl = 'http://127.0.0.1:8000'; // Dùng khi chạy trên web

// API URL cho máy thật
// Thay đổi IP tại đây để kết nối với máy chủ cục bộ
// Cấu hình cho máy thật - sử dụng địa chỉ IP của máy tính trong mạng LAN
const String apiLocalUrl = 'https://backend-openfood.onrender.com';

// Các cấu hình thay thế nếu cần:
// - Cho emulator: 'http://10.0.2.2:8000' (đặc biệt cho Android Emulator khi kết nối đến localhost của máy host)
// - Cho máy thật qua USB: 'http://localhost:8000' (với port forwarding)
// - Cho web: 'http://127.0.0.1:8000'

// URL khi deploy trên hosting
const String apiProductionUrl = 'https://backend-openfood.onrender.com'; // Sử dụng cùng địa chỉ với apiLocalUrl

// URL mặc định để sử dụng
// Cho phép đè cấu hình trong runtime từ biến apiOverrideUrl
String apiOverrideUrl = apiLocalUrl; // Mặc định sử dụng URL local

// Sử dụng URL ghi đè nếu có, nếu không dùng URL production
String get apiBaseUrl => apiOverrideUrl.isNotEmpty ? apiOverrideUrl : apiLocalUrl;

// Các endpoints API
class ApiEndpoints {
  // API Status
  static const String apiStatus = '/api-status';
  static const String checkAI = '/check-ai-availability';
  
  // Meal Plan
  static const String mealPlan = '/api/meal-plan';
  static const String generateMealPlan = '/api/meal-plan/generate';
  static const String getMealPlan = '/api/meal-plan';  // + /{user_id}
  static const String replaceDay = '/api/replace-day';
  static const String replaceMeal = '/api/meal-plan/replace-meal';
  
  // Firestore Meal Plans
  static const String firestoreMealPlans = '/firestore/meal-plans';
  static const String firestoreUserMealPlans = '/firestore/users'; // + /{user_id}/meal-plans/date/{date}
  static const String firestoreMealPlansByUser = '/firestore/meal-plans/user'; // + /{user_id}
  static const String firestoreLatestMealPlan = '/firestore/latest-meal-plan'; // + /{user_id}
  
  // User Management
  static const String userProfile = '/api/user-profile';
  static const String getUserProfile = '/api/user-profile'; // + /{user_id}
  static const String createUpdateUserProfile = '/api/user-profile';
  
  // Firestore Users
  static const String firestoreUsers = '/firestore/users';
  static const String getUser = '/firestore/users'; // + /{user_id}
  static const String createUser = '/firestore/users'; // + /{user_id}
  static const String updateUser = '/firestore/users'; // + /{user_id}
  static const String deleteUser = '/firestore/users'; // + /{user_id}
  static const String convertAnonymous = '/firestore/users'; // + /{user_id}/convert-anonymous
  
  // Force mock data for testing
  static bool forceMockData = false;
  
  // Các endpoints chính theo backend thực tế
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String foodLog = '/api/food-log';
  static const String foodSearch = '/api/usda/search';
  static const String foodInfo = '/api/usda/food';
  static const String validateToken = '/validate-token';
  static const String currentUser = '/me';
  static const String syncData = '/api/sync';
}

// API timeouts (in seconds)
const int apiRequestTimeout = 30;
const int apiConnectionTimeout = 10;

// Các endpoint API chính
const String healthEndpoint = '/api-status'; // API endpoint để kiểm tra kết nối
const String generateMealEndpoint = '/api/meal-plan/generate'; // Endpoint tạo kế hoạch bữa ăn

// Feature flags
const bool useFirebaseByDefault = true;
const bool useMockDataWhenOffline = true;
const bool enableAIFeatures = true;
const bool useDirectFirestore = true; // Sử dụng Firestore trực tiếp thay vì thông qua API

// User preferences defaults
const double defaultCaloriesTarget = 2000.0;
const double defaultProteinTarget = 120.0;
const double defaultFatTarget = 65.0;
const double defaultCarbsTarget = 250.0; 