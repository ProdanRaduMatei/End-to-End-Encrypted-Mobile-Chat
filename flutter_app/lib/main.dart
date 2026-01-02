import 'package:flutter/material.dart';
import 'screens/login.dart';
import 'screens/chat.dart';
import 'screens/connections.dart';
import 'screens/verify_key.dart';

void main() {
  runApp(const MiniSignalApp());
}

class MiniSignalApp extends StatelessWidget {
  const MiniSignalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mini-Signal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginScreen(),
        '/connections': (context) => const ConnectionsScreen(),
        '/verify': (context) => const VerifyKeyScreen(),
        '/chat': (context) => const ChatScreen(),
      },
    );
  }
}
