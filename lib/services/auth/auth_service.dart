import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Authentication for Campus Nav.
///
/// The backend is Firebase Auth (email/password). Students may sign in with
/// either their school email or their student ID; an ID without an '@' is
/// mapped to a synthetic email under `campus-nav.students` so one code path
/// serves both. The same mapping happens on sign-up and sign-in, so IDs round
/// trip. Guest mode never touches Firebase: the app stays fully usable
/// offline, and a schedule saved as a guest can be uploaded at first sign-in.
class AuthService {
  AuthService(this._auth);

  final FirebaseAuth _auth;

  /// Domain under which bare student IDs are treated as email addresses.
  static const String studentEmailDomain = 'campus-nav.students';

  String normalizeIdentifier(String identifier) {
    final value = identifier.trim();
    if (value.contains('@')) {
      return value;
    }
    return '$value@$studentEmailDomain';
  }

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<void> signIn(String identifier, String password) async {
    await _auth.signInWithEmailAndPassword(
      email: normalizeIdentifier(identifier),
      password: password,
    );
  }

  Future<void> signUp(String identifier, String password) async {
    await _auth.createUserWithEmailAndPassword(
      email: normalizeIdentifier(identifier),
      password: password,
    );
  }

  Future<void> sendPasswordReset(String identifier) {
    return _auth.sendPasswordResetEmail(email: normalizeIdentifier(identifier));
  }

  Future<void> signOut() => _auth.signOut();

  /// Maps a [FirebaseAuthException] to a message a student can act on.
  String describeError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return "That doesn't look like a valid email or student ID.";
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Wrong ID/email or password. Try again.';
      case 'email-already-in-use':
        return 'An account already exists for this ID/email. Try logging in.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'too-many-requests':
        return 'Too many attempts. Wait a minute and try again.';
      case 'network-request-failed':
        return "You're offline. Connect to the internet to sign in, "
            'or continue as guest.';
      case 'user-disabled':
        return 'This account has been disabled.';
      default:
        return e.message ?? 'Something went wrong. Please try again.';
    }
  }
}

final authServiceProvider = Provider<AuthService>(
  (ref) => AuthService(FirebaseAuth.instance),
);

/// The signed-in user, or null while the student is a guest.
final authStateProvider = StreamProvider<User?>(
  (ref) => ref.watch(authServiceProvider).authStateChanges,
);
