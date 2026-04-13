import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/task_provider.dart';
import '../providers/dashboard_provider.dart';
import '../constants/app_constants.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_snackbar.dart';
import '../widgets/custom_page_transition.dart';
import '../utils/responsive_helper.dart';
import 'follow_up_screen.dart';
import 'college_visit_screen.dart';
import 'profile_screen.dart';
import 'add_college_visit_screen.dart';
import 'add_follow_up_screen.dart';
import 'add_enquiry_screen.dart';
import 'call_logs_screen.dart';
import 'sales_analytics_screen.dart';
import 'add_task_screen.dart';
import 'tasks_screen.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _animationController.forward();

    // Load dashboard data when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshAllData();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _refreshAllData() async {
    final dashboardProvider = Provider.of<DashboardProvider>(
      context,
      listen: false,
    );
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Wait a bit to ensure auth provider has initialized
    await Future.delayed(const Duration(milliseconds: 100));

    // Set current user if available
    if (authProvider.user != null && authProvider.user!.id != 'admin_001') {
      dashboardProvider.setCurrentUser(authProvider.user!.id);
    }

    await dashboardProvider.loadDashboardData();
  }

  void _onTabTapped(int index) {
    if (index != _currentIndex) {
      setState(() {
        _currentIndex = index;
      });

      // Animate the transition
      _animationController.reset();
      _animationController.forward();

      // Refresh data when switching tabs
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final dashboardProvider = Provider.of<DashboardProvider>(
          context,
          listen: false,
        );
        dashboardProvider.refreshData();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // For other users, show the regular dashboard with bottom navigation
    final List<Widget> screens = [
      const DashboardContent(),
      const CallLogsScreen(),
      const CollegeVisitScreen(),
      const FollowUpScreen(),
      const SalesAnalyticsScreen(),
      const TasksScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: screens[_currentIndex],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          child: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            backgroundColor: AppColors.surface,
            selectedItemColor: AppColors.primary,
            unselectedItemColor: AppColors.textSecondary,
            selectedLabelStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            currentIndex: _currentIndex,
            onTap: _onTabTapped,
            elevation: 0,
            items: [
              _buildAnimatedNavItem(
                icon: Icons.dashboard,
                label: AppStrings.dashboard,
                index: 0,
              ),
              _buildAnimatedNavItem(
                icon: Icons.phone,
                label: "History",
                index: 1,
              ),
              _buildAnimatedNavItem(
                icon: Icons.location_on,
                label: AppStrings.visits,
                index: 2,
              ),
              _buildAnimatedNavItem(
                icon: Icons.calendar_today,
                label: AppStrings.followUps,
                index: 3,
              ),
              _buildAnimatedNavItem(
                icon: Icons.analytics,
                label: AppStrings.analytics,
                index: 4,
              ),
              _buildAnimatedNavItem(
                icon: Icons.task_alt,
                label: 'Tasks',
                index: 5,
              ),
              _buildAnimatedNavItem(
                icon: Icons.person,
                label: AppStrings.profile,
                index: 6,
              ),
            ],
          ),
        ),
      ),
    );
  }

  BottomNavigationBarItem _buildAnimatedNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isSelected = _currentIndex == index;

    return BottomNavigationBarItem(
      icon: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 200),
          scale: isSelected ? 1.2 : 1.0,
          child: AnimatedRotation(
            duration: const Duration(milliseconds: 300),
            turns: isSelected ? 0.1 : 0.0,
            child: Icon(
              icon,
              size: ResponsiveHelper.getResponsiveIconSize(context, 24),
            ),
          ),
        ),
      ),
      label: label,
    );
  }
}

class DashboardContent extends StatefulWidget {
  const DashboardContent({super.key});

  @override
  State<DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends State<DashboardContent>
    with TickerProviderStateMixin {
  late AnimationController _staggerController;
  late List<Animation<double>> _fadeAnimations;
  late List<Animation<Offset>> _slideAnimations;
  late AnimationController _floatingController;
  late Animation<double> _floatingAnimation;

  @override
  void initState() {
    super.initState();

    _staggerController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _floatingController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    // Create staggered animations for different sections
    _fadeAnimations = List.generate(6, (index) {
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _staggerController,
          curve: Interval(
            index * 0.1,
            (index + 1) * 0.1,
            curve: Curves.easeOut,
          ),
        ),
      );
    });

