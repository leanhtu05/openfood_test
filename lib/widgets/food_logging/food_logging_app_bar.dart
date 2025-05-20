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
          TextButton(
            onPressed: onSwitchToEmptyFood,
            child: Text('Thực phẩm trống', style: TextStyle(color: Colors.blue)),
            style: TextButton.styleFrom(
              backgroundColor: Colors.blue[50],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ],
      ),
      iconTheme: IconThemeData(color: Colors.green[800]),
    );
  }
} 