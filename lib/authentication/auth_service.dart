import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/app_user.dart';

class AuthService {
  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  Stream<User?> authChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<void> signInWithEmail(String email, String password) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signInAdmin(String email, String password) async {
    final UserCredential credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final User? user = credential.user;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'admin-login-failed',
        message: 'Unable to sign in admin.',
      );
    }

    final DocumentSnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .get();
    final String role = (snapshot.data()?['role'] as String? ?? '')
        .toLowerCase();
    if (role != UserRole.admin.name) {
      await _auth.signOut();
      throw FirebaseAuthException(
        code: 'not-admin',
        message: 'This account is not an admin account.',
      );
    }
  }

  Future<void> signUpCitizen(String email, String password, String name) async {
    final UserCredential credential = await _auth
        .createUserWithEmailAndPassword(email: email, password: password);

    final User user = credential.user!;
    await _firestore.collection('users').doc(user.uid).set(<String, dynamic>{
      'uid': user.uid,
      'email': email,
      'name': name,
      'role': UserRole.citizen.name,
      'phone': '',
      'avatar_emoji': '',
      'created_at': FieldValue.serverTimestamp(),
      'age': null,
      'gender': '',
      'profile_picture': '',
    }, SetOptions(merge: true));
  }

  Future<void> signOut() => _auth.signOut();

  Future<AppUser> getCurrentAppUser() async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user');
    }

    final DocumentSnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .get();

    if (!snapshot.exists) {
      final IdTokenResult tokenResult = await user.getIdTokenResult();
      final String roleClaim = (tokenResult.claims?['role'] as String? ?? '')
          .toLowerCase();
      if (roleClaim == UserRole.worker.name) {
        final String workerDocId =
            tokenResult.claims?['worker_doc_id'] as String? ?? user.uid;
        final DocumentSnapshot<Map<String, dynamic>> workerDoc =
            await _firestore.collection('workers').doc(workerDocId).get();
        final Map<String, dynamic> workerData =
            workerDoc.data() ?? <String, dynamic>{};
        return AppUser(
          uid: workerDocId,
          email: user.email,
          role: UserRole.worker,
          name: workerData['name'] as String?,
          phone: workerData['phone'] as String?,
          zone: workerData['zone'] as String?,
        );
      }

      final AppUser fallback = AppUser(
        uid: user.uid,
        email: user.email,
        role: roleClaim == UserRole.admin.name
            ? UserRole.admin
            : UserRole.citizen,
        name: user.displayName,
      );
      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(fallback.toMap(), SetOptions(merge: true));
      return fallback;
    }

    return AppUser.fromMap(user.uid, snapshot.data()!);
  }

  Future<void> verifyPhoneNumber({
    required String phone,
    required void Function(PhoneAuthCredential credential)
    verificationCompleted,
    required void Function(FirebaseAuthException e) verificationFailed,
    required void Function(String verificationId, int? resendToken) codeSent,
    required void Function(String verificationId) codeAutoRetrievalTimeout,
  }) {
    return _auth.verifyPhoneNumber(
      phoneNumber: phone,
      timeout: const Duration(seconds: 60),
      verificationCompleted: verificationCompleted,
      verificationFailed: verificationFailed,
      codeSent: codeSent,
      codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
    );
  }

  Future<void> signInWithPhoneCredential(PhoneAuthCredential credential) {
    return _auth.signInWithCredential(credential);
  }

  Future<AppUser?> workerLogin({
    required String workerId,
    required String password,
  }) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('workerLogin');
      final HttpsCallableResult<dynamic> result = await callable.call(
        <String, dynamic>{'workerId': workerId, 'password': password},
      );
      final Map<String, dynamic> payload = Map<String, dynamic>.from(
        result.data as Map,
      );
      final String token = payload['token'] as String? ?? '';
      if (token.isEmpty) {
        return null;
      }

      await _auth.signInWithCustomToken(token);

      final Map<String, dynamic> worker = Map<String, dynamic>.from(
        payload['worker'] as Map? ?? <String, dynamic>{},
      );

      return AppUser(
        uid: worker['doc_id'] as String? ?? '',
        email: worker['email'] as String?,
        role: UserRole.worker,
        name: worker['name'] as String?,
        phone: worker['phone'] as String?,
        zone: worker['zone'] as String?,
      );
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'resource-exhausted') {
        throw FirebaseAuthException(
          code: 'too-many-requests',
          message: e.message ?? 'Too many attempts. Try again later.',
        );
      }
      return null;
    } on FirebaseAuthException {
      return null;
    }
  }
}
