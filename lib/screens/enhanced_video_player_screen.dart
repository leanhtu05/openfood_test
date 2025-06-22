import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/video_service.dart';

class EnhancedVideoPlayerScreen extends StatefulWidget {
  final Map<String, String> video;
  final String dishName;

  const EnhancedVideoPlayerScreen({
    Key? key,
    required this.video,
    required this.dishName,
  }) : super(key: key);

  @override
  _EnhancedVideoPlayerScreenState createState() => _EnhancedVideoPlayerScreenState();
}

class _EnhancedVideoPlayerScreenState extends State<EnhancedVideoPlayerScreen> {
  YoutubePlayerController? _controller;
  final VideoService _videoService = VideoService();
  final TextEditingController _noteController = TextEditingController();
  
  bool _isFavorite = false;
  bool _showNotes = false;
  String _currentNote = '';

  @override
  void initState() {
    super.initState();
    _initializePlayer();
    _loadVideoData();
  }

  void _initializePlayer() {
    try {
      final videoId = widget.video['videoId']!;

      print('🎬 Initializing player with video ID: $videoId');

      // Kiểm tra nếu là search video
      if (videoId == 'SEARCH_YOUTUBE' || videoId == 'SEARCH_YOUTUBE_ALT') {
        print('🔍 Search video detected, showing search UI in app');
        _showEnhancedSearchUI();
        return;
      }

      // Kiểm tra nếu là video fallback (demo videos)
      if (_isKnownFallbackVideo(videoId)) {
        print('⚠️ Fallback video detected, showing enhanced search UI');
        _showEnhancedSearchUI();
        return;
      }

      _controller = YoutubePlayerController(
        initialVideoId: videoId,
        flags: YoutubePlayerFlags(
          autoPlay: false, // Không auto play để tránh lỗi
          mute: false,
          enableCaption: true,
          captionLanguage: 'vi',
          showLiveFullscreenButton: false,
        ),
      );

      // Add to watch history
      _videoService.addToWatchHistory(widget.video);
      print('✅ Video player initialized successfully');
    } catch (e) {
      print('❌ Error initializing YouTube player: $e');
      _showEnhancedSearchUI();
    }
  }

  bool _isKnownFallbackVideo(String videoId) {
    // Danh sách video fallback đã biết
    final fallbackVideos = [
      'dQw4w9WgXcQ', // Rick Roll
      'kJQP7kiw5Fk', // Nyan Cat
      'BaW_jenozKc', // Keyboard Cat
      'M7lc1UVf-VE', // Charlie bit my finger
      'jNQXAC9IVRw', // Me at the zoo
    ];
    return fallbackVideos.contains(videoId);
  }

  void _showEnhancedSearchUI() {
    // Thay thế video player bằng enhanced search UI
    setState(() {
      _controller = null; // Không khởi tạo video player
    });
    print('🎨 Showing enhanced search UI instead of video player');
  }

