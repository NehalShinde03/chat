import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/widgets.dart';

class PresenceService with WidgetsBindingObserver {
  final FirebaseFirestore firestore;
  final fb.FirebaseAuth firebaseAuth;

  StreamSubscription<fb.User?>? _authSubscription;
  bool _isInitialized = false;

  PresenceService({
    required this.firestore,
    required this.firebaseAuth,
  });

  void initialize() {
    if (_isInitialized) return;
    _isInitialized = true;

    WidgetsBinding.instance.addObserver(this);

    // Watch auth changes to update presence accordingly
    _authSubscription = firebaseAuth.authStateChanges().listen((user) {
      if (user != null) {
        setPresence(true);
      }
    });

    if (firebaseAuth.currentUser != null) {
      setPresence(true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (firebaseAuth.currentUser == null) return;

    if (state == AppLifecycleState.resumed) {
      setPresence(true);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      setPresence(false);
    }
  }

  Future<void> setPresence(bool isOnline) async {
    try {
      final uid = firebaseAuth.currentUser?.uid;
      if (uid == null || uid.isEmpty) return;

      await firestore.collection('users').doc(uid).set({
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('PresenceService error updating status: $e');
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription?.cancel();
    _isInitialized = false;
  }
}
