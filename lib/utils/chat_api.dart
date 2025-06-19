import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class ChatMessage {
  String id; // Đã bỏ final để có thể thay đổi giá trị
  final String text;
  final bool isUser;
  final String timestamp;
  String chatId; // Đã bỏ final để có thể thay đổi giá trị

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
  String id; // Đã bỏ final để có thể thay đổi giá trị
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
  static const String authTokenKey = 'firebase_id_token';
  
  /// Lấy token xác thực từ SharedPreferences hoặc Firebase Auth
  static Future<String?> _getAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString(authTokenKey);
      
      // Nếu không có token hoặc token quá cũ, lấy token mới
      if (token == null) {
        // Lấy token mới từ Firebase nếu người dùng đã đăng nhập
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          token = await currentUser.getIdToken(true);
          // Lưu token mới
          await prefs.setString(authTokenKey, token ?? '');
        }
      }
      
      return token;
    } catch (e) {
      print('Lỗi khi lấy auth token: $e');
      return null;
    }
  }
  
  /// Lưu token xác thực vào SharedPreferences
  static Future<void> saveAuthToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(authTokenKey, token);
      print('Đã lưu auth token');
    } catch (e) {
      print('Lỗi khi lưu auth token: $e');
    }
  }

  /// Làm mới token xác thực nếu token hiện tại đã hết hạn
  static Future<String?> _refreshAuthToken() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        // Cần làm mới token
        final newToken = await currentUser.getIdToken(true);
        if (newToken != null && newToken.isNotEmpty) {
          // Lưu token mới
          await saveAuthToken(newToken);
          print('✅ Đã làm mới token xác thực');
          return newToken;
        }
      }
      return null;
    } catch (e) {
      print('❌ Lỗi khi làm mới token: $e');
      return null;
    }
  }
  
  /// Xử lý phản hồi API với khả năng làm mới token
  static Future<http.Response> _handleApiResponse({
    required Future<http.Response> Function() apiCall,
    required Future<http.Response> Function(String) retryWithToken,
  }) async {
    try {
      // Gọi API với token hiện tại
      final response = await apiCall();
      
      // Kiểm tra nếu token không hợp lệ hoặc hết hạn
      if (response.statusCode == 401 || response.statusCode == 403) {
        print('🔑 Token hết hạn hoặc không hợp lệ, đang làm mới...');
        final newToken = await _refreshAuthToken();
        
        if (newToken != null) {
          // Thử lại với token mới
          return await retryWithToken(newToken);
        }
      }
      
      return response;
    } catch (e) {
      print('❌ Lỗi khi xử lý API: $e');
      rethrow;
    }
  }

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
      // Lấy token xác thực
      final String? authToken = await _getAuthToken();
      
      // Chuẩn bị headers
      final Map<String, String> headers = {
        'Content-Type': 'application/json; charset=UTF-8',
      };
      
      // Thêm token vào header nếu có
      if (authToken != null && authToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $authToken';
        print('Đã thêm token xác thực vào request');
      } else {
        print('Không có token xác thực');
      }
      
      print('🔷 Gửi request đến $baseUrl/chat với message: ${message.substring(0, message.length > 20 ? 20 : message.length)}...');
      
      // Sử dụng hàm xử lý API với khả năng làm mới token
      final response = await _handleApiResponse(
        apiCall: () => http.post(
          Uri.parse('$baseUrl/chat'),
          headers: headers,
          body: jsonEncode({
            'message': message,
            'user_id': userId,
            'chat_id': chatId,
          }),
        ).timeout(const Duration(seconds: 90)),  // Tăng timeout lên 90 giây
        retryWithToken: (newToken) => http.post(
          Uri.parse('$baseUrl/chat'),
          headers: {
            'Content-Type': 'application/json; charset=UTF-8',
            'Authorization': 'Bearer $newToken',
          },
          body: jsonEncode({
            'message': message,
            'user_id': userId,
            'chat_id': chatId,
          }),
        ).timeout(const Duration(seconds: 90)),  // Tăng timeout lên 90 giây
      );

      print('🔷 Nhận response với status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        print('🔷 Response data: $data');
        
        final String botReply = data['reply'] ?? 'Không có phản hồi';
        final String serverChatId = data['chat_id'] ?? messageId;
        
        print('📩 Nhận phản hồi từ server với chat_id: $serverChatId');
        print('📩 Nội dung phản hồi: ${botReply.substring(0, botReply.length > 50 ? 50 : botReply.length)}...');
        
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
        print('❌ Lỗi khi gửi tin nhắn: ${response.statusCode}');
        print('📃 Nội dung phản hồi: ${response.body}');
        
        return {
          'reply': 'Xin lỗi, tôi không thể trả lời ngay bây giờ. Vui lòng thử lại sau.',
          'error': true,
          'error_code': response.statusCode,
          'error_message': response.body,
        };
      }
    } catch (e) {
      print('❌ Lỗi khi gửi tin nhắn: $e');
      
      return {
        'reply': 'Xin lỗi, có lỗi xảy ra: $e',
        'error': true,
        'error_message': e.toString(),
      };
    }
  }

  /// Lấy lịch sử chat từ server
  static Future<List<dynamic>> getChatHistory(String userId, {int limit = 20}) async {
    try {
      // Lấy token xác thực
      final String? authToken = await _getAuthToken();
      
      // Chuẩn bị headers
      final Map<String, String> headers = {};
      
      // Thêm token vào header nếu có
      if (authToken != null && authToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $authToken';
      }
      
      // Sử dụng hàm xử lý API với khả năng làm mới token
      final response = await _handleApiResponse(
        apiCall: () => http.get(
          Uri.parse('$baseUrl/chat/history?user_id=$userId&limit=$limit'),
          headers: headers,
        ).timeout(const Duration(seconds: 10)),
        retryWithToken: (newToken) => http.get(
          Uri.parse('$baseUrl/chat/history?user_id=$userId&limit=$limit'),
          headers: {'Authorization': 'Bearer $newToken'},
        ).timeout(const Duration(seconds: 10)),
      );

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
  
  /// Lấy lịch sử chat mới nhất từ Firebase và đồng bộ với local storage
  static Future<List<Map<String, dynamic>>> getLatestChatHistory(String userId) async {
    try {
      print('🔍 Lấy lịch sử chat từ Firebase cho người dùng: $userId');
      
      // Truy cập Firestore
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      
      // Truy vấn collection chat_history, lọc theo user_id
      final QuerySnapshot querySnapshot = await firestore
          .collection('chat_history')
          .where('user_id', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(20)
          .get();
      
      // Chuyển đổi kết quả thành danh sách
      final List<Map<String, dynamic>> history = querySnapshot.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            // Thêm id của document vào dữ liệu
            return {
              'id': doc.id,
              'user_message': data['user_message'] ?? '',
              'ai_reply': data['ai_reply'] ?? '',
              'timestamp': data['timestamp'] ?? DateTime.now().toIso8601String(),
            };
          })
          .toList();
      
      print('📥 Nhận được ${history.length} tin nhắn từ Firebase');
      
      if (history.isEmpty) {
        print('⚠️ Không có lịch sử chat từ Firebase');
        return [];
      }
      
      // Lấy cuộc trò chuyện local
      final List<ChatConversation> localConversations = await _getLocalConversations();
      
      // Đồng bộ dữ liệu từ Firebase vào local storage
      final Map<String, ChatConversation> conversationMap = {};
      
      // Tạo một map của các cuộc trò chuyện hiện tại
      for (final conv in localConversations) {
        if (conv.userId == userId) {
          conversationMap[conv.id] = conv;
        }
      }
      
      // Đồng bộ từng tin nhắn từ Firebase
      for (final item in history) {
        final String chatId = item['id'];
        final String userMessage = item['user_message'];
        final String aiReply = item['ai_reply'];
        final String timestamp = item['timestamp'];
        
        // Kiểm tra xem có cuộc trò chuyện nào đã có chatId này không
        bool foundConversation = false;
        
        // Tìm kiếm trong các cuộc trò chuyện hiện tại
        for (final conv in localConversations) {
          if (conv.userId != userId) continue;
          
          // Tìm kiếm tin nhắn có ID khớp
          bool foundMessage = false;
          for (final msg in conv.messages) {
            if (msg.chatId == chatId) {
              foundMessage = true;
              foundConversation = true;
              break;
            }
          }
          
          if (foundMessage) break;
        }
        
        // Nếu chưa có, tạo cuộc trò chuyện mới
        if (!foundConversation) {
          print('🆕 Tạo cuộc trò chuyện mới từ chatId: $chatId');
          
          final newConversation = ChatConversation(
            id: chatId,
            title: userMessage.length > 40 ? userMessage.substring(0, 37) + '...' : userMessage,
            createdAt: timestamp,
            userId: userId,
            messages: [
              // Thêm tin nhắn người dùng
              ChatMessage(
                id: const Uuid().v4(),
                text: userMessage,
                isUser: true,
                timestamp: timestamp,
                chatId: chatId,
              ),
              // Thêm phản hồi AI
              ChatMessage(
                id: const Uuid().v4(),
                text: aiReply,
                isUser: false,
                timestamp: timestamp,
                chatId: chatId,
              ),
            ],
          );
          
          // Thêm vào danh sách local
          localConversations.add(newConversation);
          print('✅ Đã thêm cuộc trò chuyện mới: $chatId');
        }
      }
      
      // Lưu lại vào local storage
      await _saveLocalConversations(localConversations);
      print('💾 Đã lưu ${localConversations.length} cuộc trò chuyện vào local storage');
      
      return history;
    } catch (e) {
      print('❌ Lỗi khi lấy lịch sử chat từ Firebase: $e');
      return [];
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
    
    print('🔍 Đang tìm cuộc trò chuyện hiện tại với ID: $currentId');
    
    // Lọc theo userId
    final List<ChatConversation> userConversations = conversations
        .where((conv) => conv.userId == userId)
        .toList();
    
    print('📊 Tìm thấy ${userConversations.length} cuộc trò chuyện của người dùng $userId');
    
    // Tìm cuộc trò chuyện hiện tại nếu có
    if (currentId != null && currentId.isNotEmpty) {
      final List<ChatConversation> existingConversation = userConversations
          .where((conv) => conv.id == currentId)
          .toList();
      
      if (existingConversation.isNotEmpty) {
        print('✅ Đã tìm thấy cuộc trò chuyện hiện tại với ID: $currentId');
        return existingConversation.first;
      } else {
        print('⚠️ Không tìm thấy cuộc trò chuyện với ID: $currentId');
        
        // Kiểm tra xem có tin nhắn nào có chatId trùng với currentId không
        for (final conversation in userConversations) {
          for (final message in conversation.messages) {
            if (message.chatId == currentId) {
              print('🔄 Tìm thấy tin nhắn có chatId = $currentId trong cuộc trò chuyện ${conversation.id}');
              print('🔄 Đồng bộ ID cuộc trò chuyện...');
              
              // Cập nhật ID cuộc trò chuyện để khớp với chatId từ server
              conversation.id = currentId;
              
              // Cập nhật tất cả tin nhắn để có cùng chatId
              for (var msg in conversation.messages) {
                msg.chatId = currentId;
              }
              
              // Lưu lại thay đổi
              await _saveLocalConversations(conversations);
              print('✅ Đã đồng bộ ID cuộc trò chuyện thành công');
              
              return conversation;
            }
          }
        }
      }
    }
    
    // Nếu không tìm thấy cuộc trò chuyện hiện tại nhưng có cuộc trò chuyện của người dùng, lấy cuộc trò chuyện mới nhất
    if (userConversations.isNotEmpty) {
      // Sắp xếp theo thời gian tạo giảm dần (mới nhất lên đầu)
      userConversations.sort((a, b) => 
          DateTime.parse(b.createdAt).compareTo(DateTime.parse(a.createdAt)));
      
      final newestConversation = userConversations.first;
      print('🔄 Sử dụng cuộc trò chuyện mới nhất: ${newestConversation.id}');
      
      // Lưu ID cuộc trò chuyện mới nhất
      await _saveCurrentConversationId(newestConversation.id);
      
      return newestConversation;
    }
    
    // Tạo cuộc trò chuyện mới nếu không tìm thấy
    final DateTime now = DateTime.now();
    final String chatId = 'chat_${now.millisecondsSinceEpoch}';
    
    print('🆕 Tạo cuộc trò chuyện mới với ID: $chatId');
    
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
    // Lưu lại ID cũ để kiểm tra sự thay đổi
    final String oldChatId = conversation.id;
    
    // Cập nhật danh sách tin nhắn
    conversation.messages.add(message);
    
    // Đảm bảo tất cả các tin nhắn trong cuộc hội thoại có cùng chatId
    if (conversation.messages.length > 1 && message.chatId != conversation.id) {
      print('⚠️ Phát hiện chatId không khớp: ${message.chatId} vs ${conversation.id}');
      print('✅ Đồng bộ hóa chatId cho tất cả tin nhắn trong cuộc hội thoại');
      // Dùng chatId từ server cho tất cả tin nhắn
      for (var msg in conversation.messages) {
        msg.chatId = message.chatId;
      }
      // Cập nhật ID của cuộc trò chuyện
      if (!message.isUser) { // Chỉ cập nhật khi là tin nhắn từ AI (đã có chatId từ server)
        conversation.id = message.chatId;
        // Cập nhật ID hiện tại
        _saveCurrentConversationId(message.chatId);
      }
    }
    
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
    final int index = conversations.indexWhere((c) => c.id == oldChatId);
    if (index >= 0) {
      conversations[index] = conversation;
    } else {
      conversations.add(conversation);
    }
    
    await _saveLocalConversations(conversations);
    print('✅ Đã lưu cuộc trò chuyện với ID: ${conversation.id}');
    
    // Thông báo nếu chatId đã thay đổi
    if (oldChatId != conversation.id) {
      print('🔄 ChatID đã thay đổi từ $oldChatId thành ${conversation.id}');
    }
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

  /// Stream để lắng nghe các tin nhắn chat mới từ Firestore
  static Stream<List<Map<String, dynamic>>> streamChatMessages(String userId) {
    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      
      // Tạo query lắng nghe collection chat_history, lọc theo user_id
      return firestore
          .collection('chat_history')
          .where('user_id', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(20)
          .snapshots()
          .map((snapshot) {
            // Chuyển đổi kết quả snapshot thành danh sách Map
            return snapshot.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return {
                'id': doc.id,
                'user_message': data['user_message'] ?? '',
                'ai_reply': data['ai_reply'] ?? '',
                'timestamp': data['timestamp'] ?? DateTime.now().toIso8601String(),
                'user_id': data['user_id'] ?? userId,
              };
            }).toList();
          });
    } catch (e) {
      print('❌ Lỗi khi tạo stream chat messages: $e');
      // Trả về stream rỗng trong trường hợp lỗi
      return Stream.value([]);
    }
  }
  
  /// Stream để lắng nghe một cuộc trò chuyện cụ thể
  static Stream<Map<String, dynamic>?> streamChatById(String chatId) {
    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      
      // Lắng nghe document cụ thể với ID là chatId
      return firestore
          .collection('chat_history')
          .doc(chatId)
          .snapshots()
          .map((snapshot) {
            if (snapshot.exists) {
              final data = snapshot.data() as Map<String, dynamic>;
              return {
                'id': snapshot.id,
                'user_message': data['user_message'] ?? '',
                'ai_reply': data['ai_reply'] ?? '',
                'timestamp': data['timestamp'] ?? DateTime.now().toIso8601String(),
                'user_id': data['user_id'] ?? '',
              };
            } else {
              return null;
            }
          });
    } catch (e) {
      print('❌ Lỗi khi tạo stream chat by ID: $e');
      // Trả về stream rỗng trong trường hợp lỗi
      return Stream.value(null);
    }
  }

  /// Phương thức public để lưu cuộc trò chuyện
  static Future<void> saveConversations(List<ChatConversation> conversations) async {
    await _saveLocalConversations(conversations);
  }
} 