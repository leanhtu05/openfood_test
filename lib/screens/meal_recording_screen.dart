import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:math' as math;
import '../widgets/day_selector.dart';
import '../widgets/food_nutrition/header_food_info_card.dart';
import '../widgets/food_nutrition/nutrition_circle_detail.dart';
import '../widgets/food_nutrition/nutrition_circle.dart';
import '../providers/food_provider.dart';
import '../providers/user_data_provider.dart';
import '../providers/exercise_provider.dart';
import '../providers/water_provider.dart';
import '../models/food_entry.dart';
import '../models/food_item.dart';
import '../utils/constants.dart';
import '../screens/food_nutrition_detail_screen.dart';
import '../widgets/food_logging/barcode_scanner_button.dart';
import 'package:uuid/uuid.dart';
import '../screens/combined_history_screen.dart';
import 'package:firebase_storage/firebase_storage.dart';
// Meal plan imports removed

// PageTransformer tùy chỉnh để tạo hiệu ứng Coverflow 3D
class CoverflowPageTransformer extends PageTransformer {
  final double viewportFraction;
  final double depth;
  final double scale;

  CoverflowPageTransformer({
    this.viewportFraction = 0.8,
    this.depth = 0.001,
    this.scale = 0.15,
  });

  @override
  Widget transform(Widget child, TransformInfo info) {
    final position = info.position;
    final pageWidth = info.width;
    final pageHeight = info.height;

    // Với hiệu ứng toàn màn hình, giảm các hiệu ứng biến đổi
    // để các thẻ không biến dạng quá mức
    final absolutePosition = position.abs();
    final relativePosition = absolutePosition;
    final scaleEffect = 1 - (scale * relativePosition);

    // Giảm góc xoay cho thẻ toàn màn hình để không cảm thấy quá méo
    final rotationY = position * 0.5;

    // Điều chỉnh độ mờ cho phù hợp
    final opacity = 1.0 - (0.2 * relativePosition);

    // Ma trận biến đổi 3D đơn giản hơn
    final transform = Matrix4.identity()
      ..setEntry(3, 2, depth)
      ..rotateY(rotationY)
      ..scale(scaleEffect, scaleEffect);

    // Dịch chuyển Z nhẹ hơn vì thẻ đã lớn
    final zOffset = -pageHeight * 0.08 * absolutePosition;
    transform.translate(0.0, 0.0, zOffset);

    // Không nghiêng theo trục X với thẻ toàn màn hình

    return Transform(
      transform: transform,
      alignment: Alignment.center,
      child: Opacity(
        opacity: opacity,
        child: child,
      ),
    );
  }
}

// Lớp TransformInfo để cung cấp thông tin biến đổi
class TransformInfo {
  final double position;
  final double width;
  final double height;

  TransformInfo({
    required this.position,
    required this.width,
    required this.height,
  });
}

// Lớp PageTransformer để biến đổi từng trang
abstract class PageTransformer {
  Widget transform(Widget child, TransformInfo info);
}

// Widget PageViewTransformer
class PageViewTransformer extends StatelessWidget {
  final PageController pageController;
  final PageTransformer transformer;
  final IndexedWidgetBuilder itemBuilder;
  final int itemCount;
  final OnPageChanged? onPageChanged;
  final bool reverse;

  const PageViewTransformer({
    Key? key,
    required this.pageController,
    required this.transformer,
    required this.itemBuilder,
    required this.itemCount,
    this.onPageChanged,
    this.reverse = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: pageController,
      itemCount: itemCount,
      reverse: reverse,
      onPageChanged: onPageChanged,
      physics: BouncingScrollPhysics(),
      pageSnapping: true,
      padEnds: false, // Tắt padEnds để thẻ lấp đầy toàn bộ màn hình
      itemBuilder: (context, index) {
        return AnimatedBuilder(
          animation: pageController,
          builder: (context, child) {
            final pageOffset = pageController.hasClients
                ? (pageController.page ?? 0) - index
                : (pageController.initialPage - index).toDouble();

            final transformInfo = TransformInfo(
              position: pageOffset,
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height,
            );

            return transformer.transform(
              itemBuilder(context, index),
              transformInfo,
            );
          },
        );
      },
    );
  }
}

// Widget thẻ món ăn hiện đại
class EnhancedFoodCard extends StatelessWidget {
  final FoodEntry foodEntry;
  final double servingSize;
  final double caloriesGoal;
  final double proteinGoal;
  final double fatGoal;
  final double carbsGoal;
  final VoidCallback onTap;
  final Function(double)? onServingSizeChanged;
  final VoidCallback? onDelete;
  final VoidCallback? onAddImage; // Thêm callback mới để thêm ảnh

  const EnhancedFoodCard({
    Key? key,
    required this.foodEntry,
    required this.servingSize,
    required this.caloriesGoal,
    required this.proteinGoal,
    required this.fatGoal,
    required this.carbsGoal,
    required this.onTap,
    this.onServingSizeChanged,
    this.onDelete,
    this.onAddImage, // Thêm tham số onAddImage
  }) : super(key: key);

  // Getter để trả về giá trị servingSize hiệu quả
  double get effectiveServingSize => servingSize <= 0 ? 1.0 : servingSize;

