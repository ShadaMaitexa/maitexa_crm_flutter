import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_constants.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import '../services/firebase_service.dart';
import '../providers/auth_provider.dart';
import '../utils/validation_utils.dart';

class ScheduleFollowUpScreen extends StatefulWidget {
  final Map<String, dynamic> collegeVisit;

  const ScheduleFollowUpScreen({super.key, required this.collegeVisit});

  @override
  State<ScheduleFollowUpScreen> createState() => _ScheduleFollowUpScreenState();
}

class _ScheduleFollowUpScreenState extends State<ScheduleFollowUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _contactNameController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime? _followUpDate;
  TimeOfDay? _followUpTime;
  String _status = 'pending';
  bool _isLoading = false;
  String? _error;

  final List<String> _statusOptions = [
    'pending',
    'scheduled',
    'completed',
    'cancelled',
  ];

  @override
  void initState() {
    super.initState();
    // Pre-fill contact details from college visit
    _contactNameController.text = widget.collegeVisit['contactPerson'] ?? '';
    _contactPhoneController.text = widget.collegeVisit['contactPhone'] ?? '';
  }

  @override
  void dispose() {
    _contactNameController.dispose();
    _contactPhoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _followUpDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _followUpDate) {
      setState(() {
        _followUpDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _followUpTime ?? TimeOfDay.now(),
    );
    if (picked != null && picked != _followUpTime) {
      setState(() {
        _followUpTime = picked;
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_followUpDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a follow-up date'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_followUpTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a follow-up time'),
          backgroundColor: AppColors.error,
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

      // Combine date and time
      final followUpDateTime = DateTime(
        _followUpDate!.year,
        _followUpDate!.month,
        _followUpDate!.day,
        _followUpTime!.hour,
        _followUpTime!.minute,
      );

      final followUpData = {
        'contactName': _contactNameController.text.trim(),
        'contactPhone': _contactPhoneController.text.trim(),
        'notes': _notesController.text.trim(),
        'status': _status,
        'followUpDate': Timestamp.fromDate(followUpDateTime),
        'collegeVisitId': widget.collegeVisit['id'],
        'collegeName': widget.collegeVisit['collegeName'],
        'createdBy': currentUser.id,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final result = await FirebaseService.addFollowUp(followUpData);

      if (result != null) {
        // Also update the college visit with follow-up date
        await FirebaseService.updateCollegeVisit(widget.collegeVisit['id'], {
          'followUpDate': Timestamp.fromDate(followUpDateTime),
          'status': 'followup',
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Follow-up scheduled successfully!'),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.of(context).pop(true);
        }
      } else {
        throw Exception('Failed to schedule follow-up');
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
    final collegeVisit = widget.collegeVisit;
    final collegeName = collegeVisit['collegeName'] ?? 'College Name';
    final location = collegeVisit['location'] ?? 'Location';
    final purpose = collegeVisit['purpose'] ?? 'Purpose';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Schedule Follow-up'),
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
                // College Visit Details Card
                Container(
                  width: double.infinity,
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
                      const Text(
                        'College Visit Details',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppSizes.paddingM),

                      // College Name
                      _buildDetailRow('College', collegeName, Icons.school),
                      const SizedBox(height: AppSizes.paddingS),

                      // Location
                      _buildDetailRow('Location', location, Icons.location_on),
                      const SizedBox(height: AppSizes.paddingS),

                      // Purpose
                      _buildDetailRow('Purpose', purpose, Icons.assignment),
                    ],
                  ),
                ),

                const SizedBox(height: AppSizes.paddingXL),

                // Follow-up Details Section
                const Text(
                  'Follow-up Details',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSizes.paddingM),

                // Contact Name
                CustomTextField(
                  controller: _contactNameController,
                  labelText: 'Contact Person',
                  hintText: 'Enter contact person name',
                  prefixIcon: Icons.person,
                  inputFormatters: [ValidationUtils.getNameFormatter()],
                  validator: (value) => ValidationUtils.validateName(
                    value,
                    fieldName: 'Contact Person',
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

                // Date and Time Selection
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _selectDate,
                        child: Container(
                          padding: const EdgeInsets.all(AppSizes.paddingM),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: AppColors.textSecondary.withOpacity(0.3),
                            ),
                            borderRadius: BorderRadius.circular(
                              AppSizes.radiusM,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.calendar_today,
                                    size: 16,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: AppSizes.paddingXS),
                                  Text(
                                    'Follow-up Date',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSizes.paddingXS),
                              Text(
                                _followUpDate != null
                                    ? '${_followUpDate!.day}/${_followUpDate!.month}/${_followUpDate!.year}'
                                    : 'Select Date',
                                style: TextStyle(
                                  color: _followUpDate != null
                                      ? AppColors.textPrimary
                                      : AppColors.textSecondary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSizes.paddingM),
                    Expanded(
                      child: InkWell(
                        onTap: _selectTime,
                        child: Container(
                          padding: const EdgeInsets.all(AppSizes.paddingM),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: AppColors.textSecondary.withOpacity(0.3),
                            ),
                            borderRadius: BorderRadius.circular(
                              AppSizes.radiusM,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.access_time,
                                    size: 16,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: AppSizes.paddingXS),
                                  Text(
                                    'Follow-up Time',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSizes.paddingXS),
                              Text(
                                _followUpTime != null
                                    ? '${_followUpTime!.hour.toString().padLeft(2, '0')}:${_followUpTime!.minute.toString().padLeft(2, '0')}'
                                    : 'Select Time',
                                style: TextStyle(
                                  color: _followUpTime != null
                                      ? AppColors.textPrimary
                                      : AppColors.textSecondary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
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
                  hintText: 'Add any notes or agenda for the follow-up',
                  prefixIcon: Icons.note,
                  maxLines: 4,
                ),

                const SizedBox(height: AppSizes.paddingXL),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: CustomButton(
                    text: _isLoading ? 'Scheduling...' : 'Schedule Follow-up',
                    onPressed: _isLoading ? null : _submitForm,
                    isLoading: _isLoading,
                  ),
                ),

                if (_error != null) ...[
                  const SizedBox(height: AppSizes.paddingM),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSizes.paddingM),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppSizes.radiusM),
                      border: Border.all(color: AppColors.error),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 14,
                      ),
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

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: AppSizes.paddingXS),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              Text(
                value,
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
    );
  }
}
