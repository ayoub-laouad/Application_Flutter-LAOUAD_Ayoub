import 'package:flutter/material.dart';
import 'package:flutter_formulaire/SignIn.dart';
import 'package:flutter_formulaire/SignUp.dart';
import 'package:flutter_formulaire/HomeScreen.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MainApp());
} 

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      routes: {
        '/signIn': (context) => const SignIn(),
        '/signUp': (context) => const SignUp(),
        '/home': (context) => const HomeScreen(),
      },
      debugShowCheckedModeBanner: false,
      title: 'Formulaire Flutter',
      home: const SignIn(),
    );
  }
}

