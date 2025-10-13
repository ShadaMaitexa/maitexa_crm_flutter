import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_constants.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import '../providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';
import '../services/firebase_service.dart';
import 'add_follow_up_screen.dart';

class FollowUpScreen extends StatefulWidget {
  const FollowUpScreen({super.key});

  @override
  State<FollowUpScreen> createState() => _FollowUpScreenState();
}

class _FollowUpScreenState extends State<FollowUpScreen> {
  int _selectedFilter = 0;
  final List<String> _filters = ['Today', 'Overdue', 'Upcoming'];
  List<Map<String, dynamic>> _followUps = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFollowUps();
  }

  Future<void> _loadFollowUps() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final dashboardProvider = Provider.of<DashboardProvider>(
        context,
        listen: false,
      );

      if (authProvider.user != null && authProvider.user!.id != 'admin_001') {
        // Load user-specific follow-ups
        _followUps = await FirebaseService.getUserFollowUps(
          authProvider.user!.id,
        );
      } else {
        // Load all follow-ups for admin
        _followUps = await FirebaseService.getFollowUps();
      }

      // Also refresh dashboard data to keep stats in sync
      await dashboardProvider.refreshData();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> get _filteredFollowUps {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    switch (_selectedFilter) {
      case 0: // Today
        return _followUps.where((followUp) {
          final followUpDate = followUp['followUpDate'] as Timestamp?;
          if (followUpDate != null) {
            final date = followUpDate.toDate();
            return date.isAfter(today) && date.isBefore(tomorrow);
          }
          return false;
        }).toList();
      case 1: // Overdue
        return _followUps.where((followUp) {
          final followUpDate = followUp['followUpDate'] as Timestamp?;
          if (followUpDate != null) {
            final date = followUpDate.toDate();
            return date.isBefore(today);
          }
          return false;
        }).toList();
      case 2: // Upcoming
        return _followUps.where((followUp) {
          final followUpDate = followUp['followUpDate'] as Timestamp?;
          if (followUpDate != null) {
            final date = followUpDate.toDate();
            return date.isAfter(tomorrow);
          }
          return false;
        }).toList();
      default:
        return _followUps;
    }
  }

  Future<void> _navigateToAddFollowUp() async {
    final result = await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const AddFollowUpScreen()));

    if (result == true) {
      // Refresh the list if a new follow-up was added
      _loadFollowUps();

      // Also refresh dashboard data
      final dashboardProvider = Provider.of<DashboardProvider>(
        context,
        listen: false,
      );
      await dashboardProvider.refreshData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadFollowUps,
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(AppSizes.paddingL),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      AppStrings.followUps,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Stack(
                      children: [
                        const Icon(
                          Icons.notifications_outlined,
                          size: AppSizes.iconL,
                          color: AppColors.textSecondary,
                        ),
                        if (_filteredFollowUps.isNotEmpty)
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
                                '${_filteredFollowUps.length}',
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
                  ],
                ),
              ),

              // Search and Filter
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.paddingL,
                ),
                child: Column(
                  children: [
                    CustomSearchField(
                      hintText: 'Search follow-ups...',
                      onFilterTap: () {
                        // TODO: Show filter options
                      },
                    ),
                    const SizedBox(height: AppSizes.paddingL),

                    // Filter Buttons
                    Row(
                      children: List.generate(_filters.length, (index) {
                        final isSelected = _selectedFilter == index;
                        final count = _getFilterCount(index);
                        return Expanded(
                          child: Container(
                            margin: EdgeInsets.only(
                              right: index < _filters.length - 1
                                  ? AppSizes.paddingS
                                  : 0,
                            ),
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _selectedFilter = index;
                                });
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
                                        : AppColors.textSecondary.withOpacity(
                                            0.3,
                                          ),
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: AppSizes.paddingM,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text(_filters[index]),
                                  if (count > 0)
                                    Container(
                                      margin: const EdgeInsets.only(top: 4),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppColors.textInverse
                                            : AppColors.primary,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        count.toString(),
                                        style: TextStyle(
                                          color: isSelected
                                              ? AppColors.primary
                                              : AppColors.textInverse,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSizes.paddingL),

              // Follow-ups List
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Error: $_error'),
                            const SizedBox(height: 16),
                            CustomButton(
                              onPressed: _loadFollowUps,
                              text: 'Retry',
                            ),
                          ],
                        ),
                      )
                    : _filteredFollowUps.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 64,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No follow-ups found',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.paddingL,
                        ),
                        itemCount: _filteredFollowUps.length,
                        itemBuilder: (context, index) {
                          final followUp = _filteredFollowUps[index];
                          return _buildFollowUpCard(followUp);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddFollowUp,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: AppColors.textInverse),
      ),
    );
  }

  int _getFilterCount(int filterIndex) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    switch (filterIndex) {
      case 0: // Today
        return _followUps.where((followUp) {
          final followUpDate = followUp['followUpDate'] as Timestamp?;
          if (followUpDate != null) {
            final date = followUpDate.toDate();
            return date.isAfter(today) && date.isBefore(tomorrow);
          }
          return false;
        }).length;
      case 1: // Overdue
        return _followUps.where((followUp) {
          final followUpDate = followUp['followUpDate'] as Timestamp?;
          if (followUpDate != null) {
            final date = followUpDate.toDate();
            return date.isBefore(today);
          }
          return false;
        }).length;
      case 2: // Upcoming
        return _followUps.where((followUp) {
          final followUpDate = followUp['followUpDate'] as Timestamp?;
          if (followUpDate != null) {
            final date = followUpDate.toDate();
            return date.isAfter(tomorrow);
          }
          return false;
        }).length;
      default:
        return 0;
    }
  }

  Widget _buildFollowUpCard(Map<String, dynamic> followUp) {
    final contactName = followUp['contactName'] ?? 'Contact';
    final notes = followUp['notes'] ?? 'No notes';
    final followUpDate = followUp['followUpDate'] as Timestamp?;
    final status = followUp['status'] ?? 'pending';

    DateTime? date;
    if (followUpDate != null) {
      date = followUpDate.toDate();
    }

    final isOverdue = date != null && date.isBefore(DateTime.now());
    final isToday =
        date != null &&
        date.isAfter(DateTime.now().subtract(const Duration(days: 1))) &&
        date.isBefore(DateTime.now().add(const Duration(days: 1)));

    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.paddingM),
      padding: const EdgeInsets.all(AppSizes.paddingM),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSizes.paddingS),
            decoration: BoxDecoration(
              color: isOverdue
                  ? AppColors.error.withOpacity(0.1)
                  : isToday
                  ? AppColors.warning.withOpacity(0.1)
                  : AppColors.success.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.calendar_today,
              color: isOverdue
                  ? AppColors.error
                  : isToday
                  ? AppColors.warning
                  : AppColors.success,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSizes.paddingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contactName,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSizes.paddingXS),
                Text(
                  notes,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSizes.paddingXS),
                if (date != null)
                  Text(
                    _formatDate(date),
                    style: TextStyle(
                      color: isOverdue
                          ? AppColors.error
                          : isToday
                          ? AppColors.warning
                          : AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: _getStatusColor(status),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.paddingXS),
              if (isOverdue)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'OVERDUE',
                    style: TextStyle(
                      color: AppColors.error,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final yesterday = today.subtract(const Duration(days: 1));

    if (date.isAfter(yesterday) && date.isBefore(tomorrow)) {
      return 'Today at ${_formatTime(date)}';
    } else if (date.isAfter(today) &&
        date.isBefore(tomorrow.add(const Duration(days: 1)))) {
      return 'Tomorrow at ${_formatTime(date)}';
    } else {
      return '${date.day}/${date.month}/${date.year} at ${_formatTime(date)}';
    }
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return AppColors.success;
      case 'pending':
        return AppColors.warning;
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }
}
