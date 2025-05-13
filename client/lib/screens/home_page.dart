import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'login_page.dart';
import 'add_guardians_page.dart'; // <-- Import this

class HomePage extends StatelessWidget {
  const HomePage({super.key});

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
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Welcome, ${user?.email ?? "User"}!',
                style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.group_add),
              label: const Text('Add Guardian'),
              onPressed: () => _goToAddGuardianPage(context),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              onPressed: () => _logout(context),
            ),
          ],
        ),
      ),
    );
  }
}