    _slideAnimations = List.generate(6, (index) {
      return Tween<Offset>(
        begin: const Offset(0, 0.3),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _staggerController,
          curve: Interval(
            index * 0.1,
            (index + 1) * 0.1,
            curve: Curves.easeOutCubic,
          ),
        ),
      );
    });

    _floatingAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _floatingController, curve: Curves.easeInOut),
    );

    _staggerController.forward();
    _floatingController.repeat(reverse: true);

    // Load dashboard data when content initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final dashboardProvider = Provider.of<DashboardProvider>(
        context,
        listen: false,
      );
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final taskProvider = Provider.of<TaskProvider>(context, listen: false);

      // Set current user if available
      if (authProvider.user != null && authProvider.user!.id != 'admin_001') {
        dashboardProvider.setCurrentUser(authProvider.user!.id);
        taskProvider.fetchTodaysTasks(authProvider.user!.id);
      }

      dashboardProvider.loadDashboardData();
    });
  }

  @override
  void dispose() {
    _staggerController.dispose();
    _floatingController.dispose();
    super.dispose();
  }

  Future<void> _refreshAllData() async {
    final dashboardProvider = Provider.of<DashboardProvider>(
      context,
      listen: false,
    );
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Wait a bit to ensure auth provider has initialized
    await Future.delayed(const Duration(milliseconds: 100));

    // Set current user if available
    if (authProvider.user != null && authProvider.user!.id != 'admin_001') {
      dashboardProvider.setCurrentUser(authProvider.user!.id);
      Provider.of<TaskProvider>(
        context,
        listen: false,
      ).fetchTodaysTasks(authProvider.user!.id);
    }

    await dashboardProvider.loadDashboardData();
  }

  Future<void> _navigateToAddCollegeVisit() async {
    final result = await Navigator.of(
      context,
    ).push(CustomPageTransition(child: const AddCollegeVisitScreen()));

    if (result == true) {
      // Refresh all data
      await _refreshAllData();
      CustomSnackBar.showSuccess(context, 'College visit added successfully!');
    }
  }

  Future<void> _navigateToAddFollowUp() async {
    final result = await Navigator.of(
      context,
    ).push(CustomPageTransition(child: const AddFollowUpScreen()));

    if (result == true) {
      // Refresh all data
      await _refreshAllData();
      CustomSnackBar.showSuccess(context, 'Follow-up scheduled successfully!');
    }
  }

  Future<void> _navigateToAddEnquiry() async {
    final result = await Navigator.of(
      context,
    ).push(CustomPageTransition(child: const AddEnquiryScreen()));

    if (result == true) {
      // Refresh all data
      await _refreshAllData();
      CustomSnackBar.showSuccess(context, 'Enquiry added successfully!');
    }
  }

  Future<void> _navigateToCallLogs() async {
    await Navigator.of(
      context,
    ).push(CustomPageTransition(child: const CallLogsScreen()));
  }

  Future<void> _navigateToAddTask() async {
    final result = await Navigator.of(
      context,
    ).push(CustomPageTransition(child: const AddTaskScreen()));

    if (result == true) {
      await _refreshAllData();
      CustomSnackBar.showSuccess(context, 'Task added successfully!');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final dashboardProvider = Provider.of<DashboardProvider>(context);
    final taskProvider = Provider.of<TaskProvider>(context);
    final user = authProvider.user;

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddTask,
        tooltip: 'Add Note/Task',
        child: const Icon(Icons.add_task),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await dashboardProvider.refreshData();
          },
          child: SingleChildScrollView(
            padding: ResponsiveHelper.getResponsivePadding(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with notification - Animated
                FadeTransition(
                  opacity: _fadeAnimations[0],
                  child: SlideTransition(
                    position: _slideAnimations[0],
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ResponsiveHelper.responsiveTextBuilder(
                              context: context,
                              text: _getGreeting(),
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(
                              height: ResponsiveHelper.getResponsiveSpacing(
                                context,
                                AppSizes.paddingXS,
                              ),
                            ),
                            ResponsiveHelper.responsiveTextBuilder(
                              context: context,
                              text: user?.name ?? 'User',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: _navigateToCallLogs,
                          icon: Icon(
                            Icons.history,
                            size: ResponsiveHelper.getResponsiveIconSize(
                              context,
                              AppSizes.iconL,
                            ),
                            color: AppColors.primary,
                          ),
                          tooltip: 'Call Logs',
                        ),
                        AnimatedBuilder(
                          animation: _floatingAnimation,
                          builder: (context, child) {
                            return Transform.translate(
                              offset: Offset(0, _floatingAnimation.value * 3),
                              child: Stack(
                                children: [
                                  Icon(
                                    Icons.notifications_outlined,
                                    size:
                                        ResponsiveHelper.getResponsiveIconSize(
                                          context,
                                          AppSizes.iconL,
                                        ),
                                    color: AppColors.textSecondary,
                                  ),
                                  if (dashboardProvider
                                      .todayFollowUps
                                      .isNotEmpty)
                                    Positioned(
                                      right: 0,
                                      top: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: AppColors.error,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Text(
                                          '${dashboardProvider.todayFollowUps.length}',
                                          style: const TextStyle(
                                            color: AppColors.textInverse,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  height: ResponsiveHelper.getResponsiveSpacing(
                    context,
                    AppSizes.paddingXL,
                  ),
                ),

                // Today's Performance Card - Animated
                FadeTransition(
                  opacity: _fadeAnimations[1],
                  child: SlideTransition(
                    position: _slideAnimations[1],
                    child: dashboardProvider.isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _buildPerformanceCard(dashboardProvider),
                  ),
                ),
                SizedBox(
                  height: ResponsiveHelper.getResponsiveSpacing(
                    context,
                    AppSizes.paddingXL,
                  ),
                ),

                // Key Metrics Grid - Animated
                FadeTransition(
                  opacity: _fadeAnimations[2],
                  child: SlideTransition(
                    position: _slideAnimations[2],
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ResponsiveHelper.responsiveTextBuilder(
                          context: context,
                          text: 'Key Metrics',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(
                          height: ResponsiveHelper.getResponsiveSpacing(
                            context,
                            AppSizes.paddingL,
                          ),
                        ),
                        _buildMetricsGrid(dashboardProvider),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  height: ResponsiveHelper.getResponsiveSpacing(
                    context,
                    AppSizes.paddingXL,
                  ),
                ),

                // Quick Actions - Animated
                FadeTransition(
                  opacity: _fadeAnimations[3],
                  child: SlideTransition(
                    position: _slideAnimations[3],
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ResponsiveHelper.responsiveTextBuilder(
                          context: context,
                          text: AppStrings.quickActions,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(
                          height: ResponsiveHelper.getResponsiveSpacing(
                            context,
                            AppSizes.paddingL,
                          ),
                        ),
                        ResponsiveHelper.responsiveBuilder(
                          context: context,
                          mobile: Column(
                            children: [
                              _buildAnimatedButton(
                                text: "Add Lead",
                                icon: Icons.person_add_outlined,
                                onPressed: () {
                                  _navigateToAddEnquiry();
                                },
                                delay: 0,
                              ),
                              SizedBox(
                                height: ResponsiveHelper.getResponsiveSpacing(
                                  context,
                                  AppSizes.paddingM,
                                ),
                              ),
                              _buildAnimatedButton(
                                text: AppStrings.addVisit,
                                icon: Icons.location_on,
                                isOutlined: true,
                                onPressed: () {
                                  _navigateToAddCollegeVisit();
                                },
                                delay: 100,
                              ),
                              SizedBox(
                                height: ResponsiveHelper.getResponsiveSpacing(
                                  context,
                                  AppSizes.paddingM,
                                ),
                              ),
                              _buildAnimatedButton(
                                text: 'Call History',
                                icon: Icons.history,
                                isOutlined: true,
                                onPressed: _navigateToCallLogs,
                                delay: 200,
                              ),
                            ],
                          ),
                          tablet: Row(
                            children: [
                              Expanded(
                                child: _buildAnimatedButton(
                                  text: "Add Lead",
                                  icon: Icons.person_add_outlined,
                                  onPressed: () {
                                    _navigateToAddEnquiry();
                                  },
                                  delay: 0,
                                ),
                              ),
                              SizedBox(
                                width: ResponsiveHelper.getResponsiveSpacing(
                                  context,
                                  AppSizes.paddingM,
                                ),
                              ),
                              Expanded(
                                child: _buildAnimatedButton(
                                  text: AppStrings.addVisit,
                                  icon: Icons.location_on,
                                  isOutlined: true,
                                  onPressed: () {
                                    _navigateToAddCollegeVisit();
                                  },
                                  delay: 100,
                                ),
                              ),
                              SizedBox(
                                width: ResponsiveHelper.getResponsiveSpacing(
                                  context,
                                  AppSizes.paddingM,
                                ),
                              ),
                              Expanded(
                                child: _buildAnimatedButton(
                                  text: 'Call History',
                                  icon: Icons.history,
                                  isOutlined: true,
                                  onPressed: _navigateToCallLogs,
                                  delay: 200,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSizes.paddingL),
                        _buildSalesDialerSections(dashboardProvider),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.paddingXL),

                // Recent Activities - Animated
                FadeTransition(
                  opacity: _fadeAnimations[4],
                  child: SlideTransition(
                    position: _slideAnimations[4],
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            ResponsiveHelper.responsiveTextBuilder(
                              context: context,
                              text: AppStrings.recentActivities,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                // TODO: Navigate to all activities
                              },
                              child: ResponsiveHelper.responsiveTextBuilder(
                                context: context,
                                text: AppStrings.viewAll,
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(
                          height: ResponsiveHelper.getResponsiveSpacing(
                            context,
                            AppSizes.paddingL,
                          ),
                        ),
                        _buildRecentActivities(dashboardProvider),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  height: ResponsiveHelper.getResponsiveSpacing(
                    context,
                    AppSizes.paddingXL,
                  ),
                ),

                // Today's Tasks & Goals - Animated
                FadeTransition(
                  opacity: _fadeAnimations[5],
                  child: SlideTransition(
                    position: _slideAnimations[5],
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            ResponsiveHelper.responsiveTextBuilder(
                              context: context,
                              text: 'Today\'s Tasks & Goals',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextButton(
                              onPressed: _navigateToAddTask,
                              child: const Text('+ Add Task'),
                            ),
                          ],
                        ),
                        SizedBox(
                          height: ResponsiveHelper.getResponsiveSpacing(
                            context,
                            AppSizes.paddingL,
                          ),
                        ),
                        _buildTodayTasks(taskProvider),
                        const SizedBox(height: AppSizes.paddingM),
                        _buildTodayGoals(dashboardProvider),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning';
    } else if (hour < 17) {
      return 'Good Afternoon';
    } else {
      return 'Good Evening';
    }
  }

  Widget _buildPerformanceCard(DashboardProvider dashboardProvider) {
    final stats = dashboardProvider.stats;
    final totalCalls = stats['todayEnquiries'] ?? 0;
    final totalVisits = stats['todayVisits'] ?? 0;
    final totalFollowUps = stats['todayFollowUps'] ?? 0;

    // Calculate performance score based on activities
    final totalActivities = totalCalls + totalVisits + totalFollowUps;
    final performanceScore = totalActivities > 0
        ? (totalActivities / 20 * 100).clamp(0, 100)
        : 0;

    return Container(
      padding: const EdgeInsets.all(AppSizes.paddingL),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  AppStrings.todayPerformance,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSizes.paddingM),
                Text(
                  performanceScore >= 80
                      ? 'Excellent Work!'
                      : performanceScore >= 60
                      ? 'Good Progress!'
                      : performanceScore >= 40
                      ? 'Keep Going!'
                      : 'Let\'s Get Started!',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: AppSizes.paddingM),
                LinearProgressIndicator(
                  value: performanceScore / 100,
                  backgroundColor: AppColors.textSecondary.withOpacity(0.1),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.success,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.paddingL),
          Column(
            children: [
              Text(
                '${performanceScore.toInt()}',
                style: const TextStyle(
                  color: AppColors.success,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                'Score',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSalesDialerSections(DashboardProvider dashboardProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Quick CRM Actions",
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
              child: _buildQuickActionCard(
                title: "View Notes",
                subtitle: "Recent call notes",
                icon: Icons.note_outlined,
                color: Colors.purple,
                onTap: () {
                  _showRecentNotesDialog(context);
                },
              ),
            ),
            const SizedBox(width: AppSizes.paddingM),
            Expanded(
              child: _buildQuickActionCard(
                title: "Schedule",
                subtitle: "Add Follow-up",
                icon: Icons.calendar_today_outlined,
                color: Colors.orange,
                onTap: () {
                  _navigateToAddFollowUp();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.paddingM),
      ],
    );
  }

  void _showRecentNotesDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Global Call Notes",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Expanded(
                child: Center(
                  child: Text(
                    "Notes feature is active in Lead Profiles and Call Tracker.",
                  ),
                ),
              ),
              const SizedBox(height: 16),
              CustomButton(
                text: "Close",
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              subtitle,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

    final todayTotal = stats['todayCalls'] ?? 0;
    final todayIncoming = stats['incomingCalls'] ?? 0;
    final todayOutgoing = stats['outgoingCalls'] ?? 0;
    final missedCalls = stats['missedCalls'] ?? 0;

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: AppSizes.paddingM,
      mainAxisSpacing: AppSizes.paddingM,
      childAspectRatio: 1.4,
      children: [
        _buildMetricCard(
          icon: Icons.call_received,
          iconColor: Colors.green,
          value: '$todayIncoming',
          label: 'Incoming Today',
        ),
        _buildMetricCard(
          icon: Icons.call_made,
          iconColor: AppColors.primary,
          value: '$todayOutgoing',
          label: 'Outgoing Today',
        ),
        _buildMetricCard(
          icon: Icons.history,
          iconColor: AppColors.info,
          value: '$todayTotal',
          label: 'Total Calls',
        ),
        _buildMetricCard(
          icon: Icons.call_missed,
          iconColor: AppColors.error,
          value: '$missedCalls',
          label: 'Missed Calls',
        ),
      ],
    );
  }

  Widget _buildRecentActivities(DashboardProvider dashboardProvider) {
    final activities = <Map<String, dynamic>>[];

    // Add recent enquiries
    for (final enquiry in dashboardProvider.recentEnquiries.take(3)) {
      activities.add({
        'type': 'call',
        'title': 'Call with ${enquiry['contactName'] ?? 'Contact'}',
        'subtitle': enquiry['notes'] ?? 'Enquiry logged',
        'time': _formatTime(enquiry['createdAt']),
        'icon': Icons.phone,
        'iconColor': AppColors.success,
        'statusColor': AppColors.success,
      });
    }

    // Add recent visits
    for (final visit in dashboardProvider.recentVisits.take(2)) {
      activities.add({
        'type': 'visit',
        'title': 'Visit to ${visit['collegeName'] ?? 'College'}',
        'subtitle': visit['notes'] ?? 'College visit logged',
        'time': _formatTime(visit['visitDate']),
        'icon': Icons.location_on,
        'iconColor': AppColors.info,
        'statusColor': AppColors.info,
      });
    }

    // Add recent follow-ups
    for (final followUp in dashboardProvider.recentFollowUps.take(2)) {
      activities.add({
        'type': 'followup',
        'title': 'Follow-up with ${followUp['contactName'] ?? 'Contact'}',
        'subtitle': followUp['notes'] ?? 'Follow-up scheduled',
        'time': _formatTime(followUp['followUpDate']),
        'icon': Icons.calendar_today,
        'iconColor': AppColors.warning,
        'statusColor': AppColors.warning,
      });
    }

    // Sort activities by time (most recent first)
    activities.sort((a, b) => b['time'].compareTo(a['time']));

    if (activities.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text(
            'No recent activities',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
          ),
        ),
      );
    }

    return Column(
      children: activities
          .take(5)
          .map(
            (activity) => _buildActivityItem(
              icon: activity['icon'],
              iconColor: activity['iconColor'],
              title: activity['title'],
              subtitle: activity['subtitle'],
              time: activity['time'],
              statusColor: activity['statusColor'],
            ),
          )
          .toList(),
    );
  }

  Widget _buildTodayTasks(TaskProvider taskProvider) {
    if (taskProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final tasks = taskProvider.todaysTasks;
    if (tasks.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 16.0),
        child: Text(
          'No specific tasks added for today.',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    return Column(
      children: tasks.map((task) {
        return Container(
          margin: const EdgeInsets.only(bottom: AppSizes.paddingS),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSizes.radiusM),
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
          ),
          child: ListTile(
            leading: Checkbox(
              value: task.isCompleted,
              activeColor: AppColors.primary,
              onChanged: (val) {
                taskProvider.toggleTaskCompletion(task.id, task.isCompleted);
              },
            ),
            title: Text(
              task.title,
              style: TextStyle(
                decoration: task.isCompleted
                    ? TextDecoration.lineThrough
                    : null,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (task.description.isNotEmpty) Text(task.description),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.access_time,
                      size: 12,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('hh:mm a').format(task.date),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (task.reminderSet) ...[
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.notifications_active,
                        size: 12,
                        color: AppColors.primary,
                      ),
                    ],
                  ],
                ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.error),
              onPressed: () {
                taskProvider.deleteTask(task);
                CustomSnackBar.showSuccess(context, 'Task deleted');
              },
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTodayGoals(DashboardProvider dashboardProvider) {
    final stats = dashboardProvider.stats;
    final todayCalls = stats['todayEnquiries'] ?? 0;
    final todayVisits = stats['todayVisits'] ?? 0;
    final todayFollowUps = stats['todayFollowUps'] ?? 0;

    return Column(
      children: [
        _buildGoalItem(
          icon: Icons.check_circle,
          iconColor: todayCalls >= 15 ? AppColors.success : AppColors.warning,
          title: 'Make 15 calls',
          progress: '$todayCalls/15',
        ),
        _buildGoalItem(
          icon: Icons.access_time,
          iconColor: todayVisits >= 2 ? AppColors.success : AppColors.warning,
          title: 'Visit 2 colleges',
          progress: '$todayVisits/2',
        ),
        _buildGoalItem(
          icon: Icons.track_changes,
          iconColor: todayFollowUps >= 3 ? AppColors.success : AppColors.error,
          title: 'Complete 3 follow-ups',
          progress: '$todayFollowUps/3',
        ),
      ],
    );
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return 'Just now';
    DateTime dateTime;
    if (timestamp is Timestamp) {
      dateTime = timestamp.toDate();
    } else if (timestamp is String) {
      dateTime = DateTime.parse(timestamp);
    } else {
      return 'Just now';
    }

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  Widget _buildMetricCard({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 800),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.elasticOut,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: Container(
            padding: const EdgeInsets.all(AppSizes.paddingL),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSizes.radiusL),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 600),
                  tween: Tween(begin: 0.0, end: 1.0),
                  curve: Curves.bounceOut,
                  builder: (context, iconScale, child) {
                    return Transform.scale(
                      scale: iconScale,
                      child: Transform.rotate(
                        angle: (1 - iconScale) * 0.5,
                        child: Icon(icon, size: 32, color: iconColor),
                      ),
                    );
                  },
                ),
                const SizedBox(height: AppSizes.paddingM),
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 400),
                  tween: Tween(begin: 0.0, end: 1.0),
                  curve: Curves.easeOutBack,
                  builder: (context, textScale, child) {
                    return Transform.scale(
                      scale: textScale,
                      child: Text(
                        value,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
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
          ),
        );
      },
    );
  }

  Widget _buildActivityItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String time,
    required Color statusColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.paddingM),
      padding: const EdgeInsets.all(AppSizes.paddingM),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 6),
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSizes.paddingS),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: AppSizes.paddingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSizes.paddingXS),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String progress,
  }) {
    final progressParts = progress.split('/');
    final current = int.tryParse(progressParts[0]) ?? 0;
    final target = int.tryParse(progressParts[1]) ?? 1;
    final progressValue = current / target;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.paddingM),
      padding: const EdgeInsets.all(AppSizes.paddingM),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 6),
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(width: AppSizes.paddingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSizes.paddingXS),
                LinearProgressIndicator(
                  value: progressValue,
                  backgroundColor: AppColors.textSecondary.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.paddingM),
          Text(
            progress,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedButton({
    required String text,
    required IconData icon,
    required VoidCallback onPressed,
    bool isOutlined = false,
    int delay = 0,
  }) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 600 + delay),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Transform.rotate(
            angle: (1 - value) * 0.1,
            child: CustomButton(
              text: text,
              icon: icon,
              isOutlined: isOutlined,
              onPressed: onPressed,
            ),
          ),
        );
      },
    );
  }
}
