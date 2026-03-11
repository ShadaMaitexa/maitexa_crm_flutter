import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../constants/app_constants.dart';
import '../providers/lead_provider.dart';
import '../services/firebase_service.dart';
import '../models/lead_model.dart';
import '../models/note_model.dart';
import '../models/activity_model.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'add_follow_up_screen.dart';

class LeadProfileScreen extends StatefulWidget {
  final String leadId;
  const LeadProfileScreen({super.key, required this.leadId});

  @override
  State<LeadProfileScreen> createState() => _LeadProfileScreenState();
}

class _LeadProfileScreenState extends State<LeadProfileScreen> {
  final TextEditingController _noteController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final leadProvider = context.watch<LeadProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text("Lead Profile")),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('leads')
            .doc(widget.leadId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Lead not found"));
          }

          final lead = LeadModel.fromFirestore(snapshot.data!);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLeadHeader(lead, leadProvider),
                const SizedBox(height: 16),
                _buildStatusPipeline(lead, leadProvider),
                const SizedBox(height: 24),
                _buildTabs(lead, leadProvider),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLeadHeader(LeadModel lead, LeadProvider provider) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  child: Text(
                    lead.name.isNotEmpty ? lead.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: IconButton(
                    onPressed: () =>
                        _showEditLeadDialog(context, lead, provider),
                    icon: const Icon(Icons.edit, size: 20),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.surface,
                      elevation: 4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              lead.name,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              lead.phone,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionIcon(
                  Icons.call,
                  "Call",
                  Colors.green,
                  () => provider.launchCall(lead.phone),
                ),
                _buildActionIcon(
                  FontAwesomeIcons.whatsapp,
                  "WhatsApp",
                  const Color(0xFF25D366),
                  () {
                    _showWhatsAppSelectionDialog(
                      context,
                      lead.phone,
                      lead.id,
                      provider,
                    );
                  },
                ),
                _buildActionIcon(
                  Icons.edit_note,
                  "Add Note",
                  AppColors.primary,
                  () => _showAddNoteDialog(context, lead.id),
                ),
                _buildActionIcon(
                  Icons.calendar_month,
                  "Schedule",
                  Colors.orange,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddFollowUpScreen(
                          phoneNumber: lead.phone,
                          contactName: lead.name,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildLeadMetaInfo(lead),
          ],
        ),
      ),
    );
  }

  void _showEditLeadDialog(
    BuildContext context,
    LeadModel lead,
    LeadProvider provider,
  ) {
    final nameController = TextEditingController(text: lead.name);
    final sourceController = TextEditingController(text: lead.source);
    final labelController = TextEditingController(text: lead.label);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Lead Profile"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "Full Name"),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: sourceController,
                decoration: const InputDecoration(labelText: "Source"),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: labelController,
                decoration: const InputDecoration(labelText: "Label / Course"),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              await provider.updateLeadDetails(lead.id, {
                'name': nameController.text.trim(),
                'source': sourceController.text.trim(),
                'label': labelController.text.trim(),
              });
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text("Update"),
          ),
        ],
      ),
    );
  }

  Widget _buildActionIcon(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return Column(
      children: [
        IconButton.filled(
          onPressed: onTap,
          icon: Icon(icon),
          style: IconButton.styleFrom(
            backgroundColor: color.withOpacity(0.1),
            foregroundColor: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildLeadMetaInfo(LeadModel lead) {
    return Column(
      children: [
        _buildInfoRow(Icons.source, "Source", lead.source),
        const Divider(),
        _buildInfoRow(Icons.label, "Label", lead.label),
        const Divider(),
        _buildInfoRow(
          Icons.access_time,
          "Created",
          DateFormat('MMM d, yyyy').format(lead.createdAt),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildStatusPipeline(LeadModel lead, LeadProvider provider) {
    final statuses = [
      'New Inquiry',
      'Contacted',
      'Interested',
      'Demo Scheduled',
      'Converted',
      'Not Interested',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Lead Status",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: statuses.map((status) {
              final isCurrent = lead.status == status;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(status),
                  selected: isCurrent,
                  onSelected: (selected) {
                    if (selected) {
                      provider.updateLeadStatus(lead.id, status);
                    }
                  },
                  selectedColor: _getStatusColor(status).withOpacity(0.2),
                  labelStyle: TextStyle(
                    color: isCurrent
                        ? _getStatusColor(status)
                        : AppColors.textSecondary,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildTabs(LeadModel lead, LeadProvider provider) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: "Activity History"),
              Tab(text: "Lead Notes"),
            ],
            dividerColor: Colors.transparent,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
          ),
          SizedBox(
            height: 400,
            child: TabBarView(
              children: [_buildActivityTimeline(lead), _buildNotesList(lead)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityTimeline(LeadModel lead) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseService.getActivitiesStream(lead.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No activities recorded yet"));
        }

        final activities = snapshot.data!.docs
            .map((doc) => ActivityModel.fromFirestore(doc))
            .toList();

        return ListView.builder(
          padding: const EdgeInsets.only(top: 16),
          itemCount: activities.length,
          itemBuilder: (context, index) {
            final activity = activities[index];
            return _buildTimelineItem(activity);
          },
        );
      },
    );
  }

  Widget _buildTimelineItem(ActivityModel activity) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.circle, size: 8, color: Colors.white),
            ),
            Container(width: 1, height: 60, color: Colors.grey.shade300),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    activity.activityType,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    DateFormat('h:mm a, MMM d').format(activity.timestamp),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                activity.description,
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNotesList(LeadModel lead) {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseService.getNotesStream(lead.id),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text("No notes for this lead"));
              }

              final notes = snapshot.data!.docs
                  .map((doc) => NoteModel.fromFirestore(doc))
                  .toList();

              return ListView.builder(
                padding: const EdgeInsets.only(top: 16),
                itemCount: notes.length,
                itemBuilder: (context, index) {
                  final note = notes[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(note.note, style: const TextStyle(fontSize: 15)),
                          const SizedBox(height: 8),
                          Text(
                            DateFormat('MMM d, h:mm a').format(note.createdAt),
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showAddNoteDialog(BuildContext context, String leadId) {
    _noteController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Add Note"),
        content: TextField(
          controller: _noteController,
          maxLines: 3,
          decoration: const InputDecoration(hintText: "Enter note details..."),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              if (_noteController.text.isNotEmpty) {
                context.read<LeadProvider>().addNote(
                  leadId,
                  _noteController.text,
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

  void _showWhatsAppSelectionDialog(
    BuildContext context,
    String phone,
    String leadId,
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
              provider.recordWhatsAppActivity(leadId);
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
              provider.recordWhatsAppActivity(leadId);
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'New Inquiry':
        return Colors.blue;
      case 'Contacted':
        return Colors.orange;
      case 'Interested':
        return Colors.purple;
      case 'Demo Scheduled':
        return Colors.teal;
      case 'Converted':
        return Colors.green;
      case 'Not Interested':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
