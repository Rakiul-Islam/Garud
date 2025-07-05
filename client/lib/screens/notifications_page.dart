import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'package:garudclient/data/models/notification_model.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({Key? key}) : super(key: key);

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Set<String> _markedAsRead = <String>{}; // Track which notifications we've already marked as read
  
  String? get currentUserId => _auth.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.mark_email_read),
            onPressed: _markAllAsRead,
            tooltip: 'Mark all as read',
          ),
        ],
      ),
      body: currentUserId == null
          ? const Center(
              child: Text('Please log in to view notifications'),
            )
          : StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('users')
                  .doc(currentUserId)
                  .collection('notifications')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading notifications',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          snapshot.error.toString(),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notifications_none,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No notifications yet',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'You\'ll receive notifications when threats are detected',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                final notifications = snapshot.data!.docs
                    .map((doc) => NotificationModel.fromDocumentSnapshot(doc))
                    .toList();

                return RefreshIndicator(
                  onRefresh: () async {
                    setState(() {});
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      final notification = notifications[index];
                      return _buildNotificationCard(notification);
                    },
                  ),
                );
              },
            ),
    );
  }

  Widget _buildNotificationCard(NotificationModel notification) {
    final isUnread = !notification.read;
    final threatColor = _getThreatLevelColor(notification.threatLevel);
    final timeAgo = _getTimeAgo(notification.timestamp);

    return VisibilityDetector(
      key: Key('notification_${notification.id}'),
      onVisibilityChanged: (visibilityInfo) {
        // Mark as read when 50% of the card is visible and it's unread
        if (visibilityInfo.visibleFraction >= 0.5 && 
            isUnread && 
            !_markedAsRead.contains(notification.id)) {
          _markAsRead(notification);
          _markedAsRead.add(notification.id);
        }
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: isUnread ? 4 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isUnread
              ? BorderSide(color: Colors.red.shade300, width: 1)
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: () => _markAsRead(notification),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isUnread
                  ? Colors.red.shade50
                  : Colors.white,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: threatColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: threatColor.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        notification.threatLevel.toUpperCase(),
                        style: TextStyle(
                          color: threatColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (isUnread)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.red.shade500,
                          shape: BoxShape.circle,
                        ),
                      ),
                    const SizedBox(width: 4),
                    Text(
                      timeAgo,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Main Content
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: threatColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.warning,
                        color: threatColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Criminal Detected',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            notification.criminalName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'ID: ${notification.criminalId}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Detection Info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            notification.detectedOnSelf
                                ? Icons.person
                                : Icons.supervised_user_circle,
                            size: 16,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            notification.detectedOnSelf
                                ? 'Detected on your device'
                                : 'Detected on ${notification.detectedOnProtegeSName ?? 'unknown'}\'s device',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      if (notification.latitude != 0 || notification.longitude != 0) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Location: ${notification.latitude.toStringAsFixed(6)}, ${notification.longitude.toStringAsFixed(6)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _showLocationOnMap(notification),
                      icon: const Icon(Icons.map, size: 16),
                      label: const Text('View Location'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.blue.shade600,
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isUnread)
                      TextButton.icon(
                        onPressed: () => _markAsRead(notification),
                        icon: const Icon(Icons.mark_email_read, size: 16),
                        label: const Text('Mark as Read'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.green.shade600,
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getThreatLevelColor(String threatLevel) {
    switch (threatLevel.toLowerCase()) {
      case 'high':
        return Colors.red.shade700;
      case 'moderate':
        return Colors.orange.shade600;
      case 'low':
        return Colors.yellow.shade700;
      default:
        return Colors.grey.shade600;
    }
  }

  String _getTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Future<void> _markAsRead(NotificationModel notification) async {
    if (currentUserId == null) return;
    
    try {
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('notifications')
          .doc(notification.id)
          .update({'read': true});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error marking notification as read: $e'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }

  Future<void> _markAllAsRead() async {
    if (currentUserId == null) return;
    
    try {
      final notifications = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('notifications')
          .where('read', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (final doc in notifications.docs) {
        batch.update(doc.reference, {'read': true});
        _markedAsRead.add(doc.id); // Add to our tracking set
      }
      
      await batch.commit();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('All notifications marked as read'),
          backgroundColor: Colors.green.shade600,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error marking all notifications as read: $e'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }

  void _showLocationOnMap(NotificationModel notification) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Criminal: ${notification.criminalName}'),
            const SizedBox(height: 8),
            Text('Latitude: ${notification.latitude}'),
            Text('Longitude: ${notification.longitude}'),
            const SizedBox(height: 8),
            Text('Detected: ${DateFormat('MMM dd, yyyy at HH:mm').format(notification.timestamp)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Implement map navigation
              // You can use url_launcher to open maps with coordinates
            },
            child: const Text('Open in Maps'),
          ),
        ],
      ),
    );
  }
}