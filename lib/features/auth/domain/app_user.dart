import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_user.freezed.dart';
part 'app_user.g.dart';

@freezed
class AppUser with _$AppUser {
  const factory AppUser({
    required String uid,
    String? email,
    String? phoneNumber,
    String? displayName,
    @Default('client') String role, // client, driver, admin
    @Default('pending') String status, // pending, approved, suspended, rejected
    String? photoUrl,
  }) = _AppUser;

  factory AppUser.fromJson(Map<String, dynamic> json) => _$AppUserFromJson(json);
}
