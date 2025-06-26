import 'package:flutter/material.dart';
import 'package:openfood/screens/video_library_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/meal_plan.dart';
import '../services/video_service.dart';
import '../services/youtube_api_service.dart';
import '../services/video_validation_service.dart';
import '../services/real_video_service.dart';
import 'enhanced_video_player_screen.dart';

// 🎨 Import DietPlanColors để sử dụng tông màu xanh nhẹ
class DietPlanColors {
  static const Color primary = Color(0xFF2196F3);
  static const Color primaryLight = Color(0xFFE3F2FD);
  static const Color primaryDark = Color(0xFF1976D2);
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
}

class RecipeDetailScreen extends StatefulWidget {
  final Dish dish;

  const RecipeDetailScreen({
    Key? key,
    required this.dish,
  }) : super(key: key);

  @override
  _RecipeDetailScreenState createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  int _currentStep = 0;
  late List<String> _parsedSteps;

  // YouTube player variables
  YoutubePlayerController? _youtubeController;
  List<Map<String, String>> _videoOptions = [];
  bool _isLoadingVideos = false;
  bool _showVideoPlayer = false;
  String? _selectedVideoId;
  final VideoService _videoService = VideoService();
  final YouTubeApiService _youtubeApiService = YouTubeApiService();
  final VideoValidationService _videoValidationService = VideoValidationService();
  final RealVideoService _realVideoService = RealVideoService();

  // 💖 Favorite & Recently Watched variables
  bool _isFavorite = false;
  List<Map<String, dynamic>> _recentlyWatchedVideos = [];

  @override
  void initState() {
    super.initState();
    _parseInstructions();
    _loadFavoriteStatus();
    _loadRecentlyWatchedVideos();
  }

  // 💖 LOAD FAVORITE STATUS
  void _loadFavoriteStatus() {
    // TODO: Load from SharedPreferences or database
    // For now, set to false
    setState(() {
      _isFavorite = false;
    });
  }

  // 📺 LOAD RECENTLY WATCHED VIDEOS
  void _loadRecentlyWatchedVideos() {
    // TODO: Load from SharedPreferences or database
    // Sample data for demo
    setState(() {
      _recentlyWatchedVideos = [
        {
          'videoId': 'sample1',
          'title': 'Cách nấu phở bò ngon',
          'channel': 'Món Ngon Mỗi Ngày',
          'watchedAt': DateTime.now().subtract(Duration(hours: 2)),
          'thumbnail': 'https://example.com/thumb1.jpg',
        },
        {
          'videoId': 'sample2',
          'title': 'Bún chả Hà Nội chuẩn vị',
          'channel': 'Ẩm Thực Việt',
          'watchedAt': DateTime.now().subtract(Duration(days: 1)),
          'thumbnail': 'https://example.com/thumb2.jpg',
        },
      ];
    });
  }

