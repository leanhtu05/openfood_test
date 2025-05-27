import 'package:flutter/material.dart';
import '../screens/admin/firestore_admin_screen.dart';

class AdminRoutes {
  static const String firestoreAdmin = '/admin/firestore';

  static Map<String, WidgetBuilder> getRoutes() {
    return {
      firestoreAdmin: (context) => const FirestoreAdminScreen(),
    };
  }
  
  // Helper để điều hướng đến trang Admin Firestore
  static void navigateToFirestoreAdmin(BuildContext context) {
    Navigator.of(context).pushNamed(firestoreAdmin);
  }
} 