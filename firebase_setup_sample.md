# Mẫu Cấu Trúc Firestore cho Ứng Dụng DietAI

Dưới đây là cấu trúc dữ liệu mẫu cho Firestore phù hợp với ứng dụng DietAI của bạn.

## Collections

### 1. users
Lưu trữ thông tin người dùng.

```
users/{userId}
```

**Document Example:**
```json
{
  "uid": "user123",
  "email": "user@example.com",
  "displayName": "Nguyễn Văn A",
  "createdAt": "2023-06-15T08:30:00Z",
  "gender": "nam",
  "dateOfBirth": "1990-01-15",
  "height": 175,
  "weight": 68,
  "activityLevel": "moderate",
  "goal": "weight_loss",
  "weightGainPace": null,
  "tdee": 2200,
  "targetCalories": 1800,
  "targetProtein": 135,
  "targetFat": 60,
  "targetCarbs": 180
}
```

### 2. food_items
Danh sách các loại thực phẩm có sẵn trong hệ thống.

```
food_items/{foodId}
```

**Document Example:**
```json
{
  "id": "food123",
  "name": "Cơm trắng",
  "brand": null,
  "imageUrl": "https://storage.googleapis.com/food-ai-96ef6.appspot.com/foods/rice.jpg",
  "calories": 130,
  "protein": 2.7,
  "fat": 0.3,
  "carbs": 28.2,
  "fiber": 0.4,
  "sugar": 0.1,
  "sodium": 1,
  "servingSize": 100,
  "servingUnit": "g",
  "additionalNutrients": {
    "potassium": 35,
    "cholesterol": 0
  },
  "tags": ["carbs", "vietnamese", "staple"]
}
```

### 3. food_entries
Các bản ghi thực phẩm của người dùng.

```
users/{userId}/food_entries/{entryId}
```

**Document Example:**
```json
{
  "id": "entry123",
  "description": "Bữa trưa tại văn phòng",
  "imagePath": "https://storage.googleapis.com/food-ai-96ef6.appspot.com/users/user123/entries/entry123.jpg",
  "audioPath": null,
  "dateTime": "2023-09-10T12:30:00Z",
  "isFavorite": false,
  "barcode": null,
  "calories": 650,
  "mealType": "lunch",
  "nutritionInfo": {
    "calories": 650,
    "protein": 25,
    "fat": 20,
    "carbs": 85,
    "fiber": 5,
    "sugar": 8,
    "sodium": 380,
    "totalWeight": 350
  },
  "items": [
    {
      "id": "food123",
      "name": "Cơm trắng",
      "calories": 130,
      "protein": 2.7,
      "fat": 0.3,
      "carbs": 28.2,
      "servingSize": 2
    },
    {
      "id": "food456",
      "name": "Thịt gà luộc",
      "calories": 165,
      "protein": 31,
      "fat": 3.6,
      "carbs": 0,
      "servingSize": 1
    }
  ]
}
```

### 4. exercise_entries
Các bản ghi hoạt động thể dục của người dùng.

```
users/{userId}/exercise_entries/{entryId}
```

**Document Example:**
```json
{
  "id": "exercise123",
  "name": "Chạy bộ",
  "icon": "running",
  "minutes": 30,
  "intensity": "Vừa phải",
  "calories": 300,
  "caloriesPerMinute": 10.0,
  "date": "2023-09-10",
  "createdAt": "2023-09-10T17:30:00Z"
}
```

### 5. water_entries
Các bản ghi uống nước của người dùng.

```
users/{userId}/water_entries/{entryId}
```

**Document Example:**
```json
{
  "id": "water123",
  "amount": 250,
  "unit": "ml",
  "dateTime": "2023-09-10T09:15:00Z"
}
```

### 6. meal_plans
Kế hoạch ăn uống của người dùng.

```
users/{userId}/meal_plans/{planId}
```

