import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../dashboard/home_screen.dart';

class OtpLoginScreen extends StatefulWidget {
  const OtpLoginScreen({super.key});

  @override
  State<OtpLoginScreen> createState() => _OtpLoginScreenState();
}

class _OtpLoginScreenState extends State<OtpLoginScreen> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  bool _codeSent = false;
  bool _isLoading = false;
  String? _message;
  bool _isSuccess = false;

  Future<void> _sendCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() {
        _message = 'Please enter a valid email address';
        _isSuccess = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _message = null;
    });

    final auth = context.read<AuthProvider>();
    final result = await auth.sendLoginOtp(email);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _message = result.message;
      _isSuccess = result.success;
      if (result.success) _codeSent = true;
    });
  }

  Future<void> _verifyCode() async {
    final otp = _otpController.text.trim();
    if (otp.length < 4) {
      setState(() {
        _message = 'Please enter the full verification code';
        _isSuccess = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _message = null;
    });

    final auth = context.read<AuthProvider>();
    final result = await auth.verifyLoginOtp(_emailController.text.trim(), otp);
    if (!mounted) return;

    setState(() => _isLoading = false);

    if (result.success) {
      // Pop back to root router which automatically displays HomeScreen when authenticated
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      setState(() {
        _isSuccess = false;
        _message = result.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log in with OTP Code', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Icon(
                _codeSent ? Icons.mark_email_read_outlined : Icons.lock_clock_outlined,
                size: 64,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                _codeSent ? 'Enter Verification Code' : 'Passwordless Login',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _codeSent
                    ? 'We have sent a 6-digit code to ${_emailController.text.trim()}'
                    : 'Enter your registered email address and we will send you a 1-time login code.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _emailController,
                enabled: !_codeSent,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              if (_codeSent) ...[
                const SizedBox(height: 20),
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, letterSpacing: 8, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    labelText: '6-digit Verification Code',
                    prefixIcon: Icon(Icons.pin_outlined),
                    counterText: '',
                  ),
                ),
              ],
              if (_message != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isSuccess ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isSuccess ? Icons.check_circle_outline : Icons.error_outline,
                        color: _isSuccess ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _message!,
                          style: TextStyle(color: _isSuccess ? Colors.green : Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _isLoading ? null : (_codeSent ? _verifyCode : _sendCode),
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(_codeSent ? 'Verify & Continue' : 'Send One-Time Code'),
              ),
              if (_codeSent) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          setState(() {
                            _codeSent = false;
                            _otpController.clear();
                            _message = null;
                          });
                        },
                  child: const Text('Change Email or Resend'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
