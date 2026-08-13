import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class CompleteRegistrationScreen extends StatefulWidget {
  final VoidCallback onRegistered;

  const CompleteRegistrationScreen({super.key, required this.onRegistered});

  @override
  State<CompleteRegistrationScreen> createState() =>
      _CompleteRegistrationScreenState();
}

class _CompleteRegistrationScreenState
    extends State<CompleteRegistrationScreen> {
  final AuthService _authService = AuthService();
  final ApiService _apiService = ApiService();
  final _usernameController = TextEditingController();

  String _role = 'PATIENT';
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      setState(() => _error = 'Please enter your name.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final idToken = await _authService.idToken();
      if (idToken == null) throw Exception('Not signed in');
      await _apiService.registerBackendUser(idToken, _role, username);
      widget.onRegistered();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _friendlyMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyMessage(Object e) {
    final s = '$e';
    if (s.contains('409')) {
      return 'A patient is already registered for this pillbox. Choose "Caregiver" instead.';
    }
    return 'Something went wrong. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Your Profile'),
        actions: [
          TextButton(
            onPressed: _loading ? null : () => _authService.signOut(),
            child: const Text('Log Out'),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Who are you?', style: AppTextStyles.h2, textAlign: TextAlign.center),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'This decides what you can see and do in Medify.',
                    style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'PATIENT',
                        label: Text('Patient'),
                        icon: Icon(Icons.person_outline),
                      ),
                      ButtonSegment(
                        value: 'CAREGIVER',
                        label: Text('Caregiver'),
                        icon: Icon(Icons.supervisor_account_outlined),
                      ),
                    ],
                    selected: {_role},
                    onSelectionChanged: (selection) =>
                        setState(() => _role = selection.first),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  TextField(
                    controller: _usernameController,
                    decoration: const InputDecoration(labelText: 'Your name'),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(_error!, style: TextStyle(color: AppColors.error)),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Continue'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