**Document Example:**
```json
{
  "id": "plan123",
  "userId": "user123",
  "createdAt": "2023-09-01T10:00:00Z",
  "nutrition_targets": {
    "calories_target": 1800,
    "protein_target": 135,
    "fat_target": 60,
    "carbs_target": 180
  },
  "days": [
    {
      "day_of_week": "Thứ 2",
      "breakfast": {
        "dishes": [
          {
            "name": "Bánh mì trứng",
            "description": "Bánh mì với trứng ốp la",
            "nutrition": {
              "calories": 350,
              "protein": 15,
              "fat": 12,
              "carbs": 45
            },
            "ingredients": ["bánh mì", "trứng", "hành lá", "nước mắm"]
          }
        ],
        "nutrition": {
          "calories": 350,
          "protein": 15,
          "fat": 12,
          "carbs": 45
        }
      },
      "lunch": {
        "dishes": [
          {
            "name": "Cơm gà",
            "description": "Cơm với thịt gà luộc và rau xào",
            "nutrition": {
              "calories": 550,
              "protein": 35,
              "fat": 15,
              "carbs": 65
            },
            "ingredients": ["cơm", "thịt gà", "rau cải", "dầu ăn"]
          }
        ],
        "nutrition": {
          "calories": 550,
          "protein": 35,
          "fat": 15,
          "carbs": 65
        }
      },
      "dinner": {
        "dishes": [
          {
            "name": "Phở bò",
            "description": "Phở với thịt bò và các gia vị",
            "nutrition": {
              "calories": 480,
              "protein": 25,
              "fat": 10,
              "carbs": 70
            },
            "ingredients": ["bánh phở", "thịt bò", "hành", "gừng", "gia vị"]
          }
        ],
        "nutrition": {
          "calories": 480,
          "protein": 25,
          "fat": 10,
          "carbs": 70
        }
      }
    }
  ]
}
```

## Subcollections

### 1. Progress Tracking (subcollection của users)

```
users/{userId}/progress/{progressId}
```

**Document Example:**
```json
{
  "id": "progress123",
  "date": "2023-09-10",
  "weight": 67.5,
  "bmi": 22.1,
  "waistCircumference": 80,
  "notes": "Cảm thấy khá hơn sau 1 tháng theo dõi chế độ ăn"
}
```

### 2. Favorites (subcollection của users)

```
users/{userId}/favorites/{favoriteId}
```

**Document Example - Favorite Food:**
```json
{
  "id": "fav123", 
  "type": "food",
  "itemId": "food123",
  "name": "Cơm trắng",
  "addedAt": "2023-08-15T14:20:00Z"
}
```

## Tạo dữ liệu mẫu trên Firebase Console

1. Đăng nhập vào [Firebase Console](https://console.firebase.google.com/)
2. Chọn dự án "food-ai-96ef6" của bạn
3. Từ menu trái, chọn "Firestore Database"
4. Nhấp vào "Tạo collection" để tạo các collections theo cấu trúc trên
5. Thêm documents mẫu theo ví dụ trên để kiểm tra tích hợp với ứng dụng

## Luật bảo mật Firestore

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Cho phép đọc và ghi dữ liệu khi người dùng đã đăng nhập
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
      
      // Subcollections của user
      match /food_entries/{entryId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
      
      match /exercise_entries/{entryId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
      
      match /water_entries/{entryId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
      
      match /meal_plans/{planId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
      
      match /progress/{progressId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
      
      match /favorites/{favoriteId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
    }
    
    // Cho phép đọc dữ liệu thực phẩm công khai
    match /food_items/{foodId} {
      allow read: if true;
      allow write: if request.auth != null && request.auth.token.admin == true;
    }
  }
}
```

## Tích hợp với Flutter

Cấu trúc này phù hợp với các models đã có trong ứng dụng Flutter của bạn. Khi kết nối với Firestore, bạn có thể sử dụng các models hiện có để chuyển đổi dữ liệu giữa ứng dụng và Firestore. 