import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/utils/ir_parser.dart';
import '../../core/utils/layout_engine.dart';
import '../../core/utils/ir_transmitter.dart';
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
          Icon(Icons.settings_remote,
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
                  _buildRocker(context, theme, layout.volumeButtons, Icons.volume_up),
                // Channel rocker
                if (layout.channelButtons.isNotEmpty)
                  _buildRocker(
                      context, theme, layout.channelButtons, Icons.tv_rounded),
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
          _onKeyPressed(context, key);
        },
        child: icon != null
            ? Icon(icon, size: 24, color: isPower
                ? theme.colorScheme.onError
                : theme.colorScheme.onPrimaryContainer)
            : FittedBox(
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
      BuildContext context, ThemeData theme, List<PositionedKey> keys, IconData icon) {
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
              _onKeyPressed(context, pk.key);
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
          _dPadButton(context, theme, up.first.key, Icons.keyboard_arrow_up),
        const SizedBox(height: 4),
        // Left + OK + Right
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (left.isNotEmpty)
              _dPadButton(context, theme, left.first.key, Icons.keyboard_arrow_left),
            if (ok.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _dPadButton(context, theme, ok.first.key, null,
                    isCenter: true),
              ),
            if (right.isNotEmpty)
              _dPadButton(context, theme, right.first.key, Icons.keyboard_arrow_right),
          ],
        ),
        const SizedBox(height: 4),
        // Down
        if (down.isNotEmpty)
          _dPadButton(context, theme, down.first.key, Icons.keyboard_arrow_down),
      ],
    );
  }

  Widget _dPadButton(BuildContext context, ThemeData theme, IRKey key, IconData? icon,
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
        _onKeyPressed(context, key);
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
                    _onKeyPressed(context, pk.key);
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

  void _onKeyPressed(BuildContext context, IRKey key) {
    IrTransmitter.transmit(key).then((success) {
      if (!context.mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${key.displayLabel} sent'),
            duration: const Duration(milliseconds: 600),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        _showNoIrDialog(context);
      }
    });
  }

  void _showNoIrDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.settings_remote_outlined, size: 48),
        title: const Text('No IR emitter'),
        content: const Text(
          'This device does not have an infrared blaster, or '
          'the IR signal could not be sent.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _shareIrFile(
      BuildContext context, AsyncValue<List<IRKey>> keysAsync) async {
    keysAsync.whenData((keys) {
      if (keys.isNotEmpty) {
        final content = IRParser.serialize(keys);
        Share.share(content, subject: 'IRrecon - Remote File');
      }
    });
  }

  /// Map an IR key name to a Material icon where possible.
  static const Map<String, IconData> _keyIcons = {
    // ── Power ──
    'KEY_POWER': Icons.power_settings_new,
    'KEY_POWER_ON': Icons.power_settings_new,
    'KEY_POWER_OFF': Icons.power_off,
    'KEY_POWER_TOGGLE': Icons.power_settings_new,

    // ── Mute ──
    'KEY_MUTE': Icons.volume_off,

    // ── Volume ──
    'KEY_VOLUMEUP': Icons.volume_up,
    'KEY_VOLUMEUP_UP': Icons.volume_up,
    'KEY_VOLUMEDOWN': Icons.volume_down,
    'KEY_VOLUMEDOWN_DOWN': Icons.volume_down,

    // ── Channel ──
    'KEY_CHANNELUP': Icons.add_circle_outline,
    'KEY_CHANNELUP_UP': Icons.add_circle_outline,
    'KEY_CHANNELDOWN': Icons.remove_circle_outline,
    'KEY_CHANNELDOWN_DOWN': Icons.remove_circle_outline,

    // ── Directional ──
    'KEY_UP': Icons.keyboard_arrow_up,
    'KEY_DOWN': Icons.keyboard_arrow_down,
    'KEY_LEFT': Icons.keyboard_arrow_left,
    'KEY_RIGHT': Icons.keyboard_arrow_right,
    'KEY_OK': Icons.check_circle_outline,

    // ── Menu / Navigation ──
    'KEY_HOME': Icons.home,
    'KEY_MENU': Icons.menu,
    'KEY_BACK': Icons.arrow_back,
    'KEY_EXIT': Icons.close,
    'KEY_INFO': Icons.info_outline,
    'KEY_SETUP': Icons.tune,
    'KEY_GUIDE': Icons.live_tv,
    'KEY_HELP': Icons.help_outline,

    // ── Input / Source ──
    'KEY_INPUT': Icons.input,
    'KEY_SOURCE': Icons.input,
    'KEY_HDMI': Icons.cable,
    'KEY_HDMI1': Icons.cable,
    'KEY_HDMI2': Icons.cable,
    'KEY_HDMI3': Icons.cable,
    'KEY_AV': Icons.videocam,
    'KEY_TV': Icons.tv,
    'KEY_RADIO': Icons.radio,
    'KEY_VGA': Icons.computer,
    'KEY_DVI': Icons.computer,
    'KEY_COMPONENT': Icons.videocam,

    // ── Media Transport ──
    'KEY_PLAY': Icons.play_arrow,
    'KEY_PAUSE': Icons.pause,
    'KEY_STOP': Icons.stop,
    'KEY_REWIND': Icons.fast_rewind,
    'KEY_FASTFORWARD': Icons.fast_forward,
    'KEY_NEXT': Icons.skip_next,
    'KEY_PREVIOUS': Icons.skip_previous,
    'KEY_RECORD': Icons.radio_button_checked,
    'KEY_PLAY_PAUSE': Icons.pause_circle,
    'KEY_SLOW': Icons.slow_motion_video,
    'KEY_REPEAT': Icons.repeat,
    'KEY_SHUFFLE': Icons.shuffle,
    'KEY_SUBTITLE': Icons.subtitles,
    'KEY_AUDIO': Icons.audiotrack,
    'KEY_LANGUAGE': Icons.language,

    // ── Color buttons ──
    'KEY_RED': Icons.lens,
    'KEY_GREEN': Icons.lens,
    'KEY_YELLOW': Icons.lens,
    'KEY_BLUE': Icons.lens,

    // ── Brightness / Picture ──
    'KEY_BRIGHTNESS_UP': Icons.brightness_high,
    'KEY_BRIGHTNESS_DOWN': Icons.brightness_low,
    'KEY_DIMMER': Icons.brightness_low,
    'KEY_PICTURE': Icons.image,
    'KEY_ASPECT': Icons.aspect_ratio,
    'KEY_CONTRAST': Icons.contrast,
    'KEY_SLEEP': Icons.bedtime,
    'KEY_MODE': Icons.swap_horiz,

    // ── Teletext ──
    'KEY_TEXT': Icons.text_fields,
    'KEY_TELETEXT': Icons.text_fields,

    // ── Recording ──
    'KEY_EJECT': Icons.eject,
    'KEY_OPEN': Icons.open_in_new,

    // ── Zoom ──
    'KEY_ZOOM': Icons.zoom_in,
    'KEY_ZOOM_IN': Icons.zoom_in,
    'KEY_ZOOM_OUT': Icons.zoom_out,

    // ── Misc ──
    'KEY_SELECT': Icons.check_circle,
    'KEY_ENTER': Icons.keyboard_return,
    'KEY_CLEAR': Icons.backspace,
    'KEY_DELETE': Icons.delete,
    'KEY_MEDIA': Icons.library_music,
    'KEY_SOUND': Icons.volume_up,
    'KEY_TUNER': Icons.radio,
    'KEY_BASS': Icons.music_note,
    'KEY_TREBLE': Icons.music_note,
    'KEY_GOTO': Icons.gps_fixed,
    'KEY_SEARCH': Icons.search,
    'KEY_FAVORITES': Icons.favorite,
    'KEY_WIDE': Icons.wide,
    'KEY_SURROUND': Icons.surround_sound,
    'KEY_MONITOR': Icons.monitor,
  };

  static IconData? _iconForKey(IRKey key) {
    // Direct match first
    final icon = _keyIcons[key.name.toUpperCase()];
    if (icon != null) return icon;

    // Fallback: check if name starts with KEY_ followed by a digit → numeric
    final upper = key.name.toUpperCase();
    if (upper.startsWith('KEY_') &&
        upper.length == 6 &&
        upper.codeUnitAt(4) >= 48 &&
        upper.codeUnitAt(4) <= 57) {
      // Numeric keys — show as text via displayLabel, no icon
      return null;
    }

    return null;
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
