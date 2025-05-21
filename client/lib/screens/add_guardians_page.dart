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

  void _submitGuardian() {
    final email = _emailController.text.trim();
    if (email.isNotEmpty) {
      context.read<UserBloc>().add(AddGuardianRequested(email));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an email')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Guardian'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<UserBloc>().add(FetchGuardiansRequested()),
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
          } else if (state is GuardianAddFailed || state is GuardianDeleteFailed) {
            final message = (state as dynamic).message;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(message)),
            );
          }
        },
        builder: (context, state) {
          final isLoading = state is GuardiansLoadInProgress || state is GuardianAddInProgress;

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
                                DeleteGuardianRequested(guardian['uid']!)
                              );
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