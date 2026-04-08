import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../constants/app_constants.dart';
import '../providers/auth_provider.dart';

// ─── DATA MODELS ────────────────────────────────────────────────────────────

class WaCampaign {
  final String id;
  final String name;
  final String course;
  final String source;
  final String message;
  final String phone;
  final int clickCount;
  final DateTime createdAt;

  const WaCampaign({
    required this.id,
    required this.name,
    required this.course,
    required this.source,
    required this.message,
    required this.phone,
    required this.clickCount,
    required this.createdAt,
  });

  String get waUrl {
    final encoded = Uri.encodeComponent(message);
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    return 'https://wa.me/$cleanPhone?text=$encoded';
  }

  factory WaCampaign.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return WaCampaign(
      id: doc.id,
      name: d['name'] ?? '',
      course: d['course'] ?? '',
      source: d['source'] ?? '',
      message: d['message'] ?? '',
      phone: d['phone'] ?? '',
      clickCount: d['clickCount'] ?? 0,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

// ─── SCREEN ────────────────────────────────────────────────────────────────

class WhatsAppCampaignScreen extends StatefulWidget {
  const WhatsAppCampaignScreen({super.key});

  @override
  State<WhatsAppCampaignScreen> createState() => _WhatsAppCampaignScreenState();
}

class _WhatsAppCampaignScreenState extends State<WhatsAppCampaignScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF25D366).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const FaIcon(
                FontAwesomeIcons.whatsapp,
                color: Color(0xFF25D366),
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            const Text('Campaign Manager'),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'My Campaigns'),
            Tab(text: 'Create New'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'How it works',
            onPressed: () => _showHowItWorksDialog(context),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _CampaignListTab(onCreateTap: () => _tabController.animateTo(1)),
          _CreateCampaignTab(
            onCreated: () {
              _tabController.animateTo(0);
            },
          ),
        ],
      ),
    );
  }

  void _showHowItWorksDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            FaIcon(
              FontAwesomeIcons.lightbulb,
              color: Color(0xFFF59E0B),
              size: 20,
            ),
            SizedBox(width: 8),
            Text('How Campaigns Work'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: const [
              _HowItWorksStep(
                number: '1',
                title: 'Create a Campaign',
                description:
                    'Set a course name, source (Instagram, Poster, etc.) and a custom message.',
              ),
              _HowItWorksStep(
                number: '2',
                title: 'Share the Link or QR',
                description:
                    'Share on Instagram, WhatsApp Status, college posters, or any touchpoint.',
              ),
              _HowItWorksStep(
                number: '3',
                title: 'Student Clicks & Chats',
                description:
                    'The student lands in your WhatsApp with a pre-filled message mentioning the course.',
              ),
              _HowItWorksStep(
                number: '4',
                title: 'CRM Instantly Updated',
                description:
                    'You know WHICH course and FROM WHERE the lead came — zero guesswork.',
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }
}

// ─── HOW IT WORKS STEP ──────────────────────────────────────────────────────

class _HowItWorksStep extends StatelessWidget {
  final String number;
  final String title;
  final String description;
  const _HowItWorksStep({
    required this.number,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.primary,
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── CAMPAIGN LIST TAB ───────────────────────────────────────────────────────

class _CampaignListTab extends StatelessWidget {
  final VoidCallback onCreateTap;
  const _CampaignListTab({required this.onCreateTap});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('wa_campaigns')
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return _EmptyCampaignState(onCreateTap: onCreateTap);
        }

        final campaigns = snap.data!.docs
            .map((d) => WaCampaign.fromFirestore(d))
            .toList();

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: campaigns.length,
          itemBuilder: (context, index) =>
              _CampaignCard(campaign: campaigns[index]),
        );
      },
    );
  }
}

// ─── EMPTY STATE ─────────────────────────────────────────────────────────────

