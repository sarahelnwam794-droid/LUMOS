import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'base_event_model.dart';

class LumosWebSocketClient {
  final String ipAddress;
  final Uri _uri;
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;

  final _eventController = StreamController<BaseEvent>.broadcast();
  final _connectionStatusController = StreamController<bool>.broadcast();

  bool _isClosed = false;
  bool _isConnected = false;
  int _reconnectAttempt = 0;

  LumosWebSocketClient({required this.ipAddress}) : _uri = Uri.parse('ws://$ipAddress:5000/ws');

  Stream<BaseEvent> get events => _eventController.stream;
  Stream<bool> get connectionStatus => _connectionStatusController.stream;
  bool get isConnected => _isConnected;

  Future<void> connect() async {
    if (_isClosed) {
      throw StateError('LumosWebSocketClient has been closed and cannot reconnect.');
    }

    if (_channel != null) {
      return;
    }

    await _openChannel();
  }

  Future<void> _openChannel() async {
    try {
      _channel = IOWebSocketChannel.connect(_uri);
      _setConnected(true);
      _subscription = _channel!.stream.listen(
        _handleIncomingMessage,
        onDone: _handleConnectionClosed,
        onError: _handleConnectionError,
        cancelOnError: true,
      );
    } catch (error, stackTrace) {
      _setConnected(false);
      _scheduleReconnect();
      print('LumosWebSocketClient failed to connect: $error');
      print(stackTrace);
    }
  }

  void sendCommand(BaseEvent command) {
    if (_channel == null) {
      throw StateError('WebSocket is not connected. Call connect() first.');
    }

    try {
      _channel!.sink.add(jsonEncode(command.toJson()));
    } catch (error, stackTrace) {
      print('LumosWebSocketClient.sendCommand error: $error');
      print(stackTrace);
      _scheduleReconnect();
    }
  }

  void _handleIncomingMessage(dynamic rawMessage) {
    if (rawMessage is! String) {
      return;
    }

    try {
      final decoded = jsonDecode(rawMessage);
      if (decoded is Map<String, dynamic>) {
        final event = BaseEvent.fromJson(decoded);
        _eventController.add(event);
      } else {
        print('LumosWebSocketClient received non-JSON object: $rawMessage');
      }
    } on FormatException catch (error) {
      print('LumosWebSocketClient JSON parse error: $error');
    } catch (error, stackTrace) {
      print('LumosWebSocketClient unexpected message error: $error');
      print(stackTrace);
    }
  }

  void _handleConnectionClosed() {
    _setConnected(false);
    if (!_isClosed) {
      _scheduleReconnect();
    }
  }

  void _handleConnectionError(Object error, StackTrace stackTrace) {
    _setConnected(false);
    print('LumosWebSocketClient connection error: $error');
    print(stackTrace);
    if (!_isClosed) {
      _scheduleReconnect();
    }
  }

  void _setConnected(bool value) {
    _isConnected = value;
    if (!_connectionStatusController.isClosed) {
      _connectionStatusController.add(value);
    }
  }

  void _scheduleReconnect() {
    if (_isClosed) {
      return;
    }

    _reconnectTimer?.cancel();
    _reconnectAttempt = (_reconnectAttempt + 1).clamp(1, 6);
    final delaySeconds = [2, 4, 8, 15, 30, 30][_reconnectAttempt - 1];
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      if (_isClosed) {
        return;
      }
      _disposeChannel();
      _openChannel();
    });
  }

  Future<void> disconnect() async {
    _isClosed = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _disposeChannel();
    await _connectionStatusController.close();
  }

  void _disposeChannel() {
    _subscription?.cancel();
    _subscription = null;
    try {
      _channel?.sink.close();
    } catch (_) {
      // ignore sink close errors
    }
    _channel = null;
  }

  Future<void> dispose() async {
    _isClosed = true;
    _reconnectTimer?.cancel();
    _disposeChannel();
    await _eventController.close();
    await _connectionStatusController.close();
  }
}
