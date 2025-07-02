import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:garudclient/blocs/auth/auth_bloc.dart';
import 'package:garudclient/blocs/auth/auth_event.dart';
import 'package:garudclient/blocs/user/user_bloc.dart';
import 'package:garudclient/blocs/user/user_event.dart';
import 'package:garudclient/blocs/user/user_state.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  void initState() {
    super.initState();
    context.read<UserBloc>().add(LoadUserProfile());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              context.read<AuthBloc>().add(LogoutRequested());
            },
          ),
        ],
      ),
      body: BlocBuilder<UserBloc, UserState>(
        builder: (context, state) {
          if (state is UserProfileLoading || state is UserInitial) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (state is UserProfileError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error: ${state.message}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      context.read<UserBloc>().add(LoadUserProfile());
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          
          if (state is UserProfileLoaded) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [                  const Center(
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.blue,
                      child: Icon(Icons.person, size: 50, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Name',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextField(
                    readOnly: true,
                    controller: TextEditingController(text: state.name),
                    decoration: const InputDecoration(
                      hintText: 'Name',
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Email',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextField(
                    readOnly: true,
                    controller: TextEditingController(text: state.email),
                    decoration: const InputDecoration(
                      hintText: 'Email',
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Phone Number',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextField(
                    readOnly: true,
                    controller: TextEditingController(text: state.phoneNumber),
                    decoration: const InputDecoration(
                      hintText: 'Phone Number',
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Garud ID',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextField(
                    readOnly: true,
                    controller: TextEditingController(text: state.garudId),
                    decoration: const InputDecoration(
                      hintText: 'Garud ID',
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Alert Notifications'),
                    value: state.enableAlerts,
                    onChanged: null, // Read-only
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: FilledButton.icon(
                      onPressed: () {
                        // TODO: Implement edit profile later
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Editing profile will be available soon'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit Profile'),
                    ),
                  ),
                ],
              ),
            );
          }
          
          return const Center(
            child: Text('Something went wrong'),
          );
        },
      ),
    );
  }
}
