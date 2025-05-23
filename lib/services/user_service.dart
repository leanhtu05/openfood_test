import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';

class UserService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _userCollection = 'users';

  // Get Firestore reference to user document
  DocumentReference _getUserDocRef(String uid) {
    return _firestore.collection(_userCollection).doc(uid);
  }

  // Create or update user document after sign in/up
  Future<AppUser> createOrUpdateUser(User firebaseUser) async {
    final userDocRef = _getUserDocRef(firebaseUser.uid);
    
    try {
      // Try to get existing user
      final docSnapshot = await userDocRef.get();
      
      if (docSnapshot.exists) {
        // Update existing user's last login date
        final existingUser = AppUser.fromFirestore(docSnapshot);
        final updatedUser = existingUser.updateLastLogin();
        
        await userDocRef.update({
          'lastLoginAt': Timestamp.fromDate(updatedUser.lastLoginAt),
        });
        
        return updatedUser;
      } else {
        // Create new user document
        final newUser = AppUser.fromAuth(
          uid: firebaseUser.uid,
          displayName: firebaseUser.displayName,
          email: firebaseUser.email,
          photoURL: firebaseUser.photoURL,
          isAnonymous: firebaseUser.isAnonymous,
        );
        
        await userDocRef.set(newUser.toFirestore());
        return newUser;
      }
    } catch (e) {
      print('Error creating/updating user: $e');
      rethrow;
    }
  }

  // Get current user data from Firestore
  Future<AppUser?> getCurrentUser() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return null;
    
    try {
      final docSnapshot = await _getUserDocRef(currentUser.uid).get();
      if (docSnapshot.exists) {
        return AppUser.fromFirestore(docSnapshot);
      }
      
      // If document doesn't exist, create it
      return await createOrUpdateUser(currentUser);
    } catch (e) {
      print('Error getting current user: $e');
      return null;
    }
  }

  // Update user profile data
  Future<void> updateUserProfile({
    String? displayName,
    String? photoURL,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('No authenticated user found');
    
    try {
      // Update in Firebase Auth
      await currentUser.updateDisplayName(displayName);
      await currentUser.updatePhotoURL(photoURL);
      
      // Update in Firestore
      await _getUserDocRef(currentUser.uid).update({
        if (displayName != null) 'displayName': displayName,
        if (photoURL != null) 'photoURL': photoURL,
      });
    } catch (e) {
      print('Error updating user profile: $e');
      rethrow;
    }
  }

  // Update user settings
  Future<void> updateUserSettings(Map<String, dynamic> settings) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('No authenticated user found');
    
    try {
      await _getUserDocRef(currentUser.uid).update({
        'settings': FieldValue.arrayUnion([settings]),
      });
    } catch (e) {
      print('Error updating user settings: $e');
      rethrow;
    }
  }

  // Update user food preferences
  Future<void> updateUserPreferences(Map<String, dynamic> preferences) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('No authenticated user found');
    
    try {
      await _getUserDocRef(currentUser.uid).update({
        'preferences': preferences,
      });
    } catch (e) {
      print('Error updating user preferences: $e');
      rethrow;
    }
  }

  // Delete user account and all associated data
  Future<void> deleteUserAccount() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('No authenticated user found');
    
    try {
      // Delete user document from Firestore
      await _getUserDocRef(currentUser.uid).delete();
      
      // Delete user from Firebase Auth
      await currentUser.delete();
    } catch (e) {
      print('Error deleting user account: $e');
      rethrow;
    }
  }
  
  // Convert anonymous account to permanent account
  Future<void> convertAnonymousAccount({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('No authenticated user found');
    if (!currentUser.isAnonymous) throw Exception('User is not anonymous');
    
    try {
      // Create credential
      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      
      // Link anonymous account with credential
      final userCredential = await currentUser.linkWithCredential(credential);
      
      // Update user data
      await userCredential.user?.updateDisplayName(displayName);
      
      // Update Firestore document
      await _getUserDocRef(currentUser.uid).update({
        'email': email,
        'displayName': displayName,
        'isAnonymous': false,
      });
    } catch (e) {
      print('Error converting anonymous account: $e');
      rethrow;
    }
  }
} 