import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:garudclient/blocs/user/user_bloc.dart';
import 'package:garudclient/blocs/user/user_event.dart';
import 'package:garudclient/blocs/user/user_state.dart';
import 'package:garudclient/data/models/public_user_model.dart';
import 'package:garudclient/screens/public_user_details_page.dart';

class GuardiansPage extends StatefulWidget {
  final bool refresh;
  const GuardiansPage({super.key, this.refresh = false});

  @override
  State<GuardiansPage> createState() => _GuardiansPageState();
}

class _GuardiansPageState extends State<GuardiansPage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // Fetch guardians when page loads
    if (widget.refresh) {
      _refreshData();
    }
  }

  void _refreshData() {
    context.read<UserBloc>().add(FetchGuardiansRequested());
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    return Scaffold(
      body: Column(
        children: [
          // Header section
          BlocBuilder<UserBloc, UserState>(
            buildWhen: (previous, current) {
              return current is GuardiansLoaded ||
                  current is GuardiansLoadInProgress ||
                  current is GuardianLoadFailed;
            },
            builder: (context, state) {
              int totalCount = 0;
              
              if (state is GuardiansLoaded) {
                totalCount = state.guardians.length;
              }
              
              return Container(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(
                      Icons.shield,
                      size: 30,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'My Guardians${totalCount > 0 ? ' ($totalCount)' : ''}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          // Guardians list
          Expanded(
            child: BlocConsumer<UserBloc, UserState>(
              listenWhen: (previous, current) {
                return current is GuardianDeleteFailed;
              },
              listener: (context, state) {
                if (state is GuardianDeleteFailed) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to remove guardian: ${state.message}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
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
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.shield_outlined,
                            size: 80,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No guardians added yet',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add a guardian to help keep you safe',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async {
                      _refreshData();
                    },
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      itemCount: state.guardians.length,
                      itemBuilder: (BuildContext context, int index) {
                        final guardian = state.guardians[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8.0),
                          child: ListTile(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PublicUserDetailsPage(
                                    uid: guardian.uid,
                                    status: guardian.status,
                                    isGuardian: true,
                                  ),
                                ),
                              );
                            },
                            leading: CircleAvatar(
                              backgroundColor: guardian.status == 'accepted'
                                  ? Colors.green
                                  : guardian.status == 'pending'
                                      ? Colors.orange
                                      : Colors.grey,
                              child: Icon(
                                guardian.status == 'accepted'
                                    ? Icons.shield
                                    : guardian.status == 'pending'
                                        ? Icons.schedule
                                        : Icons.shield_outlined,
                                color: Colors.white,
                              ),
                            ),
                            title: Text(
                              guardian.name,
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(guardian.email),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      guardian.status == 'accepted' 
                                          ? Icons.check_circle 
                                          : guardian.status == 'requested'
                                              ? Icons.access_time
                                              : Icons.cancel,
                                      size: 16,
                                      color: guardian.status == 'accepted'
                                          ? Colors.green
                                          : guardian.status == 'requested'
                                              ? Colors.orange
                                              : Colors.red,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      guardian.status == 'accepted' 
                                          ? 'Request Accepted'
                                          : guardian.status == 'requested'
                                              ? 'Request Pending'
                                              : 'Request ${guardian.status.toUpperCase()}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: guardian.status == 'accepted'
                                            ? Colors.green
                                            : guardian.status == 'requested'
                                                ? Colors.orange
                                                : Colors.red,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
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
                  );
                } else if (state is GuardianLoadFailed) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 80,
                          color: Colors.red[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading guardians',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.red[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          state.message,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.red[400],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            context.read<UserBloc>().add(FetchGuardiansRequested());
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                } else {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.refresh,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Pull down to refresh',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            context.read<UserBloc>().add(FetchGuardiansRequested());
                          },
                          child: const Text('Load Guardians'),
                        ),
                      ],
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context, PublicUserModel guardian) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Remove Guardian'),
          content: Text(
            'Are you sure you want to remove ${guardian.email} as your guardian? This will also remove you from their proteges list.',
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: const Text(
                'Remove',
                style: TextStyle(color: Colors.red),
              ),
              onPressed: () {
                context.read<UserBloc>().add(
                      DeleteGuardianRequested(guardian.uid),
                    );
                Navigator.of(dialogContext).pop();

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Removing guardian...'),
                    duration: Duration(seconds: 1),
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