import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';

class AppUser {
  static final AppUser _singleton = AppUser._internal();
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  User? firebaseUser;
  String? userId;
  String? email;

  // Private constructor for Singleton
  AppUser._internal();

  // Public getters
  bool get isLoggedIn => firebaseUser != null;
  String? get nickname => firebaseUser?.displayName;

  // Factory constructor to access the singleton instance
  factory AppUser() {
    return _singleton;
  }

  // Method to initialize the user from Firebase Auth
  Future<void> init() async {
    final currentUser = _firebaseAuth.currentUser;
    if (currentUser != null) {
      firebaseUser = currentUser;
      userId = currentUser.uid;
      email = currentUser.email;
    }
  }

  // Example method to fetch additional information or user data if needed
  Future<void> fetchAdditionalUserData() async {
    if (firebaseUser != null) {
      // Example: Fetch user data from Firebase Storage or Firestore, etc.
      try {
        // Firebase Storage or Firestore calls can be made here to get more data
        // For instance, to fetch a profile picture from Firebase Storage:
        // final profilePicUrl = await FirebaseStorage.instance
        //     .ref('profile_pics/${firebaseUser!.uid}.jpg')
        //     .getDownloadURL();
      } catch (e) {
        print("Error fetching additional data: $e");
      }
    }
  }

// Create a new user with email and password
  Future<String?> createUser(String email, String password) async {
    try {
      // Create the user with email and password
      UserCredential ucr = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      firebaseUser = ucr.user;
      userId = firebaseUser?.uid;
      this.email = firebaseUser?.email;

      // Reload the user to reflect changes
      await firebaseUser?.reload();

      // Return null if no errors
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message; // Return error message if any issue occurs
    }
  }

  Future<String?> signIn(String email, String password) async {
    try {
      UserCredential ucr = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      firebaseUser = ucr.user;
      userId = firebaseUser?.uid;
      this.email = firebaseUser?.email;
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  Future<void> updateNickname(String newNickname) async {
    if (firebaseUser != null && newNickname.isNotEmpty) {
      await firebaseUser!.updateDisplayName(newNickname);
      // Reload the user to reflect the updated display name
      await firebaseUser!.reload();
      firebaseUser = FirebaseAuth.instance.currentUser;
    }
  }

  Future<void> passwordForgotten(email) async {
    await _firebaseAuth.sendPasswordResetEmail(email: email);
  }

  // Log out method
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }
}
