import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors
  static const Color primary = Color(0xFF2563EB);
  static const Color secondary = Color(0xFF10B981);
  static const Color accent = Color(0xFFF59E0B);

  // Background Colors
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color card = Color(0xFFFFFFFF);

  // Text Colors
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textInverse = Color(0xFFFFFFFF);

  // Status Colors
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);

  // Priority Colors
  static const Color priorityHigh = Color(0xFFEF4444);
  static const Color priorityMedium = Color(0xFFF59E0B);
  static const Color priorityLow = Color(0xFF10B981);

  // Status Colors
  static const Color statusCompleted = Color(0xFF10B981);
  static const Color statusPending = Color(0xFFF59E0B);
  static const Color statusFollowUp = Color(0xFF8B5CF6);
}

class AppSizes {
  // Padding
  static const double paddingXS = 4.0;
  static const double paddingS = 8.0;
  static const double paddingM = 16.0;
  static const double paddingL = 24.0;
  static const double paddingXL = 32.0;

  // Margin
  static const double marginXS = 4.0;
  static const double marginS = 8.0;
  static const double marginM = 16.0;
  static const double marginL = 24.0;
  static const double marginXL = 32.0;

  // Border Radius
  static const double radiusS = 4.0;
  static const double radiusM = 8.0;
  static const double radiusL = 12.0;
  static const double radiusXL = 16.0;

  // Icon Sizes
  static const double iconS = 16.0;
  static const double iconM = 24.0;
  static const double iconL = 32.0;
  static const double iconXL = 48.0;
}

class AppStrings {
  static const String appName = 'Acadeno CRM';
  static const String appVersion = '1.0.0';
  static const String appTagline = 'Marketing Team Portal';
  static const String secureAccess =
      'Secure access for marketing professionals';

  // Login
  static const String emailAddress = 'Email Address';
  static const String password = 'Password';
  static const String signIn = 'Sign In';
  static const String forgotPassword = 'Forgot Password?';

  // Roles
  static const String roleAdmin = 'Admin';
  static const String roleHR = 'HR';
  static const String roleMarketingExecutive = 'Marketing Executive';

  // Dashboard
  static const String goodMorning = 'Good Morning';
  static const String todayPerformance = "Today's Performance";
  static const String greatWork = "Great work! You're above target for today.";
  static const String quickActions = 'Quick Actions';
  static const String recentActivities = 'Recent Activities';
  static const String viewAll = 'View All';
  static const String todayGoals = "Today's Goals";

  // Navigation
  static const String dashboard = 'Dashboard';
  static const String enquiries = 'Enquiries';
  static const String visits = 'Visits';
  static const String followUps = 'Follow-ups';
  static const String analytics = 'Analytics';
  static const String profile = 'Profile';

  // Actions
  static const String logCall = 'Log Call';
  static const String addVisit = 'Add Visit';
  static const String callNow = 'Call Now';
  static const String markDone = 'Mark Done';
  static const String viewDocs = 'View Docs';
  static const String schedule = 'Schedule';
  static const String location = 'Location';

  // Status
  static const String completed = 'COMPLETED';
  static const String followUp = 'FOLLOW-UP';
  static const String pending = 'PENDING';
  static const String overdue = 'OVERDUE';
  static const String upcoming = 'UPCOMING';

  // Priority
  static const String high = 'HIGH';
  static const String medium = 'MEDIUM';
  static const String low = 'LOW';

  // WhatsApp Messages
  static const String defaultWhatsAppMessage =
      "Hello,\n\nThank you for contacting Acadeno CRM.\n\nWhich course are you interested in?\n\n1. Python\n2. Data Analytics\n3. Flutter\n4. AI / Machine Learning";
}

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String dashboard = '/dashboard';
  static const String enquiries = '/enquiries';
  static const String visits = '/visits';
  static const String followUps = '/follow-ups';
  static const String analytics = '/analytics';
  static const String profile = '/profile';
  static const String settings = '/settings';
  static const String adminDashboard = '/admin-dashboard';
}

class AppConfig {
  // API Configuration
  static const String baseUrl = 'https://api.acadeno.com';
  static const String apiVersion = '/api';
  static const int timeoutDuration = 30000; // 30 seconds

  // Image Quality
  static const double imageQuality = 0.8;

  // App Settings
  static const bool enableNotifications = true;
  static const bool enableLocationTracking = true;
}