  @override
  Widget build(BuildContext context) {
    // Tính toán giá trị dinh dưỡng
    final nutritionValues = foodEntry.calculateNutritionFromAPI();
    final calories = (nutritionValues['calories']!).toInt();
    final protein = (nutritionValues['protein']!).toInt();
    final fat = (nutritionValues['fat']!).toInt();
    final carbs = (nutritionValues['carbs']!).toInt();

    // Chuyển đổi thành % của mục tiêu
    final caloriePercent = (calories / caloriesGoal * 100).clamp(0.0, 100.0);
    final hasImageUrl = foodEntry.imageUrl != null && foodEntry.imageUrl!.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.zero, // Xóa bo góc để lấp đầy màn hình
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 15,
              offset: Offset(0, 5),
              spreadRadius: 1,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        width: double.infinity, // Chiếm toàn bộ chiều rộng có sẵn
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Phần trên với hình ảnh hoặc gradient - tăng chiều cao theo yêu cầu
            Container(
              height: 200, // Tăng chiều cao lên 200px theo yêu cầu
              child: ClipRRect(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                child: _buildImageSection(),
              ),
            ),

            // Phần dưới với thông tin món ăn - sử dụng Container với chiều cao cố định
            Container(
              height: 120, // Đặt chiều cao cố định để đảm bảo hiển thị đầy đủ
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween, // Phân bố đều các phần tử
                children: [
                  // Thời gian và Loại bữa ăn
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Thời gian
                      Row(
                        children: [
                          Icon(Icons.access_time,
                              size: 12, color: Colors.grey.shade600),
                          SizedBox(width: 4),
                          Text(
                            _formatTimeOnly(foodEntry.dateTime),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),

                      // Loại bữa ăn
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          foodEntry.mealType,
                          style: TextStyle(
                            color: Colors.green.shade800,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Hiển thị các món ăn dưới dạng chips
                  if (foodEntry.items.isNotEmpty)
                    _buildFoodItemChips(foodEntry.items),

                  // Thông tin dinh dưỡng
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Calories
                      _buildCalorieInfo(calories),

                      // Phân cách
                      Container(
                        height: 35,
                        width: 1,
                        color: Colors.grey.shade200,
                      ),

                      // Macros
                      Row(
                        children: [
                          _buildMacroInfo("P", protein, Colors.blue),
                          SizedBox(width: 10),
                          _buildMacroInfo("C", carbs, Colors.green),
                          SizedBox(width: 10),
                          _buildMacroInfo("F", fat, Colors.orange.shade700),
                        ],
                      ),
                    ],
                  ),

                  // Progress bar calories
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: caloriePercent / 100,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          caloriePercent > 90 ? Colors.red : Colors.green),
                      minHeight: 5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget hiển thị hình ảnh
  Widget _buildImageSection() {
    // Ưu tiên lấy ảnh từ FoodEntry trước, sau đó từ item đầu tiên
    String? imageUrl = foodEntry.imageUrl;
    String? imagePath = foodEntry.imagePath;

    // Nếu FoodEntry chính không có ảnh, thử lấy từ item đầu tiên
    if ((imageUrl == null || imageUrl.isEmpty) &&
        (imagePath == null || imagePath.isEmpty) &&
        foodEntry.items.isNotEmpty) {
      imageUrl = foodEntry.items.first.imageUrl;
      print('DEBUG IMAGE - Sử dụng ảnh từ item đầu tiên: $imageUrl');
    }

    final hasImageUrl = imageUrl != null && imageUrl.isNotEmpty;
    final hasImagePath = imagePath != null && imagePath.isNotEmpty;

    // Ghi log để debug
    print('DEBUG IMAGE - Entry ID: ${foodEntry.id}');
    print('DEBUG IMAGE - Description: ${foodEntry.description}');
    print('DEBUG IMAGE - Final ImageUrl: "$imageUrl"');
    print('DEBUG IMAGE - Final ImagePath: "$imagePath"');
    print('DEBUG IMAGE - Has ImageUrl: $hasImageUrl');
    print('DEBUG IMAGE - Has ImagePath: $hasImagePath');
    print('DEBUG IMAGE - Items count: ${foodEntry.items.length}');

    // Đảm bảo URL có định dạng đúng nếu là gs://
    if (imageUrl != null && imageUrl.startsWith('gs://')) {
      print('DEBUG IMAGE - URL là định dạng gs://, cần phải có getDownloadURL');
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Hiển thị ảnh từ Firebase Storage nếu có URL
        if (hasImageUrl)
          Stack(
            fit: StackFit.expand,
            children: [
              _buildNetworkOrFileImage(imageUrl!),
              // Thêm indicator hiển thị nguồn ảnh
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_done, size: 12, color: Colors.green),
                      SizedBox(width: 4),
                      Text(
                        'Cloud',
                        style: TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          )
        // Nếu không có URL nhưng có đường dẫn local
        else if (hasImagePath)
          Stack(
            fit: StackFit.expand,
            children: [
              _buildNetworkOrFileImage(imagePath!),
              // Thêm indicator hiển thị nguồn ảnh
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.folder, size: 12, color: Colors.orange),
                      SizedBox(width: 4),
                      Text(
                        'Local',
                        style: TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          )
        // Nếu không có ảnh nào
        else
          _buildGradientSection(),

        // Lớp phủ gradient
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.3),
                ],
                stops: [0.7, 1.0],
              ),
            ),
          ),
        ),

        // Nút xóa ở góc trên bên phải
        if (onDelete != null)
          Positioned(
            top: 8,
            right: 8,
            child: ClipOval(
              child: Material(
                color: Colors.white.withOpacity(0.7),
                child: InkWell(
                  onTap: onDelete,
                  child: Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.delete,
                        size: 16, color: Colors.red.shade700),
                  ),
                ),
              ),
            ),
          ),

        // Nút thêm ảnh ở góc dưới bên phải
        if (onAddImage != null && (!hasImageUrl && !hasImagePath))
          Positioned(
            bottom: 8,
            right: 8,
            child: ClipOval(
              child: Material(
                color: Colors.white.withOpacity(0.7),
                child: InkWell(
                  onTap: onAddImage,
                  child: Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.add_a_photo,
                        size: 16, color: Colors.blue.shade700),
                  ),
                ),
              ),
            ),
          ),

        // Nút thay đổi ảnh nếu đã có ảnh
        if (onAddImage != null && (hasImageUrl || hasImagePath))
          Positioned(
            bottom: 8,
            right: 8,
            child: ClipOval(
              child: Material(
                color: Colors.white.withOpacity(0.7),
                child: InkWell(
                  onTap: onAddImage,
                  child: Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.camera_alt,
                        size: 16, color: Colors.green.shade700),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
  
  // Phương thức mới để xử lý các loại URL hình ảnh
  Widget _buildNetworkOrFileImage(String url) {
    // Kiểm tra xem URL có phải là URL mạng hay không
    if (url.startsWith('http://') || url.startsWith('https://')) {
      print('DEBUG IMAGE - Xử lý URL mạng: $url');
      return Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Image.network(
          url,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) {
              print('DEBUG IMAGE - Đã tải thành công ảnh từ URL: $url');
              return child;
            }
            print('DEBUG IMAGE - Loading image from URL: $url');
            return Stack(
              fit: StackFit.expand,
              children: [
                _buildGradientSection(),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                          strokeWidth: 3,
                          backgroundColor: Colors.white.withOpacity(0.3),
                        ),
                      ),
                      SizedBox(height: 8),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Đang tải ảnh...',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
          errorBuilder: (context, error, stackTrace) {
            print('DEBUG IMAGE - Error loading from URL: $error');
            return _buildGradientSection();
          },
        ),
      );
    } 
    // Xử lý URL Firebase Storage (gs://)
    else if (url.startsWith('gs://')) {
      print('DEBUG IMAGE - Phát hiện gs:// URL, cần chuyển đổi: $url');
      // Hiển thị gradient trước khi lấy được URL tải xuống
      return FutureBuilder<String>(
        future: _getDownloadUrl(url),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            print('DEBUG IMAGE - Đang chờ chuyển đổi gs:// URL: $url');
            return Stack(
              fit: StackFit.expand,
              children: [
                _buildGradientSection(),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                          strokeWidth: 3,
                          backgroundColor: Colors.white.withOpacity(0.3),
                        ),
                      ),
                      SizedBox(height: 8),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Đang chuyển đổi URL...',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          } else if (snapshot.hasError || !snapshot.hasData) {
            print('DEBUG IMAGE - Lỗi khi chuyển đổi gs:// URL: ${snapshot.error}');
            return _buildGradientSection();
          } else {
            final downloadUrl = snapshot.data!;
            print('DEBUG IMAGE - Đã chuyển đổi gs:// thành URL: $downloadUrl');
            return Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Image.network(
                downloadUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (context, error, stackTrace) {
                  print('DEBUG IMAGE - Error loading from converted URL: $error');
                  return _buildGradientSection();
                },
              ),
            );
          }
        },
      );
    }
    // Kiểm tra URL file://
    else if (url.startsWith('file://')) {
      print('DEBUG IMAGE - Xử lý URL file:// bằng cách chuyển đổi: $url');
      String filePath = url.replaceFirst('file://', '');
      return Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Image.file(
          File(filePath),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (context, error, stackTrace) {
            print('DEBUG IMAGE - Error loading from file:// URL: $error');
            return _buildGradientSection();
          },
        ),
      );
    }
    // Đường dẫn local thông thường
    else {
      print('DEBUG IMAGE - Xử lý đường dẫn local: $url');
      return Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Image.file(
          File(url),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (context, error, stackTrace) {
            print('DEBUG IMAGE - Error loading from local file: $error');
            return _buildGradientSection();
          },
        ),
      );
    }
  }
  
  // Helper method to get download URL from Firebase Storage gs:// URL
  Future<String> _getDownloadUrl(String gsUrl) async {
    try {
      final storage = FirebaseStorage.instance;
      final ref = storage.refFromURL(gsUrl);
      final downloadUrl = await ref.getDownloadURL();
      print('DEBUG IMAGE - Converted gs:// URL to https://: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('DEBUG IMAGE - Error converting gs:// URL: $e');
      throw e;
    }
  }

  // Widget hiển thị gradient khi không có hình ảnh
  Widget _buildGradientSection() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFB74D),
            Color(0xFFFF9800),
            Color(0xFFF57C00),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Pattern overlay để tạo hiệu ứng đẹp hơn
          Positioned.fill(
            child: Opacity(
              opacity: 0.1,
              child: CustomPaint(
                painter: PatternPainter(),
              ),
            ),
          ),
          // Icon ở trung tâm với animation
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: Duration(milliseconds: 800),
              builder: (context, value, child) {
                return Transform.scale(
                  scale: 0.8 + (0.2 * value),
                  child: Opacity(
                    opacity: value,
                    child: Icon(
                      Icons.restaurant,
                      size: 50,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                );
              },
            ),
          ),

          // Nút xóa ở góc trên bên phải
          if (onDelete != null)
            Positioned(
              top: 8,
              right: 8,
              child: ClipOval(
                child: Material(
                  color: Colors.white.withOpacity(0.7),
                  child: InkWell(
                    onTap: onDelete,
                    child: Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.delete,
                          size: 16, color: Colors.red.shade700),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Widget hiển thị các món ăn dưới dạng chips
  Widget _buildFoodItemChips(List<FoodItem> items) {
    // Lấy tối đa 4 món đầu tiên để tránh quá dài
    final displayItems = items.take(4).toList();
    final hasMore = items.length > 4;

    return Wrap(
      spacing: 4,
      runSpacing: 2,
      children: [
        ...displayItems.map((item) => Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300, width: 0.5),
          ),
          child: Text(
            item.name,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        )),
        if (hasMore)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200, width: 0.5),
            ),
            child: Text(
              '+${items.length - 4}',
              style: TextStyle(
                fontSize: 10,
                color: Colors.blue.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  // Widget hiển thị thông tin calorie
  Widget _buildCalorieInfo(int calories) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              "$calories",
              style: TextStyle(
                fontSize: 18, // Giảm font size
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 2.0),
              child: Text(
                " kcal",
                style: TextStyle(
                  fontSize: 11, // Giảm font size
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          ],
        ),
        Text(
          "Đã ăn",
          style: TextStyle(
            fontSize: 10, // Giảm font size
            color: Colors.grey.shade500,
          ),
        ),
      ],
    );
  }

  // Widget hiển thị thông tin macro
  Widget _buildMacroInfo(String label, int value, Color color) {
    return Column(
      children: [
        Text(
          "$value g",
          style: TextStyle(
            fontSize: 13, // Giảm font size
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Container(
          padding:
              EdgeInsets.symmetric(horizontal: 6, vertical: 1), // Giảm padding
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // Định dạng thời gian
  String _formatTimeOnly(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return "$hour:$minute";
  }
}

// Painter để vẽ pattern cho card không có hình ảnh
class PatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    const double gap = 20.0;

    // Vẽ các đường chéo mỏng
    for (double i = 0; i < size.width + size.height; i += gap) {
      canvas.drawLine(
        Offset(i < size.width ? i : 0, i < size.width ? 0 : i - size.width),
        Offset(
          i < size.height ? 0 : i - size.height,
          i < size.height ? i : size.height,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

typedef OnPageChanged = void Function(int index);

class MealRecordingScreen extends StatefulWidget {
  final String? initialDate;
  final VoidCallback? onDataChanged;

  const MealRecordingScreen({Key? key, this.initialDate, this.onDataChanged})
      : super(key: key);

  @override
  _MealRecordingScreenState createState() => _MealRecordingScreenState();
}

class _MealRecordingScreenState extends State<MealRecordingScreen> {
  String _selectedDate = DateTime.now().toIso8601String().split('T')[0];
  late PageController _pageController;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = true;
  String _selectedMealType = 'Bữa khác';

  // Danh sách các nhóm dinh dưỡng với tiêu đề và danh sách các chất dinh dưỡng
  final List<Map<String, dynamic>> _nutritionGroups = [
    {
      'title': 'Tổng quan về Dinh dưỡng',
      'icon': Icons.pie_chart_outline,
      'iconColor': Colors.amber.shade700,
      'nutrients': ['calories', 'protein', 'fat', 'carbs'],
    },
    {
      'title': 'Sức khỏe Tim mạch',
      'icon': Icons.favorite_outline,
      'iconColor': Colors.red,
      'nutrients': ['cholesterol', 'omega3', 'fiber', 'water'],
    },
    {
      'title': 'Các chất cần kiểm soát',
      'icon': Icons.warning_amber_outlined,
      'iconColor': Colors.orange,
      'nutrients': ['sugar', 'saturatedFat', 'transFat', 'sodium'],
    },
    {
      'title': 'Vitamin thiết yếu',
      'icon': Icons.wb_sunny_outlined,
      'iconColor': Colors.amber,
      'nutrients': ['vitaminA', 'vitaminD', 'vitaminE', 'vitaminK', 'vitaminC'],
    },
    {
      'title': 'Vitamin nhóm B',
      'icon': Icons.medication_liquid,
      'iconColor': Colors.purple,
      'nutrients': [
        'vitaminB12',
        'vitaminB9',
        'thiamin',
        'riboflavin',
        'niacin'
      ],
    },
    {
      'title': 'Khoáng chất quan trọng',
      'icon': Icons.science_outlined,
      'iconColor': Colors.blue,
      'nutrients': ['iron', 'calcium', 'magnesium', 'zinc', 'potassium'],
    },
    {
      'title': 'Khoáng chất Bổ sung',
      'icon': Icons.brightness_7,
      'iconColor': Colors.deepPurple,
      'nutrients': ['phosphorus', 'selenium', 'copper', 'manganese'],
    },
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final foodProvider = Provider.of<FoodProvider>(context, listen: false);

      // Sử dụng initialDate nếu có, nếu không thì dùng selectedDate từ provider
      if (widget.initialDate != null) {
        _selectedDate = widget.initialDate!;
        // Đồng bộ ngày đã chọn với provider
        foodProvider.setSelectedDate(_selectedDate);
        print(
            'MealRecordingScreen: Khởi tạo với initialDate: ${widget.initialDate}');
      } else {
        // Nếu không có initialDate, sử dụng ngày từ provider
        _selectedDate = foodProvider.selectedDate;
        print(
            'MealRecordingScreen: Khởi tạo với ngày từ provider: $_selectedDate');
      }

      // Cập nhật ngày trong các provider khác để đảm bảo đồng bộ hoàn toàn
      final exerciseProvider =
          Provider.of<ExerciseProvider>(context, listen: false);
      final waterProvider = Provider.of<WaterProvider>(context, listen: false);
      exerciseProvider.setSelectedDate(_selectedDate);
      waterProvider.setSelectedDate(_selectedDate);

      // Khởi tạo PageController với viewportFraction full-width
      _pageController = PageController(
        initialPage: 0,
        viewportFraction: 1.0, // Sử dụng toàn bộ chiều rộng màn hình
      );

      // Tải dữ liệu các bữa ăn
      loadMealData();

      print('MealRecordingScreen: Hoàn tất khởi tạo với ngày $_selectedDate');
    });
  }

  @override
  void dispose() {
    // Giải phóng controller khi widget bị hủy
    _pageController.dispose();
    super.dispose();
  }

  Future<void> loadMealData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final foodProvider = Provider.of<FoodProvider>(context, listen: false);

      // Make sure the provider's selected date matches our selected date
      if (foodProvider.selectedDate != _selectedDate) {
        foodProvider.setSelectedDate(_selectedDate);
      }

      await foodProvider.loadData();
      
      // In thông tin debug về các bữa ăn
      print('DEBUG MEAL DATA: Đã tải ${foodProvider.todayEntries.length} bữa ăn');
      for (var entry in foodProvider.todayEntries) {
        print('DEBUG MEAL DATA: Entry ID: ${entry.id}, Description: ${entry.description}');
        print('DEBUG MEAL DATA: ImageURL: ${entry.imageUrl}');
        print('DEBUG MEAL DATA: ImagePath: ${entry.imagePath}');
        
        // Đảm bảo ảnh được tải cho mỗi bữa ăn
        await _ensureImageLoaded(entry);
      }
      
      // Cập nhật provider để đảm bảo các thay đổi được lưu lại
      for (var entry in foodProvider.todayEntries) {
        foodProvider.updateFoodEntry(entry);
      }
      
      // Yêu cầu provider lưu dữ liệu lên Firebase
      await foodProvider.synchronizeWithFirebase();
      
      // Đảm bảo UI được cập nhật
      if (mounted) {
        setState(() {});
      }

      if (widget.onDataChanged != null) widget.onDataChanged!();
    } catch (e) {
      print('Lỗi khi tải dữ liệu bữa ăn: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể tải dữ liệu bữa ăn: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Map<String, dynamic> _getNutrientValues(
      String nutrient, Map<String, dynamic>? summaryData) {
    if (summaryData == null || !summaryData.containsKey(nutrient)) {
      return {'value': 0.0, 'goal': 100.0, 'remaining': 100.0};
    }

    final data = summaryData[nutrient];
    if (data == null || !(data is Map)) {
      return {'value': 0.0, 'goal': 100.0, 'remaining': 100.0};
    }

    final value =
        (data['value'] is num) ? (data['value'] as num).toDouble() : 0.0;
    final goal =
        (data['goal'] is num) ? (data['goal'] as num).toDouble() : 100.0;
    final remaining = goal - value > 0 ? goal - value : 0.0;

    return {
      'value': value,
      'goal': goal,
      'remaining': remaining,
    };
  }

  // Phương thức hỗ trợ tải ảnh từ Firebase Storage
  Future<void> _ensureImageLoaded(FoodEntry foodEntry) async {
    try {
      final foodProvider = Provider.of<FoodProvider>(context, listen: false);
      bool needUpdate = false;
      FoodEntry updatedEntry = foodEntry;
      
      // Kiểm tra xem có imageUrl không
      if (foodEntry.imageUrl != null && foodEntry.imageUrl!.isNotEmpty) {
        print('DEBUG IMAGE - Entry đã có imageUrl: ${foodEntry.imageUrl}');
        // Đảm bảo đây là URL HTTPS thực sự
        if (!foodEntry.imageUrl!.startsWith('http')) {
          print('DEBUG IMAGE - imageUrl không bắt đầu bằng http, cần xử lý: ${foodEntry.imageUrl}');
          
          // Nếu là gs:// URL, chuyển đổi thành https://
          if (foodEntry.imageUrl!.startsWith('gs://')) {
            try {
              final storage = FirebaseStorage.instance;
              final ref = storage.refFromURL(foodEntry.imageUrl!);
              final downloadUrl = await ref.getDownloadURL();
              
              print('DEBUG IMAGE - Đã chuyển đổi gs:// URL thành https:// URL: $downloadUrl');
              updatedEntry = foodEntry.copyWith(imageUrl: downloadUrl);
              needUpdate = true;
            } catch (e) {
              print('DEBUG IMAGE - Lỗi khi chuyển đổi gs:// URL: $e');
            }
          }
          // Nếu là file://, giữ nguyên vì đã được xử lý đúng trong _buildNetworkOrFileImage
        }
        
        return;
      }
      
      // Nếu không có imageUrl nhưng có imagePath
      if (foodEntry.imagePath != null && foodEntry.imagePath!.isNotEmpty) {
        print('DEBUG IMAGE - Không có imageUrl nhưng có imagePath: ${foodEntry.imagePath}');
        
        // Kiểm tra xem imagePath có phải là đường dẫn Firebase Storage không
        if (foodEntry.imagePath!.startsWith('gs://')) {
          print('DEBUG IMAGE - Phát hiện imagePath là gs:// URL, đang chuyển đổi...');
          
          // Khởi tạo FirebaseStorage
          final storage = FirebaseStorage.instance;
          
          try {
            // Lấy reference từ gs:// URL
            final ref = storage.refFromURL(foodEntry.imagePath!);
            // Lấy URL tải xuống
            final downloadUrl = await ref.getDownloadURL();
            
            print('DEBUG IMAGE - Đã chuyển đổi gs:// URL thành https:// URL: $downloadUrl');
            
            // Cập nhật FoodEntry với URL mới
            updatedEntry = foodEntry.copyWith(imageUrl: downloadUrl);
            needUpdate = true;
          } catch (e) {
            print('DEBUG IMAGE - Lỗi khi chuyển đổi gs:// URL: $e');
          }
        } else if (foodEntry.imagePath!.startsWith('http')) {
          print('DEBUG IMAGE - Phát hiện imagePath là HTTP URL, đang sao chép sang imageUrl...');
          
          // Nếu imagePath đã là HTTP URL, sao chép sang imageUrl
          updatedEntry = foodEntry.copyWith(imageUrl: foodEntry.imagePath);
          needUpdate = true;
        } else if (foodEntry.imagePath!.startsWith('file://')) {
          print('DEBUG IMAGE - imagePath là file:// URL, giữ nguyên vì đã được xử lý trong _buildNetworkOrFileImage');
        } else {
          print('DEBUG IMAGE - imagePath là đường dẫn local, cần upload lên Firebase Storage');
          
          try {
            // Kiểm tra xem file có tồn tại không
            File imageFile = File(foodEntry.imagePath!);
            if (await imageFile.exists()) {
              print('DEBUG IMAGE - File tồn tại, đang upload lên Firebase Storage');
              
              // Lấy ID người dùng hiện tại
              final userDataProvider = Provider.of<UserDataProvider>(context, listen: false);
              final userId = userDataProvider.getCurrentUserId() ?? 'anonymous';
              
              // Tạo đường dẫn trên Firebase Storage
              final fileName = 'food_images/${userId}/${foodEntry.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
              
              // Tham chiếu đến Firebase Storage
              final storageRef = FirebaseStorage.instance.ref().child(fileName);
              
              // Upload file
              final uploadTask = storageRef.putFile(imageFile);
              
              // Chờ upload hoàn tất
              final snapshot = await uploadTask.whenComplete(() {});
              
              // Lấy URL download
              final downloadUrl = await snapshot.ref.getDownloadURL();
              
              print('DEBUG IMAGE - Đã upload thành công, URL: $downloadUrl');
              
              // Cập nhật FoodEntry với URL mới
              updatedEntry = foodEntry.copyWith(imageUrl: downloadUrl);
              needUpdate = true;
            } else {
              print('DEBUG IMAGE - File không tồn tại: ${foodEntry.imagePath}');
            }
          } catch (e) {
            print('DEBUG IMAGE - Lỗi khi upload ảnh lên Firebase Storage: $e');
          }
        }
      }
      
      // Cập nhật vào provider nếu cần
      if (needUpdate) {
        print('DEBUG IMAGE - Cập nhật entry với thông tin ảnh mới');
        foodProvider.updateFoodEntry(updatedEntry);
      }
    } catch (e) {
      print('DEBUG IMAGE - Lỗi khi đảm bảo ảnh được tải: $e');
    }
  }

  // Phương thức _navigateToMealDetails với thêm tùy chọn chọn ảnh
  void _navigateToMealDetails(FoodEntry foodEntry) async {
    // Đảm bảo ảnh được tải trước khi chuyển hướng
    await _ensureImageLoaded(foodEntry);
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FoodNutritionDetailScreen(
          foodEntry: foodEntry,
          onSave: (updatedEntry) {
            final foodProvider =
                Provider.of<FoodProvider>(context, listen: false);
            
            // In log để debug
            print('DEBUG SAVE: Lưu FoodEntry cập nhật từ màn hình chi tiết');
            print('DEBUG SAVE: ID: ${updatedEntry.id}');
            print('DEBUG SAVE: Description: ${updatedEntry.description}');
            print('DEBUG SAVE: ImageURL: ${updatedEntry.imageUrl}');
            print('DEBUG SAVE: ImagePath: ${updatedEntry.imagePath}');
            
            // Cập nhật FoodEntry trong provider
            foodProvider.updateFoodEntry(updatedEntry);

            // Tải lại dữ liệu sau khi cập nhật
            loadMealData();

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Đã cập nhật thông tin dinh dưỡng'),
                backgroundColor: Colors.green,
              ),
            );
          },
        ),
      ),
    ).then((result) {
      print('DEBUG NAVIGATION: Quay lại từ màn hình chi tiết');
      // Tải lại dữ liệu khi quay về từ màn hình chi tiết
      loadMealData();
      
      // Sau khi tải xong dữ liệu, đảm bảo cập nhật UI
      Future.delayed(Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            // Cập nhật lại UI
            print('DEBUG NAVIGATION: Cập nhật UI sau khi quay lại');
          });
        }
      });
    });
  }
  
  // Phương thức mới để chọn ảnh trực tiếp từ màn hình chính
  Future<void> _addImageToMeal(FoodEntry foodEntry) async {
    try {
      final source = await showDialog<ImageSource>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Chọn nguồn ảnh'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ListTile(
                  leading: Icon(Icons.photo_library, color: Colors.blue),
                  title: Text('Thư viện ảnh'),
                  onTap: () {
                    Navigator.of(context).pop(ImageSource.gallery);
                  },
                ),
                Divider(),
                ListTile(
                  leading: Icon(Icons.photo_camera, color: Colors.red),
                  title: Text('Máy ảnh'),
                  onTap: () {
                    Navigator.of(context).pop(ImageSource.camera);
                  },
                ),
              ],
            ),
          );
        },
      );

      if (source == null) return;

      setState(() {
        _isLoading = true;
      });

      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 800,
      );

      if (pickedFile == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Tạo file từ XFile
      final File imageFile = File(pickedFile.path);
      
      // Hiển thị dialog thông báo đang tải
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Đang tải ảnh lên...'),
              ],
            ),
          );
        },
      );
      
      try {
        // Lấy ID người dùng hiện tại
        final userDataProvider = Provider.of<UserDataProvider>(context, listen: false);
        final userId = userDataProvider.getCurrentUserId() ?? 'anonymous';
        
        // Tạo đường dẫn trên Firebase Storage
        final fileName = 'food_images/${userId}/${foodEntry.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        
        // Tham chiếu đến Firebase Storage
        final storageRef = FirebaseStorage.instance.ref().child(fileName);
        
        // Upload file
        final uploadTask = storageRef.putFile(imageFile);
        
        // Chờ upload hoàn tất
        final snapshot = await uploadTask.whenComplete(() {});
        
        // Lấy URL download
        final downloadUrl = await snapshot.ref.getDownloadURL();
        
        // Đóng dialog thông báo
        Navigator.of(context).pop();
        
        // Cập nhật FoodEntry với URL mới
        final updatedEntry = foodEntry.copyWith(
          imageUrl: downloadUrl,
          imagePath: imageFile.path,
        );
        
        // Cập nhật vào provider
        final foodProvider = Provider.of<FoodProvider>(context, listen: false);
        await foodProvider.updateFoodEntry(updatedEntry);
        
        // Đồng bộ với Firebase ngay lập tức
        await foodProvider.synchronizeWithFirebase();
        
        // Tải lại dữ liệu sau khi cập nhật
        await loadMealData();
        
        // Hiển thị thông báo thành công
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã thêm ảnh vào món ăn'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        // Đóng dialog thông báo nếu đang hiển thị
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        
        print('Lỗi khi tải ảnh lên Firebase Storage: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi tải ảnh lên: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Lỗi khi chọn ảnh: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,

      // Nút thêm thực phẩm

      body: Consumer<FoodProvider>(
        builder: (context, foodProvider, child) {
          // Cập nhật _selectedDate để khớp với provider nếu cần
          if (foodProvider.selectedDate != _selectedDate) {
            _selectedDate = foodProvider.selectedDate;
          }

          // Lấy dữ liệu từ provider
          final recordedMeals = foodProvider.todayEntries;

          // Debug hiển thị số lượng bữa ăn
          print('DEBUG BUILD: Số lượng bữa ăn: ${recordedMeals.length}');

          // Tính toán tổng hợp dinh dưỡng
          final nutritionGoals = foodProvider.getNutritionGoals(context);
          // Chuyển đổi kiểu Map<String, dynamic> sang Map<String, double>
          final Map<String, double> convertedGoals = {};
          nutritionGoals.forEach((key, value) {
            if (value is num) {
              convertedGoals[key] = value.toDouble();
            }
          });
          final summaryData =
              _calculateNutritionSummary(recordedMeals, convertedGoals);

          // Return default UI for all cases

          // Trở về giao diện mặc định nếu không có kế hoạch
          return Column(
            children: [
              // Bộ chọn ngày
              DaySelector.fullDate(
                selectedDate: _selectedDate,
                onDateChanged: (newDate) {
                  setState(() {
                    _selectedDate = newDate;
                  });

                  // Cập nhật ngày trong provider - điều này sẽ đồng bộ với HomeScreen
                  final foodProvider =
                      Provider.of<FoodProvider>(context, listen: false);
                  foodProvider.setSelectedDate(newDate);

                  // Cập nhật ngày trong các provider khác để đảm bảo đồng bộ hoàn toàn
                  final exerciseProvider =
                      Provider.of<ExerciseProvider>(context, listen: false);
                  final waterProvider =
                      Provider.of<WaterProvider>(context, listen: false);
                  exerciseProvider.setSelectedDate(newDate);
                  waterProvider.setSelectedDate(newDate);

                  // Tải lại dữ liệu khi chọn ngày mới
                  loadMealData();

                  // Khi thay đổi ngày, nếu đang ở trong stack navigate, thì pop về với kết quả
                  if (Navigator.canPop(context) &&
                      ModalRoute.of(context)?.settings.name != '/') {
                    Navigator.pop(context, {'selectedDate': newDate});
                  }

                  // In thông báo debug
                  print('MealRecordingScreen: Đã thay đổi ngày thành $newDate');
                },
              ),

              // Nội dung chính
              Expanded(
                child: _isLoading
                    ? Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 0.0), // Xóa padding hoàn toàn
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize
                                .min, // Đảm bảo Column chỉ chiếm không gian cần thiết
                            children: [
                              // Phần thực phẩm đã ghi nhận - đẩy sát lên phần lịch
                              Transform.translate(
                                offset: Offset(0, -8), // Đẩy lên trên 8px
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 8.0),
                                child: InkWell(
                                  onTap: () {
                                    // Navigate to combined history screen with food filter
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => CombinedHistoryScreen(
                                          initialFilters: {'Thực phẩm'}, // Chỉ hiển thị thực phẩm
                                          customTitle: 'Lịch sử thực phẩm',
                                        ),
                                      ),
                                    );
                                  },
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.access_time,
                                              color: Colors.black87),
                                          Text(
                                            'Thực phẩm đã ghi nhận',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.arrow_forward_ios,
                                            size: 14),
                                        onPressed: () {
                                          // Navigate to combined history screen with food filter
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => CombinedHistoryScreen(
                                                initialFilters: {'Thực phẩm'}, // Chỉ hiển thị thực phẩm
                                                customTitle: 'Lịch sử thực phẩm',
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                ),
                              ),
                              // Danh sách thực phẩm đã ghi nhận - sử dụng toàn bộ chiều rộng
                              recordedMeals.isEmpty
                                  ? _buildEmptyRecordedMeals()
                                  : Transform.translate(
                                      offset: Offset(0, -10), // Kéo food card lên sát với text "Thực phẩm đã ghi nhận"
                                      child: Column(
                                      children: [
                                        LayoutBuilder(
                                          builder: (context, constraints) {
                                            // Tính toán chiều cao tối đa an toàn cho container
                                            final safeHeight =
                                                constraints.maxHeight * 0.65;
                                            return Container(
                                              height: math.min(330,
                                                  safeHeight), // Tăng chiều cao lên 330 để có đủ không gian cho ảnh 200px + thông tin 120px + padding
                                              width: MediaQuery.of(context)
                                                  .size
                                                  .width,
                                              child: PageViewTransformer(
                                                pageController: _pageController,
                                                transformer:
                                                    CoverflowPageTransformer(
                                                  viewportFraction:
                                                      1.0, // Sử dụng toàn bộ chiều rộng màn hình
                                                  depth:
                                                      0.005, // Giảm độ sâu để phù hợp với kích thước lớn hơn
                                                  scale:
                                                      0.05, // Giảm tỷ lệ thu nhỏ để tạo hiệu ứng full-width
                                                ),
                                                itemCount: recordedMeals.length,
                                                onPageChanged: (index) {
                                                  setState(() {
                                                    // Cập nhật state để thay đổi page indicator
                                                  });
                                                },
                                                itemBuilder: (context, index) {
                                                  final foodEntry =
                                                      recordedMeals[index];
                                                  final foodProvider =
                                                      Provider.of<FoodProvider>(
                                                          context,
                                                          listen: false);
                                                  final goals = foodProvider
                                                      .getNutritionGoals(
                                                          context);

                                                  return GestureDetector(
                                                    onTap: () =>
                                                        _navigateToMealDetails(
                                                            foodEntry),
                                                    child: Container(
                                                      margin:
                                                          EdgeInsets.symmetric(
                                                              horizontal: 0.0,
                                                              vertical: 0.0),
                                                      decoration: BoxDecoration(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                                0), // Xóa bo góc để lấp đầy màn hình
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: Colors.black
                                                                .withOpacity(
                                                                    0.2),
                                                            spreadRadius: 1,
                                                            blurRadius: 15,
                                                            offset:
                                                                Offset(0, 5),
                                                          ),
                                                        ],
                                                      ),
                                                      child: ClipRRect(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                                0), // Xóa bo góc để lấp đầy màn hình
                                                        child: EnhancedFoodCard(
                                                          foodEntry: foodEntry,
                                                          servingSize: foodEntry
                                                                  .items
                                                                  .isNotEmpty
                                                              ? foodEntry
                                                                  .items
                                                                  .first
                                                                  .servingSize
                                                              : 1.0,
                                                          caloriesGoal: goals[
                                                                  'calories'] ??
                                                              2000,
                                                          proteinGoal: goals[
                                                                  'protein'] ??
                                                              50,
                                                          fatGoal:
                                                              goals['fat'] ??
                                                                  70,
                                                          carbsGoal:
                                                              goals['carbs'] ??
                                                                  310,
                                                          onTap: () =>
                                                              _navigateToMealDetails(
                                                                  foodEntry),
                                                          onServingSizeChanged:
                                                              (newSize) {
                                                            _updateServingSize(
                                                                foodEntry.id,
                                                                newSize);
                                                          },
                                                          onDelete: () {
                                                            _deleteFoodEntry(
                                                                foodEntry.id);
                                                          },
                                                          onAddImage: () {
                                                            _addImageToMeal(foodEntry);
                                                          },
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            );
                                          },
                                        ),
                                        // Page indicator với hiệu ứng mới nâng cao
                                        recordedMeals.length > 1
                                            ? AnimatedBuilder(
                                                animation: _pageController,
                                                builder: (context, child) {
                                                  double? currentPageDouble;
                                                  int currentPage = 0;

                                                  if (_pageController
                                                          .hasClients &&
                                                      _pageController.positions
                                                          .isNotEmpty) {
                                                    currentPageDouble =
                                                        _pageController.page;
                                                    currentPage =
                                                        _pageController.page
                                                                ?.round() ??
                                                            0;
                                                  }

                                                  return Container(
                                                    child: Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: List.generate(
                                                        recordedMeals.length,
                                                        (index) {
                                                          // Tính toán độ gần với trang hiện tại (0.0 đến 1.0)
                                                          double proximity =
                                                              1.0;
                                                          if (currentPageDouble !=
                                                              null) {
                                                            proximity =
                                                                (currentPageDouble -
                                                                        index)
                                                                    .abs();
                                                            if (proximity > 1.0)
                                                              proximity = 1.0;
                                                          }

                                                          final isActive =
                                                              currentPage ==
                                                                  index;

                                                          // Màu sắc chuyển đổi dựa trên độ gần
                                                          final color =
                                                              Color.lerp(
                                                            Colors.green,
                                                            Colors
                                                                .grey.shade300,
                                                            proximity,
                                                          );

                                                          return TweenAnimationBuilder(
                                                            tween:
                                                                Tween<double>(
                                                              begin: isActive
                                                                  ? 0.0
                                                                  : 1.0,
                                                              end: isActive
                                                                  ? 1.0
                                                                  : 0.0,
                                                            ),
                                                            duration: Duration(
                                                                milliseconds:
                                                                    350),
                                                            curve: Curves
                                                                .easeOutCubic,
                                                            builder: (context,
                                                                value, child) {
                                                              return Container(
                                                                width: 8.0 +
                                                                    (18 *
                                                                        (1 -
                                                                            proximity)),
                                                                height: 8.0 +
                                                                    (4 *
                                                                        (1 -
                                                                            proximity)),
                                                                margin: EdgeInsets
                                                                    .symmetric(
                                                                        horizontal:
                                                                            4),
                                                                decoration:
                                                                    BoxDecoration(
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              10),
                                                                  color: color,
                                                                  boxShadow:
                                                                      isActive
                                                                          ? [
                                                                              BoxShadow(
                                                                                color: Colors.green.withOpacity(0.5),
                                                                                spreadRadius: 1,
                                                                                blurRadius: 4,
                                                                                offset: Offset(0, 1),
                                                                              )
                                                                            ]
                                                                          : null,
                                                                ),
                                                              );
                                                            },
                                                          );
                                                        },
                                                      ),
                                                    ),
                                                  );
                                                },
                                              )
                                            : SizedBox.shrink(),
                                      ],
                                    ),
                                  ), // Đóng Transform.translate

                              // Thêm khoảng cách giữa food card và các vòng tròn dinh dưỡng
                              SizedBox(height: 20), // Giảm khoảng cách xuống 20px vì đã kéo food card lên

                              // Hiển thị các nhóm dinh dưỡng
                              ..._nutritionGroups.map((group) {
                                return _buildSectionContainer(
                                  title: group['title'],
                                  icon: group['icon'],
                                  iconColor: group['iconColor'],
                                  nutrients: group['nutrients'],
                                  summaryData: summaryData,
                                );
                              }).toList(),

                              // Removed meal plan card

                              SizedBox(
                                  height:
                                      40), // Giảm không gian ở dưới cùng từ 60 xuống 40 để tránh overflow
                            ],
                          ),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Biểu đồ tổng quan về calories

  // Widget hiển thị thông tin macro
  Widget _buildMacroInfo(String name, double value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
        SizedBox(width: 6),
        Text(
          '$name: ${value.toInt()}g',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyRecordedMeals() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.no_food,
              size: 48,
              color: Colors.grey,
            ),
            SizedBox(height: 12),
            Text(
              'Bạn chưa ghi lại bữa ăn hôm nay',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade700,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Nhấn nút + để thêm bữa ăn mới',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionContainer({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<String> nutrients,
    Map<String, dynamic>? summaryData,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: iconColor),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        SizedBox(height: 8), // Giảm từ 12 xuống 8
        Container(
          height:
              140, // Giảm chiều cao từ 170 xuống 140 để tránh overflow
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                spreadRadius: 0,
                offset: Offset(0, 2),
              ),
            ],
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Colors.grey.shade50,
              ],
            ),
          ),
          // Use LayoutBuilder to make the width of items adapt to screen size
          child: LayoutBuilder(builder: (context, constraints) {
            // Calculate an optimal item width based on container width
            final itemWidth = (constraints.maxWidth / 3.5).clamp(75.0,
                95.0); // Giảm kích thước để phù hợp với container nhỏ hơn

            return ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: nutrients.length,
              physics: BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(
                  horizontal: 5, vertical: 4), // Giảm padding dọc để tiết kiệm không gian
              itemBuilder: (context, index) {
                final nutrient = nutrients[index];
                final nutrientInfo = _getNutrientValues(nutrient, summaryData);

                return Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 4.0, vertical: 0.0), // Giảm padding ngang để tiết kiệm không gian
                  child: SizedBox(
                    width: itemWidth,
                    child: _buildNutritionCircleForNutrient(
                      nutrient,
                      nutrientInfo['value'],
                      nutrientInfo['goal'],
                      nutrientInfo['remaining'],
                    ),
                  ),
                );
              },
            );
          }),
        ),
        SizedBox(height: 16), // Giảm khoảng cách giữa các section từ 24 xuống 16
      ],
    );
  }

  Widget _buildNutritionCircleForNutrient(
      String nutrient, double value, double goal, double remaining) {
    // Map các loại dinh dưỡng với tên hiển thị và màu sắc
    final nutrientDetails = {
      'calories': {
        'label': 'Calo',
        'color': Colors.red.shade400,
        'unit': 'kcal',
        'icon': Icons.local_fire_department
      },
      'protein': {
        'label': 'Protein',
        'color': Colors.blue.shade400,
        'unit': 'g',
        'icon': Icons.fitness_center
      },
      'fat': {
        'label': 'Chất béo',
        'color': Colors.orange.shade400,
        'unit': 'g',
        'icon': Icons.water_drop
      },
      'carbs': {
        'label': 'Carb',
        'color': Colors.green.shade400,
        'unit': 'g',
        'icon': Icons.eco
      },
      'cholesterol': {
        'label': 'Cholesterol',
        'color': Colors.orange.shade400,
        'unit': 'mg',
        'icon': Icons.healing
      },
      'omega3': {
        'label': 'Omega-3',
        'color': Colors.cyan.shade400,
        'unit': 'mg',
        'icon': Icons.spa
      },
      'fiber': {
        'label': 'Chất xơ',
        'color': Colors.brown.shade400,
        'unit': 'g',
        'icon': Icons.grass
      },
      'water': {
        'label': 'Nước',
        'color': Colors.blue.shade400,
        'unit': 'ml',
        'icon': Icons.water
      },
      'sugar': {
        'label': 'Đường',
        'color': Colors.pink.shade400,
        'unit': 'g',
        'icon': Icons.cake
      },
      'saturatedFat': {
        'label': 'Chất béo bão hòa',
        'color': Colors.grey.shade700,
        'unit': 'g',
        'icon': null
      },
      'transFat': {
        'label': 'Chất béo trans',
        'color': Colors.red.shade300,
        'unit': 'g',
        'icon': null
      },
      'caffeine': {
        'label': 'Caffeine',
        'color': Colors.brown.shade400,
        'unit': 'mg',
        'icon': Icons.coffee
      },
      'alcohol': {
        'label': 'Rượu',
        'color': Colors.amber.shade400,
        'unit': 'ml',
        'icon': null
      },
      'vitaminA': {
        'label': 'Vitamin A',
        'color': Colors.orange.shade400,
        'unit': 'mcg',
        'icon': null
      },
      'vitaminD': {
        'label': 'Vitamin D',
        'color': Colors.amber.shade400,
        'unit': 'mcg',
        'icon': Icons.wb_sunny_outlined
      },
      'vitaminE': {
        'label': 'Vitamin E',
        'color': Colors.green.shade300,
        'unit': 'mg',
        'icon': null
      },
      'vitaminK': {
        'label': 'Vitamin K',
        'color': Colors.green.shade700,
        'unit': 'mcg',
        'icon': null
      },
      'vitaminB12': {
        'label': 'Vitamin B12',
        'color': Colors.purple.shade400,
        'unit': 'mcg',
        'icon': null
      },
      'vitaminC': {
        'label': 'Vitamin C',
        'color': Colors.orange.shade400,
        'unit': 'mg',
        'icon': Icons.local_florist
      },
      'vitaminB9': {
        'label': 'Vitamin B9',
        'color': Colors.green.shade400,
        'unit': 'mcg',
        'icon': null
      },
      'thiamin': {
        'label': 'Thiamin',
        'color': Colors.amber.shade600,
        'unit': 'mg',
        'icon': null
      },
      'riboflavin': {
        'label': 'Riboflavin',
        'color': Colors.amber.shade700,
        'unit': 'mg',
        'icon': null
      },
      'niacin': {
        'label': 'Niacin',
        'color': Colors.amber.shade800,
        'unit': 'mg',
        'icon': null
      },
      'iron': {
        'label': 'Sắt',
        'color': Colors.red.shade700,
        'unit': 'mg',
        'icon': Icons.power
      },
      'calcium': {
        'label': 'Canxi',
        'color': Colors.grey.shade400,
        'unit': 'mg',
        'icon': Icons.fitness_center
      },
      'magnesium': {
        'label': 'Magie',
        'color': Colors.grey.shade600,
        'unit': 'mg',
        'icon': null
      },
      'phosphorus': {
        'label': 'Phốt pho',
        'color': Colors.grey.shade500,
        'unit': 'mg',
        'icon': null
      },
      'potassium': {
        'label': 'Kali',
        'color': Colors.purple.shade200,
        'unit': 'mg',
        'icon': null
      },
      'selenium': {
        'label': 'Selen',
        'color': Colors.orange.shade300,
        'unit': 'mcg',
        'icon': null
      },
      'zinc': {
        'label': 'Kẽm',
        'color': Colors.blue.shade400,
        'unit': 'mg',
        'icon': null
      },
      'copper': {
        'label': 'Đồng',
        'color': Colors.brown.shade300,
        'unit': 'mg',
        'icon': null
      },
      'manganese': {
        'label': 'Mangan',
        'color': Colors.pink.shade300,
        'unit': 'mg',
        'icon': null
      },
      'sodium': {
        'label': 'Natri',
        'color': Colors.grey.shade400,
        'unit': 'mg',
        'icon': null
      },
    };

    final details = nutrientDetails[nutrient] ??
        {'label': nutrient, 'color': Colors.grey, 'unit': '', 'icon': null};

    final color = details['color'] as Color;
    final label = details['label'] as String;
    final unit = details['unit'] as String;
    final IconData? icon = details['icon'] as IconData?;

    // Kiểm tra xem giá trị có vượt quá mục tiêu không
    bool exceeds = value > goal;
    String remainingText = exceeds
        ? '${(value - goal).toStringAsFixed(1)}${unit} vượt quá'
        : 'Còn lại ${remaining.toStringAsFixed(1)}${unit}';

    // Tính toán phần trăm tiến trình (giới hạn ở 100%)
    double progress = value / goal;
    if (progress > 1.0) progress = 1.0;
    if (progress < 0.0) progress = 0.0;

    if (nutrient == 'calories') {
      // Sử dụng NutritionCircle giống các nutrient khác để thống nhất giao diện
      return NutritionCircle(
        size: 65.0, // Giảm kích thước từ 80.0 xuống 65.0 để phù hợp với container nhỏ hơn
        value: value, // Truyền giá trị thực tế để NutritionCircle tự tính phần trăm
        max: goal, // Truyền mục tiêu thực tế
        color: color,
        label: label,
        // Hiển thị số 0 nếu không có giá trị
        remainingText: "${value.toInt()}",
        backgroundColor: color.withOpacity(0.2),
        useRadialGradient: false,
        showPercentage: true, // Hiển thị phần trăm ở giữa vòng tròn
        icon: icon,
        // Hiển thị giá trị thực tế trong dạng "2002/1827kcal"
        showTotalValue: true,
        totalValueText: "${value.toInt()}/${goal.toInt()}${unit}",
        hideWhenZero: false, // Luôn hiển thị vòng tròn, kể cả khi 0%
      );
    }

    // Sử dụng NutritionCircle cho các nutrient khác để có giao diện giống với nutrition_illustration.dart
    return NutritionCircle(
      size: 65.0, // Giảm kích thước từ 80.0 xuống 65.0 để phù hợp với container nhỏ hơn
      value: value, // Truyền giá trị thực tế để NutritionCircle tự tính phần trăm
      max: goal, // Truyền mục tiêu thực tế
      color: color,
      label: label,
      // Hiển thị số thực tế
      remainingText: "${value.toInt()}",
      backgroundColor: color.withOpacity(0.2),
      useRadialGradient: false,
      showPercentage: true, // Hiển thị phần trăm ở giữa vòng tròn
      icon: icon,
      // Hiển thị tổng giá trị theo định dạng "2002/1827kcal"
      showTotalValue: true,
      totalValueText: "${value.toInt()}/${goal.toInt()}${unit}",
      hideWhenZero: false, // Luôn hiển thị vòng tròn, kể cả khi 0%
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.fixed,
      ),
    );
  }

  // Add success message helper method
  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.fixed,
        backgroundColor: Colors.green,
      ),
    );
  }

  void _updateServingSize(String foodEntryId, double newSize) {
    final foodProvider = Provider.of<FoodProvider>(context, listen: false);
    print(
        'DEBUG: Cập nhật kích thước serving size cho entry $foodEntryId thành $newSize');

    // Tìm entry cần cập nhật
    final index = foodProvider.todayEntries
        .indexWhere((entry) => entry.id == foodEntryId);
    if (index != -1) {
      final entry = foodProvider.todayEntries[index];
      print('DEBUG: Đã tìm thấy entry: ${entry.description}');

      // Nếu có items, cập nhật kích thước serving size của item đầu tiên
      if (entry.items.isNotEmpty) {
        final updatedItems = List<FoodItem>.from(entry.items);
        // Cập nhật serving size của item đầu tiên
        updatedItems[0] = updatedItems[0].copyWith(servingSize: newSize);

        // Tạo entry mới với items đã cập nhật
        final updatedEntry = entry.copyWith(items: updatedItems);

        // Cập nhật vào provider
        foodProvider.updateFoodEntry(updatedEntry);
        print('DEBUG: Đã cập nhật kích thước serving size!');

        // Tải lại dữ liệu sau khi cập nhật
        loadMealData();
      } else {
        print('DEBUG: Entry không có items!');
      }
    } else {
      print('DEBUG: Không tìm thấy entry với ID $foodEntryId!');
    }
  }

  void _deleteFoodEntry(String foodEntryId) {
    final foodProvider = Provider.of<FoodProvider>(context, listen: false);
    print('DEBUG: Xóa entry $foodEntryId');

    // Tìm vị trí của entry cần xóa
    final index = foodProvider.todayEntries
        .indexWhere((entry) => entry.id == foodEntryId);
    if (index != -1) {
      print('DEBUG: Đã tìm thấy entry cần xóa ở vị trí $index');
      
      // Hiển thị dialog xác nhận
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Xác nhận'),
            content: Text('Bạn có chắc chắn muốn xóa món ăn này?'),
            actions: <Widget>[
              TextButton(
                child: Text('Hủy'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                child: Text('Xóa'),
                onPressed: () async {
                  Navigator.of(context).pop(); // Đóng dialog
                  
                  // Hiển thị loading indicator
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          SizedBox(
                            width: 20, 
                            height: 20, 
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            )
                          ),
                          SizedBox(width: 16),
                          Text('Đang xóa món ăn...'),
                        ],
                      ),
                      duration: Duration(seconds: 2),
                    ),
                  );
                  
                  // Gọi phương thức xóa entry từ provider
                  final result = await foodProvider.deleteFoodEntry(foodEntryId);
                  print('DEBUG: Kết quả xóa món ăn: $result');
                  
                  if (result) {
                    // Tải lại dữ liệu sau khi xóa
                    await loadMealData();
                    
                    // Thông báo đã xóa thành công
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Đã xóa món ăn'),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  } else {
                    // Thông báo lỗi
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Không thể xóa món ăn'),
                        backgroundColor: Colors.red,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
            ],
          );
        },
      );
    } else {
      print('DEBUG: Không tìm thấy entry cần xóa!');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không tìm thấy món ăn cần xóa'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Map<String, dynamic> _calculateNutritionSummary(
      List<FoodEntry> foodEntries, Map<String, double> goals) {
    // Khởi tạo map summaryData
    Map<String, dynamic> summaryData = {};

    // Danh sách các chất dinh dưỡng có sẵn trong FoodItem
    List<String> basicNutrients = [
      'calories',
      'protein',
      'fat',
      'carbs',
      'fiber',
      'sugar',
      'sodium'
    ];

    // Danh sách bổ sung các chất dinh dưỡng cần theo dõi
    List<String> additionalNutrients = [
      'cholesterol',
      'omega3',
      'water',
      'saturatedFat',
      'transFat',
      'caffeine',
      'alcohol',
      'vitaminA',
      'vitaminD',
      'vitaminE',
      'vitaminK',
      'vitaminB12',
      'vitaminC',
      'vitaminB9',
      'thiamin',
      'riboflavin',
      'niacin',
      'iron',
      'calcium',
      'magnesium',
      'phosphorus',
      'potassium',
      'selenium',
      'zinc',
      'copper',
      'manganese',
    ];

    // Tạo danh sách đầy đủ các chất dinh dưỡng
    List<String> allNutrients = [...basicNutrients, ...additionalNutrients];

    // Khởi tạo giá trị cho mỗi chất dinh dưỡng
    for (String nutrient in allNutrients) {
      double goalValue = goals[nutrient] ?? 100.0;
      summaryData[nutrient] = {
        'value': 0.0,
        'goal': goalValue,
        'remaining': goalValue
      };
    }

    // Tính tổng dinh dưỡng từ tất cả các bữa ăn
    for (FoodEntry entry in foodEntries) {
      for (FoodItem item in entry.items) {
        double multiplier = item.servingSize;

        // Cập nhật giá trị cho các chất dinh dưỡng chính
        if (summaryData.containsKey('calories')) {
          summaryData['calories']['value'] += item.calories * multiplier;
        }

        if (summaryData.containsKey('protein')) {
          summaryData['protein']['value'] += item.protein * multiplier;
        }

        if (summaryData.containsKey('fat')) {
          summaryData['fat']['value'] += item.fat * multiplier;
        }

        if (summaryData.containsKey('carbs')) {
          summaryData['carbs']['value'] += item.carbs * multiplier;
        }

        // Cập nhật giá trị cho các chất dinh dưỡng phụ nếu có
        if (item.fiber != null && summaryData.containsKey('fiber')) {
          summaryData['fiber']['value'] += item.fiber! * multiplier;
        }

        if (item.sugar != null && summaryData.containsKey('sugar')) {
          summaryData['sugar']['value'] += item.sugar! * multiplier;
        }

        if (item.sodium != null && summaryData.containsKey('sodium')) {
          summaryData['sodium']['value'] += item.sodium! * multiplier;
        }

        // Kiểm tra và cập nhật các chất dinh dưỡng bổ sung (nếu có)
        if (item.additionalNutrients != null) {
          item.additionalNutrients!.forEach((nutrient, value) {
            if (summaryData.containsKey(nutrient) && value is num) {
              summaryData[nutrient]['value'] += value.toDouble() * multiplier;
            }
          });
        }
      }
    }

    // Tính toán lại số lượng còn lại cho mỗi chất dinh dưỡng
    for (String nutrient in allNutrients) {
      if (summaryData.containsKey(nutrient)) {
        var nutrientData = summaryData[nutrient];
        if (nutrientData != null && nutrientData is Map) {
          double value = nutrientData['value'] ?? 0.0;
          double goal = nutrientData['goal'] ?? 100.0;
          double remaining = goal - value > 0 ? goal - value : 0.0;
          nutrientData['remaining'] = remaining;
        }
      }
    }

    return summaryData;
  }

  // Xử lý FoodItem được trả về từ quét mã vạch
  void _processBarcodeFoodItem(FoodItem foodItem, String barcode) {
    try {
      // Lấy thời gian hiện tại cho bữa ăn
      DateTime now = DateTime.now();

      // Xác định mealType dựa vào thời gian trong ngày
      String mealType = 'Bữa khác';
      final hour = now.hour;

      if (hour >= 5 && hour < 10) {
        mealType = 'Bữa sáng';
      } else if (hour >= 10 && hour < 14) {
        mealType = 'Bữa trưa';
      } else if (hour >= 14 && hour < 17) {
        mealType = 'Bữa phụ';
      } else if (hour >= 17 && hour < 22) {
        mealType = 'Bữa tối';
      }

      // Tạo UUID mới
      final uuid = Uuid();
      final String entryId = uuid.v4();

      // Tạo entry từ FoodItem
      final entry = FoodEntry(
        id: entryId,
        description: foodItem.name,
        items: [foodItem],
        dateTime: now,
        mealType: mealType, // Sử dụng mealType xác định từ giờ trong ngày
        barcode: barcode,
        nutritionInfo: {
          'calories': foodItem.calories,
          'protein': foodItem.protein,
          'fat': foodItem.fat,
          'carbs': foodItem.carbs,
          'fiber': foodItem.fiber,
          'sugar': foodItem.sugar,
          'sodium': foodItem.sodium,
          'servingSize': foodItem.servingSize,
          'totalWeight': foodItem.servingSize * 100,
          'dataSource': 'Open Food Facts',
          'barcode': barcode,
          ...foodItem.additionalNutrients ?? {},
        },
      );

      // Thêm entry vào provider
      final foodProvider = Provider.of<FoodProvider>(context, listen: false);
      foodProvider.addFoodEntry(entry);

      // Hiển thị thông báo thành công
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã tìm thấy: ${foodItem.name}'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );

      // Cập nhật lại dữ liệu trên màn hình
      loadMealData();

      // Ngay lập tức chuyển hướng đến màn hình chi tiết dinh dưỡng
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FoodNutritionDetailScreen(
            foodEntry: entry,
            onSave: (updatedEntry) {
              foodProvider.updateFoodEntry(updatedEntry);
              // Đảm bảo dữ liệu được cập nhật sau khi lưu
              loadMealData();
            },
          ),
        ),
      ).then((_) {
        // Đảm bảo tải lại dữ liệu khi quay lại
        loadMealData();
      });
    } catch (e) {
      print('Lỗi khi xử lý thông tin mã vạch: $e');
      _showErrorMessage('Không thể xử lý thông tin mã vạch: $e');
    }
  }

  // Removed meal plan methods

  // Removed meal plan related function

  // Sau khi thêm hoặc xóa món ăn, cập nhật lại calo và mục tiêu nếu HomeScreen đang mounted
  void loadMealDataAndSync(BuildContext context) {
    loadMealData();
    try {
      final foodProvider = Provider.of<FoodProvider>(context, listen: false);
      final userDataProvider =
          Provider.of<UserDataProvider>(context, listen: false);
      // Nếu HomeScreen đang mounted, gọi cập nhật
      if (Navigator.canPop(context)) {
        // Tìm HomeScreen trong stack và gọi cập nhật nếu có thể
        // (Hoặc có thể dùng callback hoặc Provider để trigger)
      }
      // Cập nhật trực tiếp qua Provider
      if (foodProvider != null && userDataProvider != null) {
        // Nếu có HomeScreen, nên dùng callback, còn không thì cập nhật trực tiếp
        // (Giả sử có các hàm tương tự ở đây)
        // Nếu không, có thể trigger notifyListeners để HomeScreen tự cập nhật
        foodProvider.notifyListeners();
        userDataProvider.notifyListeners();
      }
    } catch (e) {
      print('Lỗi khi đồng bộ calo và mục tiêu: $e');
    }
  }
}
