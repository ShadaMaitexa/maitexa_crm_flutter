import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_constants.dart';
import '../services/firebase_service.dart';
import 'package:fl_chart/fl_chart.dart';

class SalesAnalyticsScreen extends StatefulWidget {
  const SalesAnalyticsScreen({super.key});

  @override
  State<SalesAnalyticsScreen> createState() => _SalesAnalyticsScreenState();
}

class _SalesAnalyticsScreenState extends State<SalesAnalyticsScreen> {
  Map<String, dynamic>? _stats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    final stats = await FirebaseService.getSalesAnalytics();
    setState(() {
      _stats = stats;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Sales Analytics"),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadStats),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Today's Overview", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 1.2,
                    children: [
                      _buildStatCard("New Leads", "${_stats?['todayLeadsCount'] ?? 0}", Icons.person_add, Colors.blue),
                      _buildStatCard("Missed Calls", "${_stats?['missedCallsCount'] ?? 0}", Icons.call_missed, Colors.red),
                      _buildStatCard("Follow Ups", "${_stats?['pendingFollowUpsCount'] ?? 0}", Icons.calendar_today, Colors.orange),
                      _buildStatCard("Converted", "${_stats?['convertedLeadsCount'] ?? 0}", Icons.check_circle, Colors.green),
                    ],
                  ),
                  const SizedBox(height: 32),
                  const Text("Lead Conversion Funnel", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildConversionChart(),
                  const SizedBox(height: 32),
                  _buildPerformanceTips(),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 0,
       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 24),
            ),
            const Spacer(),
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Text(title, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildConversionChart() {
    return Card(
      elevation: 0,
       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              centerSpaceRadius: 40,
              sectionsSpace: 4,
              sections: [
                PieChartSectionData(value: 40, color: Colors.blue, title: 'Inquiry', radius: 50, showTitle: false),
                PieChartSectionData(value: 30, color: Colors.orange, title: 'Contacted', radius: 50, showTitle: false),
                PieChartSectionData(value: 20, color: Colors.green, title: 'Converted', radius: 50, showTitle: false),
                PieChartSectionData(value: 10, color: Colors.red, title: 'Rejected', radius: 50, showTitle: false),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPerformanceTips() {
    return Column(
       crossAxisAlignment: CrossAxisAlignment.start,
      children: [
         const Text("Performance Insights", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
         const SizedBox(height: 12),
         _buildTipItem("Follow-up with 5 leads who were 'Interested' to increase conversion."),
         _buildTipItem("Reduce missed call response time (current avg: 45 mins)."),
         _buildTipItem("Focus on 'Devagiri College' leads as they have higher interest."),
      ],
    );
  }

  Widget _buildTipItem(String tip) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline, color: Colors.amber, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(tip, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}
