import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/user_model.dart';

abstract class AuthRemoteDataSource {
  Future<UserModel?> getCurrentUser();
  Future<UserModel?> signInWithGoogle();
  Future<void> signOut();
  Stream<UserModel?> get authStateChanges;
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final fb.FirebaseAuth firebaseAuth;
  final GoogleSignIn googleSignIn;
  final FirebaseFirestore firestore;

  AuthRemoteDataSourceImpl({
    required this.firebaseAuth,
    required this.googleSignIn,
    required this.firestore,
  });

  Future<void> _syncUserProfile(fb.User user) async {
    try {
      final userDocRef = firestore.collection('users').doc(user.uid);
      final defaultName = user.displayName ??
          (user.email != null && user.email!.contains('@')
              ? user.email!.split('@').first
              : 'WhatsApp User');

      await userDocRef.set({
        'uid': user.uid,
        'displayName': defaultName,
        'email': user.email ?? '',
        if (user.photoURL != null && user.photoURL!.isNotEmpty)
          'photoURL': user.photoURL,
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error syncing user profile to Firestore: $e');
    }
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    final currentUser = firebaseAuth.currentUser;
    if (currentUser != null) {
      // Non-blocking sync in background
      _syncUserProfile(currentUser);
      return UserModel.fromFirebaseUser(currentUser);
    }
    return null;
  }

  @override
  Future<UserModel?> signInWithGoogle() async {
    try {
      // Launch Google account picker
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        // User cancelled/dismissed the account selection dialog
        return null;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final fb.AuthCredential credential = fb.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final fb.UserCredential userCredential =
          await firebaseAuth.signInWithCredential(credential);

      final fb.User? user = userCredential.user;
      if (user != null) {
        // Background sync to Firestore without blocking the UI/login flow
        _syncUserProfile(user);
        return UserModel.fromFirebaseUser(user);
      } else {
        throw const AuthException('Firebase user credential returned null.');
      }
    } catch (e) {
      debugPrint('Google Sign-In Remote Exception: $e');
      if (e is AuthException) rethrow;
      throw AuthException(e.toString());
    }
  }

  @override
  Future<void> signOut() async {
    try {
      final uid = firebaseAuth.currentUser?.uid;
      if (uid != null && uid.isNotEmpty) {
        try {
          await firestore.collection('users').doc(uid).set({
            'isOnline': false,
            'lastSeen': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } catch (_) {}
      }

      await Future.wait([
        firebaseAuth.signOut(),
        googleSignIn.signOut(),
      ]);
    } catch (e) {
      debugPrint('Sign-out error: $e');
    }
  }

  @override
  Stream<UserModel?> get authStateChanges {
    return firebaseAuth.authStateChanges().map((user) {
      return user != null ? UserModel.fromFirebaseUser(user) : null;
    });
  }
}
