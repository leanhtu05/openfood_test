import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  /// 🔔 Khởi tạo notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Khởi tạo timezone
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));

    // Cài đặt cho Android
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // Cài đặt cho iOS
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _isInitialized = true;
    print('✅ Notification service initialized');
  }

  /// 📱 Xử lý khi người dùng nhấn vào notification
  void _onNotificationTapped(NotificationResponse response) {
    print('🔔 Notification tapped: ${response.payload}');
    
    // Xử lý navigation dựa trên payload
    if (response.payload != null) {
      _handleNotificationNavigation(response.payload!);
    }
  }

  /// 🧭 Xử lý navigation từ notification
  void _handleNotificationNavigation(String payload) {
    // TODO: Implement navigation logic
    switch (payload) {
      case 'meal_reminder':
        // Navigate to meal planning screen
        break;
      case 'water_reminder':
        // Navigate to water tracking screen
        break;
      case 'exercise_reminder':
        // Navigate to exercise screen
        break;
      case 'grocery_reminder':
        // Navigate to grocery list screen
        break;
    }
  }

  /// 🔐 Yêu cầu quyền notification
  Future<bool> requestPermissions() async {
    if (await Permission.notification.isGranted) {
      return true;
    }

    final status = await Permission.notification.request();
    return status == PermissionStatus.granted;
  }

  /// ⏰ Lên lịch thông báo nhắc nhở bữa ăn
  Future<void> scheduleMealReminders() async {
    if (!await requestPermissions()) return;

    final prefs = await SharedPreferences.getInstance();
    final enableMealReminders = prefs.getBool('enable_meal_reminders') ?? true;
    
    if (!enableMealReminders) return;

    // Hủy các notification cũ
    await cancelMealReminders();

    // Lên lịch cho bữa sáng (7:00)
    await _scheduleRepeatingNotification(
      id: 1,
      title: '🌅 Chào buổi sáng!',
      body: 'Đã đến giờ ăn sáng. Hãy tạo kế hoạch bữa ăn ngon miệng nhé!',
      hour: 7,
      minute: 0,
      payload: 'meal_reminder',
    );

    // Lên lịch cho bữa trưa (11:30)
    await _scheduleRepeatingNotification(
      id: 2,
      title: '🍽️ Giờ ăn trưa đến rồi!',
      body: 'Đừng quên ăn trưa đầy đủ để có năng lượng cho buổi chiều nhé!',
      hour: 11,
      minute: 30,
      payload: 'meal_reminder',
    );

    // Lên lịch cho bữa tối (18:00)
    await _scheduleRepeatingNotification(
      id: 3,
      title: '🌆 Bữa tối đã sẵn sàng!',
      body: 'Hãy chuẩn bị một bữa tối ngon miệng và bổ dưỡng!',
      hour: 18,
      minute: 0,
      payload: 'meal_reminder',
    );

    print('✅ Meal reminders scheduled');
  }

  /// 💧 Lên lịch thông báo nhắc uống nước
  Future<void> scheduleWaterReminders() async {
    if (!await requestPermissions()) return;

    final prefs = await SharedPreferences.getInstance();
    final enableWaterReminders = prefs.getBool('enable_water_reminders') ?? true;
    
    if (!enableWaterReminders) return;

    // Hủy các notification cũ
    await cancelWaterReminders();

    // Lên lịch nhắc uống nước mỗi 2 tiếng từ 8:00 đến 20:00
    for (int hour = 8; hour <= 20; hour += 2) {
      await _scheduleRepeatingNotification(
        id: 100 + hour, // ID từ 108, 110, 112...
        title: '💧 Đã đến giờ uống nước!',
        body: 'Hãy uống một ly nước để giữ cơ thể luôn khỏe mạnh nhé!',
        hour: hour,
        minute: 0,
        payload: 'water_reminder',
      );
    }

    print('✅ Water reminders scheduled');
  }

  /// 🏃‍♂️ Lên lịch thông báo nhắc tập thể dục
  Future<void> scheduleExerciseReminders() async {
    if (!await requestPermissions()) return;

    final prefs = await SharedPreferences.getInstance();
    final enableExerciseReminders = prefs.getBool('enable_exercise_reminders') ?? true;
    
    if (!enableExerciseReminders) return;

    // Hủy các notification cũ
    await cancelExerciseReminders();

    // Lên lịch nhắc tập thể dục (6:00 sáng và 17:00 chiều)
    await _scheduleRepeatingNotification(
      id: 201,
      title: '🏃‍♂️ Thời gian tập thể dục!',
      body: 'Hãy dành 30 phút để tập thể dục và giữ dáng nhé!',
      hour: 6,
      minute: 0,
      payload: 'exercise_reminder',
    );

    await _scheduleRepeatingNotification(
      id: 202,
      title: '🏋️‍♀️ Tập thể dục buổi chiều!',
      body: 'Sau một ngày làm việc, hãy thư giãn với bài tập nhẹ nhàng!',
      hour: 17,
      minute: 0,
      payload: 'exercise_reminder',
    );

    print('✅ Exercise reminders scheduled');
  }

  /// 🛒 Lên lịch thông báo nhắc mua sắm
  Future<void> scheduleGroceryReminders() async {
    if (!await requestPermissions()) return;

    final prefs = await SharedPreferences.getInstance();
    final enableGroceryReminders = prefs.getBool('enable_grocery_reminders') ?? true;
    
    if (!enableGroceryReminders) return;

    // Hủy các notification cũ
    await cancelGroceryReminders();

    // Lên lịch nhắc mua sắm (Chủ nhật 9:00)
    await _scheduleWeeklyNotification(
      id: 301,
      title: '🛒 Đi chợ thôi!',
      body: 'Hãy kiểm tra grocery list và đi mua sắm cho tuần mới nhé!',
      weekday: DateTime.sunday,
      hour: 9,
      minute: 0,
      payload: 'grocery_reminder',
    );

    print('✅ Grocery reminders scheduled');
  }

  /// ⏰ Lên lịch notification lặp lại hàng ngày
  Future<void> _scheduleRepeatingNotification({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    String? payload,
  }) async {
    await _notifications.zonedSchedule(
      id,
      title,
      body,
      _nextInstanceOfTime(hour, minute),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminders',
          'Daily Reminders',
          channelDescription: 'Nhắc nhở hàng ngày cho OpenFood',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: payload,
    );
  }

  /// 📅 Lên lịch notification hàng tuần
  Future<void> _scheduleWeeklyNotification({
    required int id,
    required String title,
    required String body,
    required int weekday,
    required int hour,
    required int minute,
    String? payload,
  }) async {
    await _notifications.zonedSchedule(
      id,
      title,
      body,
      _nextInstanceOfWeekday(weekday, hour, minute),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'weekly_reminders',
          'Weekly Reminders',
          channelDescription: 'Nhắc nhở hàng tuần cho OpenFood',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: payload,
    );
  }

  /// 🕐 Tính thời gian tiếp theo cho giờ:phút
  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    
    return scheduledDate;
  }

  /// 📅 Tính thời gian tiếp theo cho ngày trong tuần
  tz.TZDateTime _nextInstanceOfWeekday(int weekday, int hour, int minute) {
    tz.TZDateTime scheduledDate = _nextInstanceOfTime(hour, minute);
    
    while (scheduledDate.weekday != weekday) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    
    return scheduledDate;
  }

  /// ❌ Hủy tất cả notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
    print('✅ All notifications cancelled');
  }

  /// ❌ Hủy meal reminders
  Future<void> cancelMealReminders() async {
    await _notifications.cancel(1); // Breakfast
    await _notifications.cancel(2); // Lunch  
    await _notifications.cancel(3); // Dinner
  }

  /// ❌ Hủy water reminders
  Future<void> cancelWaterReminders() async {
    for (int hour = 8; hour <= 20; hour += 2) {
      await _notifications.cancel(100 + hour);
    }
  }

  /// ❌ Hủy exercise reminders
  Future<void> cancelExerciseReminders() async {
    await _notifications.cancel(201);
    await _notifications.cancel(202);
  }

  /// ❌ Hủy grocery reminders
  Future<void> cancelGroceryReminders() async {
    await _notifications.cancel(301);
  }

  /// 📊 Lấy danh sách pending notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }

  /// 🔔 Hiển thị notification ngay lập tức
  Future<void> showInstantNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'instant_notifications',
          'Instant Notifications',
          channelDescription: 'Thông báo tức thì',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );
  }
}
