import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/api/api_engine.dart';
import '../../core/constants.dart';
import '../../app/theme.dart';

/// Tracks whether each API key field is obscured.
final _obscuredProvider = StateProvider.autoDispose<Set<String>>((ref) => {});

/// Current provider selection.
final _providerSelectionProvider =
    StateProvider.autoDispose<AIProvider>((ref) => AIProvider.openAI);

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
          const SizedBox(height: 24),

          // ── Database Section ──
          _buildSectionHeader(theme, 'Database'),
          Card(
            child: ListTile(
              leading: Icon(Icons.update_rounded,
                  color: theme.colorScheme.primary),
              title: const Text('Update IR Database'),
              subtitle: const Text('Download latest from GitHub'),
              trailing: const Icon(Icons.download_rounded),
              onTap: () => _updateDatabase(context),
            ),
          ),
          Card(
            child: ListTile(
              leading: Icon(Icons.info_outline,
                  color: theme.colorScheme.primary),
              title: const Text('Database Info'),
              subtitle: const Text('Version: N/A'),
            ),
          ),
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
              return TextFormField(
                key: ValueKey(key),
                initialValue: '',
                obscureText: obscure && isObscured,
                decoration: InputDecoration(
                  labelText: label,
                  hintText: hint,
                  prefixIcon: Icon(icon),
                  border: InputBorder.none,
                  suffixIcon: obscure
                      ? IconButton(
                          icon: Icon(
                            isObscured
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            final current = ref.read(_obscuredProvider);
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
                        )
                      : null,
                ),
                onFieldSubmitted: (value) {
                  _saveKey(key, value);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$label saved')),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
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

  Future<void> _updateDatabase(BuildContext context) async {
    // TODO: Implement full GitHub->download->unzip->index flow
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 16),
            Text('Downloading database...'),
          ],
        ),
        duration: Duration(seconds: 10),
      ),
    );
  }
}
