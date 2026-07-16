import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/api/api_engine.dart';
import '../../core/constants.dart';
import '../../app/theme.dart';
import '../../core/utils/ir_parser.dart';
import '../../core/utils/ir_logger.dart';
import '../../data/database/app_database.dart';
import '../../data/models/device_type.dart';
import '../../data/models/brand.dart';
import '../../data/models/ir_model.dart';
import '../../data/models/ir_key.dart';

/// Tracks whether each API key field is obscured.
final _obscuredProvider = StateProvider.autoDispose<Set<String>>((ref) => {});

/// Current provider selection.
final _providerSelectionProvider =
    StateProvider.autoDispose<AIProvider>((ref) => AIProvider.openAI);

/// Download progress (null = idle, 0.0-1.0 = in progress, negative = error).
final _downloadProgressProvider = StateProvider.autoDispose<double?>((ref) => null);

/// Download status message.
final _downloadStatusProvider = StateProvider.autoDispose<String>((ref) => '');

/// Custom API headers as a list of (key, value) pairs.
final _customHeadersProvider =
    StateProvider.autoDispose<List<({String key, String value})>>((ref) => []);

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── AI Provider Section ──
          _buildSectionHeader(theme, 'AI Provider'),
          _buildProviderSelector(ref),
          const SizedBox(height: 24),

          // ── API Keys ──
          _buildSectionHeader(theme, 'API Keys'),
          _buildOpenAiKeyField(context, ref),
          _buildAnthropicKeyField(context, ref),
          _buildGeminiKeyField(context, ref),
          _buildOllamaUrlField(context, ref),
          const SizedBox(height: 8),
          _buildCustomApiFields(context, ref),
          const SizedBox(height: 24),

          // ── Database Section ──
          _buildSectionHeader(theme, 'Database'),
          _buildDatabaseCard(context, ref),
          const SizedBox(height: 24),

          // ── Debug Log Section ──
          _buildSectionHeader(theme, 'Debug'),
          _buildDebugLogCard(context),
          const SizedBox(height: 24),

          // ── Theme Section ──
          _buildSectionHeader(theme, 'Appearance'),
          _buildThemeSelector(ref),
          const SizedBox(height: 24),

          // ── About Section ──
          _buildSectionHeader(theme, 'About'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.info_rounded,
                      color: theme.colorScheme.primary),
                  title: const Text('IRrecon'),
                  subtitle: const Text('Version 1.0.0'),
                ),
                ListTile(
                  leading: Icon(Icons.code_rounded,
                      color: theme.colorScheme.primary),
                  title: const Text('Source'),
                  subtitle: const Text('github.com/Lucaslhm/Flipper-IRDB'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildProviderSelector(WidgetRef ref) {
    final selected = ref.watch(_providerSelectionProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: DropdownButtonFormField<AIProvider>(
          value: selected,
          decoration: const InputDecoration(
            labelText: 'Vision Provider',
            prefixIcon: Icon(Icons.psychology_rounded),
            border: InputBorder.none,
          ),
          items: [
            _providerItem(AIProvider.openAI, 'OpenAI GPT-4o'),
            _providerItem(AIProvider.anthropic, 'Anthropic Claude'),
            _providerItem(AIProvider.gemini, 'Google Gemini'),
            _providerItem(AIProvider.ollama, 'Ollama (Local)'),
            _providerItem(AIProvider.custom, 'Custom API'),
          ],
          onChanged: (p) {
            if (p != null) {
              ref.read(_providerSelectionProvider.notifier).state = p;
              _saveProvider(p);
            }
          },
        ),
      ),
    );
  }

  DropdownMenuItem<AIProvider> _providerItem(AIProvider p, String label) {
    return DropdownMenuItem(value: p, child: Text(label));
  }

  Widget _buildOpenAiKeyField(BuildContext context, WidgetRef ref) {
    return _keyField(
      context,
      ref,
      key: AppConstants.keyOpenAiKey,
      label: 'OpenAI API Key',
      icon: Icons.key_rounded,
      hint: 'sk-...',
    );
  }

  Widget _buildAnthropicKeyField(BuildContext context, WidgetRef ref) {
    return _keyField(
      context,
      ref,
      key: AppConstants.keyAnthropicKey,
      label: 'Anthropic API Key',
      icon: Icons.key_rounded,
      hint: 'sk-ant-...',
    );
  }

  Widget _buildGeminiKeyField(BuildContext context, WidgetRef ref) {
    return _keyField(
      context,
      ref,
      key: AppConstants.keyGeminiKey,
      label: 'Gemini API Key',
      icon: Icons.key_rounded,
      hint: 'AIza...',
    );
  }

  Widget _buildOllamaUrlField(BuildContext context, WidgetRef ref) {
    return _keyField(
      context,
      ref,
      key: AppConstants.keyOllamaUrl,
      label: 'Ollama URL',
      icon: Icons.link_rounded,
      hint: 'http://localhost:11434',
      obscure: false,
    );
  }

  Widget _buildCustomApiFields(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(_providerSelectionProvider);
    if (selected != AIProvider.custom) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(Theme.of(context), 'Custom API Configuration'),
        _buildCustomEndpointField(context),
        const SizedBox(height: 8),
        _buildCustomHeadersEditor(context, ref),
        const SizedBox(height: 8),
        _buildCustomBodyTemplateField(context),
        const SizedBox(height: 8),
        _buildTestConnectionButton(context),
      ],
    );
  }

  Widget _buildCustomEndpointField(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: StatefulBuilder(
          builder: (context, setInnerState) {
            return TextFormField(
              key: const ValueKey('custom_endpoint'),
              initialValue: '',
              decoration: const InputDecoration(
                labelText: 'Custom Endpoint URL',
                hintText: 'https://your-api.com/v1/chat/completions',
                prefixIcon: Icon(Icons.link_rounded),
                border: InputBorder.none,
              ),
              onFieldSubmitted: (value) {
                if (value.isNotEmpty) {
                  const FlutterSecureStorage().write(
                    key: AppConstants.keyCustomEndpoint,
                    value: value,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Endpoint saved')),
                  );
                }
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildCustomHeadersEditor(BuildContext context, WidgetRef ref) {
    final headers = ref.watch(_customHeadersProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.list_alt_rounded, size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text('Custom Headers',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        )),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  onPressed: () {
                    ref.read(_customHeadersProvider.notifier).update(
                      (state) => [...state, (key: '', value: '')],
                    );
                  },
                  tooltip: 'Add header',
                ),
              ],
            ),
            if (headers.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'No custom headers. Add headers for authentication etc.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            ...headers.asMap().entries.map((entry) {
              final i = entry.key;
              final h = entry.value;
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Header name',
                          isDense: true,
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 8, vertical: 8),
                        ),
                        controller: TextEditingController(text: h.key),
                        onChanged: (v) {
                          final list = [...headers];
                          list[i] = (key: v, value: list[i].value);
                          ref.read(_customHeadersProvider.notifier).state = list;
                          _saveCustomHeaders(list);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Value',
                          isDense: true,
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 8, vertical: 8),
                        ),
                        controller: TextEditingController(text: h.value),
                        onChanged: (v) {
                          final list = [...headers];
                          list[i] = (key: list[i].key, value: v);
                          ref.read(_customHeadersProvider.notifier).state = list;
                          _saveCustomHeaders(list);
                        },
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.remove_circle_outline,
                          size: 20, color: Theme.of(context).colorScheme.error),
                      onPressed: () {
                        final list = [...headers]..removeAt(i);
                        ref.read(_customHeadersProvider.notifier).state = list;
                        _saveCustomHeaders(list);
                      },
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomBodyTemplateField(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.description_outlined,
                    size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text('Request Body Template',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        )),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Use {{image_base64}} for the image and {{prompt}} for the analysis prompt.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 120,
              child: TextField(
                key: const ValueKey('custom_body_template'),
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  hintText: '{"image": "{{image_base64}}", "prompt": "{{prompt}}"}',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.all(8),
                ),
                onChanged: (value) {
                  if (value.isNotEmpty) {
                    const FlutterSecureStorage().write(
                      key: AppConstants.keyCustomBodyTemplate,
                      value: value,
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestConnectionButton(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(Icons.wifi_tethering_rounded,
            color: Theme.of(context).colorScheme.primary),
        title: const Text('Test Connection'),
        subtitle: const Text('Verify API endpoint is reachable'),
        trailing: const Icon(Icons.arrow_forward_rounded),
        onTap: () => _testCustomConnection(context),
      ),
    );
  }

  Future<void> _testCustomConnection(BuildContext context) async {
    const storage = FlutterSecureStorage();
    try {
      final endpoint = await storage.read(key: AppConstants.keyCustomEndpoint);
      if (endpoint == null || endpoint.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please configure endpoint URL first')),
        );
        return;
      }
      final dio = Dio();
      final response = await dio.get(endpoint);
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connection successful!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection returned status ${response.statusCode}'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connection failed: $e')),
      );
    }
  }

  Future<void> _saveCustomHeaders(
      List<({String key, String value})> headers) async {
    final filtered =
        headers.where((h) => h.key.isNotEmpty).toList();
    if (filtered.isEmpty) return;
    final json = jsonEncode(
      Map.fromEntries(filtered.map((h) => MapEntry(h.key, h.value))),
    );
    const storage = FlutterSecureStorage();
    await storage.write(key: AppConstants.keyCustomHeaders, value: json);
  }

  Widget _keyField(
    BuildContext context,
    WidgetRef ref, {
    required String key,
    required String label,
    required IconData icon,
    String? hint,
    bool obscure = true,
  }) {
    final obscured = ref.watch(_obscuredProvider);
    final isObscured = obscured.contains(key);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: StatefulBuilder(
            builder: (context, setInnerState) {
              return ApiKeyField(
                storageKey: key,
                label: label,
                hint: hint,
                icon: icon,
                obscure: obscure,
                isObscured: isObscured,
                onToggleObscured: () {
                  if (isObscured) {
                    ref
                        .read(_obscuredProvider.notifier)
                        .update((s) => {...s}..remove(key));
                  } else {
                    ref
                        .read(_obscuredProvider.notifier)
                        .update((s) => {...s}..add(key));
                  }
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDebugLogCard(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.bug_report_rounded,
                color: Theme.of(context).colorScheme.primary),
            title: const Text('IR Debug Log'),
            subtitle: const Text('View IR transmission logs'),
            trailing: const Icon(Icons.arrow_forward_rounded),
            onTap: () => _showDebugLog(context),
          ),
          ButtonBar(
            children: [
              TextButton.icon(
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Refresh'),
                onPressed: () => _showDebugLog(context),
              ),
              TextButton.icon(
                icon: Icon(Icons.delete_outline, size: 18,
                    color: Theme.of(context).colorScheme.error),
                label: Text('Clear',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error)),
                onPressed: () => _clearDebugLog(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showDebugLog(BuildContext context) async {
    try {
      final logContent = await IrLogger().readLog();
      if (!context.mounted) return;

      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          insetPadding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                title: const Text('IR Debug Log'),
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.content_copy),
                    tooltip: 'Copy all',
                    onPressed: () {
                      // Copy to clipboard handled by platform channel if available
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Log copied (use long-press to select)')),
                      );
                    },
                  ),
                ],
              ),
              Expanded(
                child: logContent == '(no log entries yet)'
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inbox_rounded,
                                size: 48,
                                color: Theme.of(ctx).colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
                            const SizedBox(height: 8),
                            Text(
                              'No IR transmissions logged yet.\nTry pressing a button on a remote screen.',
                              textAlign: TextAlign.center,
                              style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(12),
                        child: SelectableText(
                          logContent,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            height: 1.4,
                          ),
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '~${logContent.split('\n').length} lines',
                      style: Theme.of(ctx).textTheme.bodySmall,
                    ),
                    TextButton.icon(
                      icon: Icon(Icons.delete_outline, size: 18,
                          color: Theme.of(ctx).colorScheme.error),
                      label: Text('Clear Log',
                          style: TextStyle(
                              color: Theme.of(ctx).colorScheme.error)),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _clearDebugLog(context);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to read log: $e')),
      );
    }
  }

  Future<void> _clearDebugLog(BuildContext context) async {
    try {
      await IrLogger().clear();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('IR debug log cleared'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to clear log: $e')),
      );
    }
  }

  Widget _buildThemeSelector(WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: DropdownButtonFormField<ThemeMode>(
          value: mode,
          decoration: const InputDecoration(
            labelText: 'Theme',
            prefixIcon: Icon(Icons.palette_rounded),
            border: InputBorder.none,
          ),
          items: [
            const DropdownMenuItem(
                value: ThemeMode.system, child: Text('System')),
            const DropdownMenuItem(
                value: ThemeMode.light, child: Text('Light')),
            const DropdownMenuItem(
                value: ThemeMode.dark, child: Text('Dark')),
          ],
          onChanged: (m) {
            if (m != null) ref.read(themeModeProvider.notifier).state = m;
          },
        ),
      ),
    );
  }

  Future<void> _saveProvider(AIProvider provider) async {
    final storage = const FlutterSecureStorage();
    await storage.write(
      key: AppConstants.keySelectedProvider,
      value: provider.storedName,
    );
  }

  Future<void> _saveKey(String key, String value) async {
    if (value.isNotEmpty) {
      final storage = const FlutterSecureStorage();
      await storage.write(key: key, value: value);
    }
  }

  Widget _buildDatabaseCard(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(_downloadProgressProvider);
    final status = ref.watch(_downloadStatusProvider);
    final theme = Theme.of(context);

    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.update_rounded, color: theme.colorScheme.primary),
            title: const Text('Update IR Database'),
            subtitle: Text(progress != null
                ? status.isNotEmpty
                    ? status
                    : 'Downloading...'
                : 'Download latest from GitHub (~20MB)'),
            trailing: progress != null
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: progress < 0
                        ? Icon(Icons.error_outline, color: theme.colorScheme.error)
                        : CircularProgressIndicator(
                            strokeWidth: 2,
                            value: progress > 0 ? progress : null,
                          ),
                  )
                : const Icon(Icons.download_rounded),
            onTap: progress != null ? null : () => _updateDatabase(context, ref),
          ),
          if (progress != null && progress >= 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: LinearProgressIndicator(value: progress > 0 ? progress : null),
            ),
        ],
      ),
    );
  }

  Future<void> _updateDatabase(BuildContext context, WidgetRef ref) async {
    final progress = ref.read(_downloadProgressProvider.notifier);
    final status = ref.read(_downloadStatusProvider.notifier);

    progress.state = 0.0;
    status.state = 'Downloading IR database...';

    try {
      // ── Step 1: Download ZIP ──
      final dio = Dio();
      final tempDir = await getTemporaryDirectory();
      final zipPath = '${tempDir.path}/irdb_main.zip';

      await dio.download(
        AppConstants.irdbUrl,
        zipPath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            progress.state = received / total;
            status.state =
                'Downloading... ${(received / 1024 / 1024).toStringAsFixed(1)}MB / ${(total / 1024 / 1024).toStringAsFixed(1)}MB';
          }
        },
      );

      status.state = 'Extracting archive...';
      progress.state = 0.0;

      // ── Step 2: Extract ZIP ──
      final bytes = await File(zipPath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      final extractDir = Directory('${tempDir.path}/irdb_extracted');
      if (extractDir.existsSync()) extractDir.deleteSync(recursive: true);
      extractDir.createSync();

      for (final file in archive) {
        if (file.isFile) {
          final outPath = '${extractDir.path}/${file.name}';
          final outFile = File(outPath);
          outFile.parent.createSync(recursive: true);
          await outFile.writeAsBytes(file.content as List<int>);
        }
      }

      status.state = 'Parsing IR files...';
      progress.state = 0.0;

      // ── Step 3: Walk the tree and collect .ir files ──
      final rootDir = Directory(extractDir.path);

      // GitHub zip wraps in `Flipper-IRDB-main/` — auto-descend if there's
      // a single wrapper dir so we land on the real device-type dirs.
      Directory scanRoot = rootDir;
      {
        final topDirs = <Directory>[];
        await for (final e in rootDir.list(recursive: false)) {
          if (e is Directory) topDirs.add(e);
        }
        if (topDirs.length == 1) scanRoot = topDirs.first;
      }

      // Discover device type directories (top-level dirs under scan root).
      // Skip _Converted_ (6944 files in CSV/Pronto/IR_Plus format, wrong structure),
      // .git, .github, and any other non-device-type dirs.
      final deviceTypeNames = <String>{};
      await for (final entity in scanRoot.list(recursive: false)) {
        if (entity is Directory) {
          final dirName = entity.path.replaceAll('\\', '/').split('/').last;
          if (dirName.startsWith('_') || dirName.startsWith('.')) continue;
          deviceTypeNames.add(dirName);
        }
      }

      if (deviceTypeNames.isEmpty) {
        throw Exception('No device type directories found in the archive');
      }

      // Determine brand depth for each device type.
      //
      // Most device types follow {dt}/{brand}/{model}.ir so brands are
      // at depth 1.  Car_Multimedia has an extra sub-category layer:
      //   Car_Multimedia/{subcat}/{brand}/{model}.ir  → depth 2
      //
      // A few files live directly in the dt dir (no brand):
      //   Fans/Generic_Fan_HS95104SK.ir               → depth 0
      //
      // The rule: if any depth-1 subdirectory directly contains .ir files,
      // brands are at depth 1.  Otherwise check depth 2.
      final brandDepth = <String, int>{};
      for (final dtName in deviceTypeNames) {
        final dtDir = Directory('${scanRoot.path}/$dtName');
        bool hasIrAtDepth1 = false;
        bool hasIrAtDepth2 = false;
        await for (final child in dtDir.list(recursive: false)) {
          if (child is File && child.path.endsWith('.ir')) {
            // brand-less file directly under dt dir
            if (!hasIrAtDepth1) hasIrAtDepth1 = true;
          } else if (child is Directory) {
            final hasDirectIr = await child.list(recursive: false).any(
              (e) => e is File && e.path.endsWith('.ir'),
            );
            if (hasDirectIr) hasIrAtDepth1 = true;
          }
        }
        if (!hasIrAtDepth1) {
          // Check depth 2 — sub-category dirs
          await for (final child in dtDir.list(recursive: false)) {
            if (child is Directory) {
              final subDirHasIr = await child.list(recursive: false).any(
                (e) => e is Directory && e.path.endsWith('.ir') == false,
              );
              if (subDirHasIr) {
                // This sub-category has subdirs — grandchild may be a brand
                await for (final subChild in child.list(recursive: false)) {
                  if (subChild is Directory) {
                    final gcIr = await subChild.list(recursive: false).any(
                      (e) => e is File && e.path.endsWith('.ir'),
                    );
                    if (gcIr) { hasIrAtDepth2 = true; break; }
                  } else if (subChild is File && subChild.path.endsWith('.ir')) {
                    hasIrAtDepth2 = true;
                    break;
                  }
                }
                if (hasIrAtDepth2) break;
              }
            }
          }
        }
        brandDepth[dtName] = hasIrAtDepth2 ? 2 : (hasIrAtDepth1 ? 1 : 0);
      }

      // Collect .ir files, excluding any under _Converted_ or similar dirs
      final allIrFiles = <File>[];
      await for (final entity in scanRoot.list(recursive: true)) {
        if (entity is File && entity.path.endsWith('.ir')) {
          final path = entity.path.replaceAll('\\', '/');
          // Skip files not under a known device type dir
          final belongs = deviceTypeNames.any((dt) => path.contains('/$dt/'));
          if (belongs) allIrFiles.add(entity);
        }
      }

      if (allIrFiles.isEmpty) {
        throw Exception('No .ir files found in the downloaded archive');
      }

      status.state = 'Indexing ${allIrFiles.length} IR files across ${deviceTypeNames.length} device types...';

      // ── Step 4: Parse & classify ──
      final Map<String, int> deviceTypeIds = {};
      final Map<String, Map<String, int>> brandIds = {};
      int nextDtId = 1;
      int nextBrandId = 1;
      int nextModelId = 1;

      final List<DeviceType> deviceTypes = [];
      final List<IRBrand> allBrands = [];
      final List<IRModel> allModels = [];
      final List<IRKey> allKeys = [];

      final processedModels = <String>{};

      for (var i = 0; i < allIrFiles.length; i++) {
        final file = allIrFiles[i];
        final path = file.path.replaceAll('\\', '/');
        final parts = path.split('/');

        // Find which known device type this file belongs to.
        // Structure: .../{device_type}/{brand}[/{subfolder}]/{model}.ir
        // Brand is always the first dir after device type; model from file name.
        String? deviceTypeName;
        int dtPartIdx = -1;
        for (final dt in deviceTypeNames) {
          final idx = parts.indexOf(dt);
          if (idx >= 0) {
            deviceTypeName = dt;
            dtPartIdx = idx;
            break;
          }
        }
        if (deviceTypeName == null || dtPartIdx < 0) continue;

        final depth = brandDepth[deviceTypeName] ?? 1;

        // Extract brand name based on detected depth.
        // depth=1: {dt}/{brand}/{model}.ir
        // depth=2: {dt}/{subcat}/{brand}/{model}.ir
        // depth=0: no brand dir — file is directly under dt
        String brandName;
        if (depth >= 1) {
          final brandPartIdx = dtPartIdx + depth;
          if (brandPartIdx >= parts.length) continue;
          brandName = parts[brandPartIdx];
        } else {
          // brand-less file — manufacture a brand from the file name prefix
          brandName = 'Unknown';
        }

        // Model name from the file name (most specific identifier)
        final fileName = parts.last;
        final modelName = fileName.replaceAll('.ir', '');

        final modelKey = '$deviceTypeName/$brandName/$modelName';
        if (processedModels.contains(modelKey)) continue;
        processedModels.add(modelKey);

        // Parse .ir file
        try {
          final content = await file.readAsString();
          final keys = IRParser.parse(content);

          // Skip files with no parsable keys
          if (keys.isEmpty) continue;

          // Ensure device type exists
          int dtId;
          if (deviceTypeIds.containsKey(deviceTypeName)) {
            dtId = deviceTypeIds[deviceTypeName]!;
          } else {
            dtId = nextDtId++;
            deviceTypeIds[deviceTypeName] = dtId;
            deviceTypes.add(DeviceType(id: dtId, name: deviceTypeName));
          }

          // Ensure brand exists
          if (!brandIds.containsKey(deviceTypeName)) {
            brandIds[deviceTypeName] = {};
          }
          int bId;
          if (brandIds[deviceTypeName]!.containsKey(brandName)) {
            bId = brandIds[deviceTypeName]![brandName]!;
          } else {
            bId = nextBrandId++;
            brandIds[deviceTypeName]![brandName] = bId;
            allBrands.add(IRBrand(
              id: bId,
              name: brandName,
              deviceTypeId: dtId,
              normalizedName: brandName.toLowerCase(),
            ));
          }

          // Create model
          final mId = nextModelId++;
          allModels.add(IRModel(
            id: mId,
            name: modelName,
            brandId: bId,
            fileName: fileName,
            fileUrl: null,
          ));

          // Add keys — preserve ALL fields including raw signal data
          for (final key in keys) {
            allKeys.add(IRKey(
              name: key.name,
              type: key.type,
              protocol: key.protocol,
              address: key.address,
              command: key.command,
              frequency: key.frequency,
              dutyCycle: key.dutyCycle,
              data: key.data,
              modelId: mId,
            ));
          }
        } catch (_) {
          // Skip unparseable files
          continue;
        }

        // Update progress
        if (i % 50 == 0) {
          progress.state = (i / allIrFiles.length).clamp(0.0, 1.0);
          status.state = 'Indexing ${i + 1}/${allIrFiles.length}...';
        }
      }

      status.state = 'Saving to database (${deviceTypes.length} types, ${allBrands.length} brands, ${allModels.length} models, ${allKeys.length} keys)...';

      // ── Step 5: Insert into database ──
      final db = AppDatabase();
      await db.clearAll();
      await db.insertDeviceTypes(deviceTypes);
      await db.insertBrands(allBrands);
      await db.insertModels(allModels);
      // Insert keys in batches to avoid large transactions
      for (var i = 0; i < allKeys.length; i += 500) {
        final end = (i + 500 > allKeys.length) ? allKeys.length : i + 500;
        await db.insertKeys(allKeys.sublist(i, end));
      }

      // Update metadata
      final now = DateTime.now().toIso8601String();
      await db.setMetadata('version', '1.0');
      await db.setMetadata('last_updated', now);
      await db.setMetadata('file_count', allIrFiles.length.toString());
      await db.setMetadata('key_count', allKeys.length.toString());

      // ── Cleanup ──
      if (extractDir.existsSync()) extractDir.deleteSync(recursive: true);
      File(zipPath).deleteSync();

      progress.state = 1.0;
      status.state = 'Done! ${deviceTypes.length} device types, ${allModels.length} models, ${allKeys.length} keys.';

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Database updated: ${deviceTypes.length} types, ${allModels.length} models'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Reset progress after a delay
      Future.delayed(const Duration(seconds: 3), () {
        progress.state = null;
        status.state = '';
      });
    } catch (e) {
      progress.state = -1.0;
      status.state = 'Error: $e';
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    }
  }
}

