import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'search_provider.dart';
import '../../data/database/app_database.dart';
import '../../data/models/ir_model.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Auto-focus the search field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          focusNode: _focusNode,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Search brand or model — e.g. samsung, LG, samsnug...',
            border: InputBorder.none,
            fillColor: Colors.transparent,
          ),
          style: theme.textTheme.titleMedium,
          onChanged: (value) =>
              ref.read(searchProvider.notifier).setQuery(value),
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                ref.read(searchProvider.notifier).clear();
                _focusNode.requestFocus();
              },
            ),
        ],
      ),
      body: _buildBody(context, theme, state),
    );
  }

  Widget _buildBody(BuildContext context, ThemeData theme, SearchState state) {
    // Empty query state
    if (state.query.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_rounded, size: 64,
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4)),
            const SizedBox(height: 16),
            Text('Type to search brands and models',
                style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            Text('Fuzzy search handles typos like "samsnug" → Samsung',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6))),
          ],
        ),
      );
    }

    // Loading
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Error
    if (state.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48,
                  color: theme.colorScheme.error),
              const SizedBox(height: 16),
              Text(state.error!, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      );
    }

    // Empty results
    if (state.brandResults.isEmpty && state.modelResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 64,
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4)),
            const SizedBox(height: 16),
            Text('No results for "${state.query}"',
                style: theme.textTheme.bodyLarge),
          ],
        ),
      );
    }

    // Results
    final db = AppDatabase();
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        // ── Brand results ──
        if (state.brandResults.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('Brands',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                )),
          ),
          ...state.brandResults.map((hit) => _BrandResultTile(
                hit: hit,
                onTap: () => _onBrandTap(hit.brand.id),
              )),
        ],

        // ── Model results ──
        if (state.modelResults.isNotEmpty) ...[
          Padding(
            padding: EdgeInsets.fromLTRB(
              16, state.brandResults.isNotEmpty ? 24 : 8, 16, 4,
            ),
            child: Text('Models',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.secondary,
                  fontWeight: FontWeight.w600,
                )),
          ),
          ...state.modelResults.map((hit) => _ModelResultTile(
                hit: hit,
                onTap: () => context.push('/remote/${hit.model.id}'),
              )),
        ],
      ],
    );
  }

  void _onBrandTap(int brandId) {
    // Navigate to browse with this brand pre-selected
    // For now, show models under this brand in a dialog
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      builder: (ctx) => _BrandModelsSheet(brandId: brandId),
    );
  }
}

// ── Brand Result Tile ──

class _BrandResultTile extends StatelessWidget {
  final BrandSearchHit hit;
  final VoidCallback onTap;

  const _BrandResultTile({required this.hit, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Icon(Icons.business_rounded,
            color: theme.colorScheme.onPrimaryContainer, size: 20),
      ),
      title: Text(hit.brand.name,
          style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Row(
        children: [
          Chip(
            label: Text(hit.deviceTypeName,
                style: const TextStyle(fontSize: 11)),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            labelPadding: const EdgeInsets.symmetric(horizontal: 6),
          ),
          const SizedBox(width: 8),
          Text('${(hit.score * 100).round()}% match',
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }
}

// ── Model Result Tile ──

class _ModelResultTile extends StatelessWidget {
  final ModelSearchHit hit;
  final VoidCallback onTap;

  const _ModelResultTile({required this.hit, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.secondaryContainer,
        child: Icon(Icons.settings_remote,
            color: theme.colorScheme.onSecondaryContainer, size: 20),
      ),
      title: Text(hit.model.name,
          style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(
        '${hit.brandName}  ·  ${hit.deviceTypeName}',
        style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant),
      ),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }
}

// ── Brand Models Sheet ──

class _BrandModelsSheet extends ConsumerWidget {
  final int brandId;

  const _BrandModelsSheet({required this.brandId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return FutureBuilder<List<IRModel>>(
      future: AppDatabase().getModelsByBrand(brandId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final models = snapshot.data ?? [];
        if (models.isEmpty) {
          return SizedBox(
            height: 200,
            child: Center(child: Text('No models found',
                style: theme.textTheme.bodyMedium)),
          );
        }

        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          maxChildSize: 0.85,
          minChildSize: 0.3,
          expand: false,
          builder: (ctx, scrollController) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Icon(Icons.business_rounded, size: 20,
                        color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text('Models',
                        style: theme.textTheme.titleMedium),
                    const Spacer(),
                    Text('${models.length}',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: models.length,
                  itemBuilder: (ctx, i) => ListTile(
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme
                          .secondaryContainer,
                      child: Icon(Icons.settings_remote,
                          color: theme.colorScheme
                              .onSecondaryContainer,
                          size: 20),
                    ),
                    title: Text(models[i].name),
                    subtitle: Text(models[i].fileName,
                        style: theme.textTheme.bodySmall),
                    trailing: const Icon(Icons.chevron_right, size: 20),
                    onTap: () {
                      Navigator.of(context).pop();
                      context.push('/remote/${models[i].id}');
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
