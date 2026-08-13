import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_logger.dart';

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
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _patientEmailController = TextEditingController();

  String _role = 'PATIENT';
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _patientEmailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final patientEmail = _patientEmailController.text.trim();

    if (firstName.isEmpty || lastName.isEmpty) {
      setState(() => _error = 'Please enter your first and last name.');
      return;
    }
    if (_role == 'CAREGIVER' && patientEmail.isEmpty) {
      setState(() => _error = "Please enter the patient's email.");
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final idToken = await _authService.idToken();
      if (idToken == null) throw Exception('Not signed in');
      await _apiService.registerBackendUser(
        idToken,
        _role,
        firstName,
        lastName,
        patientEmail: _role == 'CAREGIVER' ? patientEmail : null,
      );
      widget.onRegistered();
    } catch (e) {
      AppLogger.error('Registration failed', e, 'Auth');
      if (!mounted) return;
      setState(() => _error = _friendlyMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyMessage(Object e) {
    // ApiException carries the backend's actual reason (e.g. "This account is
    // already registered" vs "A patient is already registered for this
    // pillbox" are both 409s but mean different things) — show it directly
    // instead of guessing generic text from the status code alone.
    if (e is ApiException) return e.message;
    return 'Something went wrong. Please check your connection and try again.';
  }

  @override
  Widget build(BuildContext context) {
    final isCaregiver = _role == 'CAREGIVER';
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
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _firstNameController,
                          decoration: const InputDecoration(labelText: 'First name'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: TextField(
                          controller: _lastNameController,
                          decoration: const InputDecoration(labelText: 'Last name'),
                        ),
                      ),
                    ],
                  ),
                  if (isCaregiver) ...[
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: _patientEmailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: "Patient's email",
                        helperText: "The email of the patient you're caring for",
                      ),
                    ),
                  ],
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
