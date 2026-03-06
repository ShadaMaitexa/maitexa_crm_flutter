import 'package:flutter/material.dart';
import 'package:call_log/call_log.dart';
import 'package:intl/intl.dart';
import '../constants/app_constants.dart';
import '../services/call_log_service.dart';
import '../services/firebase_service.dart';
import '../widgets/custom_button.dart';

class CallLogsScreen extends StatefulWidget {
  const CallLogsScreen({super.key});

  @override
  State<CallLogsScreen> createState() => _CallLogsScreenState();
}

class _CallLogsScreenState extends State<CallLogsScreen> {
  Iterable<CallLogEntry> _callLogs = [];
  Map<String, String> _numberCategories = {};
  bool _isLoading = true;
  String? _error;

  final List<String> _categories = [
    'Enquiry',
    'Marketing',
    'Hiring Candidate',
    'Employee',
    'Others',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final granted = await CallLogService.requestPermissions();
      if (!granted) {
        setState(() {
          _error = 'Phone permissions are required to view call logs.';
          _isLoading = false;
        });
        return;
      }

      final logs = await CallLogService.getLocalCallLogs();
      
      // Load categories for these numbers from Firebase
      Map<String, String> categories = {};
      for (var log in logs.take(50)) { // Limit to 50 for performance
        if (log.number != null && !categories.containsKey(log.number)) {
          final cat = await FirebaseService.getNumberCategory(log.number!);
          if (cat != null) {
            categories[log.number!] = cat;
          }
        }
      }

      setState(() {
        _callLogs = logs;
        _numberCategories = categories;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading call logs: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _updateCategory(String number, String category) async {
    await FirebaseService.setNumberCategory(number, category);
    setState(() {
      _numberCategories[number] = category;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Number $number categorized as $category')),
    );
  }

  void _showCategoryDialog(CallLogEntry entry) {
    if (entry.number == null) return;
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSizes.radiusL)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(AppSizes.paddingL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Categorize Call',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Number: ${entry.number}',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSizes.paddingL),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categories.map((cat) {
                  final isSelected = _numberCategories[entry.number] == cat;
                  return ChoiceChip(
                    label: Text(cat),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        Navigator.pop(context);
                        _updateCategory(entry.number!, cat);
                        
                        // Also record this specific call in Firebase
                        FirebaseService.recordCall({
                          'number': entry.number,
                          'name': entry.name,
                          'duration': entry.duration,
                          'timestamp': entry.timestamp,
                          'type': entry.callType.toString(),
                          'category': cat,
                        });
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSizes.paddingL),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Call Tracking'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSizes.paddingL),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                        const SizedBox(height: 16),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 24),
                        CustomButton(onPressed: _loadData, text: 'Retry'),
                      ],
                    ),
                  ),
                )
              : _callLogs.isEmpty
                  ? const Center(child: Text('No call logs found'))
                  : ListView.builder(
                      itemCount: _callLogs.length,
                      itemBuilder: (context, index) {
                        final entry = _callLogs.elementAt(index);
                        final date = DateTime.fromMillisecondsSinceEpoch(entry.timestamp ?? 0);
                        final durationStr = entry.duration != null 
                            ? '${(entry.duration! / 60).floor()}m ${entry.duration! % 60}s'
                            : '0s';
                        
                        final category = _numberCategories[entry.number];

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: AppSizes.paddingM,
                            vertical: AppSizes.paddingS,
                          ),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppSizes.radiusM),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _getCallTypeColor(entry.callType).withOpacity(0.1),
                              child: Icon(
                                _getCallTypeIcon(entry.callType),
                                color: _getCallTypeColor(entry.callType),
                                size: 20,
                              ),
                            ),
                            title: Text(
                              entry.name ?? entry.number ?? 'Unknown',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${DateFormat('MMM d, h:mm a').format(date)} • $durationStr'),
                                if (category != null)
                                  Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      category,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.category_outlined),
                              onPressed: () => _showCategoryDialog(entry),
                              tooltip: 'Categorize',
                            ),
                            onTap: () => _showCategoryDialog(entry),
                          ),
                        );
                      },
                    ),
    );
  }

  IconData _getCallTypeIcon(CallType? type) {
    switch (type) {
      case CallType.incoming: return Icons.call_received;
      case CallType.outgoing: return Icons.call_made;
      case CallType.missed: return Icons.call_missed;
      case CallType.rejected: return Icons.call_end;
      default: return Icons.call;
    }
  }

  Color _getCallTypeColor(CallType? type) {
    switch (type) {
      case CallType.incoming: return AppColors.success;
      case CallType.outgoing: return AppColors.primary;
      case CallType.missed: return AppColors.error;
      case CallType.rejected: return AppColors.warning;
      default: return AppColors.textSecondary;
    }
  }
}
