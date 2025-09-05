import 'package:chat_app/home.dart';
import 'package:chat_app/signup.dart';
import 'package:chat_app/sign_in.dart';
import 'package:chat_app/profile.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: const Color(0xFF5DE6C0),
      ),

      initialRoute: "/signup",

      routes: {
        "/signup": (context) => Signup(),
        "/signin": (context) => SignIn(),
        "/profile": (context) => ProfilePage(),
        "/home": (context) => const HomePage(),
      },
    );
  }
}


