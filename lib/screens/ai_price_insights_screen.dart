import 'package:flutter/material.dart';
import '../services/price_ai_analysis_service.dart';

class AIPriceInsightsScreen extends StatefulWidget {
  const AIPriceInsightsScreen({Key? key}) : super(key: key);

  @override
  State<AIPriceInsightsScreen> createState() => _AIPriceInsightsScreenState();
}

class _AIPriceInsightsScreenState extends State<AIPriceInsightsScreen>
    with SingleTickerProviderStateMixin {
  final PriceAIAnalysisService _aiService = PriceAIAnalysisService();
  
  late TabController _tabController;
  bool _isLoading = false;
  
  Map<String, dynamic>? _trendAnalysis;
  Map<String, dynamic>? _seasonalAnalysis;
  Map<String, dynamic>? _marketInsights;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAllInsights();
  }

  Future<void> _loadAllInsights() async {
    setState(() => _isLoading = true);

    try {
      // Test backend connection first
      final isConnected = await _aiService.testConnection();
      if (!isConnected) {
        _showErrorSnackBar('⚠️ Không thể kết nối backend. Sử dụng dữ liệu fallback.');
      }

      final futures = await Future.wait([
        _aiService.analyzePriceTrends(),
        _aiService.analyzeSeasonalTrends(null),
        _aiService.generateMarketInsights(),
      ]);

      setState(() {
        _trendAnalysis = futures[0];
        _seasonalAnalysis = futures[1];
        _marketInsights = futures[2];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Lỗi tải insights: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Price Insights'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Xu hướng', icon: Icon(Icons.trending_up)),
            Tab(text: 'Mùa vụ', icon: Icon(Icons.eco)),
            Tab(text: 'Thị trường', icon: Icon(Icons.analytics)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllInsights,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('AI đang phân tích dữ liệu...'),
                ],
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTrendAnalysisTab(),
                _buildSeasonalAnalysisTab(),
                _buildMarketInsightsTab(),
              ],
            ),
    );
  }

  Widget _buildTrendAnalysisTab() {
    if (_trendAnalysis == null) {
      return const Center(child: Text('Không có dữ liệu xu hướng'));
    }

    final insights = _trendAnalysis!['insights'] as Map<String, dynamic>? ?? {};
    final recommendations = _trendAnalysis!['recommendations'] as List? ?? [];
    final priceAlerts = _trendAnalysis!['price_alerts'] as List? ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _buildSectionHeader(
            'Phân tích Xu hướng Giá',
            Icons.trending_up,
            Colors.blue,
          ),
          
          const SizedBox(height: 16),
          
          // Trend Overview
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tổng quan Xu hướng',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildTrendIndicator(insights['trend'] ?? 'stable'),
                  const SizedBox(height: 12),
                  if (insights['key_insights'] != null)
                    ...((insights['key_insights'] as List).map((insight) =>
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.insights, size: 16, color: Colors.blue),
                            const SizedBox(width: 8),
                            Expanded(child: Text(insight.toString())),
                          ],
                        ),
                      ),
                    )),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Recommendations
          if (recommendations.isNotEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Khuyến nghị AI',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    ...recommendations.map((rec) => _buildRecommendationItem(rec.toString())),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          // Price Alerts
          if (priceAlerts.isNotEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Cảnh báo Giá',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    ...priceAlerts.map((alert) => _buildAlertItem(alert)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSeasonalAnalysisTab() {
    if (_seasonalAnalysis == null) {
      return const Center(child: Text('Không có dữ liệu mùa vụ'));
    }

    final currentSeason = _seasonalAnalysis!['current_season'] ?? 'Không xác định';
    final seasonalFoods = _seasonalAnalysis!['seasonal_foods'] as List? ?? [];
    final buyingRecs = _seasonalAnalysis!['buying_recommendations'] as List? ?? [];
    final avoidBuying = _seasonalAnalysis!['avoid_buying'] as List? ?? [];
    final bestDeals = _seasonalAnalysis!['best_deals'] as List? ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _buildSectionHeader(
            'Phân tích Mùa vụ',
            Icons.eco,
            Colors.green,
          ),
          
          const SizedBox(height: 16),
          
          // Current Season
          Card(
            color: Colors.green[50],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, color: Colors.green[700], size: 32),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Mùa hiện tại',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      Text(
                        currentSeason,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Seasonal Foods
          if (seasonalFoods.isNotEmpty) ...[
            _buildSeasonalSection(
              'Thực phẩm theo mùa',
              seasonalFoods,
              Icons.restaurant,
              Colors.green,
            ),
            const SizedBox(height: 16),
          ],
          
          // Best Deals
          if (bestDeals.isNotEmpty) ...[
            _buildSeasonalSection(
              'Deals tốt nhất',
              bestDeals,
              Icons.local_offer,
              Colors.orange,
            ),
            const SizedBox(height: 16),
          ],
          
          // Buying Recommendations
          if (buyingRecs.isNotEmpty) ...[
            _buildSeasonalSection(
              'Nên mua ngay',
              buyingRecs,
              Icons.shopping_cart,
              Colors.blue,
            ),
            const SizedBox(height: 16),
          ],
          
          // Avoid Buying
          if (avoidBuying.isNotEmpty) ...[
            _buildSeasonalSection(
              'Nên tránh mua',
              avoidBuying,
              Icons.warning,
              Colors.red,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMarketInsightsTab() {
    if (_marketInsights == null) {
      return const Center(child: Text('Không có dữ liệu thị trường'));
    }

    final overview = _marketInsights!['market_overview'] ?? 'Đang cập nhật';
    final trending = _marketInsights!['trending'] as List? ?? [];
    final recommendations = _marketInsights!['recommendations'] as List? ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _buildSectionHeader(
            'Insights Thị trường',
            Icons.analytics,
            Colors.purple,
          ),
          
          const SizedBox(height: 16),
          
          // Market Overview
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tổng quan Thị trường',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    overview,
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Trending Foods
          if (trending.isNotEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Thực phẩm Trending',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: trending.map((item) => Chip(
                        label: Text(item.toString()),
                        backgroundColor: Colors.purple[100],
                        labelStyle: TextStyle(color: Colors.purple[700]),
                      )).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          // AI Recommendations
          if (recommendations.isNotEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Khuyến nghị Đầu tư',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    ...recommendations.map((rec) => _buildRecommendationItem(rec.toString())),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildTrendIndicator(String trend) {
    IconData icon;
    Color color;
    String label;
    
    switch (trend.toLowerCase()) {
      case 'increasing':
        icon = Icons.trending_up;
        color = Colors.red;
        label = 'Xu hướng tăng';
        break;
      case 'decreasing':
        icon = Icons.trending_down;
        color = Colors.green;
        label = 'Xu hướng giảm';
        break;
      default:
        icon = Icons.trending_flat;
        color = Colors.blue;
        label = 'Xu hướng ổn định';
    }
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationItem(String recommendation) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb, size: 16, color: Colors.amber[700]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              recommendation,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertItem(dynamic alert) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.warning, color: Colors.orange[700], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              alert.toString(),
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeasonalSection(
    String title,
    List items,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: items.map((item) => Chip(
                label: Text(item.toString()),
                backgroundColor: color.withOpacity(0.1),
                labelStyle: TextStyle(color: color),
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
