import 'dart:async';

import 'package:nsd/nsd.dart';

class LumosDeviceScout {
  final String serviceType;
  final Duration discoveryTimeout;
  final _ipController = StreamController<String?>.broadcast();

  StreamSubscription<dynamic>? _subscription;
  String? _currentIp;
  bool _isScanning = false;

  LumosDeviceScout({
    this.serviceType = '_lumos._tcp',
    this.discoveryTimeout = const Duration(seconds: 30),
  });

  Stream<String?> get discoveredIp => _ipController.stream;
  String? get currentIp => _currentIp;
  bool get isScanning => _isScanning;

  Future<void> startDiscovery() async {
    await stopDiscovery();
    _isScanning = true;
    _ipController.add(null);

    try {
      final nsd = Nsd();
      final discoveryStream = nsd.discover(serviceType);

      _subscription = discoveryStream.listen(
        (dynamic service) {
          final ip = _extractIpAddress(service);
          if (ip != null && ip != _currentIp) {
            _currentIp = ip;
            _ipController.add(ip);
          }
        },
        onError: (error) {
          print('LumosDeviceScout discovery error: $error');
          _ipController.add(null);
        },
        cancelOnError: false,
      );

      if (discoveryTimeout.inMilliseconds > 0) {
        Future.delayed(discoveryTimeout, () {
          if (_isScanning) {
            stopDiscovery();
          }
        });
      }
    } catch (error, stackTrace) {
      print('LumosDeviceScout.startDiscovery failed: $error');
      print(stackTrace);
      _ipController.add(null);
      _isScanning = false;
    }
  }

  Future<void> stopDiscovery() async {
    _isScanning = false;
    await _subscription?.cancel();
    _subscription = null;
  }

  Future<void> dispose() async {
    await stopDiscovery();
    await _ipController.close();
  }

  String? _extractIpAddress(dynamic service) {
    if (service == null) {
      return null;
    }

    try {
      final host = _readProperty(service, 'host');
      final address = _readProperty(service, 'address');
      final hostname = _readProperty(service, 'hostname');
      final addresses = _readProperty(service, 'addresses') ?? _readProperty(service, 'ipAddresses');

      final candidates = <String?>[
        if (host is String) host,
        if (address is String) address,
        if (hostname is String) hostname,
      ];

      if (host != null && host is! String) {
        candidates.addAll(_extractStringsFromHost(host));
      }

      if (addresses is Iterable) {
        for (final candidate in addresses) {
          if (candidate is String) {
            candidates.add(candidate);
          } else if (candidate != null) {
            final nested = _readProperty(candidate, 'address') ?? _readProperty(candidate, 'hostname');
            if (nested is String) {
              candidates.add(nested);
            }
          }
        }
      }

      for (final candidate in candidates) {
        if (candidate != null && _isIpv4(candidate)) {
          return candidate;
        }
      }
    } catch (error, stackTrace) {
      print('LumosDeviceScout._extractIpAddress error: $error');
      print(stackTrace);
    }

    return null;
  }

  List<String?> _extractStringsFromHost(dynamic host) {
    final results = <String?>[];
    results.add(_readProperty(host, 'address') as String?);
    results.add(_readProperty(host, 'hostname') as String?);
    results.add(_readProperty(host, 'ip') as String?);
    return results;
  }

  dynamic _readProperty(dynamic object, String propertyName) {
    if (object == null) {
      return null;
    }

    if (object is Map) {
      return object[propertyName];
    }

    try {
      switch (propertyName) {
        case 'host':
          return object.host;
        case 'hostname':
          return object.hostname;
        case 'addresses':
          return object.addresses;
        case 'ipAddresses':
          return object.ipAddresses;
        case 'address':
          return object.address;
        case 'ip':
          return object.ip;
      }
    } catch (_) {
      // ignore missing property
    }

    return null;
  }

  bool _isIpv4(String candidate) {
    final parts = candidate.split('.');
    if (parts.length != 4) {
      return false;
    }
    for (final part in parts) {
      final value = int.tryParse(part);
      if (value == null || value < 0 || value > 255) {
        return false;
      }
    }
    return true;
  }
}
