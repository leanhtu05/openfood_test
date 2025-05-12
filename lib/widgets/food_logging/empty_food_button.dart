import 'package:flutter/material.dart';

class EmptyFoodButton extends StatelessWidget {
  final VoidCallback onPressed;

  const EmptyFoodButton({
    Key? key,
    required this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(Icons.add, color: Colors.blue, size: 16),
      label: Text(
        'Thực phẩm trống',
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: Colors.blue, fontSize: 12),
      ),
      style: TextButton.styleFrom(
        backgroundColor: Colors.blue.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size(10, 28),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
} 