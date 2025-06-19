import 'package:flutter/material.dart';
import '../routes/app_routes.dart';

/// Widget menu để truy cập các tính năng quản lý giá cả thực phẩm
class FoodPriceMenuWidget extends StatelessWidget {
  const FoodPriceMenuWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.attach_money,
                  color: Colors.green[700],
                  size: 28,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Quản lý Giá cả Thực phẩm',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Hệ thống quản lý giá cả thực phẩm Việt Nam với Firebase',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            
            // Menu Items
            _buildMenuItem(
              context,
              icon: Icons.price_check,
              title: 'Quản lý Giá cả',
              subtitle: 'Xem và quản lý giá cả thực phẩm',
              color: Colors.green,
              onTap: () => Navigator.pushNamed(context, AppRoutes.foodPriceManagement),
            ),
            
            const SizedBox(height: 12),
            
            _buildMenuItem(
              context,
              icon: Icons.analytics,
              title: 'Demo Phân tích Chi phí',
              subtitle: 'Xem demo tính toán chi phí grocery',
              color: Colors.blue,
              onTap: () => Navigator.pushNamed(context, AppRoutes.groceryCostDemo),
            ),
            
            const SizedBox(height: 12),
            
            _buildMenuItem(
              context,
              icon: Icons.people,
              title: 'Đóng góp Cộng đồng',
              subtitle: 'Xem và đóng góp giá cả từ cộng đồng',
              color: Colors.purple,
              onTap: () => Navigator.pushNamed(context, AppRoutes.communityContributions),
            ),

            const SizedBox(height: 12),

            _buildMenuItem(
              context,
              icon: Icons.add_circle,
              title: 'Đóng góp Giá mới',
              subtitle: 'Chia sẻ giá cả bạn biết',
              color: Colors.teal,
              onTap: () => Navigator.pushNamed(context, AppRoutes.priceContribution),
            ),

            const SizedBox(height: 12),

            _buildMenuItem(
              context,
              icon: Icons.psychology,
              title: 'AI Price Insights',
              subtitle: 'Phân tích thông minh với AI',
              color: Colors.purple,
              onTap: () => Navigator.pushNamed(context, AppRoutes.aiPriceInsights),
            ),

            const SizedBox(height: 12),

            _buildMenuItem(
              context,
              icon: Icons.trending_up,
              title: 'AI Dự đoán Giá',
              subtitle: 'Dự đoán xu hướng giá cả',
              color: Colors.indigo,
              onTap: () => Navigator.pushNamed(context, AppRoutes.aiPricePrediction),
            ),

            const SizedBox(height: 12),

            _buildMenuItem(
              context,
              icon: Icons.smart_toy,
              title: 'AI Tối ưu Grocery',
              subtitle: 'Tối ưu hóa danh sách mua sắm',
              color: Colors.teal,
              onTap: () => Navigator.pushNamed(context, AppRoutes.aiGroceryOptimizer),
            ),

            const SizedBox(height: 12),

            _buildMenuItem(
              context,
              icon: Icons.file_download,
              title: 'Export/Import Dữ liệu',
              subtitle: 'Xuất nhập dữ liệu giá cả',
              color: Colors.orange,
              onTap: () => Navigator.pushNamed(context, AppRoutes.foodPriceExport),
            ),
            
            const SizedBox(height: 16),
            
