class BaseEvent {
  final String type;
  final Map<String, dynamic> payload;
  final double timestamp;
  final int priority;

  const BaseEvent({
    required this.type,
    required this.payload,
    required this.timestamp,
    required this.priority,
  });

  factory BaseEvent.fromJson(Map<String, dynamic> json) {
    final rawType = json['type'];
    final rawPayload = json['payload'];
    final rawTimestamp = json['timestamp'];
    final rawPriority = json['priority'];

    if (rawType is! String) {
      throw FormatException('BaseEvent.type must be a String.');
    }

    final payload = rawPayload is Map
        ? Map<String, dynamic>.from(rawPayload)
        : <String, dynamic>{};

    final timestamp = rawTimestamp is num
        ? rawTimestamp.toDouble()
        : double.tryParse(rawTimestamp?.toString() ?? '') ??
            (throw FormatException('BaseEvent.timestamp must be numeric.'));

    final priority = rawPriority is int
        ? rawPriority
        : int.tryParse(rawPriority?.toString() ?? '') ??
            (throw FormatException('BaseEvent.priority must be an integer.'));

    return BaseEvent(
      type: rawType,
      payload: payload,
      timestamp: timestamp,
      priority: priority,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'payload': payload,
      'timestamp': timestamp,
      'priority': priority,
    };
  }

  @override
  String toString() {
    return 'BaseEvent(type: $type, timestamp: $timestamp, priority: $priority, payload: $payload)';
  }
}
