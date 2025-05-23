import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';

class AuthWrapper extends StatelessWidget {
  final Widget authenticatedRoute;
  final Widget unauthenticatedRoute;
  final bool requiresFullAuth;

  /// AuthWrapper checks authentication state and redirects accordingly
  /// 
  /// [authenticatedRoute]: The route/widget to show when user is authenticated
  /// [unauthenticatedRoute]: The route/widget to show when user is not authenticated
  /// [requiresFullAuth]: If true, anonymous users are treated as unauthenticated
  const AuthWrapper({
    Key? key,
    required this.authenticatedRoute,
    required this.unauthenticatedRoute,
    this.requiresFullAuth = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    
    // Show loading indicator while checking authentication
    if (authService.isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    // Check if user is authenticated based on requirements
    final isAuthenticated = requiresFullAuth 
        ? authService.isPremiumUser() 
        : authService.isAuthenticated;
    
    return isAuthenticated ? authenticatedRoute : unauthenticatedRoute;
  }
} 