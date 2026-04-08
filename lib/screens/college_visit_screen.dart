import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_constants.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import '../providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';
import '../services/firebase_service.dart';
import 'add_college_visit_screen.dart';
import 'schedule_follow_up_screen.dart';

class CollegeVisitScreen extends StatefulWidget {
  const CollegeVisitScreen({super.key});

  @override
  State<CollegeVisitScreen> createState() => _CollegeVisitScreenState();
}

class _CollegeVisitScreenState extends State<CollegeVisitScreen> {
  String _searchQuery = '';

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
                    'College Visits',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Container(
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: () => _navigateToAddCollegeVisit(context),
                      icon: const Icon(
                        Icons.add,
                        color: AppColors.textInverse,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Search
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.paddingL,
              ),
              child: CustomSearchField(
                hintText: 'Search colleges...',
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ),

            const SizedBox(height: AppSizes.paddingL),

            // College Visits List
            Expanded(
              child: userId == null
                  ? const Center(child: Text('User not logged in'))
                  : StreamBuilder<QuerySnapshot>(
                      stream: isAdmin
                          ? FirebaseService.getCollegeVisitsStream()
                          : FirebaseService.getUserCollegeVisitsStream(userId),
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

                        final visits = snapshot.data?.docs ?? [];
                        final filteredVisits = visits.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          if (_searchQuery.isEmpty) return true;

                          final collegeName = data['collegeName']?.toString().toLowerCase() ?? '';
                          final location = data['location']?.toString().toLowerCase() ?? '';
                          final contactPerson = data['contactPerson']?.toString().toLowerCase() ?? '';
                          final purpose = data['purpose']?.toString().toLowerCase() ?? '';

                          final query = _searchQuery.toLowerCase();
                          return collegeName.contains(query) ||
                              location.contains(query) ||
                              contactPerson.contains(query) ||
                              purpose.contains(query);
                        }).toList();

                        if (filteredVisits.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.location_on_outlined,
                                  size: 64,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _searchQuery.isEmpty
                                      ? 'No college visits found'
                                      : 'No college visits match your search',
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
                          itemCount: filteredVisits.length,
                          itemBuilder: (context, index) {
                            final doc = filteredVisits[index];
                            final visit = {'id': doc.id, ...doc.data() as Map<String, dynamic>};
                            return _buildCollegeVisitCard(context, visit);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollegeVisitCard(BuildContext context, Map<String, dynamic> visit) {
    final collegeName = visit['collegeName'] ?? 'College Name';
    final location = visit['location'] ?? 'Location';
    final contactPerson = visit['contactPerson'] ?? 'Contact Person';
    final purpose = visit['purpose'] ?? 'Purpose';
    final feedback = visit['feedback'] ?? 'No feedback';
    final visitDate = visit['visitDate'] as Timestamp?;
    final followUpDate = visit['followUpDate'] as Timestamp?;
    final status = visit['status'] ?? 'pending';

    DateTime? date;
    DateTime? followUp;
    if (visitDate != null) {
      date = visitDate.toDate();
    }
    if (followUpDate != null) {
      followUp = followUpDate.toDate();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.paddingL),
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
            children: [
              Container(
                padding: const EdgeInsets.all(AppSizes.paddingM),
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.location_on,
                  color: _getStatusColor(status),
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSizes.paddingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      collegeName,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSizes.paddingXS),
                    Text(
                      location,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
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
            ],
          ),

          const SizedBox(height: AppSizes.paddingM),

          // Contact Person
          Row(
            children: [
              const Icon(
                Icons.person,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: AppSizes.paddingXS),
              Expanded(
                child: Text(
                  contactPerson,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSizes.paddingS),

          // Purpose
          Row(
            children: [
              const Icon(
                Icons.assignment,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: AppSizes.paddingXS),
              Expanded(
                child: Text(
                  purpose,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSizes.paddingM),

          // Feedback
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSizes.paddingM),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(AppSizes.radiusM),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Feedback:',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSizes.paddingXS),
                Text(
                  feedback,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSizes.paddingM),

          // Visit Details and Follow-up
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Visit Date:',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: AppSizes.paddingXS),
                    Text(
                      date != null ? _formatDate(date) : 'Not specified',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (followUp != null)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Follow-up:',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: AppSizes.paddingXS),
                      Text(
                        _formatDate(followUp),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: AppSizes.paddingM),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: CustomButton(
                  text: 'View Details',
                  icon: Icons.visibility,
                  isOutlined: true,
                  onPressed: () {
                    // TODO: Navigate to visit details screen
                  },
                ),
              ),
              const SizedBox(width: AppSizes.paddingM),
              Expanded(
                child: CustomButton(
                  text: 'Schedule Follow-up',
                  icon: Icons.calendar_today,
                  onPressed: () {
                    Navigator.of(context)
                        .push(
                          MaterialPageRoute(
                            builder: (context) =>
                                ScheduleFollowUpScreen(collegeVisit: visit),
                          ),
                        )
                        .then((result) {
                      if (result == true) {
                        // The StreamBuilder will handle the refresh automatically
                      }
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToAddCollegeVisit(BuildContext context) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const AddCollegeVisitScreen()),
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
    final yesterday = today.subtract(const Duration(days: 1));

    if (date.isAfter(yesterday) &&
        date.isBefore(today.add(const Duration(days: 1)))) {
      return 'Today, ${_formatTime(date)}';
    } else if (date.isAfter(yesterday.subtract(const Duration(days: 1))) &&
        date.isBefore(today)) {
      return 'Yesterday, ${_formatTime(date)}';
    } else {
      return '${date.day}/${date.month}/${date.year}, ${_formatTime(date)}';
    }
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return AppColors.statusCompleted;
      case 'pending':
        return AppColors.statusPending;
      case 'followup':
        return AppColors.statusFollowUp;
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }
}
