import 'package:flutter/material.dart';
// import 'package:flutter/services.dart'; // Xóa import này vì không cần HapticFeedback
import '../utils/constants.dart';

class BottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;

  const BottomNavBar({
    Key? key,
    required this.selectedIndex,
    required this.onItemSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Sử dụng SafeArea để đảm bảo thanh điều hướng không bị phủ bởi phần notch hoặc thanh điều hướng hệ thống
    return SafeArea(
      child: Container(
        height: 50, // Giảm chiều cao để tránh overflow
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Colors.grey.shade200, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            _buildNavItem(context, 0, Icons.medical_services_outlined, 'Sức khỏe'),
            _buildNavItem(context, 1, Icons.restaurant_menu_outlined, 'Chế độ ăn'),
            _buildNavItem(context, 2, Icons.insert_chart_outlined, 'Theo dõi'),
            _buildNavItem(context, 3, Icons.add_box_outlined, 'Ghi lại'),
            _buildNavItem(context, 4, Icons.person_outline, 'Tài khoản'),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, int index, IconData icon, String label) {
    final bool selected = selectedIndex == index;
    
    // Tính toán màu sắc dựa trên trạng thái được chọn
    final Color color = selected ? AppColors.primary : Colors.grey.shade600;
    
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onItemSelected(index),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 24,
                color: color,
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: color,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}