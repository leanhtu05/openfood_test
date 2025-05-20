import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class VoiceRecordingService {
  final Record _audioRecorder = Record();
  bool _isRecording = false;
  String? _audioPath;

  bool get isRecording => _isRecording;
  String? get audioPath => _audioPath;
  bool get hasRecording => _audioPath != null;

  Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return status == PermissionStatus.granted;
  }

  Future<Map<String, dynamic>> toggleRecording() async {
    final isGranted = await requestMicrophonePermission();
    
    if (!isGranted) {
      return {
        'success': false,
        'message': 'Cần quyền truy cập microphone để sử dụng tính năng này',
      };
    }
    
    if (_isRecording) {
      final path = await _audioRecorder.stop();
      
      _isRecording = false;
      if (path != null) {
        _audioPath = path;
      }
      
      return {
        'success': true,
        'isRecording': false,
        'hasRecording': _audioPath != null,
        'message': 'Đã dừng ghi âm',
      };
    } else {
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final path = '${directory.path}/audio_$timestamp.m4a';
      
      await _audioRecorder.start(path: path);
      
      _isRecording = true;
      
      return {
        'success': true,
        'isRecording': true,
        'hasRecording': _audioPath != null,
        'message': 'Đang ghi âm... Nhấn lại để dừng',
      };
    }
  }

  void dispose() {
    _audioRecorder.dispose();
  }
} 