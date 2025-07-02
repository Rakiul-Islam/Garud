// Example: How to use FCM Token Update functionality
// 
// This example shows how to use the new FCM token update feature
// that was added to UserBloc, UserEvent, and UserState.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/user/user_bloc.dart';
import '../blocs/user/user_event.dart';
import '../blocs/user/user_state.dart';

class FCMTokenUpdateExample extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('FCM Token Update Example')),
      body: BlocConsumer<UserBloc, UserState>(
        listener: (context, state) {
          if (state is FCMTokenUpdateSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('FCM Token updated successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          } else if (state is FCMTokenUpdateFailed) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to update FCM token: ${state.message}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'FCM Token Update',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                SizedBox(height: 16),
                Text(
                  'The FCM token is automatically updated when a user logs in. '
                  'You can also manually trigger an update using the button below.',
                ),
                SizedBox(height: 20),
                if (state is FCMTokenUpdateInProgress)
                  Center(child: CircularProgressIndicator())
                else
                  ElevatedButton(
                    onPressed: () {
                      // Manually trigger FCM token update
                      context.read<UserBloc>().add(UpdateFCMTokenRequested());
                    },
                    child: Text('Update FCM Token'),
                  ),
                SizedBox(height: 20),
                Text(
                  'Use Cases:',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                SizedBox(height: 8),
                Text('• Automatic token update on login'),
                Text('• Manual token refresh'),
                Text('• Token update with custom token'),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    // Example: Update with a custom token
                    context.read<UserBloc>().add(
                      UpdateFCMTokenRequested(token: 'custom_token_here'),
                    );
                  },
                  child: Text('Update with Custom Token'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/*
IMPLEMENTATION NOTES:

1. Event: UpdateFCMTokenRequested
   - Takes an optional token parameter
   - If no token provided, fetches current FCM token automatically

2. States: 
   - FCMTokenUpdateInProgress: Shown during update process
   - FCMTokenUpdateSuccess: Update completed successfully
   - FCMTokenUpdateFailed: Update failed with error message

3. Automatic Usage:
   - Called automatically in HomePage.initState() when user logs in
   - Updates both FCM token and lastLogin timestamp in Firestore

4. Manual Usage:
   - Can be triggered manually from any screen
   - Useful for token refresh scenarios
   - Can provide custom token if needed

5. Integration Points:
   - login_page.dart: After successful login, navigates to HomePage
   - home_page.dart: Triggers FCM token update in initState()
   - Any other screen: Can manually trigger update when needed
*/
