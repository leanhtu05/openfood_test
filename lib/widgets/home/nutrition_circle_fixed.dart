
import 'package:flutter/material.dart';

Widget buildNutrientCircleFixed(
  String label,
  int percentage,
  String details,
  Color color
) {
  // Extract the values from details for better display
  final parts = details.split('/');
  final currentValue = parts[0].replaceAll(RegExp(r'[^0-9]'), ''); // Remove non-numeric characters
  final goalValue = parts[1].replaceAll(RegExp(r'g'), '').trim(); // Remove 'g' and trim
  
  return Container(
    width: 85,
    constraints: BoxConstraints(maxHeight: 170),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 70,
              height: 70,
              child: CircularProgressIndicator(
                value: percentage / 100,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(color),
                strokeWidth: 6,
              ),
            ),
            Text(
              '$percentage%',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
        SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
        ),
        SizedBox(height: 2),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '$currentValue/$goalValue${label == "Protein" || label == "Carbs" || label == "Chất béo" ? "g" : "kcal"}',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w500,
                fontSize: 11,
              ),
            ),
          ),
        ),
      ],
    ),
  );
} 