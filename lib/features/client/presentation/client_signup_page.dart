import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/widgets/app_button.dart';

class ClientSignupPage extends ConsumerStatefulWidget {
  const ClientSignupPage({super.key});

  @override
  ConsumerState<ClientSignupPage> createState() => _ClientSignupPageState();
}

class _ClientSignupPageState extends ConsumerState<ClientSignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();

  String? _idType;
  File? _idFrontImage;
  File? _idBackImage;

  bool _isLoading = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _fullNameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(bool isFront) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70, // Compress image
      );

      if (image != null) {
        setState(() {
          if (isFront) {
            _idFrontImage = File(image.path);
          } else {
            _idBackImage = File(image.path);
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

  Future<void> _submitSignup() async {
    if (!_formKey.currentState!.validate()) return;

    if (_idFrontImage == null || _idBackImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload both ID images')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not authenticated");

      // 1. Upload Images
      final frontUrl = await _uploadImage(
          _idFrontImage!, 'client_ids/${user.uid}/front.jpg');
      final backUrl =
          await _uploadImage(_idBackImage!, 'client_ids/${user.uid}/back.jpg');

      if (frontUrl == null || backUrl == null) {
        throw Exception("Failed to upload ID images");
      }

      final batch = FirebaseFirestore.instance.batch();
      final clientRef =
          FirebaseFirestore.instance.collection('clients').doc(user.uid);
      final userRef =
          FirebaseFirestore.instance.collection('users').doc(user.uid);

      final now = FieldValue.serverTimestamp();

      // 2. Set Client Data
      batch.set(clientRef, {
        'uid': user.uid,
        'fullName': _fullNameController.text.trim(),
        'phone': user.phoneNumber,
        'idType': _idType,
        'idFrontUrl': frontUrl,
        'idBackUrl': backUrl,
        'status': 'pending',
        'ratingAvg': 0.0,
        'ratingCount': 0,
        'createdAt': now,
      });

      // 3. Update User Role & Status
      batch.set(
          userRef,
          {
            'role': 'client',
            'status': 'pending',
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

  Widget _buildImageUploadField(String label, File? image, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          child: Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey[100],
            ),
            child: image != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(image, fit: BoxFit.cover),
                  )
                : const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.camera_alt, size: 40, color: Colors.grey),
                      SizedBox(height: 8),
                      Text('Tap to upload',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Client Registration')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.person_outline, size: 64, color: Colors.green),
                const SizedBox(height: 24),
                Text(
                  'Verify your Identity',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please provide your details and ID for verification.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
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

                // ID Type Dropdown
                DropdownButtonFormField<String>(
                  value: _idType,
                  decoration: const InputDecoration(
                    labelText: 'ID Type',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.badge),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'National ID', child: Text('National ID')),
                    DropdownMenuItem(
                        value: 'Passport', child: Text('Passport')),
                    DropdownMenuItem(
                        value: 'Driving License',
                        child: Text('Driving License')),
                  ],
                  onChanged: (value) => setState(() => _idType = value),
                  validator: (value) => value == null ? 'Required' : null,
                ),
                const SizedBox(height: 24),

                // ID Images
                Row(
                  children: [
                    Expanded(
                      child: _buildImageUploadField(
                        'ID Front',
                        _idFrontImage,
                        () => _pickImage(true),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildImageUploadField(
                        'ID Back',
                        _idBackImage,
                        () => _pickImage(false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                AppButton(
                  text: 'Submit for Verification',
                  isLoading: _isLoading,
                  onPressed: _isLoading ? null : _submitSignup,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
