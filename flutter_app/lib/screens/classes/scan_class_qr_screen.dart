import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../providers/class_provider.dart';

class ScanClassQrScreen extends StatefulWidget {
  const ScanClassQrScreen({super.key});

  @override
  State<ScanClassQrScreen> createState() => _ScanClassQrScreenState();
}

class _ScanClassQrScreenState extends State<ScanClassQrScreen> {
  bool _handled = false;

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handled) return;

    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || !raw.startsWith('edulink:class:')) return;

    _handled = true;
    final joinCode = raw.replaceFirst('edulink:class:', '');

    final result = await context.read<ClassProvider>().joinClass(joinCode);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
    if (result.success) {
      Navigator.of(context).pop();
    } else {
      _handled = false; // let them try scanning again if it failed
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan class QR code')),
      body: Stack(
        children: [
          MobileScanner(onDetect: _onDetect),
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: Text(
              'Point your camera at the class QR code',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 16, shadows: [Shadow(blurRadius: 4, color: Colors.black)]),
            ),
          ),
        ],
      ),
    );
  }
}
