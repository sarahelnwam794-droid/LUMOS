# Lumos Pi Network Blueprint (Flutter)

## Target Directory
All files must be created strictly inside: `lib/services/pi_network/`

## Required Dependencies (Assume these are in pubspec.yaml)
- `nsd`: For mDNS Zero-configuration discovery.
- `web_socket_channel`: For the persistent WebSocket connection.
- `http`: For REST API heavy-data requests.

## Architecture Components

### 1. `base_event_model.dart`
**Purpose:** The exact Dart representation of the Python `BaseEvent` Pydantic model.
**Requirements:**
- Fields: `String type`, `Map<String, dynamic> payload`, `double timestamp`, `int priority`.
- Methods: `factory BaseEvent.fromJson(Map<String, dynamic> json)` and `Map<String, dynamic> toJson()`.

### 2. `lumos_device_scout.dart`
**Purpose:** Background service to discover the Raspberry Pi on the local mobile hotspot without hardcoding IPs.
**Requirements:**
- Use the `nsd` package.
- Target service type: `_lumos._tcp`.
- Must extract and store the IPv4 address.
- Provide a reactive state (like a `Stream<String?>` or `ValueNotifier<String?>`) that emits the discovered IP address.

### 3. `lumos_websocket_client.dart`
**Purpose:** The central nervous system for real-time AI and hardware communication.
**Requirements:**
- Connects to: `ws://<discovered_ip>:5000/ws`.
- Listens to the incoming string stream, decodes the JSON, and yields a `Stream<BaseEvent>`.
- Provides a `void sendCommand(BaseEvent command)` method to push user actions back to the Pi.
- Must include basic auto-reconnect logic if the socket drops.

### 4. `lumos_rest_client.dart`
**Purpose:** Handles heavy data transfers that bypass the real-time WebSocket.
**Requirements:**
- Connects to: `http://<discovered_ip>:5000`.
- Method `Future<Uint8List?> fetchLatestScene()`: Hits `/api/v1/scene` to download the RAM-disk image.
- Method `Future<bool> triggerBrainBackup()`: Hits `/api/v1/brain`.
