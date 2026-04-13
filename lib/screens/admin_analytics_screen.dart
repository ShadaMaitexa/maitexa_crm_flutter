import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../constants/app_constants.dart';
import '../services/firebase_service.dart';
import '../services/export_service.dart';
import '../services/diagnostic_service.dart';

// ─────────────────────────────────────────────────────────────
//  Admin Analytics Screen
//  Shows: call analytics per day, leads with label/followup,
//         Hot Deals, converted leads, per-user breakdowns,
//         date-range filter.
// ─────────────────────────────────────────────────────────────

class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  DateTime _startDate = DateTime(2026, 3, 14); // Set start date to March 14, 2026
  DateTime _endDate = DateTime.now();
  String? _selectedUserId;

  bool _isLoading = true;

  // ── aggregated data ──────────────────────────────────────────
  List<Map<String, dynamic>> _allCalls = [];
  List<Map<String, dynamic>> _allLeads = [];
  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _allFollowUps = [];
  List<Map<String, dynamic>> _allPhoneNotes = [];
  List<Map<String, dynamic>> _allLeadNotes = [];
  List<Map<String, dynamic>> _allTasks = []; // Defined here
  Map<String, String> _numberCategories = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── loaders ──────────────────────────────────────────────────
  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _fetchCalls(),
        _fetchLeads(),
        FirebaseService.getAllUsers(),
        _fetchFollowUps(),
        _fetchNumberCategories(),
        _fetchPhoneNotes(),
        _fetchLeadNotes(),
        _fetchEnquiries(),
        FirebaseService.getTasks(), // Add fetch tasks here
      ]);

      setState(() {
        _allCalls = results[0] as List<Map<String, dynamic>>;
        _allLeads = [
           ...(results[1] as List<Map<String, dynamic>>),
           ...(results[7] as List<Map<String, dynamic>>),
        ];

        // Filter out "Unknown" users
        _allUsers = (results[2] as List).map((u) {
          final user = u as dynamic;
          return {'id': user.id as String, 'name': user.name as String};
        }).where((u) {
           final name = u['name'].toString().toLowerCase();
           final id = u['id'].toString().toLowerCase();
           return !name.contains('unknown') && id != 'unknown' && id != 'null' && id.isNotEmpty;
        }).toList();
        
        _allFollowUps = results[3] as List<Map<String, dynamic>>;
        _numberCategories = results[4] as Map<String, String>;
        _allPhoneNotes = results[5] as List<Map<String, dynamic>>;
        _allLeadNotes = results[6] as List<Map<String, dynamic>>;
        _allTasks = results[8] as List<Map<String, dynamic>>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e'),
              backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<List<Map<String, dynamic>>> _fetchCalls() async {
    final snap = await FirebaseService.firestore
        .collection(FirebaseService.callsCollection)
        .get();
    debugPrint('DB ANALYTICS: Found ${snap.docs.length} calls');
    for (var d in snap.docs.take(3)) {
       debugPrint('DATA SAMPLE: ID=${d.id}, data=${d.data()}');
    }
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  Future<List<Map<String, dynamic>>> _fetchLeads() async {
    final snap = await FirebaseService.firestore
        .collection(FirebaseService.leadsCollection)
        .get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  Future<List<Map<String, dynamic>>> _fetchEnquiries() async {
    final snap = await FirebaseService.firestore
        .collection(FirebaseService.enquiriesCollection)
        .get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  Future<List<Map<String, dynamic>>> _fetchFollowUps() async {
    final snap = await FirebaseService.firestore
        .collection(FirebaseService.followUpsCollection)
        .get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  Future<List<Map<String, dynamic>>> _fetchPhoneNotes() async {
    final snap = await FirebaseService.firestore
        .collection(FirebaseService.phoneNotesCollection)
        .get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  Future<List<Map<String, dynamic>>> _fetchLeadNotes() async {
    final snap = await FirebaseService.firestore
        .collection(FirebaseService.leadNotesCollection)
        .get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  Future<Map<String, String>> _fetchNumberCategories() async {
    final snap = await FirebaseService.firestore
        .collection(FirebaseService.numberCategoriesCollection)
        .get();
    final map = <String, String>{};
    for (final d in snap.docs) {
      final cat = d.data()['category'] as String?;
      if (cat != null) map[d.id] = cat;
    }
    return map;
  }

  // ── helpers ──────────────────────────────────────────────────
  DateTime? _tsToDate(dynamic ts) {
    if (ts == null) return null;
    if (ts is Timestamp) return ts.toDate();
    if (ts is int) return DateTime.fromMillisecondsSinceEpoch(ts);
    if (ts is DateTime) return ts;
    return null;
  }

  bool _inRange(DateTime? dt) {
    if (dt == null) return false;
    final start =
        DateTime(_startDate.year, _startDate.month, _startDate.day);
    final end = DateTime(
        _endDate.year, _endDate.month, _endDate.day, 23, 59, 59);
    return dt.isAfter(start.subtract(const Duration(seconds: 1))) &&
        dt.isBefore(end.add(const Duration(seconds: 1)));
  }

  List<Map<String, dynamic>> get _filteredCalls => _allCalls.where((c) {
        final dateObj = c['timestamp'] ?? c['created_at'] ?? c['createdAt'];
        final range = _inRange(_tsToDate(dateObj));
        if (!range) return false;
        if (_selectedUserId != null) {
          final uid = (c['userId'] ?? c['user_id'] ?? c['createdBy'] ?? '').toString();
          return uid == _selectedUserId;
        }
        return true;
      }).toList();

  List<Map<String, dynamic>> get _filteredLeads => _allLeads.where((l) {
        final dateObj = l['created_at'] ?? l['createdAt'] ?? l['timestamp'];
        final range = _inRange(_tsToDate(dateObj));
        if (!range) return false;
        if (_selectedUserId != null) {
          final uid = (l['createdBy'] ?? l['user_id'] ?? l['userId'] ?? '').toString();
          return uid == _selectedUserId;
        }
        return true;
      }).toList();

  List<Map<String, dynamic>> get _filteredFollowUps => _allFollowUps.where((f) {
        final dt = _tsToDate(f['followUpDate'] ?? f['created_at'] ?? f['createdAt'] ?? f['timestamp']);
        final range = _inRange(dt);
        if (!range) return false;
        if (_selectedUserId != null) {
          final uid = (f['createdBy'] ?? f['userId'] ?? '').toString();
          return uid == _selectedUserId;
        }
        return true;
      }).toList();

  List<Map<String, dynamic>> get _filteredPhoneNotes => _allPhoneNotes.where((n) {
        final dt = _tsToDate(n['created_at'] ?? n['createdAt'] ?? n['timestamp']);
        final range = _inRange(dt);
        if (!range) return false;
        if (_selectedUserId != null) {
          final uid = (n['userId'] ?? n['user_id'] ?? '').toString();
          return uid == _selectedUserId;
        }
        return true;
      }).toList();

  List<Map<String, dynamic>> get _filteredLeadNotes => _allLeadNotes.where((n) {
        final dt = _tsToDate(n['created_at'] ?? n['createdAt'] ?? n['timestamp']);
        final range = _inRange(dt);
        if (!range) return false;
        if (_selectedUserId != null) {
          final uid = (n['userId'] ?? n['user_id'] ?? '').toString();
          return uid == _selectedUserId;
        }
        return true;
      }).toList();

  // group calls by day
  Map<String, List<Map<String, dynamic>>> _groupByDay(
      List<Map<String, dynamic>> items, String tsKey) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final item in items) {
      final dt = _tsToDate(item[tsKey]);
      if (dt == null) continue;
      final key = DateFormat('yyyy-MM-dd').format(dt);
      grouped.putIfAbsent(key, () => []).add(item);
    }
    return grouped;
  }

  String _callType(Map c) {
    final t = (c['type'] ?? c['call_type'] ?? '').toString().toLowerCase();
    if (t.contains('incoming')) return 'Incoming';
    if (t.contains('outgoing')) return 'Outgoing';
    if (t.contains('missed')) return 'Missed';
    return 'Other';
  }

  String _leadLabel(Map l) {
    return (l['label'] ?? l['category'] ?? _numberCategories[l['phone'] ?? ''] ?? '').toString();
  }

  bool _isHotDeal(Map l) =>
      _leadLabel(l).toLowerCase().contains('hot') || (l['status'] ?? '').toString().toLowerCase().contains('hot');

  bool _isConverted(Map l) =>
      l['isConverted'] == true ||
      (l['status'] ?? '').toString().toLowerCase().contains('convert');

  bool _isFollowUp(Map l) =>
      _leadLabel(l).toLowerCase().contains('follow');

  String _findUserName(String? uid) {
    if (uid == null || uid.isEmpty || uid == 'null' || uid == 'undefined') return 'Unknown';
    
    try {
      final user = _allUsers.firstWhere((u) => u['id'] == uid, orElse: () => {});
      if (user.isNotEmpty) return user['name']?.toString() ?? 'User ($uid)';
    } catch (_) {}
    
    return 'User ($uid)';
  }

  // ── date picker ──────────────────────────────────────────────
  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  // ── build ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Container(
      color: const Color(0xFFF0F4FF),
      child: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverToBoxAdapter(child: _buildDateFilter()),
          SliverToBoxAdapter(child: _buildQuickStatsStrip()),
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverTabBarDelegate(
              child: _buildTabBar(),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _CallsTab(
                calls: _filteredCalls,
                phoneNotes: _allPhoneNotes,
                leadNotes: _allLeadNotes,
                allFollowUps: _allFollowUps,
                groupByDay: _groupByDay,
                callType: _callType,
                isHotDeal: _isHotDeal,
                findUserName: _findUserName,
                numberCategories: _numberCategories,
                tsToDate: _tsToDate),
            _LeadsTab(
                leads: _filteredLeads,
                labelFn: _leadLabel,
                isHot: _isHotDeal,
                isConverted: _isConverted,
                isFollowUp: _isFollowUp,
                tsToDate: _tsToDate,
                findUserName: _findUserName),
            _HotDealsTab(
                leads: _filteredLeads,
                labelFn: _leadLabel,
                isHot: _isHotDeal,
                tsToDate: _tsToDate,
                findUserName: _findUserName),
            _UserStatsTab(
                calls: _filteredCalls,
                leads: _filteredLeads,
                followUps: _filteredFollowUps,
                phoneNotes: _filteredPhoneNotes,
                leadNotes: _filteredLeadNotes,
                users: _allUsers,
                callType: _callType,
                isHot: _isHotDeal,
                isConverted: _isConverted,
                findUserName: _findUserName,
                onUserTap: (uid) {
                  setState(() {
                    _selectedUserId = uid;
                    _tabController.animateTo(0); // Go back to Calls tab with filter applied
                  });
                }),
            _FollowUpsTab(
                followUps: _filteredFollowUps,
                allFollowUps: _allFollowUps,
                tsToDate: _tsToDate,
                findUserName: _findUserName),
          ],
        ),
      ),
    );
  }


  Widget _buildDateFilter() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Analytics',
                style: TextStyle(
                  color: Color(0xFF1E293B),
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              Container(
                height: 36,
                width: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        final enriched = _filteredCalls.map((c) {
                          final uid = (c['userId'] ?? c['user_id'] ?? c['createdBy'] ?? '').toString();
                          final lead = _allLeads.firstWhere(
                            (l) => l['id'] == c['lead_id'] || l['phone'] == c['phone_number'],
                            orElse: () => <String, dynamic>{},
                          );
                          
                          // Find latest follow up for this contact
                          final contactPhone = (c['phone_number'] ?? c['number'] ?? '').toString();
                          final followUpMatches = _allFollowUps.where((f) => 
                            (f['phoneNumber'] ?? f['phone'] ?? '').toString() == contactPhone
                          ).toList()..sort((a,b) {
                              final aD = _tsToDate(a['followUpDate']);
                              final bD = _tsToDate(b['followUpDate']);
                              if (aD == null) return 1;
                              if (bD == null) return -1;
                              return bD.compareTo(aD);
                          });

                          final latestFU = followUpMatches.isNotEmpty ? followUpMatches.first : null;
                          final fuDate = latestFU != null ? _tsToDate(latestFU['followUpDate']) : null;
                          final fuStaff = latestFU != null ? _findUserName((latestFU['createdBy'] ?? latestFU['userId'])?.toString()) : 'None';
                          final fuNote = latestFU != null ? (latestFU['notes'] ?? latestFU['note'] ?? '').toString() : '';

                          // ENRICHMENT: Fetch additional notes from phoneNotes for this number
                          final relatedPhoneNotes = _allPhoneNotes.where((n) {
                             final nPhone = (n['phoneNumber'] ?? n['phone'] ?? '').toString();
                             return nPhone == contactPhone && nPhone.isNotEmpty;
                          }).map((n) => n['note'] ?? n['message'] ?? '').where((n) => n.toString().isNotEmpty).toList();
                          
                          String existingNote = (c['note'] ?? c['notes'] ?? '').toString();
                          List<String> allNotes = [if (existingNote.isNotEmpty) existingNote, ...relatedPhoneNotes.map((e) => e.toString())];

                          return {
                            ...c,
                            'userName': _findUserName(uid),
                            'isHot': _isHotDeal(lead),
                            'isConverted': _isConverted(lead),
                            'status': lead['status'] ?? c['status'] ?? '',
                            'label': _leadLabel(lead).isEmpty ? (c['label'] ?? '') : _leadLabel(lead),
                            'followUpDate': fuDate != null ? DateFormat('MMM d, yyyy').format(fuDate) : 'None',
                            'followUpStaff': fuStaff,
                            'followUpNote': fuNote,
                            'notes': allNotes, // Service will join these
                          };
                        }).toList();

                        final dateRangeStr = '${DateFormat('MMM d').format(_startDate)}-${DateFormat('MMM d').format(_endDate)}';
                        final staffSuffix = _selectedUserId != null ? '_${_findUserName(_selectedUserId).replaceAll(' ', '_')}' : '_All_Staff';
                        final fullFileName = 'CallLogs_${staffSuffix}_$dateRangeStr';
                        
                        if (enriched.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('No call logs found in this range to export.'),
                              backgroundColor: Colors.orange,
                            )
                          );
                          return;
                        }
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Exporting Call Logs...'))
                        );
                        ExportService.exportCallsToCsv(enriched, fullFileName);
                      },
                      icon: const Icon(Icons.call_outlined, color: AppColors.primary, size: 20),
                      tooltip: 'Export Call Logs',
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        // MASTER PROGRESS REPORT LOGIC
                        final masterData = _allLeads.map((l) {
                          final phone = (l['phone'] ?? l['phoneNumber'] ?? '').toString();
                          
                          // 1. Gather all calls for this lead
                          final leadCalls = _allCalls.where((c) => 
                            (c['phone_number'] ?? c['number'] ?? '').toString() == phone && phone.isNotEmpty
                          ).toList();
                          
                          final inc = leadCalls.where((c) => _callType(c) == 'Incoming').length;
                          final out = leadCalls.where((c) => _callType(c) == 'Outgoing').length;
                          final mis = leadCalls.where((c) => _callType(c) == 'Missed').length;
                          
                          DateTime? lastCallDt;
                          if (leadCalls.isNotEmpty) {
                            leadCalls.sort((a,b) {
                              final aD = _tsToDate(a['timestamp'] ?? a['createdAt']) ?? DateTime(2000);
                              final bD = _tsToDate(b['timestamp'] ?? b['createdAt']) ?? DateTime(2000);
                              return bD.compareTo(aD);
                            });
                            lastCallDt = _tsToDate(leadCalls.first['timestamp'] ?? leadCalls.first['createdAt']);
                          }
                          
                          // 2. Gather latest note
                          final relatedNotes = _allPhoneNotes.where((n) => 
                            (n['phoneNumber'] ?? n['phone'] ?? '').toString() == phone && phone.isNotEmpty
                          ).toList()..sort((a,b) {
                             final aD = _tsToDate(a['createdAt'] ?? a['timestamp']) ?? DateTime(2000);
                             final bD = _tsToDate(b['createdAt'] ?? b['timestamp']) ?? DateTime(2000);
                             return bD.compareTo(aD);
                          });
                          
                          final latestNote = relatedNotes.isNotEmpty ? (relatedNotes.first['note'] ?? relatedNotes.first['message'] ?? '') : '';
                          
                          // 3. Gather latest follow up
                          final relatedFU = _allFollowUps.where((f) => 
                            (f['phoneNumber'] ?? f['phone'] ?? '').toString() == phone && phone.isNotEmpty
                          ).toList()..sort((a,b) {
                             final aD = _tsToDate(a['followUpDate']) ?? DateTime(2000);
                             final bD = _tsToDate(b['followUpDate']) ?? DateTime(2000);
                             return bD.compareTo(aD);
                          });
                          
                          final latestFU = relatedFU.isNotEmpty ? relatedFU.first : null;
                          final fuDate = latestFU != null ? _tsToDate(latestFU['followUpDate']) : null;
                          final fuNote = latestFU != null ? (latestFU['notes'] ?? latestFU['note'] ?? '') : '';
                          final fuStaff = latestFU != null ? _findUserName((latestFU['createdBy'] ?? latestFU['userId'])?.toString()) : 'None';

                          return {
                            ...l,
                            'totalCalls': leadCalls.length,
                            'incomingCalls': inc,
                            'outgoingCalls': out,
                            'missedCalls': mis,
                            'lastCallDate': lastCallDt != null ? DateFormat('dd-MM-yyyy').format(lastCallDt) : 'None',
                            'staffName': _findUserName((l['createdBy'] ?? l['user_id'] ?? l['userId'])?.toString()),
                            'latestNote': latestNote,
                            'followUpDate': fuDate != null ? DateFormat('dd-MM-yyyy').format(fuDate) : 'None',
                            'followUpNote': fuNote,
                            'followUpStaff': fuStaff,
                          };
                        }).toList();

                        if (masterData.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('No lead data found to export.'))
                          );
                          return;
                        }

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Exporting Master Progress Report...'))
                        );
                        
                        ExportService.exportLeadLifecycleToCsv(masterData, 'Master_Lead_Progress_Export');
                      },
                      icon: const Icon(Icons.assignment_outlined, color: AppColors.primary, size: 20),
                      tooltip: 'Master Progress Report',
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(flex: 3, child: _buildUserDropdown()),
              const SizedBox(width: 8),
              Expanded(
                flex: 4,
                child: GestureDetector(
                  onTap: _pickDateRange,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, color: Color(0xFF64748B), size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${DateFormat('MMM d').format(_startDate)} – ${DateFormat('MMM d').format(_endDate)}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Color(0xFF334155), fontWeight: FontWeight.w600, fontSize: 12),
                          ),
                        ),
                        const Icon(Icons.keyboard_arrow_down, color: Color(0xFF94A3B8), size: 18),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_selectedUserId != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: GestureDetector(
                onTap: () => setState(() => _selectedUserId = null),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.person, color: AppColors.primary, size: 12),
                      const SizedBox(width: 4),
                      Text('Staff: ${_findUserName(_selectedUserId)}', 
                        style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 4),
                      const Icon(Icons.close, color: AppColors.primary, size: 12),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }



  Widget _buildUserDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: _selectedUserId,
          dropdownColor: Colors.white,
          icon: const Icon(Icons.person_outline, color: Color(0xFF64748B), size: 16),
          isExpanded: true,
          hint: const Text('Staff',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
          style: const TextStyle(color: Color(0xFF334155), fontSize: 12, fontWeight: FontWeight.w600),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('All Staff'),
            ),
            ..._allUsers.map((u) => DropdownMenuItem<String?>(
                  value: u['id'].toString(),
                  child: Text(u['name'].toString()),
                )),
          ],
          onChanged: (val) {
            setState(() => _selectedUserId = val);
          },
        ),
      ),
    );
  }



  Widget _buildQuickStatsStrip() {
    final callsCount = _filteredCalls.length;
    final leadsCount = _filteredLeads.length;
    final hotDeals = _filteredLeads.where(_isHotDeal).length;
    final followUps = _filteredFollowUps.length;

    return Container(
      padding: const EdgeInsets.only(bottom: 8, top: 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            _QuickStatCard('Calls', '$callsCount', Icons.call, const Color(0xFF3B82F6)),
            const SizedBox(width: 10),
            _QuickStatCard('Leads', '$leadsCount', Icons.people, const Color(0xFF10B981)),
            const SizedBox(width: 10),
            _QuickStatCard('Hot', '$hotDeals', Icons.whatshot, const Color(0xFFEF4444)),
            const SizedBox(width: 10),
            _QuickStatCard('Diary', '$followUps', Icons.event_note, const Color(0xFF8B5CF6)),
          ],
        ),
      ),
    );
  }

  Widget _QuickStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      width: 110,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF1E293B),
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        dividerColor: Colors.transparent,
        indicatorColor: AppColors.primary,
        indicatorWeight: 3,
        indicatorSize: TabBarIndicatorSize.label,
        labelColor: AppColors.primary,
        unselectedLabelColor: const Color(0xFF94A3B8),
        labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.normal),
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        tabs: const [
          Tab(text: 'Calls'),
          Tab(text: 'Leads'),
          Tab(text: 'Hot'),
          Tab(text: 'Growth'),
          Tab(text: 'Diary'),
        ],
      ),
    );
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _SliverTabBarDelegate({required this.child});

  @override
  double get minExtent => 60;
  @override
  double get maxExtent => 60;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: const Color(0xFFF0F4FF),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: child,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) => false;
}





