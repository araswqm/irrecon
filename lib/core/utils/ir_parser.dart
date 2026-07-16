import '../../data/models/ir_key.dart';

/// Parses Flipper Zero .ir file format content into a list of IRKey.
///
/// Format:
/// ```
/// Filetype: IR signals file
/// Version: 1
/// name: KEY_POWER
/// type: parsed
/// protocol: NEC
/// address: 00 00 00 00
/// command: 00 00 00 00
/// ---
/// ```
class IRParser {
  /// Parse the full text content of a .ir file.
  static List<IRKey> parse(String content) {
    final keys = <IRKey>[];
    final signals = content.split('---');

    for (final signal in signals) {
      final trimmed = signal.trim();
      if (trimmed.isEmpty) continue;

      final key = _parseSignal(trimmed);
      if (key != null) {
        keys.add(key);
      }
    }

    return keys;
  }

  static IRKey? _parseSignal(String signal) {
    String? name;
    String type = 'parsed';
    String? protocol;
    String? address;
    String? command;

    for (final line in signal.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('Filetype:') ||
          trimmed.startsWith('Version:')) {
        continue;
      }

      final colonIndex = trimmed.indexOf(':');
      if (colonIndex == -1) continue;

      final key = trimmed.substring(0, colonIndex).trim();
      final value = trimmed.substring(colonIndex + 1).trim();

      switch (key) {
        case 'name':
          name = value;
        case 'type':
          type = value;
        case 'protocol':
          protocol = value;
        case 'address':
          address = value;
        case 'command':
          command = value;
      }
    }

    if (name == null || name.isEmpty) return null;

    return IRKey(
      name: name,
      type: type,
      protocol: protocol,
      address: address,
      command: command,
    );
  }

  /// Serialize a list of IRKey back to .ir file format.
  static String serialize(List<IRKey> keys) {
    final buffer = StringBuffer();
    buffer.writeln('Filetype: IR signals file');
    buffer.writeln('Version: 1');
    buffer.writeln('');

    for (var i = 0; i < keys.length; i++) {
      final key = keys[i];
      buffer.writeln('# Signal ${i + 1}: ${key.name}');
      buffer.writeln('name: ${key.name}');
      buffer.writeln('type: ${key.type}');
      if (key.protocol != null) buffer.writeln('protocol: ${key.protocol}');
      if (key.address != null) buffer.writeln('address: ${key.address}');
      if (key.command != null) buffer.writeln('command: ${key.command}');
      if (i < keys.length - 1) buffer.writeln('---');
      buffer.writeln('');
    }

    return buffer.toString();
  }
}
