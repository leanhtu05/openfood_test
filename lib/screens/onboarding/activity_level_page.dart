import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_data_provider.dart';

class ActivityLevelPage extends StatefulWidget {
  const ActivityLevelPage({Key? key}) : super(key: key);

  @override
  _ActivityLevelPageState createState() => _ActivityLevelPageState();
}

class _ActivityLevelPageState extends State<ActivityLevelPage> {
  @override
  Widget build(BuildContext context) {
    final activityLevels = [
      {
        'title': 'Ít vận động',
        'description': 'Làm việc văn phòng, ít tập thể dục',
        'value': 'Ít vận động',
      },
      {
        'title': 'Hoạt động nhẹ',
        'description': 'Tập thể dục 1-3 lần/tuần',
        'value': 'Hoạt động nhẹ',
      },
      {
        'title': 'Hoạt động vừa phải',
        'description': 'Tập thể dục 3-5 lần/tuần',
        'value': 'Hoạt động vừa phải',
      },
      {
        'title': 'Rất năng động',
        'description': 'Tập thể dục 6-7 lần/tuần',
        'value': 'Rất năng động',
      },
    ];

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: Container(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Mức độ hoạt động của bạn?',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Chọn mức độ hoạt động phù hợp với lối sống của bạn',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 32),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: activityLevels.length,
                        itemBuilder: (context, index) {
                          final activity = activityLevels[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            child: ListTile(
                              title: Text(
                                activity['title']!,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(activity['description']!),
                              onTap: () {
                                // Lưu mức độ hoạt động vào UserDataProvider
                                Provider.of<UserDataProvider>(context, listen: false)
                                    .setActivityLevel(activity['value']!);
                                Navigator.pushNamed(context, '/goal');
                              },
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: const Text('Quay lại'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
        ),
      ),
    );
  }
} 