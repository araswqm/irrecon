/// Decodes parsed IR protocol signals (protocol + address + command)
/// into raw timing arrays for transmission via ConsumerIrManager.
///
/// Each decode method returns a record `(frequency, timing)` where timing
/// is a list of alternating mark (ON) / space (OFF) durations in
/// microseconds.  The calling code passes these directly to
/// `ConsumerIrManager.transmit(frequency, timing)`.
///
/// ## Supported protocols
///
/// | Protocol   | Carrier  | Encoding              | Frame bits     |
/// |------------|----------|-----------------------|----------------|
/// | NEC        | 38 kHz   | Pulse distance        | 32             |
/// | NECext     | 38 kHz   | Pulse distance        | 32 (16‑bit ad) |
/// | SIRC12     | 40 kHz   | Pulse width           | 12             |
/// | SIRC15     | 40 kHz   | Pulse width           | 15             |
/// | SIRC20     | 40 kHz   | Pulse width           | 20             |
/// | RC5        | 36 kHz   | Manchester (bi‑phase) | 14             |
/// | RC6        | 36 kHz   | Manchester (bi‑phase) | 21             |
/// | Samsung    | 38 kHz   | Pulse distance (NEC‑like) | 32         |
class IRProtocolDecoder {
  /// Decode [protocol] + [address] + [command] into a transmit‑ready record.
  ///
  /// Returns `(frequency, timing)` on success, or `null` when the protocol
  /// is not supported.
  static ({int frequency, List<int> timing})? decode({
    required String protocol,
    required String address,
    required String command,
  }) {
    final upper = protocol.toUpperCase();

    if (upper == 'NEC') return _decodeNec(address, command, extended: false);
    if (upper == 'NECEXT' || upper == 'NECX') {
      return _decodeNec(address, command, extended: true);
    }
    if (upper == 'SIRC' || upper == 'SIRC12') return _decodeSirc(address, command, 12);
    if (upper == 'SIRC15') return _decodeSirc(address, command, 15);
    if (upper == 'SIRC20') return _decodeSirc(address, command, 20);
    if (upper == 'RC5') return _decodeRc5(address, command);
    if (upper == 'RC6') return _decodeRc6(address, command);
    if (upper == 'SAMSUNG' || upper == 'SAMSUNG20' || upper == 'SAMSUNG32') {
      return _decodeSamsung(address, command);
    }

    return null; // unsupported protocol
  }

  /// Generate an NEC / NECext repeat signal.
  ///
  /// NEC repeat: 9000 µs mark + 2250 µs space + 562 µs mark.
  static List<int> necRepeat() => [9000, 2250, 562];

  // ── helpers ──

  /// Parse a hex‑string like `"02 00 00 00"` or `"FF"` into a list of bytes.
  static List<int> _parseHexBytes(String hex) {
    return hex
        .trim()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .map((s) => int.parse(s, radix: 16))
        .toList();
  }

  /// Return the low 8 bits of the first non‑zero byte, or fallback to 0.
  static int _firstByte(String hex) {
    final bytes = _parseHexBytes(hex);
    return bytes.isNotEmpty ? bytes[0] : 0;
  }

  /// Return the low 16 bits assembled from the first two bytes (little‑endian).
  static int _firstTwoBytesLe(String hex) {
    final bytes = _parseHexBytes(hex);
    if (bytes.isEmpty) return 0;
    if (bytes.length == 1) return bytes[0];
    return bytes[0] | (bytes[1] << 8);
  }

  // ── NEC & NECext ──────────────────────────────────────────────────────

  /// NEC — leader + 32 bits (LSB‑first, pulse‑distance).
  ///
  /// Standard NEC:   addr8 + ~addr8 + cmd8 + ~cmd8
  /// Extended NEC:   addr16       + cmd8 + ~cmd8
  static ({int frequency, List<int> timing}) _decodeNec(
    String address,
    String command, {
    bool extended = false,
  }) {
    final cmd = _firstByte(command);
    final timing = <int>[9000, 4500]; // leader

    void writeBit(int bit) {
      timing.add(562); // mark
      timing.add(bit == 1 ? 1687 : 562); // space
    }

    if (extended) {
      // 16‑bit address + 8‑bit cmd + 8‑bit ~cmd
      final addr = _firstTwoBytesLe(address);
      for (var i = 0; i < 16; i++) writeBit((addr >> i) & 1);
    } else {
      // 8‑bit address + ~address
      final addr = _firstByte(address);
      for (var i = 0; i < 8; i++) writeBit((addr >> i) & 1);
      for (var i = 0; i < 8; i++) writeBit((~addr >> i) & 1);
    }

    // 8‑bit command + ~command
    for (var i = 0; i < 8; i++) writeBit((cmd >> i) & 1);
    for (var i = 0; i < 8; i++) writeBit((~cmd >> i) & 1);

    return (frequency: 38000, timing: timing);
  }

  // ── SIRC (Sony) ───────────────────────────────────────────────────────

