import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
<<<<<<< HEAD
import 'package:cloud_functions/cloud_functions.dart';
=======
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c

import '../models/app_user.dart';

class AuthService {
<<<<<<< HEAD
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
=======
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c

  Stream<User?> authChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

<<<<<<< HEAD
  Future<void> signInWithEmail(String email, String password) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
=======
  Future<void> signInWithEmail(String email, String password) async {
    final String normalizedEmail = email.trim().toLowerCase();
    final String normalizedPassword = password.trim();

    final UserCredential credential = await _auth.signInWithEmailAndPassword(
      email: normalizedEmail,
      password: normalizedPassword,
    );

    final User? user = credential.user;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'invalid-credential',
        message: 'Login did not return a Firebase user.',
      );
    }

    final DocumentReference<Map<String, dynamic>> userRef = _firestore
        .collection('users')
        .doc(user.uid);
    final DocumentSnapshot<Map<String, dynamic>> userDoc = await userRef.get();

    if (!userDoc.exists) {
      await userRef.set(<String, dynamic>{
        'uid': user.uid,
        'email': normalizedEmail,
        'name': user.displayName ?? 'New User',
        'role': UserRole.citizen.name,
        'created_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
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

<<<<<<< HEAD
=======
      final AppUser? workerByEmail = await _resolveWorkerByEmail(user.email);
      if (workerByEmail != null) {
        await _ensureWorkerUserDocument(workerByEmail, authUid: user.uid);
        return AppUser(
          uid: user.uid,
          email: user.email,
          role: UserRole.worker,
          name: workerByEmail.name,
          phone: workerByEmail.phone,
          zone: workerByEmail.zone,
        );
      }

>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
      final AppUser fallback = AppUser(
        uid: user.uid,
        email: user.email,
        role: UserRole.citizen,
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

<<<<<<< HEAD
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

=======
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
  Future<AppUser?> workerLogin({
    required String workerId,
    required String password,
  }) async {
<<<<<<< HEAD
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
=======
    final String normalizedWorkerId = workerId.trim().toUpperCase();
    if (normalizedWorkerId.isEmpty || password.trim().isEmpty) {
      throw FirebaseAuthException(
        code: 'invalid-credential',
        message: 'Worker ID and password are required.',
      );
    }

    final DocumentSnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('workers')
        .doc(normalizedWorkerId)
        .get();

    if (!snapshot.exists) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'Worker ID not found.',
      );
    }

    final Map<String, dynamic> workerData = snapshot.data()!;
    final String storedPassword = (workerData['password'] as String? ?? '')
        .trim();
    if (storedPassword != password.trim()) {
      throw FirebaseAuthException(
        code: 'wrong-password',
        message: 'Incorrect password.',
      );
    }

    final AppUser appUser = AppUser(
      uid: snapshot.id,
      email: workerData['email'] as String?,
      role: UserRole.worker,
      name: workerData['name'] as String?,
      phone: workerData['phone'] as String?,
      zone: workerData['zone'] as String?,
    );
    return appUser;
  }

  Future<AppUser?> workerLoginWithId(String workerId) async {
    final String normalizedWorkerId = workerId.trim().toUpperCase();
    if (normalizedWorkerId.isEmpty) {
      throw FirebaseAuthException(
        code: 'invalid-credential',
        message: 'Worker ID is required.',
      );
    }

    final DocumentSnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('workers')
        .doc(normalizedWorkerId)
        .get();

    if (!snapshot.exists) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'Worker ID not found.',
      );
    }

    final Map<String, dynamic> workerData = snapshot.data()!;
    return AppUser(
      uid: snapshot.id,
      email: workerData['email'] as String?,
      role: UserRole.worker,
      name: workerData['name'] as String?,
      phone: workerData['phone'] as String?,
      zone: workerData['zone'] as String?,
    );
  }

  Future<AppUser?> _resolveWorkerByEmail(String? email) async {
    final String normalized = (email ?? '').trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }

    final QuerySnapshot<Map<String, dynamic>> query = await _firestore
        .collection('workers')
        .where('email', isEqualTo: normalized)
        .limit(1)
        .get();
    if (query.docs.isEmpty) {
      return null;
    }

    final Map<String, dynamic> workerData = query.docs.first.data();
    return AppUser(
      uid: query.docs.first.id,
      email: normalized,
      role: UserRole.worker,
      name: workerData['name'] as String?,
      phone: workerData['phone'] as String?,
      zone: workerData['zone'] as String?,
    );
  }

  Future<void> _ensureWorkerUserDocument(
    AppUser worker, {
    required String authUid,
  }) {
    return _firestore.collection('users').doc(authUid).set(<String, dynamic>{
      'uid': authUid,
      'email': worker.email,
      'name': worker.name,
      'phone': worker.phone,
      'role': UserRole.worker.name,
      'zone': worker.zone,
      'avatar_emoji': '',
      'profile_picture': '',
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
  }
}
