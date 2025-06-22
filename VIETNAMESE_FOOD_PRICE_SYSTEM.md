# Hệ thống Quản lý Giá cả Thực phẩm Việt Nam

## Tổng quan

Hệ thống quản lý giá cả thực phẩm Việt Nam được tích hợp vào ứng dụng OpenFood để cung cấp thông tin giá cả thời gian thực và phân tích chi phí grocery thông minh.

## Tính năng chính

### 1. Cơ sở dữ liệu giá cả thực phẩm
- **150+ mặt hàng thực phẩm Việt Nam** được phân loại theo 10 danh mục chính
- **Giá cả cập nhật thời gian thực** lưu trữ trên Firebase
- **Hỗ trợ nhiều đơn vị đo lường**: kg, lít, quả, ổ
- **Phân loại chi tiết**: Thịt tươi sống, Hải sản, Rau củ quả, Trái cây, v.v.

### 2. Phân tích chi phí Grocery thông minh
- **Tính toán tự động** chi phí ước tính cho danh sách mua sắm
- **Phân tích theo danh mục** với biểu đồ và thống kê
- **So sánh ngân sách** và cảnh báo vượt chi
- **Mẹo tiết kiệm** được tạo tự động dựa trên dữ liệu

### 3. Cảnh báo giá cả thông minh
- **Phát hiện giá bất thường** so với mức trung bình thị trường
- **Thông báo cơ hội mua sắm** khi giá thấp
- **Cảnh báo giá cao** để tránh mua đắt

### 4. Export/Import dữ liệu
- **Export ra nhiều format**: JSON, CSV, Excel
- **Template import** để thêm dữ liệu mới
- **Báo cáo chi tiết** với thống kê và phân tích
- **Chia sẻ dễ dàng** qua email, cloud storage

### 5. Đóng góp từ cộng đồng
- **Người dùng đóng góp giá**: Chia sẻ giá cả thực tế từ thị trường
- **Hệ thống vote**: Cộng đồng vote cho độ chính xác của giá
- **Xét duyệt tự động**: Giá có vote cao được cập nhật tự động
- **Báo cáo giá sai**: Người dùng có thể báo cáo giá không chính xác

### 6. Quản lý chất lượng dữ liệu
- **Lịch sử thay đổi giá**: Theo dõi mọi thay đổi giá cả
- **Xác minh bằng ảnh**: Người dùng có thể đính kèm ảnh chứng minh
- **Hệ thống reputation**: Người dùng có uy tín cao được ưu tiên
- **Kiểm duyệt nội dung**: Lọc bỏ thông tin spam hoặc sai lệch

## Cấu trúc dữ liệu

### Model chính

#### VietnameseFoodPrices
```dart
static final Map<String, Map<String, dynamic>> foodPrices = {
  'thịt bò': {
    'price_per_kg': 350000,
    'unit': 'kg',
    'category': '🥩 Thịt tươi sống'
  },
  // ... 150+ mặt hàng khác
};
```

#### GroceryItemWithCost
```dart
class GroceryItemWithCost {
  final String name;
  final String amount;
  final String unit;
  final String category;
  final double estimatedCost;
  final double pricePerUnit;
  final bool isChecked;
}
```

#### GroceryCostAnalysis
```dart
class GroceryCostAnalysis {
  final double totalCost;
  final double averageCostPerItem;
  final Map<String, CategoryCostBreakdown> categoryBreakdown;
  final List<CostSavingTip> savingTips;
  final BudgetComparison budgetComparison;
  final List<PriceAlert> priceAlerts;
  final DateTime analysisDate;
}
```

## Services

### VietnameseFoodPriceService
- Quản lý dữ liệu giá cả trên Firebase
- CRUD operations cho thực phẩm
- Tìm kiếm và lọc theo danh mục
- Thống kê và báo cáo

### GroceryCostCalculator
- Tính toán chi phí grocery
- Phân tích theo danh mục
- Tạo mẹo tiết kiệm
- Cảnh báo giá cả

### FoodPriceExporter
- Export dữ liệu ra JSON/CSV
- Import từ template CSV
- Tạo báo cáo chi tiết
- Quản lý lịch sử export

## Screens

### 1. FoodPriceManagementScreen
- Xem danh sách tất cả thực phẩm
- Tìm kiếm và lọc theo danh mục
- Xem chi tiết giá cả và lịch sử
- Đóng góp giá mới và báo cáo giá sai
- Khởi tạo dữ liệu Firebase

### 2. GroceryCostDemoScreen
- Demo phân tích chi phí grocery
- Hiển thị breakdown theo danh mục
- So sánh ngân sách
- Mẹo tiết kiệm và cảnh báo

### 3. FoodPriceExportScreen
- Export dữ liệu ra nhiều format
- Download template import
- Quản lý lịch sử export
- Chia sẻ file

### 4. PriceContributionScreen
- Form đóng góp giá cả mới
- Upload ảnh chứng minh
- Chọn địa điểm và cửa hàng
- Validation và submit

### 5. CommunityContributionsScreen
- Xem đóng góp từ cộng đồng
- Vote cho độ chính xác
- Quản lý đóng góp của bản thân
- Tab phân loại theo trạng thái

### 6. PriceReportScreen
- Báo cáo giá cả sai lệch
- Đề xuất giá chính xác
- Chọn lý do báo cáo
- Gửi feedback cho admin

