import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Menangani login Google melalui Firebase Authentication.
class CloudAuthService {
  static Future<void>? _googleInitialization;

  Future<void> _ensureGoogleInitialized() {
    return _googleInitialization ??=
        GoogleSignIn.instance.initialize();
  }

  Future<User> signInWithGoogle() async {
    await _ensureGoogleInitialized();

    if (!GoogleSignIn.instance.supportsAuthenticate()) {
      throw Exception('Login Google tidak didukung pada platform ini.');
    }

    final googleUser = await GoogleSignIn.instance.authenticate();
    final googleAuthentication = googleUser.authentication;
    final idToken = googleAuthentication.idToken;

    if (idToken == null || idToken.isEmpty) {
      throw Exception(
        'Token Google tidak ditemukan. Periksa SHA-1 dan google-services.json.',
      );
    }

    final credential = GoogleAuthProvider.credential(idToken: idToken);
    final userCredential = await FirebaseAuth.instance.signInWithCredential(
      credential,
    );
    final user = userCredential.user;

    if (user == null) {
      throw Exception('Firebase tidak mengembalikan data akun pengguna.');
    }

    try {
      await saveAccountToFirestore(user);
    } catch (error) {
      // Jangan biarkan sesi Firebase dianggap login berhasil ketika dokumen
      // akun belum dapat dibuat di Firestore.
      await FirebaseAuth.instance.signOut();
      rethrow;
    }
    return user;
  }

  /// Membuat dokumen users/{uid}. UID berasal dari Firebase Authentication.
  Future<void> saveAccountToFirestore(User user) async {
    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);
    final existing = await userRef.get();

    final accountData = <String, dynamic>{
      'uid': user.uid,
      'name': user.displayName ?? 'Pengguna HydroTracker',
      'email': user.email ?? '',
      'photoUrl': user.photoURL,
      'provider': 'google.com',
      'lastLoginAt': FieldValue.serverTimestamp(),
    };

    if (!existing.exists) {
      accountData['createdAt'] = FieldValue.serverTimestamp();
    }

    await userRef.set(accountData, SetOptions(merge: true));
  }

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    try {
      await _ensureGoogleInitialized();
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Sesi Firebase sudah keluar; kegagalan membersihkan sesi Google
      // tidak boleh menghalangi pengguna memakai mode lokal.
    }
  }
}
