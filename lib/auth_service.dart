import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kaawa/data/user_data.dart' as kaawa_user;

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Sign up a new user with email and password, and store additional data in metadata
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    required String phoneNumber,
    required String userType,
    required String district,
  }) async {
    return await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': fullName,
        'phone_number': phoneNumber,
        'user_type': userType,
        'district': district,
      },
    );
  }

  /// Sign in with email and password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Sign out
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  /// Get the current session
  Session? get currentSession => _supabase.auth.currentSession;

  /// Get the current user
  User? get currentUser => _supabase.auth.currentUser;

  /// Check if a user is logged in
  bool get isLoggedIn => _supabase.auth.currentSession != null;

  /// Get the current user's ID
  String? get userId => _supabase.auth.currentUser?.id;

  /// Get current user data as our User model
  kaawa_user.User? get currentUserData {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    final metadata = user.userMetadata ?? {};
    final userTypeStr = metadata['user_type'] ?? 'buyer';
    
    return kaawa_user.User(
      id: user.id,
      fullName: metadata['full_name'] ?? 'User',
      phoneNumber: metadata['phone_number'] ?? '',
      district: metadata['district'] ?? '',
      password: '',
      userType: kaawa_user.UserType.values.firstWhere(
        (e) => e.name == userTypeStr,
        orElse: () => kaawa_user.UserType.buyer,
      ),
    );
  }

  /// Password reset for Supabase
  Future<void> resetPassword(String email) async {
    await _supabase.auth.resetPasswordForEmail(email);
  }

  /// Logout (alias for signOut)
  Future<void> logout() async {
    await signOut();
  }
}
