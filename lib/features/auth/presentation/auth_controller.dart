import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/auth_repository.dart';
import '../domain/app_user.dart';

// State for the AuthController
class AuthState {
  final AsyncValue<AppUser?> user;
  final bool isLoading;
  final String? error;
  final String? verificationId; // For Phone Auth

  const AuthState({
    this.user = const AsyncValue.data(null),
    this.isLoading = false,
    this.error,
    this.verificationId,
  });

  AuthState copyWith({
    AsyncValue<AppUser?>? user,
    bool? isLoading,
    String? error,
    String? verificationId,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error, // Nullable on purpose to clear errors
      verificationId: verificationId ?? this.verificationId,
    );
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref.watch(authRepositoryProvider));
});

class AuthController extends StateNotifier<AuthState> {
  final AuthRepository _authRepository;

  AuthController(this._authRepository) : super(const AuthState());

  // Google Sign In
  Future<void> signInWithGoogle(BuildContext context) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final credential = await _authRepository.signInWithGoogle();
      await _handleSuccessfulAuth(context, credential.user);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // Phone Auth: Send OTP
  Future<void> sendOtp(String phoneNumber) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _authRepository.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-resolution on Android
          await _authRepository.signInWithCredential(credential);
          state = state.copyWith(isLoading: false);
        },
        verificationFailed: (FirebaseAuthException e) {
          state = state.copyWith(isLoading: false, error: e.message);
        },
        codeSent: (String verificationId, int? resendToken) {
          state = state.copyWith(
            isLoading: false,
            verificationId: verificationId,
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          state = state.copyWith(verificationId: verificationId);
        },
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // Phone Auth: Verify OTP
  Future<void> verifyOtp(BuildContext context, String smsCode) async {
    if (state.verificationId == null) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: state.verificationId!,
        smsCode: smsCode,
      );
      final userCredential =
          await _authRepository.signInWithCredential(credential);
      await _handleSuccessfulAuth(context, userCredential.user);
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> _handleSuccessfulAuth(
      BuildContext context, User? firebaseUser) async {
    if (firebaseUser == null) {
      state = state.copyWith(isLoading: false, error: "Authentication failed");
      return;
    }

    try {
      // 1. Get User Profile (from any collection)
      final appUser = await _authRepository.getUserProfile(firebaseUser.uid);

      state = state.copyWith(
        isLoading: false,
        user: AsyncValue.data(appUser),
      );

      if (!context.mounted) return;

      // 2. No Profile -> Role Selection
      if (appUser == null) {
        context.go('/role-selection');
        return;
      }

      // 3. Check if Profile is Complete (exists in specific collection)
      final isProfileComplete =
          await _authRepository.hasCompleteProfile(appUser.uid, appUser.role);

      if (!isProfileComplete) {
        // Redirect to specific signup page based on role
        switch (appUser.role) {
          case 'driver':
            context.go('/driver-signup');
            break;
          case 'client':
            context.go('/client-signup');
            break;
          case 'admin':
            context.go('/admin-pending');
            break;
          default:
            context.go('/role-selection'); // Fallback
        }
        return;
      }

      // 4. Profile is Complete -> Check Status & Role
      if (appUser.role == 'driver') {
        if (appUser.status == 'approved') {
          context.go('/driver');
        } else if (appUser.status == 'pending') {
          context.go('/pending-approval');
        } else {
          state = state.copyWith(
              error: "Account is ${appUser.status}. Contact support.");
          await _authRepository.signOut();
        }
      } else if (appUser.role == 'client') {
        if (appUser.status == 'approved') {
          context.go('/client');
        } else if (appUser.status == 'pending') {
          context.go('/pending-approval');
        } else {
          state = state.copyWith(error: "Account is ${appUser.status}.");
          await _authRepository.signOut();
        }
      } else if (appUser.role == 'admin') {
        if (appUser.status == 'approved') {
          context.go('/admin');
        } else {
          context.go('/admin-pending');
        }
      }
    } catch (e) {
      state = state.copyWith(
          isLoading: false, error: "Failed to fetch profile: $e");
    }
  }

  Future<void> signOut() async {
    await _authRepository.signOut();
    state = const AuthState();
  }

  Future<void> selectRole(BuildContext context, String role) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = _authRepository.currentUser;
      if (user == null) {
        state = state.copyWith(isLoading: false, error: "User not found");
        return;
      }

      if (role == 'client') {
        await _authRepository.createClientProfile(
          uid: user.uid,
          email: user.email,
          phone: user.phoneNumber,
          name: user.displayName,
        );
      } else if (role == 'driver') {
        await _authRepository.createDriverProfile(
          uid: user.uid,
          email: user.email,
          phone: user.phoneNumber,
          name: user.displayName,
        );
      }

      // Refresh Profile and Redirect
      await _handleSuccessfulAuth(context, user);
    } catch (e) {
      state = state.copyWith(
          isLoading: false, error: "Failed to create profile: $e");
    }
  }
}
