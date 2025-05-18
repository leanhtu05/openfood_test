import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_data_provider.dart';
import 'onboarding_screen.dart';

class EventSelectionPage extends StatefulWidget {
  const EventSelectionPage({Key? key}) : super(key: key);

  @override
  State<EventSelectionPage> createState() => _EventSelectionPageState();
}

class _EventSelectionPageState extends State<EventSelectionPage> {
  String? selectedEvent;
  
  @override
  void initState() {
    super.initState();
    // Lấy dữ liệu từ provider khi khởi tạo
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userData = Provider.of<UserDataProvider>(context, listen: false);
      if (userData.event.isNotEmpty) {
        setState(() {
          selectedEvent = userData.event;
        });
      }
    });
  }
  
  // Lưu dữ liệu vào provider
  void _saveEvent(String event) {
    final userData = Provider.of<UserDataProvider>(context, listen: false);
    userData.event = event;
  }

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
              padding: OnboardingStyles.screenPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo và Biểu tượng
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'DietAI',
                          style: OnboardingStyles.appTitleStyle,
                        ),
                        const SizedBox(height: 24),
                        
                        // Biểu tượng sự kiện
                        SizedBox(
                          width: OnboardingStyles.iconSize,
                          height: OnboardingStyles.iconSize,
                          child: Image.asset(
                            'assets/images/event_icon.png',
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.event_note,
                                size: 100,
                                color: OnboardingStyles.accentColor,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  
                  // Tiêu đề
                  Center(
                    child: Text(
                      'Bạn có sự kiện cụ thể nào đang thúc đẩy bạn lấy lại vóc dáng không?',
                      style: OnboardingStyles.pageTitleStyle,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  // Lựa chọn sự kiện
                  _buildEventOption(
                    emoji: '👥',
                    label: 'Họp mặt',
                    isSelected: selectedEvent == 'Họp mặt',
                    onTap: () {
                      setState(() => selectedEvent = 'Họp mặt');
                      _saveEvent('Họp mặt');
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  _buildEventOption(
                    emoji: '🎂',
                    label: 'Sinh nhật',
                    isSelected: selectedEvent == 'Sinh nhật',
                    onTap: () {
                      setState(() => selectedEvent = 'Sinh nhật');
                      _saveEvent('Sinh nhật');
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  _buildEventOption(
                    emoji: '📅',
                    label: 'Sự kiện khác',
                    isSelected: selectedEvent == 'Sự kiện khác',
                    onTap: () {
                      setState(() => selectedEvent = 'Sự kiện khác');
                      _saveEvent('Sự kiện khác');
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  _buildEventOption(
                    emoji: '❌',
                    label: 'Không',
                    isSelected: selectedEvent == 'Không',
                    onTap: () {
                      setState(() => selectedEvent = 'Không');
                      _saveEvent('Không');
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      }
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
          color: isSelected ? OnboardingStyles.primaryColorLight : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? OnboardingStyles.primaryColor : Colors.grey.shade300,
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
                style: const TextStyle(fontSize: 24),
              ),
            ),
            const SizedBox(width: 16),
            
            // Nhãn
            Text(
              label,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isSelected ? OnboardingStyles.primaryColor : Colors.black87,
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
                  color: OnboardingStyles.primaryColor,
                ),
                child: const Icon(
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