import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../data/models/ir_key.dart';
import 'ir_protocols.dart';

/// Wraps the Android ConsumerIrManager API via a Flutter MethodChannel.
///
/// ## Usage
///
/// ```dart
/// final available = await IrTransmitter.isAvailable;
/// if (available) {
///   await IrTransmitter.transmit(irKey);
/// }
/// ```
class IrTransmitter {
  static const _channel = MethodChannel('com.irrecon/ir');

  /// Whether the device has an IR emitter.
  ///
  /// Returns `false` on non‑Android platforms or when `ConsumerIrManager`
  /// reports no emitter.
  static Future<bool> get isAvailable async {
    try {
      return (await _channel.invokeMethod<bool>('isAvailable')) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Transmit [key] via the IR blaster.
  ///
  /// Returns `true` if the transmission was queued successfully.
  ///
  /// **Raw signals** (`key.type == 'raw'` with non‑null `frequency` and
  /// `data`) are sent as‑is — the `data` string is parsed as
  /// space‑separated microsecond durations.
  ///
  /// **Parsed signals** (non‑null `protocol`, `address`, `command`) are
  /// decoded by [IRProtocolDecoder] into the appropriate timing array.
  ///
  /// Returns `false` when the platform channel is unavailable or the signal
  /// cannot be decoded.
  static Future<bool> transmit(IRKey key) async {
    try {
      // ── Raw signal ──
      if (key.type == 'raw' && key.frequency != null && key.data != null) {
        final pattern = key.data!
            .split(RegExp(r'\s+'))
            .where((s) => s.isNotEmpty)
            .map((s) => int.tryParse(s) ?? 0)
            .toList();

        if (pattern.isEmpty) return false;

        return await _channel.invokeMethod<bool>('transmit', <String, dynamic>{
          'frequency': key.frequency,
          'pattern': pattern,
        }) ?? false;
      }

      // ── Parsed signal ──
      if (key.protocol != null && key.address != null && key.command != null) {
        final decoded = IRProtocolDecoder.decode(
          protocol: key.protocol!,
          address: key.address!,
          command: key.command!,
        );

        if (decoded == null) return false;

        return await _channel.invokeMethod<bool>('transmit', <String, dynamic>{
          'frequency': decoded.frequency,
          'pattern': decoded.timing,
        }) ?? false;
      }

      return false;
    } on MissingPluginException {
      return false;
    } catch (e) {
      // Log but don't crash — IR is best‑effort
      debugPrint('IrTransmitter error: $e');
      return false;
    }
  }

  /// Transmit an NEC repeat signal (for long‑press / hold behaviour).
  static Future<bool> repeatNec() async {
    try {
      final pattern = IRProtocolDecoder.necRepeat();
      return (await _channel.invokeMethod<bool>('transmit', <String, dynamic>{
            'frequency': 38000,
            'pattern': pattern,
          })) ??
          false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Transmit a raw timing array at [frequency].
  static Future<bool> transmitRaw({
    required int frequency,
    required List<int> pattern,
  }) async {
    try {
      return (await _channel.invokeMethod<bool>('transmit', <String, dynamic>{
            'frequency': frequency,
            'pattern': pattern,
          })) ??
          false;
    } on MissingPluginException {
      return false;
    }
  }
}
