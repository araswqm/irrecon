import 'package:flutter/material.dart';
import '../models/ir_key.dart';
import '../constants.dart';

/// Position and size of a button on the remote control grid.
class ButtonLayout {
  final int row;
  final int col;
  final int colSpan;
  final int rowSpan;

  const ButtonLayout({
    required this.row,
    required this.col,
    this.colSpan = 1,
    this.rowSpan = 1,
  });
}

/// Result of the layout engine: positioned buttons ready for rendering.
class RemoteLayout {
  final List<PositionedKey> powerButtons;
  final List<PositionedKey> volumeButtons;
  final List<PositionedKey> channelButtons;
  final List<PositionedKey> directionalButtons;
  final List<PositionedKey> numericButtons;
  final List<PositionedKey> inputButtons;
  final List<PositionedKey> transportButtons;
  final List<PositionedKey> otherButtons;

  const RemoteLayout({
    this.powerButtons = const [],
    this.volumeButtons = const [],
    this.channelButtons = const [],
    this.directionalButtons = const [],
    this.numericButtons = const [],
    this.inputButtons = const [],
    this.transportButtons = const [],
    this.otherButtons = const [],
  });

  bool get isEmpty =>
      powerButtons.isEmpty &&
      volumeButtons.isEmpty &&
      channelButtons.isEmpty &&
      directionalButtons.isEmpty &&
      numericButtons.isEmpty &&
      inputButtons.isEmpty &&
      transportButtons.isEmpty &&
      otherButtons.isEmpty;
}

/// A key positioned on the grid.
class PositionedKey {
  final IRKey key;
  final ButtonLayout layout;

  const PositionedKey({required this.key, required this.layout});
}

/// Smart layout engine that classifies and positions IR keys.
class LayoutEngine {
  /// Build a complete remote control layout from a list of IR keys.
  static RemoteLayout buildLayout(List<IRKey> keys) {
    List<PositionedKey> power = [];
    List<PositionedKey> volume = [];
    List<PositionedKey> channel = [];
    List<PositionedKey> directional = [];
    List<PositionedKey> numeric = [];
    List<PositionedKey> input = [];
    List<PositionedKey> transport = [];
    List<PositionedKey> other = [];

    // Section 1: Power row (row 0)
    for (final key in keys) {
      if (key.category == KeyCategory.power) {
        power.add(PositionedKey(
          key: key,
          layout: const ButtonLayout(row: 0, col: 0, colSpan: 2),
        ));
      } else if (key.category == KeyCategory.mute) {
        power.add(PositionedKey(
          key: key,
          layout: const ButtonLayout(row: 0, col: 3, colSpan: 2),
        ));
      }
    }

    // Section 2: Volume + Channel rockers (row 1)
    for (final key in keys) {
      if (key.category == KeyCategory.volumeUp) {
        volume.add(PositionedKey(
          key: key,
          layout: const ButtonLayout(row: 1, col: 0),
        ));
      } else if (key.category == KeyCategory.volumeDown) {
        volume.add(PositionedKey(
          key: key,
          layout: const ButtonLayout(row: 2, col: 0),
        ));
      } else if (key.category == KeyCategory.channelUp) {
        channel.add(PositionedKey(
          key: key,
          layout: const ButtonLayout(row: 1, col: 4),
        ));
      } else if (key.category == KeyCategory.channelDown) {
        channel.add(PositionedKey(
          key: key,
          layout: const ButtonLayout(row: 2, col: 4),
        ));
      }
    }

    // Section 3: D-Pad (rows 2-3, centered)
    int dPadIndex = 0;
    List<ButtonLayout> dPadPositions = [
      const ButtonLayout(row: 2, col: 1), // up
      const ButtonLayout(row: 3, col: 0), // left
      const ButtonLayout(row: 3, col: 1), // ok
      const ButtonLayout(row: 3, col: 2), // right
      const ButtonLayout(row: 4, col: 1), // down
    ];
    for (final key in keys) {
      if (key.category == KeyCategory.directional) {
        final pos = dPadIndex < dPadPositions.length
            ? dPadPositions[dPadIndex]
            : ButtonLayout(row: 4 + (dPadIndex - 5) ~/ 4, col: (dPadIndex - 5) % 4);
        directional.add(PositionedKey(key: key, layout: pos));
        dPadIndex++;
      }
    }

    // Section 4: Number pad (rows 5-7, 3 columns)
    int numIndex = 0;
    for (final key in keys) {
      if (key.category == KeyCategory.numeric) {
        final row = 5 + numIndex ~/ 3;
        final col = numIndex % 3;
        numeric.add(PositionedKey(
          key: key,
          layout: ButtonLayout(row: row, col: col),
        ));
        numIndex++;
      }
    }

    // Section 5: Input keys
    int inputIndex = 0;
    for (final key in keys) {
      if (key.category == KeyCategory.input) {
        input.add(PositionedKey(
          key: key,
          layout: ButtonLayout(row: 1 + inputIndex, col: 2),
        ));
        inputIndex++;
      }
    }

    // Section 6: Transport keys
    int transportIndex = 0;
    for (final key in keys) {
      if (key.category == KeyCategory.transport) {
        transport.add(PositionedKey(
          key: key,
          layout: ButtonLayout(row: transportIndex ~/ 4, col: transportIndex % 4),
        ));
        transportIndex++;
      }
    }

    // Section 7: Everything else
    int otherIndex = 0;
    for (final key in keys) {
      if (key.category == KeyCategory.other) {
        final row = 8 + otherIndex ~/ 4;
        final col = otherIndex % 4;
        other.add(PositionedKey(
          key: key,
          layout: ButtonLayout(row: row, col: col),
        ));
        otherIndex++;
      }
    }

    return RemoteLayout(
      powerButtons: power,
      volumeButtons: volume,
      channelButtons: channel,
      directionalButtons: directional,
      numericButtons: numeric,
      inputButtons: input,
      transportButtons: transport,
      otherButtons: other,
    );
  }
}