// ─────────────────────────────────────────────────────────────
//  CALLS TAB
// ─────────────────────────────────────────────────────────────
class _CallsTab extends StatelessWidget {
  final List<Map<String, dynamic>> calls;
  final List<Map<String, dynamic>> phoneNotes;
  final List<Map<String, dynamic>> leadNotes;
  final List<Map<String, dynamic>> allFollowUps;
  final Map<String, List<Map<String, dynamic>>> Function(
      List<Map<String, dynamic>>, String) groupByDay;
  final String Function(Map) callType;
  final bool Function(Map) isHotDeal;
  final String Function(String?) findUserName;
  final Map<String, String> numberCategories;
  final DateTime? Function(dynamic) tsToDate;

  const _CallsTab({
    required this.calls,
    required this.phoneNotes,
    required this.leadNotes,
    required this.allFollowUps,
    required this.groupByDay,
    required this.callType,
    required this.isHotDeal,
    required this.findUserName,
    required this.numberCategories,
    required this.tsToDate,
  });

  int _count(List<Map<String, dynamic>> list, String type) =>
      list.where((c) => callType(c) == type).length;

  int _hotCount(List<Map<String, dynamic>> list) => list
      .where((c) {
        final label = (c['label'] ?? numberCategories[(c['phone_number'] ?? c['number'])?.toString() ?? ''] ?? '').toString().toLowerCase();
        return label.contains('hot');
      })
      .length;

