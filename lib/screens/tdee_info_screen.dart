import 'package:flutter/material.dart';
import '../widgets/tdee_summary_card.dart';

class TDEEInfoScreen extends StatelessWidget {
  const TDEEInfoScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông tin dinh dưỡng'),
        backgroundColor: Colors.green,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: const [
            TDEESummaryCard(),
            Padding(
              padding: EdgeInsets.all(16.0),
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Giải thích các chỉ số',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 16),
                      _buildInfoSection(title: 'BMR (Basal Metabolic Rate)', description: 'Là lượng calo cơ thể đốt cháy khi nghỉ ngơi hoàn toàn. Đây là năng lượng cần thiết để duy trì các chức năng cơ bản như hô hấp, tuần hoàn, và nhiệt độ cơ thể.'),
                      _buildInfoSection(title: 'TDEE (Total Daily Energy Expenditure)', description: 'Là tổng lượng calo cơ thể đốt cháy trong một ngày, bao gồm cả hoạt động thể chất và tiêu hóa thức ăn.'),
                      _buildInfoSection(title: 'Mục tiêu calo', description: 'Là lượng calo bạn nên tiêu thụ mỗi ngày để đạt được mục tiêu tăng/giảm/duy trì cân nặng.'),
                      _buildInfoSection(title: 'Phân chia macros', description: 'Là tỷ lệ phân chia các chất dinh dưỡng đa lượng (protein, carbs, fat) trong chế độ ăn của bạn.'),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _buildInfoSection extends StatelessWidget {
  final String title;
  final String description;

  const _buildInfoSection({
    Key? key,
    required this.title,
    required this.description,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
} 