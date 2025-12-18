import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../models/system_log.dart';
import '../../services/logging_service.dart';

/// Screen displaying system logs with filtering capabilities
class SystemLogsScreen extends StatefulWidget {
  const SystemLogsScreen({super.key});

  @override
  State<SystemLogsScreen> createState() => _SystemLogsScreenState();
}

class _SystemLogsScreenState extends State<SystemLogsScreen> {
  final LoggingService _loggingService = LoggingService();
  late StreamSubscription<List<SystemLog>> _logSubscription;

  LogLevel? _selectedLevel;
  LogCategory? _selectedCategory;
  List<SystemLog> _logs = [];

  @override
  void initState() {
    super.initState();
    _logs = _loggingService.logs;
    _logSubscription = _loggingService.logStream.listen((updatedLogs) {
      if (mounted) {
        setState(() {
          _logs = updatedLogs;
        });
      }
    });
  }

  @override
  void dispose() {
    _logSubscription.cancel();
    super.dispose();
  }

  List<SystemLog> get _filteredLogs {
    var filtered = _logs;

    if (_selectedCategory != null) {
      filtered =
          filtered.where((log) => log.category == _selectedCategory).toList();
    }

    if (_selectedLevel != null) {
      filtered = filtered.where((log) => log.level == _selectedLevel).toList();
    }

    return filtered;
  }

  Color _getLevelColor(LogLevel level) {
    switch (level) {
      case LogLevel.info:
        return Colors.blue;
      case LogLevel.warning:
        return Colors.orange;
      case LogLevel.error:
        return Colors.red;
      case LogLevel.critical:
        return Colors.purple;
    }
  }

  IconData _getLevelIcon(LogLevel level) {
    switch (level) {
      case LogLevel.info:
        return Icons.info_outline;
      case LogLevel.warning:
        return Icons.warning_amber_rounded;
      case LogLevel.error:
        return Icons.error_outline;
      case LogLevel.critical:
        return Icons.dangerous_rounded;
    }
  }

  IconData _getCategoryIcon(LogCategory category) {
    switch (category) {
      case LogCategory.auth:
        return Icons.lock_outline;
      case LogCategory.parking:
        return Icons.local_parking;
      case LogCategory.admin:
        return Icons.admin_panel_settings_outlined;
      case LogCategory.system:
        return Icons.settings_outlined;
      case LogCategory.api:
        return Icons.cloud_outlined;
    }
  }

  void _showClearConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Logs?'),
        content: const Text(
            'This will permanently delete all system logs. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _loggingService.clearLogs();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Logs cleared'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showLogDetails(SystemLog log) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _LogDetailSheet(log: log),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filteredLogs = _filteredLogs;

    return Scaffold(
      appBar: AppBar(
        title: const Text('System Logs'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear Logs',
            onPressed: _showClearConfirmation,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF0D1B2A), const Color(0xFF1B3A4B)]
                : [const Color(0xFFE8F5E9), const Color(0xFFE3F2FD)],
          ),
        ),
        child: Column(
          children: [
            // Filter Section
            _buildFilterSection(isDark),

            // Log Count
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    '${filteredLogs.length} log${filteredLogs.length == 1 ? '' : 's'}',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black54,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  if (_selectedLevel != null || _selectedCategory != null)
                    TextButton.icon(
                      icon: const Icon(Icons.clear, size: 16),
                      label: const Text('Clear Filters'),
                      onPressed: () {
                        setState(() {
                          _selectedLevel = null;
                          _selectedCategory = null;
                        });
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ),
                ],
              ),
            ),

