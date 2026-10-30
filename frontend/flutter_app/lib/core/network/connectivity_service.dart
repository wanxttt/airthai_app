import 'dart:async';
import 'api_client.dart';

/// Connectivity monitoring service.
///
/// Dispatches connection change events and supports offline simulation
/// for testing and network toggling.
class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  bool _isOnline = true;
  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  bool get isOnline => _isOnline;
  Stream<bool> get onConnectivityChanged => _controller.stream;

  /// Sets connectivity state explicitly (useful for offline simulation, unit & widget testing).
  void setMockOnline(bool online) {
    if (_isOnline != online) {
      _isOnline = online;
      _controller.add(_isOnline);
    }
  }

  /// Verifies connectivity by checking backend reachability.
  Future<bool> checkConnection() async {
    try {
      final res = await ApiClient.instance.get('/api/v1/health');
      final online = res.statusCode >= 200 && res.statusCode < 400;
      setMockOnline(online);
      return online;
    } catch (_) {
      setMockOnline(false);
      return false;
    }
  }

  void dispose() {
    _controller.close();
  }
}

