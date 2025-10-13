import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_constants.dart';
import '../providers/dashboard_provider.dart';
import '../providers/auth_provider.dart';
import '../services/firebase_service.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  int _selectedPeriod = 1; // 0: Today, 1: This Week, 2: This Month
  final List<String> _periods = ['Today', 'This Week', 'This Month'];
  Map<String, dynamic> _analyticsData = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAnalyticsData();
  }

  Future<void> _loadAnalyticsData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      if (authProvider.user != null && authProvider.user!.id != 'admin_001') {
        _analyticsData = await FirebaseService.getUserDashboardStats(authProvider.user!.id);
      } else {
        _analyticsData = await FirebaseService.getDashboardStats();
      }
    } catch (e) {
      print('Error loading analytics data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
   
    final stats = _isLoading ? <String, dynamic>{} : _analyticsData;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadAnalyticsData,
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
                      AppStrings.analytics,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        _loadAnalyticsData();
                      },
                      icon: const Icon(
                        Icons.refresh,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppSizes.paddingL),

                // Time Period Selection
                Row(
                  children: List.generate(_periods.length, (index) {
                    final isSelected = _selectedPeriod == index;
                    return Expanded(
                      child: Container(
                        margin: EdgeInsets.only(
                          right: index < _periods.length - 1
                              ? AppSizes.paddingS
                              : 0,
                        ),
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _selectedPeriod = index;
                            });
                            _loadAnalyticsData();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isSelected
                                ? AppColors.primary
                                : AppColors.surface,
                            foregroundColor: isSelected
                                ? AppColors.textInverse
                                : AppColors.textSecondary,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppSizes.radiusM,
                              ),
                              side: BorderSide(
                                color: isSelected
                                    ? AppColors.primary
                                   
                                    : AppColors.textSecondary.withOpacity(0.3),
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSizes.paddingM,
                            ),
                          ),
                          child: Text(_periods[index]),
                        ),
                      ),
                    );
                  }),
                ),

                const SizedBox(height: AppSizes.paddingXL),

                // KPI Cards
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: AppSizes.paddingM,
                    mainAxisSpacing: AppSizes.paddingM,
                    childAspectRatio: 1.1,
                    children: [
                      _buildKPICard(
                        icon: Icons.phone_outlined,
                        iconColor: AppColors.info,
                        value: '${stats['totalEnquiries'] ?? 0}',
                        label: 'Total Calls',
                        trend: _calculateTrend(stats['totalEnquiries'] ?? 0),
                        trendColor: AppColors.success,
                      ),
                      _buildKPICard(
                        icon: Icons.location_on_outlined,
                        iconColor: AppColors.success,
                        value: '${stats['totalVisits'] ?? 0}',
                        label: 'College Visits',
                        trend: _calculateTrend(stats['totalVisits'] ?? 0),
                        trendColor: AppColors.success,
                      ),
                      _buildKPICard(
                        icon: Icons.track_changes_outlined,
                        iconColor: AppColors.statusFollowUp,
                        value: '${stats['conversions'] ?? 0}',
                        label: 'Conversions',
                        trend: _calculateTrend(stats['conversions'] ?? 0),
                        trendColor: AppColors.success,
                      ),
                      _buildKPICard(
                        icon: Icons.attach_money_outlined,
                        iconColor: AppColors.warning,
                        value: '₹${_calculateRevenue(stats)}',
                        label: 'Revenue',
                        trend: _calculateTrend(stats['conversions'] ?? 0),
                        trendColor: AppColors.success,
                      ),
                    ],
                  ),

                const SizedBox(height: AppSizes.paddingXL),

                // Monthly Performance Chart
                Container(
                  padding: const EdgeInsets.all(AppSizes.paddingL),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppSizes.radiusL),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Monthly Performance',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppSizes.paddingL),
                      SizedBox(
                        height: 200,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _buildBarChart('Calls', stats['monthEnquiries'] ?? 0, 0.3),
                            _buildBarChart('Visits', stats['monthVisits'] ?? 0, 0.7),
                            _buildBarChart('Follow-ups', stats['todayFollowUps'] ?? 0, 0.2),
                            _buildBarChart('Conversions', stats['conversions'] ?? 0, 0.5),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSizes.paddingXL),

                // Performance Summary
                Container(
                  padding: const EdgeInsets.all(AppSizes.paddingL),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppSizes.radiusL),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Performance Summary',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppSizes.paddingL),
                      _buildSummaryItem('Today\'s Calls', '${stats['todayEnquiries'] ?? 0}'),
                      _buildSummaryItem('Today\'s Visits', '${stats['todayVisits'] ?? 0}'),
                      _buildSummaryItem('Today\'s Follow-ups', '${stats['todayFollowUps'] ?? 0}'),
                      _buildSummaryItem('This Month\'s Calls', '${stats['monthEnquiries'] ?? 0}'),
                      _buildSummaryItem('This Month\'s Visits', '${stats['monthVisits'] ?? 0}'),
                      _buildSummaryItem('Total Conversions', '${stats['conversions'] ?? 0}'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _calculateTrend(int value) {
    // Simple trend calculation based on value
    if (value > 10) return '+15%';
    if (value > 5) return '+8%';
    if (value > 0) return '+3%';
    return '0%';
  }

  String _calculateRevenue(Map<String, dynamic> stats) {
    final conversions = stats['conversions'] ?? 0;
    final revenue = conversions * 5000; // Assuming ₹5000 per conversion
    if (revenue >= 100000) {
      return '${(revenue / 100000).toStringAsFixed(1)}L';
    } else if (revenue >= 1000) {
      return '${(revenue / 1000).toStringAsFixed(1)}K';
    } else {
      return revenue.toString();
    }
  }

  Widget _buildKPICard({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
    required String trend,
    required Color trendColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.paddingL),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSizes.paddingS),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: trendColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  trend,
                  style: TextStyle(
                    color: trendColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.paddingM),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSizes.paddingXS),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart(String label, int value, double height) {
    final maxValue = _analyticsData.values.fold<int>(0, (max, val) {
      final intVal = val is int ? val : 0;
      return intVal > max ? intVal : max;
    });
    final normalizedHeight = maxValue > 0 ? (value / maxValue).clamp(0.1, 1.0) : 0.1;
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 30,
          height: 150 * normalizedHeight,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Center(
            child: Text(
              value.toString(),
              style: const TextStyle(
                color: AppColors.textInverse,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSizes.paddingS),
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.paddingS),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
