import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Writes IR transmission debug logs to a file on the device so users
/// can inspect them without a computer.
///
/// The log lives at `{appDocDir}/ir_log.txt` and is truncated to ~500 KB
/// to avoid unbounded disk usage.
class IrLogger {
  static final IrLogger _instance = IrLogger._();
  factory IrLogger() => _instance;
  IrLogger._();

  static const int _maxBytes = 512 * 1024; // 512 KB

  File? _file;

  Future<File> _getFile() async {
    if (_file != null) return _file!;
    final dir = await getApplicationDocumentsDirectory();
    _file = File('${dir.path}/ir_log.txt');
    return _file!;
  }

  /// Write a line prepended with a timestamp.
  Future<void> log(String message) async {
    try {
      final file = await _getFile();
      final ts = DateTime.now().toIso8601String().substring(11, 23); // HH:mm:ss.mmm
      final line = '$ts $message\n';

      // Append, then truncate if over limit
      await file.writeAsString(line, mode: FileMode.append);
      final length = await file.length();
      if (length > _maxBytes) {
        final existing = await file.readAsLines();
        // Keep last ~80% of lines
        final keep = (existing.length * 0.8).round();
        await file.writeAsString(
          existing.sublist(existing.length - keep).join('\n'),
        );
      }
    } catch (e) {
      // Don't crash — logging is best-effort
      debugPrint('IrLogger error: $e');
    }
  }

  /// Read the full log as a string.
  Future<String> readLog() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        return await file.readAsString();
      }
    } catch (_) {}
    return '(no log entries yet)';
  }

  /// Clear the log file.
  Future<void> clear() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        await file.writeAsString('');
      }
    } catch (_) {}
  }
}
