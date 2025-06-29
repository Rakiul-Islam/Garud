import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/user/user_bloc.dart';
import '../blocs/user/user_event.dart';
import '../blocs/user/user_state.dart';

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
    for (var doc in usersSnapshot.docs) {
      print('User Document: ${doc.data()}'); // prints the actual user data (Map<String, dynamic>)
    }

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
          currentState.guardians.any((g) => g['email'] == email);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Guardian'),
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
              const SnackBar(content: Text('Guardian added successfully')),
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
                        return ListTile(
                          leading: const Icon(Icons.person),
                          title: Text(guardian['email'] ?? ''),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              context.read<UserBloc>().add(
                                  DeleteGuardianRequested(guardian['uid']!));
                            },
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 30),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Guardian Email',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: isLoading ? null : _submitGuardian,
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Add Guardian'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