/// A text field that loads a saved API key from [FlutterSecureStorage] on
/// init and auto-saves on every keystroke (not just on submit).
class ApiKeyField extends StatefulWidget {
  final String storageKey;
  final String label;
  final String? hint;
  final IconData icon;
  final bool obscure;
  final bool isObscured;
  final VoidCallback onToggleObscured;

  const ApiKeyField({
    super.key,
    required this.storageKey,
    required this.label,
    this.hint,
    required this.icon,
    required this.obscure,
    required this.isObscured,
    required this.onToggleObscured,
  });

  @override
  State<ApiKeyField> createState() => _ApiKeyFieldState();
}

class _ApiKeyFieldState extends State<ApiKeyField> {
  final _controller = TextEditingController();
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadSavedValue();
  }

  Future<void> _loadSavedValue() async {
    final storage = const FlutterSecureStorage();
    final saved = await storage.read(key: widget.storageKey);
    if (saved != null && saved.isNotEmpty) {
      _controller.text = saved;
    }
    if (mounted) setState(() => _loaded = true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: ValueKey(widget.storageKey),
      controller: _controller,
      obscureText: widget.obscure && widget.isObscured,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        prefixIcon: Icon(widget.icon),
        border: InputBorder.none,
        suffixIcon: widget.obscure
            ? IconButton(
                icon: Icon(
                  widget.isObscured
                      ? Icons.visibility_off
                      : Icons.visibility,
                ),
                onPressed: widget.onToggleObscured,
              )
            : null,
      ),
      onChanged: (value) {
        if (value.isNotEmpty) {
          const FlutterSecureStorage().write(
            key: widget.storageKey,
            value: value,
          );
        }
      },
      onFieldSubmitted: (value) {
        if (value.isNotEmpty) {
          const FlutterSecureStorage().write(
            key: widget.storageKey,
            value: value,
          );
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${widget.label} saved')),
        );
      },
    );
  }
}
