import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';

class AppLogger {
  static AppLogger? _instance;
  static AppLogger get instance => _instance ??= AppLogger._();

  AppLogger._();

  static const _maxEntries = 500;
  static const _maxFileSize = 512 * 1024;
  final List<_LogEntry> _entries = [];
  File? _logFile;
  bool _initialized = false;

  final _dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss.SSS');

  // ignore: library_private_types_in_public_api
  List<_LogEntry> get entries => List.unmodifiable(_entries);

  Future<void> init() async {
    if (_initialized) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      _logFile = File(p.join(dir.path, 'logs', 'app.log'));
      if (!await _logFile!.parent.exists()) {
        await _logFile!.parent.create(recursive: true);
      }
      _initialized = true;
    } catch (e) {
      debugPrint('[AppLogger] init_error: $e');
    }
  }

  void info(String tag, String message) => _log(_LogLevel.info, tag, message);

  void warning(String tag, String message) =>
      _log(_LogLevel.warning, tag, message);

  void error(String tag, String message, [String? stackTrace]) =>
      _log(_LogLevel.error, tag, message, stackTrace);

  void _log(_LogLevel level, String tag, String message,
      [String? stackTrace]) {
    final entry = _LogEntry(
      timestamp: DateTime.now(),
      level: level,
      tag: tag,
      message: message,
      stackTrace: stackTrace,
    );

    _entries.add(entry);
    if (_entries.length > _maxEntries) {
      _entries.removeRange(0, _entries.length - _maxEntries);
    }

    final prefix = switch (level) {
      _LogLevel.info => 'INFO',
      _LogLevel.warning => 'WARN',
      _LogLevel.error => 'ERROR',
    };
    final formatted =
        '${_dateFormat.format(entry.timestamp)} [$prefix] [$tag] $message';
    debugPrint(formatted);
    if (stackTrace != null) {
      debugPrint(stackTrace);
    }

    _appendToFile(formatted, stackTrace);
  }

  void _appendToFile(String line, [String? extra]) {
    if (_logFile == null) return;
    final content = extra != null ? '$line\n$extra\n' : '$line\n';
    _logFile!.writeAsString(content, mode: FileMode.append, flush: false);
  }

  Future<void> rotateIfNeeded() async {
    if (_logFile == null || !await _logFile!.exists()) return;
    try {
      final size = await _logFile!.length();
      if (size > _maxFileSize) {
        final backup = File('${_logFile!.path}.1');
        if (await backup.exists()) await backup.delete();
        await _logFile!.rename(backup.path);
        _logFile = File(p.join(_logFile!.parent.path, 'app.log'));
      }
    } catch (_) {}
  }

  Future<String> getLogContent({int maxLines = 200}) async {
    if (_logFile == null || !await _logFile!.exists()) {
      return _entries
          .takeLast(maxLines)
          .map((e) => e.format(_dateFormat))
          .join('\n');
    }
    try {
      final lines = await _logFile!.readAsLines();
      if (lines.length <= maxLines) return lines.join('\n');
      return lines.skip(lines.length - maxLines).join('\n');
    } catch (e) {
      return _entries
          .takeLast(maxLines)
          .map((e) => e.format(_dateFormat))
          .join('\n');
    }
  }

  Future<void> clearLogs() async {
    _entries.clear();
    if (_logFile != null && await _logFile!.exists()) {
      await _logFile!.writeAsString('');
    }
  }

  static void initGlobalErrorHandlers() {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      instance.error(
        'FlutterError',
        details.exceptionAsString(),
        details.stack?.toString(),
      );
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      instance.error('PlatformError', error.toString(), stack.toString());
      return true;
    };
  }
}

enum _LogLevel { info, warning, error }

class _LogEntry {
  _LogEntry({
    required this.timestamp,
    required this.level,
    required this.tag,
    required this.message,
    this.stackTrace,
  });

  final DateTime timestamp;
  final _LogLevel level;
  final String tag;
  final String message;
  final String? stackTrace;

  String format(DateFormat dateFormat) {
    final prefix = switch (level) {
      _LogLevel.info => 'INFO',
      _LogLevel.warning => 'WARN',
      _LogLevel.error => 'ERROR',
    };
    final base =
        '${dateFormat.format(timestamp)} [$prefix] [$tag] $message';
    if (stackTrace != null) return '$base\n$stackTrace';
    return base;
  }
}

extension _TakeLast<T> on List<T> {
  List<T> takeLast(int n) {
    if (length <= n) return this;
    return sublist(length - n);
  }
}
