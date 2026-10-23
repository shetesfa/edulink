import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _tokenController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _codeSent = false;
  bool _isLoading = false;
  String? _message;

  Future<void> _sendCode() async {
    setState(() => _isLoading = true);
    final result = await context.read<AuthProvider>().forgotPassword(_emailController.text.trim());
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _message = result.message;
      if (result.success) _codeSent = true;
    });
  }

  Future<void> _reset() async {
    setState(() => _isLoading = true);
    final result = await context.read<AuthProvider>().resetPassword(
          _emailController.text.trim(),
          _tokenController.text.trim(),
          _passwordController.text,
        );
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _message = result.message;
    });
    if (result.success) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset password')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _emailController,
                enabled: !_codeSent,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
              ),
              if (_codeSent) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _tokenController,
                  decoration: const InputDecoration(labelText: 'Reset code from email', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'New password', border: OutlineInputBorder()),
                ),
              ],
              if (_message != null) ...[
                const SizedBox(height: 8),
                Text(_message!),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _isLoading ? null : (_codeSent ? _reset : _sendCode),
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_codeSent ? 'Reset password' : 'Send reset code'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
