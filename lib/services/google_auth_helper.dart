import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

Future<UserCredential> signInWithGoogle() async {
  await _googleSignIn.initialize();

  final GoogleSignInAccount googleUser =
  await _googleSignIn.authenticate();

  final GoogleSignInAuthentication googleAuth =
  await googleUser.authentication;

  final credential = GoogleAuthProvider.credential(
    idToken: googleAuth.idToken,
  );

  return FirebaseAuth.instance.signInWithCredential(credential);
}
