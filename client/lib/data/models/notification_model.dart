import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id; // Firestore document ID
  final String criminalId;
  final String criminalName;
  final String threatLevel; 
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final bool detectedOnSelf;
  final String? detectedOnProtegeUid;
  final String? detectedOnProtegeSName;
  final bool read;

  NotificationModel({
    required this.id,
    required this.criminalId,
    required this.criminalName,
    required this.threatLevel,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.detectedOnSelf,
    this.detectedOnProtegeUid,
    this.detectedOnProtegeSName,
    required this.read,
  });

  factory NotificationModel.fromDocumentSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final location = data['location'] as Map<String, dynamic>;

    // Handle timestamp - it can be either a number (Unix timestamp) or Timestamp object
    DateTime parsedTimestamp;
    final timestampData = data['timestamp'];
    
    if (timestampData is num) {
      // Unix timestamp with milliseconds (like 1751725042.168994)
      parsedTimestamp = DateTime.fromMillisecondsSinceEpoch(
        (timestampData * 1000).round(),
      );
    } else if (timestampData is Timestamp) {
      // Firestore Timestamp object
      parsedTimestamp = timestampData.toDate();
    } else if (timestampData is String) {
      // ISO 8601 string format
      parsedTimestamp = DateTime.parse(timestampData);
    } else {
      // Fallback to current time if timestamp is invalid
      parsedTimestamp = DateTime.now();
    }

    return NotificationModel(
      id: doc.id,
      criminalId: data['criminal_id'] ?? '',
      criminalName: data['criminal_name'] ?? '',
      threatLevel: data['threat_level'] ?? 'Unknown', 
      timestamp: parsedTimestamp,
      latitude: location['latitude']?.toDouble() ?? 0.0,
      longitude: location['longitude']?.toDouble() ?? 0.0,
      detectedOnSelf: data['detected_on_self'] ?? true,
      detectedOnProtegeUid: data['detected_on_protege_s_uid'],
      detectedOnProtegeSName: data['detected_on_protege_s_name'],
      read: data['read'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'criminal_id': criminalId,
      'criminal_name': criminalName,
      'threat_level': threatLevel,
      'timestamp': timestamp.millisecondsSinceEpoch / 1000, // Store as Unix timestamp
      'location': {
        'latitude': latitude,
        'longitude': longitude,
      },
      'detected_on_self': detectedOnSelf,
      'detected_on_protege_s_uid': detectedOnProtegeUid,
      'detected_on_protege_s_name': detectedOnProtegeSName,
      'read': read,
    };
  }
}