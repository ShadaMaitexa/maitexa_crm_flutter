import 'package:flutter/material.dart';
import 'package:call_log/call_log.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_constants.dart';
import '../services/call_log_service.dart';
import '../services/firebase_service.dart';
import '../widgets/custom_button.dart';
import '../providers/lead_provider.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'add_follow_up_screen.dart';
import 'call_log_detail_screen.dart';

class CallLogsScreen extends StatefulWidget {
  const CallLogsScreen({super.key});

  @override
  State<CallLogsScreen> createState() => _CallLogsScreenState();
}

class _CallLogsScreenState extends State<CallLogsScreen> {
  Iterable<CallLogEntry> _allCallLogs = [];
  Iterable<CallLogEntry> _callLogs = [];
  Map<String, String> _numberCategories = {};
  bool _isLoading = true;
  String? _error;

  String? _selectedSimFilter;
  List<String> _simOptions = [];
  bool _simSelected = false;

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
      // final granted = await CallLogService.requestPermissions();
      final granted = true; // Permissions handled in service
      if (!granted) {
        setState(() {
          _error = 'Phone permissions are required to view call logs.';
          _isLoading = false;
        });
        return;
      }

      final logs = await CallLog.query(); // Direct call_log package access

      // Get standardized SIMs and show selection modal
      _simOptions = await CallLogService.getAvailableSims();

      setState(() {
        _allCallLogs = logs;
        _simSelected = false; // Force selection
        _isLoading = false;
      });

      // Show upfront SIM selection modal
      if (mounted && _simOptions.isNotEmpty) {
        _showSimSelectionModal();
      }

      // Load categories in background without blocking UI
      _loadCategoriesInBackground(logs);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error loading call logs: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _applySimFilter() {
    if (_selectedSimFilter == null) {
      _callLogs = [];
      return;
    }

    _callLogs = _allCallLogs.where((log) {
      bool simMatch = false;
      String? logSim = log.simDisplayName?.isNotEmpty == true
          ? log.simDisplayName
          : null;
      if (logSim == null && log.phoneAccountId?.isNotEmpty == true) {
        logSim = log.phoneAccountId;
      }

      // Apply same normalization as service for matching
      String normalizedLogSim = CallLogService.normalizeSimId(logSim);

      simMatch = normalizedLogSim == _selectedSimFilter;

      if (!simMatch) return false;

      bool typeMatch =
          (log.callType == CallType.incoming ||
          log.callType == CallType.outgoing);
      return typeMatch;
    }).toList();
  }