### 7. AIPriceInsightsScreen
- Dashboard AI insights với 3 tabs
- Phân tích xu hướng giá cả
- Phân tích mùa vụ và thời điểm mua
- Market insights và trending foods
- Recommendations thông minh

### 8. AIPricePredictionScreen
- Dự đoán giá cả tương lai
- Chọn thực phẩm và thời gian dự đoán
- Hiển thị confidence level
- Phân tích yếu tố ảnh hưởng
- Khuyến nghị mua/bán

### 9. AIGroceryOptimizerScreen
- Tối ưu hóa danh sách grocery
- AI suggestions cho thay thế
- Tối ưu chi phí và dinh dưỡng
- Timing advice cho mua sắm
- Sustainability tips

## Cách sử dụng

### 1. Khởi tạo dữ liệu Firebase

```dart
final priceService = VietnameseFoodPriceService();
await priceService.initializePriceData();
```

### 2. Tính toán chi phí grocery

```dart
final calculator = GroceryCostCalculator();
final analysis = await calculator.calculateCostAnalysis(
  groceryItems: groceryList,
  budgetLimit: 500000,
);
```

### 3. Export dữ liệu

```dart
final exporter = FoodPriceExporter();
final filePath = await exporter.exportToJson();
await exporter.shareFile(filePath);
```

### 4. Thêm vào navigation

```dart
// Trong app_routes.dart
static const String foodPriceManagement = '/food-price-management';

static Map<String, WidgetBuilder> routes = {
  foodPriceManagement: (context) => const FoodPriceManagementScreen(),
};
```

### 5. Sử dụng widget menu

```dart
// Trong home screen hoặc drawer
FoodPriceMenuWidget(),

// Hoặc compact version
FoodPriceMenuCompact(),

// Hoặc floating menu
FoodPriceFloatingMenu(),
```

## Danh mục thực phẩm

1. **🥩 Thịt tươi sống** - Thịt bò, heo, gà, vịt, cừu, dê
2. **🐟 Hải sản** - Cá, tôm, mực, nghêu, sò, hàu
3. **🥬 Rau củ quả** - Rau xanh, củ quả, gia vị tươi
4. **🍎 Trái cây** - Trái cây trong nước và nhập khẩu
5. **🌾 Ngũ cốc & Gạo** - Gạo, bột, ngũ cốc
6. **🥜 Đậu & Hạt** - Các loại đậu và hạt dinh dưỡng
7. **🥛 Sữa & Trứng** - Sản phẩm từ sữa và trứng
8. **🧂 Gia vị** - Gia vị, nước chấm, dầu ăn
9. **🥤 Đồ uống** - Nước, trà, cà phê, đồ uống
10. **🍪 Bánh kẹo** - Bánh, kẹo, snack
11. **🍖 Thực phẩm chế biến** - Thực phẩm đã chế biến sẵn

## Lợi ích

### Cho người dùng
- **Tiết kiệm thời gian** lập kế hoạch mua sắm
- **Kiểm soát chi phí** hiệu quả
- **Mua sắm thông minh** với cảnh báo giá
- **So sánh giá** dễ dàng

### Cho ứng dụng
- **Tăng giá trị** cho người dùng
- **Dữ liệu thời gian thực** từ Firebase
- **Tích hợp mượt mà** với hệ thống hiện tại
- **Mở rộng dễ dàng** cho các tính năng mới

## Yêu cầu kỹ thuật

### Dependencies
```yaml
dependencies:
  cloud_firestore: ^4.13.6
  path_provider: ^2.1.1
  share_plus: ^7.2.1
```

### Firebase Setup
- Firestore Database với collection `vietnamese_food_prices`
- Security rules cho phép read/write
- Indexes cho tìm kiếm và lọc

### Permissions
- Storage permission để lưu file export
- Network permission cho Firebase

## Roadmap

### Phase 1 (Hiện tại)
- ✅ Cơ sở dữ liệu giá cả cơ bản
- ✅ Phân tích chi phí grocery
- ✅ Export/Import dữ liệu
- ✅ UI/UX cơ bản

### Phase 2 (Hiện tại - AI Features)
- ✅ AI Price Insights - Phân tích xu hướng thông minh
- ✅ AI Price Prediction - Dự đoán giá cả tương lai
- ✅ AI Grocery Optimizer - Tối ưu hóa danh sách mua sắm
- ✅ Seasonal Analysis - Phân tích mùa vụ
- ✅ Market Insights - Insights thị trường thông minh

### Phase 3 (Tương lai)
- 🔄 Cập nhật giá tự động từ API
- 🔄 Machine Learning nâng cao
- 🔄 Tích hợp với meal planning
- 🔄 Social features (chia sẻ giá)

### Phase 3 (Mở rộng)
- 🔄 Multi-region pricing
- 🔄 Vendor comparison
- 🔄 Price history tracking
- 🔄 Advanced analytics

## Hỗ trợ

Để được hỗ trợ hoặc đóng góp ý kiến, vui lòng liên hệ qua:
- GitHub Issues
- Email support
- Documentation wiki

---

**Lưu ý**: Hệ thống này được thiết kế để tích hợp mượt mà với ứng dụng OpenFood hiện tại và có thể mở rộng dễ dàng cho các tính năng tương lai.
