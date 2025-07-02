// screens/add_guardians_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:garudclient/blocs/user/user_bloc.dart';
import 'package:garudclient/blocs/user/user_event.dart';
import 'package:garudclient/blocs/user/user_state.dart';
import 'package:garudclient/data/models/public_user_model.dart';

class AddGuardianPage extends StatefulWidget {
  const AddGuardianPage({super.key});

  @override
  State<AddGuardianPage> createState() => _AddGuardianPageState();
}

class _AddGuardianPageState extends State<AddGuardianPage> {
  final TextEditingController _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<UserBloc>().add(FetchGuardiansRequested());
  }

  void _submitGuardian() async {
    final email = _emailController.text.trim();

    // Validate email format
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!emailRegex.hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address')),
      );
      return;
    }

    // Prevent user from adding their own email
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null && currentUser.email == email) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot add yourself as a guardian')),
      );
      return;
    }

    // Check if email belongs to a registered user
    final usersSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: email)
        .get();

    if (usersSnapshot.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No registered user with this email')),
      );
      return;
    }

    // Check if already in guardians list
    final currentState = context.read<UserBloc>().state;
    if (currentState is GuardiansLoaded) {
      final alreadyAdded =
          currentState.guardians.any((g) => g.email == email);
      if (alreadyAdded) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This guardian is already added')),
        );
        return;
      }
    }

    // All checks passed – Add guardian
    context.read<UserBloc>().add(AddGuardianRequested(email));
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'accepted':
        return Colors.green;
      case 'requested':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'accepted':
        return Icons.check_circle;
      case 'requested':
        return Icons.hourglass_empty;
      default:
        return Icons.help;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'accepted':
        return 'Active';
      case 'requested':
        return 'Pending';
      default:
        return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Guardians'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                context.read<UserBloc>().add(FetchGuardiansRequested()),
            tooltip: 'Refresh Guardian List',
          ),
        ],
      ),
      body: BlocConsumer<UserBloc, UserState>(
        listener: (context, state) {
          if (state is GuardianAdded) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Guardian request sent successfully')),
            );
            _emailController.clear();

            // Refresh both lists when guardian is added successfully
            context.read<UserBloc>().add(FetchGuardiansRequested());
            context.read<UserBloc>().add(FetchProtegesRequested());
          } else if (state is GuardianAddFailed ||
              state is GuardianDeleteFailed) {
            final message = (state as dynamic).message;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(message)),
            );
          }
        },
        builder: (context, state) {
          final isLoading = state is GuardiansLoadInProgress ||
              state is GuardianAddInProgress;

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Current Guardians:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                if (isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (state is GuardiansLoaded && state.guardians.isEmpty)
                  const Text('No guardians added yet.')
                else if (state is GuardiansLoaded)
                  Expanded(
                    child: ListView.builder(
                      itemCount: state.guardians.length,
                      itemBuilder: (context, index) {
                        final guardian = state.guardians[index];
                        final status = guardian.status;
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8.0),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _getStatusColor(status),
                              child: Icon(
                                _getStatusIcon(status),
                                color: Colors.white,
                              ),
                            ),
                            title: Text(guardian.name),
                            subtitle: Text(
                              '${guardian.email} • ${_getStatusText(status) }',
                              style: TextStyle(
                                color: _getStatusColor(status),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'delete') {
                                  _showDeleteConfirmationDialog(context, guardian);
                                }
                              },
                              itemBuilder: (BuildContext context) => [
                                const PopupMenuItem<String>(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text('Remove'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 30),
                const Text(
                  'Add New Guardian:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Guardian Email',
                    border: OutlineInputBorder(),
                    helperText: 'Enter a valid email',
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _submitGuardian,
                    child: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Send Guardian Request'),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Note: The person will receive a notification and must accept your request to become your guardian.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context, PublicUserModel guardian) {
    final status = guardian.status;
    final actionText = status == 'requested' ? 'Cancel Request' : 'Remove Guardian';
    final contentText = status == 'requested' 
        ? 'Cancel your guardian request to ${guardian.email}?'
        : 'Remove ${guardian.email} as your guardian? This will end the guardian relationship.';

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(actionText),
          content: Text(contentText),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: Text(
                actionText,
                style: const TextStyle(color: Colors.red),
              ),
              onPressed: () {
                context.read<UserBloc>().add(
                      DeleteGuardianRequested(guardian.uid),
                    );
                Navigator.of(dialogContext).pop();

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(status == 'requested' 
                        ? 'Cancelling request...' 
                        : 'Removing guardian...'),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}