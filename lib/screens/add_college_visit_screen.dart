import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_constants.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/location_autocomplete.dart';
import '../widgets/college_autocomplete.dart';
import '../services/firebase_service.dart';
import '../services/notification_service.dart';
import '../providers/auth_provider.dart';
import '../utils/validation_utils.dart';

class AddCollegeVisitScreen extends StatefulWidget {
  const AddCollegeVisitScreen({super.key});

  @override
  State<AddCollegeVisitScreen> createState() => _AddCollegeVisitScreenState();
}

class _AddCollegeVisitScreenState extends State<AddCollegeVisitScreen> {
  final _formKey = GlobalKey<FormState>();
  final _collegeNameController = TextEditingController();
  final _locationController = TextEditingController();
  final _contactPersonController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _purposeController = TextEditingController();
  final _feedbackController = TextEditingController();

  DateTime? _visitDate;
  DateTime? _followUpDate;
  String _status = 'pending';
  bool _isLoading = false;
  String? _error;

  final List<String> _statusOptions = [
    'pending',
    'completed',
    'cancelled',
    'followup',
  ];

  @override
  void dispose() {
    _collegeNameController.dispose();
    _locationController.dispose();
    _contactPersonController.dispose();
    _contactPhoneController.dispose();
    _purposeController.dispose();
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isVisitDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        if (isVisitDate) {
          _visitDate = picked;
        } else {
          _followUpDate = picked;
        }
      });
    }
  }

  String? _validateCollegeName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter college name';
    }
    if (value.trim().length < 3) {
      return 'College name must be at least 3 characters';
    }
    if (value.trim().length > 100) {
      return 'College name must be less than 100 characters';
    }
    return null;
  }

  String? _validateLocation(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter location';
    }
    if (value.trim().length < 3) {
      return 'Location must be at least 3 characters';
    }
    return null;
  }

  String? _validateContactPerson(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter contact person name';
    }
    if (value.trim().length < 2) {
      return 'Contact person name must be at least 2 characters';
    }
    if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value.trim())) {
      return 'Contact person name can only contain letters and spaces';
    }
    return null;
  }

  String? _validateContactPhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter contact phone number';
    }
    // Remove all non-digit characters for validation
    final digitsOnly = value.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.length < 10) {
      return 'Phone number must be at least 10 digits';
    }
    if (digitsOnly.length > 15) {
      return 'Phone number must be less than 15 digits';
    }
    return null;
  }

  String? _validatePurpose(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter visit purpose';
    }
    if (value.trim().length < 10) {
      return 'Purpose must be at least 10 characters';
    }
    if (value.trim().length > 500) {
      return 'Purpose must be less than 500 characters';
    }
    return null;
  }

  String? _validateVisitDate() {
    if (_visitDate == null) {
      return 'Please select visit date';
    }
    if (_visitDate!.isBefore(
      DateTime.now().subtract(const Duration(days: 1)),
    )) {
      return 'Visit date cannot be in the past';
    }
    return null;
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    // Additional validation for dates
    final visitDateError = _validateVisitDate();
    if (visitDateError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(visitDateError),
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

      final visitData = {
        'collegeName': _collegeNameController.text.trim(),
        'location': _locationController.text.trim(),
        'contactPerson': _contactPersonController.text.trim(),
        'contactPhone': _contactPhoneController.text.trim(),
        'purpose': _purposeController.text.trim(),
        'feedback': _feedbackController.text.trim(),
        'status': _status,
        'visitDate': _visitDate != null
            ? Timestamp.fromDate(_visitDate!)
            : null,
        'followUpDate': _followUpDate != null
            ? Timestamp.fromDate(_followUpDate!)
            : null,
        'createdBy': currentUser.id,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final result = await FirebaseService.addCollegeVisit(visitData);

      if (result != null) {
        // Schedule notifications for the college visit
        if (_visitDate != null) {
          // await NotificationService().scheduleCollegeVisitReminder(...) // Fixed undefined method
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('College visit added successfully!'),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.of(context).pop(true);
        }
      } else {
        throw Exception('Failed to add college visit');
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
        title: const Text('Add College Visit'),
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
                // College Name with Autocomplete
                CollegeAutocomplete(
                  controller: _collegeNameController,
                  labelText: 'College Name',
                  hintText: 'Enter college name',
                  prefixIcon: Icons.school,
                  validator: _validateCollegeName,
                ),
                const SizedBox(height: AppSizes.paddingM),

                // Location with Autocomplete
                LocationAutocomplete(
                  controller: _locationController,
                  labelText: 'Location',
                  hintText: 'Enter location',
                  prefixIcon: Icons.location_on,
                  validator: _validateLocation,
                ),
                const SizedBox(height: AppSizes.paddingM),

                // Contact Person
                CustomTextField(
                  controller: _contactPersonController,
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

                // Purpose
                CustomTextField(
                  controller: _purposeController,
                  labelText: 'Purpose',
                  hintText: 'Enter visit purpose',
                  prefixIcon: Icons.assignment,
                  maxLines: 3,
                  validator: _validatePurpose,
                ),
                const SizedBox(height: AppSizes.paddingM),

                // Visit Date
                InkWell(
                  onTap: () => _selectDate(context, true),
                  child: Container(
                    padding: const EdgeInsets.all(AppSizes.paddingM),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppSizes.radiusM),
                      border: Border.all(
                        color: _visitDate == null
                            ? AppColors.error
                            : AppColors.textSecondary,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          color: _visitDate == null
                              ? AppColors.error
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: AppSizes.paddingM),
                        Expanded(
                          child: Text(
                            _visitDate != null
                                ? '${_visitDate!.day}/${_visitDate!.month}/${_visitDate!.year}'
                                : 'Select Visit Date *',
                            style: TextStyle(
                              color: _visitDate == null
                                  ? AppColors.error
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_visitDate == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0, left: 12.0),
                    child: Text(
                      'Please select visit date',
                      style: TextStyle(color: AppColors.error, fontSize: 12),
                    ),
                  ),
                const SizedBox(height: AppSizes.paddingM),

                // Follow-up Date
                InkWell(
                  onTap: () => _selectDate(context, false),
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
                                : 'Select Follow-up Date (Optional)',
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

                // Feedback
                CustomTextField(
                  controller: _feedbackController,
                  labelText: 'Feedback',
                  hintText: 'Enter visit feedback (Optional)',
                  prefixIcon: Icons.feedback,
                  maxLines: 4,
                ),
                const SizedBox(height: AppSizes.paddingL),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: CustomButton(
                    text: _isLoading ? 'Adding...' : 'Add College Visit',
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
