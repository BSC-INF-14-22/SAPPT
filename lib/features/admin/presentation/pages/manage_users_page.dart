import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_agri_price_tracker/core/services/firestore_service.dart';
import 'package:smart_agri_price_tracker/core/services/notification_service.dart';

class ManageUsersPage extends StatefulWidget {
  final String? initialRole;

  const ManageUsersPage({super.key, this.initialRole});

  @override
  State<ManageUsersPage> createState() => _ManageUsersPageState();
}

class _ManageUsersPageState extends State<ManageUsersPage> {
  String _searchQuery = '';
  late String _selectedRole;

  final List<String> _roles = ['All', 'Farmer', 'Cooperative Officer', 'Admin'];

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.initialRole ?? 'All';
  }

  void _toggleUserStatus(String docId, bool currentStatus) async {
    try {
      await FirestoreService().updateData('users', docId, {
        'isDisabled': !currentStatus,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'User ${!currentStatus ? 'disabled' : 'enabled'} successfully.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _deleteUser(String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User?'),
        content: const Text('This action cannot be undone. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirestoreService().deleteData('users', docId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User deleted successfully.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _setApprovalStatus(String docId, bool approve) async {
    try {
      await FirestoreService().updateData('users', docId, {
        'approved': approve,
        'approvalStatus': approve ? 'approved' : 'rejected',
      });

      // Notify the user about approval/rejection
      await NotificationService().sendInAppNotification(
        uid: docId,
        title: approve ? 'Account Approved' : 'Account Rejected',
        message: approve
            ? 'Your cooperative account has been approved. You can now login.'
            : 'Your cooperative registration was rejected. Contact support for details.',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'User ${approve ? 'approved' : 'rejected'} successfully.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Users')),
      body: Column(
        children: [
          // Search & Filter Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: theme.primaryColor.withAlpha(10),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by name or email',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (val) =>
                      setState(() => _searchQuery = val.toLowerCase()),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _roles.map((role) {
                      final isSelected = _selectedRole == role;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ActionChip(
                          label: Text(role),
                          backgroundColor: isSelected
                              ? theme.primaryColor
                              : Colors.white,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : theme.primaryColor,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          onPressed: () => setState(() => _selectedRole = role),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // User List
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirestoreService().getCollectionStream('users'),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final docs = snapshot.data?.docs ?? [];

                // Client-side filtering
                final filteredDocs = docs.where((doc) {
                  final data = doc.data();
                  final name = (data['fullName'] ?? '')
                      .toString()
                      .toLowerCase();
                  final email = (data['email'] ?? '').toString().toLowerCase();
                  final role = data['role'] ?? '';

                  final matchesSearch =
                      name.contains(_searchQuery) ||
                      email.contains(_searchQuery);
                  final matchesRole =
                      _selectedRole == 'All' || role == _selectedRole;

                  return matchesSearch && matchesRole;
                }).toList();

                if (filteredDocs.isEmpty) {
                  return const Center(child: Text('No users found.'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final doc = filteredDocs[index];
                    final data = doc.data();
                    return _buildUserCard(doc.id, data, theme);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(
    String docId,
    Map<String, dynamic> data,
    ThemeData theme,
  ) {
    final name = data['fullName'] ?? 'Unknown';
    final email = data['email'] ?? 'No email';
    final role = data['role'] ?? 'User';
    final isDisabled = data['isDisabled'] ?? false;

    Color roleColor;
    switch (role) {
      case 'Admin':
        roleColor = Colors.red;
        break;
      case 'Cooperative Officer':
        roleColor = Colors.orange;
        break;
      default:
        roleColor = Colors.green;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: isDisabled ? Colors.grey : roleColor.withAlpha(30),
          child: Icon(
            isDisabled ? Icons.person_off : Icons.person,
            color: isDisabled ? Colors.white : roleColor,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  decoration: isDisabled ? TextDecoration.lineThrough : null,
                  color: isDisabled ? Colors.grey : Colors.black87,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: roleColor.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                role,
                style: TextStyle(
                  fontSize: 10,
                  color: roleColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(email, style: const TextStyle(fontSize: 12)),
            if (isDisabled)
              const Padding(
                padding: EdgeInsets.only(top: 4.0),
                child: Text(
                  'ACCOUNT DISABLED',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'toggle') {
              _toggleUserStatus(docId, isDisabled);
            } else if (value == 'delete') {
              _deleteUser(docId);
            } else if (value == 'approve') {
              _setApprovalStatus(docId, true);
            } else if (value == 'reject') {
              _setApprovalStatus(docId, false);
            }
          },
          itemBuilder: (context) {
            final items = <PopupMenuEntry<String>>[];
            items.add(
              PopupMenuItem(
                value: 'toggle',
                child: Row(
                  children: [
                    Icon(
                      isDisabled ? Icons.check_circle_outline : Icons.block,
                      color: isDisabled ? Colors.green : Colors.orange,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(isDisabled ? 'Enable User' : 'Disable User'),
                  ],
                ),
              ),
            );

            if (role == 'Cooperative Officer') {
              final isApproved = data['approved'] == true;
              items.add(
                PopupMenuItem(
                  value: isApproved ? 'reject' : 'approve',
                  child: Row(
                    children: [
                      Icon(
                        isApproved ? Icons.cancel : Icons.check_circle_outline,
                        color: isApproved ? Colors.red : Colors.green,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(isApproved ? 'Reject' : 'Approve'),
                    ],
                  ),
                ),
              );
            }

            items.add(
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Text('Delete User', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            );

            return items;
          },
        ),
      ),
    );
  }
}
