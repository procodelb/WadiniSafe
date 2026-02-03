# WadiniSafe Progress Report

This document tracks the implementation progress of the WadiniSafe application.

## ✅ Completed Tasks

### 1. Project Setup & Architecture
- [x] Flutter project initialized.
- [x] Feature-first folder structure created (`lib/features`, `lib/core`).
- [x] Core dependencies added (Firebase, Riverpod, GoRouter, etc.).
- [x] Localization support configured (Arabic/English).
- [x] Theme configuration (Light/Dark mode).

### 2. Authentication System
- [x] **Firebase Integration**: `FirebaseAuth` and `GoogleSignIn` configured.
- [x] **User Model**: `AppUser` domain model created with `freezed`.
- [x] **Repository**: `AuthRepository` implemented with:
    - Phone Auth (`verifyPhoneNumber`).
    - Google Sign-In.
    - Profile resolution (checking `clients`, `drivers`, `admins`, and `users` collections).
- [x] **State Management**: `AuthController` (Riverpod) handles auth state, loading, and errors.
- [x] **UI**: `SignInPage` implemented with:
    - Phone input & OTP verification.
    - Google Sign-In button.
    - Error handling via Snackbars.

### 3. Role Selection & Onboarding
- [x] **Role Selection Page**: Implemented for new users.
    - Cards for Client, Driver, Admin.
    - Writes initial user data to Firestore (`users/{uid}`).
- [x] **Destination Pages**:
    - `DriverSignupPage` (Placeholder).
    - `ClientSignupPage` (Placeholder).
    - `AdminPendingPage` (Placeholder).
- [x] **Routing**:
    - `AppRouter` updated with all new routes (`/role-selection`, `/driver-signup`, etc.).
    - Automatic redirection from `SignInPage` based on profile existence.

## 🚧 Pending / In Progress

### 1. User Profile Completion (Signup Forms)
- [x] **Driver Signup**: Implement form for Vehicle info, License, etc.
- [x] **Client Signup**: Implement form for Name, basic info (Auto-approved).
- [x] **Admin Approval**: Dashboard to approve/reject drivers.

### 2. Core Features
- [ ] **Driver**: Online/Offline toggle, Location tracking.
- [ ] **Client**: Request Ride UI, Map view of nearby drivers.
- [ ] **Admin**: Dashboard logic to approve drivers/admins.

## 🔄 Next Steps
1.  Implement the actual form logic for `DriverSignupPage` and `ClientSignupPage`.
2.  Connect the "Submit" buttons on these pages to update the user's profile in Firestore (moving them from `users` collection to `drivers`/`clients` collections or updating status).
