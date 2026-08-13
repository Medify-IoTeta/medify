import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'auth_screen.dart';
import 'caregiver_screen.dart';
import 'complete_registration_screen.dart';
import 'home_screen.dart';

/// App root: routes between signed-out, mid-registration, patient and
/// caregiver based on Firebase auth state + the backend's /api/auth/me.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final AuthService _authService = AuthService();
  final ApiService _apiService = ApiService();

  Future<Map<String, dynamic>?>? _meFuture;
  String? _lastUid;

  void _refreshMe() {
    setState(() => _meFuture = _apiService.getCurrentBackendUser());
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authService.authStateChanges,
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScaffold();
        }

        final user = authSnapshot.data;
        if (user == null) {
          _meFuture = null;
          _lastUid = null;
          return const AuthScreen();
        }

        if (_meFuture == null || _lastUid != user.uid) {
          _lastUid = user.uid;
          _meFuture = _apiService.getCurrentBackendUser();
        }

        return FutureBuilder<Map<String, dynamic>?>(
          future: _meFuture,
          builder: (context, meSnapshot) {
            if (meSnapshot.connectionState == ConnectionState.waiting) {
              return const _LoadingScaffold();
            }
            if (meSnapshot.hasError) {
              return _ErrorScaffold(
                message: '${meSnapshot.error}',
                onRetry: _refreshMe,
              );
            }

            final me = meSnapshot.data;
            if (me == null) {
              return CompleteRegistrationScreen(onRegistered: _refreshMe);
            }

            if (me['type'] == 'CAREGIVER') {
              return CaregiverScreen(userId: (me['id'] as num).toInt());
            }
            return const HomeScreen();
          },
        );
      },
    );
  }
}

class _LoadingScaffold extends StatelessWidget {
  const _LoadingScaffold();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _ErrorScaffold extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorScaffold({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
