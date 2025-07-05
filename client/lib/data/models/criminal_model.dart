// Model class for Criminal data
import 'package:cloud_firestore/cloud_firestore.dart';

class CriminalModel {
  final String id;
  final String fullName;
  final String nationalId;
  final String gender;
  final DateTime dob;
  final List<String> aliases;
  final List<Crime> crimes;
  final List<CriminalImage> images;
  final bool isWanted;
  final LastKnownLocation? lastKnownLocation;
  final String? lastSeenTimestamp;
  final String notes;
  final String threatLevel;
  final DateTime createdAt;
  final DateTime updatedAt;

  CriminalModel({
    required this.id,
    required this.fullName,
    required this.nationalId,
    required this.gender,
    required this.dob,
    required this.aliases,
    required this.crimes,
    required this.images,
    required this.isWanted,
    this.lastKnownLocation,
    this.lastSeenTimestamp,
    required this.notes,
    required this.threatLevel,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CriminalModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CriminalModel(
      id: doc.id,
      fullName: data['full_name'] ?? '',
      nationalId: data['national_id'] ?? '',
      gender: data['gender'] ?? '',
      dob: _parseDateTime(data['dob']),
      aliases: List<String>.from(data['aliases'] ?? []),
      crimes: (data['crimes'] as List<dynamic>?)
          ?.map((crime) => Crime.fromMap(crime))
          .toList() ?? [],
      images: (data['images'] as List<dynamic>?)
          ?.map((image) => CriminalImage.fromMap(image))
          .toList() ?? [],
      isWanted: data['is_wanted'] ?? false,
      lastKnownLocation: data['last_known_location'] != null
          ? LastKnownLocation.fromMap(data['last_known_location'])
          : null,
      lastSeenTimestamp: data['last_seen_timestamp'],
      notes: data['notes'] ?? '',
      threatLevel: data['threat_level'] ?? '',
      createdAt: _parseDateTime(data['created_at']),
      updatedAt: _parseDateTime(data['updated_at']),
    );
  }

  static DateTime _parseDateTime(dynamic dateValue) {
    if (dateValue is Timestamp) {
      return dateValue.toDate();
    } else if (dateValue is String) {
      return DateTime.parse(dateValue);
    } else {
      return DateTime.now(); // fallback
    }
  }
}

class Crime {
  final String type;
  final String description;
  final String location;
  final String status;
  final DateTime date;

  Crime({
    required this.type,
    required this.description,
    required this.location,
    required this.status,
    required this.date,
  });

  factory Crime.fromMap(Map<String, dynamic> map) {
    return Crime(
      type: map['type'] ?? '',
      description: map['description'] ?? '',
      location: map['location'] ?? '',
      status: map['status'] ?? '',
      date: CriminalModel._parseDateTime(map['date']),
    );
  }
}

class CriminalImage {
  final String id;
  final String name;
  final String url;
  final DateTime createdAt;

  CriminalImage({
    required this.id,
    required this.name,
    required this.url,
    required this.createdAt,
  });

  factory CriminalImage.fromMap(Map<String, dynamic> map) {
    return CriminalImage(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      url: map['url'] ?? '',
      createdAt: CriminalModel._parseDateTime(map['created_at']),
    );
  }
}

class LastKnownLocation {
  final double latitude;
  final double longitude;

  LastKnownLocation({
    required this.latitude,
    required this.longitude,
  });

  factory LastKnownLocation.fromMap(Map<String, dynamic> map) {
    return LastKnownLocation(
      latitude: map['latitude']?.toDouble() ?? 0.0,
      longitude: map['longitude']?.toDouble() ?? 0.0,
    );
  }
}