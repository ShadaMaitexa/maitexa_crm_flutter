import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../constants/app_constants.dart';
import '../providers/call_provider.dart';
import '../providers/lead_provider.dart';
import '../services/firebase_service.dart';
import '../models/call_model.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'lead_profile_screen.dart';
import 'add_follow_up_screen.dart';

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
        title: const Text("Call History"),
        actions: [
          if (callProvider.isSyncing)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
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
                  return const Center(child: Text("No call history found"));
                }

                final calls = snapshot.data!.docs
                    .map((doc) => CallModel.fromFirestore(doc))
                    .toList();

                // Apply search and filters
                final filteredBySearch = _searchQuery.isEmpty
                    ? calls
                    : calls
                          .where(
                            (c) =>
                                c.phoneNumber.contains(_searchQuery) ||
                                c.label.toLowerCase().contains(
                                  _searchQuery.toLowerCase(),
                                ),
                          )
                          .toList();

                final filteredByStatus = _applyFilters(
                  filteredBySearch,
                  leadProvider.selectedFilter,
                );

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
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        _buildFilters(leadProvider),
      ],
    );
  }

  Widget _buildFilters(LeadProvider leadProvider) {
    final filters = [
      'All Calls',
      'Missed Calls',
      'New Leads',
      'Follow Ups',
      'Converted',
    ];
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
    if (filter == 'Missed Calls')
      return calls.where((c) => c.callType == 'missed').toList();
    // For other filters like 'New Leads', we would need to fetch lead data,
    // but for simplicity in this stream, we just filter by call type or keep all.
    // In a real app, you might use a more complex query or multiple streams.
    return calls;
  }

  Widget _buildCallItem(
    BuildContext context,
    CallModel call,
    LeadProvider leadProvider,
  ) {
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
                          builder: (context) =>
                              LeadProfileScreen(leadId: call.leadId!),
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
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (call.label.isNotEmpty && call.label != 'Unknown')
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      call.label,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
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
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green,
                    ),
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
                    icon: const Icon(FontAwesomeIcons.whatsapp, size: 18),
                    label: const Text("WhatsApp"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF25D366),
                      side: const BorderSide(color: Color(0xFF25D366)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _showAddNoteDialog(context, call),
                  icon: const Icon(Icons.note_add_outlined),
                  tooltip: "Add Note",
                ),
                IconButton(
                  onPressed: () =>
                      _showLabelDialog(context, call, leadProvider),
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

  void _showAddNoteDialog(BuildContext context, CallModel call) {
    final noteController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Add Call Note"),
        content: TextField(
          controller: noteController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: "Enter note details about this call...",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              if (noteController.text.isNotEmpty && call.leadId != null) {
                context.read<LeadProvider>().addNote(
                  call.leadId!,
                  noteController.text,
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Note added to lead profile")),
                );
              } else if (call.leadId == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Error: No lead associated with this call"),
                  ),
                );
                Navigator.pop(context);
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _showLabelDialog(
    BuildContext context,
    CallModel call,
    LeadProvider leadProvider,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseService.getLabelsStream(),
            builder: (context, snapshot) {
              // Hardcoded defaults always present
              const List<String> defaultLabels = [
                'Devagiri College',
                'St Joseph College',
                'Providence College',
                'Hot Lead',
                'Follow Up',
                'Unknown',
              ];

              // Merge hardcoded + custom labels from Firestore
              final Set<String> labelSet = {...defaultLabels};
              if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                for (final doc in snapshot.data!.docs) {
                  final name = doc.get('label_name') as String? ?? '';
                  if (name.isNotEmpty) labelSet.add(name);
                }
              }
              final List<String> labels = labelSet.toList();

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Assign Label",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.add_circle,
                          color: AppColors.primary,
                        ),
                        onPressed: () {
                          _showAddNewLabelDialog(context);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: labels
                        .map(
                          (label) => ActionChip(
                            label: Text(label),
                            onPressed: () async {
                              await context
                                  .read<CallProvider>()
                                  .updateCallLabel(call.id, label);
                              if (call.leadId != null) {
                                await FirebaseService.updateLead(call.leadId!, {
                                  'label': label,
                                });
                              }

                              if (context.mounted) Navigator.pop(context);

                              if (label == 'Follow Up' && call.leadId != null) {
                                // Redirect to detail page
                                if (context.mounted) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => LeadProfileScreen(
                                        leadId: call.leadId!,
                                      ),
                                    ),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        "Lead set to Follow Up. Use 'Schedule' to add reminder.",
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 24),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void _showAddNewLabelDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Add New Label"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "Enter label name..."),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                context.read<LeadProvider>().addLabel(controller.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  String _capitalize(String s) =>
      s.isNotEmpty ? s[0].toUpperCase() + s.substring(1) : s;

  IconData _getCallTypeIcon(String type) {
    switch (type) {
      case 'incoming':
        return Icons.call_received;
      case 'outgoing':
        return Icons.call_made;
      case 'missed':
        return Icons.call_missed;
      default:
        return Icons.call;
    }
  }

  Color _getCallTypeColor(String type) {
    switch (type) {
      case 'incoming':
        return Colors.green;
      case 'outgoing':
        return Colors.blue;
      case 'missed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
