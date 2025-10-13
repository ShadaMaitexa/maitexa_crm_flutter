import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../services/firebase_service.dart';
// import '../utils/app_colors.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Overdue Follow-ups'),
            Tab(text: 'Overdue Visits'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildOverdueFollowUps(), _buildOverdueVisits()],
      ),
    );
  }

  Widget _buildOverdueFollowUps() {
    final now = DateTime.now();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('follow_ups')
          .where('followUpDate', isLessThan: Timestamp.fromDate(now))
          .where('status', whereIn: ['pending', 'scheduled'])
          .orderBy('followUpDate')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, size: 64, color: Colors.green),
                SizedBox(height: 16),
                Text(
                  'No overdue follow-ups!',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'All your follow-ups are up to date.',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final followUpDate = (data['followUpDate'] as Timestamp).toDate();
            final daysOverdue = now.difference(followUpDate).inDays;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: daysOverdue > 7 ? Colors.red : Colors.orange,
                  child: Icon(Icons.schedule, color: Colors.white),
                ),
                title: Text(
                  data['contactName'] ?? 'Unknown Contact',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data['contactPhone'] ?? 'No phone'),
                    Text(
                      'Overdue by $daysOverdue days',
                      style: TextStyle(
                        color: daysOverdue > 7 ? Colors.red : Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Due: ${_formatDate(followUpDate)}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.phone),
                  onPressed: () => _callContact(data['contactPhone']),
                ),
                onTap: () => _viewFollowUpDetails(docs[index].id, data),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildOverdueVisits() {
    final now = DateTime.now();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('college_visits')
          .where('visitDate', isLessThan: Timestamp.fromDate(now))
          .where('status', whereIn: ['pending', 'scheduled'])
          .orderBy('visitDate')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.location_on, size: 64, color: Colors.green),
                SizedBox(height: 16),
                Text(
                  'No overdue college visits!',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'All your college visits are up to date.',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final visitDate = (data['visitDate'] as Timestamp).toDate();
            final daysOverdue = now.difference(visitDate).inDays;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: daysOverdue > 7 ? Colors.red : Colors.orange,
                  child: const Icon(Icons.location_on, color: Colors.white),
                ),
                title: Text(
                  data['collegeName'] ?? 'Unknown College',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data['location'] ?? 'No location'),
                    Text(
                      'Overdue by $daysOverdue days',
                      style: TextStyle(
                        color: daysOverdue > 7 ? Colors.red : Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Due: ${_formatDate(visitDate)}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.phone),
                  onPressed: () => _callContact(data['contactPhone']),
                ),
                onTap: () => _viewVisitDetails(docs[index].id, data),
              ),
            );
          },
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _callContact(String? phone) {
    if (phone != null && phone.isNotEmpty) {
      // Use url_launcher to make phone call
      // You can implement this based on your existing phone call functionality
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Calling $phone...')));
    }
  }

  void _viewFollowUpDetails(String id, Map<String, dynamic> data) {
    // Navigate to follow-up details screen
    Get.toNamed('/follow-up-details', arguments: {'id': id, 'data': data});
  }

  void _viewVisitDetails(String id, Map<String, dynamic> data) {
    // Navigate to college visit details screen
    Get.toNamed('/college-visit-details', arguments: {'id': id, 'data': data});
  }
}
