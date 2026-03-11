import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_constants.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import '../providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/lead_provider.dart';
import '../services/firebase_service.dart';
import 'add_enquiry_screen.dart';
import 'update_enquiry_status_screen.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class EnquiriesScreen extends StatefulWidget {
  const EnquiriesScreen({super.key});

  @override
  State<EnquiriesScreen> createState() => _EnquiriesScreenState();
}

class _EnquiriesScreenState extends State<EnquiriesScreen> {
  List<Map<String, dynamic>> _enquiries = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadEnquiries();
  }

  Future<void> _loadEnquiries() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final dashboardProvider = Provider.of<DashboardProvider>(
        context,
        listen: false,
      );

      if (authProvider.user != null && authProvider.user!.id != 'admin_001') {
        // Load user-specific enquiries
        _enquiries = await FirebaseService.getUserEnquiries(
          authProvider.user!.id,
        );
      } else {
        // Load all enquiries for admin
        _enquiries = await FirebaseService.getEnquiries();
      }

      // Also refresh dashboard data to keep stats in sync
      await dashboardProvider.refreshData();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> get _filteredEnquiries {
    List<Map<String, dynamic>> filtered = _enquiries;

    // Apply status filter
    if (_statusFilter != 'all') {
      filtered = filtered.where((enquiry) {
        return enquiry['status'] == _statusFilter;
      }).toList();
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((enquiry) {
        final name = enquiry['name']?.toString().toLowerCase() ?? '';
        final phone = enquiry['phone']?.toString().toLowerCase() ?? '';
        final email = enquiry['email']?.toString().toLowerCase() ?? '';
        final college = enquiry['college']?.toString().toLowerCase() ?? '';
        final course = enquiry['course']?.toString().toLowerCase() ?? '';

        final query = _searchQuery.toLowerCase();
        return name.contains(query) ||
            phone.contains(query) ||
            email.contains(query) ||
            college.contains(query) ||
            course.contains(query);
      }).toList();
    }

    return filtered;
  }

  Future<void> _navigateToAddEnquiry() async {
    final result = await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const AddEnquiryScreen()));

    if (result == true) {
      // Refresh the list if a new enquiry was added
      _loadEnquiries();

      // Also refresh dashboard data
      final dashboardProvider = Provider.of<DashboardProvider>(
        context,
        listen: false,
      );
      await dashboardProvider.refreshData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadEnquiries,
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(AppSizes.paddingL),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Enquiries',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: _navigateToAddEnquiry,
                        icon: const Icon(
                          Icons.add,
                          color: AppColors.textInverse,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Search
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.paddingL,
                ),
                child: CustomSearchField(
                  hintText: 'Search enquiries...',
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),

              const SizedBox(height: AppSizes.paddingL),

              // Status Filter
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.paddingL,
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All', 'all'),
                      const SizedBox(width: AppSizes.paddingS),
                      _buildFilterChip('New', 'new'),
                      const SizedBox(width: AppSizes.paddingS),
                      _buildFilterChip('Contacted', 'contacted'),
                      const SizedBox(width: AppSizes.paddingS),
                      _buildFilterChip('Interested', 'interested'),
                      const SizedBox(width: AppSizes.paddingS),
                      _buildFilterChip('Not Interested', 'not_interested'),
                      const SizedBox(width: AppSizes.paddingS),
                      _buildFilterChip('Converted', 'converted'),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppSizes.paddingL),

              // Enquiries List
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Error: $_error'),
                            const SizedBox(height: 16),
                            CustomButton(
                              onPressed: _loadEnquiries,
                              text: 'Retry',
                            ),
                          ],
                        ),
                      )
                    : _filteredEnquiries.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.phone_outlined,
                              size: 64,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isEmpty && _statusFilter == 'all'
                                  ? 'No enquiries found'
                                  : 'No enquiries match your search',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.paddingL,
                        ),
                        itemCount: _filteredEnquiries.length,
                        itemBuilder: (context, index) {
                          final enquiry = _filteredEnquiries[index];
                          return _buildEnquiryCard(enquiry);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _statusFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _statusFilter = value;
        });
      },
      backgroundColor: AppColors.surface,
      selectedColor: AppColors.primary.withOpacity(0.2),
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : AppColors.textSecondary,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  Widget _buildEnquiryCard(Map<String, dynamic> enquiry) {
    final name = enquiry['name'] ?? 'Name';
    final phone = enquiry['phone'] ?? 'Phone';
    final email = enquiry['email'] ?? 'Email';
    final college = enquiry['college'] ?? 'College';
    final course = enquiry['course'] ?? 'Course';
    final source = enquiry['source'] ?? 'source';
    final status = enquiry['status'] ?? 'new';
    final notes = enquiry['notes'] ?? 'No notes';
    final createdAt = enquiry['createdAt'] as Timestamp?;

    DateTime? date;
    if (createdAt != null) {
      date = createdAt.toDate();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.paddingL),
      padding: const EdgeInsets.all(AppSizes.paddingL),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSizes.paddingM),
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.phone,
                  color: _getStatusColor(status),
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSizes.paddingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSizes.paddingXS),
                    Text(
                      phone,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status.replaceAll('_', ' ').toUpperCase(),
                  style: TextStyle(
                    color: _getStatusColor(status),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSizes.paddingM),

          // Contact Details
          Row(
            children: [
              const Icon(Icons.email, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: AppSizes.paddingXS),
              Expanded(
                child: Text(
                  email,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.paddingS),
              IconButton(
                tooltip: 'Call',
                onPressed: () => _launchPhoneCall(phone),
                icon: const Icon(
                  Icons.call,
                  color: AppColors.success,
                  size: 20,
                ),
              ),
              IconButton(
                tooltip: 'WhatsApp',
                onPressed: () => _handleWhatsApp(phone),
                icon: Icon(
                  FontAwesomeIcons.whatsapp,
                  color: Color(0xFF25D366),
                  size: 20,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSizes.paddingS),

          // College
          Row(
            children: [
              const Icon(
                Icons.school,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: AppSizes.paddingXS),
              Expanded(
                child: Text(
                  college,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSizes.paddingS),

          // Course
          Row(
            children: [
              const Icon(Icons.book, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: AppSizes.paddingXS),
              Expanded(
                child: Text(
                  course,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSizes.paddingM),

          // Notes
          if (notes.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSizes.paddingM),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(AppSizes.radiusM),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Notes:',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSizes.paddingXS),
                  Text(
                    notes,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: AppSizes.paddingM),

          // Source and Date
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Source:',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: AppSizes.paddingXS),
                    Text(
                      source.replaceAll('_', ' ').toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (date != null)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Created:',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: AppSizes.paddingXS),
                      Text(
                        _formatDate(date),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: AppSizes.paddingM),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: CustomButton(
                  text: 'View Details',
                  icon: Icons.visibility,
                  isOutlined: true,
                  onPressed: () {
                    // TODO: Navigate to enquiry details screen
                  },
                ),
              ),
              const SizedBox(width: AppSizes.paddingM),
              Expanded(
                child: CustomButton(
                  text: 'Update Status',
                  icon: Icons.edit,
                  onPressed: () {
                    Navigator.of(context)
                        .push(
                          MaterialPageRoute(
                            builder: (context) =>
                                UpdateEnquiryStatusScreen(enquiry: enquiry),
                          ),
                        )
                        .then((result) {
                          if (result == true) {
                            _loadEnquiries();
                          }
                        });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Helpers
  String _sanitizePhone(String raw) {
    final onlyDigits = raw.replaceAll(RegExp(r'[^0-9+]'), '');
    if (onlyDigits.startsWith('+')) return onlyDigits;
    // Default country code can be adjusted as needed
    return '+91${onlyDigits}';
  }

  Future<void> _launchPhoneCall(String rawPhone) async {
    final phone = _sanitizePhone(rawPhone);
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot launch phone dialer')),
      );
    }
  }

  Future<void> _handleWhatsApp(String phone) async {
    // Show selection dialog for WhatsApp type
    final leadProvider = Provider.of<LeadProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select WhatsApp'),
        content: const Text('Which WhatsApp would you like to use?'),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(context);
              leadProvider.launchWhatsAppByType(phone, 'business');
            },
            icon: const Icon(
              FontAwesomeIcons.whatsapp,
              color: Color(0xFF25D366),
            ),
            label: const Text('WhatsApp Business'),
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.pop(context);
              leadProvider.launchWhatsAppByType(phone, 'personal');
            },
            icon: const Icon(
              FontAwesomeIcons.whatsapp,
              color: Color(0xFF25D366),
            ),
            label: const Text('WhatsApp Personal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showWhatsAppFallback(String phone) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('WhatsApp Not Available'),
        content: const Text(
          'WhatsApp is not installed or cannot be opened. Would you like to:\n\n'
          '• Install WhatsApp from Play Store\n'
          '• Send SMS instead\n'
          '• Copy phone number to clipboard',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _launchPlayStore();
            },
            child: const Text('Install WhatsApp'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _launchSMS(phone);
            },
            child: const Text('Send SMS'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _copyToClipboard(phone);
            },
            child: const Text('Copy Number'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _launchPlayStore() async {
    try {
      final uri = Uri.parse('market://details?id=com.whatsapp');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback to web browser
        final webUri = Uri.parse(
          'https://play.google.com/store/apps/details?id=com.whatsapp',
        );
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cannot open Play Store')));
    }
  }

  Future<void> _launchSMS(String phone) async {
    try {
      final uri = Uri.parse('sms:$phone');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Cannot open SMS app')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cannot open SMS app')));
    }
  }

  Future<void> _copyToClipboard(String phone) async {
    try {
      await Clipboard.setData(ClipboardData(text: phone));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Phone number $phone copied to clipboard')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cannot copy to clipboard')));
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (date.isAfter(yesterday) &&
        date.isBefore(today.add(const Duration(days: 1)))) {
      return 'Today, ${_formatTime(date)}';
    } else if (date.isAfter(yesterday.subtract(const Duration(days: 1))) &&
        date.isBefore(today)) {
      return 'Yesterday, ${_formatTime(date)}';
    } else {
      return '${date.day}/${date.month}/${date.year}, ${_formatTime(date)}';
    }
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'new':
        return AppColors.info;
      case 'contacted':
        return AppColors.warning;
      case 'interested':
        return AppColors.statusFollowUp;
      case 'not_interested':
        return AppColors.error;
      case 'converted':
        return AppColors.success;
      default:
        return AppColors.textSecondary;
    }
  }
}
