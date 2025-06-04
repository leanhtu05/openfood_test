import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
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
  
  @override
  void initState() {
    super.initState();
    
    // Đăng ký observer để biết khi app trở lại foreground
    WidgetsBinding.instance.addObserver(this);
    
    _initUserId().then((_) {
      // Tải lịch sử chat
      _loadAllChatHistories();
    });
  }
  
  @override
  void dispose() {
    // Hủy đăng ký observer
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Khi ứng dụng chuyển sang trạng thái resumed (trở lại foreground)
    if (state == AppLifecycleState.resumed) {
      // Tải lại lịch sử chat nhưng giữ nguyên cuộc trò chuyện hiện tại
      if (_userId.isNotEmpty) {
        _refreshChatHistories();
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
    
    try {
      // Lấy tất cả cuộc trò chuyện từ local storage
      final conversations = await ChatApi.getAllConversations(_userId);
      
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
        } else if (conversations.isNotEmpty) {
          // Nếu không có cuộc trò chuyện hiện tại, lấy cuộc trò chuyện đầu tiên
          _loadCurrentChat();
        }
      });
    } catch (e) {
      print('Lỗi khi làm mới lịch sử chat: $e');
    }
  }
  
  Future<void> _loadCurrentChat() async {
    try {
      final currentId = await ChatApi.getCurrentConversationId();
      
      if (currentId != null && _chatHistories.isNotEmpty) {
        // Tìm cuộc trò chuyện hiện tại
        final currentChat = _chatHistories.firstWhere(
          (chat) => chat.id == currentId,
          orElse: () => _chatHistories.first,
        );
        
        setState(() {
          _currentChat = currentChat;
          _messages.clear();
          _messages.addAll(_currentChat!.messages);
        });
      } else if (_chatHistories.isNotEmpty) {
        // Nếu không có ID hiện tại, lấy cuộc trò chuyện đầu tiên
        setState(() {
          _currentChat = _chatHistories.first;
          _messages.clear();
          _messages.addAll(_currentChat!.messages);
        });
        
        // Lưu ID cuộc trò chuyện hiện tại
        await ChatApi.selectConversation(_currentChat!.id);
      }
      
      // Cuộn xuống cuối danh sách
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollToBottom();
      });
    } catch (e) {
      print('Lỗi khi tải cuộc trò chuyện hiện tại: $e');
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

  Future<void> _sendMessage(String text) async {
    try {
      final response = await ChatApi.sendMessage(text, _userId);
      
      // Làm mới lịch sử chat và cuộc trò chuyện hiện tại
      await _refreshChatHistories();
      
      setState(() {
        _isTyping = false;
      });
    } catch (e) {
      print('Lỗi khi gửi tin nhắn: $e');
      
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
