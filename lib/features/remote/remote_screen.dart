import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/utils/ir_parser.dart';
import '../../core/utils/layout_engine.dart';
import '../../core/constants.dart';
import '../../data/models/ir_key.dart';
import '../../data/database/app_database.dart';

/// Riverpod provider that loads and parses IR keys for a given model.
final remoteKeysProvider =
    FutureProvider.family<List<IRKey>, String>((ref, modelId) async {
  final db = AppDatabase();
  final id = int.tryParse(modelId);
  if (id == null) return [];
  return db.getKeysByModel(id);
});

class RemoteScreen extends ConsumerWidget {
  final String modelId;

  const RemoteScreen({super.key, required this.modelId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final keysAsync = ref.watch(remoteKeysProvider(modelId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Remote Control'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _shareIrFile(context, keysAsync),
          ),
        ],
      ),
      body: keysAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => _buildEmptyState(theme, 'Error loading remote data'),
        data: (keys) {
          if (keys.isEmpty) {
            return _buildEmptyState(
                theme, 'No IR keys found for this model');
          }

          final layout = LayoutEngine.buildLayout(keys);
          return _buildRemoteUI(context, theme, layout, keys);
        },
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.remote_control_off_rounded,
              size: 80, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(message, style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }

  Widget _buildRemoteUI(
    BuildContext context,
    ThemeData theme,
    RemoteLayout layout,
    List<IRKey> allKeys,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.buttonSpacing),
      child: Column(
        children: [
          // ── Power Row ──
          if (layout.powerButtons.isNotEmpty) ...[
            _buildSectionLabel(theme, 'Power'),
            Wrap(
              spacing: AppConstants.buttonSpacing,
              runSpacing: AppConstants.buttonSpacing,
              children: layout.powerButtons
                  .map((pk) => _buildButton(context, theme, pk.key,
                      isPower: true))
                  .toList(),
            ),
            const SizedBox(height: AppConstants.buttonSpacing),
          ],

          // ── Volume + Channel ──
          if (layout.volumeButtons.isNotEmpty ||
              layout.channelButtons.isNotEmpty) ...[
            _buildSectionLabel(theme, 'Controls'),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Volume rocker
                if (layout.volumeButtons.isNotEmpty)
                  _buildRocker(theme, layout.volumeButtons, Icons.volume_up),
                // Channel rocker
                if (layout.channelButtons.isNotEmpty)
                  _buildRocker(
                      theme, layout.channelButtons, Icons.tv_rounded),
              ],
            ),
            const SizedBox(height: AppConstants.buttonSpacing),
          ],

          // ── D-Pad ──
          if (layout.directionalButtons.isNotEmpty) ...[
            _buildSectionLabel(theme, 'Navigation'),
            _buildDPad(context, theme, layout.directionalButtons),
            const SizedBox(height: AppConstants.buttonSpacing),
          ],

          // ── Number Pad ──
          if (layout.numericButtons.isNotEmpty) ...[
            _buildSectionLabel(theme, 'Numbers'),
            _buildNumberPad(context, theme, layout.numericButtons),
            const SizedBox(height: AppConstants.buttonSpacing),
          ],

          // ── Input Keys ──
          if (layout.inputButtons.isNotEmpty) ...[
            _buildSectionLabel(theme, 'Input'),
            Wrap(
              spacing: AppConstants.buttonSpacing,
              runSpacing: AppConstants.buttonSpacing,
              children: layout.inputButtons
                  .map((pk) => _buildButton(context, theme, pk.key))
                  .toList(),
            ),
            const SizedBox(height: AppConstants.buttonSpacing),
          ],

          // ── Transport Keys ──
          if (layout.transportButtons.isNotEmpty) ...[
            _buildSectionLabel(theme, 'Media'),
            Wrap(
              spacing: AppConstants.buttonSpacing,
              runSpacing: AppConstants.buttonSpacing,
              children: layout.transportButtons
                  .map((pk) => _buildButton(context, theme, pk.key))
                  .toList(),
            ),
            const SizedBox(height: AppConstants.buttonSpacing),
          ],

          // ── Other Keys ──
          if (layout.otherButtons.isNotEmpty) ...[
            _buildSectionLabel(theme, 'Other'),
            Wrap(
              spacing: AppConstants.buttonSpacing,
              runSpacing: AppConstants.buttonSpacing,
              children: layout.otherButtons
                  .map((pk) => _buildButton(context, theme, pk.key))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionLabel(ThemeData theme, String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 1.2,
            )),
      ),
    );
  }

  Widget _buildButton(
    BuildContext context,
    ThemeData theme,
    IRKey key, {
    bool isPower = false,
  }) {
    final color = isPower
        ? theme.colorScheme.error
        : theme.colorScheme.primaryContainer;
    final icon = _iconForKey(key);

    return SizedBox(
      width: AppConstants.buttonSize,
      height: AppConstants.buttonSize,
      child: RawMaterialButton(
        fillColor: color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        onPressed: () {
          HapticFeedback.lightImpact();
          _onKeyPressed(key);
        },
        child: icon ??
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                key.displayLabel,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isPower
                      ? theme.colorScheme.onError
                      : theme.colorScheme.onPrimaryContainer,
                ),
                textAlign: TextAlign.center,
              ),
            ),
      ),
    );
  }

  Widget _buildRocker(
      ThemeData theme, List<PositionedKey> keys, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: keys.map((pk) {
        final isUp = pk.key.category == KeyCategory.volumeUp ||
            pk.key.category == KeyCategory.channelUp;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: RawMaterialButton(
            fillColor: theme.colorScheme.secondaryContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            constraints: const BoxConstraints(
              minWidth: 72,
              minHeight: 48,
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              _onKeyPressed(pk.key);
            },
            child: Icon(
              isUp ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              color: theme.colorScheme.onSecondaryContainer,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDPad(
    BuildContext context,
    ThemeData theme,
    List<PositionedKey> keys,
  ) {
    // Build a cross-shaped D-Pad
    final up = keys.where((k) => k.key.name.toUpperCase() == 'KEY_UP');
    final down = keys.where((k) => k.key.name.toUpperCase() == 'KEY_DOWN');
    final left = keys.where((k) => k.key.name.toUpperCase() == 'KEY_LEFT');
    final right = keys.where((k) => k.key.name.toUpperCase() == 'KEY_RIGHT');
    final ok = keys.where((k) => k.key.name.toUpperCase() == 'KEY_OK');

    return Column(
      children: [
        // Up
        if (up.isNotEmpty)
          _dPadButton(theme, up.first.key, Icons.keyboard_arrow_up),
        const SizedBox(height: 4),
        // Left + OK + Right
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (left.isNotEmpty)
              _dPadButton(theme, left.first.key, Icons.keyboard_arrow_left),
            if (ok.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _dPadButton(theme, ok.first.key, null,
                    isCenter: true),
              ),
            if (right.isNotEmpty)
              _dPadButton(theme, right.first.key, Icons.keyboard_arrow_right),
          ],
        ),
        const SizedBox(height: 4),
        // Down
        if (down.isNotEmpty)
          _dPadButton(theme, down.first.key, Icons.keyboard_arrow_down),
      ],
    );
  }

  Widget _dPadButton(ThemeData theme, IRKey key, IconData? icon,
      {bool isCenter = false}) {
    return RawMaterialButton(
      fillColor: isCenter
          ? theme.colorScheme.tertiaryContainer
          : theme.colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      constraints: BoxConstraints(
        minWidth: isCenter ? 64 : 56,
        minHeight: isCenter ? 64 : 56,
      ),
      onPressed: () {
        HapticFeedback.lightImpact();
        _onKeyPressed(key);
      },
      child: icon != null
          ? Icon(icon, color: theme.colorScheme.onSurfaceVariant)
          : Text(key.displayLabel,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: theme.colorScheme.onTertiaryContainer,
              )),
    );
  }

  Widget _buildNumberPad(
    BuildContext context,
    ThemeData theme,
    List<PositionedKey> keys,
  ) {
    final sorted = keys.toList()
      ..sort((a, b) => a.key.name.compareTo(b.key.name));

    return Wrap(
      spacing: AppConstants.buttonSpacing,
      runSpacing: AppConstants.buttonSpacing,
      alignment: WrapAlignment.center,
      children: sorted
          .map((pk) => SizedBox(
                width: AppConstants.buttonSize,
                height: AppConstants.buttonSize,
                child: RawMaterialButton(
                  fillColor: theme.colorScheme.surfaceContainerHigh,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    _onKeyPressed(pk.key);
                  },
                  child: Text(
                    _numberLabel(pk.key),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ))
          .toList(),
    );
  }

  void _onKeyPressed(IRKey key) {
    // TODO: Transmit IR signal via Flipper Zero / other hardware
    debugPrint('IR key pressed: ${key.name}');
  }

  Future<void> _shareIrFile(
      BuildContext context, AsyncValue<List<IRKey>> keysAsync) async {
    keysAsync.whenData((keys) {
      if (keys.isNotEmpty) {
        final content = IRParser.serialize(keys);
        SharePlus.instance.share(
          ShareParams(text: content, subject: 'IRrecon - Remote File'),
        );
      }
    });
  }

  /// Map an IR key name to a Material icon where possible.
  static IconData? _iconForKey(IRKey key) {
    switch (key.name.toUpperCase()) {
      case 'KEY_POWER':
        return Icons.power_settings_new;
      case 'KEY_MUTE':
        return Icons.volume_off;
      case 'KEY_HOME':
        return Icons.home;
      case 'KEY_MENU':
        return Icons.menu;
      case 'KEY_BACK':
        return Icons.arrow_back;
      case 'KEY_EXIT':
        return Icons.close;
      case 'KEY_INFO':
        return Icons.info_outline;
      case 'KEY_SETUP':
        return Icons.tune;
      case 'KEY_GUIDE':
        return Icons.live_tv;
      default:
        return null;
    }
  }

  static String _numberLabel(IRKey key) {
    final upper = key.name.toUpperCase();
    if (upper == 'KEY_0') return '0';
    if (upper == 'KEY_1') return '1';
    if (upper == 'KEY_2') return '2';
    if (upper == 'KEY_3') return '3';
    if (upper == 'KEY_4') return '4';
    if (upper == 'KEY_5') return '5';
    if (upper == 'KEY_6') return '6';
    if (upper == 'KEY_7') return '7';
    if (upper == 'KEY_8') return '8';
    if (upper == 'KEY_9') return '9';
    return key.displayLabel;
  }
}
