import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_constants.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import '../services/firebase_service.dart';
import '../providers/auth_provider.dart';
import '../utils/validation_utils.dart';

class AddEnquiryScreen extends StatefulWidget {
  const AddEnquiryScreen({super.key});

  @override
  State<AddEnquiryScreen> createState() => _AddEnquiryScreenState();
}

class _AddEnquiryScreenState extends State<AddEnquiryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _collegeController = TextEditingController();
  final _courseController = TextEditingController();
  final _notesController = TextEditingController();

  String _source = 'phone';
  String _status = 'new';
  bool _isLoading = false;
  String? _error;

  final List<String> _sourceOptions = [
    'phone',
    'website',
    'walk-in',
    'referral',
    'social_media',
    'whatsapp_campaign',
  ];
  final List<String> _statusOptions = [
    'new',
    'contacted',
    'interested',
    'not_interested',
    'converted',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _collegeController.dispose();
    _courseController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

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

      final enquiryData = {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'college': _collegeController.text.trim(),
        'course': _courseController.text.trim(),
        'notes': _notesController.text.trim(),
        'source': _source,
        'status': _status,
        'createdBy': currentUser.id,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final result = await FirebaseService.addEnquiry(enquiryData);

      if (result != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Enquiry added successfully!'),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.of(context).pop(true);
        }
      } else {
        throw Exception('Failed to add enquiry');
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
        title: const Text('Add Enquiry'),
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
                // Name
                CustomTextField(
                  controller: _nameController,
                  labelText: 'Name',
                  hintText: 'Enter full name',
                  prefixIcon: Icons.person,
                  inputFormatters: [ValidationUtils.getNameFormatter()],
                  validator: (value) =>
                      ValidationUtils.validateName(value, fieldName: 'Name'),
                ),
                const SizedBox(height: AppSizes.paddingM),

                // Phone
                CustomTextField(
                  controller: _phoneController,
                  labelText: 'Phone',
                  hintText: 'Enter phone number',
                  prefixIcon: Icons.phone,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [ValidationUtils.getPhoneNumberFormatter()],
                  validator: ValidationUtils.validatePhoneNumber,
                ),
                const SizedBox(height: AppSizes.paddingM),

                // Email
                CustomTextField(
                  controller: _emailController,
                  labelText: 'Email',
                  hintText: 'Enter email address (Optional)',
                  prefixIcon: Icons.email,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return null; // optional
                    }
                    return ValidationUtils.validateEmail(value);
                  },
                ),
                const SizedBox(height: AppSizes.paddingM),

                // College
                CustomTextField(
                  controller: _collegeController,
                  labelText: 'College/Institution',
                  hintText: 'Enter college or institution name',
                  prefixIcon: Icons.school,
                  inputFormatters: [
                    ValidationUtils.getAlphanumericWithSpacesFormatter(),
                  ],
                  validator: (value) => ValidationUtils.validateMinLength(
                    value,
                    3,
                    fieldName: 'College/Institution',
                  ),
                ),
                const SizedBox(height: AppSizes.paddingM),

                // Course
                CustomTextField(
                  controller: _courseController,
                  labelText: 'Course Interest',
                  hintText: 'Enter course of interest',
                  prefixIcon: Icons.book,
                  inputFormatters: [
                    ValidationUtils.getAlphanumericWithSpacesFormatter(),
                  ],
                  validator: (value) => ValidationUtils.validateMinLength(
                    value,
                    2,
                    fieldName: 'Course Interest',
                  ),
                ),
                const SizedBox(height: AppSizes.paddingM),

                // Source
                DropdownButtonFormField<String>(
                  value: _source,
                  decoration: const InputDecoration(
                    labelText: 'Source',
                    prefixIcon: Icon(Icons.source),
                    border: OutlineInputBorder(),
                  ),
                  items: _sourceOptions.map((String source) {
                    return DropdownMenuItem<String>(
                      value: source,
                      child: Text(source.replaceAll('_', ' ').toUpperCase()),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _source = newValue!;
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
                      child: Text(status.replaceAll('_', ' ').toUpperCase()),
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
                  hintText: 'Enter additional notes (Optional)',
                  prefixIcon: Icons.note,
                  maxLines: 4,
                ),
                const SizedBox(height: AppSizes.paddingL),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: CustomButton(
                    text: _isLoading ? 'Adding...' : 'Add Enquiry',
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
