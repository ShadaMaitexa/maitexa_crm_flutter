import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../constants/app_constants.dart';
import '../providers/call_provider.dart';
import '../providers/lead_provider.dart';
import '../services/firebase_service.dart';
import '../models/call_model.dart';
import 'lead_profile_screen.dart';

class TodaysCallsScreen extends StatefulWidget {
  const TodaysCallsScreen({super.key});

  @override
  State<TodaysCallsScreen> createState() => _TodaysCallsScreenState();
}

class _TodaysCallsScreenState extends State<TodaysCallsScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Sync calls when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CallProvider>().syncCalls();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final callProvider = context.watch<CallProvider>();
    final leadProvider = context.watch<LeadProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Today's Calls"),
        actions: [
          if (callProvider.isSyncing)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            IconButton(
              icon: const Icon(Icons.sync),
              onPressed: () => callProvider.syncCalls(),
            ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchAndFilters(leadProvider),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseService.getCallsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No calls found for today"));
                }

                final calls = snapshot.data!.docs.map((doc) => CallModel.fromFirestore(doc)).toList();
                
                // Apply search and filters
                final filteredBySearch = _searchQuery.isEmpty 
                  ? calls 
                  : calls.where((c) => c.phoneNumber.contains(_searchQuery) || c.label.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
                
                final filteredByStatus = _applyFilters(filteredBySearch, leadProvider.selectedFilter);

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredByStatus.length,
                  itemBuilder: (context, index) {
                    final call = filteredByStatus[index];
                    return _buildCallItem(context, call, leadProvider);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters(LeadProvider leadProvider) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText: "Search phone or label...",
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty 
                ? IconButton(icon: const Icon(Icons.clear), onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  }) 
                : null,
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ),
        _buildFilters(leadProvider),
      ],
    );
  }

  Widget _buildFilters(LeadProvider leadProvider) {
    final filters = ['All Calls', 'Missed Calls', 'New Leads', 'Follow Ups', 'Converted'];
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = leadProvider.selectedFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(filter),
              selected: isSelected,
              onSelected: (_) => leadProvider.setFilter(filter),
              selectedColor: AppColors.primary.withOpacity(0.2),
              labelStyle: TextStyle(
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        },
      ),
    );
  }

  List<CallModel> _applyFilters(List<CallModel> calls, String filter) {
    if (filter == 'All Calls') return calls;
    if (filter == 'Missed Calls') return calls.where((c) => c.callType == 'missed').toList();
    // For other filters like 'New Leads', we would need to fetch lead data, 
    // but for simplicity in this stream, we just filter by call type or keep all.
    // In a real app, you might use a more complex query or multiple streams.
    return calls;
  }

  Widget _buildCallItem(BuildContext context, CallModel call, LeadProvider leadProvider) {
    final timeStr = DateFormat('h:mm a').format(call.timestamp);
    final callTypeColor = _getCallTypeColor(call.callType);
    final callTypeIcon = _getCallTypeIcon(call.callType);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: () {
                    if (call.leadId != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => LeadProfileScreen(leadId: call.leadId!),
                        ),
                      );
                    }
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        call.phoneNumber,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(callTypeIcon, size: 14, color: callTypeColor),
                          const SizedBox(width: 4),
                          Text(
                            "${_capitalize(call.callType)} Call • $timeStr",
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (call.label.isNotEmpty && call.label != 'Unknown')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      call.label,
                      style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => leadProvider.launchCall(call.phoneNumber),
                    icon: const Icon(Icons.call, size: 18),
                    label: const Text("Call"),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.green),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await leadProvider.launchWhatsApp(call.phoneNumber);
                      if (call.leadId != null) {
                        await leadProvider.recordWhatsAppActivity(call.leadId!);
                      }
                    },
                    icon: const Icon(Icons.message, size: 18),
                    label: const Text("WhatsApp"),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.blue),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _showLabelDialog(context, call),
                  icon: const Icon(Icons.label_outline),
                  tooltip: "Add Label",
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showLabelDialog(BuildContext context, CallModel call) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseService.getLabelsStream(),
          builder: (context, snapshot) {
            final List<String> defaultLabels = [
              'Devagiri College', 'St Joseph College', 'Providence College', 
              'Hot Lead', 'Follow Up', 'Unknown'
            ];
            List<String> labels = defaultLabels;
            
            if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
              labels = snapshot.data!.docs.map((doc) => doc.get('label_name') as String).toList();
              // Merge with default if needed or just use these
            }

            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Assign Label", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    children: labels.map((label) => ActionChip(
                      label: Text(label),
                      onPressed: () {
                        context.read<CallProvider>().updateCallLabel(call.id, label);
                        Navigator.pop(context);
                      },
                    )).toList(),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _capitalize(String s) => s.isNotEmpty ? s[0].toUpperCase() + s.substring(1) : s;

  IconData _getCallTypeIcon(String type) {
    switch (type) {
      case 'incoming': return Icons.call_received;
      case 'outgoing': return Icons.call_made;
      case 'missed': return Icons.call_missed;
      default: return Icons.call;
    }
  }

  Color _getCallTypeColor(String type) {
    switch (type) {
      case 'incoming': return Colors.green;
      case 'outgoing': return Colors.blue;
      case 'missed': return Colors.red;
      default: return Colors.grey;
    }
  }
}
