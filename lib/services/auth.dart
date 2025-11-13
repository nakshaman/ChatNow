import 'package:chats/pages/home.dart';
import 'package:chats/services/database.dart';
import 'package:chats/services/shared_preferances.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthMethods {
  final FirebaseAuth firebaseAuth = FirebaseAuth.instance;

  // Get current logged in user
  Future<User?> getCurrentUser(BuildContext context) async {
    return firebaseAuth.currentUser;
  }

  // Sign in with Google
  signInWithGoogle(BuildContext context) async {
    try {
      final FirebaseAuth firebaseAuth = FirebaseAuth.instance;
      final GoogleSignInAccount? googleSignIn = await GoogleSignIn().signIn();
      if (googleSignIn == null) return; // user canceled

      final GoogleSignInAuthentication googleSignInAuthentication =
          await googleSignIn.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleSignInAuthentication.accessToken,
        idToken: googleSignInAuthentication.idToken,
      );

      UserCredential result = await firebaseAuth.signInWithCredential(
        credential,
      );
      // ignore: unused_local_variable
      User? userDetails = result.user;
      String userName = userDetails!.email!.replaceAll("@gmail.com", "");
      String firstLetter = userName.substring(0, 1).toUpperCase();
      await SharedPreferancesData().saveUserDisplayName(
        userDetails.displayName!,
      );
      await SharedPreferancesData().saveUserEmail(userDetails.email!);
      await SharedPreferancesData().saveUserName(userName);
      await SharedPreferancesData().saveUserId(userDetails.uid);
      await SharedPreferancesData().saveUserImage(userDetails.photoURL!);
      // ignore: unnecessary_null_comparison
      if (result != null) {
        Map<String, dynamic> userDetailsMap = {
          "Name": userDetails.displayName,
          "Email": userDetails.email,
          "Image": userDetails.photoURL,
          "Id": userDetails.uid,
          "username": userName.toUpperCase(),
          "SearchKey": firstLetter,
        };
        await DatabaseMethods().addUser(userDetailsMap, userDetails.uid).then((
          value,
        ) {
          // ignore: use_build_context_synchronously
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: Duration(seconds: 5),
              content: Center(
                child: Text(
                  "Welcome ${userDetails.displayName}",
                  style: TextStyle(
                    fontSize: 20,
                    fontStyle: FontStyle.italic,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 10.0,
              margin: EdgeInsets.all(12),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => Home()),
          );
        });
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }
}
