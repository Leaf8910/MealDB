import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

class AuthService with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Register with email and password
  Future<UserModel?> registerWithEmailAndPassword(
    String name,
    String email,
    String password,
  ) async {
    try {
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Update display name
      await result.user?.updateDisplayName(name);
    
      if (result.user != null) {
        final UserModel userModel = UserModel(
          id: result.user!.uid,
          name: name,
          email: email,
          photoUrl: result.user!.photoURL,
          favorites: [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        await _firestore
            .collection('users')
            .doc(result.user!.uid)
            .set(userModel.toJson());
        
        return userModel;
      }
    } catch (e) {
      debugPrint('Error registering user: $e');
      rethrow;
    }
    return null;
  }

  // Sign in with email and password
  Future<UserModel?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (result.user != null) {
        // Get user document from Firestore
        final DocumentSnapshot doc = await _firestore
            .collection('users')
            .doc(result.user!.uid)
            .get();
        
        if (doc.exists) {
          return UserModel.fromFirestore(doc);
        } else {
          final UserModel userModel = UserModel(
            id: result.user!.uid,
            name: result.user!.displayName ?? 'User',
            email: result.user!.email ?? '',
            photoUrl: result.user!.photoURL,
          );
          
          await _firestore
              .collection('users')
              .doc(result.user!.uid)
              .set(userModel.toJson());
          
          return userModel;
        }
      }
    } catch (e) {
      debugPrint('Error signing in user: $e');
      rethrow;
    }
    return null;
  }


  Future<void> signOut() async {
    try {
      await _auth.signOut();
      notifyListeners();
    } catch (e) {
      debugPrint('Error signing out: $e');
      rethrow;
    }
  }
}