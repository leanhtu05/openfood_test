import 'package:flutter/material.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

class BarcodeScannerService {
  Future<String?> scanBarcode() async {
    try {
      final permissionStatus = await Permission.camera.request();
      
      if (permissionStatus.isGranted) {
        String barcodeScanRes = await FlutterBarcodeScanner.scanBarcode(
          '#ff6666', 
          'Hủy', 
          true, 
          ScanMode.BARCODE
        );
        
        if (barcodeScanRes != '-1') {
          return barcodeScanRes;
        }
      } 
      return null;
    } catch (e) {
      return null;
    }
  }
} 