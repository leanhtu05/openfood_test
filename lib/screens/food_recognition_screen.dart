import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:openfood/models/food_item.dart';
import 'package:provider/provider.dart';
import 'package:openfood/models/food_entry.dart';
import 'package:openfood/models/nutrition_info.dart';
import 'package:openfood/providers/food_provider.dart';
import 'package:openfood/services/food_recognition_service.dart';
import 'package:openfood/services/food_database_service.dart';
import 'package:openfood/utils/food_data_adapter.dart';
import 'package:openfood/screens/food_nutrition_detail_screen.dart';
import 'package:shimmer/shimmer.dart';
import 'package:uuid/uuid.dart';

class FoodRecognitionScreen extends StatefulWidget {
  static const routeName = '/food-recognition';

  const FoodRecognitionScreen({Key? key}) : super(key: key);

  @override
  _FoodRecognitionScreenState createState() => _FoodRecognitionScreenState();
}

class _FoodRecognitionScreenState extends State<FoodRecognitionScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _imageFile;
  bool _isAnalyzing = false;
  bool _isSearching = false;
  String? _recognitionError;
  List<Map<String, dynamic>>? _detectedItems;
  List<String>? _allLabels;
  final TextEditingController _descriptionController = TextEditingController();
  NutritionInfo? _selectedNutritionInfo;
  
  final FoodRecognitionService _recognitionService = FoodRecognitionService();
  final FoodDatabaseService _databaseService = FoodDatabaseService();
  
  // Placeholder for search results
  List<Map<String, dynamic>> _searchResults = [];

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  // Take a photo with camera
  Future<void> _takePhoto() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      setState(() {
        _imageFile = File(image.path);
        _detectedItems = null;
        _allLabels = null;
        _recognitionError = null;
        _selectedNutritionInfo = null;
      });
      _analyzeImage();
    }
  }

  // Select photo from gallery
  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _imageFile = File(image.path);
        _detectedItems = null;
        _allLabels = null;
        _recognitionError = null;
        _selectedNutritionInfo = null;
      });
      _analyzeImage();
    }
  }

  // Analyze the selected image
  Future<void> _analyzeImage() async {
    if (_imageFile == null) return;

    setState(() {
      _isAnalyzing = true;
    });

    try {
      final recognizedFoods = await _recognitionService.recognizeFoodFromImage(_imageFile!);
      
      setState(() {
        _isAnalyzing = false;
        
        if (recognizedFoods.isNotEmpty) {
          // Convert the recognized foods to a format compatible with the rest of the code
          _detectedItems = recognizedFoods.map((name) => {
            'name': name,
            'confidence': 0.9, // Placeholder confidence
          }).toList();
          
          _allLabels = recognizedFoods;
          
          if (_detectedItems!.isNotEmpty) {
            // Pre-populate the description with the most confident food item
            _descriptionController.text = _detectedItems![0]['name'];
            // Get nutrition info for the top detected food
            _searchFoodDatabase(_detectedItems![0]['name']);
          }
        } else {
          _recognitionError = 'No food items detected';
          _allLabels = [];
        }
      });
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
        _recognitionError = 'Error: $e';
      });
    }
  }

  // Search the food database for the detected food item
  Future<void> _searchFoodDatabase(String query) async {
    setState(() {
      _isSearching = true;
    });

    try {
      final results = await _databaseService.searchFood(query);
      
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
      
      // If we got results, open the dialog to select the food
      if (results.isNotEmpty) {
        _showFoodSelectionDialog(results);
      }
    } catch (e) {
      setState(() {
        _isSearching = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error searching food database: $e'))
      );
    }
  }
  
  // Show a dialog to select the correct food item
  void _showFoodSelectionDialog(List<Map<String, dynamic>> foods) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Select the Correct Food'),
        content: Container(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: foods.length,
            itemBuilder: (ctx, index) {
              final food = foods[index];
              return ListTile(
                title: Text(food['description']),
                subtitle: food['brandName'] != null && food['brandName'] != '' 
                    ? Text(food['brandName']) 
                    : food['category'] != null ? Text(food['category']) : null,
                onTap: () {
                  Navigator.of(ctx).pop();
                  _getFoodDetails(food['fdcId']);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            child: Text('Cancel'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }
  
  // Get detailed nutrition info for a selected food
  Future<void> _getFoodDetails(String fdcId) async {
    setState(() {
      _isSearching = true;
    });
    
    try {
      final nutritionInfo = await _databaseService.getFoodDetails(fdcId);
      
      setState(() {
        _selectedNutritionInfo = nutritionInfo;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting food details: $e'))
      );
    }
  }
  
  // Save the food entry
  void _saveFoodEntry() {
    if (_descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a food description'))
      );
      return;
    }
    
    try {
      // Tạo đối tượng FoodEntry từ dữ liệu đã nhận dạng
      Map<String, dynamic>? nutritionData;
      if (_selectedNutritionInfo != null) {
        nutritionData = {
          'calories': _selectedNutritionInfo!.calories,
          'protein': _selectedNutritionInfo!.protein,
          'fat': _selectedNutritionInfo!.fat,
          'carbs': _selectedNutritionInfo!.carbs,
          'fiber': _selectedNutritionInfo!.fiber,
          'sugar': _selectedNutritionInfo!.sugar,
          'sodium': _selectedNutritionInfo!.sodium,
        };
      }
      
      List<String> recognizedItems = [_descriptionController.text];
      if (_allLabels != null && _allLabels!.isNotEmpty) {
        recognizedItems = _allLabels!;
      }
      
      final now = DateTime.now();
      final mealType = FoodDataAdapter.getMealTypeBasedOnTime(now);
      
      final foodEntry = FoodDataAdapter.createFromAIRecognition(
        recognizedItems: recognizedItems,
        nutritionData: nutritionData,
        imagePath: _imageFile?.path,
        dateTime: now,
        mealType: mealType,
      );
      
      // Chuyển đến màn hình chi tiết dinh dưỡng
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FoodNutritionDetailScreen(
            foodEntry: foodEntry,
            onSave: (updatedEntry) {
              // Lưu vào FoodProvider khi người dùng nhấn lưu
              final foodProvider = Provider.of<FoodProvider>(context, listen: false);
              foodProvider.addFoodEntry(
                description: updatedEntry.description, 
                items: updatedEntry.items,
                dateTime: updatedEntry.dateTime,
                mealType: updatedEntry.mealType,
                image: _imageFile,
              );
              Navigator.of(context).pop(true);
            },
          ),
        ),
      ).then((value) {
        if (value == true) {
          Navigator.of(context).pop(true);
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating food entry: $e'))
      );
    }
  }

  // Manual food search
  void _manualSearch() {
    if (_descriptionController.text.isNotEmpty) {
      _searchFoodDatabase(_descriptionController.text);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a food description to search'))
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('AI Food Recognition'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image selection area
            if (_imageFile == null)
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.photo_camera, size: 48, color: Colors.grey[400]),
                      SizedBox(height: 8),
                      Text('Take a photo or select from gallery', style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                ),
              )
            else
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      _imageFile!,
                      width: double.infinity,
                      height: 300,
                      fit: BoxFit.cover,
                    ),
                  ),
                  if (_isAnalyzing)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black54,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(color: Colors.white),
                              SizedBox(height: 16),
                              Text('Analyzing image...', style: TextStyle(color: Colors.white)),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            
            SizedBox(height: 16),
            
            // Image selection buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.camera_alt),
                    label: Text('Camera'),
                    onPressed: _takePhoto,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.photo_library),
                    label: Text('Gallery'),
                    onPressed: _pickImage,
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 24),
            
            // Analysis results
            if (_recognitionError != null)
              Card(
                color: Colors.red[50],
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recognition Error', 
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)
                      ),
                      SizedBox(height: 8),
                      Text(_recognitionError!),
                      if (_allLabels != null && _allLabels!.isNotEmpty) ...[
                        SizedBox(height: 12),
                        Text('Detected labels:'),
                        SizedBox(height: 4),
                        ...(_allLabels!.take(5).map((label) => Text('- $label')).toList()),
                      ],
                    ],
                  ),
                ),
              )
            else if (_detectedItems != null && _detectedItems!.isNotEmpty)
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Detected Food Items', style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 12),
                      ...(_detectedItems!.take(3).map((item) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(item['name']),
                        subtitle: Text('Confidence: ${(item['confidence'] * 100).toStringAsFixed(1)}%'),
                        trailing: TextButton(
                          child: Text('Select'),
                          onPressed: () {
                            _descriptionController.text = item['name'];
                            _searchFoodDatabase(item['name']);
                          },
                        ),
                      ))),
                    ],
                  ),
                ),
              ),
            
            SizedBox(height: 24),
            
            // Food description input
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Food Description',
                hintText: 'e.g., Apple, Chicken Salad',
                border: OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(Icons.search),
                  onPressed: _manualSearch,
                  tooltip: 'Search food database',
                ),
              ),
            ),
            
            SizedBox(height: 24),
            
            // Nutrition info card
            if (_selectedNutritionInfo != null)
              Card(
                elevation: 2,
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Nutrition Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      SizedBox(height: 8),
                      if (_selectedNutritionInfo!.servingSize != null)
                        Text('Serving: ${_selectedNutritionInfo!.servingSize}'),
                      SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _nutrientItem('Calories', '${_selectedNutritionInfo!.calories.toStringAsFixed(1)}', 'kcal'),
                          _nutrientItem('Protein', '${_selectedNutritionInfo!.protein.toStringAsFixed(1)}', 'g'),
                          _nutrientItem('Fat', '${_selectedNutritionInfo!.fat.toStringAsFixed(1)}', 'g'),
                        ],
                      ),
                      SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _nutrientItem('Carbs', '${_selectedNutritionInfo!.carbs.toStringAsFixed(1)}', 'g'),
                          _nutrientItem('Sugar', '${_selectedNutritionInfo!.sugar.toStringAsFixed(1)}', 'g'),
                          _nutrientItem('Fiber', '${_selectedNutritionInfo!.fiber.toStringAsFixed(1)}', 'g'),
                        ],
                      ),
                    ],
                  ),
                ),
              )
            else if (_isSearching)
              Shimmer.fromColors(
                baseColor: Colors.grey[300]!,
                highlightColor: Colors.grey[100]!,
                child: Card(
                  child: Container(
                    height: 150,
                    width: double.infinity,
                  ),
                ),
              ),
            
            SizedBox(height: 24),
            
            // Save button
            ElevatedButton(
              onPressed: _saveFoodEntry,
              child: Text('Save Food Entry'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Helper widget for displaying nutrition info
  Widget _nutrientItem(String label, String value, String unit) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        Text(
          unit,
          style: TextStyle(fontSize: 12),
        ),
      ],
    );
  }
} 