import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static const String projectUrl =
      'https://tthiwtrovndeucvpxzhc.supabase.co';

  static const String publishableKey =
      'sb_publishable_PuvvCrpOXCDM84aHrK6bhA_E2n3H4Vj';

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: projectUrl,
      anonKey: publishableKey,
    );
  }

  static bool get isLoggedIn => client.auth.currentUser != null;

  static String? get currentUserId => client.auth.currentUser?.id;

  static Stream<AuthState> get authStateChanges =>
      client.auth.onAuthStateChange;

  static Future<void> signOut() async {
    await client.auth.signOut();
  }
}