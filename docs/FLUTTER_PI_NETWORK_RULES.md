# Flutter Network Execution Rules

## 1. Isolation Protocol (CRITICAL)
- Do **NOT** modify any files in `lib/screens/`. 
- Do **NOT** modify `lib/services/medical_api_service.dart` (This is reserved for the .NET backend).
- You are only authorized to write pure Dart classes inside `lib/services/pi_network/`.

## 2. No UI Coupling
These services must be pure Dart logic. Do not import `package:flutter/material.dart` and do not pass `BuildContext` into these network classes. They should expose Streams or Futures that the UI can listen to independently.

## 3. Safe JSON Parsing
WebSocket streams can be volatile. Wrap `jsonDecode` in `try/catch` blocks. If the Pi sends a malformed JSON string, catch the `FormatException`, log it locally, and drop the frame rather than crashing the Flutter app.

## 4. IP Dependency
The WebSocket and REST clients must accept the `ipAddress` as a dependency (e.g., passed into their constructors or initialization methods) rather than resolving it themselves. `lumos_device_scout.dart` is the only class responsible for finding the IP.