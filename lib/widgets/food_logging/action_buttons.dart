import 'package:flutter/material.dart';

class FoodLoggingActionButtons extends StatelessWidget {
  final bool isRecording;
  final VoidCallback onRecordTap;
  final VoidCallback onGalleryTap;
  final VoidCallback onCameraTap;
  final VoidCallback onHistoryTap;
  final VoidCallback onFavoriteTap;

  const FoodLoggingActionButtons({
    Key? key,
    required this.isRecording,
    required this.onRecordTap,
    required this.onGalleryTap,
    required this.onCameraTap,
    required this.onHistoryTap,
    required this.onFavoriteTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Nút ghi âm
          _buildIconButton(
            isRecording: isRecording,
            onTap: onRecordTap,
            icon: Icons.mic,
            size: 60,
            isMain: false,
          ),
          
          // Nút chọn ảnh từ thư viện
          _buildIconButton(
            isRecording: false,
            onTap: onGalleryTap,
            icon: Icons.photo_library,
            size: 60,
            isMain: false,
          ),
          
          // Nút chụp ảnh (ở giữa và lớn hơn)
          _buildIconButton(
            isRecording: false,
            onTap: onCameraTap,
            icon: Icons.camera_alt,
            size: 80,
            isMain: true,
          ),
          
          // Nút lịch sử
          _buildActionButton(
            onTap: onHistoryTap,
            icon: Icons.history,
            label: 'Lịch Sử',
          ),
          
          // Nút yêu thích
          _buildActionButton(
            onTap: onFavoriteTap,
            icon: Icons.star,
            label: 'Yêu thích',
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton({
    required bool isRecording,
    required VoidCallback onTap,
    required IconData icon,
    required double size,
    required bool isMain,
  }) {
    final Color iconColor;
    final Color bgColor;
    
    if (isMain) {
      iconColor = Colors.white;
      bgColor = Colors.green;
    } else if (isRecording && icon == Icons.mic) {
      iconColor = Colors.red;
      bgColor = Colors.red.withOpacity(0.2);
    } else {
      iconColor = Colors.indigo[900]!;
      bgColor = Colors.grey.withOpacity(0.1);
    }
    
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: isMain ? 40 : 30,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildActionButton({
    required VoidCallback onTap,
    required IconData icon,
    required String label,
  }) {
    return ActionButton(
      icon: icon,
      label: label,
      color: Colors.blue,
      onPressed: onTap,
    );
  }
}

class ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const ActionButton({
    Key? key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 80,
        height: 85,
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              flex: 2,
              child: Icon(icon, color: color, size: 22),
            ),
            SizedBox(height: 4),
            Flexible(
              flex: 1,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 