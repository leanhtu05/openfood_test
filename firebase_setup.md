# Hướng dẫn thiết lập Firebase Cloud Firestore

Tài liệu này hướng dẫn cách thiết lập và cấu hình Firebase Cloud Firestore cho ứng dụng Flutter OpenFood.

## 1. Tạo project Firebase

1. Truy cập [Firebase Console](https://console.firebase.google.com/)
2. Nhấp vào "Add project" (Thêm dự án)
3. Nhập tên dự án (ví dụ: "OpenFood")
4. Tùy chọn: Bật Google Analytics
5. Nhấp vào "Create project" (Tạo dự án)

## 2. Cấu hình Firebase cho ứng dụng Android

1. Trong Firebase Console, nhấp vào biểu tượng Android để thêm ứng dụng Android
2. Nhập package name của ứng dụng (thường là `com.example.openfood_test`)
3. Nhấp vào "Register app" (Đăng ký ứng dụng)
4. Tải tệp `google-services.json` và đặt vào thư mục `android/app` của dự án Flutter
5. Làm theo các bước còn lại trong hướng dẫn để cài đặt Firebase SDK

## 3. Cấu hình Firebase cho ứng dụng iOS (nếu cần)

1. Trong Firebase Console, nhấp vào biểu tượng iOS để thêm ứng dụng iOS
2. Nhập bundle ID của ứng dụng
3. Tải tệp `GoogleService-Info.plist` và đặt vào thư mục iOS của dự án Flutter
4. Làm theo các bước còn lại trong hướng dẫn để cài đặt Firebase SDK

## 4. Bật Firestore

1. Trong Firebase Console, vào phần "Firestore Database"
2. Nhấp vào "Create database" (Tạo cơ sở dữ liệu)
3. Chọn chế độ bảo mật: "Start in test mode" (bắt đầu ở chế độ thử nghiệm)
4. Chọn vị trí máy chủ gần nhất với người dùng
5. Nhấp vào "Enable" (Bật)

## 5. Bật Authentication

1. Trong Firebase Console, vào phần "Authentication"
2. Trong tab "Sign-in method", bật các phương thức xác thực muốn sử dụng (Email/Password, Google, Phone, v.v.)

## 6. Thiết lập Firestore Rules

1. Trong Firebase Console, vào phần "Firestore Database"
2. Chọn tab "Rules"
3. Cập nhật rules để đảm bảo bảo mật:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Chỉ cho phép người dùng đọc/ghi dữ liệu của chính họ
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Cho phép đọc/ghi kế hoạch ăn của người dùng
    match /meal_plans/{planId} {
      allow read, write: if request.auth != null && resource.data.user_id == request.auth.uid;
    }
  }
}
```

## 7. Cấu trúc dữ liệu

Firestore sẽ có các collections chính sau:

### Collection `users`
- Document ID: `{userId}` (Firebase Auth UID)
- Fields:
  - `profile`: Map (thông tin cá nhân)
  - `current_meal_plan_id`: String (ID của kế hoạch ăn hiện tại)
  - `updated_at`: Timestamp

### Collection `meal_plans`
- Document ID: auto-generated
- Fields:
  - `user_id`: String (Firebase Auth UID)
  - `created_at`: Timestamp
  - `updated_at`: Timestamp
  - `weekly_plan`: Map (kế hoạch ăn theo tuần)

## 8. Cấu hình Flutter

Đảm bảo `pubspec.yaml` của bạn đã có các dependencies Firebase:

```yaml
dependencies:
  firebase_core: ^2.15.0
  firebase_auth: ^4.7.2
  cloud_firestore: ^4.8.4
```

## 9. Khởi tạo Firebase trong ứng dụng

Đảm bảo đã khởi tạo Firebase trong `main.dart`:

```dart
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}
```

## 10. Kiểm tra kết nối

Để kiểm tra kết nối Firebase đã được thiết lập đúng:

1. Chạy ứng dụng Flutter
2. Sử dụng tính năng đăng nhập
3. Kiểm tra Firebase Console để xác nhận người dùng mới đã được tạo
4. Kiểm tra Firestore để xác nhận dữ liệu đã được lưu 