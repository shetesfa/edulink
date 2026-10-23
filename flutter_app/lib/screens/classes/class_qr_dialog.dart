import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ClassQrDialog extends StatelessWidget {
  final String className;
  final String joinCode;

  const ClassQrDialog({super.key, required this.className, required this.joinCode});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Join $className'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: QrImageView(
              // A simple, unambiguous payload: "edulink:class:<code>" - the
              // scanner screen checks for this prefix so it doesn't try to
              // "join a class" with some random QR code found in the wild.
              data: 'edulink:class:$joinCode',
              version: QrVersions.auto,
              size: 220,
            ),
          ),
          const SizedBox(height: 16),
          Text('Or type this code:', style: Theme.of(context).textTheme.bodyMedium),
          Text(joinCode, style: const TextStyle(fontSize: 28, letterSpacing: 4, fontWeight: FontWeight.bold)),
        ],
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
    );
  }
}
