import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/api_config.dart';

/// Opens Google's login inside the app (no separate browser, no native
/// OAuth SDK/deep-link setup needed). When Google redirects back to our
/// Laravel backend's callback URL, the backend returns raw JSON (since it's
/// built API-first) - we detect that URL and read the page's JSON text
/// directly out of the WebView to get the token and user.
class GoogleSignInWebView extends StatefulWidget {
  const GoogleSignInWebView({super.key});

  @override
  State<GoogleSignInWebView> createState() => _GoogleSignInWebViewState();
}

class _GoogleSignInWebViewState extends State<GoogleSignInWebView> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final authUrl = '${ApiConfig.baseDomain}/api/auth/google';
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent("Mozilla/5.0 (Linux; Android 13; SM-A245F) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Mobile Safari/537.36")
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (url) {
          if (mounted) setState(() => _isLoading = true);
        },
        onPageFinished: (url) async {
          if (mounted) setState(() => _isLoading = false);
          if (url.contains('/auth/google/callback')) {
            await _extractTokenFromPage();
          }
        },
        onWebResourceError: (error) {
          if (mounted && !error.url!.contains('/auth/google')) {
            setState(() {
              _errorMessage = 'Failed to load Google Auth: ${error.description}';
              _isLoading = false;
            });
          }
        },
      ))
      ..loadRequest(Uri.parse(authUrl));
  }

  Future<void> _extractTokenFromPage() async {
    try {
      final raw = await _controller.runJavaScriptReturningResult('document.body.innerText') as String;
      String cleaned = raw.trim();
      if (cleaned.startsWith('"') && cleaned.endsWith('"')) {
        cleaned = jsonDecode(cleaned);
      }
      final body = jsonDecode(cleaned);

      if (body is Map<String, dynamic> && body['success'] == true && mounted) {
        Navigator.of(context).pop(body);
      } else if (mounted && body is Map<String, dynamic> && body['message'] != null) {
        setState(() => _errorMessage = body['message'].toString());
      }
    } catch (_) {
      // Retrying when DOM is completely ready
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign in with Google', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const LinearProgressIndicator(),
          if (_errorMessage != null)
            Center(
              child: Card(
                margin: const EdgeInsets.all(24),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                      const SizedBox(height: 16),
                      Text(_errorMessage!, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(null),
                        child: const Text('Go Back'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
