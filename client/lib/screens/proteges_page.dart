import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:garudclient/blocs/user/user_bloc.dart';
import 'package:garudclient/blocs/user/user_event.dart';
import 'package:garudclient/blocs/user/user_state.dart';
import 'package:garudclient/data/models/public_user_model.dart';
import 'package:garudclient/screens/public_user_details_page.dart';

class ProtegesPage extends StatefulWidget {
  final bool refresh;
  const ProtegesPage({super.key, this.refresh = false});

  @override
  State<ProtegesPage> createState() => _ProtegesPageState();
}

class _ProtegesPageState extends State<ProtegesPage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // Fetch proteges when page loads
    if (widget.refresh) {
      _refreshData();
    }
  }

  void _refreshData() {
    context.read<UserBloc>().add(FetchProtegesRequested());
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
              return current is ProtegesLoaded ||
                  current is ProtegesLoadInProgress ||
                  current is ProtegesLoadFailed;
            },
            builder: (context, state) {
              int totalCount = 0;
              
              if (state is ProtegesLoaded) {
                totalCount = state.proteges.length;
              }
              
              return Container(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(
                      Icons.people,
                      size: 30,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'My Proteges${totalCount > 0 ? ' ($totalCount)' : ''}',
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
          // Proteges list
          Expanded(
            child: BlocConsumer<UserBloc, UserState>(
              listenWhen: (previous, current) {
                return current is ProtegeDeleteFailed ||
                    current is ProtegeAcceptFailed ||
                    current is ProtegeRejectFailed;
              },
              listener: (context, state) {
                if (state is ProtegeDeleteFailed) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to remove protege: ${state.message}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                } else if (state is ProtegeAcceptFailed) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to accept request: ${state.message}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                } else if (state is ProtegeRejectFailed) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to reject request: ${state.message}'),
                      backgroundColor: Colors.red,
                    ),
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
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 80,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No proteges yet',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Someone needs to add you as their guardian',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  // Separate pending requests from accepted proteges
                  final pendingRequests = state.proteges
                      .where((protege) => protege.status == 'requested')
                      .toList();
                  final acceptedProteges = state.proteges
                      .where((protege) => protege.status == 'accepted')
                      .toList();

                  return RefreshIndicator(
                    onRefresh: () async {
                      _refreshData();
                    },
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      children: [
                        // Pending requests section
                        if (pendingRequests.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              'Guardian Requests (${pendingRequests.length})',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                          ),
                          ...pendingRequests.map((protege) => _buildPendingRequestCard(protege)),
                          const SizedBox(height: 16),
                        ],
                        
                        // Accepted proteges section
                        if (acceptedProteges.isNotEmpty) ...[
                          ...acceptedProteges.map((protege) => _buildAcceptedProtegeCard(protege)),
                        ],
                      ],
                    )
                  );
                } else if (state is ProtegesLoadFailed) {
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
                          'Error loading proteges',
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
                            context.read<UserBloc>().add(FetchProtegesRequested());
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
                            context.read<UserBloc>().add(FetchProtegesRequested());
                          },
                          child: const Text('Load Proteges'),
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

  Widget _buildPendingRequestCard(PublicUserModel protege) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      elevation: 4,
      child: ListTile(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PublicUserDetailsPage(
                uid: protege.uid,
                isGuardian: false,
                status: protege.status,
              ),
            ),
          );
        },
        leading: const CircleAvatar(
          backgroundColor: Colors.orange,
          child: Icon(
            Icons.person_add,
            color: Colors.white,
          ),
        ),
        title: Text(
          protege.name,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(protege.email,
          style: const TextStyle(color: Colors.orange),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.check, color: Colors.green),
              onPressed: () => _showAcceptDialog(context, protege),
              tooltip: 'Accept',
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.red),
              onPressed: () => _showRejectDialog(context, protege),
              tooltip: 'Reject',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAcceptedProtegeCard(PublicUserModel protege) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      child: ListTile(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PublicUserDetailsPage(
                uid: protege.uid,
                isGuardian: false,
                status: protege.status,
              ),
            ),
          );
        },
        leading: const CircleAvatar(
          backgroundColor: Colors.green,
          child: Icon(
            Icons.people,
            color: Colors.white,
          ),
        ),
        title: Text(
          protege.name,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(protege.email),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'delete') {
              _showDeleteConfirmationDialog(context, protege);
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
  }

  void _showAcceptDialog(BuildContext context, PublicUserModel protege) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Accept Guardian Request'),
          content: Text(
            'Accept ${protege.name} as your protege? You will become their guardian.',
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
                'Accept',
                style: TextStyle(color: Colors.green),
              ),
              onPressed: () {
                context.read<UserBloc>().add(
                      AcceptGuardianRequested(protege.uid),
                    );
                Navigator.of(dialogContext).pop();

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Accepting guardian request...'),
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

  void _showRejectDialog(BuildContext context, PublicUserModel protege) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Reject Guardian Request'),
          content: Text(
            'Reject ${protege.name}\'s guardian request? This cannot be undone.',
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
                'Reject',
                style: TextStyle(color: Colors.red),
              ),
              onPressed: () {
                context.read<UserBloc>().add(
                      RejectGuardianRequested(protege.uid),
                    );
                Navigator.of(dialogContext).pop();

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Rejecting guardian request...'),
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

  void _showDeleteConfirmationDialog(BuildContext context, PublicUserModel protege) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Remove Protege'),
          content: Text(
            'Are you sure you want to remove ${protege.name} as your protege? This will also remove you as their guardian.',
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
                      DeleteProtegeRequested(protege.uid),
                    );
                Navigator.of(dialogContext).pop();

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Removing protege...'),
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