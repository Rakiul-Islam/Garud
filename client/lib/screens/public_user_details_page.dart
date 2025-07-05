import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:garudclient/data/models/public_user_model.dart';
import 'package:garudclient/repositories/user_repository.dart';
import 'package:garudclient/screens/video_feed_page.dart';
import 'package:url_launcher/url_launcher.dart';

class PublicUserDetailsPage extends StatefulWidget {
  final String uid;
  final String status;
  final isGuardian;

  const PublicUserDetailsPage({
    super.key,
    required this.uid,
    required this.status,
    required this.isGuardian,
  });

  @override
  State<PublicUserDetailsPage> createState() => _PublicUserDetailsPageState();
}

class _PublicUserDetailsPageState extends State<PublicUserDetailsPage> {
  late Future<PublicUserModel> _publicUserDetailsFuture;
  final UserRepository _userRepository = UserRepository();

  @override
  void initState() {
    super.initState();
    _publicUserDetailsFuture = _fetchPublicUserDetails();
  }

  Future<PublicUserModel> _fetchPublicUserDetails() async {
    final userModel = await _userRepository.getPublicUserData(widget.uid);
    return PublicUserModel(
      uid: userModel.uid,
      name: userModel.name,
      email: userModel.email,
      phoneNumber: userModel.phoneNumber,
      garudId: userModel.garudId,
      status: widget.status,
    );
  }

  Future<void> _copyToClipboard(String text, String label) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$label copied to clipboard'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not launch dialer for $phoneNumber'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: Text(widget.isGuardian ? 'Guardian Details' : 'Protege Details'),
      ),
      body: FutureBuilder<PublicUserModel>(
        future: _publicUserDetailsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                strokeWidth: 3,
              ),
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Theme.of(context).colorScheme.error.withOpacity(0.7),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error: ${snapshot.error}',
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          } else if (snapshot.hasData) {
            final user = snapshot.data!;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Card with Avatar
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .onPrimary
                              .withOpacity(0.2),
                          child: Text(
                            user.name.isNotEmpty
                                ? user.name[0].toUpperCase()
                                : 'G',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          user.name,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        if (widget.isGuardian)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimary
                                  .withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              user.status,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  _buildDetailCard(
                    icon: Icons.email_outlined,
                    label: 'Email',
                    value: user.email,
                    actionIcon: Icons.file_copy,
                    onAction: () => _copyToClipboard(user.email, 'Email'),
                    actionTooltip: 'Copy Email',
                  ),
                  const SizedBox(height: 22),
                  _buildDetailCard(
                    icon: Icons.phone_outlined,
                    label: 'Phone Number',
                    value: user.phoneNumber,
                    actionIcon: Icons.phone,
                    onAction: () => _makePhoneCall(user.phoneNumber),
                    actionTooltip: 'Call',
                  ),

                  const SizedBox(height: 22),

                  if (!widget.isGuardian)
                    _buildDetailCard(
                      icon: Icons.visibility_outlined,
                      label: 'Garud ID',
                      value: user.garudId,
                      actionIcon: Icons.videocam,
                      onAction: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              VideoFeedPage(garudId: user.garudId),
                        ),
                      ),
                      actionTooltip: 'Open video feed',
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
                    Icons.person_off_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No data found.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildDetailCard({
    required IconData icon,
    required String label,
    required String value,
    required IconData actionIcon,
    required VoidCallback onAction,
    required String actionTooltip,
    bool showActionButton = true,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 12, 20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (showActionButton)
              IconButton(
                onPressed: onAction,
                icon: Icon(
                  actionIcon,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                tooltip: actionTooltip,
                style: IconButton.styleFrom(
                  backgroundColor:
                      Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.all(12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
