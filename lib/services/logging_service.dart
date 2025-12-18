import 'dart:async';
import '../models/system_log.dart';

/// Singleton service for managing system logs
class LoggingService {
  static final LoggingService _instance = LoggingService._internal();
  factory LoggingService() => _instance;
  LoggingService._internal() {
    _addDemoLogs();
  }

  /// Maximum number of logs to keep in memory
  static const int maxLogs = 500;

  /// In-memory log storage
  final List<SystemLog> _logs = [];

  /// Stream controller for real-time log updates
  final StreamController<List<SystemLog>> _logStreamController =
      StreamController<List<SystemLog>>.broadcast();

  /// Stream of logs for UI updates
  Stream<List<SystemLog>> get logStream => _logStreamController.stream;

  /// Get all logs (newest first)
  List<SystemLog> get logs => List.unmodifiable(_logs.reversed.toList());

  /// Add demo logs for testing
  void _addDemoLogs() {
    final demoLogs = [
      SystemLog(
        id: '1',
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        level: LogLevel.info,
        category: LogCategory.system,
        message: 'System started',
      ),
      SystemLog(
        id: '2',
        timestamp:
            DateTime.now().subtract(const Duration(hours: 1, minutes: 45)),
        level: LogLevel.info,
        category: LogCategory.auth,
        message: 'User authentication service initialized',
      ),
      SystemLog(
        id: '3',
        timestamp:
            DateTime.now().subtract(const Duration(hours: 1, minutes: 30)),
        level: LogLevel.info,
        category: LogCategory.api,
        message: 'Connected to DynamoDB API Gateway',
      ),
      SystemLog(
        id: '4',
        timestamp: DateTime.now().subtract(const Duration(hours: 1)),
        level: LogLevel.warning,
        category: LogCategory.parking,
        message: 'Sensor S-001 response delayed (>2s)',
        metadata: {'sensorId': 'S-001', 'responseTime': 2150},
      ),
      SystemLog(
        id: '5',
        timestamp: DateTime.now().subtract(const Duration(minutes: 45)),
        level: LogLevel.info,
        category: LogCategory.parking,
        message: 'Parking spot A-01 status changed: available → occupied',
        metadata: {
          'spotId': 'A-01',
          'previousStatus': 'available',
          'newStatus': 'occupied'
        },
      ),
      SystemLog(
        id: '6',
        timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
        level: LogLevel.error,
        category: LogCategory.api,
        message: 'Failed to fetch parking spots: Network timeout',
        metadata: {'errorCode': 'NETWORK_TIMEOUT', 'retryCount': 3},
      ),
      SystemLog(
        id: '7',
        timestamp: DateTime.now().subtract(const Duration(minutes: 15)),
        level: LogLevel.info,
        category: LogCategory.admin,
        message: 'Admin user accessed Grid Designer',
        userId: 'admin@example.com',
      ),
      SystemLog(
        id: '8',
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
        level: LogLevel.info,
        category: LogCategory.parking,
        message: 'New parking grid "Main Lot" saved',
        metadata: {'gridId': 'main-lot', 'spotCount': 24},
      ),
    ];

    _logs.addAll(demoLogs);
  }

  /// Log a message with specified level and category
  void log({
    required LogLevel level,
    required LogCategory category,
    required String message,
    String? userId,
    Map<String, dynamic>? metadata,
  }) {
    final logEntry = SystemLog.create(
      level: level,
      category: category,
      message: message,
      userId: userId,
      metadata: metadata,
    );

    _logs.add(logEntry);

    // Remove oldest logs if exceeding max
    while (_logs.length > maxLogs) {
      _logs.removeAt(0);
    }

    // Notify listeners
    _logStreamController.add(logs);

    // Also print to console for debugging
    print('[${level.displayName}] ${category.displayName}: $message');
  }

  /// Log an info message
  void logInfo(LogCategory category, String message,
      {String? userId, Map<String, dynamic>? metadata}) {
    log(
        level: LogLevel.info,
        category: category,
        message: message,
        userId: userId,
        metadata: metadata);
  }

  /// Log a warning message
  void logWarning(LogCategory category, String message,
      {String? userId, Map<String, dynamic>? metadata}) {
    log(
        level: LogLevel.warning,
        category: category,
        message: message,
        userId: userId,
        metadata: metadata);
  }

  /// Log an error message
  void logError(LogCategory category, String message,
      {String? userId, Map<String, dynamic>? metadata}) {
    log(
        level: LogLevel.error,
        category: category,
        message: message,
        userId: userId,
        metadata: metadata);
  }

  /// Log a critical message
  void logCritical(LogCategory category, String message,
      {String? userId, Map<String, dynamic>? metadata}) {
    log(
        level: LogLevel.critical,
        category: category,
        message: message,
        userId: userId,
        metadata: metadata);
  }

  /// Get logs filtered by category and/or level
  List<SystemLog> getLogs({LogCategory? category, LogLevel? level}) {
    var filtered = logs;

    if (category != null) {
      filtered = filtered.where((log) => log.category == category).toList();
    }

    if (level != null) {
      filtered = filtered.where((log) => log.level == level).toList();
    }

    return filtered;
  }

  /// Clear all logs
  void clearLogs() {
    _logs.clear();
    _logStreamController.add(logs);
    logInfo(LogCategory.admin, 'System logs cleared');
  }

  /// Dispose the stream controller
  void dispose() {
    _logStreamController.close();
  }
}
