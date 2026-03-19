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
  Map<String, bool> _convertedCalls = {}; // Track conversion status by number+timestamp
  bool _isLoading = true;
  bool _isConverting = false;
  String? _error;

  String? _selectedSimFilter;
  String? _userPhone;
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

  static const String _simPrefKey = 'selected_sim_filter';

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final granted = await CallLogService.requestPermissions();
      if (!granted) {
        setState(() {
          _error = 'Phone and Call Log permissions are required to view logs.';
          _isLoading = false;
        });
        return;
      }

      final logs = await CallLog.query();
      final logsList = logs.toList();

      // Get normalized SIM options (e.g. "SIM 1", "SIM 2", "Airtel", etc.)
      _simOptions = await CallLogService.getAvailableSims(logs: logsList);

      // Fetch the user's registered phone number from Firebase
      String? userPhone;
      final user = FirebaseService.authInstance.currentUser;
      if (user != null) {
        final profile = await FirebaseService.firestore
            .collection(FirebaseService.usersCollection)
            .doc(user.uid)
            .get();
        if (profile.exists) {
          userPhone = profile.data()?['phone']?.toString().trim();
        }
      }

      // Normalize registered phone to last 10 digits for comparison
      String? userPhoneShort;
      if (userPhone != null && userPhone.isNotEmpty) {
        final digits = userPhone.replaceAll(RegExp(r'[^0-9]'), '');
        userPhoneShort = digits.length >= 10 ? digits.substring(digits.length - 10) : digits;
      }

      // --- Step 1: Try to auto-detect SIM by matching registered phone number ---
      // On many Android devices, phoneAccountId stores the SIM's actual phone number.
      // We scan all call log entries and check if any phoneAccountId ends with the
      // user's registered number. If found, we know which SIM label to select.
      String? autoDetectedSim;
      if (userPhoneShort != null && userPhoneShort.isNotEmpty) {
        // Build a map: simLabel -> set of raw phoneAccountIds seen for that SIM
        final Map<String, Set<String>> simToAccountIds = {};
        for (var entry in logsList) {
          final simLabel = CallLogService.normalizeSimId(
            entry.simDisplayName,
            phoneAccountId: entry.phoneAccountId,
          );
          if (entry.phoneAccountId != null && entry.phoneAccountId!.isNotEmpty) {
            simToAccountIds.putIfAbsent(simLabel, () => {}).add(entry.phoneAccountId!);
          }
        }

        // Check each SIM: does its phoneAccountId contain the user's phone number?
        for (var simLabel in _simOptions) {
          final accountIds = simToAccountIds[simLabel] ?? {};
          for (var accId in accountIds) {
            final cleanAccId = accId.replaceAll(RegExp(r'[^0-9]'), '');
            if (cleanAccId.endsWith(userPhoneShort)) {
              autoDetectedSim = simLabel;
              break;
            }
          }
          if (autoDetectedSim != null) break;
        }
      }

      // --- Step 2: Restore saved preference if auto-detection didn't work ---
      final prefs = await SharedPreferences.getInstance();
      final savedSim = prefs.getString(_simPrefKey);

      String? simToSelect;
      if (autoDetectedSim != null) {
        // Best case: matched by phone number
        simToSelect = autoDetectedSim;
        // Update saved preference to match
        await prefs.setString(_simPrefKey, autoDetectedSim);
      } else if (savedSim != null && _simOptions.contains(savedSim)) {
        // Restore previous user choice
        simToSelect = savedSim;
      } else if (_simOptions.length == 1) {
        // Only one SIM on the device
        simToSelect = _simOptions.first;
      }
      // Otherwise → show modal for manual selection

      setState(() {
        _allCallLogs = logs;
        _isLoading = false;
        _userPhone = userPhone;
        if (simToSelect != null) {
          _selectedSimFilter = simToSelect;
          _simSelected = true;
          _applySimFilter();
        } else {
          _simSelected = false;
        }
      });

      // Show SIM selection modal only if we couldn't determine which SIM to use
      if (mounted && _simOptions.isNotEmpty && simToSelect == null) {
        _showSimSelectionModal();
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

  void _applySimFilter() {
    if (_selectedSimFilter == null) {
      _callLogs = [];
      return;
    }

    _callLogs = _allCallLogs.where((log) {
      // Basic call type matching
      bool typeMatch = (log.callType == CallType.incoming || log.callType == CallType.outgoing);
      if (!typeMatch) return false;

      // Use the exact SAME normalization as getAvailableSims
      final currentSim = CallLogService.normalizeSimId(
        log.simDisplayName, 
        phoneAccountId: log.phoneAccountId
      );

      // Exact match with our selected standardized option
      return currentSim == _selectedSimFilter;
    }).toList();
  }

  void _showSimSelectionModal() {
    // Build a preview of last call per SIM for the user to identify theirs
    final Map<String, String> simPreviews = {};
    for (var sim in _simOptions) {
      try {
        final lastCall = _allCallLogs.firstWhere(
          (l) => CallLogService.normalizeSimId(
            l.simDisplayName, phoneAccountId: l.phoneAccountId) == sim,
        );
        simPreviews[sim] = lastCall.number ?? 'No recent calls';
      } catch (_) {
        simPreviews[sim] = 'No recent calls';
      }
    }

    // Format the registered phone for display
    final hintPhone = _userPhone ?? 'your registered number';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
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
              'Pick the SIM card linked to $hintPhone to see its call logs:',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            ..._simOptions.map((sim) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListTile(
                  leading: const Icon(Icons.sim_card, color: AppColors.primary),
                  title: Text(sim, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    'Last call to/from: ${simPreviews[sim]}',
                    style: const TextStyle(fontSize: 11),
                  ),
                  onTap: () async {
                    Navigator.pop(dialogContext);
                    // Persist the user's choice
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString(_simPrefKey, sim);
                    setState(() {
                      _selectedSimFilter = sim;
                      _simSelected = true;
                    });
                    _applySimFilter();
                  },
                ),
              );
            }).toList(),
            const SizedBox(height: 12),
            const Text(
              'Tip: Pick the SIM whose last call number above belongs to one of your leads or contacts.',
              style: TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic),
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

  Future<void> _loadConversionStatusInBackground(Iterable<CallLogEntry> logs) async {
    // Only check the first 50 logs for conversion to save on reads initially
    final checkLogs = logs.take(50);
    for (var entry in checkLogs) {
      if (entry.number == null || entry.timestamp == null) continue;
      final callId = await FirebaseService.findExistingCallRecord(entry.number!, entry.timestamp!);
      if (callId != null) {
        final doc = await FirebaseService.firestore.collection(FirebaseService.callsCollection).doc(callId).get();
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
    if (entry.number == null || entry.timestamp == null || _isConverting) return;

    final key = '${entry.number}_${entry.timestamp}';
    final wasConverted = _convertedCalls[key] ?? false;

    setState(() => _isConverting = true);
    try {
      String? callId = await FirebaseService.findExistingCallRecord(entry.number!, entry.timestamp!);
      
      if (callId == null) {
        // Record it first if it doesn't exist
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
            content: Text(!wasConverted ? 'Marked as Converted!' : 'Removed Conversion'),
            backgroundColor: !wasConverted ? AppColors.success : AppColors.textSecondary,
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _isConverting = false);
    }
  }

  String _getCallTypeString(CallType? type) {
    switch (type) {
      case CallType.incoming: return 'incoming';
      case CallType.outgoing: return 'outgoing';
      case CallType.missed: return 'missed';
      case CallType.rejected: return 'rejected';
      default: return 'other';
    }
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
                  color: AppColors.primary.withValues(alpha: 0.1),
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
                                  color: AppColors.primary.withValues(alpha: 0.3),
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
                                  onChanged: (String? newValue) async {
                                    if (newValue != null) {
                                      final prefs = await SharedPreferences.getInstance();
                                      await prefs.setString(_simPrefKey, newValue);
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
                                ).withValues(alpha: 0.1),
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
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () => _toggleConverted(entry),
                                        icon: Icon(
                                          _convertedCalls['${entry.number}_${entry.timestamp}'] == true 
                                            ? Icons.check_circle 
                                            : Icons.check_circle_outline, 
                                          size: 16
                                        ),
                                        label: const Text("Converted"),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 8,
                                          ),
                                          visualDensity: VisualDensity.compact,
                                          foregroundColor: _convertedCalls['${entry.number}_${entry.timestamp}'] == true 
                                            ? AppColors.success 
                                            : AppColors.textSecondary,
                                          side: BorderSide(
                                            color: _convertedCalls['${entry.number}_${entry.timestamp}'] == true 
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
    'Hot Deals',
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.note_add, color: AppColors.primary),
            const SizedBox(width: 8),
            const Text('Add Note'),
          ],
        ),
        content: TextField(
          controller: noteController,
          maxLines: 3,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Enter note about this call...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
                // Find or create lead for this number, then save note
                final snapshot = await FirebaseFirestore.instance
                    .collection(FirebaseService.leadsCollection)
                    .where('phone', isEqualTo: entry.number)
                    .limit(1)
                    .get();

                String leadId;
                if (snapshot.docs.isNotEmpty) {
                  leadId = snapshot.docs.first.id;
                } else {
                  // Create a minimal lead so the note has somewhere to live
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