            // Logs List
            Expanded(
              child: filteredLogs.isEmpty
                  ? _buildEmptyState(isDark)
                  : RefreshIndicator(
                      onRefresh: () async {
                        setState(() {
                          _logs = _loggingService.logs;
                        });
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: filteredLogs.length,
                        itemBuilder: (context, index) {
                          return _buildLogCard(filteredLogs[index], isDark);
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _loggingService.logInfo(
            LogCategory.system,
            'Test log entry created',
            metadata: {'source': 'manual'},
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Test Log'),
      ),
    );
  }

  Widget _buildFilterSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Level filters
          Text(
            'Severity',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildLevelChip(null, 'All', isDark),
                const SizedBox(width: 8),
                ...LogLevel.values.map((level) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _buildLevelChip(level, level.displayName, isDark),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Category filters
          Text(
            'Category',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildCategoryChip(null, 'All', isDark),
                const SizedBox(width: 8),
                ...LogCategory.values.map((category) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _buildCategoryChip(
                          category, category.displayName, isDark),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelChip(LogLevel? level, String label, bool isDark) {
    final isSelected = _selectedLevel == level;
    final color = level != null ? _getLevelColor(level) : Colors.grey;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedLevel = selected ? level : null;
        });
      },
      avatar: level != null
          ? Icon(_getLevelIcon(level),
              size: 18, color: isSelected ? Colors.white : color)
          : null,
      selectedColor: color,
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected
            ? Colors.white
            : (isDark ? Colors.white70 : Colors.black87),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      backgroundColor: isDark
          ? Colors.white.withValues(alpha: 0.1)
          : Colors.black.withValues(alpha: 0.05),
      side: BorderSide(
        color: isSelected ? color : Colors.transparent,
      ),
    );
  }

  Widget _buildCategoryChip(LogCategory? category, String label, bool isDark) {
    final isSelected = _selectedCategory == category;
    final color = Theme.of(context).colorScheme.primary;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedCategory = selected ? category : null;
        });
      },
      avatar: category != null
          ? Icon(_getCategoryIcon(category),
              size: 18, color: isSelected ? Colors.white : color)
          : null,
      selectedColor: color,
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected
            ? Colors.white
            : (isDark ? Colors.white70 : Colors.black87),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      backgroundColor: isDark
          ? Colors.white.withValues(alpha: 0.1)
          : Colors.black.withValues(alpha: 0.05),
      side: BorderSide(
        color: isSelected ? color : Colors.transparent,
      ),
    );
  }

  Widget _buildLogCard(SystemLog log, bool isDark) {
    final levelColor = _getLevelColor(log.level);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Material(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () => _showLogDetails(log),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: levelColor, width: 4),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Level icon
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: levelColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _getLevelIcon(log.level),
                        color: levelColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header row
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: levelColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  log.level.displayName,
                                  style: TextStyle(
                                    color: levelColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                _getCategoryIcon(log.category),
                                size: 14,
                                color: isDark ? Colors.white54 : Colors.black45,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                log.category.displayName,
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      isDark ? Colors.white54 : Colors.black45,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                _formatTimestamp(log.timestamp),
                                style: TextStyle(
                                  fontSize: 11,
                                  color:
                                      isDark ? Colors.white38 : Colors.black38,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Message
                          Text(
                            log.message,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              height: 1.3,
                            ),
                          ),

                          // Metadata indicator
                          if (log.metadata != null || log.userId != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Row(
                                children: [
                                  if (log.userId != null) ...[
                                    Icon(Icons.person_outline,
                                        size: 14,
                                        color: isDark
                                            ? Colors.white38
                                            : Colors.black38),
                                    const SizedBox(width: 4),
                                    Text(
                                      log.userId!,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark
                                            ? Colors.white38
                                            : Colors.black38,
                                      ),
                                    ),
                                  ],
                                  if (log.metadata != null) ...[
                                    const Spacer(),
                                    Icon(Icons.data_object,
                                        size: 14,
                                        color: isDark
                                            ? Colors.white38
                                            : Colors.black38),
                                    const SizedBox(width: 4),
                                    Text(
                                      'metadata',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark
                                            ? Colors.white38
                                            : Colors.black38,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Chevron
                    Icon(
                      Icons.chevron_right,
                      color: isDark ? Colors.white24 : Colors.black26,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 64,
            color: isDark ? Colors.white24 : Colors.black26,
          ),
          const SizedBox(height: 16),
          Text(
            'No logs found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedLevel != null || _selectedCategory != null
                ? 'Try adjusting your filters'
                : 'System logs will appear here',
            style: TextStyle(
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }
}

/// Bottom sheet showing log details
class _LogDetailSheet extends StatelessWidget {
  final SystemLog log;

  const _LogDetailSheet({required this.log});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B3A4B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black26,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Text(
                  'Log Details',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 20),

                // Details
                _buildDetailRow('ID', log.id, isDark),
                _buildDetailRow(
                  'Timestamp',
                  '${log.timestamp.toLocal()}',
                  isDark,
                ),
                _buildDetailRow('Level', log.level.displayName, isDark),
                _buildDetailRow('Category', log.category.displayName, isDark),
                _buildDetailRow('Message', log.message, isDark),
                if (log.userId != null)
                  _buildDetailRow('User ID', log.userId!, isDark),
                if (log.metadata != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Metadata',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black26 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      log.metadata!.entries
                          .map((e) => '${e.key}: ${e.value}')
                          .join('\n'),
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
