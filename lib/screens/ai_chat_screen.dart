import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../utils/chat_api.dart';

class AIChatScreen extends StatefulWidget {
  const AIChatScreen({Key? key}) : super(key: key);

  @override
  _AIChatScreenState createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  List<ChatConversation> _chatHistories = [];
  ChatConversation? _currentChat;
  bool _isComposing = false;
  bool _isTyping = false;
  bool _isLoadingHistory = false;
  bool _initialHistoryLoaded = false;
  bool _showSidebar = false;
  String _userId = '';
  
  // Thêm biến để giữ các subscription
  StreamSubscription? _chatStreamSubscription;
  StreamSubscription? _currentChatStreamSubscription;
  
  // Thêm timer để tự động tắt loading nếu quá lâu không nhận được phản hồi
  Timer? _loadingTimeoutTimer;
  
  @override
  void initState() {
    super.initState();
    
    // Đăng ký observer để biết khi app trở lại foreground
    WidgetsBinding.instance.addObserver(this);
    
    _initUserId().then((_) {
      // Tải lịch sử chat
      _loadAllChatHistories();
      
      // Lắng nghe stream tin nhắn mới
      _subscribeToMessagesStream();
    });
  }
  
  @override
  void dispose() {
    // Hủy timer nếu còn hoạt động
    _loadingTimeoutTimer?.cancel();
    
    // Hủy các subscription để tránh memory leak
    _chatStreamSubscription?.cancel();
    _currentChatStreamSubscription?.cancel();
    
    // Hủy đăng ký observer
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  // Đăng ký stream lắng nghe tin nhắn mới
  void _subscribeToMessagesStream() {
    if (_userId.isEmpty) return;
    
    // Hủy subscription cũ nếu có
    _chatStreamSubscription?.cancel();
    
    // Đăng ký stream mới
    _chatStreamSubscription = ChatApi.streamChatMessages(_userId).listen(
      (messages) {
        if (messages.isEmpty) return;
        
        print('📥 Nhận được ${messages.length} tin nhắn mới từ stream');
        
        // Xử lý tin nhắn mới và cập nhật UI
        _processChatUpdates(messages);
      },
      onError: (error) {
        print('❌ Lỗi khi lắng nghe stream tin nhắn: $error');
      }
    );
  }
  
  // Đăng ký stream lắng nghe cập nhật cho cuộc trò chuyện hiện tại
  void _subscribeToCurrentChatStream() {
    if (_currentChat == null) return;
    
    // Hủy subscription cũ nếu có
    _currentChatStreamSubscription?.cancel();
    
    // Lấy ID cuộc trò chuyện hiện tại
    final String chatId = _currentChat!.id;
    print('🔄 Đăng ký stream cho cuộc trò chuyện: $chatId');
    
    // Đăng ký stream mới
    _currentChatStreamSubscription = ChatApi.streamChatById(chatId).listen(
      (chatData) {
        if (chatData == null) return;
        
        print('📥 Nhận được cập nhật cho cuộc trò chuyện: ${chatData['id']}');
        
        // Đảm bảo trạng thái đang nhập kết thúc
        if (_isTyping) {
          setState(() {
            _isTyping = false;
          });
        }
        
        // Cập nhật UI với tin nhắn mới nhất
        _updateCurrentChatFromStream(chatData);
      },
      onError: (error) {
        print('❌ Lỗi khi lắng nghe stream cuộc trò chuyện: $error');
        // Kết thúc trạng thái đang nhập nếu có lỗi
        if (_isTyping) {
          setState(() {
            _isTyping = false;
          });
        }
      }
    );
  }
  
  // Xử lý cập nhật từ stream
  void _processChatUpdates(List<Map<String, dynamic>> messages) async {
    try {
      // Lấy lại tất cả cuộc trò chuyện hiện có
      final List<ChatConversation> conversations = await ChatApi.getAllConversations(_userId);
      
      // Tạo một map để theo dõi những cuộc trò chuyện đã được xử lý
      final Map<String, bool> processedChats = {};
      
      // Xử lý từng tin nhắn từ stream
      for (final messageData in messages) {
        final String chatId = messageData['id'];
        
        // Bỏ qua nếu đã xử lý chat này rồi
        if (processedChats[chatId] == true) continue;
        processedChats[chatId] = true;
        
        final String userMessage = messageData['user_message'];
        final String aiReply = messageData['ai_reply'];
        final String timestamp = messageData['timestamp'];
        
        // Tìm cuộc trò chuyện hiện có với ID này
        final existingChatIndex = conversations.indexWhere((chat) => chat.id == chatId);
        
        if (existingChatIndex >= 0) {
          // Cuộc trò chuyện đã tồn tại, kiểm tra xem có tin nhắn mới không
          final existingChat = conversations[existingChatIndex];
          
          // Kiểm tra xem tin nhắn này đã có trong danh sách chưa
          bool messageExists = false;
          for (final msg in existingChat.messages) {
            if (msg.chatId == chatId && 
                ((msg.isUser && msg.text == userMessage) || 
                (!msg.isUser && msg.text == aiReply))) {
              messageExists = true;
              break;
            }
          }
          
          // Nếu chưa có, thêm tin nhắn mới
          if (!messageExists) {
            // Thêm tin nhắn người dùng nếu chưa có
            existingChat.messages.add(ChatMessage(
              id: const Uuid().v4(),
              text: userMessage,
              isUser: true,
              timestamp: timestamp,
              chatId: chatId,
            ));
            
            // Thêm phản hồi AI
            existingChat.messages.add(ChatMessage(
              id: const Uuid().v4(),
              text: aiReply,
              isUser: false,
              timestamp: timestamp,
              chatId: chatId,
            ));
            
            // Cập nhật cuộc trò chuyện
            conversations[existingChatIndex] = existingChat;
          }
        } else {
          // Tạo cuộc trò chuyện mới
          final newConversation = ChatConversation(
            id: chatId,
            title: userMessage.length > 40 ? userMessage.substring(0, 37) + '...' : userMessage,
            createdAt: timestamp,
            userId: _userId,
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
          
          // Thêm vào danh sách
          conversations.add(newConversation);
        }
      }
      
      // Lưu lại cuộc trò chuyện đã cập nhật
      await ChatApi.saveConversations(conversations);
      
      // Cập nhật danh sách cuộc trò chuyện
      setState(() {
        _chatHistories = conversations;
        
        // Nếu đang có cuộc trò chuyện hiện tại, cập nhật nó
        if (_currentChat != null) {
          final updatedCurrentChat = conversations.firstWhere(
            (chat) => chat.id == _currentChat!.id,
            orElse: () => _currentChat!,
          );
          
          _currentChat = updatedCurrentChat;
          _messages.clear();
          _messages.addAll(_currentChat!.messages);
          
          // Cuộn xuống để hiển thị tin nhắn mới nhất
          Future.delayed(const Duration(milliseconds: 100), () {
            _scrollToBottom();
          });
          
          // Kết thúc trạng thái đang nhập nếu đã nhận được phản hồi
          if (_isTyping && _messages.isNotEmpty && !_messages.last.isUser) {
            _isTyping = false;
          }
        }
      });
    } catch (e) {
      print('❌ Lỗi khi xử lý cập nhật từ stream: $e');
    }
  }
  
  // Cập nhật cuộc trò chuyện hiện tại từ stream
  void _updateCurrentChatFromStream(Map<String, dynamic> chatData) {
    if (_currentChat == null || _currentChat!.id != chatData['id']) return;
    
    final String userMessage = chatData['user_message'];
    final String aiReply = chatData['ai_reply'];
    final String timestamp = chatData['timestamp'];
    final String chatId = chatData['id'];
    
    // Nếu có phản hồi AI, đảm bảo tắt trạng thái loading
    if (aiReply.isNotEmpty) {
      if (_isTyping) {
        setState(() {
          _isTyping = false;
        });
      }
    }
    
    // Kiểm tra xem đã có tin nhắn này chưa
    bool hasUserMessage = false;
    bool hasAiReply = false;
    
    for (final message in _messages) {
      if (message.isUser && message.text == userMessage) {
        hasUserMessage = true;
      } else if (!message.isUser && message.text == aiReply) {
        hasAiReply = true;
      }
    }
    
    // Nếu chưa có tin nhắn, thêm vào
    if (!hasUserMessage || !hasAiReply) {
      setState(() {
        // Đảm bảo có tin nhắn người dùng
        if (!hasUserMessage) {
          _messages.add(ChatMessage(
            id: const Uuid().v4(),
            text: userMessage,
            isUser: true,
            timestamp: timestamp,
            chatId: chatId,
          ));
        }
        
        // Đảm bảo có tin nhắn AI
        if (!hasAiReply) {
          _messages.add(ChatMessage(
            id: const Uuid().v4(),
            text: aiReply,
            isUser: false,
            timestamp: timestamp,
            chatId: chatId,
          ));
        }
        
        // Kết thúc trạng thái đang nhập
        _isTyping = false;
        
        // Lưu lại thay đổi vào cuộc trò chuyện hiện tại và toàn bộ danh sách
        if (_currentChat != null) {
          // Tạo một cuộc trò chuyện mới với các tin nhắn hiện tại
          final updatedChat = ChatConversation(
            id: _currentChat!.id,
            title: _currentChat!.title,
            createdAt: _currentChat!.createdAt,
            userId: _currentChat!.userId,
            messages: List.from(_messages),
          );
          
          // Cập nhật cuộc trò chuyện hiện tại
          _currentChat = updatedChat;
          
          // Cập nhật trong danh sách cuộc trò chuyện
          final int index = _chatHistories.indexWhere((c) => c.id == updatedChat.id);
          if (index >= 0) {
            _chatHistories[index] = updatedChat;
            // Lưu vào local storage
            ChatApi.saveConversations(_chatHistories);
          }
        }
      });
      
      // Cuộn xuống để hiển thị tin nhắn mới nhất
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollToBottom();
      });
    }
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Khi ứng dụng chuyển sang trạng thái resumed (trở lại foreground)
    if (state == AppLifecycleState.resumed) {
      // Tải lại lịch sử chat nhưng giữ nguyên cuộc trò chuyện hiện tại
      if (_userId.isNotEmpty) {
        _refreshChatHistories();
        
        // Đăng ký lại stream
        _subscribeToMessagesStream();
      }
    }
  }
  
