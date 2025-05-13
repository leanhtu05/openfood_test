import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_data_provider.dart';
import '../utils/tdee_calculator.dart';

class TDEESummaryCard extends StatelessWidget {
  const TDEESummaryCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final userData = Provider.of<UserDataProvider>(context);
    
    final calculator = TDEECalculator(
      gender: userData.gender,
      age: userData.age,
      heightCm: userData.heightCm,
      weightKg: userData.weightKg,
      activityLevel: userData.activityLevel,
      goal: userData.goal,
      pace: userData.pace,
    );

    final bmr = calculator.calculateBMR();
    final tdee = calculator.calculateTDEE();
    final dailyCalories = calculator.calculateDailyCalories();
    final macros = calculator.calculateMacroDistribution();

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Thông tin dinh dưỡng',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.info_outline),
                  onPressed: () {
                    Navigator.pushNamed(context, '/tdee-calculator');
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow('BMR', '${bmr.round()} kcal'),
            _buildInfoRow('TDEE', '${tdee.round()} kcal'),
            _buildInfoRow(
              'Mục tiêu calo',
              '${dailyCalories.round()} kcal',
              isHighlighted: true,
            ),
            const Divider(height: 24),
            const Text(
              'Phân chia macros',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildMacroItem(
                    'Protein',
                    '${macros['protein']!.round()}g',
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildMacroItem(
                    'Carbs',
                    '${macros['carbs']!.round()}g',
                    Colors.orange,
                  ),
                ),
                Expanded(
                  child: _buildMacroItem(
                    'Fat',
                    '${macros['fat']!.round()}g',
                    Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isHighlighted = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16,
                color: isHighlighted ? Colors.green : Colors.grey[700],
                fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 16,
                color: isHighlighted ? Colors.green : Colors.black87,
                fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
} 