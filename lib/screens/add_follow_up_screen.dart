import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_constants.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import '../services/firebase_service.dart';
import '../providers/auth_provider.dart';
import '../utils/validation_utils.dart';

class AddFollowUpScreen extends StatefulWidget {
  final String? phoneNumber;
  final String? contactName;
  final String? callId;
  const AddFollowUpScreen({super.key, this.phoneNumber, this.contactName, this.callId});

  @override
  State<AddFollowUpScreen> createState() => _AddFollowUpScreenState();
}

class _AddFollowUpScreenState extends State<AddFollowUpScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _contactNameController;
  late final TextEditingController _contactPhoneController;
  final _notesController = TextEditingController();
  final _outcomeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _contactNameController = TextEditingController(
      text: widget.contactName ?? '',
    );
    _contactPhoneController = TextEditingController(
      text: widget.phoneNumber ?? '',
    );
  }

  DateTime? _followUpDate;
  String _status = 'pending';
  String _priority = 'medium';
  bool _isLoading = false;
  String? _error;

  final List<String> _statusOptions = [
    'pending',
    'completed',
    'cancelled',
    'rescheduled',
  ];
  final List<String> _priorityOptions = ['low', 'medium', 'high'];

  @override
  void dispose() {
    _contactNameController.dispose();
    _contactPhoneController.dispose();
    _notesController.dispose();
    _outcomeController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _followUpDate = picked;
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_followUpDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a follow-up date'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUser = authProvider.user;

      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Normalize phone number to +91XXXXXXXXXX
      String contactPhone = _contactPhoneController.text.trim().replaceAll(RegExp(r'[^\d]'), '');
      if (contactPhone.length == 10) {
        contactPhone = '+91$contactPhone';
      } else if (contactPhone.length == 12 && contactPhone.startsWith('91')) {
        contactPhone = '+$contactPhone';
      }

      final followUpData = {
        'contactName': _contactNameController.text.trim(),
        'contactPhone': contactPhone, // Use normalized phone
        'notes': _notesController.text.trim(),
        'outcome': _outcomeController.text.trim(),
        'status': _status,
        'priority': _priority,
        'followUpDate': Timestamp.fromDate(_followUpDate!),
        'createdBy': currentUser.id,
        'callerName': currentUser.name, // Intel redundancy
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'call_id': widget.callId,
      };

      // 1. Add to the main collection
      final result = await FirebaseService.addFollowUp(followUpData);

      // 2. If it came from a call, also link it in the call document!
      if (widget.callId != null) {
        await FirebaseService.addFollowUpToCall(widget.callId!, followUpData);
      }

      if (result != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Follow-up scheduled and linked!'),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.of(context).pop(true);
        }
      } else {
        throw Exception('Failed to schedule');
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Add Follow-up'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSizes.paddingL),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Contact Name
                CustomTextField(
                  controller: _contactNameController,
                  labelText: 'Contact Name',
                  hintText: 'Enter contact name',
                  prefixIcon: Icons.person,
                  inputFormatters: [ValidationUtils.getNameFormatter()],
                  validator: (value) => ValidationUtils.validateName(
                    value,
                    fieldName: 'Contact Name',
                  ),
                ),
                const SizedBox(height: AppSizes.paddingM),

                // Contact Phone
                CustomTextField(
                  controller: _contactPhoneController,
                  labelText: 'Contact Phone',
                  hintText: 'Enter contact phone number',
                  prefixIcon: Icons.phone,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [ValidationUtils.getPhoneNumberFormatter()],
                  validator: ValidationUtils.validatePhoneNumber,
                ),
                const SizedBox(height: AppSizes.paddingM),

                // Follow-up Date
                InkWell(
                  onTap: () => _selectDate(context),
                  child: Container(
                    padding: const EdgeInsets.all(AppSizes.paddingM),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppSizes.radiusM),
                      border: Border.all(color: AppColors.textSecondary),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: AppSizes.paddingM),
                        Expanded(
                          child: Text(
                            _followUpDate != null
                                ? '${_followUpDate!.day}/${_followUpDate!.month}/${_followUpDate!.year}'
                                : 'Select Follow-up Date',
                            style: TextStyle(
                              color: _followUpDate != null
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.paddingM),

                // Priority
                DropdownButtonFormField<String>(
                  value: _priority,
                  decoration: const InputDecoration(
                    labelText: 'Priority',
                    prefixIcon: Icon(Icons.priority_high),
                    border: OutlineInputBorder(),
                  ),
                  items: _priorityOptions.map((String priority) {
                    return DropdownMenuItem<String>(
                      value: priority,
                      child: Text(priority.toUpperCase()),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _priority = newValue!;
                    });
                  },
                ),
                const SizedBox(height: AppSizes.paddingM),

                // Status
                DropdownButtonFormField<String>(
                  value: _status,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    prefixIcon: Icon(Icons.flag),
                    border: OutlineInputBorder(),
                  ),
                  items: _statusOptions.map((String status) {
                    return DropdownMenuItem<String>(
                      value: status,
                      child: Text(status.toUpperCase()),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _status = newValue!;
                    });
                  },
                ),
                const SizedBox(height: AppSizes.paddingM),

                // Notes
                CustomTextField(
                  controller: _notesController,
                  labelText: 'Notes',
                  hintText: 'Enter follow-up notes',
                  prefixIcon: Icons.note,
                  maxLines: 4,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter follow-up notes';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSizes.paddingM),

                // Outcome
                CustomTextField(
                  controller: _outcomeController,
                  labelText: 'Outcome',
                  hintText: 'Enter follow-up outcome (Optional)',
                  prefixIcon: Icons.outlined_flag,
                  maxLines: 3,
                ),
                const SizedBox(height: AppSizes.paddingL),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: CustomButton(
                    text: _isLoading ? 'Adding...' : 'Add Follow-up',
                    onPressed: _isLoading ? null : _submitForm,
                    isLoading: _isLoading,
                  ),
                ),

                if (_error != null) ...[
                  const SizedBox(height: AppSizes.paddingM),
                  Container(
                    padding: const EdgeInsets.all(AppSizes.paddingM),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppSizes.radiusM),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
