import 'package:flutter/material.dart';
import 'screens/login.dart';
import 'screens/users.dart';
import 'screens/chat.dart';

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
        '/users': (context) => const UsersScreen(),
        '/chat': (context) => const ChatScreen(),
      },
    );
  }
}
