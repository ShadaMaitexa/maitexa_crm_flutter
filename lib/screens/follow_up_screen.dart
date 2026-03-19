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

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final userId = authProvider.user?.id;
    final isAdmin = userId == 'admin_001';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
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
                  const Icon(
                    Icons.notifications_outlined,
                    size: AppSizes.iconL,
                    color: AppColors.textSecondary,
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
                                      : AppColors.textSecondary.withValues(
                                          alpha: 0.3,
                                        ),
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSizes.paddingM,
                              ),
                            ),
                            child: Text(_filters[index]),
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
              child: userId == null
                  ? const Center(child: Text('User not logged in'))
                  : StreamBuilder<QuerySnapshot>(
                      stream: isAdmin
                          ? FirebaseService.getFollowUpsStream()
                          : FirebaseService.getUserFollowUpsStream(userId),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('Error: ${snapshot.error}'),
                                const SizedBox(height: 16),
                                CustomButton(
                                  onPressed: () => setState(() {}),
                                  text: 'Retry',
                                ),
                              ],
                            ),
                          );
                        }

                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final followUps = snapshot.data?.docs ?? [];
                        final filteredFollowUps = _applyFilter(followUps);

                        if (filteredFollowUps.isEmpty) {
                          return Center(
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
                                  'No ${_filters[_selectedFilter].toLowerCase()} follow-ups found',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSizes.paddingL,
                          ),
                          itemCount: filteredFollowUps.length,
                          itemBuilder: (context, index) {
                            final doc = filteredFollowUps[index];
                            final followUp = doc.data() as Map<String, dynamic>;
                            return _buildFollowUpCard(followUp);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddFollowUp(context),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: AppColors.textInverse),
      ),
    );
  }

  List<QueryDocumentSnapshot> _applyFilter(List<QueryDocumentSnapshot> docs) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final followUpDate = data['followUpDate'] as Timestamp?;
      if (followUpDate == null) return false;
      final date = followUpDate.toDate();

      switch (_selectedFilter) {
        case 0: // Today
          return !date.isBefore(today) && date.isBefore(tomorrow);
        case 1: // Overdue
          return date.isBefore(today);
        case 2: // Upcoming
          return !date.isBefore(tomorrow);
        default:
          return true;
      }
    }).toList();
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
            color: Colors.black.withValues(alpha: 0.05),
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
                  ? AppColors.error.withValues(alpha: 0.1)
                  : isToday
                  ? AppColors.warning.withValues(alpha: 0.1)
                  : AppColors.success.withValues(alpha: 0.1),
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
                  color: _getStatusColor(status).withValues(alpha: 0.1),
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
                    color: AppColors.error.withValues(alpha: 0.1),
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

  Future<void> _navigateToAddFollowUp(BuildContext context) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const AddFollowUpScreen()),
    );

    if (result == true) {
      // The StreamBuilder will handle the refresh automatically
      final dashboardProvider = Provider.of<DashboardProvider>(
        context,
        listen: false,
      );
      await dashboardProvider.refreshData();
    }
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
