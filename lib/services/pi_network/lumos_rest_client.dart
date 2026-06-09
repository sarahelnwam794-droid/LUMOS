import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class LumosRestClient {
  final String ipAddress;
  final Uri _baseUri;

  LumosRestClient({required this.ipAddress}) : _baseUri = Uri.parse('http://$ipAddress:5000');

  Future<Uint8List?> fetchLatestScene() async {
    final uri = _baseUri.replace(path: '/api/v1/scene');

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 20));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
      print('LumosRestClient.fetchLatestScene unexpected status code: ${response.statusCode}');
    } catch (error, stackTrace) {
      print('LumosRestClient.fetchLatestScene error: $error');
      print(stackTrace);
    }

    return null;
  }

  Future<Uint8List?> downloadBrainBackup() async {
      final uri = _baseUri.replace(path: '/api/v1/brain');
      try {
        final response = await http.get(uri).timeout(const Duration(seconds: 30));
        if (response.statusCode == 200) {
          return response.bodyBytes; // Returns the actual .pkl file bytes
        }
        print('Failed to download brain: ${response.statusCode}');
      } catch (e) {
        print('Backup error: $e');
      }
      return null;
    }