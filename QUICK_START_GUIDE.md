# 🚀 Hướng dẫn Sử dụng Nhanh - AI Finance Agent

## 📱 Cách sử dụng trong Ứng dụng

### 1. Mở Danh sách Mua sắm
- Từ màn hình chính, chọn "Danh sách mua sắm"
- Hoặc tạo kế hoạch bữa ăn trước để có danh sách tự động

### 2. Kích hoạt AI Finance Agent
- Nhấn vào icon **Analytics** (📊) trên thanh công cụ
- Icon sẽ chuyển màu xanh khi được kích hoạt
- Hệ thống sẽ tự động phân tích chi phí

### 3. Xem Phân tích Chi phí
Sau khi kích hoạt, bạn sẽ thấy:

#### 💰 Card Tổng Chi phí
- Tổng chi phí ước tính cho 2 ngày (hôm nay + ngày mai)
- Chi phí trung bình mỗi món
- Hiển thị bằng tiền Việt Nam (VND)

#### 📊 So sánh Ngân sách
- Thanh tiến độ màu sắc:
  - 🟢 Xanh: Dưới 50% ngân sách
  - 🟡 Vàng: 50-80% ngân sách  
  - 🔴 Đỏ: Trên 80% hoặc vượt ngân sách
- Phần trăm sử dụng ngân sách
- Cảnh báo nếu vượt ngân sách

#### 🥧 Biểu đồ Phân tích Danh mục
- Biểu đồ tròn hiển thị tỷ lệ chi phí theo danh mục
- Danh sách chi tiết:
  - 🥩 Thịt tươi sống
  - 🥬 Rau củ quả
  - 🌾 Thực phẩm khô
  - 🥛 Sản phẩm từ sữa
  - 🧂 Gia vị & Nước chấm

#### 💡 Mẹo Tiết kiệm AI
- Phân tích danh mục tốn kém nhất
- Gợi ý mua theo mùa
- Khuyến khích so sánh giá nhiều nơi
- Hiển thị số tiền có thể tiết kiệm

#### ⚠️ Cảnh báo Giá cả
- Phát hiện sản phẩm có giá cao bất thường
- Hiển thị % tăng giá so với bình thường
- Gợi ý thời điểm mua tốt hơn

### 4. Cập nhật Ngân sách
- Nhấn vào nút "Chỉnh sửa" trong phần so sánh ngân sách
- Hoặc nhấn vào Floating Action Button (FAB) khi đang xem phân tích
- Nhập số tiền ngân sách mới
- Hệ thống sẽ phân tích lại tự động

### 5. Xem Chi phí từng Món
- Khi bật chế độ phân tích, mỗi món trong danh sách sẽ hiển thị:
  - Tên món và số lượng
  - **Ước tính giá**: Hiển thị bằng VND compact (VD: 175K₫)

## 🎯 Demo và Test

### Chạy Demo
1. Mở ứng dụng
2. Chọn "Finance Agent Demo" (nếu có)
3. Hoặc sử dụng nút "Test với dữ liệu mẫu" trong Grocery List

### Dữ liệu Demo bao gồm:
- **Thịt bò** 500g → 175,000₫
- **Cà chua** 300g → 7,500₫  
- **Hành tây** 200g → 4,000₫
- **Gạo** 1kg → 25,000₫
- **Trứng gà** 6 quả → 24,000₫
- **Dầu oliu** 3 muỗng → 6,750₫
- **Phô mai** 100g → 20,000₫
- **Chuối** 1kg → 25,000₫

**Tổng: 287,250₫**

## 🎨 Giao diện và Màu sắc

### Màu sắc Thông minh
- **Xanh lá** 🟢: An toàn, trong ngân sách
- **Vàng** 🟡: Cảnh báo, gần hết ngân sách
- **Đỏ** 🔴: Nguy hiểm, vượt ngân sách
- **Xanh dương** 🔵: Thông tin, phân tích
- **Cam** 🟠: Mẹo tiết kiệm

### Icons Sử dụng
- 📊 Analytics: Kích hoạt phân tích
- 💰 Wallet: Ngân sách và chi phí
- 💡 Lightbulb: Mẹo tiết kiệm
- ⚠️ Warning: Cảnh báo giá cao
- 🥧 Pie Chart: Phân tích danh mục

## ⚡ Tính năng Nhanh

### Shortcuts
- **Nhấn đôi** vào tổng chi phí → Cập nhật ngân sách
- **Vuốt** để ẩn/hiện phân tích
- **Nhấn giữ** món ăn → Xem chi tiết giá

### Thông báo Thông minh
- Cảnh báo khi vượt ngân sách
- Thông báo khi có mẹo tiết kiệm mới
- Alert khi phát hiện giá cao

## 🔧 Tùy chỉnh

### Cài đặt Ngân sách
- Ngân sách mặc định: 500,000₫
- Có thể thay đổi bất kỳ lúc nào
- Lưu tự động cho lần sử dụng tiếp theo

### Tùy chỉnh Danh mục
- Hệ thống tự động phân loại
- Dựa trên tên sản phẩm tiếng Việt
- Có thể mở rộng thêm danh mục mới

## 🆘 Xử lý Sự cố

### Không hiển thị phân tích?
1. Kiểm tra có danh sách mua sắm không
2. Nhấn nút Refresh (🔄)
3. Thử tắt/bật chế độ phân tích

### Giá cả không chính xác?
- Giá dựa trên database mẫu Việt Nam
- Có thể khác với giá thực tế tại địa phương
- Sẽ được cập nhật với API thực tế trong tương lai

### Ứng dụng chậm?
- Phân tích chỉ chạy khi cần thiết
- Có thể tắt chế độ phân tích để tăng tốc
- Cache kết quả để lần sau nhanh hơn

## 📞 Hỗ trợ

Nếu gặp vấn đề:
1. Kiểm tra kết nối internet
2. Restart ứng dụng
3. Liên hệ support qua app
4. Báo lỗi trên GitHub

---

**🎉 Chúc bạn mua sắm thông minh và tiết kiệm!**
