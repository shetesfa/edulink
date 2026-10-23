import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'role_picker_screen.dart';

class VerifyEmailScreen extends StatefulWidget {
  final String email;
  final String? debugOtp;
  const VerifyEmailScreen({super.key, required this.email, this.debugOtp});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _otpController = TextEditingController();
  bool _isLoading = false;
  bool _isResending = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _resendCode() async {
    setState(() { _isResending = true; _errorMessage = null; });
    final result = await context.read<AuthProvider>().resendVerificationOtp(widget.email);
    if (!mounted) return;
    setState(() {
      _isResending = false;
      _errorMessage = result.success ? null : result.message;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
  }

  Future<void> _handleVerify() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final auth = context.read<AuthProvider>();
    final result = await auth.verifyEmail(widget.email, _otpController.text.trim());

    if (!mounted) return;

    if (result.success) {
      // Show role picker after registration verification
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const RolePickerScreen()),
        (route) => false,
      );
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = result.message;
      });
    }
    // On success, AuthProvider's status change automatically navigates
    // the app to the home screen via the listener in main.dart.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify your email')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('We sent a 6-digit code to ${widget.email}. Enter it below.',
                  style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 24),
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 28, letterSpacing: 8),
                decoration: const InputDecoration(counterText: '', border: OutlineInputBorder()),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _isLoading ? null : _handleVerify,
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Verify'),
              ),
              TextButton(
                onPressed: _isResending ? null : _resendCode,
                child: Text(_isResending ? 'Sending code...' : 'Resend code'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
