import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth_service.dart';

enum FeatureType {
  basic,      // Available to all users
  standard,   // Available to authenticated users (including anonymous)
  premium     // Available only to fully registered users
}

class FeatureAccessService {
  final BuildContext context;
  late final AuthService _authService;

  FeatureAccessService(this.context) {
    _authService = Provider.of<AuthService>(context, listen: false);
  }

  /// Check if a feature is available to the current user
  bool canAccessFeature(FeatureType featureType) {
    switch (featureType) {
      case FeatureType.basic:
        return true;
      case FeatureType.standard:
        return _authService.isAuthenticated;
      case FeatureType.premium:
        return _authService.isPremiumUser();
    }
  }

  /// Handle a feature access attempt
  /// 
  /// Returns true if access is granted, false if access is denied.
  /// If access is denied and [showDialog] is true, displays a dialog to the user.
  bool handleFeatureAccess(
    FeatureType featureType, {
    bool showDialog = true,
    VoidCallback? onAccessGranted,
  }) {
    final hasAccess = canAccessFeature(featureType);
    
    if (hasAccess) {
      if (onAccessGranted != null) {
        onAccessGranted();
      }
      return true;
    } else if (showDialog) {
      _showAccessDeniedDialog(featureType);
    }
    
    return false;
  }

  /// Determine the appropriate error message based on feature type
  void _showAccessDeniedDialog(FeatureType featureType) {
    String title;
    String message;

    switch (featureType) {
      case FeatureType.basic:
        // This should not happen as basic features are always accessible
        return;
      case FeatureType.standard:
        title = 'Yêu cầu đăng nhập';
        message = 'Bạn cần đăng nhập để sử dụng tính năng này.';
        break;
      case FeatureType.premium:
        title = 'Tính năng cao cấp';
        message = _authService.isAuthenticated && _authService.user?.isAnonymous == true
            ? 'Bạn đang sử dụng chế độ khách. Vui lòng đăng ký tài khoản để sử dụng tính năng này.'
            : 'Tính năng này chỉ có sẵn cho người dùng đã đăng ký. Vui lòng đăng nhập để tiếp tục.';
        break;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Huỷ'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _navigateToAuth();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFE65100),
            ),
            child: Text(
              _authService.isAuthenticated && _authService.user?.isAnonymous == true
                  ? 'Đăng ký'
                  : 'Đăng nhập'
            ),
          ),
        ],
      ),
    );
  }

  /// Navigate to authentication screen
  void _navigateToAuth() {
    Navigator.of(context).pushNamed('/auth', arguments: {
      'isLoginMode': !(_authService.isAuthenticated && _authService.user?.isAnonymous == true)
    });
  }
} 