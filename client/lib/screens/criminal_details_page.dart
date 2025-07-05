import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:garudclient/data/models/criminal_model.dart';
import 'package:intl/intl.dart';

class CriminalDetailsPage extends StatefulWidget {
  final String documentId;

  const CriminalDetailsPage({
    Key? key,
    required this.documentId,
  }) : super(key: key);

  @override
  State<CriminalDetailsPage> createState() => _CriminalDetailsPageState();
}

class _CriminalDetailsPageState extends State<CriminalDetailsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  CriminalModel? criminal;
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchCriminalDetails();
  }

  Future<void> _fetchCriminalDetails() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final docSnapshot = await _firestore
          .collection('criminals')
          .doc(widget.documentId)
          .get();

      if (docSnapshot.exists) {
        setState(() {
          criminal = CriminalModel.fromFirestore(docSnapshot);
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Criminal not found';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load criminal details: $e';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(criminal?.fullName ?? 'Criminal Details'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              errorMessage!,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchCriminalDetails,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (criminal == null) {
      return const Center(
        child: Text('No criminal data found'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderSection(),
          const SizedBox(height: 24),
          _buildPersonalInfoSection(),
          const SizedBox(height: 24),
          _buildCrimesSection(),
          const SizedBox(height: 24),
          _buildImagesSection(),
          const SizedBox(height: 24),
          _buildLocationSection(),
          const SizedBox(height: 24),
          _buildNotesSection(),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    criminal!.fullName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildStatusChip(),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'National ID: ${criminal!.nationalId}',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            _buildThreatLevelChip(),
            if (criminal!.aliases.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Aliases: ${criminal!.aliases.join(', ')}',
                style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: criminal!.isWanted ? Colors.red : Colors.green,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        criminal!.isWanted ? 'WANTED' : 'NOT WANTED',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildThreatLevelChip() {
    Color chipColor;
    switch (criminal!.threatLevel.toLowerCase()) {
      case 'critical':
        chipColor = Colors.red;
        break;
      case 'high':
        chipColor = Colors.orange;
        break;
      case 'medium':
        chipColor = Colors.yellow;
        break;
      case 'low':
        chipColor = Colors.green;
        break;
      default:
        chipColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'Threat Level: ${criminal!.threatLevel}',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildPersonalInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Personal Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Gender', criminal!.gender),
            _buildInfoRow('Date of Birth', DateFormat('MMM dd, yyyy').format(criminal!.dob)),
            _buildInfoRow('Age', _calculateAge(criminal!.dob).toString()),
            _buildInfoRow('Created', DateFormat('MMM dd, yyyy HH:mm').format(criminal!.createdAt)),
            _buildInfoRow('Last Updated', DateFormat('MMM dd, yyyy HH:mm').format(criminal!.updatedAt)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildCrimesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Crimes (${criminal!.crimes.length})',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (criminal!.crimes.isEmpty)
              const Text('No crimes recorded')
            else
              ...criminal!.crimes.map((crime) => _buildCrimeCard(crime)),
          ],
        ),
      ),
    );
  }

  Widget _buildCrimeCard(Crime crime) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    crime.type,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(crime.status),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    crime.status,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(crime.description),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  crime.location,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(width: 16),
                Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  DateFormat('MMM dd, yyyy').format(crime.date),
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Images (${criminal!.images.length})',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (criminal!.images.isEmpty)
              const Text('No images available')
            else
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: criminal!.images.length,
                  itemBuilder: (context, index) {
                    final image = criminal!.images[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => _showImageDialog(image.url),
                        child: Container(
                          width: 120,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              image.url,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey.shade200,
                                  child: const Icon(Icons.image_not_supported),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Location Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (criminal!.lastKnownLocation != null) ...[
              _buildInfoRow('Latitude', criminal!.lastKnownLocation!.latitude.toString()),
              _buildInfoRow('Longitude', criminal!.lastKnownLocation!.longitude.toString()),
            ],
            if (criminal!.lastSeenTimestamp != null)
              _buildInfoRow(
                'Last Seen',
                DateFormat('MMM dd, yyyy HH:mm').format(
                  DateTime.parse(criminal!.lastSeenTimestamp!),
                ),
              ),
            if (criminal!.lastKnownLocation == null && criminal!.lastSeenTimestamp == null)
              const Text('No location information available'),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Notes',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              criminal!.notes.isNotEmpty ? criminal!.notes : 'No notes available',
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'convicted':
        return Colors.red;
      case 'under investigation':
        return Colors.orange;
      case 'alleged':
        return Colors.yellow.shade700;
      case 'cleared':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  int _calculateAge(DateTime birthDate) {
    final today = DateTime.now();
    int age = today.year - birthDate.year;
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  void _showImageDialog(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          constraints: const BoxConstraints(maxHeight: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                title: const Text('Image'),
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Expanded(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Text('Failed to load image'),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}