# Debug Authentication Issues

## Vấn đề hiện tại
Lỗi "An internal error has occurred. Visibility check was unavailable" khi đăng nhập bằng:
- Điện thoại
- Gmail 
- Google

## Các bước kiểm tra và sửa lỗi

### 1. Kiểm tra SHA-1 Fingerprint

**Vấn đề phát hiện:**
- Trong `google-services.json`: SHA-1 = `14d93bd3c31b7a429de9ca7ccf39da18dc487239`
- Trong Firebase Console: SHA-1 = `14:d9:3b:d3:c3:1b:7a:42:9d:e9:ca:7c:cf:39:da:18:dc:48:72:39`

**Giải pháp:**
1. Lấy SHA-1 fingerprint hiện tại:
```bash
cd android
./gradlew signingReport
```

2. Cập nhật SHA-1 trong Firebase Console:
   - Vào Firebase Console > Project Settings > General
   - Chọn app Android
   - Thêm SHA-1 fingerprint mới
   - Tải lại `google-services.json`

### 2. Cấu hình Google Sign-In

**Cần kiểm tra:**
1. Google Cloud Console > APIs & Services > Credentials
2. Tạo OAuth 2.0 Client ID cho Android:
   - Package name: `com.example.openfood_test`
   - SHA-1 fingerprint: (từ bước 1)

### 3. Cấu hình Firebase Authentication

**Cần bật các phương thức:**
1. Firebase Console > Authentication > Sign-in method
2. Bật:
   - Email/Password
   - Phone
   - Google

### 4. Kiểm tra cấu hình Android

**AndroidManifest.xml** - ✅ Đã cập nhật:
- Thêm permissions
- Thêm Google Play Services metadata
- Thêm Firebase messaging service

**build.gradle** - ✅ Đã cập nhật:
- Thêm dependencies
- Bật multidex

### 5. Debug Commands

**Lấy SHA-1:**
```bash
cd android
./gradlew signingReport
```

**Kiểm tra Google Services:**
```bash
flutter doctor
flutter clean
flutter pub get
cd android && ./gradlew clean
```

**Build và test:**
```bash
flutter run --debug
```

### 6. Các lỗi thường gặp và giải pháp

**"Visibility check was unavailable":**
- SHA-1 fingerprint không khớp
- Thiếu OAuth Client ID
- Google Play Services không được cấu hình đúng

**"PlatformException":**
- Cấu hình Google Sign-In không đúng
- Thiếu client ID

**"Network error":**
- Kiểm tra kết nối internet
- Kiểm tra Firebase project settings

### 7. Checklist hoàn chỉnh

- [ ] SHA-1 fingerprint khớp giữa debug keystore và Firebase
- [ ] OAuth Client ID được tạo trong Google Cloud Console
- [ ] Google Sign-In được bật trong Firebase Authentication
- [ ] Phone Authentication được bật trong Firebase Authentication
- [ ] `google-services.json` được cập nhật mới nhất
- [ ] Dependencies trong `build.gradle` đầy đủ
- [ ] Permissions trong `AndroidManifest.xml` đầy đủ
- [ ] Google Play Services metadata được thêm

### 8. Lệnh khắc phục nhanh

```bash
# 1. Clean project
flutter clean
cd android && ./gradlew clean && cd ..

# 2. Get dependencies
flutter pub get

# 3. Lấy SHA-1
cd android && ./gradlew signingReport

# 4. Build lại
flutter run --debug
```
