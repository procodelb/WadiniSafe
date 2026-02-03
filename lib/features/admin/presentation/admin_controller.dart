import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/domain/app_user.dart';
import '../data/admin_repository.dart';

final pendingDriversProvider = StreamProvider<List<AppUser>>((ref) {
  return ref.watch(adminRepositoryProvider).watchPendingDrivers();
});

final pendingClientsProvider = StreamProvider<List<AppUser>>((ref) {
  return ref.watch(adminRepositoryProvider).watchPendingClients();
});

final adminControllerProvider = StateNotifierProvider<AdminController, AsyncValue<void>>((ref) {
  return AdminController(ref.watch(adminRepositoryProvider));
});

class AdminController extends StateNotifier<AsyncValue<void>> {
  final AdminRepository _repository;

  AdminController(this._repository) : super(const AsyncData(null));

  Future<void> approveUser(String uid, String role) async {
    state = const AsyncLoading();
    try {
      await _repository.updateUserStatus(uid: uid, role: role, newStatus: 'approved');
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> rejectUser(String uid, String role) async {
    state = const AsyncLoading();
    try {
      await _repository.updateUserStatus(uid: uid, role: role, newStatus: 'rejected');
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> updateUserStatus(String uid, String role, String newStatus) async {
    state = const AsyncLoading();
    try {
      await _repository.updateUserStatus(uid: uid, role: role, newStatus: newStatus);
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> suspendUser(String uid, String role) async {
    state = const AsyncLoading();
    try {
      await _repository.updateUserStatus(uid: uid, role: role, newStatus: 'suspended');
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}
