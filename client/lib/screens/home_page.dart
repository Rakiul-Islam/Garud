import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:garudclient/blocs/theme/theme_bloc.dart';
import 'package:garudclient/blocs/theme/theme_event.dart';
import 'package:garudclient/blocs/theme/theme_state.dart';
import 'package:garudclient/blocs/user/user_bloc.dart';
import 'package:garudclient/blocs/user/user_event.dart';
import 'package:garudclient/blocs/user/user_state.dart';
import 'package:garudclient/screens/add_guardians_page.dart';
import 'package:garudclient/screens/guardians_page.dart';
import 'package:garudclient/screens/login_page.dart';
import 'package:garudclient/screens/profile_page.dart';
import 'package:garudclient/screens/proteges_page.dart';
import 'package:garudclient/data/models/user_model.dart';

class HomePage extends StatefulWidget {
  final UserModel user;
  const HomePage({super.key, required this.user});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _garudId;
  bool _isLoading = true;
  int _selectedIndex = 0;
  late UserModel _currentUser; // Add current user state

  UserModel get currentUser => _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    _garudId = widget.user.garudId;
    _isLoading = false;
    // Load initial data
    _refreshHomeData();
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
      _refreshHomeData();
    });
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  radius: 30,
                  child: Icon(Icons.person, size: 35),
                ),
                const SizedBox(height: 10),
                Text(
                  FirebaseAuth.instance.currentUser?.email ?? 'User',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
                if (_garudId != null)
                  Text(
                    'Garud ID: $_garudId',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.group_add),
            title: const Text('Add Guardian'),
            onTap: () {
              Navigator.pop(context); // Close the drawer
              _goToAddGuardianPage(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () {
              Navigator.pop(context); // Close the drawer
              // TODO: Implement settings page
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context); // Close the drawer
              _logout(context);
            },
          ),
        ],
      ),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    
    // Refresh data based on selected tab
    if (index == 0) { // Home tab - refresh complete user data
      context.read<UserBloc>().add(UpdateUserRequested());
    } else if (index == 1) { // Guardians tab
      context.read<UserBloc>().add(FetchGuardiansRequested());
    } else if (index == 2) { // Proteges tab
      context.read<UserBloc>().add(FetchProtegesRequested());
    } else if (index == 3) { // Profile tab
      context.read<UserBloc>().add(LoadUserProfile());
    }
  }

  void _refreshHomeData() {
    // Use the comprehensive user update instead of individual requests
    context.read<UserBloc>().add(UpdateUserRequested());
  }

  Widget _buildHomeTab() {
    final user = FirebaseAuth.instance.currentUser;
    
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                Text(
                  'Welcome, ${user?.email?.split('@')[0] ?? "User"}!',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                if (_garudId != null)
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.badge,
                            size: 50,
                            color: Colors.green,
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Your Garud ID',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color.fromARGB(255, 18, 18, 18),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _garudId!,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 50,
                            color: Colors.orange,
                          ),
                          SizedBox(height: 10),
                          Text(
                            'No Garud ID assigned',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
  }

  List<Widget> _buildScreens() {
    return [
      Center(child: _buildHomeTab()),
      const GuardiansPage(),
      const ProtegesPage(),
      const ProfilePage(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<UserBloc, UserState>(
      listener: (context, state) {
        if (state is UserUpdateSuccess) {
          setState(() {
            _currentUser = state.user;
            _garudId = state.user.garudId;
          });
        } else if (state is UserUpdateFailed) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update user data: ${state.message}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      child: Scaffold(
      endDrawer: _buildDrawer(),
      appBar: AppBar(
        title: const Text("Garud"),
        actions: [
          BlocBuilder<ThemeBloc, ThemeState>(
            builder: (context, state) {
              return IconButton(
                icon: Icon(state.isDarkMode ? Icons.light_mode : Icons.dark_mode),
                onPressed: () => context.read<ThemeBloc>().add(ToggleTheme()),
                tooltip: state.isDarkMode ? 'Switch to Light Mode' : 'Switch to Dark Mode',
              );
            },
          ),
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _buildScreens(),
      ),
      floatingActionButton: _selectedIndex == 1 // Show only on Guardians tab
          ? FloatingActionButton(
              onPressed: () => _goToAddGuardianPage(context),
              child: const Icon(Icons.group_add),
              tooltip: 'Add Guardian',
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shield),
            label: 'Guardians',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Proteges',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    ),
    );
  }
}