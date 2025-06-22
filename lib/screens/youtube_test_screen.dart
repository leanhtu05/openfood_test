import 'package:flutter/material.dart';
import '../services/real_video_service.dart';

class YouTubeTestScreen extends StatefulWidget {
  @override
  _YouTubeTestScreenState createState() => _YouTubeTestScreenState();
}

class _YouTubeTestScreenState extends State<YouTubeTestScreen> {
  final RealVideoService _videoService = RealVideoService();
  List<Map<String, String>> _videos = [];
  bool _isLoading = false;
  String _status = '';
  bool _backendConnected = false;

  @override
  void initState() {
    super.initState();
    _testBackendConnection();
  }

  Future<void> _testBackendConnection() async {
    setState(() {
      _status = 'Testing backend connection...';
    });

    try {
      final isConnected = await _videoService.testBackendConnection();
      setState(() {
        _backendConnected = isConnected;
        _status = isConnected 
          ? '✅ Backend connected - Using secure proxy'
          : '❌ Backend unavailable - Using direct API fallback';
      });
    } catch (e) {
      setState(() {
        _backendConnected = false;
        _status = '❌ Connection test failed: $e';
      });
    }
  }

  Future<void> _searchVideos(String dishName) async {
    setState(() {
      _isLoading = true;
      _status = 'Searching videos for: $dishName';
      _videos = [];
    });

    try {
      final videos = await _videoService.getRealVideosForDish(dishName);
      setState(() {
        _videos = videos;
        _isLoading = false;
        _status = 'Found ${videos.length} videos for $dishName';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _status = 'Error: $e';
      });
    }
  }

  Future<void> _getCacheStats() async {
    try {
      final stats = await _videoService.getBackendCacheStats();
      if (stats != null) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Cache Statistics'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total entries: ${stats['total_entries']}'),
                Text('Valid entries: ${stats['valid_entries']}'),
                Text('Expired entries: ${stats['expired_entries']}'),
                Text('Cache duration: ${stats['cache_duration_hours']}h'),
                Text('Max cache size: ${stats['max_cache_size']}'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close'),
              ),
            ],
          ),
        );
      } else {
        setState(() {
          _status = 'Cache stats not available (backend offline)';
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Error getting cache stats: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('YouTube Backend Test'),
        backgroundColor: Colors.orange,
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Backend Status
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Backend Status',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          _backendConnected ? Icons.check_circle : Icons.error,
                          color: _backendConnected ? Colors.green : Colors.red,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _backendConnected 
                              ? 'Backend Connected (Secure)'
                              : 'Backend Offline (Fallback)',
                            style: TextStyle(
                              color: _backendConnected ? Colors.green : Colors.orange,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      _status,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 16),

            // Test Buttons
            Text(
              'Test Video Search',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: () => _searchVideos('Phở Bò'),
                  child: Text('Phở Bò'),
                ),
                ElevatedButton(
                  onPressed: () => _searchVideos('Cá hồi nướng với khoai lang và rau củ'),
                  child: Text('Cá hồi nướng'),
                ),
                ElevatedButton(
                  onPressed: () => _searchVideos('Bánh Mì Chả Cá Nha Trang'),
                  child: Text('Bánh Mì Chả Cá'),
                ),
                ElevatedButton(
                  onPressed: _testBackendConnection,
                  child: Text('Test Connection'),
                ),
                if (_backendConnected)
                  ElevatedButton(
                    onPressed: _getCacheStats,
                    child: Text('Cache Stats'),
                  ),
              ],
            ),

            SizedBox(height: 16),

            // Loading indicator
            if (_isLoading)
              Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 8),
                    Text('Searching videos...'),
                  ],
                ),
              ),

            // Video Results
            if (_videos.isNotEmpty) ...[
              Text(
                'Video Results (${_videos.length})',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: _videos.length,
                  itemBuilder: (context, index) {
                    final video = _videos[index];
                    return Card(
                      child: ListTile(
                        leading: video['thumbnail']?.isNotEmpty == true
                          ? Image.network(
                              video['thumbnail']!,
                              width: 80,
                              height: 60,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  width: 80,
                                  height: 60,
                                  color: Colors.grey[300],
                                  child: Icon(Icons.video_library),
                                ),
                            )
                          : Container(
                              width: 80,
                              height: 60,
                              color: Colors.grey[300],
                              child: Icon(Icons.video_library),
                            ),
                        title: Text(
                          video['title'] ?? 'No title',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Channel: ${video['channel'] ?? 'Unknown'}'),
                            Text('Duration: ${video['duration'] ?? 'N/A'} | Views: ${video['views'] ?? 'N/A'}'),
                            if (video['videoId'] == 'SEARCH_YOUTUBE')
                              Text(
                                'Search Video (Fallback)',
                                style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                              ),
                          ],
                        ),
                        onTap: () {
                          // Show video details
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text('Video Details'),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Title: ${video['title']}'),
                                  Text('Channel: ${video['channel']}'),
                                  Text('Duration: ${video['duration']}'),
                                  Text('Views: ${video['views']}'),
                                  Text('Video ID: ${video['videoId']}'),
                                  if (video['description'] != null)
                                    Text('Description: ${video['description']}'),
                                ],
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text('Close'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
