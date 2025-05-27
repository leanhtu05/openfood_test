import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/firebase_web_fix.dart';

class FirebaseTestScreen extends StatefulWidget {
  const FirebaseTestScreen({Key? key}) : super(key: key);

  @override
  State<FirebaseTestScreen> createState() => _FirebaseTestScreenState();
}

class _FirebaseTestScreenState extends State<FirebaseTestScreen> {
  String _status = 'Initializing...';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkFirebaseStatus();
  }

  Future<void> _checkFirebaseStatus() async {
    try {
      setState(() {
        _isLoading = true;
        _status = 'Checking Firebase status...';
      });

      // Get current user
      User? currentUser = FirebaseAuth.instance.currentUser;
      
      if (currentUser != null) {
        setState(() {
          _status = 'User is signed in with ID: ${currentUser.uid}';
        });
      } else {
        setState(() {
          _status = 'No user signed in.';
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Error checking Firebase status: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _signInAnonymously() async {
    try {
      setState(() {
        _isLoading = true;
        _status = 'Attempting anonymous sign-in...';
      });

      // Try sign in
      UserCredential result = await FirebaseAuth.instance.signInAnonymously();
      
      setState(() {
        _status = 'Signed in anonymously with ID: ${result.user?.uid}';
      });
    } catch (e) {
      setState(() {
        _status = 'Error signing in: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _signOut() async {
    try {
      setState(() {
        _isLoading = true;
        _status = 'Signing out...';
      });

      await FirebaseAuth.instance.signOut();
      
      setState(() {
        _status = 'Signed out successfully';
      });
    } catch (e) {
      setState(() {
        _status = 'Error signing out: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firebase Test'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Firebase Status',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : Text(
                        _status,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _isLoading ? null : _checkFirebaseStatus,
                child: const Text('Refresh Status'),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _isLoading ? null : _signInAnonymously,
                child: const Text('Sign In Anonymously'),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _isLoading ? null : _signOut,
                child: const Text('Sign Out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 