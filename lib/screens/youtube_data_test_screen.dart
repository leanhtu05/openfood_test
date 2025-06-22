import 'package:flutter/material.dart';
import '../services/real_video_service.dart';
import '../services/youtube_data_api_service.dart';

class YouTubeDataTestScreen extends StatefulWidget {
  const YouTubeDataTestScreen({Key? key}) : super(key: key);

  @override
  _YouTubeDataTestScreenState createState() => _YouTubeDataTestScreenState();
}

class _YouTubeDataTestScreenState extends State<YouTubeDataTestScreen> {
  final RealVideoService _realVideoService = RealVideoService();
  final YouTubeDataAPIService _youtubeDataAPI = YouTubeDataAPIService();
  
  List<Map<String, String>> _testVideos = [];
  bool _isLoading = false;
  String _status = 'Sẵn sàng test data thực từ YouTube';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Test YouTube Data Thực',
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
            onPressed: _testYouTubeDataAPI,
            icon: Icon(Icons.api),
            tooltip: 'Test YouTube Data API',
          ),
        ],
      ),
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          // Status Card
          Container(
            margin: EdgeInsets.all(16),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange.shade600, Colors.orange.shade800],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.info, color: Colors.white, size: 24),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Test Data Thực Từ YouTube',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Text(
                  _status,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildActionButton(
                      'Test Phở Bò',
                      Icons.restaurant,
                      () => _testDishVideos('Phở Bò'),
                    ),
                    _buildActionButton(
                      'Test Bún Chả',
                      Icons.ramen_dining,
                      () => _testDishVideos('Bún Chả'),
                    ),
                    _buildActionButton(
                      'Test API',
                      Icons.api,
                      _testYouTubeDataAPI,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Loading indicator
          if (_isLoading)
            Container(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 8),
                  Text('Đang lấy data thực từ YouTube...'),
                ],
              ),
            ),

          // Video list
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 16),
              itemCount: _testVideos.length,
              itemBuilder: (context, index) {
                final video = _testVideos[index];
                return _buildVideoCard(video);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: _isLoading ? null : onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label, style: TextStyle(fontSize: 12)),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white.withOpacity(0.2),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  Widget _buildVideoCard(Map<String, String> video) {
    final isRealData = video.containsKey('likes') || video['views'] != 'Đang tải...';
    
    return Container(
      margin: EdgeInsets.only(bottom: 12),
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
        border: Border.all(
          color: isRealData ? Colors.green : Colors.orange,
          width: 2,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with data source indicator
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isRealData ? Colors.green : Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isRealData ? 'DATA THỰC' : 'DATA GIẢ',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Spacer(),
                Text(
                  'ID: ${video['videoId']}',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade500,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),

            // Title
            Text(
              video['title'] ?? 'Không có tiêu đề',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 8),

            // Channel and stats
            Row(
              children: [
                Icon(Icons.account_circle, size: 16, color: Colors.grey.shade600),
                SizedBox(width: 4),
                Expanded(
                  child: Text(
                    video['channel'] ?? 'Kênh không xác định',
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
                    video['views']!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: 8),

            // Additional data (if available)
            if (video.containsKey('likes') || video.containsKey('duration'))
              Wrap(
                spacing: 8,
                children: [
                  if (video['duration'] != null)
                    _buildInfoChip(Icons.access_time, video['duration']!),
                  if (video['likes'] != null)
                    _buildInfoChip(Icons.thumb_up, video['likes']!),
                  if (video['publishedAt'] != null)
                    _buildInfoChip(Icons.calendar_today, _formatDate(video['publishedAt']!)),
                ],
              ),

            // Description
            if (video['description'] != null) ...[
              SizedBox(height: 8),
              Text(
                video['description']!,
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
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey.shade600),
          SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }

  Future<void> _testDishVideos(String dishName) async {
    setState(() {
      _isLoading = true;
      _status = 'Đang test data cho $dishName...';
      _testVideos.clear();
    });

    try {
      final videos = await _realVideoService.getRealVideosForDish(dishName);
      
      setState(() {
        _testVideos = videos;
        _status = 'Đã lấy ${videos.length} video cho $dishName';
        _isLoading = false;
      });

      // Show result
      final realDataCount = videos.where((v) => v.containsKey('likes') || v['views'] != 'Đang tải...').length;
      final fakeDataCount = videos.length - realDataCount;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ $realDataCount video data thực, $fakeDataCount video data giả'),
          backgroundColor: realDataCount > 0 ? Colors.green : Colors.orange,
        ),
      );

    } catch (e) {
      setState(() {
        _status = 'Lỗi: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _testYouTubeDataAPI() async {
    setState(() {
      _isLoading = true;
      _status = 'Đang test YouTube Data API...';
    });

    try {
      final isValid = await _youtubeDataAPI.isAPIKeyValid();
      
      if (isValid) {
        final testVideo = await _youtubeDataAPI.getVideoDetails('BlSpEbJ-o1g');
        
        setState(() {
          _status = 'YouTube Data API hoạt động! Video: ${testVideo?['title'] ?? 'Unknown'}';
          if (testVideo != null) {
            _testVideos = [testVideo];
          }
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ YouTube Data API hoạt động!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() {
          _status = 'YouTube Data API chưa được cấu hình hoặc không hợp lệ';
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ YouTube Data API chưa được cấu hình'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _status = 'Lỗi test API: $e';
        _isLoading = false;
      });
    }
  }
}
