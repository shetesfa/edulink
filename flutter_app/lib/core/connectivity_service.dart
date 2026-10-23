import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityService extends ChangeNotifier {
  bool _isOnline = true;
  bool get isOnline => _isOnline;

  StreamSubscription? _subscription;

  ConnectivityService() {
    _init();
  }

  Future<void> _init() async {
    final result = await Connectivity().checkConnectivity();
    _updateStatus(result);

    _subscription = Connectivity().onConnectivityChanged.listen(_updateStatus);
  }

  void _updateStatus(List<ConnectivityResult> results) {
    final wasOnline = _isOnline;
    _isOnline = !results.contains(ConnectivityResult.none) && results.isNotEmpty;

    if (_isOnline != wasOnline) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
