import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import 'package:intl/intl.dart';

class AuthStatusIndicator extends StatelessWidget {
  const AuthStatusIndicator({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final syncService = Provider.of<SyncService>(context);
    
    // Kiểm tra xem người dùng có phải là khách hay không
    final bool isGuest = authService.isAuthenticated && (authService.user?.isAnonymous ?? false);
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 5,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Auth status icon
          Icon(
            isGuest ? 
              Icons.person_outline : 
              (authService.isAuthenticated ? Icons.person : Icons.no_accounts),
            color: isGuest ? 
              Colors.orange : 
              (authService.isAuthenticated ? Colors.green : Colors.grey),
            size: 18,
          ),
          SizedBox(width: 8),
          
          // Status text
          Text(
            isGuest ? 
              "Chế độ khách" : 
              (authService.isAuthenticated ? "Đã đăng nhập" : "Chưa đăng nhập"),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          
          // Sync indicator
          if (syncService.isSyncing)
            Padding(
              padding: EdgeInsets.only(left: 8),
              child: SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              ),
            ),
            
          if (syncService.lastSyncTime != null && !syncService.isSyncing)
            Padding(
              padding: EdgeInsets.only(left: 8),
              child: Tooltip(
                message: "Đồng bộ lần cuối: ${_formatDateTime(syncService.lastSyncTime!)}",
                child: Icon(
                  Icons.sync,
                  size: 16,
                  color: syncService.lastSyncError == null ? Colors.green : Colors.orange,
                ),
              ),
            ),
            
          // Error indicator
          if (syncService.lastSyncError != null && !syncService.isSyncing)
            Padding(
              padding: EdgeInsets.only(left: 4),
              child: Tooltip(
                message: syncService.lastSyncError,
                child: Icon(
                  Icons.error_outline,
                  size: 16,
                  color: Colors.red,
                ),
              ),
            ),
            
          // Force sync button
          if (authService.isAuthenticated && !isGuest && !syncService.isSyncing)
            Padding(
              padding: EdgeInsets.only(left: 4),
              child: InkWell(
                onTap: () {
                  syncService.forceSync();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Đang đồng bộ dữ liệu...'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                child: Tooltip(
                  message: "Đồng bộ ngay",
                  child: Icon(
                    Icons.sync,
                    size: 16,
                    color: Colors.blue,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  String _formatDateTime(DateTime dateTime) {
    return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
  }
} 