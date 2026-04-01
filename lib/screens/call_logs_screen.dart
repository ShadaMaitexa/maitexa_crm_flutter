import 'package:flutter/material.dart';
import 'package:call_log/call_log.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  Map<String, bool> _convertedCalls = {};
  bool _isLoading = true;
  bool _isConverting = false;
  String? _error;

  // SIM detection state
  SimInfo? _detectedSim;
  String? _userPhone;
  String? _statusMessage; // shown in the info banner
  bool _isSingleSimDevice = false;

  // Persisted fallback: slot index the user last used
  static const String _simSlotPrefKey = 'saved_sim_slot_index';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _statusMessage = null;
    });

    try {
      // 1. Request permissions
      final granted = await CallLogService.requestPermissions();
      if (!granted) {
        setState(() {
          _error =
              'Phone and Call Log permissions are required to view call logs.';
          _isLoading = false;
        });
        return;
      }

      // 2. Fetch all call logs
      final logs = await CallLog.query();
      final logsList = logs.toList();

      // 3. Fetch the user's registered phone from Firebase
      String? userPhone;
      final user = FirebaseService.authInstance.currentUser;
      if (user != null) {
        final profile = await FirebaseService.firestore
            .collection(FirebaseService.usersCollection)
            .doc(user.uid)
            .get();
        if (profile.exists) {
          userPhone =
              profile.data()?['phone']?.toString().trim();
        }
      }

      // 4. Query device SIM info via platform channel (Android 14+ safe)
      final deviceSims = await CallLogService.getDeviceSimInfoList();

      debugPrint('[CallLogs] Device SIMs: $deviceSims');
      debugPrint('[CallLogs] Registered phone: $userPhone');

      SimInfo? detectedSim;
      String statusMsg;

      if (deviceSims.isEmpty) {
        statusMsg = 'Showing all call logs (SIM info unavailable).';
      } else if (deviceSims.length == 1) {
        detectedSim = deviceSims.first;
        statusMsg = 'Showing logs for: ${detectedSim.displayName}';
      } else {
        // Multi-SIM: try to match registered phone
        if (userPhone != null && userPhone.isNotEmpty) {
          detectedSim = CallLogService.findMatchingSim(deviceSims, userPhone);
        }

        if (detectedSim != null) {
          statusMsg = 'Showing logs for your registered SIM: ${detectedSim.displayName}';
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt(_simSlotPrefKey, detectedSim.slotIndex);
        } else {
          final prefs = await SharedPreferences.getInstance();
          final savedSlot = prefs.getInt(_simSlotPrefKey);
          if (savedSlot != null) {
            detectedSim = deviceSims.firstWhere(
              (s) => s.slotIndex == savedSlot,
              orElse: () => deviceSims.first,
            );
            statusMsg = 'Showing logs for: ${detectedSim.displayName} (previously used)';
          } else {
            statusMsg = 'Multiple SIMs detected. Please select yours.';
          }
        }
      }

      // 5. Apply filter / fall-through to all logs
      Iterable<CallLogEntry> filtered;
      if (detectedSim != null) {
        filtered = CallLogService.filterLogsBySim(logsList, detectedSim);
        if (filtered.isEmpty) {
          // Filtering was too aggressive — show all (safety fallback)
          debugPrint(
              '[CallLogs] Filtered result was empty — showing all logs as fallback');
          filtered = logsList.where(
            (l) =>
                l.callType == CallType.incoming ||
                l.callType == CallType.outgoing ||
                l.callType == CallType.missed,
          );
          statusMsg += ' (filter fallback — showing all)';
        }
      } else if (deviceSims.isEmpty) {
        // No SIM info at all: show everything
        filtered = logsList.where(
          (l) =>
              l.callType == CallType.incoming ||
              l.callType == CallType.outgoing ||
              l.callType == CallType.missed,
        );
      } else {
        // Multi-SIM, could not detect — show a picker
        filtered = [];
      }

      setState(() {
        _allCallLogs = logsList;
        _callLogs = filtered;
        _userPhone = userPhone;
        _detectedSim = detectedSim;
        _statusMessage = statusMsg;
        _isSingleSimDevice = deviceSims.length == 1;
        _isLoading = false;
      });

      // Show manual picker if multi-SIM and still not detected
      if (mounted &&
          deviceSims.length > 1 &&
          detectedSim == null) {
        _showSimSelectionModal(deviceSims);
      }

      _loadCategoriesInBackground(logs);
      _loadConversionStatusInBackground(logs);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error loading call logs: $e';
          _isLoading = false;
        });
      }
    }
  }

  // ──────────────────────────────── Manual SIM picker ───────────────────────────────

  void _showSimSelectionModal(List<SimInfo> sims) {
    final hintPhone = _userPhone ?? 'your registered number';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.sim_card_alert, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Select Your SIM'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Pick the SIM linked to $hintPhone:',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            ...sims.map((sim) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListTile(
                  leading:
                      const Icon(Icons.sim_card, color: AppColors.primary),
                  title: Text(sim.displayName,
                      style:
                          const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    sim.phoneNumber.isNotEmpty
                        ? sim.phoneNumber
                        : 'SIM ${sim.slotIndex + 1}',
                    style: const TextStyle(fontSize: 11),
                  ),
                  onTap: () async {
                    Navigator.pop(dialogContext);
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setInt(_simSlotPrefKey, sim.slotIndex);

                    final filtered = CallLogService.filterLogsBySim(
                        _allCallLogs.toList(), sim);
                    setState(() {
                      _detectedSim = sim;
                      _callLogs = filtered.isEmpty
                          ? _allCallLogs.where(
                              (l) =>
                                  l.callType == CallType.incoming ||
                                  l.callType == CallType.outgoing ||
                                  l.callType == CallType.missed,
                            )
                          : filtered;
                      _statusMessage =
                          'Showing logs for: ${sim.displayName}';
                    });
                  },
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────── Background tasks ────────────────────────────────

  Future<void> _loadCategoriesInBackground(
      Iterable<CallLogEntry> logs) async {
    final uniqueNumbers = logs
        .map((log) => log.number)
        .where((number) => number != null)
        .toSet()
        .take(1000);

    for (var number in uniqueNumbers) {
      if (!mounted) return;
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

  /// After returning from detail screen, re-check one entry's converted status
  Future<void> _refreshConversionForEntry(CallLogEntry entry) async {
    if (entry.number == null || entry.timestamp == null || !mounted) return;
    final callId = await FirebaseService.findExistingCallRecord(
        entry.number!, entry.timestamp!);
    if (callId == null) return;
    final doc = await FirebaseService.firestore
        .collection(FirebaseService.callsCollection)
        .doc(callId)
        .get();
    if (!mounted) return;
    final data = doc.data();
    final key = '${entry.number}_${entry.timestamp}';
    setState(() {
      _convertedCalls[key] = data?['isConverted'] == true;
    });
  }

  Future<void> _loadConversionStatusInBackground(
      Iterable<CallLogEntry> logs) async {
    final checkLogs = logs.take(50);
    for (var entry in checkLogs) {
      if (entry.number == null || entry.timestamp == null) continue;
      final callId = await FirebaseService.findExistingCallRecord(
          entry.number!, entry.timestamp!);
      if (callId != null) {
        final doc = await FirebaseService.firestore
            .collection(FirebaseService.callsCollection)
            .doc(callId)
            .get();
        final data = doc.data();
        if (data != null && data['isConverted'] == true && mounted) {
          setState(() {
            _convertedCalls['${entry.number}_${entry.timestamp}'] = true;
          });
        }
      }
    }
  }

  Future<void> _toggleConverted(CallLogEntry entry) async {
    if (entry.number == null || entry.timestamp == null || _isConverting)
      return;

    final key = '${entry.number}_${entry.timestamp}';
    final wasConverted = _convertedCalls[key] ?? false;

    setState(() => _isConverting = true);
    try {
      String? callId = await FirebaseService.findExistingCallRecord(
          entry.number!, entry.timestamp!);

      if (callId == null) {
        callId = await FirebaseService.recordCall({
          'phone_number': entry.number,
          'name': entry.name ?? 'Unknown',
          'duration': entry.duration,
          'timestamp': entry.timestamp,
          'call_type': _getCallTypeString(entry.callType),
          'isConverted': !wasConverted,
        });
      } else {
        await FirebaseService.updateCallConversion(callId, !wasConverted);
      }

      if (mounted) {
        setState(() {
          _convertedCalls[key] = !wasConverted;
          _isConverting = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                !wasConverted ? 'Marked as Converted!' : 'Removed Conversion'),
            backgroundColor:
                !wasConverted ? AppColors.success : AppColors.textSecondary,
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _isConverting = false);
    }
  }

  String _getCallTypeString(CallType? type) {
    switch (type) {
      case CallType.incoming:
        return 'incoming';
      case CallType.outgoing:
        return 'outgoing';
      case CallType.missed:
        return 'missed';
      case CallType.rejected:
        return 'rejected';
      default:
        return 'other';
    }
  }

  // ──────────────────────────────── Build ───────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Call Logs'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          if (!_isSingleSimDevice && _allCallLogs.isNotEmpty)
            IconButton(
              onPressed: () async {
                final deviceSims = await CallLogService.getDeviceSimInfoList();
                if (deviceSims.length > 1) {
                  _showSimSelectionModal(deviceSims);
                }
              },
              icon: const Icon(Icons.sim_card_outlined),
              tooltip: 'Switch SIM',
            ),
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorView()
              : _callLogs.isEmpty
                  ? _buildEmptyView()
                  : _buildLogsList(),
    );
  }

  Widget _buildErrorView() {
    return Center(
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
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.call_missed, size: 64, color: AppColors.primary),
            const SizedBox(height: 16),
            const Text(
              'No call logs found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_statusMessage != null)
              Text(
                _statusMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Reload'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogsList() {
    return Column(
      children: [
        // ── Info banner ──
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          color: AppColors.primary.withValues(alpha: 0.07),
          child: Row(
            children: [
              const Icon(Icons.info_outline,
                  size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _detectedSim != null 
                    ? 'Showing logs for: ${_detectedSim!.displayName} ${_detectedSim!.phoneNumber.isNotEmpty ? "(${_detectedSim!.phoneNumber})" : ""}'
                    : _statusMessage ?? 'Showing call logs from this device.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        // ── List ──
        Expanded(
          child: ListView.builder(
            itemCount: _callLogs.length,
            itemBuilder: (context, index) {
              final entry = _callLogs.elementAt(index);
              return _buildCallCard(entry);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCallCard(CallLogEntry entry) {
    final date = DateTime.fromMillisecondsSinceEpoch(entry.timestamp ?? 0);
    final durationStr = entry.duration != null
        ? '${(entry.duration! / 60).floor()}m ${entry.duration! % 60}s'
        : '0s';
    final category = _numberCategories[entry.number];
    final key = '${entry.number}_${entry.timestamp}';
    final isConverted = _convertedCalls[key] == true;
    final leadProvider = Provider.of<LeadProvider>(context, listen: false);

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSizes.paddingM,
        vertical: AppSizes.paddingS,
      ),
      elevation: 0,
      color: isConverted ? Colors.green.withOpacity(0.03) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
        side: isConverted
            ? const BorderSide(color: Colors.green, width: 1.5)
            : BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CallLogDetailScreen(callEntry: entry),
          ),
        ).then((_) => _refreshConversionForEntry(entry)),
        child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  _getCallTypeColor(entry.callType).withValues(alpha: 0.1),
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
                if (entry.number != null)
                  Text(
                    entry.number!,
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 13),
                  ),
                Text(
                  '${DateFormat('MMM d, h:mm a').format(date)} • $durationStr',
                  style: const TextStyle(fontSize: 12),
                ),
                if (category != null)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
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
                            CallLogDetailScreen(callEntry: entry),
                      ),
                    ).then((_) => _refreshConversionForEntry(entry));
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
                        builder: (context) => AddFollowUpScreen(
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
                  child: Row(children: [
                    Icon(Icons.info_outline, size: 20),
                    SizedBox(width: 12),
                    Text('View Details'),
                  ]),
                ),
                const PopupMenuItem(
                  value: 'name',
                  child: Row(children: [
                    Icon(Icons.person_add, size: 20),
                    SizedBox(width: 12),
                    Text('Add/Save Name'),
                  ]),
                ),
                const PopupMenuItem(
                  value: 'label',
                  child: Row(children: [
                    Icon(Icons.label_outline, size: 20),
                    SizedBox(width: 12),
                    Text('Add Label'),
                  ]),
                ),
                const PopupMenuItem(
                  value: 'note',
                  child: Row(children: [
                    Icon(Icons.note_add_outlined, size: 20),
                    SizedBox(width: 12),
                    Text('Add Note'),
                  ]),
                ),
                const PopupMenuItem(
                  value: 'schedule',
                  child: Row(children: [
                    Icon(Icons.calendar_today, size: 20),
                    SizedBox(width: 12),
                    Text('Schedule Follow-up'),
                  ]),
                ),
              ],
            ),
          ),
          if (entry.number != null)
            Padding(
              padding:
                  const EdgeInsets.only(left: 16, right: 16, bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          leadProvider.launchCall(entry.number!),
                      icon: const Icon(Icons.call, size: 16),
                      label: const Text('Call'),
                      style: OutlinedButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showWhatsAppSelectionDialog(
                          context, entry.number!, leadProvider),
                      icon: const Icon(FontAwesomeIcons.whatsapp,
                          size: 16),
                      label: const Text('WhatsApp'),
                      style: OutlinedButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 8),
                        visualDensity: VisualDensity.compact,
                        foregroundColor: const Color(0xFF25D366),
                        side:
                            const BorderSide(color: Color(0xFF25D366)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _toggleConverted(entry),
                      icon: Icon(
                        isConverted
                            ? Icons.check_circle
                            : Icons.check_circle_outline,
                        size: 16,
                      ),
                      label: Text(isConverted ? 'Converted ✓' : 'Converted'),
                      style: OutlinedButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 8),
                        visualDensity: VisualDensity.compact,
                        foregroundColor: isConverted
                            ? AppColors.success
                            : AppColors.textSecondary,
                        side: BorderSide(
                          color: isConverted
                              ? AppColors.success
                              : Colors.grey.shade300,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
        ),  // closes Column
      ),    // closes InkWell
    );
  }

  // ──────────────────────────── Helpers ─────────────────────────────────────────────

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
      BuildContext context, String phone, LeadProvider provider) {
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
            icon: const Icon(FontAwesomeIcons.whatsapp,
                color: Color(0xFF25D366)),
            label: const Text('WhatsApp Business'),
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              provider.launchWhatsAppByType(phone, 'personal');
            },
            icon: const Icon(FontAwesomeIcons.whatsapp,
                color: Color(0xFF25D366)),
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

  // ──────────────────────────── Dialogs ─────────────────────────────────────────────

  final List<String> _defaultLabels = [
    'Devagiri College',
    'St Joseph College',
    'Providence College',
    'Hot Deals',
    'Follow Up',
    'Unknown',
  ];

  void _showAddNameDialog(BuildContext context, CallLogEntry entry) {
    if (entry.number == null) return;
    final nameController =
        TextEditingController(text: entry.name ?? '');

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
                        'Assign Label',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle,
                            color: AppColors.primary),
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
        title: const Text('Add New Label'),
        content: TextField(
          controller: controller,
          decoration:
              const InputDecoration(hintText: 'Enter label name...'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                context
                    .read<LeadProvider>()
                    .addLabel(controller.text.trim());
                Navigator.pop(dialogContext);
              }
            },
            child: const Text('Add'),
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
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.note_add, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Add Note'),
          ],
        ),
        content: TextField(
          controller: noteController,
          maxLines: 3,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Enter note about this call...',
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final note = noteController.text.trim();
              if (note.isEmpty) return;
              Navigator.pop(dialogContext);

              try {
                final snapshot = await FirebaseFirestore.instance
                    .collection(FirebaseService.leadsCollection)
                    .where('phone', isEqualTo: entry.number)
                    .limit(1)
                    .get();

                String leadId;
                if (snapshot.docs.isNotEmpty) {
                  leadId = snapshot.docs.first.id;
                } else {
                  final ref = await FirebaseFirestore.instance
                      .collection(FirebaseService.leadsCollection)
                      .add({
                    'name': entry.name ?? 'Unknown',
                    'phone': entry.number,
                    'source': 'Call Log Note',
                    'label': 'Unknown',
                    'status': 'New Inquiry',
                    'created_at': FieldValue.serverTimestamp(),
                    'last_contacted': FieldValue.serverTimestamp(),
                  });
                  leadId = ref.id;
                }

                await FirebaseService.addNote(leadId, note);

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Note saved successfully'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to save note: $e'),
                      backgroundColor: AppColors.error,
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
}