  @override
  Widget build(BuildContext context) {
    if (calls.isEmpty) return _empty('No calls in the selected date range');

    final grouped = groupByDay(calls, 'timestamp');
    final sortedDays = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    // overall summary
    final totalIn = _count(calls, 'Incoming');
    final totalOut = _count(calls, 'Outgoing');
    final totalMissed = _count(calls, 'Missed');
    final totalHot = _hotCount(calls);

    final double screenWidth = MediaQuery.of(context).size.width;
    final int gridCount = screenWidth > 1200 ? 6 : (screenWidth > 800 ? 3 : 2);
    final double aspectRatio = screenWidth > 800 ? 1.8 : 1.3;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Summary Cards ────────────────────────────────────
        _SectionHeader('Overall Stats', Icons.insights_rounded),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: gridCount,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: aspectRatio,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _SummaryCard('Total Calls', '${calls.length}',
                Icons.call, const Color(0xFF3B82F6)),
            _SummaryCard('Incoming', '$totalIn',
                Icons.call_received, const Color(0xFF10B981)),
            _SummaryCard('Outgoing', '$totalOut',
                Icons.call_made, const Color(0xFF6366F1)),
            _SummaryCard('Missed', '$totalMissed',
                Icons.call_missed, const Color(0xFFEF4444)),
            _SummaryCard('Hot Calls', '$totalHot',
                Icons.local_fire_department, const Color(0xFFF59E0B)),
            _SummaryCard('Total Days', '${sortedDays.length}',
                Icons.calendar_month, const Color(0xFF8B5CF6)),
          ],
        ),
        const SizedBox(height: 24),

        // ── Per-Day Breakdown ────────────────────────────────
        _SectionHeader('Daily Breakdown', Icons.today),
        const SizedBox(height: 8),
        ...sortedDays.map((day) {
          final dayItems = grouped[day]!;
          final dt = DateFormat('yyyy-MM-dd').parse(day);
          final inc = _count(dayItems, 'Incoming');
          final out = _count(dayItems, 'Outgoing');
          final mis = _count(dayItems, 'Missed');
          final hot = _hotCount(dayItems);

          return _DayCallCard(
            date: dt,
            items: dayItems,
            phoneNotes: phoneNotes,
            leadNotes: leadNotes,
            allFollowUps: allFollowUps,
            callType: callType,
            findUserName: findUserName,
            numberCategories: numberCategories,
            tsToDate: tsToDate,
            total: dayItems.length,
            incoming: inc,
            outgoing: out,
            missed: mis,
            HotDeals: hot,
          );
        }),
      ],
    );
  }
}

