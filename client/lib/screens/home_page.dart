import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../blocs/user/user_bloc.dart';
import '../blocs/user/user_event.dart';
import '../blocs/user/user_state.dart';
import '../blocs/theme/theme_bloc.dart';
import '../blocs/theme/theme_event.dart';
import '../blocs/theme/theme_state.dart';
import 'login_page.dart';
import 'add_guardians_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  String? _garudId;
  bool _isLoading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserData();
    // Fetch both guardians and proteges when page loads
    context.read<UserBloc>().add(FetchGuardiansRequested());
    context.read<UserBloc>().add(FetchProtegesRequested());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists && userDoc.data()?['garudId'] != null) {
          setState(() {
            _garudId = userDoc.data()!['garudId'];
          });
        }
      }
    } catch (e) {
      // Handle error silently
      print('Error loading user data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => LoginPage()),
      (route) => false,
    );
  }

  void _goToAddGuardianPage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddGuardianPage()),
    ).then((_) {
      // Refresh data when returning from add guardian page
      context.read<UserBloc>().add(FetchGuardiansRequested());
      context.read<UserBloc>().add(FetchProtegesRequested());
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          BlocBuilder<ThemeBloc, ThemeState>(
            builder: (context, state) {
              return IconButton(
                icon:
                    Icon(state.isDarkMode ? Icons.light_mode : Icons.dark_mode),
                onPressed: () => context.read<ThemeBloc>().add(ToggleTheme()),
                tooltip: state.isDarkMode
                    ? 'Switch to Light Mode'
                    : 'Switch to Dark Mode',
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Guardians'),
            Tab(text: 'Proteges'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text('Welcome, ${user?.email ?? "User"}!',
                          style: const TextStyle(fontSize: 20)),
                      const SizedBox(height: 10),
                      if (_garudId != null)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                const Text(
                                  'Your Garud ID',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _garudId!,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Guardians Tab
                      _buildGuardiansTab(),
                      // Proteges Tab
                      _buildProtegesTab(),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _goToAddGuardianPage(context),
        child: const Icon(Icons.group_add),
        tooltip: 'Add Guardian',
      ),
      bottomNavigationBar: BottomAppBar(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
                onPressed: () {
                  context.read<UserBloc>().add(FetchGuardiansRequested());
                  context.read<UserBloc>().add(FetchProtegesRequested());
                },
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
                onPressed: () => _logout(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuardiansTab() {
    return BlocBuilder<UserBloc, UserState>(
      buildWhen: (previous, current) {
        return current is GuardiansLoaded ||
            current is GuardiansLoadInProgress ||
            current is GuardianLoadFailed;
      },
      builder: (context, state) {
        if (state is GuardiansLoadInProgress) {
          return const Center(child: CircularProgressIndicator());
        } else if (state is GuardiansLoaded) {
          if (state.guardians.isEmpty) {
            return const Center(
              child: Text('No guardians added yet.'),
            );
          }
          return ListView.builder(
            itemCount: state.guardians.length,
            itemBuilder: (BuildContext context, int index) {
              final guardian = state.guardians[index];
              return ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.person),
                ),
                title: Text(guardian['email'] ?? ''),
                subtitle: const Text('Guardian'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    context.read<UserBloc>().add(
                          DeleteGuardianRequested(guardian['uid']!),
                        );
                  },
                ),
              );
            },
          );
        } else if (state is GuardianLoadFailed) {
          return Center(
            child: Text('Error: ${state.message}'),
          );
        } else {
          return const Center(
            child: Text('Select the refresh button to load guardians.'),
          );
        }
      },
    );
  }

  // Updated _buildProtegesTab method in screens/home_page.dart
  Widget _buildProtegesTab() {
    return BlocConsumer<UserBloc, UserState>(
      // Changed from BlocBuilder to BlocConsumer
      listenWhen: (previous, current) {
        return current is ProtegeDeleteFailed;
      },
      listener: (context, state) {
        // Display error message if delete operation fails
        if (state is ProtegeDeleteFailed) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Failed to remove protege: ${state.message}')),
          );
        }
      },
      buildWhen: (previous, current) {
        return current is ProtegesLoaded ||
            current is ProtegesLoadInProgress ||
            current is ProtegesLoadFailed;
      },
      builder: (context, state) {
        if (state is ProtegesLoadInProgress) {
          return const Center(child: CircularProgressIndicator());
        } else if (state is ProtegesLoaded) {
          if (state.proteges.isEmpty) {
            return const Center(
              child: Text(
                  'No proteges yet. Someone has to add you as their guardian.'),
            );
          }
          return ListView.builder(
            itemCount: state.proteges.length,
            itemBuilder: (BuildContext context, int index) {
              final protege = state.proteges[index];
              return ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: Icon(Icons.shield, color: Colors.white),
                ),
                title: Text(protege['email'] ?? ''),
                subtitle: const Text('Protege'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    // Show confirmation dialog
                    showDialog(
                      context: context,
                      builder: (BuildContext dialogContext) {
                        return AlertDialog(
                          title: const Text('Remove Protege'),
                          content: Text(
                              'Are you sure you want to remove ${protege['email']} as your protege? This will also remove you as their guardian.'),
                          actions: [
                            TextButton(
                              child: const Text('Cancel'),
                              onPressed: () {
                                Navigator.of(dialogContext).pop();
                              },
                            ),
                            TextButton(
                              child: const Text('Remove'),
                              onPressed: () {
                                context.read<UserBloc>().add(
                                      DeleteProtegeRequested(protege['uid']!),
                                    );
                                Navigator.of(dialogContext).pop();

                                // Show a loading indicator while the deletion is being processed
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(const SnackBar(
                                  content: Text('Removing protege...'),
                                  duration: Duration(seconds: 1),
                                ));
                              },
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              );
            },
          );
        } else if (state is ProtegesLoadFailed) {
          return Center(
            child: Text('Error: ${state.message}'),
          );
        } else {
          return const Center(
            child: Text('Select the refresh button to load proteges.'),
          );
        }
      },
    );
  }
}
