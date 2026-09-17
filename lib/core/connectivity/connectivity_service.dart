import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityService extends ChangeNotifier {
  final Connectivity _connectivity;
  bool _isOnline = true;

  bool get isOnline => _isOnline;

  ConnectivityService({Connectivity? connectivity, bool initialize = true})
      : _connectivity = connectivity ?? Connectivity() {
    if (initialize) {
      _init();
    }
  }

  Future<void> _init() async {
    final result = await _connectivity.checkConnectivity();
    _isOnline = _hasConnection(result);
    notifyListeners();

    _connectivity.onConnectivityChanged.listen((results) {
      final wasOnline = _isOnline;
      _isOnline = _hasConnection(results);
      if (wasOnline != _isOnline) {
        notifyListeners();
      }
    });
  }

  Future<bool> checkOnline() async {
    final result = await _connectivity.checkConnectivity();
    _isOnline = _hasConnection(result);
    return _isOnline;
  }

  bool _hasConnection(List<ConnectivityResult> results) {
    return results.any((r) =>
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.ethernet);
  }
}
