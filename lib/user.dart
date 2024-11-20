import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kwf_energiemonitor/monitor.dart';

class AppUser {
  static final AppUser _singleton = AppUser._internal();
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  User? firebaseUser;
  String? userId;
  String? email;
  int _activeMonitorRead = 0;
  List<EnergieMonitor> monitorRead = [];
  List<EnergieMonitor> monitorEdit = [];

  // Private constructor for Singleton
  AppUser._internal();

  // Remove all user data
  AppUser.init() {
    firebaseUser = null;
    userId = null;
    email = null;
    _activeMonitorRead = 0;
    monitorRead = [];
    monitorEdit = [];
  }

  // Public getters
  bool get isLoggedIn => firebaseUser != null;
  String? get nickname => firebaseUser?.displayName;
  int get activeMonitorRead => _activeMonitorRead;
  EnergieMonitor? get activeMonitor =>
      monitorRead.isEmpty ? null : monitorRead[_activeMonitorRead];

  // Factory constructor to access the singleton instance
  factory AppUser() {
    return _singleton;
  }

  // Switch the monitor that is displayed for this user
  void changeActiveMonitorRead() {
    _activeMonitorRead += 1;

    if (_activeMonitorRead > monitorRead.length - 1) {
      _activeMonitorRead = 0;
    }
  }

  // Method to initialize the user from Firebase Auth
  Future<void> init() async {
    final currentUser = _firebaseAuth.currentUser;
    if (currentUser != null) {
      firebaseUser = currentUser;
      userId = currentUser.uid;
      email = currentUser.email;
      await fetchAdditionalUserData();
    }
  }

  // For data stored outside of firebase auth
  Future<void> fetchAdditionalUserData() async {
    if (firebaseUser != null) {
      // Fetch user data from Firebase Storage or Firestore, etc.
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();

        if (userDoc.exists) {
          // Retrieve the data as a Map
          Map<String, dynamic> userData =
              userDoc.data() as Map<String, dynamic>;

          final editIds = userData['monitor_edit'];
          final readIds = userData['monitor_read'];

          // Fetch the monitor data for this user
          for (String id in readIds) {
            final emon = await fetchMonitor(id);
            if (emon != null) {
              monitorRead.add(emon);
            } else {
              print("Error: Energiemonitor not found!");
            }
          }

          for (String id in editIds) {
            final emon = await fetchMonitor(id);
            if (emon != null) {
              monitorEdit.add(emon);
            } else {
              print("Error: Energieonitor not found!");
            }
          }
        } else {
          throw Exception("No user document found for user $userId");
        }
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

      // Create user in database with a specific ID
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId) // Set the document ID to userId
          .set({
        'user_id': userId,
        'monitor_read': [],
        'monitor_edit': [],
        'date_created': DateTime.now()
      });

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
      await fetchAdditionalUserData();
      return null;
    } on Exception catch (e) {
      return e.toString();
    }
  }

  Future<String?> updateNickname(String newNickname) async {
    if (firebaseUser != null && newNickname.isNotEmpty) {
      try {
        await firebaseUser!.updateDisplayName(newNickname);

        // Also update custom user db
        await FirebaseFirestore.instance.collection('users').doc(userId).update(
            {'user_name': newNickname, 'nickname_changed': DateTime.now()});

        // Reload the user to reflect the updated display name
        await firebaseUser!.reload();
        firebaseUser = FirebaseAuth.instance.currentUser;

        return null;
      } on Exception catch (e) {
        return e.toString();
      }
    }
    return null;
  }

  Future<void> passwordForgotten(email) async {
    await _firebaseAuth.sendPasswordResetEmail(email: email);
  }

  // Log out method
  Future<void> signOut() async {
    await _firebaseAuth.signOut();

    // Remove all user data
    init();
  }
}
