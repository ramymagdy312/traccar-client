import 'package:flutter/material.dart';

import '../screens/home_shell.dart';
import 'auth_storage.dart';
import 'login_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  Future<String?>? _tokenFuture;

  @override
  void initState() {
    super.initState();
    _tokenFuture = const AuthStorage().readAccessToken();
  }

  void _onLoginSuccess() {
    setState(() {
      _tokenFuture = const AuthStorage().readAccessToken();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _tokenFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final token = snapshot.data;
        if (token == null || token.isEmpty) {
          return LoginScreen(onLoginSuccess: _onLoginSuccess);
        }

        return const HomeShell();
      },
    );
  }
}

