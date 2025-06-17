import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../screens/auth/auth_screen.dart';

class AuthHelper {
  /// Kiểm tra xem người dùng đã đăng nhập thực sự (không phải anonymous) chưa
  static bool isRealUser(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    return authService.isAuthenticated && 
           authService.user != null && 
           !authService.user!.isAnonymous;
  }

  /// Hiển thị dialog mời đăng nhập với thông báo tùy chỉnh
  static Future<bool> showLoginPrompt(
    BuildContext context, {
    String? title,
    String? message,
    String? feature,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.login,
                color: Colors.blue,
                size: 28,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  title ?? 'Đăng nhập để tiếp tục',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message ?? 'Mời bạn đăng nhập để trải nghiệm ${feature ?? "tính năng này"}',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue.shade600,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Đăng nhập để lưu dữ liệu và đồng bộ trên nhiều thiết bị',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Để sau',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Đăng nhập',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );

    // Nếu người dùng chọn đăng nhập, chuyển đến màn hình đăng nhập
    if (result == true) {
      bool loginSuccess = false;

      final loginResult = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AuthScreen(
            onAuthSuccess: () {
              loginSuccess = true;
              Navigator.pop(context, true);
            },
          ),
        ),
      );

      // Trả về true nếu đăng nhập thành công
      return loginSuccess || loginResult == true;
    }

    return false;
  }

  /// Kiểm tra đăng nhập và thực hiện action nếu đã đăng nhập, 
  /// hoặc hiển thị prompt nếu chưa đăng nhập
  static Future<bool> requireLogin(
    BuildContext context, {
    required VoidCallback onAuthenticated,
    String? title,
    String? message,
    String? feature,
  }) async {
    if (isRealUser(context)) {
      onAuthenticated();
      return true;
    } else {
      final loginSuccess = await showLoginPrompt(
        context,
        title: title,
        message: message,
        feature: feature,
      );
      
      if (loginSuccess) {
        onAuthenticated();
        return true;
      }
      
      return false;
    }
  }

  /// Hiển thị snackbar thông báo cần đăng nhập
  static void showLoginRequiredSnackBar(
    BuildContext context, {
    String? message,
    String? feature,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: Colors.white,
              size: 20,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                message ?? 'Vui lòng đăng nhập để sử dụng ${feature ?? "tính năng này"}',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange.shade600,
        duration: Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Đăng nhập',
          textColor: Colors.white,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AuthScreen(
                  onAuthSuccess: () {
                    Navigator.pop(context);
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Wrapper widget để bọc các tính năng cần đăng nhập
  static Widget requireAuthWrapper({
    required BuildContext context,
    required Widget child,
    required VoidCallback onTap,
    String? feature,
    String? title,
    String? message,
  }) {
    return GestureDetector(
      onTap: () {
        requireLogin(
          context,
          onAuthenticated: onTap,
          title: title,
          message: message,
          feature: feature,
        );
      },
      child: child,
    );
  }
}
