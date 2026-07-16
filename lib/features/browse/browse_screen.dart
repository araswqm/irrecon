import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'browse_provider.dart';

class BrowseScreen extends ConsumerWidget {
  const BrowseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(browseProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Browse IR Database'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search brands / models',
            onPressed: () => context.push('/search'),
          ),
          if (state.selectedDeviceTypeId != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => ref.read(browseProvider.notifier).reset(),
            ),
        ],
      ),
      body: state.error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_off_rounded,
                        size: 64, color: theme.colorScheme.error),
                    const SizedBox(height: 16),
                    Text('Database unavailable',
                        style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                      'Please download the IR database from Settings first.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => context.push('/settings'),
                      icon: const Icon(Icons.settings),
                      label: const Text('Open Settings'),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Device Type Dropdown ──
                _DropdownSection(
                  label: 'Device Type',
                  icon: Icons.devices_rounded,
                  value: state.selectedDeviceTypeId,
                  items: state.deviceTypes
                      .map((dt) => _DropdownItem(dt.id, dt.name))
                      .toList(),
                  onChanged: (id) => ref
                      .read(browseProvider.notifier)
                      .selectDeviceType(id),
                ),

                if (state.isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: CircularProgressIndicator()),
                  ),

                // ── Brand Dropdown ──
                if (state.brands.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _DropdownSection(
                    label: 'Brand',
                    icon: Icons.business_rounded,
                    value: state.selectedBrandId,
                    items: state.brands
                        .map((b) => _DropdownItem(b.id, b.name))
                        .toList(),
                    onChanged: (id) => ref
                        .read(browseProvider.notifier)
                        .selectBrand(id),
                  ),
                ],

                // ── Model List ──
                if (state.models.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Text('Models',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        )),
                  ),
                  ...state.models.map((model) => Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: theme.colorScheme.primaryContainer,
                            child: Icon(Icons.settings_remote,
                                color: theme.colorScheme.onPrimaryContainer),
                          ),
                          title: Text(model.name),
                          subtitle: Text('File: ${model.fileName}'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push('/remote/${model.id}'),
                        ),
                      )),
                ],

                // ── Empty state ──
                if (state.deviceTypes.isEmpty && state.error == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 64),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.storage_rounded,
                              size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('No device types found'),
                          SizedBox(height: 8),
                          Text('Update the database in Settings'),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _DropdownItem {
  final int id;
  final String label;
  const _DropdownItem(this.id, this.label);
}

class _DropdownSection extends StatelessWidget {
  final String label;
  final IconData icon;
  final int? value;
  final List<_DropdownItem> items;
  final ValueChanged<int> onChanged;

  const _DropdownSection({
    required this.label,
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: DropdownButtonFormField<int>(
          value: value != null && items.any((item) => item.id == value)
              ? value
              : null,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon),
            border: InputBorder.none,
          ),
          isExpanded: true,
          items: items
              .map((item) => DropdownMenuItem(
                    value: item.id,
                    child: Text(item.label),
                  ))
              .toList(),
          onChanged: (id) {
            if (id != null) onChanged(id);
          },
        ),
      ),
    );
  }
}
