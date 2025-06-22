import 'package:flutter/material.dart';
import '../services/video_service.dart';
import 'enhanced_video_player_screen.dart';

class VideoLibraryScreen extends StatefulWidget {
  const VideoLibraryScreen({Key? key}) : super(key: key);

  @override
  _VideoLibraryScreenState createState() => _VideoLibraryScreenState();
}

class _VideoLibraryScreenState extends State<VideoLibraryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final VideoService _videoService = VideoService();

  List<Map<String, dynamic>> _favorites = [];
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    final favorites = await _videoService.getFavoriteVideos();
    final history = await _videoService.getWatchHistory();
    
    setState(() {
      _favorites = favorites;
      _history = history;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Thư viện Video',
          style: TextStyle(
            color: Colors.orange.shade800,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.orange.shade800),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.orange.shade700,
          unselectedLabelColor: Colors.grey.shade600,
          indicatorColor: Colors.orange.shade700,
          tabs: [
            Tab(
              icon: Icon(Icons.favorite),
              text: 'Yêu thích (${_favorites.length})',
            ),
            Tab(
              icon: Icon(Icons.history),
              text: 'Lịch sử (${_history.length})',
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
                _buildFavoritesTab(),
                _buildHistoryTab(),
              ],
            ),
    );
  }

  Widget _buildFavoritesTab() {
    if (_favorites.isEmpty) {
      return _buildEmptyState(
        icon: Icons.favorite_border,
        title: 'Chưa có video yêu thích',
        subtitle: 'Thêm video vào yêu thích để xem lại dễ dàng',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: _favorites.length,
        itemBuilder: (context, index) {
          final video = _favorites[index];
          return _buildVideoCard(
            video: video,
            showRemoveButton: true,
            onRemove: () => _removeFromFavorites(video['videoId']),
          );
        },
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (_history.isEmpty) {
      return _buildEmptyState(
        icon: Icons.history,
        title: 'Chưa có lịch sử xem',
        subtitle: 'Các video bạn đã xem sẽ xuất hiện ở đây',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: Column(
        children: [
          // Clear history button
          Container(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Lịch sử xem gần đây',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _clearHistory,
                  icon: Icon(Icons.clear_all, size: 18),
                  label: Text('Xóa tất cả'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red.shade600,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 16),
              itemCount: _history.length,
              itemBuilder: (context, index) {
                final video = _history[index];
                return _buildVideoCard(
                  video: video,
                  showWatchTime: true,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoCard({
    required Map<String, dynamic> video,
    bool showRemoveButton = false,
    bool showWatchTime = false,
    VoidCallback? onRemove,
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
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Icon(
                        Icons.play_circle_filled,
                        size: 40,
                        color: Colors.orange.shade600,
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
                            video['duration'],
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (showWatchTime && video['watchedAt'] != null)
                      Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          _formatWatchTime(video['watchedAt']),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Action button
              if (showRemoveButton && onRemove != null)
                IconButton(
                  onPressed: onRemove,
                  icon: Icon(Icons.favorite, color: Colors.red),
                  tooltip: 'Xóa khỏi yêu thích',
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
  }) {
    return Center(
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
        ],
      ),
    );
  }

  void _playVideo(Map<String, dynamic> video) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EnhancedVideoPlayerScreen(
          video: Map<String, String>.from(video),
          dishName: video['dishName'] ?? 'Món ăn',
        ),
      ),
    ).then((_) => _loadData()); // Refresh data when returning
  }

  void _removeFromFavorites(String videoId) async {
    final success = await _videoService.removeFromFavorites(videoId);
    if (success) {
      _loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã xóa khỏi yêu thích'),
          backgroundColor: Colors.orange.shade600,
        ),
      );
    }
  }

  void _clearHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Xóa lịch sử'),
        content: Text('Bạn có chắc chắn muốn xóa toàn bộ lịch sử xem?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _videoService.clearWatchHistory();
      _loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã xóa lịch sử xem'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }

  String _formatWatchTime(String isoString) {
    try {
      final watchTime = DateTime.parse(isoString);
      final now = DateTime.now();
      final difference = now.difference(watchTime);

      if (difference.inDays > 0) {
        return '${difference.inDays} ngày trước';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} giờ trước';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} phút trước';
      } else {
        return 'Vừa xem';
      }
    } catch (e) {
      return 'Không xác định';
    }
  }
}
