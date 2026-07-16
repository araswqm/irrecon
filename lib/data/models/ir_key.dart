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

  /// Classifies this key into a layout group.
  KeyCategory get category {
    final upper = name.toUpperCase();
    if (upper == 'KEY_POWER') return KeyCategory.power;
    if (upper == 'KEY_MUTE') return KeyCategory.mute;
    if (upper == 'KEY_VOLUMEUP' || upper == 'KEY_VOLUMEUP_UP') {
      return KeyCategory.volumeUp;
    }
    if (upper == 'KEY_VOLUMEDOWN' || upper == 'KEY_VOLUMEDOWN_DOWN') {
      return KeyCategory.volumeDown;
    }
    if (upper == 'KEY_CHANNELUP' || upper == 'KEY_CHANNELUP_UP') {
      return KeyCategory.channelUp;
    }
    if (upper == 'KEY_CHANNELDOWN' || upper == 'KEY_CHANNELDOWN_DOWN') {
      return KeyCategory.channelDown;
    }
    if (['KEY_UP', 'KEY_DOWN', 'KEY_LEFT', 'KEY_RIGHT', 'KEY_OK']
        .contains(upper)) {
      return KeyCategory.directional;
    }
    if (upper.startsWith('KEY_') &&
        upper.length == 6 &&
        upper.codeUnitAt(4) >= 48 &&
        upper.codeUnitAt(4) <= 57) {
      return KeyCategory.numeric;
    }
    if (['KEY_INPUT', 'KEY_SOURCE', 'KEY_HDMI', 'KEY_HDMI1', 'KEY_HDMI2',
            'KEY_HDMI3', 'KEY_AV', 'KEY_TV']
        .contains(upper)) {
      return KeyCategory.input;
    }
    if (['KEY_PLAY', 'KEY_PAUSE', 'KEY_STOP', 'KEY_REWIND', 'KEY_FASTFORWARD',
            'KEY_NEXT', 'KEY_PREVIOUS', 'KEY_RECORD']
        .contains(upper)) {
      return KeyCategory.transport;
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
