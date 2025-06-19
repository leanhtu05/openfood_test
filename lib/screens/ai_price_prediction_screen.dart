import 'package:flutter/material.dart';
import '../services/price_ai_analysis_service.dart';
import '../services/vietnamese_food_price_service.dart';

class AIPricePredictionScreen extends StatefulWidget {
  const AIPricePredictionScreen({Key? key}) : super(key: key);

  @override
  State<AIPricePredictionScreen> createState() => _AIPricePredictionScreenState();
}

class _AIPricePredictionScreenState extends State<AIPricePredictionScreen> {
  final PriceAIAnalysisService _aiService = PriceAIAnalysisService();
  final VietnameseFoodPriceService _priceService = VietnameseFoodPriceService();
  
  final _searchController = TextEditingController();
  
  List<String> _allFoods = [];
  List<String> _filteredFoods = [];
  String? _selectedFood;
  int _predictionDays = 7;
  bool _isLoading = false;
  bool _isPredicting = false;
  Map<String, dynamic>? _prediction;

  @override
  void initState() {
    super.initState();
    _loadFoods();
  }

  Future<void> _loadFoods() async {
    setState(() => _isLoading = true);
    
    try {
      final prices = await _priceService.getAllPrices();
      final foods = prices.keys.toList()..sort();
      
      setState(() {
        _allFoods = foods;
        _filteredFoods = foods;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Lỗi tải danh sách thực phẩm: $e');
    }
  }

  void _filterFoods(String query) {
    setState(() {
      _filteredFoods = _allFoods
          .where((food) => food.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  Future<void> _predictPrice() async {
    if (_selectedFood == null) {
      _showErrorSnackBar('Vui lòng chọn thực phẩm');
      return;
    }
    
    setState(() => _isPredicting = true);
    
    try {
      final prediction = await _aiService.predictFuturePrices(
        foodName: _selectedFood!,
        daysAhead: _predictionDays,
      );
      
      setState(() {
        _prediction = prediction;
        _isPredicting = false;
      });
    } catch (e) {
      setState(() => _isPredicting = false);
      _showErrorSnackBar('Lỗi dự đoán giá: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  String _formatCurrency(double amount) {
    return '${amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    )}₫';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Dự đoán Giá'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Card(
                    color: Colors.indigo[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.psychology, color: Colors.indigo[700], size: 32),
                              const SizedBox(width: 12),
                              const Text(
                                'AI Dự đoán Giá cả',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Sử dụng AI để dự đoán xu hướng giá cả thực phẩm trong tương lai',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Food Selection
                  const Text(
                    'Chọn thực phẩm',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Tìm kiếm thực phẩm...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: _filterFoods,
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Food List
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.builder(
                      itemCount: _filteredFoods.length,
                      itemBuilder: (context, index) {
                        final food = _filteredFoods[index];
                        final isSelected = food == _selectedFood;
                        
                        return ListTile(
                          title: Text(food),
                          selected: isSelected,
                          selectedTileColor: Colors.indigo[50],
                          onTap: () {
                            setState(() {
                              _selectedFood = food;
                              _prediction = null; // Clear previous prediction
                            });
                          },
                          trailing: isSelected 
                              ? Icon(Icons.check, color: Colors.indigo[700])
                              : null,
                        );
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Prediction Period
                  const Text(
                    'Thời gian dự đoán',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: _predictionDays.toDouble(),
                          min: 1,
                          max: 30,
                          divisions: 29,
                          label: '$_predictionDays ngày',
                          onChanged: (value) {
                            setState(() {
                              _predictionDays = value.round();
                              _prediction = null; // Clear previous prediction
                            });
                          },
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.indigo[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$_predictionDays ngày',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Predict Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _selectedFood != null && !_isPredicting ? _predictPrice : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isPredicting
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text('AI đang phân tích...'),
                              ],
                            )
                          : const Text(
                              'Dự đoán Giá',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Prediction Results
                  if (_prediction != null) _buildPredictionResults(),
                ],
              ),
            ),
    );
  }

  Widget _buildPredictionResults() {
    final prediction = _prediction!;
    final foodName = prediction['food_name'] ?? '';
    final currentPrice = prediction['current_price']?.toDouble() ?? 0.0;
    final predictedPrice = prediction['predicted_price']?.toDouble() ?? 0.0;
    final confidence = prediction['confidence']?.toInt() ?? 0;
    final trend = prediction['trend'] ?? 'stable';
    final factors = prediction['factors'] as List? ?? [];
    final recommendation = prediction['recommendation'] ?? '';
    final priceRange = prediction['price_range'] as Map<String, dynamic>? ?? {};

    final priceChange = currentPrice > 0 
        ? ((predictedPrice - currentPrice) / currentPrice) * 100 
        : 0.0;

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.psychology, color: Colors.indigo[700]),
                const SizedBox(width: 8),
                const Text(
                  'Kết quả Dự đoán',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Food Name
            Text(
              foodName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            
            const SizedBox(height: 16),
            
            // Price Comparison
            Row(
              children: [
                Expanded(
                  child: _buildPriceCard(
                    'Giá hiện tại',
                    _formatCurrency(currentPrice),
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildPriceCard(
                    'Giá dự đoán',
                    _formatCurrency(predictedPrice),
                    _getTrendColor(trend),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Price Change
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getTrendColor(trend).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _getTrendColor(trend).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(_getTrendIcon(trend), color: _getTrendColor(trend)),
                  const SizedBox(width: 12),
                  Text(
                    '${priceChange >= 0 ? '+' : ''}${priceChange.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _getTrendColor(trend),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'trong $_predictionDays ngày tới',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Confidence
            Row(
              children: [
                const Text('Độ tin cậy: '),
                Text(
                  '$confidence%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _getConfidenceColor(confidence),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: LinearProgressIndicator(
                    value: confidence / 100,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(_getConfidenceColor(confidence)),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Price Range
            if (priceRange.isNotEmpty) ...[
              const Text(
                'Khoảng giá dự kiến:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                '${_formatCurrency(priceRange['min']?.toDouble() ?? 0)} - ${_formatCurrency(priceRange['max']?.toDouble() ?? 0)}',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
            ],
            
            // Factors
            if (factors.isNotEmpty) ...[
              const Text(
                'Yếu tố ảnh hưởng:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: factors.map((factor) => Chip(
                  label: Text(factor.toString()),
                  backgroundColor: Colors.grey[200],
                )).toList(),
              ),
              const SizedBox(height: 16),
            ],
            
            // Recommendation
            if (recommendation.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb, color: Colors.green[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        recommendation,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPriceCard(String title, String price, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          Text(
            price,
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

  Color _getTrendColor(String trend) {
    switch (trend.toLowerCase()) {
      case 'increasing':
        return Colors.red;
      case 'decreasing':
        return Colors.green;
      default:
        return Colors.blue;
    }
  }

  IconData _getTrendIcon(String trend) {
    switch (trend.toLowerCase()) {
      case 'increasing':
        return Icons.trending_up;
      case 'decreasing':
        return Icons.trending_down;
      default:
        return Icons.trending_flat;
    }
  }

  Color _getConfidenceColor(int confidence) {
    if (confidence >= 80) return Colors.green;
    if (confidence >= 60) return Colors.orange;
    return Colors.red;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
