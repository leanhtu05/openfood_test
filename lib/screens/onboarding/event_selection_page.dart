import 'package:flutter/material.dart';

class EventSelectionPage extends StatefulWidget {
  const EventSelectionPage({Key? key}) : super(key: key);

  @override
  State<EventSelectionPage> createState() => _EventSelectionPageState();
}

class _EventSelectionPageState extends State<EventSelectionPage> {
  String? selectedEvent;

  @override
  Widget build(BuildContext context) {
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
                      // Nút quay lại
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.black),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Logo và Biểu tượng
                      Center(
                        child: Column(
                          children: [
                            const Text(
                              'DietAI',
                              style: TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF24204F),
                              ),
                            ),
                            const SizedBox(height: 24),
                            
                            // Biểu tượng sự kiện
                            Container(
                              width: 150,
                              height: 150,
                              child: Image.asset(
                                'assets/images/event_icon.png',
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(
                                    Icons.event_note,
                                    size: 100,
                                    color: Colors.indigo,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                      
                      // Tiêu đề
                      const Center(
                        child: Text(
                          'Bạn có sự kiện cụ thể nào đang thúc đẩy bạn lấy lại vóc dáng không?',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 40),
                      
                      // Lựa chọn sự kiện
                      _buildEventOption(
                        emoji: '👥',
                        label: 'Họp mặt',
                        isSelected: selectedEvent == 'Họp mặt',
                        onTap: () => setState(() => selectedEvent = 'Họp mặt'),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      _buildEventOption(
                        emoji: '🎂',
                        label: 'Sinh nhật',
                        isSelected: selectedEvent == 'Sinh nhật',
                        onTap: () => setState(() => selectedEvent = 'Sinh nhật'),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      _buildEventOption(
                        emoji: '📅',
                        label: 'Sự kiện khác',
                        isSelected: selectedEvent == 'Sự kiện khác',
                        onTap: () => setState(() => selectedEvent = 'Sự kiện khác'),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      _buildEventOption(
                        emoji: '❌',
                        label: 'Không',
                        isSelected: selectedEvent == 'Không',
                        onTap: () => setState(() => selectedEvent = 'Không'),
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
  
  Widget _buildEventOption({
    required String emoji,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.green.shade50 : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.green : Colors.grey.shade300,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            // Emoji
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              child: Text(
                emoji,
                style: TextStyle(fontSize: 24),
              ),
            ),
            const SizedBox(width: 16),
            
            // Nhãn
            Text(
              label,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.green.shade700 : Colors.black87,
              ),
            ),
            
            // Spacer
            const Spacer(),
            
            // Nút chọn
            if (isSelected)
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green,
                ),
                child: Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 16,
                ),
              ),
          ],
        ),
      ),
    );
  }
} 