class _DayCallCard extends StatefulWidget {
  final DateTime date;
  final List<Map<String, dynamic>> items;
  final List<Map<String, dynamic>> phoneNotes;
  final List<Map<String, dynamic>> leadNotes;
  final List<Map<String, dynamic>> allFollowUps;
  final String Function(Map) callType;
  final String Function(String?) findUserName;
  final Map<String, String> numberCategories;
  final DateTime? Function(dynamic) tsToDate;
  final int total, incoming, outgoing, missed, HotDeals;

  const _DayCallCard({
    required this.date,
    required this.items,
    required this.phoneNotes,
    required this.leadNotes,
    required this.allFollowUps,
    required this.callType,
    required this.findUserName,
    required this.numberCategories,
    required this.tsToDate,
    required this.total,
    required this.incoming,
    required this.outgoing,
    required this.missed,
    required this.HotDeals,
  });

  @override
  State<_DayCallCard> createState() => _DayCallCardState();
}

class _DayCallCardState extends State<_DayCallCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final isToday = DateUtils.isSameDay(widget.date, DateTime.now());

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: isToday
            ? Border.all(color: AppColors.primary, width: 1.5)
            : null,
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat('dd').format(widget.date),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppColors.primary,
                          ),
                        ),
                        Text(
                          DateFormat('MMM').format(widget.date),
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              DateFormat('EEEE').format(widget.date),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            if (isToday) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text('Today',
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 10)),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('${widget.total} total calls',
                            style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12)),
                      ],
                    ),
                  ),
                  _MiniStatBadge(widget.incoming, Colors.green, Icons.call_received),
                  const SizedBox(width: 6),
                  _MiniStatBadge(widget.outgoing, AppColors.primary, Icons.call_made),
                  const SizedBox(width: 6),
                  _MiniStatBadge(widget.missed, AppColors.error, Icons.call_missed),
                  const SizedBox(width: 6),
                  Icon(
                    _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  Row(
                    children: [
                      _StatBadgeButton('Incoming', widget.incoming, Colors.green),
                      const SizedBox(width: 8),
                      _StatBadgeButton('Outgoing', widget.outgoing, AppColors.primary),
                      const SizedBox(width: 8),
                      _StatBadgeButton('Missed', widget.missed, AppColors.error),
                    ],
                  ),
                  if (widget.HotDeals > 0) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.local_fire_department, color: Colors.orange, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            '${widget.HotDeals} Hot Deal Calls',
                            style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Text('Daily Logs:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  ...widget.items.map((call) {
                    final type = widget.callType(call);
                    final number = (call['phone_number'] ?? call['number'] ?? 'No Number').toString();
                    final name = call['name'] ?? 'Unknown';
                    final user = widget.findUserName((call['userId'] ?? call['user_id'])?.toString());
                    final callTs = call['timestamp'];
                    final time = callTs != null
                        ? DateFormat('h:mm a').format(widget.tsToDate(callTs) ?? DateTime.now())
                        : '--:--';

                    final label = (call['label'] ?? widget.numberCategories[number] ?? '').toString();
                    final isHot = label.toLowerCase().contains('hot');

                    final callNotes = (call['notes'] as List?)?.cast<Map<String, dynamic>>() ?? [];
                    final matchingNotes = [
                      ...callNotes,
                      ...widget.phoneNotes.where((n) => (n['phone'] ?? n['phone_number']) == number),
                      ...widget.leadNotes.where((n) => n['phone'] == number)
                    ];
                    
                    final callFollowUp = call['follow_up'] as Map<String, dynamic>?;
                    final matchingFollowUps = [
                      if (callFollowUp != null) callFollowUp,
                      ...widget.allFollowUps.where((f) => (f['phoneNumber'] ?? f['phone']) == number),
                    ];

                    Color typeColor = Colors.grey;
                    IconData typeIcon = Icons.call;
                    if (type == 'Incoming') { typeColor = Colors.green; typeIcon = Icons.call_received; }
                    else if (type == 'Outgoing') { typeColor = AppColors.primary; typeIcon = Icons.call_made; }
                    else if (type == 'Missed') { typeColor = AppColors.error; typeIcon = Icons.call_missed; }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isHot ? Colors.orange.withOpacity(0.03) : AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: isHot ? Border.all(color: Colors.orange.withOpacity(0.2), width: 1) : null,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(typeIcon, color: typeColor, size: 16),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text('$name ($number)', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                              ),
                              if (label.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isHot ? Colors.orange : Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(label.toUpperCase(), style: TextStyle(color: isHot ? Colors.white : Colors.grey.shade700, fontSize: 9, fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('Logged by: $user • $time • ${call['sim_name'] ?? 'Unknown SIM'}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          
                          if (matchingNotes.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            const Divider(height: 1),
                            const SizedBox(height: 8),
                            ...matchingNotes.map((n) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.note,
                                          size: 12, color: Colors.orange),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          n['note'] ?? '',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              fontStyle: FontStyle.italic),
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                          ],

                          if (matchingFollowUps.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            const Text('Scheduled Follow-Ups:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.statusFollowUp)),
                            ...matchingFollowUps.map((f) {
                              final fDate = widget.tsToDate(f['followUpDate']);
                              final dateStr = fDate != null ? DateFormat('MMM d, h:mm a').format(fDate) : 'No date';
                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(
                                  children: [
                                    const Icon(Icons.event, size: 10, color: AppColors.statusFollowUp),
                                    const SizedBox(width: 6),
                                    Text('$dateStr • ${f['status'] ?? 'Pending'}', style: const TextStyle(fontSize: 11)),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  LEADS TAB
// ─────────────────────────────────────────────────────────────
class _LeadsTab extends StatefulWidget {
  final List<Map<String, dynamic>> leads;
  final String Function(Map) labelFn;
  final bool Function(Map) isHot;
  final bool Function(Map) isConverted;
  final bool Function(Map) isFollowUp;
  final DateTime? Function(dynamic) tsToDate;
  final String Function(String?) findUserName;

  const _LeadsTab({
    required this.leads,
    required this.labelFn,
    required this.isHot,
    required this.isConverted,
    required this.isFollowUp,
    required this.tsToDate,
    required this.findUserName,
  });

  @override
  State<_LeadsTab> createState() => _LeadsTabState();
}

class _LeadsTabState extends State<_LeadsTab> {
  String _filter = 'All';
  final _filters = ['All', 'Hot Deals', 'Follow Up', 'Converted'];

  List<Map<String, dynamic>> get _filtered {
    return widget.leads.where((l) {
      switch (_filter) {
        case 'Hot Deals':
          return widget.isHot(l);
        case 'Follow Up':
          return widget.isFollowUp(l);
        case 'Converted':
          return widget.isConverted(l);
        default:
          return true;
      }
    }).toList()
      ..sort((a, b) {
        final aDate = widget.tsToDate(a['created_at']);
        final bDate = widget.tsToDate(b['created_at']);
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.leads.isEmpty) {
      return _empty('No leads in the selected date range');
    }

    final hot = widget.leads.where(widget.isHot).length;
    final converted = widget.leads.where(widget.isConverted).length;
    final followUp = widget.leads.where(widget.isFollowUp).length;

    return Column(
      children: [
        // Summary
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _CompactStat('Total', '${widget.leads.length}',
                  AppColors.primary),
              _CompactStat('Hot', '$hot', Colors.orange),
              _CompactStat('Follow Up', '$followUp',
                  AppColors.statusFollowUp),
              _CompactStat('Converted', '$converted', AppColors.success),
            ],
          ),
        ),

        // Filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: _filters.map((f) {
              final selected = _filter == f;
              return GestureDetector(
                onTap: () => setState(() => _filter = f),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected
                          ? AppColors.primary
                          : Colors.grey.shade300,
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            )
                          ]
                        : null,
                  ),
                  child: Text(
                    f,
                    style: TextStyle(
                      color: selected ? Colors.white : AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // List
        Expanded(
          child: _filtered.isEmpty
              ? _empty('No leads matching "$_filter"')
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  itemCount: _filtered.length,
                  itemBuilder: (ctx, i) {
                    final lead = _filtered[i];
                    return _LeadCard(
                      lead: lead,
                      label: widget.labelFn(lead),
                      isHot: widget.isHot(lead),
                      isConverted: widget.isConverted(lead),
                      isFollowUp: widget.isFollowUp(lead),
                      date: widget.tsToDate(lead['created_at']),
                      userName: widget.findUserName(
                          (lead['createdBy'] ?? lead['user_id'])?.toString()),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Hot Deals TAB
// ─────────────────────────────────────────────────────────────
class _HotDealsTab extends StatelessWidget {
  final List<Map<String, dynamic>> leads;
  final String Function(Map) labelFn;
  final bool Function(Map) isHot;
  final DateTime? Function(dynamic) tsToDate;
  final String Function(String?) findUserName;

  const _HotDealsTab({
    required this.leads,
    required this.labelFn,
    required this.isHot,
    required this.tsToDate,
    required this.findUserName,
  });

  @override
  Widget build(BuildContext context) {
    final hotLeads = leads.where(isHot).toList()
      ..sort((a, b) {
        final aDate = tsToDate(a['created_at']);
        final bDate = tsToDate(b['created_at']);
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });

    if (hotLeads.isEmpty) {
      return _empty('No Hot Deals found');
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF6B35), Color(0xFFFF8E53)],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.local_fire_department,
                  color: Colors.white, size: 36),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Hot Deals',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  Text('${hotLeads.length} total from all time',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 13)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...hotLeads.map((lead) => _LeadCard(
              lead: lead,
              label: labelFn(lead),
              isHot: true,
              isConverted: (lead['status'] ?? '')
                  .toString()
                  .toLowerCase()
                  .contains('convert'),
              isFollowUp: labelFn(lead).toLowerCase().contains('follow'),
              date: tsToDate(lead['created_at']),
              userName: findUserName(
                  (lead['createdBy'] ?? lead['user_id'])?.toString()),
            )),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  USER STATS TAB
// ─────────────────────────────────────────────────────────────
class _UserStatsTab extends StatefulWidget {
  final List<Map<String, dynamic>> calls;
  final List<Map<String, dynamic>> leads;
  final List<Map<String, dynamic>> followUps;
  final List<Map<String, dynamic>> phoneNotes;
  final List<Map<String, dynamic>> leadNotes;
  final List<Map<String, dynamic>> users;
  final String Function(Map) callType;
  final bool Function(Map) isHot;
  final bool Function(Map) isConverted;
  final String Function(String?) findUserName;
  final Function(String) onUserTap;

  const _UserStatsTab({
    required this.calls,
    required this.leads,
    required this.followUps,
    required this.phoneNotes,
    required this.leadNotes,
    required this.users,
    required this.callType,
    required this.isHot,
    required this.isConverted,
    required this.findUserName,
    required this.onUserTap,
  });

  @override
  State<_UserStatsTab> createState() => _UserStatsTabState();
}

class _UserStatsTabState extends State<_UserStatsTab> {
  @override
  Widget build(BuildContext context) {
    // Access widget properties via widget.xxx
    final Map<String, _UserStat> userStats = {};

    for (final call in widget.calls) {
      final uid = call['userId']?.toString() ?? call['user_id']?.toString() ?? '';
      userStats.putIfAbsent(uid, () => _UserStat(uid, widget.findUserName(uid)));
      final type = widget.callType(call);
      if (type == 'Incoming') userStats[uid]!.incoming++;
      if (type == 'Outgoing') userStats[uid]!.outgoing++;
      if (type == 'Missed') userStats[uid]!.missed++;
      if (widget.isConverted(call)) userStats[uid]!.converted++;
      userStats[uid]!.totalCalls++;
    }

    for (final lead in widget.leads) {
      final uid =
          lead['createdBy']?.toString() ?? lead['user_id']?.toString() ?? '';
      userStats.putIfAbsent(uid, () => _UserStat(uid, widget.findUserName(uid)));
      userStats[uid]!.leads++;
      if (widget.isHot(lead)) userStats[uid]!.HotDeals++;
      if (widget.isConverted(lead)) userStats[uid]!.converted++;
    }

    for (final note in widget.phoneNotes) {
      final uid = note['userId']?.toString() ?? note['user_id']?.toString() ?? '';
      if (uid.isNotEmpty) {
        userStats.putIfAbsent(uid, () => _UserStat(uid, widget.findUserName(uid)));
        userStats[uid]!.notes++;
      }
    }

    for (final note in widget.leadNotes) {
      final uid = note['userId']?.toString() ?? note['user_id']?.toString() ?? '';
      if (uid.isNotEmpty) {
        userStats.putIfAbsent(uid, () => _UserStat(uid, widget.findUserName(uid)));
        userStats[uid]!.notes++;
      }
    }

    for (final f in widget.followUps) {
      final uid = f['createdBy']?.toString() ?? f['userId']?.toString() ?? '';
      if (uid.isNotEmpty) {
        userStats.putIfAbsent(uid, () => _UserStat(uid, widget.findUserName(uid)));
        userStats[uid]!.followUps++;
      }
    }

    // Also add users with no activity (already filtered in _loadAll)
    for (final u in widget.users) {
      final uid = u['id'] as String;
      userStats.putIfAbsent(uid, () => _UserStat(uid, u['name'] as String));
    }

    final statList = userStats.values.where((s) {
       final id = s.uid.toLowerCase();
       if (id == 'unknown' || id == 'null' || id.isEmpty) return false;
       return true;
    }).toList()
      ..sort((a, b) => b.totalCalls.compareTo(a.totalCalls));

    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _SectionHeader('Staff Performance', Icons.analytics_outlined),
            const Icon(Icons.info_outline, color: Colors.blueGrey, size: 20),
          ],
        ),
        const SizedBox(height: 12),
        ...statList.map((stat) => _UserStatCard(
              stat: stat,
              onTap: () => widget.onUserTap(stat.uid),
            )),
        const SizedBox(height: 100), // Better bottom spacing
      ],
    );
  }
}

class _UserStat {
  final String uid;
  String name;
  int totalCalls = 0;
  int incoming = 0;
  int outgoing = 0;
  int missed = 0;
  int leads = 0;
  int HotDeals = 0;
  int converted = 0;
  int notes = 0;
  int followUps = 0;

  _UserStat(this.uid, this.name);
}

class _UserStatCard extends StatelessWidget {
  final _UserStat stat;
  final VoidCallback onTap;

  const _UserStatCard({required this.stat, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final initials = stat.name.isNotEmpty
        ? stat.name.trim().split(' ').map((w) => w[0]).take(2).join().toUpperCase()
        : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.primary,
                  child: Text(initials,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    stat.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                _MiniStatBadge(stat.totalCalls, AppColors.primary, Icons.call),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                Expanded(child: _GridStat('Incoming', '${stat.incoming}', Colors.green)),
                Expanded(child: _GridStat('Outgoing', '${stat.outgoing}', AppColors.primary)),
                Expanded(child: _GridStat('Missed', '${stat.missed}', AppColors.error)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _GridStat('Leads', '${stat.leads}', Colors.indigo)),
                Expanded(child: _GridStat('Hot', '${stat.HotDeals}', Colors.orange)),
                Expanded(child: _GridStat('Converted', '${stat.converted}', AppColors.success)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _GridStat('Notes', '${stat.notes}', Colors.blueGrey)),
                Expanded(child: _GridStat('Follow-Ups', '${stat.followUps}', AppColors.statusFollowUp)),
                const Expanded(child: SizedBox()), // Spacer
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: onTap,
                icon: const Icon(Icons.filter_list, size: 16),
                label: const Text('View Detailed Logs', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  backgroundColor: AppColors.primary.withOpacity(0.08),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  SHARED WIDGETS
// ─────────────────────────────────────────────────────────────
class _LeadCard extends StatelessWidget {
  final Map<String, dynamic> lead;
  final String label;
  final bool isHot;
  final bool isConverted;
  final bool isFollowUp;
  final DateTime? date;
  final String userName;

  const _LeadCard({
    required this.lead,
    required this.label,
    required this.isHot,
    required this.isConverted,
    required this.isFollowUp,
    required this.date,
    required this.userName,
  });

  @override
  Widget build(BuildContext context) {
    final name = (lead['name'] ?? lead['contact_name'] ?? 'Unknown').toString();
    final phone = (lead['phone'] ?? lead['number'] ?? '').toString();
    final source = (lead['source'] ?? '').toString();
    final status = (lead['status'] ?? 'New').toString();

    Color statusColor = AppColors.info;
    if (isConverted) statusColor = AppColors.success;
    else if (isHot) statusColor = Colors.orange;
    else if (isFollowUp) statusColor = AppColors.statusFollowUp;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: isHot
            ? Border.all(color: Colors.orange.withOpacity(0.5), width: 1.5)
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: statusColor.withOpacity(0.15),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                        color: statusColor, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      if (phone.isNotEmpty)
                        Text(phone,
                            style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12)),
                    ],
                  ),
                ),
                if (isHot)
                  const Icon(Icons.local_fire_department,
                      color: Colors.orange, size: 20),
                if (isConverted)
                  const Icon(Icons.check_circle,
                      color: AppColors.success, size: 20),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (label.isNotEmpty) _Tag(label, statusColor),
                if (status.isNotEmpty) _Tag(status, AppColors.textSecondary),
                if (source.isNotEmpty) _Tag(source, AppColors.info),
                if (userName.isNotEmpty && userName != 'Unknown')
                  _Tag(userName, AppColors.primary, icon: Icons.person),
                if (date != null)
                  _Tag(
                    DateFormat('MMM d, yyyy').format(date!),
                    Colors.grey,
                    icon: Icons.calendar_today,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;

  const _Tag(this.text, this.color, {this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard(this.title, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 20),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 12,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader(this.title, this.icon);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _MiniStatBadge extends StatelessWidget {
  final int count;
  final Color color;
  final IconData icon;

  const _MiniStatBadge(this.count, this.color, this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          Text('$count',
              style: TextStyle(
                  fontSize: 11, color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _StatBadgeButton extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatBadgeButton(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text('$count', style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16)),
            Text(label, style: TextStyle(color: color, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _CompactStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _CompactStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: color)),
          Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }
}

class _GridStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _GridStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 15)),
          Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 10)),
        ],
      ),
    );
  }
}

Widget _empty(String msg) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade300),
        const SizedBox(height: 16),
        Text(msg,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary)),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────
//  FOLLOW-UPS TAB
// ─────────────────────────────────────────────────────────────
class _FollowUpsTab extends StatelessWidget {
  final List<Map<String, dynamic>> followUps;
  final List<Map<String, dynamic>> allFollowUps;
  final DateTime? Function(dynamic) tsToDate;
  final String Function(String?) findUserName;

  const _FollowUpsTab({
    required this.followUps,
    required this.allFollowUps,
    required this.tsToDate,
    required this.findUserName,
  });

  bool _isPending(Map f) =>
      (f['status'] ?? '').toString().toLowerCase() == 'pending' ||
      (f['status'] ?? '').toString().isEmpty;

  bool _isDone(Map f) =>
      (f['status'] ?? '').toString().toLowerCase().contains('done') ||
      (f['status'] ?? '').toString().toLowerCase().contains('complet');

  DateTime? _followUpDate(Map f) =>
      tsToDate(f['followUpDate'] ?? f['follow_up_date'] ??
          f['created_at'] ?? f['createdAt']);

  @override
  Widget build(BuildContext context) {
    final pending = allFollowUps.where(_isPending).length;
    final done = allFollowUps.where(_isDone).length;
    final inRange = followUps.length;

    // Sort filtered follow-ups newest first
    final sorted = List<Map<String, dynamic>>.from(followUps)
      ..sort((a, b) {
        final aDate = _followUpDate(a);
        final bDate = _followUpDate(b);
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_month, color: Colors.white, size: 36),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Follow-Ups',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    Text('$inRange in selected range • ${allFollowUps.length} total',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Summary cards
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                'In Range',
                '$inRange',
                Icons.date_range,
                AppColors.statusFollowUp,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryCard(
                'Pending',
                '$pending',
                Icons.pending_actions,
                AppColors.warning,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryCard(
                'Done',
                '$done',
                Icons.task_alt,
                AppColors.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        if (sorted.isEmpty)
          _empty('No follow-ups in the selected date range')
        else ...[
          _SectionHeader('Follow-Up List (Date-wise)', Icons.list),
          const SizedBox(height: 8),
          ...sorted.map((f) => _FollowUpCard(
                followUp: f,
                date: _followUpDate(f),
                isPending: _isPending(f),
                isDone: _isDone(f),
                userName: findUserName(
                    f['createdBy']?.toString() ?? f['userId']?.toString()),
              )),
        ],
      ],
    );
  }
}

class _FollowUpCard extends StatelessWidget {
  final Map<String, dynamic> followUp;
  final DateTime? date;
  final bool isPending;
  final bool isDone;
  final String userName;

  const _FollowUpCard({
    required this.followUp,
    required this.date,
    required this.isPending,
    required this.isDone,
    required this.userName,
  });

  @override
  Widget build(BuildContext context) {
    final phone = (followUp['phoneNumber'] ?? followUp['phone'] ?? '').toString();
    final contactName =
        (followUp['contactName'] ?? followUp['name'] ?? 'Unknown').toString();
    final note = (followUp['notes'] ?? followUp['note'] ?? '').toString();
    final status = (followUp['status'] ?? 'Pending').toString();

    Color statusColor =
        isDone ? AppColors.success : isPending ? AppColors.warning : AppColors.info;
    IconData statusIcon =
        isDone ? Icons.task_alt : isPending ? Icons.pending_actions : Icons.info;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border(
          left: BorderSide(color: statusColor, width: 4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: statusColor.withOpacity(0.15),
                  child: Icon(statusIcon, size: 18, color: statusColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(contactName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      if (phone.isNotEmpty)
                        Text(phone,
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(status,
                      style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (date != null)
                  _Tag(
                    DateFormat('MMM d, yyyy h:mm a').format(date!),
                    Colors.grey,
                    icon: Icons.schedule,
                  ),
                if (userName.isNotEmpty && userName != 'Unknown')
                  _Tag(userName, AppColors.primary, icon: Icons.person),
                if (note.isNotEmpty)
                  _Tag(
                    note.length > 40 ? '${note.substring(0, 40)}…' : note,
                    AppColors.textSecondary,
                    icon: Icons.note,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