            // Quick Stats
            _buildQuickStats(),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Colors.blue[700],
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Thông tin Hệ thống',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildStatRow('Tổng số mặt hàng:', '150+ thực phẩm'),
          _buildStatRow('Danh mục:', '10 danh mục chính'),
          _buildStatRow('Cập nhật:', 'Thời gian thực'),
          _buildStatRow('Lưu trữ:', 'Firebase Cloud'),
          _buildStatRow('Đóng góp:', 'Cộng đồng'),
          _buildStatRow('AI Features:', 'Insights, Dự đoán, Tối ưu'),
          _buildStatRow('Tính năng:', 'Báo cáo, Vote, Lịch sử'),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget compact để hiển thị trong drawer hoặc menu nhỏ
class FoodPriceMenuCompact extends StatelessWidget {
  const FoodPriceMenuCompact({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      leading: Icon(
        Icons.attach_money,
        color: Colors.green[700],
      ),
      title: const Text('Quản lý Giá cả'),
      subtitle: const Text('Thực phẩm Việt Nam'),
      children: [
        ListTile(
          leading: const Icon(Icons.price_check, color: Colors.green),
          title: const Text('Quản lý Giá cả'),
          subtitle: const Text('Xem và cập nhật giá'),
          onTap: () => Navigator.pushNamed(context, AppRoutes.foodPriceManagement),
        ),
        ListTile(
          leading: const Icon(Icons.analytics, color: Colors.blue),
          title: const Text('Phân tích Chi phí'),
          subtitle: const Text('Demo tính toán grocery'),
          onTap: () => Navigator.pushNamed(context, AppRoutes.groceryCostDemo),
        ),
        ListTile(
          leading: const Icon(Icons.people, color: Colors.purple),
          title: const Text('Cộng đồng'),
          subtitle: const Text('Đóng góp và xem giá'),
          onTap: () => Navigator.pushNamed(context, AppRoutes.communityContributions),
        ),
        ListTile(
          leading: const Icon(Icons.add_circle, color: Colors.teal),
          title: const Text('Đóng góp giá'),
          subtitle: const Text('Chia sẻ giá bạn biết'),
          onTap: () => Navigator.pushNamed(context, AppRoutes.priceContribution),
        ),
        ListTile(
          leading: const Icon(Icons.psychology, color: Colors.purple),
          title: const Text('AI Insights'),
          subtitle: const Text('Phân tích thông minh'),
          onTap: () => Navigator.pushNamed(context, AppRoutes.aiPriceInsights),
        ),
        ListTile(
          leading: const Icon(Icons.trending_up, color: Colors.indigo),
          title: const Text('AI Dự đoán'),
          subtitle: const Text('Dự đoán xu hướng giá'),
          onTap: () => Navigator.pushNamed(context, AppRoutes.aiPricePrediction),
        ),
        ListTile(
          leading: const Icon(Icons.smart_toy, color: Colors.teal),
          title: const Text('AI Tối ưu'),
          subtitle: const Text('Tối ưu grocery list'),
          onTap: () => Navigator.pushNamed(context, AppRoutes.aiGroceryOptimizer),
        ),
        ListTile(
          leading: const Icon(Icons.file_download, color: Colors.orange),
          title: const Text('Export/Import'),
          subtitle: const Text('Xuất nhập dữ liệu'),
          onTap: () => Navigator.pushNamed(context, AppRoutes.foodPriceExport),
        ),
      ],
    );
  }
}

/// Widget floating action button để truy cập nhanh
class FoodPriceFloatingMenu extends StatefulWidget {
  const FoodPriceFloatingMenu({Key? key}) : super(key: key);

  @override
  State<FoodPriceFloatingMenu> createState() => _FoodPriceFloatingMenuState();
}

class _FoodPriceFloatingMenuState extends State<FoodPriceFloatingMenu>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Sub menu items
        AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return Transform.scale(
              scale: _animation.value,
              child: Opacity(
                opacity: _animation.value,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isExpanded) ...[
                      _buildSubMenuItem(
                        icon: Icons.file_download,
                        color: Colors.orange,
                        onPressed: () {
                          _toggleMenu();
                          Navigator.pushNamed(context, AppRoutes.foodPriceExport);
                        },
                      ),
                      const SizedBox(height: 8),
                      _buildSubMenuItem(
                        icon: Icons.analytics,
                        color: Colors.blue,
                        onPressed: () {
                          _toggleMenu();
                          Navigator.pushNamed(context, AppRoutes.groceryCostDemo);
                        },
                      ),
                      const SizedBox(height: 8),
                      _buildSubMenuItem(
                        icon: Icons.price_check,
                        color: Colors.green,
                        onPressed: () {
                          _toggleMenu();
                          Navigator.pushNamed(context, AppRoutes.foodPriceManagement);
                        },
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
        
        // Main FAB
        FloatingActionButton(
          onPressed: _toggleMenu,
          backgroundColor: Colors.green,
          child: AnimatedRotation(
            turns: _isExpanded ? 0.125 : 0,
            duration: const Duration(milliseconds: 300),
            child: Icon(
              _isExpanded ? Icons.close : Icons.attach_money,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubMenuItem({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return FloatingActionButton(
      mini: true,
      onPressed: onPressed,
      backgroundColor: color,
      heroTag: null,
      child: Icon(icon, color: Colors.white),
    );
  }
}
