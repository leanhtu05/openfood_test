import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String? displayName;
  final String? email;
  final String? photoURL;
  final bool isAnonymous;
  final DateTime createdAt;
  final DateTime lastLoginAt;
  final Map<String, dynamic>? settings;
  final Map<String, dynamic>? preferences;

  AppUser({
    required this.uid,
    this.displayName,
    this.email,
    this.photoURL,
    required this.isAnonymous,
    required this.createdAt,
    required this.lastLoginAt,
    this.settings,
    this.preferences,
  });

  // Create from Firebase Auth user data
  factory AppUser.fromAuth({
    required String uid,
    String? displayName,
    String? email,
    String? photoURL,
    required bool isAnonymous,
  }) {
    final now = DateTime.now();
    return AppUser(
      uid: uid,
      displayName: displayName,
      email: email,
      photoURL: photoURL,
      isAnonymous: isAnonymous,
      createdAt: now,
      lastLoginAt: now,
      settings: {},
      preferences: {},
    );
  }

  // Create from Firestore document
  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Xử lý trường createdAt
    DateTime createdAt;
    if (data['createdAt'] is Timestamp) {
      createdAt = (data['createdAt'] as Timestamp).toDate();
    } else if (data['createdAt'] is String) {
      try {
        createdAt = DateTime.parse(data['createdAt']);
      } catch (e) {
        createdAt = DateTime.now();
      }
    } else {
      createdAt = DateTime.now();
    }
    
    // Xử lý trường lastLoginAt
    DateTime lastLoginAt;
    if (data['lastLoginAt'] is Timestamp) {
      lastLoginAt = (data['lastLoginAt'] as Timestamp).toDate();
    } else if (data['lastLoginAt'] is String) {
      try {
        lastLoginAt = DateTime.parse(data['lastLoginAt']);
      } catch (e) {
        lastLoginAt = DateTime.now();
      }
    } else {
      lastLoginAt = DateTime.now();
    }
    
    return AppUser(
      uid: doc.id,
      displayName: data['displayName'],
      email: data['email'],
      photoURL: data['photoURL'],
      isAnonymous: data['isAnonymous'] ?? false,
      createdAt: createdAt,
      lastLoginAt: lastLoginAt,
      settings: data['settings'],
      preferences: data['preferences'],
    );
  }

  // Convert to map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'displayName': displayName,
      'email': email,
      'photoURL': photoURL,
      'isAnonymous': isAnonymous,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastLoginAt': Timestamp.fromDate(lastLoginAt),
      'settings': settings ?? {},
      'preferences': preferences ?? {},
    };
  }

  // Create copy with updated fields
  AppUser copyWith({
    String? displayName,
    String? photoURL,
    DateTime? lastLoginAt,
    Map<String, dynamic>? settings,
    Map<String, dynamic>? preferences,
  }) {
    return AppUser(
      uid: this.uid,
      displayName: displayName ?? this.displayName,
      email: this.email,
      photoURL: photoURL ?? this.photoURL,
      isAnonymous: this.isAnonymous,
      createdAt: this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      settings: settings ?? this.settings,
      preferences: preferences ?? this.preferences,
    );
  }

  // Update last login timestamp
  AppUser updateLastLogin() {
    return copyWith(lastLoginAt: DateTime.now());
  }
} 