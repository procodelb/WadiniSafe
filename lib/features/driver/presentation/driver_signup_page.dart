import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/widgets/app_button.dart';

class DriverSignupPage extends ConsumerStatefulWidget {
  const DriverSignupPage({super.key});

  @override
  ConsumerState<DriverSignupPage> createState() => _DriverSignupPageState();
}

class _DriverSignupPageState extends ConsumerState<DriverSignupPage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _fullNameController = TextEditingController();
  final _plateNumberController = TextEditingController();
  final _seatsController = TextEditingController();
  final _licenseNumberController = TextEditingController();

  String? _vehicleType;
  File? _licensePhoto;
  File? _vehiclePhoto;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _plateNumberController.dispose();
    _seatsController.dispose();
    _licenseNumberController.dispose();
    super.dispose();
  }

  Widget _buildImageUploadField(String label, File? image, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          AspectRatio(
            aspectRatio: 1.0,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey[200],
              ),
              child: image != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(image, fit: BoxFit.cover),
                    )
                  : const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.camera_alt, color: Colors.grey, size: 40),
                        SizedBox(height: 8),
                        Text('Tap to upload',
                            style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(bool isLicense) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );

      if (image != null) {
        setState(() {
          if (isLicense) {
            _licensePhoto = File(image.path);
          } else {
            _vehiclePhoto = File(image.path);
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  Future<String?> _uploadImage(File file, String path) async {
    try {
      final ref = FirebaseStorage.instance.ref().child(path);
      final uploadTask = ref.putFile(file);
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return null;
    }
  }

  Future<void> _submitApplication() async {
    if (!_formKey.currentState!.validate()) return;
    if (_vehicleType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a vehicle type')),
      );
      return;
    }
    if (_licensePhoto == null || _vehiclePhoto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please upload both license and vehicle photos')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not authenticated");

      // Upload Images
      final licenseUrl = await _uploadImage(
          _licensePhoto!, 'driver_docs/${user.uid}/license.jpg');
      final vehicleUrl = await _uploadImage(
          _vehiclePhoto!, 'driver_docs/${user.uid}/vehicle.jpg');

      if (licenseUrl == null || vehicleUrl == null) {
        throw Exception("Failed to upload documents");
      }

      final batch = FirebaseFirestore.instance.batch();

      // Driver Document Reference
      final driverRef =
          FirebaseFirestore.instance.collection('drivers').doc(user.uid);

      // Vehicle Document Reference (New collection for vehicles)
      final vehicleRef =
          FirebaseFirestore.instance.collection('vehicles').doc();

      final now = FieldValue.serverTimestamp();

      // Set Driver Data
      batch.set(driverRef, {
        'uid': user.uid,
        'fullName': _fullNameController.text.trim(),
        'phone': user.phoneNumber, // Read-only from Auth
        'vehicleType': _vehicleType,
        'plateNumber': _plateNumberController.text.trim(),
        'seats': int.tryParse(_seatsController.text.trim()) ?? 4,
        'licenseNumber': _licenseNumberController.text.trim(),
        'licensePhotoUrl': licenseUrl,
        'status': 'pending',
        'isOnline': false,
        'ratingAvg': 0.0,
        'ratingCount': 0,
        'vehicleId': vehicleRef.id,
        'createdAt': now,
      });

      // Set Vehicle Data
      batch.set(vehicleRef, {
        'id': vehicleRef.id,
        'driverId': user.uid,
        'type': _vehicleType,
        'plateNumber': _plateNumberController.text.trim(),
        'seats': int.tryParse(_seatsController.text.trim()) ?? 4,
        'photoUrl': vehicleUrl,
        'createdAt': now,
      });

      // Update User Role Status (Optional redundancy but good for quick lookups)
      final userRef =
          FirebaseFirestore.instance.collection('users').doc(user.uid);
      batch.set(
          userRef,
          {
            'status': 'pending',
            'role': 'driver',
            'driverProfileId': user.uid,
          },
          SetOptions(merge: true));

      await batch.commit();

      if (!mounted) return;
      context.go('/pending-approval');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Driver Registration')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.drive_eta, size: 64, color: Colors.blue),
                const SizedBox(height: 24),
                Text(
                  'Complete your Driver Profile',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Read-only Phone Field
                TextFormField(
                  initialValue: user?.phoneNumber ?? 'N/A',
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                    filled: true,
                    fillColor: Colors.white70,
                  ),
                ),
                const SizedBox(height: 16),

                // Full Name
                TextFormField(
                  controller: _fullNameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),

                // Vehicle Type Dropdown
                DropdownButtonFormField<String>(
                  value: _vehicleType,
                  decoration: const InputDecoration(
                    labelText: 'Vehicle Type',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.directions_car),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Taxi', child: Text('Taxi')),
                    DropdownMenuItem(value: 'Bus', child: Text('Bus')),
                    DropdownMenuItem(
                        value: 'School Bus', child: Text('School Bus')),
                    DropdownMenuItem(
                        value: 'University Bus', child: Text('University Bus')),
                  ],
                  onChanged: (value) => setState(() => _vehicleType = value),
                  validator: (value) => value == null ? 'Required' : null,
                ),
                const SizedBox(height: 16),

                // Plate Number
                TextFormField(
                  controller: _plateNumberController,
                  decoration: const InputDecoration(
                    labelText: 'Plate Number',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.confirmation_number),
                  ),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),

                // Seats
                TextFormField(
                  controller: _seatsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Number of Seats',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.event_seat),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Required';
                    if (int.tryParse(value) == null) return 'Must be a number';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // License Number
                TextFormField(
                  controller: _licenseNumberController,
                  decoration: const InputDecoration(
                    labelText: 'Driving License Number',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.card_membership),
                  ),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 24),

                // Document Uploads
                Text(
                  'Document Photos',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildImageUploadField(
                        'License Photo',
                        _licensePhoto,
                        () => _pickImage(true),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildImageUploadField(
                        'Vehicle Photo',
                        _vehiclePhoto,
                        () => _pickImage(false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                AppButton(
                  text: 'Submit Application',
                  isLoading: _isLoading,
                  onPressed: _isLoading ? null : _submitApplication,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