  void _openYouTubeSearch() async {
    // Tạo từ khóa tìm kiếm thông minh dựa trên món ăn
    String searchQuery = _getSmartSearchQuery(widget.dishName);
    final searchUrl = 'https://www.youtube.com/results?search_query=${Uri.encodeComponent(searchQuery)}';

    try {
      final Uri url = Uri.parse(searchUrl);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        Navigator.pop(context); // Quay lại màn hình trước
      } else {
        _showVideoNotFoundDialog();
      }
    } catch (e) {
      _showVideoNotFoundDialog();
    }
  }

  String _getSmartSearchQuery(String dishName) {
    // Từ khóa tìm kiếm thông minh cho từng món ăn
    final Map<String, String> smartQueries = {
      'Phở Bò': 'cách nấu phở bò Hà Nội ngon',
      'Bún Chả': 'cách làm bún chả Hà Nội Obama',
      'Cơm Tấm': 'cách làm cơm tấm sườn nướng Sài Gòn',
      'Bánh Mì': 'cách làm bánh mì Việt Nam giòn tan',
      'Gỏi Cuốn': 'cách cuốn gỏi cuốn tôm thịt đẹp',
      'Canh Chua': 'cách nấu canh chua cá miền Tây',
    };

    return smartQueries[dishName] ?? '$dishName hướng dẫn nấu ăn';
  }

  void _openInYouTube() async {
    final videoUrl = 'https://www.youtube.com/watch?v=${widget.video['videoId']}';
    try {
      final Uri url = Uri.parse(videoUrl);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        Navigator.pop(context); // Quay lại màn hình trước
      } else {
        _showVideoNotFoundDialog();
      }
    } catch (e) {
      _showVideoNotFoundDialog();
    }
  }

  void _showVideoNotFoundDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.orange),
            SizedBox(width: 8),
            Text('Video không khả dụng'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Video này hiện không thể phát được. Bạn có thể:'),
            SizedBox(height: 12),
            Text('• Thử video khác trong danh sách'),
            Text('• Tìm kiếm trên YouTube với từ khóa:'),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${widget.dishName} hướng dẫn nấu ăn',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade700,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Đóng dialog
              Navigator.pop(context); // Quay lại màn hình trước
            },
            child: Text('Quay lại'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Đóng dialog
              final searchUrl = 'https://www.youtube.com/results?search_query=${Uri.encodeComponent('${widget.dishName} hướng dẫn nấu ăn')}';
              final Uri url = Uri.parse(searchUrl);
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
              Navigator.pop(context); // Quay lại màn hình trước
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: Text('Tìm trên YouTube'),
          ),
        ],
      ),
    );
  }

  void _loadVideoData() async {
    final isFav = await _videoService.isFavorite(widget.video['videoId']!);
    final note = await _videoService.getVideoNote(widget.video['videoId']!) ?? '';
    
    setState(() {
      _isFavorite = isFav;
      _currentNote = note;
      _noteController.text = note;
    });
  }

  @override
  void dispose() {
    _controller?.dispose(); // Safe disposal for nullable controller
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final videoId = widget.video['videoId']!;
    final isSearchVideo = videoId == 'SEARCH_YOUTUBE' || videoId == 'SEARCH_YOUTUBE_ALT';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          widget.dishName,
          style: TextStyle(fontSize: 18),
        ),
        actions: [
          if (!isSearchVideo) ...[
            IconButton(
              onPressed: _toggleFavorite,
              icon: Icon(
                _isFavorite ? Icons.favorite : Icons.favorite_border,
                color: _isFavorite ? Colors.red : Colors.white,
              ),
            ),
            IconButton(
              onPressed: () => setState(() => _showNotes = !_showNotes),
              icon: Icon(
                Icons.note_add,
                color: _showNotes ? Colors.orange : Colors.white,
              ),
            ),
          ],
        ],
      ),
      body: isSearchVideo || _controller == null
          ? _buildSearchVideoView()
          : Column(
              children: [
                // Video Player với error handling
                YoutubePlayer(
                  controller: _controller!,
                  showVideoProgressIndicator: true,
                  progressIndicatorColor: Colors.orange,
                  progressColors: ProgressBarColors(
                    playedColor: Colors.orange,
                    handleColor: Colors.orange.shade700,
                  ),
                  onReady: () {
                    print('✅ Video ready to play: ${widget.video['videoId']}');
                  },
                  onEnded: (metaData) {
                    print('📺 Video ended: ${metaData.videoId}');
                  },
                ),
          
          // Video Info
          Container(
            color: Colors.grey.shade900,
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.video['title']!,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.account_circle, color: Colors.grey.shade400, size: 20),
                    SizedBox(width: 8),
                    Text(
                      widget.video['channel']!,
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 14,
                      ),
                    ),
                    Spacer(),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        widget.video['duration']!,
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Notes Section
          if (_showNotes)
            Expanded(
              child: Container(
                color: Colors.grey.shade800,
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.edit_note, color: Colors.orange, size: 24),
                        SizedBox(width: 8),
                        Text(
                          'Ghi chú của bạn',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Expanded(
                      child: TextField(
                        controller: _noteController,
                        maxLines: null,
                        expands: true,
                        style: TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Viết ghi chú về video này...\n\nVí dụ:\n- Nguyên liệu cần chuẩn bị\n- Mẹo hay từ video\n- Điều chỉnh theo khẩu vị',
                          hintStyle: TextStyle(color: Colors.grey.shade400),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade600),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade600),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.orange),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade900,
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _saveNote,
                            icon: Icon(Icons.save, size: 18),
                            label: Text('Lưu ghi chú'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _clearNote,
                          icon: Icon(Icons.clear, size: 18),
                          label: Text('Xóa'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // Control Buttons - only show when controller is available
          if (!_showNotes && _controller != null)
            Container(
              color: Colors.grey.shade900,
              padding: EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildControlButton(
                    icon: Icons.replay_10,
                    label: 'Lùi 10s',
                    onPressed: () => _controller?.seekTo(
                      (_controller?.value.position ?? Duration.zero) - Duration(seconds: 10),
                    ),
                  ),
                  _buildControlButton(
                    icon: (_controller?.value.isPlaying ?? false) ? Icons.pause : Icons.play_arrow,
                    label: (_controller?.value.isPlaying ?? false) ? 'Tạm dừng' : 'Phát',
                    onPressed: () {
                      if (_controller?.value.isPlaying ?? false) {
                        _controller?.pause();
                      } else {
                        _controller?.play();
                      }
                    },
                  ),
                  _buildControlButton(
                    icon: Icons.forward_10,
                    label: 'Tới 10s',
                    onPressed: () => _controller?.seekTo(
                      (_controller?.value.position ?? Duration.zero) + Duration(seconds: 10),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onPressed,
          icon: Icon(icon, color: Colors.white, size: 28),
          style: IconButton.styleFrom(
            backgroundColor: Colors.grey.shade800,
            shape: CircleBorder(),
            padding: EdgeInsets.all(12),
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  void _toggleFavorite() async {
    if (_isFavorite) {
      await _videoService.removeFromFavorites(widget.video['videoId']!);
    } else {
      await _videoService.addToFavorites(widget.video);
    }
    
    setState(() {
      _isFavorite = !_isFavorite;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isFavorite ? 'Đã thêm vào yêu thích' : 'Đã xóa khỏi yêu thích'),
        backgroundColor: _isFavorite ? Colors.green : Colors.grey.shade700,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _saveNote() async {
    final success = await _videoService.saveVideoNote(
      widget.video['videoId']!,
      _noteController.text,
    );
    
    if (success) {
      setState(() {
        _currentNote = _noteController.text;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã lưu ghi chú'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _clearNote() {
    _noteController.clear();
    _saveNote();
  }

  Widget _buildSearchVideoView() {
    return Container(
      color: Colors.grey.shade900,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange.shade600, Colors.orange.shade800],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.search,
                  size: 64,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 24),
              Text(
                'Tìm kiếm video trên YouTube',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              Text(
                'Chúng tôi sẽ mở YouTube để bạn tìm video hướng dẫn nấu "${widget.dishName}"',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 32),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade800,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.search, color: Colors.orange, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Từ khóa tìm kiếm:',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      '"${_getSmartSearchQuery(widget.dishName)}"',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.arrow_back, size: 18),
                    label: Text('Quay lại'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _openYouTubeSearch,
                    icon: Icon(Icons.open_in_new, size: 18),
                    label: Text('Mở YouTube'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade600,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
