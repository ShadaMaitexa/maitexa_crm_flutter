import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_constants.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import '../services/firebase_service.dart';
import '../providers/auth_provider.dart';

class UpdateEnquiryStatusScreen extends StatefulWidget {
  final Map<String, dynamic> enquiry;

  const UpdateEnquiryStatusScreen({super.key, required this.enquiry});

  @override
  State<UpdateEnquiryStatusScreen> createState() =>
      _UpdateEnquiryStatusScreenState();
}

class _UpdateEnquiryStatusScreenState extends State<UpdateEnquiryStatusScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();

  String _status = 'new';
  bool _isLoading = false;
  String? _error;

  final List<String> _statusOptions = [
    'new',
    'contacted',
    'interested',
    'not_interested',
    'Converted',
  ];

  @override
  void initState() {
    super.initState();
    _status = widget.enquiry['status'] ?? 'new';
    _notesController.text = widget.enquiry['notes'] ?? '';
  }

  @override
  void dispose() {
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

      final updateData = {
        'status': _status,
        'notes': _notesController.text.trim(),
        'updatedBy': currentUser.id,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final result = await FirebaseService.updateEnquiry(
        widget.enquiry['id'],
        updateData,
      );

      if (result) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Enquiry status updated successfully!'),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.of(context).pop(true);
        }
      } else {
        throw Exception('Failed to update enquiry status');
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
    final enquiry = widget.enquiry;
    final name = enquiry['name'] ?? 'Name';
    final phone = enquiry['phone'] ?? 'Phone';
    final email = enquiry['email'] ?? 'Email';
    final college = enquiry['college'] ?? 'College';
    final course = enquiry['course'] ?? 'Course';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Update Enquiry Status'),
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
                // Enquiry Details Card
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
                        'Enquiry Details',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppSizes.paddingM),

                      // Name
                      _buildDetailRow('Name', name, Icons.person),
                      const SizedBox(height: AppSizes.paddingS),

                      // Phone
                      _buildDetailRow('Phone', phone, Icons.phone),
                      const SizedBox(height: AppSizes.paddingS),

                      // Email
                      _buildDetailRow('Email', email, Icons.email),
                      const SizedBox(height: AppSizes.paddingS),

                      // College
                      _buildDetailRow('College', college, Icons.school),
                      const SizedBox(height: AppSizes.paddingS),

                      // Course
                      _buildDetailRow('Course', course, Icons.book),
                    ],
                  ),
                ),

                const SizedBox(height: AppSizes.paddingXL),

                // Status Update Section
                const Text(
                  'Update Status',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSizes.paddingM),

                // Status Dropdown
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
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: _getStatusColor(status),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(status.replaceAll('_', ' ').toUpperCase()),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _status = newValue!;
                    });
                  },
                ),

                const SizedBox(height: AppSizes.paddingL),

                // Notes
                CustomTextField(
                  controller: _notesController,
                  labelText: 'Notes',
                  hintText: 'Add any additional notes or comments',
                  prefixIcon: Icons.note,
                  maxLines: 4,
                ),

                const SizedBox(height: AppSizes.paddingXL),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: CustomButton(
                    text: _isLoading ? 'Updating...' : 'Update Status',
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
