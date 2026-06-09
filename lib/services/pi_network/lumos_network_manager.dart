import 'dart:async';
import 'base_event_model.dart';
import 'lumos_device_scout.dart';
import 'lumos_websocket_client.dart';
import 'lumos_rest_client.dart';

class LumosNetworkManager {
  // Singleton pattern so the entire app shares the same hardware link
  static final LumosNetworkManager _instance = LumosNetworkManager._internal();
  factory LumosNetworkManager() => _instance;
  LumosNetworkManager._internal();

  final LumosDeviceScout _scout = LumosDeviceScout();
  LumosWebSocketClient? _wsClient;
  LumosRestClient? _restClient;
  StreamSubscription<String?>? _scoutSubscription;

  // Broadcasters to let the UI know what the network state is
  final StreamController<BaseEvent> _incomingEventsController = StreamController<BaseEvent>.broadcast();
  final StreamController<bool> _connectionStatusController = StreamController<bool>.broadcast();

  String? _connectedIp;

  // Getters for the UI layer
  Stream<BaseEvent> get piEvents => _incomingEventsController.stream;
  Stream<bool> get isConnectedToPi => _connectionStatusController.stream;
  LumosRestClient? get rest => _restClient;
  String? get connectedIp => _connectedIp;

  /// Initializes the device scout and starts monitoring the hotspot network
  void initialize() {
    _scoutSubscription = _scout.discoveredIp.listen((ip) {
      if (ip != null && ip != _connectedIp) {
        _connectToDevice(ip);
      } else if (ip == null) {
        _handleDisconnect();
      }
    });

    _scout.startDiscovery();
  }

  /// Establishes downstream WebSocket and REST dependencies once an IP is resolved
  Future<void> _connectToDevice(String ip) async {
    print('[NetworkManager] Target IP identified: $ip. Initializing clients...');
    _connectedIp = ip;

    // Clean up previous socket channels if any exist
    _wsClient?.disconnect();

    // Instantiate your audited Copilot modules with the dynamic IP dependency
    _wsClient = LumosWebSocketClient(ipAddress: ip);
    _restClient = LumosRestClient(ipAddress: ip);

    // Relay underlying WebSocket connection updates directly to our master status stream
    _wsClient!.connectionStatus.listen((status) {
      _connectionStatusController.add(status);
    });

    // Relay incoming BaseEvents directly to our global event stream
    _wsClient!.events.listen((event) {
      _incomingEventsController.add(event);
    });

    // Connect the socket pipeline
    await _wsClient!.connect();
  }

  /// Dispatches a command payload down the active WebSocket stream to the Pi
  void sendCommand(String type, Map<String, dynamic> payload, {int priority = 6}) {
    if (_wsClient != null && _wsClient!.isConnected) {
      final command = BaseEvent(
        type: type,
        payload: payload,
        timestamp: DateTime.now().millisecondsSinceEpoch / 1000,
        priority: priority,
      );
      _wsClient!.sendCommand(command);
    } else {
      print('[NetworkManager] Error: Cannot transmit command. Pi connection offline.');
    }
  }

  void _handleDisconnect() {
    _connectedIp = null;
    _connectionStatusController.add(false);
    _wsClient?.disconnect();
    _wsClient = null;
    _restClient = null;
  }

  /// Complete teardown on application exit
  void dispose() {
    _scoutSubscription?.cancel();
    _scout.stopDiscovery();
    _wsClient?.disconnect();
    _incomingEventsController.close();
    _connectionStatusController.close();
  }
}
