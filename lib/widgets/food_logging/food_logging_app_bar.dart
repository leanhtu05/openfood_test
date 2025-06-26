import 'package:flutter/material.dart';

class FoodLoggingAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onSwitchToEmptyFood;
  
  const FoodLoggingAppBar({
    Key? key,
    required this.onSwitchToEmptyFood,
  }) : super(key: key);

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      automaticallyImplyLeading: true,
      title: Row(
        children: [
          Icon(Icons.qr_code_2, color: Colors.green[800]),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              'Ghi lại thực phẩm', 
              style: TextStyle(color: Colors.green[800], fontSize: 16),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Spacer(),
          TextButton.icon(
            onPressed: onSwitchToEmptyFood,
            icon: Icon(Icons.add_circle_outline, size: 16, color: Colors.green),
            label: Text('Thêm mới', style: TextStyle(color: Colors.green, fontSize: 12)),
            style: TextButton.styleFrom(
              backgroundColor: Colors.green[50],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
          ),
        ],
      ),
      iconTheme: IconThemeData(color: Colors.green[800]),
    );
  }
} 