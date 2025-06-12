# 🛒 Danh sách mua sắm (Grocery List)

## Tổng quan
Màn hình **Danh sách mua sắm** tự động tạo ra danh sách các nguyên liệu cần mua dựa trên kế hoạch bữa ăn hàng tuần của người dùng. Giao diện hiện đại với Material Design 3, phân nhóm thông minh và nhiều tính năng tiện ích.

## ✨ Tính năng chính

### 🎯 Tự động tạo danh sách
- Tự động tổng hợp nguyên liệu từ tất cả món ăn trong tuần
- Gộp các nguyên liệu trùng lặp và tính tổng số lượng
- Phân loại nguyên liệu theo khu vực mua sắm

### 🏷️ Phân nhóm thông minh
- **🥩 Thịt tươi sống**: Thịt bò, gà, heo, cá, tôm
- **🥬 Rau củ quả**: Rau xanh, củ quả, gia đỗ
- **🌾 Thực phẩm khô**: Gạo, bún, mì, bánh
- **🧂 Gia vị & Nước chấm**: Muối, đường, nước mắm, tương
- **🥛 Sản phẩm từ sữa**: Sữa, trứng, bơ, phô mai
- **🥤 Đồ uống**: Nước, trà, cà phê
- **📦 Khác**: Các nguyên liệu khác

### 📊 Theo dõi tiến độ
- Thanh tiến độ hiển thị % hoàn thành
- Đếm số lượng nguyên liệu đã mua/tổng số
- Giao diện gradient đẹp mắt

### 🔍 Tìm kiếm & Lọc
- Thanh tìm kiếm thông minh
- Lọc nguyên liệu theo tên
- Hiển thị kết quả tìm kiếm real-time

### ✅ Quản lý trạng thái
- Checkbox để đánh dấu nguyên liệu đã mua
- Hiệu ứng gạch ngang khi hoàn thành
- Animation mượt mà khi thay đổi trạng thái

### 🎨 Giao diện hiện đại
- Material Design 3
- Thẻ nguyên liệu bo tròn với bóng đổ
- Màu sắc nhất quán với theme ứng dụng
- Haptic feedback khi tương tác

## 🚀 Cách sử dụng

### Truy cập danh sách mua sắm
1. Vào màn hình **Kế hoạch bữa ăn**
2. Nhấn icon 🛒 trên thanh AppBar
3. Hoặc điều hướng trực tiếp: `Navigator.pushNamed(context, '/grocery-list')`

### Sử dụng các tính năng
- **Tìm kiếm**: Nhập tên nguyên liệu vào thanh tìm kiếm
- **Đánh dấu hoàn thành**: Nhấn checkbox bên cạnh nguyên liệu
- **Hoàn thành tất cả**: Nhấn nút floating action button
- **Chia sẻ danh sách**: Nhấn icon chia sẻ trên AppBar
- **Làm mới**: Nhấn icon refresh để tạo lại danh sách

## 🛠️ Cài đặt & Cấu hình

### Dependencies cần thiết
```yaml
dependencies:
  grouped_list: ^5.1.2  # Đã có trong pubspec.yaml
  provider: ^6.0.5      # Đã có
  flutter/material.dart # Built-in
  flutter/services.dart # Built-in
```

### Import cần thiết
```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/meal_plan.dart';
import '../providers/meal_plan_provider.dart';
import 'package:grouped_list/grouped_list.dart';
import 'package:flutter/services.dart';
```

## 📱 Demo & Test

### Chạy demo độc lập
```bash
# Chạy demo với dữ liệu mẫu
flutter run lib/demo/grocery_list_demo.dart
```

### Dữ liệu demo bao gồm
- **Phở bò**: Bánh phở, thịt bò, hành lá, ngò gai
- **Bún chả**: Bún, thịt heo, rau sống, nước mắm
- **Cơm chiên gà**: Gạo, thịt gà, trứng, cà rốt
- **Bánh mì thịt**: Bánh mì, thịt nguội, rau cải

## 🔧 Tùy chỉnh

### Thêm danh mục mới
Chỉnh sửa method `_categorizeIngredient()` trong `grocery_list_screen.dart`:

```dart
String _categorizeIngredient(String ingredient) {
  final ingredientLower = ingredient.toLowerCase();
  
  // Thêm danh mục mới
  if (ingredientLower.contains('hải sản')) {
    return '🦐 Hải sản';
  }
  
  // ... các danh mục khác
}
```

### Tùy chỉnh giao diện
- Thay đổi màu sắc trong `Colors.green.shade600`
- Điều chỉnh border radius trong `BorderRadius.circular(12)`
- Tùy chỉnh shadow trong `BoxShadow`

## 🐛 Xử lý lỗi

### Không có dữ liệu
- Hiển thị màn hình empty state với hướng dẫn
- Nút "Tạo kế hoạch bữa ăn" để điều hướng

### Lỗi dữ liệu
- Fallback về `ingredients` cũ nếu `detailedIngredients` trống
- Xử lý null safety cho tất cả fields

## 📋 Cấu trúc dữ liệu

### GroceryItem
```dart
class GroceryItem {
  final String name;      // Tên nguyên liệu
  final String amount;    // Số lượng
  final String unit;      // Đơn vị (g, ml, quả, ...)
  final String category;  // Danh mục (🥩 Thịt tươi sống, ...)
}
```

### Luồng dữ liệu
1. `MealPlanProvider` → `MealPlan`
2. `MealPlan` → `DayPlan` → `Meal` → `Dish`
3. `Dish.detailedIngredients` → `GroceryItem`
4. Tổng hợp và phân nhóm → Hiển thị UI

## 🎯 Roadmap

### Tính năng sắp tới
- [ ] Lưu trạng thái checkbox vào local storage
- [ ] Thêm ghi chú cho từng nguyên liệu
- [ ] Ước tính giá tiền
- [ ] Tích hợp với ứng dụng mua sắm online
- [ ] Xuất PDF danh sách mua sắm
- [ ] Chia sẻ qua social media

### Cải thiện UX
- [ ] Pull-to-refresh
- [ ] Swipe-to-delete
- [ ] Drag-and-drop sắp xếp
- [ ] Dark mode support
- [ ] Accessibility improvements

---

**Được phát triển với ❤️ cho ứng dụng OpenFood**
