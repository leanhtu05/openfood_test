import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final String timestamp;
  final String chatId;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    required this.chatId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'isUser': isUser,
      'timestamp': timestamp,
      'chatId': chatId,
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'],
      text: json['text'],
      isUser: json['isUser'],
      timestamp: json['timestamp'],
      chatId: json['chatId'],
    );
  }
}

class ChatConversation {
  final String id;
  String title;
  final String createdAt;
  final String userId;
  final List<ChatMessage> messages;

  ChatConversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.userId,
    required this.messages,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'createdAt': createdAt,
      'userId': userId,
      'messages': messages.map((m) => m.toJson()).toList(),
    };
  }

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    return ChatConversation(
      id: json['id'],
      title: json['title'],
      createdAt: json['createdAt'],
      userId: json['userId'],
      messages: (json['messages'] as List)
          .map((m) => ChatMessage.fromJson(m))
          .toList(),
    );
  }
}

class ChatApi {
  static const String baseUrl = 'https://backend-openfood.onrender.com';
  static const String localStorageKey = 'chat_conversations';
  static const String currentConversationKey = 'current_conversation_id';
  
  /// Gửi tin nhắn đến server và nhận phản hồi
  static Future<Map<String, dynamic>> sendMessage(String message, String userId) async {
    final String messageId = const Uuid().v4();
    final DateTime now = DateTime.now();
    final String timestamp = now.toIso8601String();
    
    // Lấy hoặc tạo cuộc trò chuyện hiện tại
    final currentConversation = await _getCurrentConversation(userId);
    final String chatId = currentConversation.id;
    
    // Thêm tin nhắn người dùng vào cuộc trò chuyện cục bộ
    final userMessage = ChatMessage(
      id: messageId,
      text: message,
      isUser: true,
      timestamp: timestamp,
      chatId: chatId,
    );
    
    await _addMessageToLocalConversation(currentConversation, userMessage);
    
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/chat'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({
          'message': message,
          'user_id': userId,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final String botReply = data['reply'] ?? 'Không có phản hồi';
        final String serverChatId = data['chat_id'] ?? messageId;
        
        // Thêm phản hồi bot vào cuộc trò chuyện cục bộ
        final botMessage = ChatMessage(
          id: const Uuid().v4(),
          text: botReply,
          isUser: false,
          timestamp: DateTime.now().toIso8601String(),
          chatId: serverChatId,
        );
        
        await _addMessageToLocalConversation(currentConversation, botMessage);
        
        return {
          'reply': botReply,
          'chat_id': serverChatId,
          'error': false,
        };
      } else {
        final String errorMessage = 'Lỗi máy chủ (${response.statusCode})';
        
        // Thêm tin nhắn lỗi vào cuộc trò chuyện cục bộ
        final errorBotMessage = ChatMessage(
          id: const Uuid().v4(),
          text: 'Xin lỗi, có lỗi xảy ra khi kết nối với máy chủ. Vui lòng thử lại sau.',
          isUser: false,
          timestamp: DateTime.now().toIso8601String(),
          chatId: chatId,
        );
        
        await _addMessageToLocalConversation(currentConversation, errorBotMessage);
        
        print('Lỗi API: ${response.statusCode} - ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}...');
        
        return {
          'reply': 'Xin lỗi, có lỗi xảy ra khi kết nối với máy chủ. Vui lòng thử lại sau.',
          'error': true
        };
      }
    } catch (e) {
      print('Lỗi khi gửi tin nhắn: $e');
      
      // Thêm tin nhắn lỗi vào cuộc trò chuyện cục bộ
      final errorBotMessage = ChatMessage(
        id: const Uuid().v4(),
        text: 'Không thể kết nối đến máy chủ. Vui lòng kiểm tra kết nối mạng và thử lại.',
        isUser: false,
        timestamp: DateTime.now().toIso8601String(),
        chatId: chatId,
      );
      
      await _addMessageToLocalConversation(currentConversation, errorBotMessage);
      
      return {
        'reply': 'Không thể kết nối đến máy chủ. Vui lòng kiểm tra kết nối mạng và thử lại.',
        'error': true
      };
    }
  }

  /// Lấy lịch sử chat từ server
  static Future<List<dynamic>> getChatHistory(String userId, {int limit = 20}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/chat/history?user_id=$userId&limit=$limit'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['history'] ?? [];
      } else {
        print('Lỗi API lịch sử: ${response.statusCode} - ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}...');
        // Nếu server lỗi, lấy lịch sử từ local storage
        return await _getLocalHistory(userId);
      }
    } catch (e) {
      print('Lỗi khi lấy lịch sử: $e');
      // Nếu có lỗi kết nối, lấy lịch sử từ local storage
      return await _getLocalHistory(userId);
    }
  }
  
  /// Lấy cuộc hội thoại mới nhất của người dùng
  static Future<List<Map<String, dynamic>>> getLatestChatHistory(String userId) async {
    try {
      // Lấy tối đa 10 cuộc hội thoại gần nhất
      final history = await getChatHistory(userId, limit: 10);
      
      if (history.isEmpty) {
        return [];
      }
      
      // Sắp xếp theo thời gian giảm dần (mới nhất lên đầu)
      history.sort((a, b) {
        final DateTime timeA = DateTime.parse(a['timestamp']);
        final DateTime timeB = DateTime.parse(b['timestamp']);
        return timeB.compareTo(timeA);
      });
      
      // Nhóm theo cuộc hội thoại
      final Map<String, List<Map<String, dynamic>>> conversations = {};
      
      for (final item in history) {
        final String message = item['user_message'];
        final String reply = item['ai_reply'];
        final String timestamp = item['timestamp'];
        final String id = item['id'];
        
        // Sử dụng date (không bao gồm giờ) làm khóa nhóm cuộc hội thoại
        final String conversationKey = timestamp.split('T')[0];
        
        if (!conversations.containsKey(conversationKey)) {
          conversations[conversationKey] = [];
        }
        
        conversations[conversationKey]!.add({
          'user_message': message,
          'ai_reply': reply,
          'timestamp': timestamp,
          'id': id,
        });
      }
      
      // Lấy cuộc hội thoại mới nhất (nhóm đầu tiên)
      if (conversations.isNotEmpty) {
        final latestKey = conversations.keys.toList()..sort((a, b) => b.compareTo(a));
        return conversations[latestKey.first] ?? [];
      }
      
      return [];
    } catch (e) {
      print('Lỗi khi lấy cuộc hội thoại mới nhất: $e');
      
      // Nếu có lỗi, thử lấy từ local storage
      final List<ChatConversation> localConversations = await _getLocalConversations();
      
      if (localConversations.isEmpty) {
        return [];
      }
      
      // Sắp xếp theo thời gian tạo giảm dần
      localConversations.sort((a, b) => 
        DateTime.parse(b.createdAt).compareTo(DateTime.parse(a.createdAt)));
      
      // Lấy cuộc hội thoại mới nhất
      final latestConversation = localConversations.first;
      
      // Chuyển đổi định dạng
      final List<Map<String, dynamic>> result = [];
      
      for (int i = 0; i < latestConversation.messages.length; i += 2) {
        if (i + 1 < latestConversation.messages.length) {
          final userMsg = latestConversation.messages[i];
          final botMsg = latestConversation.messages[i + 1];
          
          result.add({
            'user_message': userMsg.text,
            'ai_reply': botMsg.text,
            'timestamp': userMsg.timestamp,
            'id': userMsg.id,
          });
        }
      }
      
      return result;
    }
  }
  
  /// Lưu cuộc trò chuyện hiện tại
  static Future<void> _saveCurrentConversationId(String conversationId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(currentConversationKey, conversationId);
  }
  
  /// Lấy ID cuộc trò chuyện hiện tại
  static Future<String?> getCurrentConversationId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(currentConversationKey);
  }
  
  /// Lấy hoặc tạo cuộc trò chuyện hiện tại
  static Future<ChatConversation> _getCurrentConversation(String userId) async {
    final String? currentId = await getCurrentConversationId();
    final List<ChatConversation> conversations = await _getLocalConversations();
    
    // Tìm cuộc trò chuyện hiện tại nếu có
    if (currentId != null) {
      final existingConversation = conversations
          .where((conv) => conv.id == currentId && conv.userId == userId)
          .toList();
      
      if (existingConversation.isNotEmpty) {
        return existingConversation.first;
      }
    }
    
    // Tạo cuộc trò chuyện mới nếu không tìm thấy
    final DateTime now = DateTime.now();
    final String chatId = 'chat_${now.millisecondsSinceEpoch}';
    
    final newConversation = ChatConversation(
      id: chatId,
      title: 'Cuộc trò chuyện mới',
      createdAt: now.toIso8601String(),
      userId: userId,
      messages: [],
    );
    
    // Lưu ID cuộc trò chuyện mới
    await _saveCurrentConversationId(chatId);
    
    // Thêm vào danh sách và lưu
    conversations.add(newConversation);
    await _saveLocalConversations(conversations);
    
    return newConversation;
  }
  
  /// Tạo cuộc trò chuyện mới
  static Future<ChatConversation> createNewConversation(String userId, {String? title}) async {
    final DateTime now = DateTime.now();
    final String chatId = 'chat_${now.millisecondsSinceEpoch}';
    
    final newConversation = ChatConversation(
      id: chatId,
      title: title ?? 'Cuộc trò chuyện mới',
      createdAt: now.toIso8601String(),
      userId: userId,
      messages: [],
    );
    
    // Lưu ID cuộc trò chuyện mới
    await _saveCurrentConversationId(chatId);
    
    // Thêm vào danh sách và lưu
    final conversations = await _getLocalConversations();
    conversations.add(newConversation);
    await _saveLocalConversations(conversations);
    
    return newConversation;
  }
  
  /// Chọn cuộc trò chuyện
  static Future<void> selectConversation(String conversationId) async {
    await _saveCurrentConversationId(conversationId);
  }
  
  /// Thêm tin nhắn vào cuộc trò chuyện cục bộ
  static Future<void> _addMessageToLocalConversation(
    ChatConversation conversation,
    ChatMessage message,
  ) async {
    // Cập nhật danh sách tin nhắn
    conversation.messages.add(message);
    
    // Cập nhật tiêu đề cuộc trò chuyện nếu là tin nhắn đầu tiên và là tin nhắn người dùng
    if (conversation.messages.length == 1 && message.isUser) {
      final String newTitle = message.text.length > 40 
          ? message.text.substring(0, 37) + '...'
          : message.text;
      
      conversation.title = newTitle;
    }
    
    // Lưu lại vào storage
    final List<ChatConversation> conversations = await _getLocalConversations();
    
    // Tìm và cập nhật cuộc trò chuyện
    final int index = conversations.indexWhere((c) => c.id == conversation.id);
    if (index >= 0) {
      conversations[index] = conversation;
    } else {
      conversations.add(conversation);
    }
    
    await _saveLocalConversations(conversations);
  }
  
  /// Lấy tất cả cuộc trò chuyện từ local storage
  static Future<List<ChatConversation>> _getLocalConversations() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(localStorageKey);
    
    if (data == null) {
      return [];
    }
    
    try {
      final List<dynamic> jsonList = jsonDecode(data);
      return jsonList.map((json) => ChatConversation.fromJson(json)).toList();
    } catch (e) {
      print('Lỗi khi đọc lịch sử chat từ local storage: $e');
      return [];
    }
  }
  
  /// Lưu tất cả cuộc trò chuyện vào local storage
  static Future<void> _saveLocalConversations(List<ChatConversation> conversations) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = conversations.map((conv) => conv.toJson()).toList();
    await prefs.setString(localStorageKey, jsonEncode(jsonList));
  }
  
  /// Lấy lịch sử chat từ local storage theo định dạng tương thích với API
  static Future<List<dynamic>> _getLocalHistory(String userId) async {
    final List<ChatConversation> conversations = await _getLocalConversations();
    
    if (conversations.isEmpty) {
      return [];
    }
    
    // Lọc cuộc hội thoại theo userId
    final userConversations = conversations
        .where((conv) => conv.userId == userId)
        .toList();
    
    if (userConversations.isEmpty) {
      return [];
    }
    
    // Chuyển đổi định dạng
    final List<Map<String, dynamic>> result = [];
    
    for (final conversation in userConversations) {
      for (int i = 0; i < conversation.messages.length; i += 2) {
        if (i + 1 < conversation.messages.length) {
          final userMsg = conversation.messages[i];
          final botMsg = conversation.messages[i + 1];
          
          result.add({
            'user_message': userMsg.text,
            'ai_reply': botMsg.text,
            'timestamp': userMsg.timestamp,
            'id': userMsg.id,
          });
        }
      }
    }
    
    return result;
  }
  
  /// Lấy tất cả cuộc trò chuyện
  static Future<List<ChatConversation>> getAllConversations(String userId) async {
    final List<ChatConversation> conversations = await _getLocalConversations();
    
    // Lọc theo userId
    return conversations
        .where((conv) => conv.userId == userId)
        .toList()
        // Sắp xếp theo thời gian tạo giảm dần (mới nhất lên đầu)
        ..sort((a, b) => 
            DateTime.parse(b.createdAt).compareTo(DateTime.parse(a.createdAt)));
  }
  
  /// Xóa cuộc trò chuyện
  static Future<void> deleteConversation(String conversationId) async {
    final List<ChatConversation> conversations = await _getLocalConversations();
    
    // Lọc bỏ cuộc trò chuyện cần xóa
    final filteredConversations = conversations
        .where((conv) => conv.id != conversationId)
        .toList();
    
    await _saveLocalConversations(filteredConversations);
    
    // Nếu xóa cuộc trò chuyện hiện tại, tạo cuộc trò chuyện mới
    final currentId = await getCurrentConversationId();
    if (currentId == conversationId && filteredConversations.isNotEmpty) {
      await _saveCurrentConversationId(filteredConversations.first.id);
    }
  }
  
  /// Kiểm tra kết nối đến server
  static Future<bool> checkConnection() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api-status'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      print('Lỗi khi kiểm tra kết nối: $e');
      return false;
    }
  }
} 