class _EmptyCampaignState extends StatelessWidget {
  final VoidCallback onCreateTap;
  const _EmptyCampaignState({required this.onCreateTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF25D366).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const FaIcon(
                FontAwesomeIcons.whatsapp,
                color: Color(0xFF25D366),
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Campaigns Yet',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create campaign links with pre-filled messages for each course and source. Track which platform brings the most leads.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onCreateTap,
              icon: const Icon(Icons.add),
              label: const Text('Create First Campaign'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── CAMPAIGN CARD ──────────────────────────────────────────────────────────

class _CampaignCard extends StatelessWidget {
  final WaCampaign campaign;
  const _CampaignCard({required this.campaign});

  Color get _sourceColor {
    switch (campaign.source.toLowerCase()) {
      case 'instagram':
        return const Color(0xFFE1306C);
      case 'website':
        return AppColors.primary;
      case 'poster / qr':
        return const Color(0xFF8B5CF6);
      case 'college seminar':
        return const Color(0xFFF59E0B);
      case 'whatsapp status':
        return const Color(0xFF25D366);
      default:
        return AppColors.textSecondary;
    }
  }

  bool get _isFaIcon {
    switch (campaign.source.toLowerCase()) {
      case 'instagram':
      case 'whatsapp status':
        return true;
      default:
        return false;
    }
  }

  IconData get _sourceIcon {
    switch (campaign.source.toLowerCase()) {
      case 'instagram':
        return FontAwesomeIcons.instagram;
      case 'website':
        return Icons.language;
      case 'poster / qr':
        return Icons.qr_code;
      case 'college seminar':
        return Icons.school;
      case 'whatsapp status':
        return FontAwesomeIcons.whatsapp;
      default:
        return Icons.link;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _sourceColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: _isFaIcon
                      ? FaIcon(_sourceIcon, color: _sourceColor, size: 18)
                      : Icon(_sourceIcon, color: _sourceColor, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        campaign.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '${campaign.source} · ${campaign.course}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                // Click count badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.touch_app,
                        size: 13,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${campaign.clickCount} taps',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.success,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Preview message
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                campaign.message,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            const SizedBox(height: 12),

            // Action row
            Row(
              children: [
                Expanded(
                  child: _ActionBtn(
                    icon: Icons.copy,
                    label: 'Copy Link',
                    color: AppColors.primary,
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: campaign.waUrl));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Campaign link copied!')),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionBtn(
                    icon: Icons.qr_code,
                    label: 'QR Code',
                    color: const Color(0xFF8B5CF6),
                    onTap: () => _showQRDialog(context, campaign),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionBtn(
                    faIcon: FontAwesomeIcons.whatsapp,
                    label: 'Open',
                    color: const Color(0xFF25D366),
                    onTap: () => _openCampaign(context, campaign),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openCampaign(BuildContext context, WaCampaign campaign) async {
    // Increment click counter in Firestore
    FirebaseFirestore.instance
        .collection('wa_campaigns')
        .doc(campaign.id)
        .update({'clickCount': FieldValue.increment(1)});

    final uri = Uri.parse(campaign.waUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showQRDialog(BuildContext context, WaCampaign campaign) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                campaign.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              Text(
                campaign.source,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 20),
              QrImageView(
                data: campaign.waUrl,
                version: QrVersions.auto,
                size: 220,
                backgroundColor: Colors.white,
              ),
              const SizedBox(height: 16),
              const Text(
                'Print this QR on your poster or share as image. When students scan it, they land in WhatsApp with the pre-filled message.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Close'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: campaign.waUrl));
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Link copied to clipboard'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Copy Link'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── ACTION BUTTON (small) ───────────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  final IconData? icon;
  final IconData? faIcon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({
    this.icon,
    this.faIcon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Column(
          children: [
            faIcon != null
                ? FaIcon(faIcon!, color: color, size: 16)
                : Icon(icon!, color: color, size: 16),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── CREATE CAMPAIGN TAB ────────────────────────────────────────────────────

class _CreateCampaignTab extends StatefulWidget {
  final VoidCallback onCreated;
  const _CreateCampaignTab({required this.onCreated});

  @override
  State<_CreateCampaignTab> createState() => _CreateCampaignTabState();
}

class _CreateCampaignTabState extends State<_CreateCampaignTab> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _msgCtrl = TextEditingController();

  String _selectedCourse = 'Python';
  String _selectedSource = 'Instagram';
  bool _isLoading = false;

  final List<String> _courses = [
    'Python',
    'Data Analytics',
    'Flutter',
    'AI / Machine Learning',
    'Web Development',
    'Internship Program',
    'Other',
  ];

  final List<_SourceOption> _sources = const [
    _SourceOption('Instagram', FontAwesomeIcons.instagram, Color(0xFFE1306C)),
    _SourceOption(
      'WhatsApp Status',
      FontAwesomeIcons.whatsapp,
      Color(0xFF25D366),
    ),
    _SourceOption('Website', Icons.language, AppColors.primary),
    _SourceOption('Poster / QR', Icons.qr_code, Color(0xFF8B5CF6)),
    _SourceOption('College Seminar', Icons.school, Color(0xFFF59E0B)),
  ];

  @override
  void initState() {
    super.initState();
    _updateMessage();
  }

  void _updateMessage() {
    _msgCtrl.text =
        'Hello! I am interested in the $_selectedCourse course at your institute. Kindly share the details — fees, batch timing, and admission process.';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final user = authProvider.user;

      await FirebaseFirestore.instance.collection('wa_campaigns').add({
        'name': _nameCtrl.text.trim(),
        'course': _selectedCourse,
        'source': _selectedSource,
        'message': _msgCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'clickCount': 0,
        'createdBy': user?.id ?? 'unknown',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Campaign created! Share the link or QR.'),
            backgroundColor: AppColors.success,
          ),
        );
        _nameCtrl.clear();
        _phoneCtrl.clear();
        widget.onCreated();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info Banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF25D366).withOpacity(0.15),
                    AppColors.primary.withOpacity(0.15),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF25D366).withOpacity(0.15),
                ),
              ),
              child: Row(
                children: const [
                  FaIcon(
                    FontAwesomeIcons.circleInfo,
                    color: Color(0xFF25D366),
                    size: 18,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Each campaign generates a unique WhatsApp link with a pre-filled message. Use different campaigns for Instagram, posters, seminars, etc.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            _SectionLabel('Campaign Name'),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                hintText: 'e.g. Instagram Flutter March 2025',
                prefixIcon: Icon(Icons.campaign_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
            ),

            const SizedBox(height: 16),

            _SectionLabel('Your WhatsApp Business Number'),
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                hintText: 'e.g. 919447933266 (with country code, no +)',
                prefixIcon: Icon(Icons.phone, color: Color(0xFF25D366)),
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Enter phone number';
                if (v.trim().length < 10) return 'Enter a valid number';
                return null;
              },
            ),

            const SizedBox(height: 16),

            _SectionLabel('Course'),
            DropdownButtonFormField<String>(
              value: _selectedCourse,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.book_outlined),
                border: OutlineInputBorder(),
              ),
              items: _courses
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) {
                setState(() {
                  _selectedCourse = v!;
                  _updateMessage();
                });
              },
            ),

            const SizedBox(height: 16),

            _SectionLabel('Lead Source / Platform'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _sources.map((s) {
                final selected = _selectedSource == s.label;
                return GestureDetector(
                  onTap: () => setState(() {
                    _selectedSource = s.label;
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? s.color.withOpacity(0.15)
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: selected ? s.color : Colors.grey.shade300,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        s.icon is IconData
                            ? Icon(
                                s.icon as IconData,
                                color: selected
                                    ? s.color
                                    : AppColors.textSecondary,
                                size: 16,
                              )
                            : FaIcon(
                                s.icon as IconData,
                                color: selected
                                    ? s.color
                                    : AppColors.textSecondary,
                                size: 16,
                              ),
                        const SizedBox(width: 6),
                        Text(
                          s.label,
                          style: TextStyle(
                            color: selected ? s.color : AppColors.textSecondary,
                            fontWeight: selected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            _SectionLabel('Pre-filled WhatsApp Message'),
            TextFormField(
              controller: _msgCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Message student will send when they tap the link',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter a message' : null,
            ),

            const SizedBox(height: 8),
            // Live preview
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFDCF8C6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.preview, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Preview (what student sends)',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _msgCtrl.text,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _save,
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.rocket_launch_outlined),
                label: Text(_isLoading ? 'Creating...' : 'Create Campaign'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ─── HELPERS ─────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 14,
        color: AppColors.textPrimary,
      ),
    ),
  );
}

class _SourceOption {
  final String label;
  final dynamic icon; // IconData or FaIconData
  final Color color;
  const _SourceOption(this.label, this.icon, this.color);
}
