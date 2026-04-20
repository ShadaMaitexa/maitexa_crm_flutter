import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../constants/app_constants.dart';
import '../services/firebase_service.dart';
import '../services/notification_service.dart';

class AuthProvider extends ChangeNotifier {
  User? _user;
  bool _isLoading = false;
  String? _error;
  bool _isAuthenticated = false;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _isAuthenticated;

  void updateUser(User updatedUser) {
    _user = updatedUser;
    _isAuthenticated = true;
    notifyListeners();
  }

  // Method to get current user ID safely
  String? get currentUserId => _user?.id;

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Use Firebase service for authentication
      final user = await FirebaseService.signInWithEmailAndPassword(
        email,
        password,
      );

      if (user != null) {
        _user = user;
        _isAuthenticated = true;

        // Save complete user data to shared preferences for persistent login
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_email', _user!.email);
        await prefs.setString('user_role', _user!.role);
        await prefs.setString('user_id', _user!.id);
        await prefs.setString('user_name', _user!.name);
        await prefs.setString('user_phone', _user!.phone);
        await prefs.setString('user_avatar', _user!.avatar);
        await prefs.setString('user_organization', _user!.organization);
        await prefs.setBool('is_authenticated', true);

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = 'Invalid credentials';
        _isLoading = false;
        _isAuthenticated = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Invalid credentials';
      _isLoading = false;
      _isAuthenticated = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> forgotPassword(String email) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await FirebaseService.sendPasswordResetEmail(email);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Clear shared preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // Reset state
      _user = null;
      _isAuthenticated = false;
      _error = null;

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> checkAuthStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isAuthenticated = prefs.getBool('is_authenticated') ?? false;
      final userEmail = prefs.getString('user_email');
      final userRole = prefs.getString('user_role');
      final userId = prefs.getString('user_id');
      final userName = prefs.getString('user_name');
      final userPhone = prefs.getString('user_phone');
      final userAvatar = prefs.getString('user_avatar');
      final userOrganization = prefs.getString('user_organization');

      if (isAuthenticated && userEmail != null && userRole != null) {
        // Check if it's admin
        if (userEmail == FirebaseService.adminEmail &&
            userRole == FirebaseService.adminRole) {
          _user = User(
            id: 'admin_001',
            name: FirebaseService.adminName,
            email: FirebaseService.adminEmail,
            role: FirebaseService.adminRole,
            phone: '+91 98765 43210',
            avatar: 'A',
            organization: 'Acadeno CRM',
            isActive: true,
            createdAt: DateTime.now(),
            lastLogin: DateTime.now(),
          );
          _isAuthenticated = true;
        } else {
          // For other users, always restore from saved data (no need to fetch from Firestore)
          if (userId != null && userName != null) {
            // Restore from saved data - this is the key for persistent login
            _user = User(
              id: userId,
              name: userName,
              email: userEmail,
              role: userRole,
              phone: userPhone ?? '',
              avatar: userAvatar ?? userEmail[0].toUpperCase(),
              organization: userOrganization ?? 'Acadeno CRM',
              isActive: true,
              createdAt: DateTime.now(),
              lastLogin: DateTime.now(),
            );
            _isAuthenticated = true;
          } else {
            _isAuthenticated = false;
          }
        }
      }
    } catch (e) {
      _isAuthenticated = false;
    }
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  bool isAdmin() {
    return _user?.role == 'admin';
  }

  bool isHR() {
    return _user?.role == AppStrings.roleHR;
  }

  bool isMarketingExecutive() {
    return _user?.role == AppStrings.roleMarketingExecutive;
  }
}
