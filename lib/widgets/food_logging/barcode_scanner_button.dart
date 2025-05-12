import 'package:flutter/material.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

class BarcodeScannerButton extends StatelessWidget {
  final Function(String) onBarcodeScan;

  const BarcodeScannerButton({
    Key? key,
    required this.onBarcodeScan,
  }) : super(key: key);

  Future<void> _scanBarcode(BuildContext context) async {
    try {
      final permissionStatus = await Permission.camera.request();
      
      if (permissionStatus.isGranted) {
        String barcodeScanRes = await FlutterBarcodeScanner.scanBarcode(
          '#ff6666', 
          'Huỷ', 
          true, 
          ScanMode.BARCODE
        );
        
        if (barcodeScanRes != '-1') {
          // Chuyển kết quả lên màn hình chính
          onBarcodeScan(barcodeScanRes);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cần quyền truy cập camera để sử dụng tính năng này'))
        );
      }
    } catch (e) {
      print('Lỗi khi quét mã vạch: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể quét mã vạch: $e'))
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _scanBarcode(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 80,
        height: 85,
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.purple.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              flex: 2,
              child: Icon(Icons.qr_code_scanner, color: Colors.purple, size: 22),
            ),
            SizedBox(height: 4),
            Flexible(
              flex: 1,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Mã vạch',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.purple,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 