import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../models/role_model.dart';
import '../constants/app_constants.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';

class RoleManagementScreen extends StatefulWidget {
  const RoleManagementScreen({super.key});

  @override
  State<RoleManagementScreen> createState() => _RoleManagementScreenState();
}

class _RoleManagementScreenState extends State<RoleManagementScreen> {
  List<Role> _roles = [];
  bool _isLoading = false;
  String? _error;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadRoles();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRoles() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final roles = await FirebaseService.getAllRoles();
      setState(() {
        _roles = roles;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<Role> get _filteredRoles {
    if (_searchQuery.isEmpty) return _roles;
    return _roles
        .where(
          (role) =>
              role.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              role.description.toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ),
        )
        .toList();
  }

  Future<void> _addRole() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const AddRoleDialog(),
    );

    if (result != null) {
      try {
        final roleId = await FirebaseService.addRole(result);
        if (roleId != null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Role added successfully')),
            );
            _loadRoles();
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Failed to add role')));
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

  Future<void> _editRole(Role role) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => EditRoleDialog(role: role),
    );

    if (result != null) {
      try {
        final success = await FirebaseService.updateRole(role.id, result);
        if (success) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Role updated successfully')),
            );
            _loadRoles();
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to update role')),
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

  Future<void> _deleteRole(Role role) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Role'),
        content: Text(
          'Are you sure you want to delete "${role.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final success = await FirebaseService.deleteRole(role.id);
        if (success) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Role deleted successfully')),
            );
            _loadRoles();
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to delete role')),
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

  Future<void> _toggleRoleStatus(Role role) async {
    try {
      final success = await FirebaseService.toggleRoleStatus(
        role.id,
        !role.isActive,
      );
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Role ${role.isActive ? 'deactivated' : 'activated'} successfully',
              ),
            ),
          );
          _loadRoles();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update role status')),
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return Scaffold(
     
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error: $_error'),
                      const SizedBox(height: 16),
                      CustomButton(onPressed: _loadRoles, text: 'Retry'),
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
                            hintText: 'Search roles...',
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
                                            '${_filteredRoles.length}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .headlineLarge
                                                ?.copyWith(
                                                  color: AppColors.primary,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                          const Text(
                                            'Total Roles',
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
                                    onPressed: _addRole,
                                    text: 'Add New Role',
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
                                    child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${_filteredRoles.length}',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .headlineMedium
                                                  ?.copyWith(
                                                    color: AppColors.primary,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                            ),
                                            const Text(
                                              'Total Roles',
                                              style: TextStyle(fontSize: 14),
                                            ),
                                          ],
                                        ),
                                        CustomButton(
                                          onPressed: _addRole,
                                          text: 'Add Role',
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    // Roles List
                    Expanded(
                      child: _filteredRoles.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.work_outline,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No roles found',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Add your first role to get started',
                                style: TextStyle(color: Colors.grey[500]),
                                  ),
                                  const SizedBox(height: 16),
                                  CustomButton(
                                    onPressed: _addRole,
                                    text: 'Add First Role',
                                  ),
                                ],
                              ),
                            )
                          : isTablet
                              ? GridView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    childAspectRatio: 2.5,
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 16,
                                  ),
                                  itemCount: _filteredRoles.length,
                                  itemBuilder: (context, index) {
                                    final role = _filteredRoles[index];
                                    return _buildRoleCard(role, isTablet);
                                  },
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                  itemCount: _filteredRoles.length,
                                  itemBuilder: (context, index) {
                                    final role = _filteredRoles[index];
                                    return _buildRoleCard(role, isTablet);
                                  },
                                ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildRoleCard(Role role, bool isTablet) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          radius: isTablet ? 28 : 24,
          backgroundColor: role.isActive ? AppColors.primary : Colors.grey,
          child: Icon(
            Icons.work,
            color: Colors.white,
            size: isTablet ? 24 : 20,
          ),
        ),
        title: Text(
          role.name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: isTablet ? 18 : 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              role.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
                Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: role.isActive
                        ? Colors.green.withOpacity(0.2)
                        : Colors.grey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    role.isActive ? 'Active' : 'Inactive',
                    style: TextStyle(
                      color: role.isActive ? Colors.green[700] : Colors.grey[700],
                      fontSize: isTablet ? 14 : 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Edit'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'toggle',
              child: Row(
                children: [
                  Icon(
                    role.isActive ? Icons.block : Icons.check_circle,
                    color: role.isActive ? Colors.orange : Colors.green,
                  ),
                  const SizedBox(width: 8),
                  Text(role.isActive ? 'Deactivate' : 'Activate'),
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
                _editRole(role);
                break;
              case 'toggle':
                _toggleRoleStatus(role);
                break;
              case 'delete':
                _deleteRole(role);
                break;
            }
          },
        ),
      ),
    );
  }
}

class AddRoleDialog extends StatefulWidget {
  const AddRoleDialog({super.key});

  @override
  State<AddRoleDialog> createState() => _AddRoleDialogState();
}

class _AddRoleDialogState extends State<AddRoleDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return AlertDialog(
      title: const Text('Add New Role'),
      content: SizedBox(
        width: isTablet ? 500 : double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.7,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomTextField(
                  controller: _nameController,
                  labelText: 'Role Name',
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a role name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Description (optional)
                CustomTextField(
                  controller: _descriptionController,
                  labelText: 'Description (optional)',
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                // No permissions selection needed
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

                    Navigator.of(context).pop({
                      'name': _nameController.text.trim(),
                      'description': _descriptionController.text.trim(),
                    });
                  }
                },
          text: _isLoading ? 'Adding...' : 'Add Role',
        ),
      ],
    );
  }
}

class EditRoleDialog extends StatefulWidget {
  final Role role;

  const EditRoleDialog({super.key, required this.role});

  @override
  State<EditRoleDialog> createState() => _EditRoleDialogState();
}

class _EditRoleDialogState extends State<EditRoleDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.role.name);
    _descriptionController = TextEditingController(
      text: widget.role.description,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return AlertDialog(
      title: const Text('Edit Role'),
      content: SizedBox(
        width: isTablet ? 500 : double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.7,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomTextField(
                  controller: _nameController,
                  labelText: 'Role Name',
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a role name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Description is optional and not needed per requirements
                const SizedBox(height: 16),
                // No permissions selection needed
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
                'description': _descriptionController.text.trim(),
              });
            }
          },
          text: 'Update Role',
        ),
      ],
    );
  }
}
