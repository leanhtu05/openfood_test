import 'package:flutter/material.dart';

/// Hàm tiện ích để hiển thị dialog chọn nước
Future<void> showWaterInputDialog(BuildContext context, Function(int) onSaveWater) async {
  return showDialog(
    context: context,
    builder: (BuildContext context) {
      return WaterInputDialog(onSaveWater: onSaveWater);
    },
  );
}

/// Dialog nhập lượng nước
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
  int waterAmount = 200; // Mặc định 200ml
  String selectedDrinkType = 'water'; // Loại đồ uống mặc định: nước lọc
  bool isCustomAmount = false; // Biến để kiểm soát chế độ nhập tùy chỉnh
  final TextEditingController customAmountController = TextEditingController(text: '200');
  
  // Danh sách loại đồ uống
  final List<Map<String, dynamic>> drinkTypes = [
    {'id': 'water', 'name': 'Nước lọc', 'icon': Icons.water_drop, 'color': Colors.blue},
    {'id': 'tea', 'name': 'Trà', 'icon': Icons.emoji_food_beverage, 'color': Colors.brown.shade300},
    {'id': 'coffee', 'name': 'Cà phê', 'icon': Icons.coffee, 'color': Colors.brown},
    {'id': 'juice', 'name': 'Nước ép', 'icon': Icons.local_drink, 'color': Colors.orange},
  ];
  
  // Lấy thông tin đồ uống hiện tại
  Map<String, dynamic> getCurrentDrink() {
    return drinkTypes.firstWhere((drink) => drink['id'] == selectedDrinkType);
  }
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header với icon và tiêu đề
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: getCurrentDrink()['color'].withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      getCurrentDrink()['icon'],
                      color: getCurrentDrink()['color'],
                      size: 28,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nhập lượng nước đã uống',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Theo dõi lượng nước đã uống',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: 24),
              
              // Chọn loại đồ uống
              Container(
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  itemCount: drinkTypes.length,
                  separatorBuilder: (context, index) => SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final drink = drinkTypes[index];
                    final isSelected = selectedDrinkType == drink['id'];
                    
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedDrinkType = drink['id'];
                        });
                      },
                      child: AnimatedContainer(
                        duration: Duration(milliseconds: 200),
                        width: 56,
                        decoration: BoxDecoration(
                          color: isSelected ? drink['color'] : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: isSelected ? [
                            BoxShadow(
                              color: drink['color'].withOpacity(0.3),
                              blurRadius: 8,
                              offset: Offset(0, 3),
                            )
                          ] : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              drink['icon'],
                              color: isSelected ? Colors.white : drink['color'],
                              size: 24,
                            ),
                            SizedBox(height: 4),
                            Text(
                              drink['name'],
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? Colors.white : Colors.black,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              
              SizedBox(height: 24),
              
              // Hiển thị lượng nước đã chọn
              AnimatedContainer(
                duration: Duration(milliseconds: 300),
                padding: EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: getCurrentDrink()['color'].withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        if (!isCustomAmount) ...[
                          // Hiển thị số lượng đã chọn
                          Text(
                            '$waterAmount',
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: getCurrentDrink()['color'],
                            ),
                          ),
                          Text(
                            ' mL',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.normal,
                              color: getCurrentDrink()['color'],
                            ),
                          ),
                        ] else ...[
                          // Hiển thị ô nhập liệu
                          SizedBox(
                            width: 100,
                            child: TextField(
                              controller: customAmountController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              autofocus: true,
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: getCurrentDrink()['color'],
                              ),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText: '0',
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          Text(
                            ' mL',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.normal,
                              color: getCurrentDrink()['color'],
                            ),
                          ),
                        ],
                        // Nút để chuyển đổi giữa nhập tùy chỉnh và slider
                        IconButton(
                          icon: Icon(
                            isCustomAmount ? Icons.graphic_eq : Icons.edit,
                            size: 18,
                          ),
                          color: getCurrentDrink()['color'],
                          onPressed: () {
                            setState(() {
                              if (!isCustomAmount) {
                                // Chuyển sang chế độ nhập tùy chỉnh
                                isCustomAmount = true;
                              } else {
                                // Chuyển về chế độ slider và cập nhật giá trị
                                int? value = int.tryParse(customAmountController.text);
                                if (value != null && value > 0) {
                                  waterAmount = value > 2000 ? 2000 : value;
                                }
                                isCustomAmount = false;
                              }
                            });
                          },
                        ),
                      ],
                    ),
                    
                    if (!isCustomAmount) ...[
                      SizedBox(height: 8),
                      // Thanh điều chỉnh lượng nước
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          children: [
                            // Nút giảm
                            GestureDetector(
                              onTap: () {
                                if (waterAmount > 50) {
                                  setState(() {
                                    waterAmount -= 50;
                                  });
                                }
                              },
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(Icons.remove, color: Colors.grey[700], size: 16),
                              ),
                            ),
                            
                            // Thanh trượt
                            Expanded(
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  activeTrackColor: getCurrentDrink()['color'],
                                  inactiveTrackColor: Colors.grey[200],
                                  thumbColor: Colors.white,
                                  thumbShape: RoundSliderThumbShape(
                                    enabledThumbRadius: 8,
                                    elevation: 4,
                                  ),
                                  overlayColor: getCurrentDrink()['color'].withOpacity(0.2),
                                  trackHeight: 4,
                                ),
                                child: Slider(
                                  value: waterAmount.toDouble(),
                                  min: 50,
                                  max: 2000,
                                  onChanged: (value) {
                                    setState(() {
                                      waterAmount = value.round();
                                    });
                                  },
                                ),
                              ),
                            ),
                            
                            // Nút tăng
                            GestureDetector(
                              onTap: () {
                                if (waterAmount < 2000) {
                                  setState(() {
                                    waterAmount += 50;
                                  });
                                }
                              },
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(Icons.add, color: Colors.grey[700], size: 16),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              SizedBox(height: 16),
              
              // Các nút lựa chọn nhanh
              Wrap(
                spacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _buildQuickChoiceChip(100),
                  _buildQuickChoiceChip(200),
                  _buildQuickChoiceChip(250),
                  _buildQuickChoiceChip(300),
                  _buildQuickChoiceChip(500),
                ],
              ),
              
              SizedBox(height: 24),
              
              // Nút thao tác
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey[700],
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text('Hủy'),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        // Lấy giá trị cuối cùng khi đang ở chế độ nhập tùy chỉnh
                        if (isCustomAmount) {
                          int? value = int.tryParse(customAmountController.text);
                          if (value != null && value > 0) {
                            waterAmount = value;
                          }
                        }
                        
                        Navigator.of(context).pop();
                        widget.onSaveWater(waterAmount);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: getCurrentDrink()['color'],
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'Xác nhận',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildQuickChoiceChip(int amount) {
    final bool isSelected = waterAmount == amount;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          waterAmount = amount;
          customAmountController.text = amount.toString();
          isCustomAmount = false;
        });
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 8),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? getCurrentDrink()['color'] : Colors.grey[100],
          borderRadius: BorderRadius.circular(30),
          boxShadow: isSelected ? [
            BoxShadow(
              color: getCurrentDrink()['color'].withOpacity(0.3),
              blurRadius: 8,
              offset: Offset(0, 3),
            )
          ] : null,
        ),
        child: Text(
          '$amount mL',
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
} 