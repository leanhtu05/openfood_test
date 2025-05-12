import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/water_provider.dart';
import '../screens/water_history_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Widget để hiển thị phần theo dõi nước trong ứng dụng
class WaterTrackingWidget extends StatelessWidget {
  final int waterConsumed; // Lượng nước đã uống (mL)
  final int waterGoal; // Mục tiêu uống nước (mL)
  final Function onAddWater; // Callback khi bấm nút thêm nước
  final DateTime? lastWaterTime; // Thời gian lần cuối uống nước

  const WaterTrackingWidget({
    Key? key,
    this.waterConsumed = 0,
    this.waterGoal = 3700,
    this.lastWaterTime,
    required this.onAddWater,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Định dạng thời gian ghi nhận lần cuối
    String lastRecordTime = lastWaterTime != null 
        ? DateFormat('HH:mm').format(lastWaterTime!) 
        : '--:--';
    
    // Nếu không có lượng nước nào, không hiển thị gì cả
    final bool hasWaterData = waterConsumed > 0;
    
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header với icon và title - nhỏ hơn
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.water_drop_outlined, color: Colors.blue, size: 22),
                SizedBox(width: 8),
                Text(
                  'Nước',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Spacer(),
                // Nút hiển thị lịch sử
                GestureDetector(
                  onTap: () {
                    Navigator.pushNamed(context, WaterHistoryScreen.routeName);
                  },
                  child: Icon(Icons.arrow_forward_ios, size: 16),
                ),
              ],
            ),
          ),
          
          // Phần nội dung
          hasWaterData 
              ? _buildWaterContent(context, lastRecordTime)
              : _buildEmptyWaterContent(context),
        ],
      ),
    );
  }
  
  // Hiển thị khi không có dữ liệu nước
  Widget _buildEmptyWaterContent(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Biểu tượng và thông báo khi chưa có nước
          Icon(
            Icons.water_drop_outlined,
            size: 48,
            color: Colors.blue.withOpacity(0.3),
          ),
          SizedBox(height: 8),
          Text(
            'Chưa ghi nhận uống nước hôm nay',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          // Nút thêm nước
          ElevatedButton.icon(
            onPressed: () => onAddWater(),
            icon: Icon(Icons.add, color: Colors.white, size: 18),
            label: Text(
              'Ghi Lại Nước',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade400,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
  
  // Hiển thị khi có dữ liệu nước
  Widget _buildWaterContent(BuildContext context, String lastRecordTime) {
    // Tính phần trăm đạt được so với mục tiêu
    final double percentage = waterConsumed / waterGoal;
    final bool isExceeded = percentage > 1.0;
    
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Thông tin về lần cuối ghi nhận
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Lần cuối ghi nhận: $lastRecordTime',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              SizedBox(width: 4),
              Text(
                '+${_formatAmount(waterConsumed)}mL',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          
          // Thanh tiến độ
          Container(
            height: 10,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Stack(
              children: [
                FractionallySizedBox(
                  widthFactor: percentage > 1.0 ? 1.0 : percentage,
                  child: Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: isExceeded ? Colors.green : Colors.blue,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 8),
          
          // Hiển thị lượng nước đã uống / mục tiêu
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${_formatAmount(waterConsumed)}/${_formatAmount(waterGoal)}mL',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: Colors.grey.shade600,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              SizedBox(width: 4),
              Text(
                isExceeded ? 'Hoàn thành!' : '${(percentage * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isExceeded ? Colors.green : Colors.blue,
                ),
              )
            ],
          ),
          SizedBox(height: 16),
          
          // Nút ghi lại nước
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: () => onAddWater(),
              icon: Icon(Icons.add, color: Colors.white, size: 18),
              label: Text(
                'Ghi Lại Nước',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade400,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // Định dạng số lượng với dấu phân cách hàng nghìn (ví dụ: 12,650)
  String _formatAmount(int amount) {
    return NumberFormat('#,###').format(amount);
  }
}

/// Dialog hiển thị để nhập lượng nước
class WaterInputDialog extends StatefulWidget {
  final Function(int) onSaveWater;

  const WaterInputDialog({
    Key? key, 
    required this.onSaveWater,
  }) : super(key: key);

  @override
  _WaterInputDialogState createState() => _WaterInputDialogState();
}

class _WaterInputDialogState extends State<WaterInputDialog> {
  // Giá trị và đơn vị được chọn
  int selectedAmount = 1;
  bool isUsingCups = true; // true: cốc, false: mL
  
  // Controller cho việc nhập số tùy ý
  final TextEditingController _customAmountController = TextEditingController();
  
  // Các lựa chọn cho từng đơn vị
  final List<int> mlOptions = [50, 100, 150, 200, 250, 300, 350, 400, 450, 500, 750, 1000];
  final List<int> cupOptions = [1, 2, 3, 4, 5, 6, 8, 10];
  
  // Hệ số quy đổi: 1 cốc = 250mL
  final int cupToMlFactor = 250;

  // Chế độ hiển thị: true = chế độ nhập giá trị tùy chọn, false = chế độ chọn từ gợi ý
  bool isCustomInputMode = false;
  
  @override
  void initState() {
    super.initState();
    _customAmountController.text = selectedAmount.toString();
  }
  
  @override
  void dispose() {
    _customAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header với icon dots và arrows
            Container(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Icon dots menu
                  Icon(Icons.grid_view, size: 20, color: Colors.grey),
                  
                  // Toggle chuyển đổi giữa chế độ nhập và chế độ gợi ý
                  Row(
                    children: [
                      Switch(
                        value: isCustomInputMode,
                        onChanged: (value) {
                          setState(() {
                            isCustomInputMode = value;
                            if (isCustomInputMode) {
                              _customAmountController.text = selectedAmount.toString();
                            }
                          });
                        },
                        activeColor: Colors.green,
                        inactiveThumbColor: Colors.grey,
                        inactiveTrackColor: Colors.grey.withOpacity(0.5),
                      ),
                      Icon(Icons.keyboard_arrow_up, size: 20, color: Colors.grey),
                      Icon(Icons.keyboard_arrow_down, size: 20, color: Colors.grey),
                    ],
                  ),
                ],
              ),
            ),
            
            // Tiêu đề với icon nước
            Container(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.local_drink_outlined, color: Colors.blue, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Nước',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Nội dung chính của dialog
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                children: [
                  // Icon và Text giải thích
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '💧',
                        style: TextStyle(fontSize: 16),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Ghi lại lượng nước bạn uống để theo dõi mức độ hydrat hóa của bạn. '
                          '1 ly là 250mL! Hãy uống đủ nước, giữ cho cơ thể luôn tươi mới '
                          'và đạt được mục tiêu hydrat hóa của bạn! 💦',
                          style: TextStyle(fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 20),
                  
                  // Chuyển đổi giữa cốc và mL
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            isUsingCups = true;
                            if (isCustomInputMode) {
                              // Chuyển đổi giá trị từ mL sang cốc
                              try {
                                int ml = int.parse(_customAmountController.text);
                                _customAmountController.text = (ml / cupToMlFactor).round().toString();
                              } catch (e) {
                                _customAmountController.text = "1";
                              }
                            } else {
                              selectedAmount = 1; // Reset về mặc định khi chuyển đơn vị
                            }
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isUsingCups ? Colors.blue : Colors.grey.shade200,
                          foregroundColor: isUsingCups ? Colors.white : Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.horizontal(
                              left: Radius.circular(20),
                              right: Radius.zero,
                            ),
                          ),
                          elevation: isUsingCups ? 2 : 0,
                        ),
                        child: Text('Cốc'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            isUsingCups = false;
                            if (isCustomInputMode) {
                              // Chuyển đổi giá trị từ cốc sang mL
                              try {
                                int cups = int.parse(_customAmountController.text);
                                _customAmountController.text = (cups * cupToMlFactor).toString();
                              } catch (e) {
                                _customAmountController.text = "150";
                              }
                            } else {
                              selectedAmount = 150; // Reset về mặc định khi chuyển đơn vị
                            }
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: !isUsingCups ? Colors.blue : Colors.grey.shade200,
                          foregroundColor: !isUsingCups ? Colors.white : Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.horizontal(
                              left: Radius.zero,
                              right: Radius.circular(20),
                            ),
                          ),
                          elevation: !isUsingCups ? 2 : 0,
                        ),
                        child: Text('mL'),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 20),
                  
                  // Hiển thị tùy theo chế độ
                  if (isCustomInputMode)
                    _buildCustomInputSelector()
                  else
                    _buildSuggestionsScrollView(),
                ],
              ),
            ),

            // Nút lưu ở dưới cùng
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: ElevatedButton.icon(
                onPressed: () {
                  int finalAmount = selectedAmount;
                  
                  // Nếu đang ở chế độ nhập tùy chọn, lấy giá trị từ TextField
                  if (isCustomInputMode) {
                    try {
                      finalAmount = int.parse(_customAmountController.text);
                      // Đảm bảo giá trị hợp lệ
                      if (finalAmount <= 0) {
                        finalAmount = isUsingCups ? 1 : 50;
                      }
                    } catch (e) {
                      finalAmount = isUsingCups ? 1 : 50;
                    }
                  }
                  
                  // Quy đổi sang mL nếu đang dùng cốc
                  final int mlAmount = isUsingCups 
                      ? finalAmount * cupToMlFactor 
                      : finalAmount;
                  
                  // Gọi hàm lưu dữ liệu
                  widget.onSaveWater(mlAmount);
                  Navigator.of(context).pop();
                },
                icon: Icon(Icons.add, color: Colors.white),
                label: Text(
                  'Ghi Lại Nước',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Widget cho phép nhập giá trị tùy chọn
  Widget _buildCustomInputSelector() {
    return Column(
      children: [
        // Input field với nút tăng/giảm
        Row(
          children: [
            // Nút giảm
            IconButton(
              onPressed: () {
                int currentValue = int.tryParse(_customAmountController.text) ?? 0;
                if (currentValue > 1) {
                  _customAmountController.text = (currentValue - 1).toString();
                }
              },
              icon: Icon(Icons.remove_circle_outline),
              color: Colors.red,
            ),
            
            // TextField nhập số
            Expanded(
              child: TextField(
                controller: _customAmountController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: isUsingCups ? 'Số cốc' : 'Số mL',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  suffixText: isUsingCups ? 'cốc' : 'mL',
                ),
              ),
            ),
            
            // Nút tăng
            IconButton(
              onPressed: () {
                int currentValue = int.tryParse(_customAmountController.text) ?? 0;
                _customAmountController.text = (currentValue + 1).toString();
              },
              icon: Icon(Icons.add_circle_outline),
              color: Colors.green,
            ),
          ],
        ),
      ],
    );
  }
  
  // Widget hiển thị gợi ý dạng SingleChildScrollView
  Widget _buildSuggestionsScrollView() {
    final options = isUsingCups ? cupOptions : mlOptions;
    
    return Column(
      children: [
        // Hiển thị lượng đã chọn
        Container(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Text(
            isUsingCups 
                ? '$selectedAmount cốc (${selectedAmount * cupToMlFactor} mL)' 
                : '$selectedAmount mL',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
        ),
        
        SizedBox(height: 15),
        
        // Danh sách gợi ý dạng scroll ngang
        Container(
          height: 80,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: options.map((value) {
                final bool isSelected = value == selectedAmount;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedAmount = value;
                    });
                  },
                  child: Container(
                    width: 70,
                    margin: EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.blue : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? Colors.blue.shade700 : Colors.grey.shade300,
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$value',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : Colors.black87,
                          ),
                        ),
                        Text(
                          isUsingCups ? 'cốc' : 'mL',
                          style: TextStyle(
                            fontSize: 14,
                            color: isSelected ? Colors.white70 : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

/// Hàm tiện ích để hiển thị dialog chọn nước
Future<void> showWaterInputDialog(BuildContext context, Function(int) onSaveWater) async {
  return showDialog(
    context: context,
    builder: (BuildContext context) {
      return WaterInputDialog(onSaveWater: onSaveWater);
    },
  );
}

/// Hàm xử lý lưu dữ liệu nước 
Future<void> saveWaterToPrefs(int ml) async {
  try {
    // Lấy ngày hiện tại
    final String currentDate = DateTime.now().toIso8601String().split('T')[0];
    
    // Lưu vào SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    
    // Lấy dữ liệu nước hiện tại nếu có
    final String waterDataString = prefs.getString('water_data_$currentDate') ?? '0';
    final int currentWaterAmount = int.parse(waterDataString);
    
    // Cộng thêm lượng nước mới
    final int newWaterAmount = currentWaterAmount + ml;
    
    // Lưu lại dữ liệu mới
    await prefs.setString('water_data_$currentDate', newWaterAmount.toString());
    
    print('Đã lưu lượng nước: $ml mL vào ngày $currentDate');
  } catch (e) {
    print('Lỗi khi lưu dữ liệu nước: $e');
  }
}
