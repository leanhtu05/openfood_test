import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class VideoService {
  static const String _favoritesKey = 'favorite_videos';
  static const String _watchHistoryKey = 'watch_history';
  static const String _videoNotesKey = 'video_notes';

  // Singleton pattern
  static final VideoService _instance = VideoService._internal();
  factory VideoService() => _instance;
  VideoService._internal();

  // Favorite Videos Management
  Future<List<Map<String, dynamic>>> getFavoriteVideos() async {
    final prefs = await SharedPreferences.getInstance();
    final String? favoritesJson = prefs.getString(_favoritesKey);
    
    if (favoritesJson == null) return [];
    
    try {
      final List<dynamic> favoritesList = json.decode(favoritesJson);
      return favoritesList.cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error loading favorite videos: $e');
      return [];
    }
  }

  Future<bool> addToFavorites(Map<String, dynamic> video) async {
    try {
      final favorites = await getFavoriteVideos();
      
      // Check if already exists
      final exists = favorites.any((fav) => fav['videoId'] == video['videoId']);
      if (exists) return false;
      
      // Add timestamp
      video['addedAt'] = DateTime.now().toIso8601String();
      favorites.add(video);
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_favoritesKey, json.encode(favorites));
      
      return true;
    } catch (e) {
      print('Error adding to favorites: $e');
      return false;
    }
  }

  Future<bool> removeFromFavorites(String videoId) async {
    try {
      final favorites = await getFavoriteVideos();
      favorites.removeWhere((video) => video['videoId'] == videoId);
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_favoritesKey, json.encode(favorites));
      
      return true;
    } catch (e) {
      print('Error removing from favorites: $e');
      return false;
    }
  }

  Future<bool> isFavorite(String videoId) async {
    final favorites = await getFavoriteVideos();
    return favorites.any((video) => video['videoId'] == videoId);
  }

  // Watch History Management
  Future<List<Map<String, dynamic>>> getWatchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String? historyJson = prefs.getString(_watchHistoryKey);
    
    if (historyJson == null) return [];
    
    try {
      final List<dynamic> historyList = json.decode(historyJson);
      return historyList.cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error loading watch history: $e');
      return [];
    }
  }

  Future<void> addToWatchHistory(Map<String, dynamic> video) async {
    try {
      final history = await getWatchHistory();
      
      // Remove if already exists to avoid duplicates
      history.removeWhere((item) => item['videoId'] == video['videoId']);
      
      // Add to beginning with timestamp
      video['watchedAt'] = DateTime.now().toIso8601String();
      history.insert(0, video);
      
      // Keep only last 50 items
      if (history.length > 50) {
        history.removeRange(50, history.length);
      }
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_watchHistoryKey, json.encode(history));
    } catch (e) {
      print('Error adding to watch history: $e');
    }
  }

  Future<void> clearWatchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_watchHistoryKey);
    } catch (e) {
      print('Error clearing watch history: $e');
    }
  }

  // Video Notes Management
  Future<Map<String, String>> getVideoNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final String? notesJson = prefs.getString(_videoNotesKey);
    
    if (notesJson == null) return {};
    
    try {
      final Map<String, dynamic> notesMap = json.decode(notesJson);
      return notesMap.cast<String, String>();
    } catch (e) {
      print('Error loading video notes: $e');
      return {};
    }
  }

  Future<String?> getVideoNote(String videoId) async {
    final notes = await getVideoNotes();
    return notes[videoId];
  }

  Future<bool> saveVideoNote(String videoId, String note) async {
    try {
      final notes = await getVideoNotes();
      
      if (note.trim().isEmpty) {
        notes.remove(videoId);
      } else {
        notes[videoId] = note;
      }
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_videoNotesKey, json.encode(notes));
      
      return true;
    } catch (e) {
      print('Error saving video note: $e');
      return false;
    }
  }

  // Search suggestions based on history
  Future<List<String>> getSearchSuggestions() async {
    final history = await getWatchHistory();
    final Set<String> suggestions = {};
    
    for (final video in history) {
      final title = video['title'] as String?;
      if (title != null) {
        // Extract keywords from title
        final words = title.toLowerCase().split(' ');
        for (final word in words) {
          if (word.length > 3 && !_isStopWord(word)) {
            suggestions.add(word);
          }
        }
      }
    }
    
    return suggestions.take(10).toList();
  }

  bool _isStopWord(String word) {
    const stopWords = [
      'cách', 'làm', 'nấu', 'với', 'của', 'trong', 'trên', 'dưới',
      'và', 'hoặc', 'nhưng', 'để', 'từ', 'cho', 'về', 'theo',
      'the', 'and', 'or', 'but', 'to', 'from', 'for', 'with'
    ];
    return stopWords.contains(word.toLowerCase());
  }

  // Get recommended videos based on favorites and history
  Future<List<String>> getRecommendedKeywords() async {
    final favorites = await getFavoriteVideos();
    final history = await getWatchHistory();
    
    final Map<String, int> keywordCount = {};
    
    // Analyze favorites (higher weight)
    for (final video in favorites) {
      _extractKeywords(video['title'] as String? ?? '', keywordCount, weight: 3);
    }
    
    // Analyze recent history
    for (final video in history.take(20)) {
      _extractKeywords(video['title'] as String? ?? '', keywordCount, weight: 1);
    }
    
    // Sort by frequency and return top keywords
    final sortedKeywords = keywordCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sortedKeywords.take(5).map((e) => e.key).toList();
  }

  void _extractKeywords(String title, Map<String, int> keywordCount, {int weight = 1}) {
    final words = title.toLowerCase().split(' ');
    for (final word in words) {
      if (word.length > 3 && !_isStopWord(word)) {
        keywordCount[word] = (keywordCount[word] ?? 0) + weight;
      }
    }
  }
}
