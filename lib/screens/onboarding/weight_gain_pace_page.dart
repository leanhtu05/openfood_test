import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_data_provider.dart';

class WeightGainPacePage extends StatefulWidget {
  const WeightGainPacePage({Key? key}) : super(key: key);

  @override
  State<WeightGainPacePage> createState() => _WeightGainPacePageState();
}

class _WeightGainPacePageState extends State<WeightGainPacePage> {
  double _pace = 0.5;

  @override
  Widget build(BuildContext context) {
    final userData = Provider.of<UserDataProvider>(context);
    final isWeightGain = userData.goal == 'Tăng cân';
    final isWeightLoss = userData.goal == 'Giảm cân';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Tốc độ thay đổi cân nặng', 
          style: TextStyle(color: Colors.black),
        ),
      ),
      body: LayoutBuilder(
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
                    Text(
                      isWeightGain
                          ? 'Bạn muốn tăng bao nhiêu kg mỗi tuần?'
                          : isWeightLoss
                              ? 'Bạn muốn giảm bao nhiêu kg mỗi tuần?'
                              : 'Bạn muốn duy trì cân nặng hiện tại?',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isWeightGain
                          ? 'Tăng cân quá nhanh có thể không tốt cho sức khỏe'
                          : isWeightLoss
                              ? 'Giảm cân quá nhanh có thể không tốt cho sức khỏe'
                              : 'Duy trì cân nặng hiện tại là một lựa chọn tốt',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    if (isWeightGain || isWeightLoss) ...[
                      const SizedBox(height: 32),
                      Center(
                        child: Text(
                          '${_pace.toStringAsFixed(2)} kg/tuần',
                          style: const TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 8.0,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 15.0),
                        ),
                        child: Slider(
                          value: _pace,
                          min: 0.25,
                          max: 1.0,
                          divisions: 3,
                          activeColor: Colors.green,
                          label: _pace.toStringAsFixed(2),
                          onChanged: (value) => setState(() => _pace = value),
                        ),
                      ),
                    ],
                    const SizedBox(height: 40),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Quay lại'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Provider.of<UserDataProvider>(context, listen: false)
                                .setPace(_pace);
                            Navigator.pushNamed(context, '/tdee-calculator');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                          ),
                          child: const Text('Tiếp tục'),
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
    );
  }
} 