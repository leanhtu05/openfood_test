import 'package:flutter/material.dart';
import '../services/meal_plan_video_service.dart';
import '../services/youtube_api_service.dart';
import 'enhanced_video_player_screen.dart';

class MealPlanVideosScreen extends StatefulWidget {
  const MealPlanVideosScreen({Key? key}) : super(key: key);

  @override
  _MealPlanVideosScreenState createState() => _MealPlanVideosScreenState();
}

class _MealPlanVideosScreenState extends State<MealPlanVideosScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final MealPlanVideoService _mealPlanVideoService = MealPlanVideoService();
  final YouTubeApiService _youtubeService = YouTubeApiService();

  List<Map<String, String>> _todayVideos = [];
  List<Map<String, String>> _weeklyVideos = [];
  List<Map<String, String>> _recommendedVideos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadVideos();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadVideos() async {
    setState(() => _isLoading = true);

    try {
      final today = _getCurrentDay();
      
      // Load videos for today
      final todayVideos = await _mealPlanVideoService.getVideosForDay(today);
      
      // Load weekly trending videos
      final weeklyVideos = await _mealPlanVideoService.getWeeklyTrendingVideos();
      
      // Load recommended videos
      final recommendedVideos = await _mealPlanVideoService.getRecommendedVideos();

      setState(() {
        _todayVideos = todayVideos;
        _weeklyVideos = weeklyVideos;
        _recommendedVideos = recommendedVideos;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading videos: $e');
      setState(() => _isLoading = false);
    }
  }

  String _getCurrentDay() {
    final weekdays = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    final today = DateTime.now().weekday - 1; // 0-6
    return weekdays[today];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Video Theo Kế Hoạch',
          style: TextStyle(
            color: Colors.orange.shade800,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.orange.shade800),
        actions: [
          IconButton(
            onPressed: _refreshVideos,
            icon: Icon(Icons.refresh),
            tooltip: 'Cập nhật video',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.orange.shade700,
          unselectedLabelColor: Colors.grey.shade600,
          indicatorColor: Colors.orange.shade700,
          tabs: [
            Tab(
              icon: Icon(Icons.today),
              text: 'Hôm nay',
            ),
            Tab(
              icon: Icon(Icons.trending_up),
              text: 'Tuần này',
            ),
            Tab(
              icon: Icon(Icons.recommend),
              text: 'Gợi ý',
            ),
          ],
        ),
      ),
      backgroundColor: Colors.grey.shade50,
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTodayVideosTab(),
                _buildWeeklyVideosTab(),
                _buildRecommendedVideosTab(),
              ],
            ),
    );
  }

  Widget _buildTodayVideosTab() {
    if (_todayVideos.isEmpty) {
      return _buildEmptyState(
        icon: Icons.today,
        title: 'Chưa có video cho hôm nay',
        subtitle: 'Thêm món ăn vào kế hoạch để xem video hướng dẫn',
        actionText: 'Cập nhật kế hoạch',
        onAction: () {
          // Navigate to meal plan screen
          Navigator.pushNamed(context, '/diet-plan');
        },
      );
    }

    return RefreshIndicator(
      onRefresh: _loadVideos,
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: _todayVideos.length,
        itemBuilder: (context, index) {
          final video = _todayVideos[index];
          return _buildVideoCard(video, showMealInfo: true);
        },
      ),
    );
  }

  Widget _buildWeeklyVideosTab() {
    if (_weeklyVideos.isEmpty) {
      return _buildEmptyState(
        icon: Icons.trending_up,
        title: 'Chưa có video trending',
        subtitle: 'Các video phổ biến trong tuần sẽ xuất hiện ở đây',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadVideos,
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: _weeklyVideos.length,
        itemBuilder: (context, index) {
          final video = _weeklyVideos[index];
          return _buildVideoCard(video, showStats: true);
        },
      ),
    );
  }

  Widget _buildRecommendedVideosTab() {
    if (_recommendedVideos.isEmpty) {
      return _buildEmptyState(
        icon: Icons.recommend,
        title: 'Chưa có video gợi ý',
        subtitle: 'Video gợi ý dựa trên sở thích của bạn',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadVideos,
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: _recommendedVideos.length,
        itemBuilder: (context, index) {
          final video = _recommendedVideos[index];
          return _buildVideoCard(video);
        },
      ),
    );
  }

  Widget _buildVideoCard(
    Map<String, String> video, {
    bool showMealInfo = false,
    bool showStats = false,
  }) {
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
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _playVideo(video),
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            children: [
              // Thumbnail
              Container(
                width: 120,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: LinearGradient(
                    colors: [Colors.orange.shade300, Colors.orange.shade600],
                  ),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Icon(
                        Icons.play_circle_filled,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                    if (video['duration'] != null)
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            video['duration']!,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(width: 12),
              // Video info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video['title'] ?? 'Video không có tiêu đề',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Text(
                      video['channel'] ?? 'Kênh không xác định',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    if (showMealInfo && video['dishName'] != null) ...[
                      SizedBox(height: 4),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_getMealTypeVietnamese(video['mealType'] ?? '')} - ${video['dishName']}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                    if (showStats && video['views'] != null) ...[
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.visibility, size: 14, color: Colors.grey.shade500),
                          SizedBox(width: 4),
                          Text(
                            video['views']!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    String? actionText,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 80,
              color: Colors.grey.shade400,
            ),
            SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
            if (actionText != null && onAction != null) ...[
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: Text(actionText),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getMealTypeVietnamese(String mealType) {
    switch (mealType.toLowerCase()) {
      case 'breakfast':
        return 'Sáng';
      case 'lunch':
        return 'Trưa';
      case 'dinner':
        return 'Tối';
      default:
        return mealType;
    }
  }

  void _playVideo(Map<String, String> video) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EnhancedVideoPlayerScreen(
          video: video,
          dishName: video['dishName'] ?? 'Món ăn',
        ),
      ),
    ).then((_) => _loadVideos()); // Refresh when returning
  }

  Future<void> _refreshVideos() async {
    await _mealPlanVideoService.forceUpdateVideos();
    await _loadVideos();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã cập nhật video mới'),
        backgroundColor: Colors.green,
      ),
    );
  }
}
