import '../../data/models/ir_key.dart';

/// Parses Flipper Zero .ir file format content into a list of IRKey.
///
/// Flipper-IRDB format — signals are NOT separated by `---`. Each new
/// `name:` field starts the next signal. Comment lines (`#`) and blank
/// lines are ignored. The `---` separator (used by some other Flipper
/// tools) is also supported for backwards compatibility.
///
/// Format:
/// ```
/// Filetype: IR signals file
/// Version: 1
/// # comment
/// name: Power
/// type: parsed
/// protocol: NEC
/// address: 00 00 00 00
/// command: 00 00 00 00
/// #
/// name: Vol_up
/// ...
/// ```
class IRParser {
  /// Parse the full text content of a .ir file.
  static List<IRKey> parse(String content) {
    final keys = <IRKey>[];

    String? name;
    String type = 'parsed';
    String? protocol;
    String? address;
    String? command;

    void flush() {
      if (name != null && name!.isNotEmpty) {
        keys.add(IRKey(
          name: name!,
          type: type,
          protocol: protocol,
          address: address,
          command: command,
        ));
        name = null;
        type = 'parsed';
        protocol = null;
        address = null;
        command = null;
      }
    }

    for (final line in content.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // `---` is a hard separator in some Flipper tool outputs.
      if (trimmed == '---') {
        flush();
        continue;
      }

      // Skip header / comment lines (they separate signals visually but
      // are not required for boundary detection).
      if (trimmed.startsWith('Filetype:') ||
          trimmed.startsWith('Version:') ||
          trimmed.startsWith('#')) {
        continue;
      }

      final colonIndex = trimmed.indexOf(':');
      if (colonIndex == -1) continue;

      final key = trimmed.substring(0, colonIndex).trim();
      final value = trimmed.substring(colonIndex + 1).trim();

      if (key == 'name') {
        // Each new `name:` starts the next signal.
        flush();
        name = value;
      } else {
        switch (key) {
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
    }

    // Flush the last signal.
    flush();

    return keys;
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
