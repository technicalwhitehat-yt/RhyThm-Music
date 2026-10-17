import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class AppLogger {
  static File? _logFile;
  static bool _initialized = false;
  static final List<String> _inMemoryLogs = [];
  static const int _maxInMemoryLines = 200;

  static Future<void> init() async {
    if (_initialized) return;
    try {
      String? dirPath;
      if (Platform.isWindows) {
        final appData = Platform.environment['APPDATA'];
        if (appData != null && appData.isNotEmpty) {
          dirPath = '$appData\\com.twh\\rhythm_music';
        }
      }

      if (dirPath == null) {
        final appSupportDir = await getApplicationSupportDirectory();
        dirPath = appSupportDir.path;
      }

      final dir = Directory(dirPath);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }

      _logFile = File('${dir.path}${Platform.pathSeparator}rhythm_debug.log');

      // Check log file size and trim if larger than 3MB
      if (_logFile!.existsSync() && _logFile!.lengthSync() > 3 * 1024 * 1024) {
        try {
          final lines = _logFile!.readAsLinesSync();
          final kept = lines.length > 1000 ? lines.sublist(lines.length - 1000) : lines;
          _logFile!.writeAsStringSync(kept.join('\n'));
        } catch (_) {}
      }

      _initialized = true;

      // Hook into global Flutter error dispatcher
      FlutterError.onError = (FlutterErrorDetails details) {
        error("FlutterError: ${details.exceptionAsString()}",
            stackTrace: details.stack, tag: "FlutterError");
        FlutterError.presentError(details);
      };

      // Hook into asynchronous platform error dispatcher
      PlatformDispatcher.instance.onError = (Object err, StackTrace stack) {
        error("Uncaught async error: $err",
            stackTrace: stack, tag: "PlatformDispatcher");
        return true;
      };

      info("=== Rhythm Music Started [Platform: ${Platform.operatingSystem}] ===", tag: "AppLogger");
    } catch (e) {
      debugPrint("AppLogger init error: $e");
    }
  }

  static void info(dynamic message, {String tag = "RhyThm Music"}) {
    _writeLog("INFO", message, tag: tag);
  }

  static void warn(dynamic message, {String tag = "RhyThm Music"}) {
    _writeLog("WARN", message, tag: tag);
  }

  static void error(dynamic message, {StackTrace? stackTrace, String tag = "RhyThm Music"}) {
    final fullMsg = stackTrace != null ? "$message\n$stackTrace" : message.toString();
    _writeLog("ERROR", fullMsg, tag: tag);
  }

  static void _writeLog(String level, dynamic message, {String tag = "RhyThm Music"}) {
    final now = DateTime.now();
    final timeStr =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}.${now.millisecond.toString().padLeft(3, '0')}";
    final entry = "[$timeStr] [$level] [$tag]: $message";

    _inMemoryLogs.add(entry);
    if (_inMemoryLogs.length > _maxInMemoryLines) {
      _inMemoryLogs.removeAt(0);
    }

    debugPrint(entry);

    if (_logFile != null) {
      try {
        _logFile!.writeAsStringSync("$entry\n", mode: FileMode.append, flush: true);
      } catch (_) {}
    }
  }

  static String getLogFilePath() {
    return _logFile?.path ?? "rhythm_debug.log";
  }

  static String getRecentLogs({int maxLines = 100}) {
    if (_logFile != null && _logFile!.existsSync()) {
      try {
        final lines = _logFile!.readAsLinesSync();
        if (lines.length > maxLines) {
          return lines.sublist(lines.length - maxLines).join('\n');
        }
        return lines.join('\n');
      } catch (_) {}
    }
    return _inMemoryLogs.join('\n');
  }

  static Future<void> copyLogsToClipboard() async {
    final logs = getRecentLogs();
    await Clipboard.setData(ClipboardData(text: logs.isEmpty ? "No logs yet." : logs));
  }

  static Future<void> clearLog() async {
    _inMemoryLogs.clear();
    if (_logFile != null && _logFile!.existsSync()) {
      try {
        _logFile!.writeAsStringSync("");
      } catch (_) {}
    }
    info("Logs cleared by user", tag: "AppLogger");
  }

  static Future<void> openLogFile() async {
    final path = getLogFilePath();
    if (Platform.isWindows) {
      try {
        await Process.run('notepad.exe', [path]);
      } catch (_) {
        await Process.run('cmd.exe', ['/c', 'start', '', path]);
      }
    } else if (Platform.isLinux) {
      try {
        await Process.run('xdg-open', [path]);
      } catch (_) {}
    } else if (Platform.isMacOS) {
      try {
        await Process.run('open', [path]);
      } catch (_) {}
    }
  }
}
