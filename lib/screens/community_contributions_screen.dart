import 'package:flutter/material.dart';
import '../services/vietnamese_food_price_service.dart';
import 'price_contribution_screen.dart';

class CommunityContributionsScreen extends StatefulWidget {
  const CommunityContributionsScreen({Key? key}) : super(key: key);

  @override
  State<CommunityContributionsScreen> createState() => _CommunityContributionsScreenState();
}

class _CommunityContributionsScreenState extends State<CommunityContributionsScreen>
    with SingleTickerProviderStateMixin {
  final VietnameseFoodPriceService _priceService = VietnameseFoodPriceService();
  
  late TabController _tabController;
  List<Map<String, dynamic>> _pendingContributions = [];
  List<Map<String, dynamic>> _approvedContributions = [];
  List<Map<String, dynamic>> _myContributions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadContributions();
  }

  Future<void> _loadContributions() async {
    setState(() => _isLoading = true);
    
    try {
      final pending = await _priceService.getUserPriceContributions(status: 'pending');
      final approved = await _priceService.getUserPriceContributions(status: 'approved');
      final my = await _priceService.getUserPriceContributions(); // TODO: Filter by current user
      
      setState(() {
        _pendingContributions = pending;
        _approvedContributions = approved;
        _myContributions = my;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Lỗi tải dữ liệu: $e');
    }
  }

  Future<void> _voteContribution(String contributionId, bool isUpvote) async {
    try {
      await _priceService.voteForPriceContribution(contributionId, isUpvote);
      _showSuccessSnackBar(isUpvote ? '👍 Đã vote tích cực' : '👎 Đã vote tiêu cực');
      _loadContributions(); // Refresh data
    } catch (e) {
      _showErrorSnackBar('Lỗi vote: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  String _formatCurrency(double amount) {
    return '${amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    )}₫';
  }

  String _formatDateTime(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      final dateTime = timestamp.toDate();
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'N/A';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đóng góp Cộng đồng'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Chờ duyệt', icon: Icon(Icons.pending)),
            Tab(text: 'Đã duyệt', icon: Icon(Icons.check_circle)),
            Tab(text: 'Của tôi', icon: Icon(Icons.person)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadContributions,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildContributionsList(_pendingContributions, showVoting: true),
                _buildContributionsList(_approvedContributions),
                _buildContributionsList(_myContributions, isMyContributions: true),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const PriceContributionScreen(),
            ),
          );
          if (result == true) {
            _loadContributions();
          }
        },
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Đóng góp giá'),
      ),
    );
  }

  Widget _buildContributionsList(
    List<Map<String, dynamic>> contributions, {
    bool showVoting = false,
    bool isMyContributions = false,
  }) {
    if (contributions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Chưa có đóng góp nào',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            if (isMyContributions) ...[
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PriceContributionScreen(),
                    ),
                  );
                  if (result == true) {
                    _loadContributions();
                  }
                },
                child: const Text('Đóng góp đầu tiên'),
              ),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadContributions,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: contributions.length,
        itemBuilder: (context, index) {
          final contribution = contributions[index];
          return _buildContributionCard(
            contribution,
            showVoting: showVoting,
            isMyContributions: isMyContributions,
          );
        },
      ),
    );
  }

  Widget _buildContributionCard(
    Map<String, dynamic> contribution, {
    bool showVoting = false,
    bool isMyContributions = false,
  }) {
    final foodName = contribution['food_name'] ?? '';
    final price = contribution['price']?.toDouble() ?? 0.0;
    final priceType = contribution['price_type'] ?? '';
    final location = contribution['location'] ?? '';
    final storeName = contribution['store_name'] ?? '';
    final userName = contribution['user_name'] ?? 'Ẩn danh';
    final votes = contribution['votes'] ?? 0;
    final status = contribution['status'] ?? '';
    final submittedAt = contribution['submitted_at'];

    Color statusColor = Colors.grey;
    IconData statusIcon = Icons.pending;
    
    switch (status) {
      case 'pending':
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        break;
      case 'approved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    foodName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 16, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        status == 'pending' ? 'Chờ duyệt' :
                        status == 'approved' ? 'Đã duyệt' : 'Từ chối',
                        style: TextStyle(
                          fontSize: 12,
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Price info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.attach_money, color: Colors.green[700]),
                  const SizedBox(width: 8),
                  Text(
                    _formatCurrency(price),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _getPriceTypeLabel(priceType),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.green[600],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Location and store
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '$storeName, $location',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // User and time
            Row(
              children: [
                Icon(Icons.person, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  userName,
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const Spacer(),
                Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  _formatDateTime(submittedAt),
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
            
            // Voting section
            if (showVoting) ...[
              const SizedBox(height: 12),
              const Divider(),
              Row(
                children: [
                  Text(
                    'Votes: $votes',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _voteContribution(contribution['id'], false),
                    icon: const Icon(Icons.thumb_down, size: 16),
                    label: const Text('Không chính xác'),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _voteContribution(contribution['id'], true),
                    icon: const Icon(Icons.thumb_up, size: 16),
                    label: const Text('Chính xác'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
            
            // Photo if available
            if (contribution['photo_url'] != null) ...[
              const SizedBox(height: 12),
              Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    contribution['photo_url'],
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[200],
                        child: const Center(
                          child: Icon(Icons.image_not_supported),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getPriceTypeLabel(String priceType) {
    switch (priceType) {
      case 'price_per_kg':
        return '/kg';
      case 'price_per_liter':
        return '/lít';
      case 'price_per_unit':
        return '/đơn vị';
      default:
        return '';
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
