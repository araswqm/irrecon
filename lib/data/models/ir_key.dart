/// Represents a single IR key parsed from a .ir file.
class IRKey {
  final String name;
  final String type;
  final String? protocol;
  final String? address;
  final String? command;
  final int? frequency;
  final double? dutyCycle;
  final String? data;
  final int? modelId;

  const IRKey({
    required this.name,
    this.type = 'parsed',
    this.protocol,
    this.address,
    this.command,
    this.frequency,
    this.dutyCycle,
    this.data,
    this.modelId,
  });

  /// User's exact button names and their `KEY_`‑prefixed IRDB equivalents.
  ///
  /// All matching is **case‑sensitive** — database stores names exactly as
  /// listed here (`"Power"`, `"Vol Up"`, `"KEY_POWER"`, …).
  static const Map<KeyCategory, Set<String>> _categoryNames = {
    KeyCategory.power: {
      'Power', 'Power On', 'Power Off',
      'KEY_POWER', 'KEY_POWER_ON', 'KEY_POWER_OFF', 'KEY_POWER_TOGGLE',
    },
    KeyCategory.mute: {
      'Mute', 'KEY_MUTE',
    },
    KeyCategory.volumeUp: {
      'Vol Up',
      'KEY_VOLUMEUP', 'KEY_VOLUMEUP_UP',
    },
    KeyCategory.volumeDown: {
      'Vol Dn',
      'KEY_VOLUMEDOWN', 'KEY_VOLUMEDOWN_DOWN',
    },
    KeyCategory.channelUp: {
      'Ch Next',
      'KEY_CHANNELUP', 'KEY_CHANNELUP_UP',
    },
    KeyCategory.channelDown: {
      'Ch Prev',
      'KEY_CHANNELDOWN', 'KEY_CHANNELDOWN_DOWN',
    },
    KeyCategory.directional: {
      'Up', 'Down', 'Left', 'Right', 'Select', 'Enter', 'Return', 'OK',
      'KEY_UP', 'KEY_DOWN', 'KEY_LEFT', 'KEY_RIGHT', 'KEY_OK',
      'KEY_SELECT', 'KEY_ENTER', 'KEY_RETURN',
    },
    KeyCategory.input: {
      'Source', 'Input',
      'KEY_SOURCE', 'KEY_INPUT',
    },
    KeyCategory.transport: {
      'Play', 'Pause', 'Stop', 'Rewind', 'Fast Forward', 'Next', 'Previous', 'Record',
      'KEY_PLAY', 'KEY_PAUSE', 'KEY_STOP', 'KEY_REWIND', 'KEY_FASTFORWARD',
      'KEY_NEXT', 'KEY_PREVIOUS', 'KEY_RECORD',
    },
  };

  /// Derive lookup variants for [name].
  ///
  /// Tries both the original string and its `KEY_` counterpart so we match
  /// both human‑readable names (`"Power"`) and Flipper IRDB codes (`"KEY_POWER"`).
  /// No case conversion — all matching is case‑sensitive.
  static List<String> _variants(String name) {
    if (name.startsWith('KEY_')) {
      return [name, name.substring(4)];
    }
    return [name, 'KEY_$name'];
  }

  /// Classifies this key into a layout group.
  KeyCategory get category {
    for (final v in _variants(name)) {
      for (final entry in _categoryNames.entries) {
        if (entry.value.contains(v)) return entry.key;
      }
      // Numeric: single digit 0-9
      if (v.length == 1 && v.codeUnitAt(0) >= 48 && v.codeUnitAt(0) <= 57) {
        return KeyCategory.numeric;
      }
    }
    return KeyCategory.other;
  }

  /// Human-readable label derived from the key name.
  String get displayLabel {
    final cleaned = name.replaceFirst('KEY_', '');
    return cleaned
        .split('_')
        .map((w) => w.isNotEmpty
            ? '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}'
            : '')
        .join(' ');
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'type': type,
        'protocol': protocol,
        'address': address,
        'command': command,
        'frequency': frequency,
        'duty_cycle': dutyCycle,
        'data': data,
        'model_id': modelId,
      };

  factory IRKey.fromMap(Map<String, dynamic> map) => IRKey(
        name: map['name'] as String,
        type: map['type'] as String? ?? 'parsed',
        protocol: map['protocol'] as String?,
        address: map['address'] as String?,
        command: map['command'] as String?,
        frequency: map['frequency'] as int?,
        dutyCycle: map['duty_cycle'] != null
            ? (map['duty_cycle'] as num).toDouble()
            : null,
        data: map['data'] as String?,
        modelId: map['model_id'] as int?,
      );

  @override
  String toString() => 'IRKey(name: $name, type: $type, '
      'protocol: $protocol, frequency: $frequency)';
}

/// Categories used by the layout engine for dynamic remote UI positioning.
enum KeyCategory {
  power,
  mute,
  volumeUp,
  volumeDown,
  channelUp,
  channelDown,
  directional,
  numeric,
  input,
  transport,
  other,
}
