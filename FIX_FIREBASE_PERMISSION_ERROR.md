# 🔧 Sửa lỗi Firebase Permission Denied

## ❌ Lỗi hiện tại:
```
Lỗi: Không thể tải kế hoạch ăn: [cloud_firestore/permission-denied] 
The caller does not have permission to execute the specified operation.
```

## 🔍 Nguyên nhân:
Firebase Security Rules đang chặn quyền truy cập vào Firestore, mặc dù user đã đăng nhập.

## ✅ Giải pháp:

### Bước 1: Cập nhật Firebase Security Rules

1. **Truy cập Firebase Console:**
   - Vào https://console.firebase.google.com
   - Chọn project `food-ai-96ef6`

2. **Vào Firestore Database:**
   - Sidebar → Firestore Database
   - Tab "Rules"

3. **Thay thế Rules hiện tại:**
   - Copy toàn bộ nội dung từ file `firestore_security_rules.rules`
   - Paste vào Firebase Console
   - Click "Publish"

### Bước 2: Rules chính cần có:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // USER DATA - Cho phép user truy cập dữ liệu của chính họ
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
      
      match /meal_plans/{planId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
    }
    
    // MEAL PLANS COLLECTION
    match /meal_plans/{planId} {
      allow read, write: if request.auth != null && 
        (resource == null || resource.data.user_id == request.auth.uid);
      allow create: if request.auth != null && 
        request.resource.data.user_id == request.auth.uid;
    }
    
    // LATEST MEAL PLANS
    match /latest_meal_plans/{userId} {
      allow read, write: if request.auth != null && 
        (resource == null || resource.data.user_id == request.auth.uid || request.auth.uid == userId);
    }
    
    // FOOD RECORDS
    match /food_records/{recordId} {
      allow read, write: if request.auth != null && 
        (resource == null || resource.data.user_id == request.auth.uid);
    }
    
    // VIETNAMESE FOOD PRICES - Public read/write for authenticated users
    match /vietnamese_food_prices/{priceId} {
      allow read, write: if request.auth != null;
    }
    
    // TEMPORARY FALLBACK (Remove in production)
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

### Bước 3: Kiểm tra Authentication

1. **Kiểm tra user đã đăng nhập:**
   ```dart
   // Trong Flutter app
   final user = FirebaseAuth.instance.currentUser;
   print('Current user: ${user?.uid}');
   print('Is authenticated: ${user != null}');
   ```

2. **Kiểm tra ID Token:**
   ```dart
   if (user != null) {
     final idToken = await user.getIdToken();
     print('ID Token exists: ${idToken.isNotEmpty}');
   }
   ```

### Bước 4: Test Rules

1. **Trong Firebase Console:**
   - Firestore Database → Rules
   - Click "Rules playground"
   - Test với user ID thực tế

2. **Trong Flutter app:**
   ```dart
   // Test đọc dữ liệu
   try {
     final doc = await FirebaseFirestore.instance
         .collection('users')
         .doc(user.uid)
         .get();
     print('✅ Có thể đọc dữ liệu user');
   } catch (e) {
     print('❌ Lỗi đọc dữ liệu: $e');
   }
   ```

### Bước 5: Debug Authentication

1. **Kiểm tra Firebase Auth state:**
   ```dart
   FirebaseAuth.instance.authStateChanges().listen((User? user) {
     if (user == null) {
       print('❌ User chưa đăng nhập');
     } else {
       print('✅ User đã đăng nhập: ${user.uid}');
       print('Email: ${user.email}');
       print('Anonymous: ${user.isAnonymous}');
     }
   });
   ```

2. **Force refresh token:**
   ```dart
   final user = FirebaseAuth.instance.currentUser;
   if (user != null) {
     await user.getIdToken(true); // Force refresh
     print('✅ Token đã được refresh');
   }
   ```

## 🚨 Lưu ý quan trọng:

### 1. Rules tạm thời (Development):
```javascript
// TEMPORARY - Cho phép tất cả khi đã đăng nhập
match /{document=**} {
  allow read, write: if request.auth != null;
}
```

### 2. Rules production (Secure):
```javascript
// PRODUCTION - Chỉ cho phép truy cập dữ liệu của chính user
match /users/{userId} {
  allow read, write: if request.auth != null && request.auth.uid == userId;
}
```

### 3. Kiểm tra user_id trong documents:
```javascript
// Đảm bảo user chỉ truy cập dữ liệu của mình
allow read, write: if request.auth != null && 
  resource.data.user_id == request.auth.uid;
```

## 🔄 Quy trình sửa lỗi:

1. ✅ **Cập nhật Firebase Rules** (quan trọng nhất)
2. ✅ **Kiểm tra user đã đăng nhập**
3. ✅ **Test rules trong Console**
4. ✅ **Restart Flutter app**
5. ✅ **Kiểm tra logs**

## 📱 Test trong app:

Sau khi cập nhật rules, test các chức năng:

1. **Đăng nhập/đăng ký**
2. **Tạo meal plan mới**
3. **Đọc meal plan hiện tại**
4. **Cập nhật dữ liệu user**
5. **Truy cập Vietnamese food prices**

## 🎯 Kết quả mong đợi:

- ✅ Không còn lỗi permission denied
- ✅ App có thể đọc/ghi dữ liệu Firestore
- ✅ User có thể tạo và xem meal plans
- ✅ Dữ liệu được bảo mật (chỉ user sở hữu mới truy cập được)

## 🆘 Nếu vẫn lỗi:

1. **Kiểm tra Firebase project ID** trong `firebase_options.dart`
2. **Đảm bảo user thực sự đã đăng nhập**
3. **Xóa cache app và restart**
4. **Kiểm tra network connection**
5. **Xem Firebase Console logs**

---

**Lưu ý:** Rules hiện tại có fallback rule cho phép tất cả user đã đăng nhập truy cập mọi dữ liệu. Trong production, nên xóa rule này và chỉ giữ lại các rules cụ thể cho từng collection.
