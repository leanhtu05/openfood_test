import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// Test backend encoding with Vietnamese text
void main() async {
  print('🧪 Testing Backend Encoding with Vietnamese Text');
  print('=' * 60);
  
  await testVietnameseEncoding();
}

Future<void> testVietnameseEncoding() async {
  const String baseUrl = 'https://backend-openfood.onrender.com';
  
  // Test dishes with Vietnamese characters
  final testDishes = [
    'Phở Bò',
    'Bánh Mì Chả Cá Nha Trang',
    'Cá hồi nướng với khoai lang và rau củ',
    'Bún Bò Huế',
    'Gỏi Cuốn Tôm Thịt',
  ];
  
  for (final dish in testDishes) {
    print('\n🍜 Testing dish: "$dish"');
    print('-' * 40);
    
    try {
      final url = Uri.parse('$baseUrl/youtube/search');
      
      // Ensure proper UTF-8 encoding
      final requestBody = {
        'query': dish.trim(),
        'max_results': 2,
        'duration': 'medium',
        'order': 'relevance',
      };
      
      print('📡 URL: $url');
      print('📦 Request: ${json.encode(requestBody)}');
      
      // Test encoding
      final encodedBody = utf8.encode(json.encode(requestBody));
      print('🔤 Encoded length: ${encodedBody.length} bytes');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json',
          'Accept-Charset': 'utf-8',
        },
        body: encodedBody,
      ).timeout(Duration(seconds: 30));
      
      print('📡 Response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        try {
          final data = json.decode(utf8.decode(response.bodyBytes));
          final videos = data['videos'] as List;
          final cached = data['cached'] ?? false;
          
          print('✅ SUCCESS! Found ${videos.length} videos');
          print('📦 Cached: $cached');
          
          if (videos.isNotEmpty) {
            final video = videos[0] as Map<String, dynamic>;
            print('📹 Sample: ${video['title']?.substring(0, 50) ?? 'No title'}...');
            print('   Channel: ${video['channel'] ?? 'Unknown'}');
            print('   Duration: ${video['duration'] ?? 'N/A'}');
            print('   Views: ${video['views'] ?? 'N/A'}');
          }
          
        } catch (parseError) {
          print('❌ JSON parse error: $parseError');
          print('Raw response: ${response.body.substring(0, 200)}...');
        }
        
      } else if (response.statusCode == 500) {
        print('❌ 500 Internal Server Error');
        try {
          final errorData = json.decode(response.body);
          print('Error details: ${errorData['detail'] ?? 'Unknown error'}');
        } catch (e) {
          print('Error text: ${response.body.substring(0, 200)}...');
        }
        
      } else {
        print('❌ HTTP ${response.statusCode}');
        print('Response: ${response.body.substring(0, 200)}...');
      }
      
    } catch (e) {
      print('❌ Request error: $e');
    }
    
    // Wait between requests
    await Future.delayed(Duration(seconds: 2));
  }
  
  // Test cache stats
  print('\n📊 Testing Cache Stats');
  print('-' * 40);
  
  try {
    final url = Uri.parse('$baseUrl/youtube/cache/stats');
    final response = await http.get(
      url,
      headers: {'Accept': 'application/json'},
    ).timeout(Duration(seconds: 10));
    
    print('📡 Cache stats: ${response.statusCode}');
    
    if (response.statusCode == 200) {
      final stats = json.decode(response.body);
      print('✅ Cache Statistics:');
      print('   Total entries: ${stats['total_entries']}');
      print('   Valid entries: ${stats['valid_entries']}');
      print('   Expired entries: ${stats['expired_entries']}');
      print('   Cache duration: ${stats['cache_duration_hours']}h');
    }
    
  } catch (e) {
    print('❌ Cache stats error: $e');
  }
  
  print('\n' + '=' * 60);
  print('🎯 Encoding Test Complete');
  print('💡 If all tests pass, Flutter app should work with backend');
  print('🔧 If 500 errors persist, backend needs encoding fixes');
}
