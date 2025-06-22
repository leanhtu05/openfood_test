import 'package:flutter/material.dart';
import '../services/video_validation_service.dart';
import '../services/youtube_api_service.dart';
import 'enhanced_video_player_screen.dart';

class VideoTestScreen extends StatefulWidget {
  const VideoTestScreen({Key? key}) : super(key: key);

  @override
  _VideoTestScreenState createState() => _VideoTestScreenState();
}

class _VideoTestScreenState extends State<VideoTestScreen> {
  final VideoValidationService _validationService = VideoValidationService();
  final YouTubeApiService _youtubeService = YouTubeApiService();
  
  bool _isLoading = false;
  List<Map<String, String>> _testVideos = [];
  Map<String, bool> _validationResults = {};

  @override
  void initState() {
    super.initState();
    _loadTestVideos();
  }

  Future<void> _loadTestVideos() async {
    setState(() => _isLoading = true);
    
    try {
      // Lấy video demo an toàn
      final safeVideos = _validationService.getSafeDemoVideos();
      
      // Test video cho các món ăn
      final dishes = ['Phở Bò', 'Bún Chả', 'Cơm Tấm'];
      final List<Map<String, String>> allVideos = [];
      
      // Thêm safe demo videos
      allVideos.addAll(safeVideos);
      
      // Thêm video cho từng món ăn
      for (final dish in dishes) {
        final dishVideos = await _youtubeService.searchVideosForDish(dish);
        allVideos.addAll(dishVideos.take(1)); // Chỉ lấy 1 video per dish
      }
      
      setState(() {
        _testVideos = allVideos;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading test videos: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _validateAllVideos() async {
    setState(() => _isLoading = true);
    
    try {
      final results = <String, bool>{};
      
      for (final video in _testVideos) {
        final videoId = video['videoId']!;
        final isValid = await _validationService.isVideoIdValid(videoId);
        results[videoId] = isValid;
        
        // Update UI progressively
        setState(() {
          _validationResults = Map.from(results);
        });
        
        // Small delay to show progress
        await Future.delayed(Duration(milliseconds: 500));
      }
      
      setState(() => _isLoading = false);
    } catch (e) {
      print('Error validating videos: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Test Video Hoạt Động',
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
            onPressed: _isLoading ? null : _validateAllVideos,
            icon: Icon(Icons.check_circle),
            tooltip: 'Test tất cả video',
          ),
          IconButton(
            onPressed: _isLoading ? null : _loadTestVideos,
            icon: Icon(Icons.refresh),
            tooltip: 'Reload videos',
          ),
        ],
      ),
      backgroundColor: Colors.grey.shade50,
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Đang test video...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Header info
                Container(
                  padding: EdgeInsets.all(16),
                  margin: EdgeInsets.all(16),
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
                          Icon(Icons.play_circle_filled, color: Colors.white, size: 32),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Test Video Hoạt Động',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Kiểm tra video có phát được không',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildStatCard('Tổng video', '${_testVideos.length}', Colors.white),
                          _buildStatCard('Đã test', '${_validationResults.length}', Colors.white),
                          _buildStatCard('Hoạt động', '${_validationResults.values.where((v) => v).length}', Colors.green.shade300),
                        ],
                      ),
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
                      final videoId = video['videoId']!;
                      final isValidated = _validationResults.containsKey(videoId);
                      final isValid = _validationResults[videoId] ?? false;
                      
                      return _buildVideoTestCard(video, isValidated, isValid);
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildVideoTestCard(Map<String, String> video, bool isValidated, bool isValid) {
    final videoId = video['videoId']!;
    
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
        border: isValidated
            ? Border.all(
                color: isValid ? Colors.green : Colors.red,
                width: 2,
              )
            : null,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _playVideo(video),
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            children: [
              // Status indicator
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: isValidated
                      ? (isValid ? Colors.green : Colors.red)
                      : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Icon(
                  isValidated
                      ? (isValid ? Icons.check : Icons.close)
                      : Icons.help_outline,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              SizedBox(width: 12),
              
              // Video info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video['title']!,
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
                      'ID: $videoId',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                        fontFamily: 'monospace',
                      ),
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.account_circle, size: 14, color: Colors.grey.shade500),
                        SizedBox(width: 4),
                        Text(
                          video['channel']!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Spacer(),
                        if (video['duration'] != null)
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              video['duration']!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Play button
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.play_arrow,
                  color: Colors.orange.shade700,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _playVideo(Map<String, String> video) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EnhancedVideoPlayerScreen(
          video: video,
          dishName: video['title']!,
        ),
      ),
    );
  }
}