  void _showSimSelectionModal() {
    showDialog(
      context: context,
      barrierDismissible: false, // Mandatory
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.sim_card_alert, color: Colors.orange),
            SizedBox(width: 8),
            Text('Select SIM for Call Logs'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Choose which SIM\'s call logs to view:'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value:
                      _selectedSimFilter ??
                      (_simOptions.isNotEmpty ? _simOptions.first : null),
                  isExpanded: true,
                  items: _simOptions
                      .map(
                        (sim) => DropdownMenuItem(
                          value: sim,
                          child: Row(
                            children: [
                              Icon(Icons.sim_card, color: Colors.blue),
                              SizedBox(width: 8),
                              Text(sim),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (String? value) {
                    Navigator.pop(dialogContext);
                    if (value != null) {
                      setState(() {
                        _selectedSimFilter = value;
                        _simSelected = true;
                      });
                      _applySimFilter();
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadCategoriesInBackground(Iterable<CallLogEntry> logs) async {
    // Process unique numbers (up to 1000) to avoid excessive usage while remaining thorough
    final uniqueNumbers = logs
        .map((log) => log.number)
        .where((number) => number != null)
        .toSet()
        .take(1000);

    for (var number in uniqueNumbers) {
      if (!mounted) {
        return;
      }
      try {
        final cat = await FirebaseService.getNumberCategory(number!);
        if (cat != null && mounted) {
          setState(() {
            _numberCategories[number] = cat;
          });
        }
      } catch (e) {
        debugPrint('Error loading category for $number: $e');
      }
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
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSizes.radiusL),
        ),
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
        title: const Text('Device Call Logs'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Logs',
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
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: AppColors.error,
                    ),
                    const SizedBox(height: 16),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    CustomButton(onPressed: _loadData, text: 'Retry'),
                  ],
                ),
              ),
            )
          : !_simSelected
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.sim_card_alert,
                      size: 64,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Select SIM to view call logs',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap below to choose SIM 1 or SIM 2',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _showSimSelectionModal,
                        icon: const Icon(Icons.sim_card),
                        label: const Text('Select SIM'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Skip'),
                    ),
                  ],
                ),
              ),
            )
          : _callLogs.isEmpty
          ? const Center(child: Text('No call logs found on this device'))
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  color: AppColors.primary.withOpacity(0.1),
                  child: Column(
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Showing call logs from this device. You can categorize or contact them via WhatsApp.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(
                            Icons.sim_card,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Filter by SIM:',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              height: 36,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(
                                  AppSizes.radiusM,
                                ),
                                border: Border.all(
                                  color: AppColors.primary.withOpacity(0.3),
                                ),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value:
                                      _selectedSimFilter ??
                                      (_simOptions.isNotEmpty
                                          ? _simOptions.first
                                          : null),
                                  isExpanded: true,
                                  icon: const Icon(
                                    Icons.arrow_drop_down,
                                    color: AppColors.primary,
                                  ),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  items: _simOptions.map((String sim) {
                                    return DropdownMenuItem<String>(
                                      value: sim,
                                      child: Text(sim),
                                    );
                                  }).toList(),
                                  onChanged: (String? newValue) {
                                    if (newValue != null) {
                                      setState(() {
                                        _selectedSimFilter = newValue;
                                        _simSelected = true;
                                        _applySimFilter();
                                      });
                                    }
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _callLogs.length,
                    itemBuilder: (context, index) {
                      final entry = _callLogs.elementAt(index);
                      final date = DateTime.fromMillisecondsSinceEpoch(
                        entry.timestamp ?? 0,
                      );
                      final durationStr = entry.duration != null
                          ? '${(entry.duration! / 60).floor()}m ${entry.duration! % 60}s'
                          : '0s';

                      final category = _numberCategories[entry.number];
                      final leadProvider = Provider.of<LeadProvider>(
                        context,
                        listen: false,
                      );

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
                        child: Column(
                          children: [
                            ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _getCallTypeColor(
                                  entry.callType,
                                ).withOpacity(0.1),
                                child: Icon(
                                  _getCallTypeIcon(entry.callType),
                                  color: _getCallTypeColor(entry.callType),
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                entry.name ?? entry.number ?? 'Unknown',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (entry.number != null)
                                    Text(
                                      entry.number!,
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 13,
                                      ),
                                    ),
                                  Text(
                                    '${DateFormat('MMM d, h:mm a').format(date)} • $durationStr',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  if (category != null)
                                    Container(
                                      margin: const EdgeInsets.only(top: 4),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withOpacity(
                                          0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        category,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              trailing: PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, size: 20),
                                onSelected: (value) {
                                  switch (value) {
                                    case 'detail':
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              CallLogDetailScreen(
                                                callEntry: entry,
                                              ),
                                        ),
                                      );
                                      break;
                                    case 'name':
                                      _showAddNameDialog(context, entry);
                                      break;
                                    case 'label':
                                      _showLabelDialog(context, entry);
                                      break;
                                    case 'note':
                                      _showAddNoteDialog(context, entry);
                                      break;
                                    case 'schedule':
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              AddFollowUpScreen(
                                                phoneNumber: entry.number,
                                                contactName: entry.name,
                                              ),
                                        ),
                                      );
                                      break;
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'detail',
                                    child: Row(
                                      children: [
                                        Icon(Icons.info_outline, size: 20),
                                        SizedBox(width: 12),
                                        Text('View Details'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'name',
                                    child: Row(
                                      children: [
                                        Icon(Icons.person_add, size: 20),
                                        SizedBox(width: 12),
                                        Text('Add/Save Name'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'label',
                                    child: Row(
                                      children: [
                                        Icon(Icons.label_outline, size: 20),
                                        SizedBox(width: 12),
                                        Text('Add Label'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'note',
                                    child: Row(
                                      children: [
                                        Icon(Icons.note_add_outlined, size: 20),
                                        SizedBox(width: 12),
                                        Text('Add Note'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'schedule',
                                    child: Row(
                                      children: [
                                        Icon(Icons.calendar_today, size: 20),
                                        SizedBox(width: 12),
                                        Text('Schedule Follow-up'),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (entry.number != null)
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: 16,
                                  right: 16,
                                  bottom: 8,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () => leadProvider
                                            .launchCall(entry.number!),
                                        icon: const Icon(Icons.call, size: 16),
                                        label: const Text("Call"),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 8,
                                          ),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () =>
                                            _showWhatsAppSelectionDialog(
                                              context,
                                              entry.number!,
                                              leadProvider,
                                            ),
                                        icon: const Icon(
                                          FontAwesomeIcons.whatsapp,
                                          size: 16,
                                        ),
                                        label: const Text("WhatsApp"),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 8,
                                          ),
                                          visualDensity: VisualDensity.compact,
                                          foregroundColor: const Color(
                                            0xFF25D366,
                                          ),
                                          side: const BorderSide(
                                            color: Color(0xFF25D366),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  IconData _getCallTypeIcon(CallType? type) {
    switch (type) {
      case CallType.incoming:
        return Icons.call_received;
      case CallType.outgoing:
        return Icons.call_made;
      case CallType.missed:
        return Icons.call_missed;
      case CallType.rejected:
        return Icons.call_end;
      default:
        return Icons.call;
    }
  }

  Color _getCallTypeColor(CallType? type) {
    switch (type) {
      case CallType.incoming:
        return AppColors.success;
      case CallType.outgoing:
        return AppColors.primary;
      case CallType.missed:
        return AppColors.error;
      case CallType.rejected:
        return AppColors.warning;
      default:
        return AppColors.textSecondary;
    }
  }

  void _showWhatsAppSelectionDialog(
    BuildContext context,
    String phone,
    LeadProvider provider,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Select WhatsApp'),
        content: const Text('Which WhatsApp would you like to use?'),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              provider.launchWhatsAppByType(phone, 'business');
            },
            icon: const Icon(
              FontAwesomeIcons.whatsapp,
              color: Color(0xFF25D366),
            ),
            label: const Text('WhatsApp Business'),
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              provider.launchWhatsAppByType(phone, 'personal');
            },
            icon: const Icon(
              FontAwesomeIcons.whatsapp,
              color: Color(0xFF25D366),
            ),
            label: const Text('WhatsApp Personal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  // Default labels (fetched from Firebase with hardcoded defaults)
  final List<String> _defaultLabels = [
    'Devagiri College',
    'St Joseph College',
    'Providence College',
    'Hot Lead',
    'Follow Up',
    'Unknown',
  ];

  void _showAddNameDialog(BuildContext context, CallLogEntry entry) {
    if (entry.number == null) return;

    final nameController = TextEditingController(text: entry.name ?? '');

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add/Save Name'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Contact Name',
            hintText: 'Enter contact name',
            prefixIcon: Icon(Icons.person),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isNotEmpty) {
                // Save name to Firebase
                await FirebaseService.recordCall({
                  'number': entry.number,
                  'name': nameController.text.trim(),
                  'duration': entry.duration,
                  'timestamp': entry.timestamp,
                  'type': entry.callType.toString(),
                  'category': _numberCategories[entry.number],
                });

                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Name saved successfully'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showLabelDialog(BuildContext context, CallLogEntry entry) {
    if (entry.number == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseService.getLabelsStream(),
            builder: (context, snapshot) {
              // Merge hardcoded + custom labels from Firestore
              final Set<String> labelSet = {..._defaultLabels};
              if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                for (final doc in snapshot.data!.docs) {
                  final name = doc.get('label_name') as String? ?? '';
                  if (name.isNotEmpty) labelSet.add(name);
                }
              }
              final labels = labelSet.toList();

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
                          Navigator.pop(sheetContext);
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
                              await _updateCategory(entry.number!, label);

                              if (sheetContext.mounted) {
                                Navigator.pop(sheetContext);
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
      builder: (dialogContext) => AlertDialog(
        title: const Text("Add New Label"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "Enter label name..."),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                context.read<LeadProvider>().addLabel(controller.text.trim());
                Navigator.pop(dialogContext);
              }
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  void _showAddNoteDialog(BuildContext context, CallLogEntry entry) {
    if (entry.number == null) return;

    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Note'),
        content: TextField(
          controller: noteController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Enter note about this call...',
            prefixIcon: Icon(Icons.note),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (noteController.text.isNotEmpty) {
                // Record note - for call logs without leadId
                // This would typically save to a separate notes collection
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Note: Create a lead first to save notes'),
                    backgroundColor: AppColors.warning,
                  ),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
