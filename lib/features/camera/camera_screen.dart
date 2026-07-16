import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'analysis_provider.dart';

class CameraScreen extends ConsumerWidget {
  const CameraScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(analysisProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Camera Search'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ── Image Preview / Placeholder ──
            Expanded(
              child: _buildImageArea(context, theme, state, ref),
            ),
            const SizedBox(height: 16),
            // ── Action Buttons ──
            _buildActionButtons(context, theme, state, ref),
            // ── Results ──
            if (state.step == AnalysisStep.complete &&
                state.matches.isNotEmpty)
              _buildResults(context, theme, state),
            if (state.step == AnalysisStep.error)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Card(
                  color: theme.colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.error_rounded,
                            color: theme.colorScheme.onErrorContainer),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            state.errorMessage ?? 'Unknown error',
                            style: TextStyle(
                                color: theme.colorScheme.onErrorContainer),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageArea(
    BuildContext context,
    ThemeData theme,
    AnalysisState state,
    WidgetRef ref,
  ) {
    if (state.imageBase64 != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(
          base64Decode(state.imageBase64!),
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 64),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.camera_alt_rounded,
                size: 80, color: theme.colorScheme.primary.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text('Take a photo of your remote',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'or select from gallery',
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    ThemeData theme,
    AnalysisState state,
    WidgetRef ref,
  ) {
    final isBusy = state.step == AnalysisStep.optimizingImage ||
        state.step == AnalysisStep.callingLLM ||
        state.step == AnalysisStep.matchingDatabase;

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: isBusy
                ? null
                : () => _pickImage(context, ref, ImageSource.camera),
            icon: const Icon(Icons.camera_alt_rounded),
            label: const Text('Camera'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            onPressed: isBusy
                ? null
                : () => _pickImage(context, ref, ImageSource.gallery),
            icon: const Icon(Icons.photo_library_rounded),
            label: const Text('Gallery'),
          ),
        ),
      ],
    );
  }

  Widget _buildResults(
    BuildContext context,
    ThemeData theme,
    AnalysisState state,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Matched Models',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              )),
          const SizedBox(height: 8),
          ...state.matches.take(5).map(
                (match) => Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: match.score >= 0.8
                          ? Colors.green.withOpacity(0.2)
                          : Colors.orange.withOpacity(0.2),
                      child: Icon(
                        Icons.check_rounded,
                        color:
                            match.score >= 0.8 ? Colors.green : Colors.orange,
                      ),
                    ),
                    title: Text(match.modelName),
                    subtitle: Text(
                        'Match: ${(match.score * 100).toStringAsFixed(0)}%'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(
                      '/remote/${Uri.encodeComponent(match.modelName)}',
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Future<void> _pickImage(
      BuildContext context, WidgetRef ref, ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (picked != null) {
      ref
          .read(analysisProvider.notifier)
          .pickAndAnalyze(File(picked.path));
    }
  }
}
