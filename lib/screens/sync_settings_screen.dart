import 'package:flutter/material.dart';
import '../widgets/sync_settings_widget.dart';

class SyncSettingsScreen extends StatelessWidget {
  const SyncSettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cài đặt đồng bộ'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: const [
            SyncSettingsWidget(),
          ],
        ),
      ),
    );
  }
} 