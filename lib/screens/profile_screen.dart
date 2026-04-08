import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../constants/app_constants.dart';
import '../widgets/custom_button.dart';
import '../services/firebase_service.dart';
import 'edit_profile_screen.dart';
import 'splash_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _pushNotifications = true;
  bool _locationTracking = true;

  // Performance data
  Map<String, dynamic> _performanceData = {
    'totalCalls': 0,
    'collegeVisits': 0,
    'conversions': 0,
  };
  bool _isLoadingPerformance = true;

  @override
  void initState() {
    super.initState();
    _loadPerformanceData();
  }

  Future<void> _loadPerformanceData() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;

      if (user != null) {
        Map<String, dynamic> stats;

        if (user.id == 'admin_001') {
          // Admin gets overall stats
          stats = await FirebaseService.getDashboardStats();
        } else {
          // Regular user gets their specific stats
          stats = await FirebaseService.getUserDashboardStats(user.id);
        }

        if (mounted) {
          setState(() {
            _performanceData = {
              'totalCalls': stats['totalEnquiries'] ?? 0,
              'collegeVisits': stats['totalVisits'] ?? 0,
              'conversions': stats['conversions'] ?? 0,
            };
            _isLoadingPerformance = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading performance data: $e');
      if (mounted) {
        setState(() {
          _isLoadingPerformance = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.paddingL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    AppStrings.profile,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  IconButton(
                    onPressed: () async {
                      final result = await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const EditProfileScreen(),
                        ),
                      );
                      if (result == true) {
                        // Refresh performance data if profile was updated
                        _loadPerformanceData();
                      }
                    },
                    icon: const Icon(
                      Icons.edit,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSizes.paddingXL),

              // User Profile Card
              Container(
                padding: const EdgeInsets.all(AppSizes.paddingL),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppSizes.radiusL),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Avatar
                    Stack(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              user?.avatar ?? 'U',
                              style: const TextStyle(
                                color: AppColors.textInverse,
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.surface,
                                width: 3,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSizes.paddingL),

                    // Name
                    Text(
                      user?.name ?? 'User Name',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSizes.paddingS),

                    // Role
                    Text(
                      user?.role ?? 'Role',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: AppSizes.paddingXS),

                    // Organization
                    Text(
                      user?.organization ?? 'Organization',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: AppSizes.paddingL),

                    // Contact Info
                    Row(
                      children: [
                        const Icon(
                          Icons.email,
                          size: AppSizes.iconS,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: AppSizes.paddingS),
                        Text(
                          user?.email ?? 'email@example.com',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSizes.paddingS),
                    Row(
                      children: [
                        const Icon(
                          Icons.phone,
                          size: AppSizes.iconS,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: AppSizes.paddingS),
                        Text(
                          user?.phone ?? '+91 98765 43210',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSizes.paddingXL),

              // Performance Section
              const Text(
                'Your Performance',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSizes.paddingL),

              Row(
                children: [
                  Expanded(
                    child: _buildPerformanceCard(
                      icon: Icons.phone,
                      iconColor: AppColors.info,
                      value: _isLoadingPerformance
                          ? '...'
                          : _performanceData['totalCalls'].toString(),
                      label: 'Total Calls',
                      isLoading: _isLoadingPerformance,
                    ),
                  ),
                  const SizedBox(width: AppSizes.paddingM),
                  Expanded(
                    child: _buildPerformanceCard(
                      icon: Icons.location_on,
                      iconColor: AppColors.success,
                      value: _isLoadingPerformance
                          ? '...'
                          : _performanceData['collegeVisits'].toString(),
                      label: 'College Visits',
                      isLoading: _isLoadingPerformance,
                    ),
                  ),
                  const SizedBox(width: AppSizes.paddingM),
                  Expanded(
                    child: _buildPerformanceCard(
                      icon: Icons.emoji_events,
                      iconColor: AppColors.statusFollowUp,
                      value: _isLoadingPerformance
                          ? '...'
                          : _performanceData['conversions'].toString(),
                      label: 'Conversions',
                      isLoading: _isLoadingPerformance,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSizes.paddingXL),

              // Settings Section
              const Text(
                'Settings',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSizes.paddingL),

              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppSizes.radiusL),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildSettingItem(
                      icon: Icons.notifications,
                      iconColor: AppColors.warning,
                      title: 'Push Notifications',
                      isToggle: true,
                      value: _pushNotifications,
                      onChanged: (value) {
                        setState(() {
                          _pushNotifications = value;
                        });
                      },
                    ),
                    const Divider(height: 1),
                    _buildSettingItem(
                      icon: Icons.location_on,
                      iconColor: AppColors.success,
                      title: 'Location Tracking',
                      isToggle: true,
                      value: _locationTracking,
                      onChanged: (value) {
                        setState(() {
                          _locationTracking = value;
                        });
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSizes.paddingXL),

              // Settings Links
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppSizes.radiusL),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildSettingItem(
                      icon: Icons.edit,
                      iconColor: AppColors.primary,
                      title: 'Edit Profile',
                      isToggle: false,
                      onTap: () {
                        // TODO: Navigate to edit profile
                      },
                    ),
                    const Divider(height: 1),
                    _buildSettingItem(
                      icon: Icons.notifications,
                      iconColor: AppColors.warning,
                      title: 'Notification Settings',
                      isToggle: false,
                      onTap: () {
                        // TODO: Navigate to notification settings
                      },
                    ),
                    const Divider(height: 1),
                    _buildSettingItem(
                      icon: Icons.security,
                      iconColor: AppColors.success,
                      title: 'Privacy & Security',
                      isToggle: false,
                      onTap: () {
                        // TODO: Navigate to privacy settings
                      },
                    ),
                    const Divider(height: 1),
                    _buildSettingItem(
                      icon: Icons.help,
                      iconColor: AppColors.statusFollowUp,
                      title: 'Help & Support',
                      isToggle: false,
                      onTap: () {
                        // TODO: Navigate to help
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSizes.paddingXL),

              // Logout Button
              SizedBox(
                width: double.infinity,
                child: CustomButton(
                  text: 'Logout',
                  backgroundColor: AppColors.error,
                  icon: Icons.logout,
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Logout'),
                        content: const Text('Are you sure you want to logout?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('Logout'),
                          ),
                        ],
                      ),
                    );

                    if (confirmed == true) {
                      await authProvider.logout();
                      if (mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (context) => const SplashScreen(),
                          ),
                          (route) => false,
                        );
                      }
                    }
                  },
                ),
              ),

              const SizedBox(height: AppSizes.paddingXL),

              // App Version
              const Center(
                child: Text(
                  'Version 1.0.0',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.paddingS),
              const Center(
                child: Text(
                  'Made with ❤️ for Acadeno CRM Team',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPerformanceCard({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
    bool isLoading = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.paddingM),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 6),
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: AppSizes.iconL),
          const SizedBox(height: AppSizes.paddingS),
          isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                  ),
                )
              : Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
          const SizedBox(height: AppSizes.paddingXS),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required bool isToggle,
    bool? value,
    Function(bool)? onChanged,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(AppSizes.paddingS),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: AppSizes.iconM),
      ),
      title: Text(
        title,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
      ),
      trailing: isToggle
          ? Switch(
              value: value ?? false,
              onChanged: onChanged,
              activeColor: AppColors.primary,
            )
          : const Icon(
              Icons.arrow_forward_ios,
              color: AppColors.textSecondary,
              size: AppSizes.iconS,
            ),
      onTap: onTap,
    );
  }
}
