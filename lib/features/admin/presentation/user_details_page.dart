import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'admin_controller.dart';

class UserDetailsPage extends ConsumerStatefulWidget {
  final String uid;
  final String role;

  const UserDetailsPage({
    super.key,
    required this.uid,
    required this.role,
  });

  @override
  ConsumerState<UserDetailsPage> createState() => _UserDetailsPageState();
}

class _UserDetailsPageState extends ConsumerState<UserDetailsPage> {
  bool _isLoading = true;
  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _vehicleData;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchUserDetails();
  }

  Future<void> _fetchUserDetails() async {
    try {
      final collection = widget.role == 'driver' ? 'drivers' : 'clients';
      final doc = await FirebaseFirestore.instance
          .collection(collection)
          .doc(widget.uid)
          .get();

      if (doc.exists) {
        final userData = doc.data();
        Map<String, dynamic>? vehicleData;

        if (widget.role == 'driver' &&
            userData != null &&
            userData['vehicleId'] != null) {
          final vehicleDoc = await FirebaseFirestore.instance
              .collection('vehicles')
              .doc(userData['vehicleId'])
              .get();
          if (vehicleDoc.exists) {
            vehicleData = vehicleDoc.data();
          }
        }

        setState(() {
          _userData = userData;
          _vehicleData = vehicleData;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'User document not found';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.role.toUpperCase()} Details'),
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(child: Text('Error: $_error'));
    }

    if (_userData == null) {
      return const Center(child: Text('No data available'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const Divider(height: 32),
          if (widget.role == 'driver') _buildDriverDetails(),
          if (widget.role == 'client') _buildClientDetails(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final data = _userData!;
    final name = data['fullName'] ??
        (data['personalInfo'] as Map?)?['name'] ??
        'Unknown Name';
    final phone = data['phone'] ??
        (data['personalInfo'] as Map?)?['phone'] ??
        'Unknown Phone';
    final status = data['status'] ?? 'Unknown';

    return Row(
      children: [
        CircleAvatar(
          radius: 30,
          child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?'),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: Theme.of(context).textTheme.headlineSmall),
              Text(phone, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _getStatusColor(status)),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: _getStatusColor(status),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDriverDetails() {
    final data = _userData!;
    final vehicle = _vehicleData ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Vehicle Information'),
        _buildDetailRow('Vehicle Type', vehicle['type']),
        _buildDetailRow('Plate Number', vehicle['plateNumber']),
        _buildDetailRow('Seats', '${vehicle['seats'] ?? "N/A"}'),
        const SizedBox(height: 24),
        _buildSectionTitle('License Information'),
        _buildDetailRow('License Number', data['licenseNumber']),
        const SizedBox(height: 16),
        _buildSectionTitle('Document Photos'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildZoomableImage('License', data['licensePhotoUrl']),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildZoomableImage('Vehicle', vehicle['photoUrl']),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildClientDetails() {
    final data = _userData!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Identity Verification'),
        _buildDetailRow('ID Type', data['idType']),
        const SizedBox(height: 16),
        _buildSectionTitle('ID Photos'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildZoomableImage('Front Side', data['idFrontUrl']),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildZoomableImage('Back Side', data['idBackUrl']),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildZoomableImage(String label, String? url) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        AspectRatio(
          aspectRatio: 1.5,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey.shade100,
            ),
            child: url != null
                ? GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) =>
                              FullScreenImageView(imageUrl: url),
                        ),
                      );
                    },
                    child: Hero(
                      tag: url,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          url,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const Center(
                                child: CircularProgressIndicator());
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                                child: Icon(Icons.broken_image));
                          },
                        ),
                      ),
                    ),
                  )
                : const Center(child: Icon(Icons.image_not_supported)),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey,
            ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value ?? 'N/A',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => _handleAction('rejected'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('REJECT'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: () => _handleAction('approved'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('APPROVE'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAction(String status) async {
    try {
      await ref
          .read(adminControllerProvider.notifier)
          .updateUserStatus(widget.uid, widget.role, status);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('User $status successfully')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      case 'suspended':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }
}

class FullScreenImageView extends StatelessWidget {
  final String imageUrl;

  const FullScreenImageView({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          boundaryMargin: const EdgeInsets.all(20),
          minScale: 0.5,
          maxScale: 4.0,
          child: Hero(
            tag: imageUrl,
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const CircularProgressIndicator(color: Colors.white);
              },
            ),
          ),
        ),
      ),
    );
  }
}
