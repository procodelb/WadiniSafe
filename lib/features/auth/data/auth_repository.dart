import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/app_user.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    FirebaseAuth.instance,
    GoogleSignIn(),
    FirebaseFirestore.instance,
  );
});

class AuthRepository {
  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
  final FirebaseFirestore _firestore;

  AuthRepository(this._auth, this._googleSignIn, this._firestore);

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw FirebaseAuthException(
        code: 'ERROR_ABORTED_BY_USER',
        message: 'Sign in aborted by user',
      );
    }
    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    return await _auth.signInWithCredential(credential);
  }

  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required void Function(PhoneAuthCredential) verificationCompleted,
    required void Function(FirebaseAuthException) verificationFailed,
    required void Function(String, int?) codeSent,
    required void Function(String) codeAutoRetrievalTimeout,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: verificationCompleted,
      verificationFailed: verificationFailed,
      codeSent: codeSent,
      codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
    );
  }

  Future<UserCredential> signInWithCredential(AuthCredential credential) {
    return _auth.signInWithCredential(credential);
  }

  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }

  /// Checks if the specific role profile exists in its respective collection
  Future<bool> hasCompleteProfile(String uid, String role) async {
    try {
      if (role == 'driver') {
        final doc = await _firestore.collection('drivers').doc(uid).get();
        return doc.exists;
      } else if (role == 'client') {
        final doc = await _firestore.collection('clients').doc(uid).get();
        return doc.exists;
      } else if (role == 'admin') {
        final doc = await _firestore.collection('admins').doc(uid).get();
        return doc.exists;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Checks Firestore collections to find the user's profile and return an [AppUser].
  /// Returns null if the user is not found in any collection.
  Future<AppUser?> getUserProfile(String uid) async {
    // Check Clients
    final clientDoc = await _firestore.collection('clients').doc(uid).get();
    if (clientDoc.exists) {
      final data = clientDoc.data()!;
      return AppUser(
        uid: uid,
        email: _auth.currentUser?.email,
        phoneNumber: (data['personalInfo'] as Map?)?['phone'] ??
            _auth.currentUser?.phoneNumber,
        displayName: (data['personalInfo'] as Map?)?['name'],
        role: 'client',
        status: data['status'] ?? 'pending',
        photoUrl: (data['personalInfo'] as Map?)?['photoUrl'],
      );
    }

    // Check Drivers
    final driverDoc = await _firestore.collection('drivers').doc(uid).get();
    if (driverDoc.exists) {
      final data = driverDoc.data()!;
      return AppUser(
        uid: uid,
        email: _auth.currentUser?.email,
        phoneNumber: (data['personalInfo'] as Map?)?['phone'] ??
            _auth.currentUser?.phoneNumber,
        displayName: (data['personalInfo'] as Map?)?['name'],
        role: 'driver',
        status: data['status'] ?? 'pending',
        photoUrl: (data['personalInfo'] as Map?)?['photoUrl'],
      );
    }

    // Check Admins
    final adminDoc = await _firestore.collection('admins').doc(uid).get();
    if (adminDoc.exists) {
      final data = adminDoc.data()!;
      return AppUser(
        uid: uid,
        email: data['email'] ?? _auth.currentUser?.email,
        displayName: data['displayName'],
        role: 'admin', // or data['role']
        status: 'approved', // Admins are always approved if they exist
      );
    }

    // Check generic Users collection (Fallback for incomplete signups)
    final userDoc = await _firestore.collection('users').doc(uid).get();
    if (userDoc.exists) {
      final data = userDoc.data()!;
      return AppUser(
        uid: uid,
        email: _auth.currentUser?.email,
        role: data['role'] ?? 'client',
        status: data['status'] ?? 'pending',
      );
    }

    return null;
  }

  Future<void> createClientProfile({
    required String uid,
    String? email,
    String? phone,
    String? name,
  }) async {
    await _firestore.collection('clients').doc(uid).set({
      'personalInfo': {
        'name': name ?? 'Client',
        'email': email,
        'phone': phone,
        'createdAt': FieldValue.serverTimestamp(),
      },
      'status': 'approved',
      'ratingAvg': 5.0,
      'ratingCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Also update generic user doc to link role
    await _firestore.collection('users').doc(uid).set({
      'role': 'client',
      'status': 'approved',
      'email': email,
      'phone': phone,
    }, SetOptions(merge: true));
  }

  Future<void> createDriverProfile({
    required String uid,
    String? email,
    String? phone,
    String? name,
  }) async {
    await _firestore.collection('drivers').doc(uid).set({
      'personalInfo': {
        'name': name ?? 'Driver',
        'email': email,
        'phone': phone,
        'createdAt': FieldValue.serverTimestamp(),
      },
      'vehicleInfo': {
        'type': 'sedan', // Default
        'plateNumber': '',
        'color': '',
      },
      'status': 'pending', // Drivers require approval
      'isOnline': false,
      'ratingAvg': 5.0,
      'ratingCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Also update generic user doc
    await _firestore.collection('users').doc(uid).set({
      'role': 'driver',
      'status': 'pending',
      'email': email,
      'phone': phone,
    }, SetOptions(merge: true));
  }
}
