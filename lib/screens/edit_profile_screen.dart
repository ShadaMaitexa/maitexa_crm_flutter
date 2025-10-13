import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../constants/app_constants.dart';
import '../widgets/custom_button.dart';
import 'package:cloudinary/cloudinary.dart';
import '../widgets/custom_text_field.dart';
import '../services/firebase_service.dart';
import '../utils/validation_utils.dart';
import '../providers/auth_provider.dart';
import '../models/user_model.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _organizationController = TextEditingController();

  File? _selectedImage;
  String? _imageUrl;
  bool _isLoading = false;
  bool _isUploadingImage = false;
  String? _error;

  // Cloudinary configuration
  final cloudinary = Cloudinary.signedConfig(
    apiKey: '459459889672212', // Replace with your Cloudinary API key
    apiSecret:
        'WoPZkbeNXlsWMTWuMhsrtOelj2Y', // Replace with your Cloudinary API secret
    cloudName: 'dpfhr81ee', // Your Cloudinary cloud name
  );

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _organizationController.dispose();
    super.dispose();
  }

  void _loadUserData() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;

    if (user != null) {
      _nameController.text = user.name;
      _emailController.text = user.email;
      _phoneController.text = user.phone;
      _organizationController.text = user.organization;
      _imageUrl = user.avatar;
    }
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _isUploadingImage = true;
        });

        // Upload to Cloudinary
        await _uploadImageToCloudinary();
      }
    } catch (e) {
      setState(() {
        _error = 'Error picking image: $e';
        _isUploadingImage = false;
      });
    }
  }

  Future<void> _uploadImageToCloudinary() async {
    try {
      if (_selectedImage == null) return;

      final response = await cloudinary.upload(
        file: _selectedImage!.path,
        fileBytes: await _selectedImage!.readAsBytes(),
        resourceType: CloudinaryResourceType.image,
        folder: 'crm_images',
        fileName: 'profile_${DateTime.now().millisecondsSinceEpoch}',
      );

      setState(() {
        _imageUrl = response.secureUrl;
        _isUploadingImage = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error uploading image: $e';
        _isUploadingImage = false;
      });
    }
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
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'organization': _organizationController.text.trim(),
        'avatar': _imageUrl ?? currentUser.avatar,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      final result = await FirebaseService.updateUser(
        currentUser.id,
        updateData,
      );

      if (result) {
        // Update the user in AuthProvider
        final updatedUser = User(
          id: currentUser.id,
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          phone: _phoneController.text.trim(),
          organization: _organizationController.text.trim(),
          avatar: _imageUrl ?? currentUser.avatar,
          role: currentUser.role,
          isActive: currentUser.isActive,
          createdAt: currentUser.createdAt,
          lastLogin: currentUser.lastLogin,
        );

        authProvider.updateUser(updatedUser);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully!'),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.of(context).pop(true);
        }
      } else {
        throw Exception('Failed to update profile');
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
        title: const Text('Edit Profile'),
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
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Profile Image Section
                Center(
                  child: Stack(
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primary,
                            width: 3,
                          ),
                        ),
                        child: ClipOval(
                          child: _isUploadingImage
                              ? Container(
                                  color: AppColors.surface,
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                )
                              : _selectedImage != null
                              ? Image.file(_selectedImage!, fit: BoxFit.cover)
                              : _imageUrl != null && _imageUrl!.isNotEmpty
                              ? Image.network(
                                  _imageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: AppColors.surface,
                                      child: Icon(
                                        Icons.person,
                                        size: 60,
                                        color: AppColors.textSecondary,
                                      ),
                                    );
                                  },
                                )
                              : Container(
                                  color: AppColors.surface,
                                  child: Icon(
                                    Icons.person,
                                    size: 60,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.background,
                              width: 2,
                            ),
                          ),
                          child: IconButton(
                            onPressed: _isUploadingImage ? null : _pickImage,
                            icon: const Icon(
                              Icons.camera_alt,
                              color: AppColors.textInverse,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSizes.paddingXL),

                // Form Fields
                CustomTextField(
                  controller: _nameController,
                  labelText: 'Full Name',
                  hintText: 'Enter your full name',
                  prefixIcon: Icons.person,
                  inputFormatters: [ValidationUtils.getNameFormatter()],
                  validator: (value) => ValidationUtils.validateName(value, fieldName: 'Full Name'),
                ),
                const SizedBox(height: AppSizes.paddingM),

                CustomTextField(
                  controller: _emailController,
                  labelText: 'Email',
                  hintText: 'Enter your email address',
                  prefixIcon: Icons.email,
                  keyboardType: TextInputType.emailAddress,
                  validator: ValidationUtils.validateEmail,
                ),
                const SizedBox(height: AppSizes.paddingM),

                CustomTextField(
                  controller: _phoneController,
                  labelText: 'Phone',
                  hintText: 'Enter your phone number',
                  prefixIcon: Icons.phone,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [ValidationUtils.getPhoneNumberFormatter()],
                  validator: ValidationUtils.validatePhoneNumber,
                ),
                const SizedBox(height: AppSizes.paddingM),

                CustomTextField(
                  controller: _organizationController,
                  labelText: 'Organization',
                  hintText: 'Enter your organization name',
                  prefixIcon: Icons.business,
                  inputFormatters: [ValidationUtils.getAlphanumericWithSpacesFormatter()],
                  validator: (value) => ValidationUtils.validateMinLength(value, 2, fieldName: 'Organization'),
                ),

                const SizedBox(height: AppSizes.paddingXL),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: CustomButton(
                    text: _isLoading ? 'Updating...' : 'Update Profile',
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
}
