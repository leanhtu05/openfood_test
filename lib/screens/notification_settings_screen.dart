import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  final NotificationService _notificationService = NotificationService();
  
  bool _enableMealReminders = true;
  bool _enableWaterReminders = true;
  bool _enableExerciseReminders = true;
  bool _enableGroceryReminders = true;
  
  bool _isLoading = true;
  int _pendingNotifications = 0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadPendingNotifications();
  }

  /// 📱 Load cài đặt từ SharedPreferences
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    setState(() {
      _enableMealReminders = prefs.getBool('enable_meal_reminders') ?? true;
      _enableWaterReminders = prefs.getBool('enable_water_reminders') ?? true;
      _enableExerciseReminders = prefs.getBool('enable_exercise_reminders') ?? true;
      _enableGroceryReminders = prefs.getBool('enable_grocery_reminders') ?? true;
      _isLoading = false;
    });
  }

  /// 📊 Load số lượng notifications đang chờ
  Future<void> _loadPendingNotifications() async {
    final pending = await _notificationService.getPendingNotifications();
    setState(() {
      _pendingNotifications = pending.length;
    });
  }

  /// 💾 Lưu cài đặt
  Future<void> _saveSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  /// 🔔 Cập nhật meal reminders
  Future<void> _updateMealReminders(bool value) async {
    setState(() => _enableMealReminders = value);
    await _saveSetting('enable_meal_reminders', value);
    
    if (value) {
      await _notificationService.scheduleMealReminders();
      _showSnackBar('✅ Đã bật nhắc nhở bữa ăn');
    } else {
      await _notificationService.cancelMealReminders();
      _showSnackBar('❌ Đã tắt nhắc nhở bữa ăn');
    }
    
    _loadPendingNotifications();
  }

  /// 💧 Cập nhật water reminders
  Future<void> _updateWaterReminders(bool value) async {
    setState(() => _enableWaterReminders = value);
    await _saveSetting('enable_water_reminders', value);
    
    if (value) {
      await _notificationService.scheduleWaterReminders();
      _showSnackBar('✅ Đã bật nhắc nhở uống nước');
    } else {
      await _notificationService.cancelWaterReminders();
      _showSnackBar('❌ Đã tắt nhắc nhở uống nước');
    }
    
    _loadPendingNotifications();
  }

  /// 🏃‍♂️ Cập nhật exercise reminders
  Future<void> _updateExerciseReminders(bool value) async {
    setState(() => _enableExerciseReminders = value);
    await _saveSetting('enable_exercise_reminders', value);
    
    if (value) {
      await _notificationService.scheduleExerciseReminders();
      _showSnackBar('✅ Đã bật nhắc nhở tập thể dục');
    } else {
      await _notificationService.cancelExerciseReminders();
      _showSnackBar('❌ Đã tắt nhắc nhở tập thể dục');
    }
    
    _loadPendingNotifications();
  }

  /// 🛒 Cập nhật grocery reminders
  Future<void> _updateGroceryReminders(bool value) async {
    setState(() => _enableGroceryReminders = value);
    await _saveSetting('enable_grocery_reminders', value);
    
    if (value) {
      await _notificationService.scheduleGroceryReminders();
      _showSnackBar('✅ Đã bật nhắc nhở mua sắm');
    } else {
      await _notificationService.cancelGroceryReminders();
      _showSnackBar('❌ Đã tắt nhắc nhở mua sắm');
    }
    
    _loadPendingNotifications();
  }

  /// 📢 Hiển thị SnackBar
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: 2),
        backgroundColor: Colors.blue.shade600,
      ),
    );
  }

  /// 🧪 Test notification
  Future<void> _testNotification() async {
    await _notificationService.showInstantNotification(
      title: '🧪 Test Notification',
      body: 'Thông báo đang hoạt động bình thường!',
      payload: 'test',
    );
    _showSnackBar('🧪 Đã gửi test notification');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Cài đặt thông báo'),
          backgroundColor: Colors.blue.shade600,
          foregroundColor: Colors.white,
        ),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Cài đặt thông báo'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.notifications_active),
            onPressed: _testNotification,
            tooltip: 'Test notification',
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          // Header info
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.notifications,
                  size: 48,
                  color: Colors.blue.shade600,
                ),
                SizedBox(height: 8),
                Text(
                  'Quản lý thông báo',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Nhận nhắc nhở để duy trì thói quen tốt',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.blue.shade600,
                  ),
                ),
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade600,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$_pendingNotifications thông báo đã lên lịch',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          SizedBox(height: 24),

          // Meal reminders
          _buildNotificationTile(
            icon: Icons.restaurant,
            title: 'Nhắc nhở bữa ăn',
            subtitle: 'Sáng 7:00, Trưa 11:30, Tối 18:00',
            value: _enableMealReminders,
            onChanged: _updateMealReminders,
            color: Colors.orange,
          ),

          SizedBox(height: 16),

          // Water reminders
          _buildNotificationTile(
            icon: Icons.water_drop,
            title: 'Nhắc nhở uống nước',
            subtitle: 'Mỗi 2 tiếng từ 8:00 đến 20:00',
            value: _enableWaterReminders,
            onChanged: _updateWaterReminders,
            color: Colors.blue,
          ),

          SizedBox(height: 16),

          // Exercise reminders
          _buildNotificationTile(
            icon: Icons.fitness_center,
            title: 'Nhắc nhở tập thể dục',
            subtitle: 'Sáng 6:00 và Chiều 17:00',
            value: _enableExerciseReminders,
            onChanged: _updateExerciseReminders,
            color: Colors.green,
          ),

          SizedBox(height: 16),

          // Grocery reminders
          _buildNotificationTile(
            icon: Icons.shopping_cart,
            title: 'Nhắc nhở mua sắm',
            subtitle: 'Chủ nhật 9:00 hàng tuần',
            value: _enableGroceryReminders,
            onChanged: _updateGroceryReminders,
            color: Colors.purple,
          ),

          SizedBox(height: 32),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _testNotification,
                  icon: Icon(Icons.notifications_active),
                  label: Text('Test thông báo'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue.shade600,
                    side: BorderSide(color: Colors.blue.shade600),
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await _notificationService.cancelAllNotifications();
                    _loadPendingNotifications();
                    _showSnackBar('🗑️ Đã xóa tất cả thông báo');
                  },
                  icon: Icon(Icons.clear_all),
                  label: Text('Xóa tất cả'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 16),

          // Info text
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '💡 Mẹo: Thông báo sẽ giúp bạn duy trì thói quen ăn uống và tập luyện tốt. Bạn có thể bật/tắt từng loại thông báo theo nhu cầu.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 🎨 Build notification tile
  Widget _buildNotificationTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: color,
            size: 24,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade600,
          ),
        ),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeColor: color,
        ),
      ),
    );
  }
}