  Future<void> _initUserId() async {
    final prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('chat_user_id');
    
    if (userId == null) {
      // Tạo userId mới nếu chưa có
      userId = const Uuid().v4();
      await prefs.setString('chat_user_id', userId);
    }
    
    setState(() {
      _userId = userId!;
    });
    
    print('Đã khởi tạo user ID: $_userId');
  }
  
  Future<void> _loadAllChatHistories() async {
    if (_userId.isEmpty) return;
    
    setState(() {
      _isLoadingHistory = true;
    });
    
    try {
      // Lấy tất cả cuộc trò chuyện từ local storage
      final conversations = await ChatApi.getAllConversations(_userId);
      
      setState(() {
        _chatHistories = conversations;
        
        if (conversations.isEmpty) {
          // Nếu không có lịch sử, tạo cuộc trò chuyện mới
          _startNewChat();
        } else {
          // Lấy cuộc trò chuyện hiện tại
          _loadCurrentChat();
        }
      });
      
      _initialHistoryLoaded = true;
    } catch (e) {
      print('Lỗi khi tải lịch sử chat: $e');
      _startNewChat();
    } finally {
      setState(() {
        _isLoadingHistory = false;
      });
    }
  }
  
  Future<void> _refreshChatHistories() async {
    if (_userId.isEmpty) return;
    
    setState(() {
      _isLoadingHistory = true;
    });
    
    try {
      print('🔄 Đang làm mới lịch sử chat cho người dùng: $_userId');
      
      // Truy vấn chat mới nhất từ Firebase để đồng bộ với local
      try {
        await ChatApi.getLatestChatHistory(_userId);
        
        // Chờ một khoảng thời gian nhỏ để đảm bảo dữ liệu được xử lý
        await Future.delayed(const Duration(milliseconds: 300));
      } catch (e) {
        print('⚠️ Lỗi khi lấy lịch sử chat từ Firebase: $e');
      }
      
      // Lấy tất cả cuộc trò chuyện từ local storage (đã được đồng bộ)
      final conversations = await ChatApi.getAllConversations(_userId);
      print('📊 Đã tải ${conversations.length} cuộc trò chuyện');
      
      if (mounted) {
        setState(() {
          _chatHistories = conversations;
          
          if (_currentChat != null) {
            // Tìm cuộc trò chuyện hiện tại trong danh sách mới
            final updatedCurrentChat = conversations.firstWhere(
              (chat) => chat.id == _currentChat!.id,
              orElse: () => conversations.isNotEmpty ? conversations.first : _currentChat!,
            );
            
            // Cập nhật cuộc trò chuyện hiện tại và tin nhắn
            _currentChat = updatedCurrentChat;
            _messages.clear();
            _messages.addAll(_currentChat!.messages);
            
            print('✅ Đã cập nhật cuộc trò chuyện hiện tại: ${_currentChat!.id} với ${_currentChat!.messages.length} tin nhắn');
            
            // Cuộn xuống cuối danh sách tin nhắn
            Future.delayed(const Duration(milliseconds: 100), () {
              _scrollToBottom();
            });
          } else if (conversations.isNotEmpty) {
            // Nếu không có cuộc trò chuyện hiện tại, lấy cuộc trò chuyện đầu tiên
            _loadCurrentChat();
          }
        });
      }
    } catch (e) {
      print('❌ Lỗi khi làm mới lịch sử chat: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingHistory = false;
        });
      }
    }
  }
  
  Future<void> _loadCurrentChat() async {
    try {
      print('🔄 Đang tải cuộc trò chuyện hiện tại...');
      final currentId = await ChatApi.getCurrentConversationId();
      print('🔄 ID cuộc trò chuyện hiện tại: $currentId');
      
      // Lấy lại tất cả các cuộc trò chuyện từ local storage để đảm bảo dữ liệu mới nhất
      final updatedChatHistories = await ChatApi.getAllConversations(_userId);
      
      if (currentId != null && updatedChatHistories.isNotEmpty) {
        // Tìm cuộc trò chuyện hiện tại trong danh sách đã cập nhật
        final currentChat = updatedChatHistories.firstWhere(
          (chat) => chat.id == currentId,
          orElse: () => updatedChatHistories.first,
        );
        
        print('🔄 Đã tìm thấy cuộc trò chuyện với ID: ${currentChat.id}, có ${currentChat.messages.length} tin nhắn');
        
        setState(() {
          // Cập nhật cả danh sách cuộc trò chuyện
          _chatHistories = updatedChatHistories;
          // Cập nhật cuộc trò chuyện hiện tại
          _currentChat = currentChat;
          // Cập nhật danh sách tin nhắn
          _messages.clear();
          _messages.addAll(_currentChat!.messages);
        });
        
        // Đăng ký stream cho cuộc trò chuyện này
        _subscribeToCurrentChatStream();
      } else if (updatedChatHistories.isNotEmpty) {
        // Nếu không có ID hiện tại, lấy cuộc trò chuyện đầu tiên
        setState(() {
          // Cập nhật cả danh sách cuộc trò chuyện
          _chatHistories = updatedChatHistories;
          _currentChat = updatedChatHistories.first;
          _messages.clear();
          _messages.addAll(_currentChat!.messages);
        });
        
        // Lưu ID cuộc trò chuyện hiện tại
        await ChatApi.selectConversation(_currentChat!.id);
        
        // Đăng ký stream cho cuộc trò chuyện này
        _subscribeToCurrentChatStream();
      }
      
      // Cuộn xuống cuối danh sách
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollToBottom();
      });
    } catch (e) {
      print('❌ Lỗi khi tải cuộc trò chuyện hiện tại: $e');
    }
  }
  
  Future<void> _startNewChat() async {
    try {
      // Tạo cuộc trò chuyện mới
      final newChat = await ChatApi.createNewConversation(_userId);
      
      setState(() {
        _currentChat = newChat;
        _messages.clear();
        
        // Thêm vào danh sách lịch sử
        _chatHistories.insert(0, newChat);
      });
    } catch (e) {
      print('Lỗi khi tạo cuộc trò chuyện mới: $e');
      
      setState(() {
        _messages.clear();
        _currentChat = null;
      });
    }
  }
  
  Future<void> _selectChat(ChatConversation chat) async {
    try {
      // Lưu ID cuộc trò chuyện được chọn
      await ChatApi.selectConversation(chat.id);
      
      setState(() {
        _currentChat = chat;
        _messages.clear();
        _messages.addAll(chat.messages);
        _showSidebar = false;
      });
      
      // Đăng ký stream cho cuộc trò chuyện này
      _subscribeToCurrentChatStream();
      
      // Cuộn xuống cuối danh sách
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollToBottom();
      });
    } catch (e) {
      print('Lỗi khi chọn cuộc trò chuyện: $e');
    }
  }
  
  Future<void> _deleteChat(ChatConversation chat) async {
    try {
      await ChatApi.deleteConversation(chat.id);
      
      // Cập nhật danh sách cuộc trò chuyện
      final updatedHistories = await ChatApi.getAllConversations(_userId);
      
      setState(() {
        _chatHistories = updatedHistories;
        
        if (chat.id == _currentChat?.id) {
          if (updatedHistories.isNotEmpty) {
            // Nếu xóa cuộc trò chuyện hiện tại, chuyển sang cuộc trò chuyện khác
            _currentChat = updatedHistories.first;
            _messages.clear();
            _messages.addAll(_currentChat!.messages);
          } else {
            // Nếu không còn cuộc trò chuyện nào, tạo mới
            _startNewChat();
          }
        }
      });
    } catch (e) {
      print('Lỗi khi xóa cuộc trò chuyện: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể xóa cuộc trò chuyện')),
      );
    }
  }

  void _handleSubmitted(String text) {
    if (text.trim().isEmpty) return;
    
    _messageController.clear();
    setState(() {
      _isComposing = false;
      _isTyping = true;
    });

    // Gọi API để gửi tin nhắn
    _sendMessage(text);
  }

  // Bắt đầu timer cho trạng thái loading
  void _startLoadingTimeout() {
    // Hủy timer cũ nếu còn
    _loadingTimeoutTimer?.cancel();
    
    // Đặt timer mới để tự động tắt trạng thái loading sau 30 giây
    _loadingTimeoutTimer = Timer(const Duration(seconds: 30), () {
      if (mounted && _isTyping) {
        print('⚠️ Đã quá thời gian chờ phản hồi, tự động tắt trạng thái loading');
        setState(() {
          _isTyping = false;
        });
        
        // Hiển thị thông báo cho người dùng
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không nhận được phản hồi từ server sau 30 giây. Vui lòng thử lại sau.'),
            duration: Duration(seconds: 5),
          ),
        );
      }
    });
  }
  
  Future<void> _sendMessage(String text) async {
    try {
      print('🚀 Đang gửi tin nhắn: ${text.substring(0, text.length > 20 ? 20 : text.length)}...');
      
      // Đảm bảo có cuộc trò chuyện hiện tại
      if (_currentChat == null) {
        await _startNewChat();
      }
      
      // Lưu lại ID cuộc trò chuyện trước khi gửi
      final String originalChatId = _currentChat!.id;
      
      // Thêm tin nhắn người dùng vào UI ngay lập tức để hiển thị
      final userMessage = ChatMessage(
        id: const Uuid().v4(),
        text: text,
        isUser: true,
        timestamp: DateTime.now().toIso8601String(),
        chatId: _currentChat!.id,
      );
      
      setState(() {
        _messages.add(userMessage);
        _isTyping = true;
        
        // Thêm tin nhắn vào cuộc trò chuyện hiện tại
        final updatedChat = ChatConversation(
          id: _currentChat!.id,
          title: _currentChat!.title,
          createdAt: _currentChat!.createdAt,
          userId: _currentChat!.userId,
          messages: List.from(_messages), // Tạo bản sao của danh sách tin nhắn
        );
        
        // Cập nhật tiêu đề nếu là tin nhắn đầu tiên
        if (updatedChat.messages.length == 1) {
          updatedChat.title = text.length > 40 ? text.substring(0, 37) + '...' : text;
        }
        
        // Cập nhật cuộc trò chuyện hiện tại
        _currentChat = updatedChat;
        
        // Cập nhật trong danh sách cuộc trò chuyện
        final int index = _chatHistories.indexWhere((c) => c.id == updatedChat.id);
        if (index >= 0) {
          _chatHistories[index] = updatedChat;
        } else {
          _chatHistories.add(updatedChat);
        }
      });
      
      // Bắt đầu timer để tự động tắt trạng thái loading sau thời gian chờ
      _startLoadingTimeout();
      
      // Lưu vào local storage
      await ChatApi.saveConversations(_chatHistories);
      
      // Cuộn xuống để hiển thị tin nhắn mới
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollToBottom();
      });
      
      // Gọi API để gửi tin nhắn
      final response = await ChatApi.sendMessage(text, _userId);
      print('✅ Đã nhận phản hồi từ API: ${response.toString().substring(0, response.toString().length > 50 ? 50 : response.toString().length)}...');
      
      // Hủy timer vì đã nhận được phản hồi
      _loadingTimeoutTimer?.cancel();
      
      // Kiểm tra lỗi
      if (response['error'] == true) {
        print('❌ Lỗi từ API: ${response['error_message']}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: ${response['error_message'] ?? "Không rõ lỗi"}')),
        );
        
        // Kết thúc trạng thái đang nhập nếu có lỗi
        setState(() {
          _isTyping = false;
        });
      } else {
        print('✅ Phản hồi thành công: ${response['reply']?.substring(0, response['reply'].length > 30 ? 30 : response['reply'].length)}...');
        
        // Lấy chatId từ phản hồi
        final String serverChatId = response['chat_id'] ?? _currentChat!.id;
        
        // Kiểm tra xem ID có thay đổi không
        if (serverChatId != originalChatId) {
          print('🔄 ChatID đã thay đổi trên server: $originalChatId -> $serverChatId');
          
          // Đảm bảo cập nhật lại ID trong các danh sách
          await _refreshChatHistories();
          
          // Tìm cuộc trò chuyện với ID mới
          final currentChatIndex = _chatHistories.indexWhere((chat) => chat.id == serverChatId);
          if (currentChatIndex >= 0) {
            setState(() {
              _currentChat = _chatHistories[currentChatIndex];
              _messages.clear();
              _messages.addAll(_currentChat!.messages);
              
              // Đảm bảo tắt trạng thái đang nhập
              _isTyping = false;
            });
          }
        }
        
        // Đăng ký lại stream với ID mới
        _subscribeToCurrentChatStream();
        
        // Đảm bảo cập nhật UI với phản hồi
        final botMessage = ChatMessage(
          id: const Uuid().v4(),
          text: response['reply'] ?? 'Không có phản hồi',
          isUser: false,
          timestamp: DateTime.now().toIso8601String(),
          chatId: serverChatId,
        );
        
        // Kiểm tra xem phản hồi đã có trong tin nhắn chưa
        bool replyExists = false;
        for (final msg in _messages) {
          if (!msg.isUser && msg.text == botMessage.text) {
            replyExists = true;
            break;
          }
        }
        
        // Nếu chưa có, thêm vào UI
        if (!replyExists) {
          setState(() {
            _messages.add(botMessage);
            _isTyping = false;
            
            // Cập nhật cuộc trò chuyện hiện tại
            if (_currentChat != null) {
              // Tạo bản sao của tin nhắn hiện tại
              final updatedMessages = List<ChatMessage>.from(_messages);
              
              // Tạo cuộc trò chuyện mới với các tin nhắn đã cập nhật
              final updatedChat = ChatConversation(
                id: serverChatId,
                title: _currentChat!.title,
                createdAt: _currentChat!.createdAt,
                userId: _currentChat!.userId,
                messages: updatedMessages,
              );
              
              _currentChat = updatedChat;
              
              // Cập nhật trong danh sách cuộc trò chuyện
              final int index = _chatHistories.indexWhere((c) => c.id == serverChatId);
              if (index >= 0) {
                _chatHistories[index] = updatedChat;
              } else {
                // Thêm mới nếu không tìm thấy
                _chatHistories.add(updatedChat);
              }
              
              // Lưu vào local storage
              ChatApi.saveConversations(_chatHistories);
            }
          });
          
          // Cuộn xuống để hiển thị tin nhắn mới
          Future.delayed(const Duration(milliseconds: 100), () {
            _scrollToBottom();
          });
        } else {
          // Đảm bảo tắt trạng thái đang nhập ngay cả khi tin nhắn đã tồn tại
          setState(() {
            _isTyping = false;
          });
        }
      }
    } catch (e) {
      print('❌ Lỗi khi gửi tin nhắn: $e');
      
      // Hủy timer
      _loadingTimeoutTimer?.cancel();
      
      setState(() {
        _isTyping = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi gửi tin nhắn: $e')),
      );
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Trò chuyện dinh dưỡng'),
        leading: IconButton(
          icon: Icon(Icons.menu),
          onPressed: () {
            setState(() {
              _showSidebar = !_showSidebar;
            });
          },
        ),
        actions: [
          // Nút tạo cuộc trò chuyện mới
          IconButton(
            icon: Icon(Icons.add),
            onPressed: _startNewChat,
            tooltip: 'Cuộc trò chuyện mới',
          ),
        ],
      ),
      body: Row(
        children: [
          // Sidebar hiển thị lịch sử
          if (_showSidebar)
            Container(
              width: 300,
              color: Colors.grey.shade200,
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.all(16),
                    color: Colors.blue.shade100,
                    child: Row(
                      children: [
                        Icon(Icons.history),
                        SizedBox(width: 8),
                        Text(
                          'Lịch sử cuộc trò chuyện',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _isLoadingHistory
                        ? Center(child: CircularProgressIndicator())
                        : _chatHistories.isEmpty
                            ? Center(child: Text('Chưa có cuộc trò chuyện nào'))
                            : ListView.builder(
                                itemCount: _chatHistories.length,
                                itemBuilder: (context, index) {
                                  final chat = _chatHistories[index];
                                  final bool isSelected = _currentChat?.id == chat.id;
                                  
                                  return Dismissible(
                                    key: Key(chat.id),
                                    background: Container(
                                      color: Colors.red,
                                      alignment: Alignment.centerRight,
                                      padding: EdgeInsets.only(right: 16),
                                      child: Icon(Icons.delete, color: Colors.white),
                                    ),
                                    direction: DismissDirection.endToStart,
                                    confirmDismiss: (direction) async {
                                      return await showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: Text('Xác nhận xóa'),
                                          content: Text('Bạn có chắc muốn xóa cuộc trò chuyện này?'),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.of(context).pop(false),
                                              child: Text('Hủy'),
                                            ),
                                            TextButton(
                                              onPressed: () => Navigator.of(context).pop(true),
                                              child: Text('Xóa'),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                    onDismissed: (direction) {
                                      _deleteChat(chat);
                                    },
                                    child: ListTile(
                                      title: Text(
                                        chat.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      subtitle: Text(
                                        DateFormat('dd/MM/yyyy').format(DateTime.parse(chat.createdAt)),
                                        style: TextStyle(fontSize: 12),
                                      ),
                                      selected: isSelected,
                                      selectedTileColor: Colors.blue.shade50,
                                      leading: Icon(Icons.chat_bubble_outline),
                                      onTap: () => _selectChat(chat),
                                    ),
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),
          
          // Chat screen
          Expanded(
            child: Stack(
              children: [
                Column(
                  children: [
                    // Chat messages area
                    Expanded(
                      child: Container(
                        color: Colors.grey.shade100,
                        child: _messages.isEmpty && _isLoadingHistory
                            ? Center(child: CircularProgressIndicator())
                            : _messages.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.chat_bubble_outline,
                                          size: 64,
                                          color: Colors.grey,
                                        ),
                                        SizedBox(height: 16),
                                        Text(
                                          'Bắt đầu cuộc trò chuyện mới',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    controller: _scrollController,
                                    padding: EdgeInsets.all(8.0),
                                    itemCount: _messages.length,
                                    itemBuilder: (context, index) {
                                      final message = _messages[index];
                                      return _buildMessageWidget(message);
                                    },
                                  ),
                      ),
                    ),
                    
                    // Typing indicator
                    if (_isTyping)
                      Container(
                        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                        color: Colors.grey.shade50,
                        child: Row(
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Đang trả lời...',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    // Input area
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          top: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                      child: _buildInputArea(),
                    ),
                  ],
                ),
                
                // Loading overlay
                if (_isLoadingHistory)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withOpacity(0.3),
                      child: Center(
                        child: Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text('Đang tải lịch sử chat...'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageWidget(ChatMessage message) {
    final isUser = message.isUser;
    final timestamp = DateTime.parse(message.timestamp);
    final formattedTime = DateFormat.Hm().format(timestamp);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Bot avatar (only show for bot messages)
              if (!isUser)
                CircleAvatar(
                  backgroundColor: Colors.blue,
                  radius: 16,
                  child: Icon(Icons.smart_toy, color: Colors.white, size: 18),
                ),
              
              SizedBox(width: 8),
              
              // Message bubble
              Flexible(
                child: Container(
                  decoration: BoxDecoration(
                    color: isUser ? Colors.blue : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        spreadRadius: 1,
                        blurRadius: 1,
                      ),
                    ],
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      color: isUser ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              ),
              
              SizedBox(width: 8),
              
              // User avatar (only show for user messages)
              if (isUser)
                CircleAvatar(
                  backgroundColor: Colors.blue.shade100,
                  radius: 16,
                  child: Icon(Icons.person, color: Colors.blue, size: 18),
                ),
            ],
          ),
          
          // Time and chat ID indicator
          Padding(
            padding: const EdgeInsets.only(top: 2.0, left: 48.0, right: 48.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  formattedTime,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
                if (message.chatId.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 4.0),
                    child: Icon(
                      Icons.cloud_done,
                      color: Colors.green,
                      size: 12,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        children: [
          // Text input
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Hãy đặt bất kỳ câu hỏi nào',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              onChanged: (String text) {
                setState(() {
                  _isComposing = text.isNotEmpty;
                });
              },
              onSubmitted: _isTyping ? null : _handleSubmitted,
              enabled: !_isTyping,
            ),
          ),
          
          // Send button
          Container(
            margin: EdgeInsets.symmetric(horizontal: 4.0),
            decoration: BoxDecoration(
              color: _isComposing && !_isTyping ? Colors.green : Colors.grey.shade400,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(Icons.arrow_forward, color: Colors.white),
              onPressed: _isComposing && !_isTyping
                  ? () => _handleSubmitted(_messageController.text)
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
