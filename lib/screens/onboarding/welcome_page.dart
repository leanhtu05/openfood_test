import 'package:flutter/material.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: Container(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Quay lại nút (ẩn ở trang đầu tiên)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Opacity(
                      opacity: 0,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: null,
                      ),
                    ),
                  ),
                  
                  // Logo
                  const Text(
                    'DietAI',
                    style: TextStyle(
                      fontSize: 50,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF24204F),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Logo hình quả táo
                  SizedBox(
                    width: 200,
                    height: 200,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Quả táo màu xanh
                        Container(
                          width: 180,
                          height: 180,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Icon(
                              Icons.apple,
                              size: 150,
                              color: Colors.green[700],
                            ),
                          ),
                        ),
                        
                        // Icon não bộ và mạch điện
                        Image.asset(
                          'assets/images/brain_circuits.png',
                          width: 120,
                          height: 120,
                          color: Colors.white,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.psychology,
                              size: 120,
                              color: Colors.white,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  // Thông điệp chào mừng
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/images/confetti.png',
                        width: 24,
                        height: 24,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.celebration, size: 24, color: Colors.amber);
                        },
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Năm mới, Bạn mới! Trở nên khỏe mạnh hơn...',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Chuyên gia dinh dưỡng
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text(
                          'Chào👋 Tôi là Chuyên gia Dinh dưỡng Cá nhân của bạn được hỗ trợ bởi AI. Tôi sẽ hỏi bạn một số câu hỏi để cá nhân hóa một kế hoạch ăn kiêng thông minh cho bạn',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  
                  // Thay thế Spacer bằng SizedBox với chiều cao cố định
                  const SizedBox(height: 40),
                  
                  // Google Health Connect button
                  ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.link, color: Colors.blue),
                    label: const Text('Đồng bộ với Google Health Connect'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade50,
                      foregroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 0,
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Đăng nhập text
                  const Text(
                    'Nếu bạn có tài khoản, vui lòng đăng nhập tại đây',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      }
    );
  }
} 