  // 💖 TOGGLE FAVORITE
  void _toggleFavorite() {
    setState(() {
      _isFavorite = !_isFavorite;
    });

    // TODO: Save to SharedPreferences or database

    // Show snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isFavorite
            ? '💖 Đã thêm "${widget.dish.name}" vào yêu thích'
            : '💔 Đã xóa "${widget.dish.name}" khỏi yêu thích',
        ),
        duration: Duration(seconds: 2),
        backgroundColor: _isFavorite ? Colors.pink : Colors.grey,
        action: SnackBarAction(
          label: 'Xem danh sách',
          textColor: Colors.white,
          onPressed: _showFavoriteRecipes,
        ),
      ),
    );
  }

  // 💖 SHOW FAVORITE RECIPES
  void _showFavoriteRecipes() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.favorite, color: Colors.pink, size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Công thức yêu thích',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Divider(height: 1),
            // Favorite recipes list
            Expanded(
              child: _buildFavoriteRecipesList(),
            ),
          ],
        ),
      ),
    );
  }

  // 📺 SHOW RECENTLY WATCHED VIDEOS
  void _showRecentlyWatchedVideos() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.history, color: DietPlanColors.primary, size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Video đã xem',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => VideoLibraryScreen(),
                        ),
                      );
                    },
                    child: Text(
                      'Xem tất cả',
                      style: TextStyle(color: DietPlanColors.primary),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Divider(height: 1),
            // Recently watched videos list
            Expanded(
              child: _buildRecentlyWatchedVideosList(),
            ),
          ],
        ),
      ),
    );
  }

  // Hàm để tách instructions thành các bước riêng biệt
  void _parseInstructions() {
    _parsedSteps = [];

    for (String instruction in widget.dish.instructions) {
      // Tách theo pattern "Bước X:" hoặc theo dấu chấm
      if (instruction.contains(RegExp(r'Bước \d+:'))) {
        // Tách theo "Bước X:"
        List<String> steps = instruction.split(RegExp(r'Bước \d+:'))
            .where((step) => step.trim().isNotEmpty)
            .map((step) => step.trim())
            .toList();
        _parsedSteps.addAll(steps);
      } else {
        // Tách theo dấu chấm
        List<String> steps = instruction.split('. ')
            .where((step) => step.trim().isNotEmpty)
            .map((step) => step.trim())
            .toList();

        // Thêm dấu chấm nếu chưa có
        for (int i = 0; i < steps.length; i++) {
          if (!steps[i].endsWith('.') && !steps[i].endsWith('!') && !steps[i].endsWith('?')) {
            steps[i] += '.';
          }
        }

        _parsedSteps.addAll(steps);
      }
    }

    // Nếu không tách được gì, giữ nguyên instructions gốc
    if (_parsedSteps.isEmpty) {
      _parsedSteps = widget.dish.instructions;
    }
  }

  // Method để search YouTube videos và hiển thị options - Updated to use smart search
  Future<void> _searchYouTubeVideos(String dishName) async {
    setState(() {
      _isLoadingVideos = true;
      _videoOptions.clear();
    });

    try {
      print('🔍 Searching videos for: $dishName');

      // Ưu tiên sử dụng Real Video Service để lấy video thực
      final realVideos = await _realVideoService.getRealVideosForDish(dishName);

      if (realVideos.isNotEmpty) {
        _videoOptions = realVideos;
        print('✅ Found ${realVideos.length} real videos for $dishName');

        setState(() {
          _isLoadingVideos = false;
        });

        // Hiển thị bottom sheet với video options
        _showVideoOptionsBottomSheet();
        return;
      }

      // Fallback: Sử dụng video validation service
      final videos = await _videoValidationService.getWorkingVideosForDish(dishName);

      if (videos.isNotEmpty) {
        _videoOptions = videos;
        print('✅ Found ${videos.length} videos for $dishName');

        setState(() {
          _isLoadingVideos = false;
        });

        // Hiển thị bottom sheet với video options
        _showVideoOptionsBottomSheet();
      } else {
        // Fallback: Tạo search video và hiển thị Enhanced Video Player
        print('🔄 No videos found, creating search video');
        _videoOptions = [
          {
            'videoId': 'SEARCH_YOUTUBE',
            'title': 'Tìm kiếm: "$dishName hướng dẫn nấu ăn"',
            'channel': 'YouTube Search',
            'duration': '∞',
            'views': 'Nhiều video',
            'description': 'Tìm kiếm video hướng dẫn nấu $dishName trên YouTube',
          }
        ];

        setState(() {
          _isLoadingVideos = false;
        });

        // Hiển thị bottom sheet với search option
        _showVideoOptionsBottomSheet();
      }

    } catch (e) {
      print('❌ Error searching videos: $e');

      // Tạo search video cho error case
      _videoOptions = [
        {
          'videoId': 'SEARCH_YOUTUBE',
          'title': 'Tìm kiếm: "$dishName hướng dẫn nấu ăn"',
          'channel': 'YouTube Search',
          'duration': '∞',
          'views': 'Nhiều video',
          'description': 'Tìm kiếm video hướng dẫn nấu $dishName trên YouTube',
        }
      ];

      setState(() {
        _isLoadingVideos = false;
      });

      // Hiển thị bottom sheet với search option
      _showVideoOptionsBottomSheet();
    }
  }

  // Method removed - now using VideoValidationService for smart search

  // Method để mở YouTube search với smart queries
  Future<void> _openYouTubeSearch(String dishName) async {
    try {
      // Tạo smart query tìm kiếm dựa trên món ăn
      String searchQuery = _getSmartSearchQuery(dishName);
      String youtubeSearchUrl = 'https://www.youtube.com/results?search_query=${Uri.encodeComponent(searchQuery)}';

      print('🔍 Opening YouTube search with query: $searchQuery');

      final Uri url = Uri.parse(youtubeSearchUrl);

      if (await canLaunchUrl(url)) {
        await launchUrl(
          url,
          mode: LaunchMode.externalApplication, // Mở trong app YouTube hoặc browser
        );
      } else {
        // Fallback: hiển thị dialog với thông tin tìm kiếm
        _showSearchDialog(searchQuery);
      }
    } catch (e) {
      // Nếu có lỗi, hiển thị dialog với thông tin tìm kiếm
      _showSearchDialog(_getSmartSearchQuery(dishName));
    }
  }

  // Smart search query cho từng món ăn
  String _getSmartSearchQuery(String dishName) {
    final Map<String, String> smartQueries = {
      'Phở Bò': 'cách nấu phở bò Hà Nội ngon',
      'Bún Chả': 'cách làm bún chả Hà Nội Obama',
      'Cơm Tấm': 'cách làm cơm tấm sườn nướng Sài Gòn',
      'Bánh Mì': 'cách làm bánh mì Việt Nam giòn tan',
      'Gỏi Cuốn': 'cách cuốn gỏi cuốn tôm thịt đẹp',
      'Canh Chua': 'cách nấu canh chua cá miền Tây',
      'Thịt Kho': 'cách kho thịt ba chỉ ngon',
      'Rau Xào': 'cách xào rau ngon giòn',
      'Cháo Gà': 'cách nấu cháo gà ngon',
    };

    return smartQueries[dishName] ?? '$dishName hướng dẫn nấu ăn';
  }

  // Bottom sheet hiển thị video options
  void _showVideoOptionsBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.play_circle_filled,
                       color: DietPlanColors.primary, size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Chọn video hướng dẫn',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Divider(height: 1),
            // Video list
            Expanded(
              child: _videoOptions.isEmpty
                ? _buildNoVideosMessage()
                : ListView.builder(
                    padding: EdgeInsets.all(16),
                    itemCount: _videoOptions.length,
                    itemBuilder: (context, index) {
                      final video = _videoOptions[index];
                      return _buildVideoOptionCard(video);
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget hiển thị khi không có video
  Widget _buildNoVideosMessage() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.video_library_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            SizedBox(height: 16),
            Text(
              'Không tìm thấy video',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Hiện tại không có video hướng dẫn cho món "${widget.dish.name}"',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade500,
                height: 1.4,
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                // Có thể thêm logic tìm kiếm manual ở đây
              },
              icon: Icon(Icons.search),
              label: Text('Tìm kiếm thủ công'),
              style: ElevatedButton.styleFrom(
                backgroundColor: DietPlanColors.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget để build video option card
  Widget _buildVideoOptionCard(Map<String, String> video) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
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
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _playVideo(video['videoId']!),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              child: Stack(
                children: [
                  Container(
                    height: 180,
                    width: double.infinity,
                    color: Colors.grey.shade200,
                    child: Icon(
                      Icons.play_circle_filled,
                      size: 64,
                      color: DietPlanColors.primary,
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        video['duration'] ?? '∞',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Video info
            Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video['title'] ?? 'Video hướng dẫn nấu ăn',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.account_circle,
                           size: 16, color: Colors.grey.shade600),
                      SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          video['channel'] ?? 'YouTube Channel',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (video['views'] != null) ...[
                        Icon(Icons.visibility, size: 14, color: Colors.grey.shade500),
                        SizedBox(width: 4),
                        Text(
                          video['views'] ?? '0',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        SizedBox(width: 8),
                      ],
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: DietPlanColors.primaryLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Xem ngay',
                          style: TextStyle(
                            fontSize: 12,
                            color: DietPlanColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (video['description'] != null) ...[
                    SizedBox(height: 8),
                    Text(
                      video['description'] ?? 'Video hướng dẫn nấu ăn',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Method để play video - updated to handle search videos
  void _playVideo(String videoId) {
    Navigator.pop(context); // Đóng bottom sheet

    print('🎬 Playing video with ID: $videoId');

    // 📺 ADD TO RECENTLY WATCHED
    _addToRecentlyWatched(videoId);
  }

  // 📺 ADD VIDEO TO RECENTLY WATCHED
  void _addToRecentlyWatched(String videoId) {
    // Find video info from current options
    final videoInfo = _videoOptions.firstWhere(
      (video) => video['videoId'] == videoId,
      orElse: () => {
        'videoId': videoId,
        'title': 'Video hướng dẫn nấu ăn',
        'channel': 'YouTube',
      },
    );

    // Create recently watched entry
    final recentlyWatchedEntry = {
      'videoId': videoId,
      'title': videoInfo['title'] ?? 'Video hướng dẫn nấu ăn',
      'channel': videoInfo['channel'] ?? 'YouTube',
      'watchedAt': DateTime.now(),
      'thumbnail': videoInfo['thumbnail'] ?? '',
    };

    setState(() {
      // Remove if already exists
      _recentlyWatchedVideos.removeWhere((video) => video['videoId'] == videoId);

      // Add to beginning of list
      _recentlyWatchedVideos.insert(0, recentlyWatchedEntry);

      // Keep only last 10 videos
      if (_recentlyWatchedVideos.length > 10) {
        _recentlyWatchedVideos = _recentlyWatchedVideos.take(10).toList();
      }
    });

    // TODO: Save to SharedPreferences or database
    print('📺 Added to recently watched: ${videoInfo['title']}');

    // Kiểm tra nếu là search video - mở Enhanced Video Player với search UI
    if (videoId == 'SEARCH_YOUTUBE' || videoId == 'SEARCH_YOUTUBE_ALT') {
      print('🔍 Detected search video, opening Enhanced Video Player with search UI');

      // Tìm video data để pass vào Enhanced Video Player
      final videoData = _videoOptions.firstWhere(
        (video) => video['videoId'] == videoId,
        orElse: () => {
          'videoId': videoId,
          'title': 'Tìm kiếm video ${widget.dish.name}',
          'channel': 'YouTube Search',
          'duration': '∞',
          'views': 'Nhiều video',
          'description': 'Tìm kiếm video hướng dẫn nấu ${widget.dish.name}',
        },
      );

      // Mở Enhanced Video Player với search UI
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EnhancedVideoPlayerScreen(
            video: videoData,
            dishName: widget.dish.name,
          ),
        ),
      );
      return;
    }

    // Tìm video data
    final videoData = _videoOptions.firstWhere(
      (video) => video['videoId'] == videoId,
      orElse: () => {
        'videoId': videoId,
        'title': 'Video hướng dẫn ${widget.dish.name}',
        'channel': 'Unknown',
        'duration': '0:00',
      },
    );

    // Nếu video data có search video ID, mở Enhanced Video Player với search UI
    if (videoData['videoId'] == 'SEARCH_YOUTUBE' || videoData['videoId'] == 'SEARCH_YOUTUBE_ALT') {
      print('🔍 Video data is search type, opening Enhanced Video Player with search UI');

      // Mở Enhanced Video Player với search UI
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EnhancedVideoPlayerScreen(
            video: videoData,
            dishName: widget.dish.name,
          ),
        ),
      );
      return;
    }

    // Mở enhanced video player cho video thực
    print('📺 Opening enhanced video player');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EnhancedVideoPlayerScreen(
          video: videoData,
          dishName: widget.dish.name,
        ),
      ),
    );
  }

  // Dialog hiển thị thông tin tìm kiếm khi không thể mở YouTube
  void _showSearchDialog(String searchQuery) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.search, color: DietPlanColors.primary),
              SizedBox(width: 8),
              Text('Tìm kiếm YouTube'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Hãy tìm kiếm trên YouTube với từ khóa:'),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  searchQuery,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: DietPlanColors.primary,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Đóng'),
            ),
          ],
        );
      },
    );
  }

  // 💖 BUILD FAVORITE RECIPES LIST
  Widget _buildFavoriteRecipesList() {
    // Sample favorite recipes data
    final favoriteRecipes = [
      {
        'name': 'Phở Bò Hà Nội',
        'prepTime': '120 phút',
        'difficulty': 'Khó',
        'image': 'https://example.com/pho.jpg',
      },
      {
        'name': 'Bún Chả',
        'prepTime': '45 phút',
        'difficulty': 'Trung bình',
        'image': 'https://example.com/buncha.jpg',
      },
      {
        'name': 'Cơm Tấm Sườn',
        'prepTime': '60 phút',
        'difficulty': 'Dễ',
        'image': 'https://example.com/comtam.jpg',
      },
    ];

    if (favoriteRecipes.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.favorite_border,
                size: 64,
                color: Colors.grey.shade400,
              ),
              SizedBox(height: 16),
              Text(
                'Chưa có công thức yêu thích',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Nhấn vào icon ❤️ để thêm công thức vào danh sách yêu thích',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: favoriteRecipes.length,
      itemBuilder: (context, index) {
        final recipe = favoriteRecipes[index];
        return Container(
          margin: EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: EdgeInsets.all(12),
            leading: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.restaurant_menu,
                color: Colors.grey.shade600,
                size: 24,
              ),
            ),
            title: Text(
              recipe['name']!,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            subtitle: Row(
              children: [
                Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                SizedBox(width: 4),
                Text(recipe['prepTime']!),
                SizedBox(width: 12),
                Icon(Icons.bar_chart, size: 14, color: Colors.grey.shade600),
                SizedBox(width: 4),
                Text(recipe['difficulty']!),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () {
                    // Remove from favorites
                  },
                  icon: Icon(Icons.favorite, color: Colors.pink, size: 20),
                ),
                Icon(Icons.chevron_right, color: Colors.grey.shade400),
              ],
            ),
            onTap: () {
              Navigator.pop(context);
              // Navigate to recipe detail
            },
          ),
        );
      },
    );
  }

  // 📺 BUILD RECENTLY WATCHED VIDEOS LIST
  Widget _buildRecentlyWatchedVideosList() {
    if (_recentlyWatchedVideos.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.history,
                size: 64,
                color: Colors.grey.shade400,
              ),
              SizedBox(height: 16),
              Text(
                'Chưa xem video nào',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Xem video hướng dẫn nấu ăn để chúng xuất hiện ở đây',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _recentlyWatchedVideos.length,
      itemBuilder: (context, index) {
        final video = _recentlyWatchedVideos[index];
        final watchedAt = video['watchedAt'] as DateTime;
        final timeAgo = _getTimeAgo(watchedAt);

        return Container(
          margin: EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: EdgeInsets.all(12),
            leading: Container(
              width: 80,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.play_circle_filled,
                    color: DietPlanColors.primary,
                    size: 32,
                  ),
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Text(
                        '5:30',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            title: Text(
              video['title']!,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 4),
                Text(
                  video['channel']!,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  timeAgo,
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            trailing: PopupMenuButton(
              icon: Icon(Icons.more_vert, color: Colors.grey.shade600),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'watch_again',
                  child: Row(
                    children: [
                      Icon(Icons.play_arrow, size: 18),
                      SizedBox(width: 8),
                      Text('Xem lại'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'remove',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 18, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Xóa khỏi lịch sử', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'watch_again') {
                  Navigator.pop(context);
                  _playVideo(video['videoId']!);
                } else if (value == 'remove') {
                  setState(() {
                    _recentlyWatchedVideos.removeAt(index);
                  });
                }
              },
            ),
            onTap: () {
              Navigator.pop(context);
              _playVideo(video['videoId']!);
            },
          ),
        );
      },
    );
  }

  // Helper method to get time ago string
  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} ngày trước';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} giờ trước';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} phút trước';
    } else {
      return 'Vừa xem';
    }
  }

  @override
  void dispose() {
    _youtubeController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'Hướng dẫn nấu ăn',
          style: TextStyle(
            color: Colors.grey.shade800,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.grey.shade700),
        centerTitle: true,
        actions: [
          // 📺 Recently Watched Videos Icon
          IconButton(
            onPressed: _showRecentlyWatchedVideos,
            icon: Stack(
              children: [
                Icon(
                  Icons.history,
                  color: Colors.grey.shade700,
                  size: 26,
                ),
                if (_recentlyWatchedVideos.isNotEmpty)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: DietPlanColors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      constraints: BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        '${_recentlyWatchedVideos.length}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            tooltip: 'Video đã xem',
          ),
          // 💖 Favorite Icon
          IconButton(
            onPressed: _toggleFavorite,
            icon: Icon(
              _isFavorite ? Icons.favorite : Icons.favorite_border,
              color: _isFavorite ? Colors.pink : Colors.grey.shade700,
              size: 26,
            ),
            tooltip: _isFavorite ? 'Bỏ yêu thích' : 'Thêm vào yêu thích',
          ),
          SizedBox(width: 8),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildDishHeader(),
                _buildVideoSection(),
                _buildIngredientsSection(),
                _buildHealthBenefitsSection(),
                _buildInstructionsSection(),
                SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildDishHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.shade200,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.restaurant_menu,
                color: Colors.grey.shade700,
                size: 28,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.dish.name,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              if (widget.dish.prepTimeInMinutes != null) ...[
                Icon(
                  Icons.access_time,
                  color: Colors.grey.shade600,
                  size: 18,
                ),
                SizedBox(width: 6),
                Text(
                  '${widget.dish.prepTimeInMinutes} phút',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(width: 20),
              ],
              Icon(
                Icons.restaurant,
                color: Colors.grey.shade600,
                size: 18,
              ),
              SizedBox(width: 6),
              Text(
                'Công thức nấu ăn',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }







  Widget _buildIngredientsSection() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.list_alt, color: Colors.grey.shade700, size: 22),
              SizedBox(width: 8),
              Text(
                'Nguyên liệu',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          _buildIngredientsList(),
        ],
      ),
    );
  }

  Widget _buildIngredientsList() {
    // Ưu tiên sử dụng detailedIngredients nếu có
    if (widget.dish.detailedIngredients.isNotEmpty) {
      return Column(
        children: widget.dish.detailedIngredients.map((ingredient) {
          return Container(
            margin: EdgeInsets.only(bottom: 8),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: DietPlanColors.primaryLight),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    ingredient.name,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ),
                Text(
                  ingredient.amount,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: DietPlanColors.primary,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      );
    } else {
      // Fallback về ingredients cũ
      return Column(
        children: widget.dish.ingredients.map((ingredient) {
          return Container(
            margin: EdgeInsets.only(bottom: 8),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: DietPlanColors.primaryLight),
            ),
            child: Row(
              children: [
                Icon(Icons.circle, size: 8, color: DietPlanColors.primary),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    ingredient,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      );
    }
  }

  Widget _buildInstructionsSection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.list_outlined, color: DietPlanColors.primary, size: 24),
              SizedBox(width: 8),
              Text(
                'Các bước thực hiện',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: DietPlanColors.primary,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.light(
                primary: DietPlanColors.primary,
              ),
            ),
            child: Stepper(
              currentStep: _currentStep,
              onStepTapped: (step) {
                setState(() {
                  _currentStep = step;
                });
              },
              controlsBuilder: (context, details) {
                return Row(
                  children: [
                    if (details.stepIndex < _parsedSteps.length - 1)
                      ElevatedButton(
                        onPressed: details.onStepContinue,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: DietPlanColors.primary,
                          foregroundColor: Colors.white,
                        ),
                        child: Text('Tiếp theo'),
                      ),
                    SizedBox(width: 8),
                    if (details.stepIndex > 0)
                      TextButton(
                        onPressed: details.onStepCancel,
                        child: Text(
                          'Quay lại',
                          style: TextStyle(color: DietPlanColors.primary),
                        ),
                      ),
                  ],
                );
              },
              onStepContinue: () {
                if (_currentStep < _parsedSteps.length - 1) {
                  setState(() {
                    _currentStep++;
                  });
                }
              },
              onStepCancel: () {
                if (_currentStep > 0) {
                  setState(() {
                    _currentStep--;
                  });
                }
              },
              steps: _parsedSteps.asMap().entries.map((entry) {
                int index = entry.key;
                String instruction = entry.value;

                return Step(
                  title: Text(
                    'Bước ${index + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: DietPlanColors.primary,
                    ),
                  ),
                  content: Text(
                    instruction,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade800,
                      height: 1.5,
                    ),
                  ),
                  isActive: _currentStep == index,
                  state: _currentStep > index
                      ? StepState.complete
                      : _currentStep == index
                          ? StepState.indexed
                          : StepState.disabled,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthBenefitsSection() {
    // Kiểm tra xem món ăn có lợi ích sức khỏe không
    if (widget.dish.healthBenefits == null || widget.dish.healthBenefits!.isEmpty) {
      return SizedBox.shrink(); // Không hiển thị gì nếu không có lợi ích
    }

    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.favorite, color: Colors.green.shade700, size: 22),
              SizedBox(width: 8),
              Text(
                'Lợi ích sức khỏe',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.green.shade700,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          _buildHealthBenefitsList(),
        ],
      ),
    );
  }

  Widget _buildHealthBenefitsList() {
    return Column(
      children: widget.dish.healthBenefits!.map((benefit) {
        return Container(
          margin: EdgeInsets.only(bottom: 12),
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.shade100),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.check_circle,
                  size: 16,
                  color: Colors.green.shade600,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  benefit,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey.shade800,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildVideoSection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: DietPlanColors.primaryLight,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border(
                bottom: BorderSide(
                  color: DietPlanColors.primary.withOpacity(0.3),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.play_circle_filled, color: DietPlanColors.primary, size: 24),
                SizedBox(width: 12),
                Text(
                  'Video hướng dẫn',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: DietPlanColors.primary,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16),
            child: _buildVideoPlayer(),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPlayer() {
    // Nếu đang hiển thị video player
    if (_showVideoPlayer && _youtubeController != null) {
      return Column(
        children: [
          // YouTube Player
          YoutubePlayer(
            controller: _youtubeController!,
            showVideoProgressIndicator: true,
            progressIndicatorColor: DietPlanColors.primary,
            progressColors: ProgressBarColors(
              playedColor: DietPlanColors.primary,
              handleColor: DietPlanColors.primaryDark,
            ),
          ),
          SizedBox(height: 16),
          // Video controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _showVideoPlayer = false;
                    _youtubeController?.dispose();
                    _youtubeController = null;
                  });
                },
                icon: Icon(Icons.close, size: 18),
                label: Text('Đóng video'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  print('🎬 User clicked "Video khác" button');
                  _searchYouTubeVideos(widget.dish.name);
                },
                icon: Icon(Icons.video_library, size: 18),
                label: Text('Video khác'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    // Tạo URL tìm kiếm YouTube dựa trên tên món ăn
    String searchQuery = widget.dish.name;

    return Container(
      height: 220,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.orange.shade700,
            Colors.orange.shade900,
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.3),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _isLoadingVideos ? null : () {
            print('🎬 User clicked video section for: ${widget.dish.name}');
            // Show video options in app for better UX
            _searchYouTubeVideos(widget.dish.name);
          },
          child: Center(
            child: _isLoadingVideos
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Đang tìm video hướng dẫn...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.video_library,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Xem video hướng dẫn',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Nhiều video từ các kênh uy tín',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 12),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.play_circle_filled,
                            color: Colors.white,
                            size: 16,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Chọn video để xem',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
          ),
        ),
      ),
    );
  }
}
