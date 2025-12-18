/// Log severity levels
enum LogLevel {
  info,
  warning,
  error,
  critical;

  String get displayName {
    switch (this) {
      case LogLevel.info:
        return 'INFO';
      case LogLevel.warning:
        return 'WARNING';
      case LogLevel.error:
        return 'ERROR';
      case LogLevel.critical:
        return 'CRITICAL';
    }
  }
}

/// Log categories for organizing system events
enum LogCategory {
  auth,
  parking,
  admin,
  system,
  api;

  String get displayName {
    switch (this) {
      case LogCategory.auth:
        return 'Authentication';
      case LogCategory.parking:
        return 'Parking';
      case LogCategory.admin:
        return 'Admin';
      case LogCategory.system:
        return 'System';
      case LogCategory.api:
        return 'API';
    }
  }
}

/// Model representing a single system log entry
class SystemLog {
  final String id;
  final DateTime timestamp;
  final LogLevel level;
  final LogCategory category;
  final String message;
  final String? userId;
  final Map<String, dynamic>? metadata;

  SystemLog({
    required this.id,
    required this.timestamp,
    required this.level,
    required this.category,
    required this.message,
    this.userId,
    this.metadata,
  });

  /// Create a log with auto-generated ID and current timestamp
  factory SystemLog.create({
    required LogLevel level,
    required LogCategory category,
    required String message,
    String? userId,
    Map<String, dynamic>? metadata,
  }) {
    return SystemLog(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      level: level,
      category: category,
      message: message,
      userId: userId,
      metadata: metadata,
    );
  }

  /// Convert log to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'level': level.name,
      'category': category.name,
      'message': message,
      'userId': userId,
      'metadata': metadata,
    };
  }

  /// Create log from JSON
  factory SystemLog.fromJson(Map<String, dynamic> json) {
    return SystemLog(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      level: LogLevel.values.firstWhere(
        (e) => e.name == json['level'],
        orElse: () => LogLevel.info,
      ),
      category: LogCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => LogCategory.system,
      ),
      message: json['message'] as String,
      userId: json['userId'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  @override
  String toString() {
    return 'SystemLog(${level.displayName} | ${category.displayName}: $message)';
  }
}