  /// SIRC — leader + N bits (LSB‑first, pulse‑width).
  ///
  /// SIRC12:  7‑bit cmd + 5‑bit addr  = 12 bits
  /// SIRC15:  7‑bit cmd + 8‑bit addr  = 15 bits
  /// SIRC20:  7‑bit cmd + 5‑bit addr + 8‑bit extended = 20 bits
  static ({int frequency, List<int> timing}) _decodeSirc(
    String address,
    String command,
    int bitCount,
  ) {
    final cmd = _firstByte(command) & 0x7F; // 7 bits
    final addr = _firstByte(address);

    // Assemble bits: command first (LSB), then address
    final bits = <int>[];
    for (var i = 0; i < 7; i++) bits.add((cmd >> i) & 1);

    if (bitCount == 12) {
      for (var i = 0; i < 5; i++) bits.add((addr >> i) & 1);
    } else if (bitCount == 15) {
      for (var i = 0; i < 8; i++) bits.add((addr >> i) & 1);
    } else {
      // SIRC20 — 5‑bit addr + 8‑bit extended
      for (var i = 0; i < 5; i++) bits.add((addr >> i) & 1);
      for (var i = 0; i < 8; i++) bits.add((addr >> (5 + i)) & 1);
    }

    final timing = <int>[2400, 600]; // leader
    for (final bit in bits) {
      timing.add(bit == 1 ? 1200 : 600); // mark
      timing.add(600); // space
    }

    return (frequency: 40000, timing: timing);
  }

  // ── RC5 (Philips) ─────────────────────────────────────────────────────

  /// RC5 — 2 start bits (both 1) + toggle + 5‑bit addr + 6‑bit cmd.
  ///
  /// Manchester encoding @ 36 kHz, bit period = 1778 µs.
  static ({int frequency, List<int> timing}) _decodeRc5(
    String address,
    String command,
  ) {
    final addr = _firstByte(address) & 0x1F; // 5 bits
    final cmd = _firstByte(command) & 0x3F; // 6 bits

    // Manchester @ 889 µs half‑bit:
    //   '1' → space + mark   (half₂ = mark)
    //   '0' → mark + space   (half₂ = space)
    void addManchesterBit(int bit, List<int> timing) {
      if (bit == 1) {
        timing.addAll([889, 889]); // space, mark
      } else {
        timing.addAll([889, 889]); // mark, space
      }
    }

    final timing = <int>[];
    // Start bits S1, S2 = both logical '1'
    addManchesterBit(1, timing);
    addManchesterBit(1, timing);

    // Toggle + Address (MSB first) + Command (MSB first)
    // Toggle bit — always 0 for now (first press)
    addManchesterBit(0, timing);

    for (var i = 4; i >= 0; i--) addManchesterBit((addr >> i) & 1, timing);
    for (var i = 5; i >= 0; i--) addManchesterBit((cmd >> i) & 1, timing);

    return (frequency: 36000, timing: timing);
  }

  // ── RC6 (Philips) ─────────────────────────────────────────────────────

  /// RC6 — leader + start bit + mode + toggle + 8‑bit addr + 8‑bit cmd.
  ///
  /// Manchester encoding @ 36 kHz, bit period = 889 µs.
  static ({int frequency, List<int> timing}) _decodeRc6(
    String address,
    String command,
  ) {
    final addr = _firstByte(address);
    final cmd = _firstByte(command);

    void addManchesterBit(int bit, List<int> timing) {
      if (bit == 1) {
        timing.addAll([444, 445]); // space, mark
      } else {
        timing.addAll([445, 444]); // mark, space
      }
    }

    final timing = <int>[2666, 889]; // leader

    // Start bit (always '1')
    addManchesterBit(1, timing);

    // Mode = 000 (RC6‑6‑6)
    addManchesterBit(0, timing);
    addManchesterBit(0, timing);
    addManchesterBit(0, timing);

    // Toggle
    addManchesterBit(0, timing);

    // Address (MSB first)
    for (var i = 7; i >= 0; i--) addManchesterBit((addr >> i) & 1, timing);

    // Command (MSB first)
    for (var i = 7; i >= 0; i--) addManchesterBit((cmd >> i) & 1, timing);

    return (frequency: 36000, timing: timing);
  }

  // ── Samsung ────────────────────────────────────────────────────────────

  /// Samsung — NEC‑like pulse‑distance with a 4500/4500 leader.
  ///
  /// Frame: addr8 + ~addr8 + cmd8 + ~cmd8 (same as standard NEC, but leader
  /// is half as long and there is no repeat code — frame is repeated raw).
  static ({int frequency, List<int> timing}) _decodeSamsung(
    String address,
    String command,
  ) {
    final addr = _firstByte(address);
    final cmd = _firstByte(command);
    final timing = <int>[4500, 4500]; // leader (shorter than NEC)

    void writeBit(int bit) {
      timing.add(562);
      timing.add(bit == 1 ? 1687 : 562);
    }

    for (var i = 0; i < 8; i++) writeBit((addr >> i) & 1);
    for (var i = 0; i < 8; i++) writeBit((~addr >> i) & 1);
    for (var i = 0; i < 8; i++) writeBit((cmd >> i) & 1);
    for (var i = 0; i < 8; i++) writeBit((~cmd >> i) & 1);

    return (frequency: 38000, timing: timing);
  }
}
