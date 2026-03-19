import 'package:flutter/material.dart';
import 'package:call_log/call_log.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_constants.dart';
import '../services/firebase_service.dart';
import '../providers/lead_provider.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import 'add_follow_up_screen.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class CallLogDetailScreen extends StatefulWidget {
  final CallLogEntry callEntry;

  const CallLogDetailScreen({super.key, required this.callEntry});

  @override
  State<CallLogDetailScreen> createState() => _CallLogDetailScreenState();
}

class _CallLogDetailScreenState extends State<CallLogDetailScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  String? _selectedLabel;
  String? _currentCallId;
  bool _isSaving = false;
  bool _isSavingNote = false;

  // Default labels (same as in todays_calls_screen.dart)
  final List<String> _defaultLabels = [
    'Devagiri College',
    'St Joseph College',
    'Providence College',
    'Hot Deals',
    'Follow Up',
    'Unknown',
  ];

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.callEntry.name ?? '';
    _loadExistingLabel();
  }

  Future<void> _loadExistingLabel() async {
    if (widget.callEntry.number != null) {
      final label = await FirebaseService.getNumberCategory(
        widget.callEntry.number!,
      );
      if (label != null && mounted) {
        setState(() {
          _selectedLabel = label;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    if (widget.callEntry.number == null) return;

    setState(() {
      _isSaving = true;
    });

    try {
      // Save the name to Firebase
      await FirebaseService.setNumberCategory(
        widget.callEntry.number!,
        _selectedLabel ?? 'Unknown',
      );

      // Record the call with the name
      _currentCallId = await FirebaseService.recordCall({
        'number': widget.callEntry.number,
        'name': _nameController.text.trim().isNotEmpty
            ? _nameController.text.trim()
            : widget.callEntry.name,
        'duration': widget.callEntry.duration,
        'timestamp': widget.callEntry.timestamp,
        'type': widget.callEntry.callType.toString(),
        'label': _selectedLabel,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Name saved successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _saveLabel(String label) async {
    if (widget.callEntry.number == null) return;

    setState(() {
      _selectedLabel = label;
    });

    await FirebaseService.setNumberCategory(widget.callEntry.number!, label);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Label set to: $label'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _saveNote() async {
    if (_noteController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a note'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    if (widget.callEntry.number == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot save note: phone number is unavailable'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSavingNote = true);

    try {
      // Normalize number
      String number = widget.callEntry.number!.replaceAll(RegExp(r'\s+'), '');
      if (number.length == 10) number = '+91$number';
      
      final String callDocId = '${number}_${widget.callEntry.timestamp}';

      await FirebaseService.addPhoneNote(
        number,
        _noteController.text.trim(),
        callId: callDocId,
      );
      _noteController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Note saved successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving note: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingNote = false);
    }
  }

  void _navigateToScheduleFollowUp() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddFollowUpScreen(
          phoneNumber: widget.callEntry.number,
          contactName: _nameController.text.trim().isNotEmpty
              ? _nameController.text.trim()
              : widget.callEntry.name,
          callId: _currentCallId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final call = widget.callEntry;
    final date = DateTime.fromMillisecondsSinceEpoch(call.timestamp ?? 0);
    final durationStr = call.duration != null
        ? '${(call.duration! / 60).floor()}m ${call.duration! % 60}s'
        : '0s';

    final leadProvider = Provider.of<LeadProvider>(context, listen: false);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Call Details'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.paddingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Call Info Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusM),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.paddingL),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: _getCallTypeColor(
                        call.callType,
                      ).withOpacity(0.1),
                      child: Icon(
                        _getCallTypeIcon(call.callType),
                        color: _getCallTypeColor(call.callType),
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _nameController.text.isNotEmpty
                          ? _nameController.text
                          : call.number ?? 'Unknown',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (call.number != null)
                      Text(
                        call.number!,
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('MMM d, yyyy h:mm a').format(date),
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        const SizedBox(width: 16),
                        Icon(
                          Icons.timer,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          durationStr,
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    if (_selectedLabel != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _selectedLabel!,
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Quick Actions
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon: Icons.call,
                    label: 'Call',
                    color: Colors.green,
                    onTap: () => leadProvider.launchCall(call.number!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionButton(
                    icon: FontAwesomeIcons.whatsapp,
                    label: 'WhatsApp',
                    color: const Color(0xFF25D366),
                    onTap: () => _showWhatsAppSelectionDialog(
                      call.number!,
                      leadProvider,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Add/Save Name Section
            const Text(
              'Add/Save Name',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    controller: _nameController,
                    hintText: 'Enter contact name',
                    prefixIcon: Icons.person,
                  ),
                ),
                const SizedBox(width: 12),
                CustomButton(
                  onPressed: _isSaving ? null : _saveName,
                  text: _isSaving ? 'Saving...' : 'Save',
                  isLoading: _isSaving,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Add Label Section
            const Text(
              'Add Label',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot>(
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

                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: labels.map((label) {
                    final isSelected = _selectedLabel == label;
                    return ChoiceChip(
                      label: Text(label),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          _saveLabel(label);
                        }
                      },
                      selectedColor: AppColors.primary.withOpacity(0.2),
                      labelStyle: TextStyle(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textPrimary,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    );
                  }).toList(),
                );
              },
            ),

            const SizedBox(height: 24),

            // Add Note Section
            const Text(
              'Add Note',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            CustomTextField(
              controller: _noteController,
              hintText: 'Enter note about this call...',
              prefixIcon: Icons.note,
              maxLines: 4,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: CustomButton(
                onPressed: _isSavingNote ? null : _saveNote,
                text: _isSavingNote ? 'Saving...' : 'Save Note',
                isLoading: _isSavingNote,
              ),
            ),

            const SizedBox(height: 16),

            // Saved Notes List
            if (widget.callEntry.number != null)
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseService.getPhoneNotesStream(
                  widget.callEntry.number!,
                ),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  final docs = List.from(snapshot.data!.docs)
                    ..sort((a, b) {
                      final aTs = (a.data()
                          as Map<String, dynamic>)['created_at'] as Timestamp?;
                      final bTs = (b.data()
                          as Map<String, dynamic>)['created_at'] as Timestamp?;
                      if (aTs == null && bTs == null) return 0;
                      if (aTs == null) return 1;
                      if (bTs == null) return -1;
                      return bTs.compareTo(aTs); // newest first
                    });
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Saved Notes',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...docs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final noteText = data['note'] as String? ?? '';
                        final createdAt =
                            (data['created_at'] as Timestamp?)?.toDate();
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.note_alt_outlined,
                                      size: 16,
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        noteText,
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ),
                                  ],
                                ),
                                if (createdAt != null) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    DateFormat('MMM d, yyyy h:mm a').format(
                                      createdAt,
                                    ),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  );
                },
              ),

            const SizedBox(height: 24),

            // Schedule Follow-up Section
            const Text(
              'Schedule Follow-up',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _navigateToScheduleFollowUp,
                icon: const Icon(Icons.calendar_today),
                label: const Text('Schedule Follow-up'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  foregroundColor: Colors.orange,
                  side: const BorderSide(color: Colors.orange),
                ),
              ),
            ),
          ],
        ),
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

  void _showWhatsAppSelectionDialog(String phone, LeadProvider provider) {
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
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusM),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppSizes.radiusM),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
