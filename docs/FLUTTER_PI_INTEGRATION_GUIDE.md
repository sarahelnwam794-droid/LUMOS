# Flutter Pi Integration Guide

## 1. Architecture Overview

`LumosNetworkManager` is the single entry point for Pi connectivity in the Flutter app. It is implemented as a singleton so the UI can share one consistent hardware link across the application.

It handles:
- mDNS discovery through `LumosDeviceScout`
- WebSocket connection and message flow through `LumosWebSocketClient`
- REST heavy-data transfers through `LumosRestClient`

The UI should only use `LumosNetworkManager()` and should not manually instantiate the lower-level network clients.

## 2. Initialization

Initialize the network manager early in app startup, before the first screen needs Pi data.

### Example in `main.dart`

```dart
import 'package:flutter/material.dart';
import 'package:lumos/services/pi_network/lumos_network_manager.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  LumosNetworkManager().initialize();
  runApp(const MyApp());
}
```

### Dispose when the app shuts down

Dispose the singleton when your root widget is destroyed so the discovery stream and WebSocket are cleaned up.

```dart
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void dispose() {
    LumosNetworkManager().dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: HomeScreen(),
    );
  }
}
```

> Note: Because `LumosNetworkManager` is a singleton, calling `LumosNetworkManager()` anywhere in the app returns the same shared instance.

## 3. UI Connection Status

Use `StreamBuilder` to render a live Pi connection badge from `isConnectedToPi`.

```dart
import 'package:flutter/material.dart';
import 'package:lumos/services/pi_network/lumos_network_manager.dart';

class PiConnectionBadge extends StatelessWidget {
  const PiConnectionBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: LumosNetworkManager().isConnectedToPi,
      initialData: false,
      builder: (context, snapshot) {
        final connected = snapshot.data == true;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.circle,
              color: connected ? Colors.green : Colors.red,
              size: 12,
            ),
            const SizedBox(width: 8),
            Text(
              connected ? 'Pi Connected' : 'Pi Offline',
              style: TextStyle(
                color: connected ? Colors.green : Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      },
    );
  }
}
```

## 4. Sending Commands (App to Pi)

Send commands through `LumosNetworkManager().sendCommand()` once the Pi is connected.

```dart
ElevatedButton(
  onPressed: () {
    LumosNetworkManager().sendCommand(
      'INTENT_ENROLL',
      {'name': 'Abdullah'},
      priority: 6,
    );
  },
  child: const Text('Enroll Abdullah'),
)
```

This constructs a `BaseEvent` and sends it over the active WebSocket channel.

## 5. Listening to Events (Pi to App)

Use `piEvents` to receive Pi-to-app messages. Filter the event stream by type before rendering.

```dart
import 'package:flutter/material.dart';
import 'package:lumos/services/pi_network/base_event_model.dart';
import 'package:lumos/services/pi_network/lumos_network_manager.dart';

class EnrollmentProgressIndicator extends StatelessWidget {
  const EnrollmentProgressIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<BaseEvent>(
      stream: LumosNetworkManager()
          .piEvents
          .where((event) => event.type == 'ENROLLMENT_PROGRESS'),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(height: 4);
        }

        final payload = snapshot.data!.payload;
        final progress = (payload['progress'] as num?)?.toDouble() ?? 0.0;

        return LinearProgressIndicator(
          value: progress.clamp(0.0, 1.0),
          minHeight: 6,
          backgroundColor: Colors.grey.shade300,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
        );
      },
    );
  }
}
```

This example expects the Pi to send events with `type == 'ENROLLMENT_PROGRESS'` and a numeric `progress` field in the `payload`.

## 6. Using the REST Client (Heavy Data)

`LumosNetworkManager().rest` is the REST client instance tied to the current Pi IP. It may be `null` if the Pi is disconnected, so guard against that in the UI.

```dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:lumos/services/pi_network/lumos_network_manager.dart';

class LatestSceneWidget extends StatelessWidget {
  const LatestSceneWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final restClient = LumosNetworkManager().rest;

    return FutureBuilder<Uint8List?>(
      future: restClient?.fetchLatestScene(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (restClient == null) {
          return const Text('Pi disconnected. Scene unavailable.');
        }

        if (snapshot.hasError || snapshot.data == null) {
          return const Text('Failed to load scene.');
        }

        return Image.memory(
          snapshot.data!,
          fit: BoxFit.cover,
        );
      },
    );
  }
}
```

> Tip: Call `fetchLatestScene()` only when the Pi is connected. If the Pi disconnects, `LumosNetworkManager().rest` becomes `null` and the UI should fall back gracefully.

## Quick Integration Checklist

- [x] Add `LumosNetworkManager().initialize()` during app startup
- [x] Dispose the manager in the root widget
- [x] Use `StreamBuilder` to show connection status
- [x] Use `sendCommand()` to send action intents to the Pi
- [x] Use `piEvents.where(...)` for type-filtered event handling
- [x] Use `rest?.fetchLatestScene()` for image downloads

## File references

- `lib/services/pi_network/lumos_network_manager.dart`
- `lib/services/pi_network/lumos_device_scout.dart`
- `lib/services/pi_network/lumos_websocket_client.dart`
- `lib/services/pi_network/lumos_rest_client.dart`
- `lib/services/pi_network/base_event_model.dart`
