import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_constants.dart';
import '../services/firebase_service.dart';
import 'package:fl_chart/fl_chart.dart';

import '../providers/auth_provider.dart';

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
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?.id;
    final stats = await FirebaseService.getSalesAnalytics(userId: userId);
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
    final leadsCount = double.tryParse(_stats?['todayLeadsCount']?.toString() ?? '0') ?? 0;
    final convertedCount = double.tryParse(_stats?['convertedLeadsCount']?.toString() ?? '0') ?? 0; 
    final missedCount = double.tryParse(_stats?['missedCallsCount']?.toString() ?? '0') ?? 0;
    final followUpCount = double.tryParse(_stats?['pendingFollowUpsCount']?.toString() ?? '0') ?? 0;

    final hasData = leadsCount > 0 || convertedCount > 0 || missedCount > 0 || followUpCount > 0;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            SizedBox(
              height: 200,
              child: !hasData
                ? const Center(child: Text("No analytics data yet", style: TextStyle(color: AppColors.textSecondary)))
                : PieChart(
                    PieChartData(
                      centerSpaceRadius: 40,
                      sectionsSpace: 4,
                      sections: [
                        if (leadsCount > 0)
                          PieChartSectionData(
                            value: leadsCount,
                            color: Colors.blue,
                            title: 'Leads',
                            radius: 50,
                            showTitle: false,
                          ),
                        if (followUpCount > 0)
                          PieChartSectionData(
                            value: followUpCount,
                            color: Colors.orange,
                            title: 'Pending',
                            radius: 50,
                            showTitle: false,
                          ),
                        if (convertedCount > 0)
                          PieChartSectionData(
                            value: convertedCount,
                            color: Colors.green,
                            title: 'Conv.',
                            radius: 50,
                            showTitle: false,
                          ),
                        if (missedCount > 0)
                          PieChartSectionData(
                            value: missedCount,
                            color: Colors.red,
                            title: 'Missed',
                            radius: 50,
                            showTitle: false,
                          ),
                      ],
                    ),
                  ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              children: [
                _buildChartLegend("Leads", Colors.blue),
                _buildChartLegend("Pending", Colors.orange),
                _buildChartLegend("Conv.", Colors.green),
                _buildChartLegend("Missed", Colors.red),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartLegend(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
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
