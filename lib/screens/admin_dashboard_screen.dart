import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firebase_service.dart';
import '../models/user_model.dart';
import '../models/role_model.dart';
import '../constants/app_constants.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import '../providers/auth_provider.dart';
import '../screens/splash_screen.dart';
import '../screens/role_management_screen.dart';
import '../utils/validation_utils.dart';
import 'admin_analytics_screen.dart';
import 'label_management_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  List<User> _users = [];
  bool _isLoading = false;
  String? _error;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final users = await FirebaseService.getAllUsers();
      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<User> get _filteredUsers {
    if (_searchQuery.isEmpty) return _users;
    return _users
        .where(
          (user) =>
              user.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              user.email.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              user.role.toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .toList();
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const SplashScreen()),
          (route) => false,
        );
      }
    }
  }

  Future<void> _addUser() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const AddUserDialog(),
    );

    if (result != null) {
      try {
        final userId = await FirebaseService.addUser(result);
        if (userId != null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('User added successfully')),
            );
            _loadUsers();
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Failed to add user')));
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  Future<void> _editUser(User user) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => EditUserDialog(user: user),
    );

    if (result != null) {
      try {
        final success = await FirebaseService.updateUser(user.id, result);
        if (success) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('User updated successfully')),
            );
            _loadUsers();
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to update user')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  Future<void> _deleteUser(User user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Are you sure you want to delete ${user.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final success = await FirebaseService.deleteUser(user.id);
        if (success) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('User deleted successfully')),
            );
            _loadUsers();
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to delete user')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  Future<void> _toggleUserStatus(User user) async {
    try {
      final success = await FirebaseService.toggleUserStatus(
        user.id,
        !user.isActive,
      );
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'User ${user.isActive ? 'deactivated' : 'activated'} successfully',
              ),
            ),
          );
          _loadUsers();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update user status')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Widget _buildUserManagementScreen(bool isTablet) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Error: $_error'),
                const SizedBox(height: 16),
                CustomButton(onPressed: _loadUsers, text: 'Retry'),
              ],
            ),
          )
        : Column(
            children: [
              // Header Section
              Container(
                padding: EdgeInsets.all(isTablet ? 24.0 : 16.0),
                child: Column(
                  children: [
                    // Search Bar
                    CustomSearchField(
                      controller: _searchController,
                      hintText: 'Search users...',
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                    ),
                    SizedBox(height: isTablet ? 24.0 : 16.0),
                    // Stats and Add Button
                    if (isTablet)
                      Row(
                        children: [
                          Expanded(
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  children: [
                                    Text(
                                      '${_filteredUsers.length}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineLarge
                                          ?.copyWith(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const Text(
                                      'Total Users',
                                      style: TextStyle(fontSize: 16),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: CustomButton(
                              onPressed: _addUser,
                              text: 'Add New User',
                            ),
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                children: [
                                  Text(
                                    '${_filteredUsers.length}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium
                                        ?.copyWith(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  const Text('Total Users'),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: CustomButton(
                              onPressed: _addUser,
                              text: 'Add New User',
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              // Users List
              Expanded(
                child: _filteredUsers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: isTablet ? 96 : 64,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isEmpty
                                  ? 'No users found'
                                  : 'No users match your search',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: isTablet ? 18 : 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.symmetric(
                          horizontal: isTablet ? 24.0 : 16.0,
                        ),
                        itemCount: _filteredUsers.length,
                        itemBuilder: (context, index) {
                          final user = _filteredUsers[index];
                          return _buildUserCard(user, isTablet);
                        },
                      ),
              ),
            ],
          );
  }

  Color _getRoleColor(String roleName) {
    switch (roleName.toLowerCase()) {
      case 'admin':
        return Colors.red;
      case 'hr':
        return Colors.blue;
      case 'marketing executive':
        return Colors.green;
      case 'manager':
        return Colors.orange;
      case 'supervisor':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Widget _buildUserCard(User user, bool isTablet) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          radius: isTablet ? 28 : 24,
          backgroundColor: user.isActive ? AppColors.primary : Colors.grey,
          child: Text(
            user.avatar,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: isTablet ? 16 : 14,
            ),
          ),
        ),
        title: Text(
          user.name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: isTablet ? 18 : 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user.email),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getRoleColor(user.role).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    user.role,
                    style: TextStyle(
                      color: _getRoleColor(user.role),
                      fontSize: isTablet ? 14 : 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: user.isActive
                        ? Colors.green.withOpacity(0.2)
                        : Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    user.isActive ? 'Active' : 'Inactive',
                    style: TextStyle(
                      color: user.isActive
                          ? Colors.green[700]
                          : Colors.red[700],
                      fontSize: isTablet ? 14 : 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [Icon(Icons.edit), SizedBox(width: 8), Text('Edit')],
              ),
            ),
            PopupMenuItem(
              value: 'toggle',
              child: Row(
                children: [
                  Icon(user.isActive ? Icons.block : Icons.check_circle),
                  const SizedBox(width: 8),
                  Text(user.isActive ? 'Deactivate' : 'Activate'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            switch (value) {
              case 'edit':
                _editUser(user);
                break;
              case 'toggle':
                _toggleUserStatus(user);
                break;
              case 'delete':
                _deleteUser(user);
                break;
            }
          },
        ),
      ),
    );
  }

  void _showAdminCredentials() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.admin_panel_settings, color: AppColors.primary),
            SizedBox(width: 10),
            Text('Admin Credentials'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Use these credentials to log in as admin:',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 16),
            _CredentialRow(label: 'Email', value: FirebaseService.adminEmail),
            const SizedBox(height: 8),
            _CredentialRow(label: 'Password', value: FirebaseService.adminPassword),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    final List<Widget> screens = [
      _buildUserManagementScreen(isTablet),
      const RoleManagementScreen(),
      const LabelManagementScreen(),
      const AdminAnalyticsScreen(),
    ];

    final titles = [
      'Staff Management',
      'System Roles',
      'Categorization',
      'Enterprise Insights',
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Modern off-white background
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'MAITEXA CRM',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 1.2,
                color: Colors.white,
              ),
            ),
            Text(
              titles[_currentIndex].toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                color: Colors.white.withOpacity(0.7),
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => _showAdminCredentials(),
            icon: const Icon(Icons.shield_outlined, size: 20),
            tooltip: 'Security Status',
          ),
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded, size: 20),
            tooltip: 'Secure Logout',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Global status summary banner (Dynamic based on DB state)
          if (_currentIndex == 0) _buildGlobalStatsBanner(isTablet),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
              ),
              child: IndexedStack(
                index: _currentIndex,
                children: screens,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.people_alt_outlined, Icons.people_alt, 'Staff'),
                _buildNavItem(1, Icons.verified_user_outlined, Icons.verified_user, 'Roles'),
                _buildNavItem(2, Icons.label_important_outline, Icons.label_important, 'Labels'),
                _buildNavItem(3, Icons.insights_outlined, Icons.insights, 'Insights'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData outline, IconData solid, String label) {
    bool isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? solid : outline,
              color: isSelected ? AppColors.primary : Colors.blueGrey.shade300,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.primary : Colors.blueGrey.shade300,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlobalStatsBanner(bool isTablet) {
    int activeCount = _users.where((u) => u.isActive).length;
    return Container(
      width: double.infinity,
      color: AppColors.primary,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
             _BannerStat(label: 'TOTAL STAFF', value: '${_users.length}'),
             _BannerStat(label: 'ACTIVE', value: '$activeCount'),
             _BannerStat(label: 'OFFLINE', value: '${_users.length - activeCount}'),
          ],
        ),
      ),
    );
  }
}

class _BannerStat extends StatelessWidget {
  final String label;
  final String value;
  const _BannerStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 9, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

/// Small helper widget to display a credential row
class _CredentialRow extends StatelessWidget {
  final String label;
  final String value;

  const _CredentialRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
                fontSize: 13),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class AddUserDialog extends StatefulWidget {
  const AddUserDialog({super.key});

  @override
  State<AddUserDialog> createState() => _AddUserDialogState();
}

class _AddUserDialogState extends State<AddUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  String _selectedRole = '';
  bool _isLoading = false;
  List<Role> _roles = [];
  bool _isLoadingRoles = true;

  @override
  void initState() {
    super.initState();
    _loadRoles();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadRoles() async {
    try {
      var roles = await FirebaseService.getAllRoles();
      // Seed defaults if no roles present
      if (roles.isEmpty) {
        await FirebaseService.initializeDefaultRoles();
        roles = await FirebaseService.getAllRoles();
      }

      // Build role names with fallback
      final roleNames = roles.isNotEmpty
          ? roles.map((r) => r.name).toList()
          : <String>[AppStrings.roleHR, AppStrings.roleMarketingExecutive];

      // Ensure selected value is in items
      String nextSelected = _selectedRole;
      if (!roleNames.contains(nextSelected)) {
        nextSelected = roleNames.isNotEmpty ? roleNames.first : '';
      }

      if (mounted) {
        setState(() {
          _roles = roles;
          _isLoadingRoles = false;
          _selectedRole = nextSelected;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingRoles = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return AlertDialog(
      title: const Text('Add New User'),
      content: SizedBox(
        width: isTablet ? 400 : double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomTextField(
                  controller: _nameController,
                  labelText: 'Full Name',
                  inputFormatters: [ValidationUtils.getNameFormatter()],
                  validator: (value) => ValidationUtils.validateName(
                    value,
                    fieldName: 'Full Name',
                  ),
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _emailController,
                  labelText: 'Email Address',
                  keyboardType: TextInputType.emailAddress,
                  validator: ValidationUtils.validateEmail,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _phoneController,
                  labelText: 'Phone Number',
                  keyboardType: TextInputType.phone,
                  inputFormatters: [ValidationUtils.getPhoneNumberFormatter()],
                  validator: ValidationUtils.validatePhoneNumber,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _passwordController,
                  labelText: 'Password',
                  obscureText: true,
                  validator: ValidationUtils.validatePassword,
                ),
                const SizedBox(height: 16),
                _isLoadingRoles
                    ? const Center(child: CircularProgressIndicator())
                    : Builder(
                        builder: (context) {
                          final items =
                              (_roles.isNotEmpty
                                      ? _roles.map((role) => role.name).toList()
                                      : <String>[
                                          AppStrings.roleHR,
                                          AppStrings.roleMarketingExecutive,
                                        ])
                                  .toList();

                          final value = items.contains(_selectedRole)
                              ? _selectedRole
                              : (items.isNotEmpty ? items.first : null);

                          return DropdownButtonFormField<String>(
                            value: value,
                            decoration: const InputDecoration(
                              labelText: 'Role',
                              border: OutlineInputBorder(),
                            ),
                            items: items
                                .map(
                                  (name) => DropdownMenuItem(
                                    value: name,
                                    child: Text(name),
                                  ),
                                )
                                .toList(),
                            onChanged: (selected) {
                              setState(() {
                                _selectedRole = selected ?? '';
                              });
                            },
                            validator: (selected) {
                              if (selected == null || selected.isEmpty) {
                                return 'Please select a role';
                              }
                              return null;
                            },
                          );
                        },
                      ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        CustomButton(
          onPressed: _isLoading
              ? null
              : () async {
                  if (_formKey.currentState!.validate()) {
                    setState(() {
                      _isLoading = true;
                    });

                    // Check if email already exists
                    final existingUsers = await FirebaseService.getAllUsers();
                    final emailExists = existingUsers.any(
                      (user) =>
                          user.email.toLowerCase() ==
                          _emailController.text.trim().toLowerCase(),
                    );

                    if (emailExists) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Email already exists')),
                        );
                        setState(() {
                          _isLoading = false;
                        });
                      }
                      return;
                    }

                    if (mounted) {
                      Navigator.of(context).pop({
                        'name': _nameController.text.trim(),
                        'email': _emailController.text.trim(),
                        'phone': _phoneController.text.trim(),
                        'password': _passwordController.text,
                        'role': _selectedRole,
                      });
                    }
                  }
                },
          text: _isLoading ? 'Adding...' : 'Add User',
        ),
      ],
    );
  }
}

class EditUserDialog extends StatefulWidget {
  final User user;

  const EditUserDialog({super.key, required this.user});

  @override
  State<EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<EditUserDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late String _selectedRole;
  List<Role> _roles = [];
  bool _isLoadingRoles = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _emailController = TextEditingController(text: widget.user.email);
    _phoneController = TextEditingController(text: widget.user.phone);
    _selectedRole = widget.user.role;
    _loadRoles();
  }

  Future<void> _loadRoles() async {
    try {
      final roles = await FirebaseService.getAllRoles();
      if (mounted) {
        setState(() {
          _roles = roles;
          _isLoadingRoles = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingRoles = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return AlertDialog(
      title: const Text('Edit User'),
      content: SizedBox(
        width: isTablet ? 400 : double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomTextField(
                  controller: _nameController,
                  labelText: 'Full Name',
                  inputFormatters: [ValidationUtils.getNameFormatter()],
                  validator: (value) => ValidationUtils.validateName(
                    value,
                    fieldName: 'Full Name',
                  ),
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _emailController,
                  labelText: 'Email Address',
                  keyboardType: TextInputType.emailAddress,
                  validator: ValidationUtils.validateEmail,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _phoneController,
                  labelText: 'Phone Number',
                  keyboardType: TextInputType.phone,
                  inputFormatters: [ValidationUtils.getPhoneNumberFormatter()],
                  validator: ValidationUtils.validatePhoneNumber,
                ),
                const SizedBox(height: 16),
                _isLoadingRoles
                    ? const Center(child: CircularProgressIndicator())
                    : DropdownButtonFormField<String>(
                        value: _selectedRole.isNotEmpty ? _selectedRole : null,
                        decoration: const InputDecoration(
                          labelText: 'Role',
                          border: OutlineInputBorder(),
                        ),
                        items: _roles.map((role) {
                          return DropdownMenuItem(
                            value: role.name,
                            child: Text(role.name),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedRole = value!;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select a role';
                          }
                          return null;
                        },
                      ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        CustomButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.of(context).pop({
                'name': _nameController.text.trim(),
                'email': _emailController.text.trim(),
                'phone': _phoneController.text.trim(),
                'role': _selectedRole,
              });
            }
          },
          text: 'Update User',
        ),
      ],
    );
  }
}
