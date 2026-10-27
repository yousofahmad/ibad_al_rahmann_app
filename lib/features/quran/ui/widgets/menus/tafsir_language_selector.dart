import 'package:flutter/material.dart';
import 'package:ibad_al_rahmann/core/helpers/tafsir_catalog.dart';

class TafsirLanguageSelector extends StatelessWidget {
  const TafsirLanguageSelector({
    super.key,
    required this.group,
    required this.selectedBookId,
    required this.onChanged,
    this.downloadedStatus = const {},
  });

  final TafsirBookGroup group;
  final String selectedBookId;
  final ValueChanged<TafsirBook> onChanged;
  final Map<String, bool> downloadedStatus;

  @override
  Widget build(BuildContext context) {
    final selected = group.variants.firstWhere(
      (book) => book.id == selectedBookId,
      orElse: () => group.variants.first,
    );
    final accent = Theme.of(context).primaryColor;
    return InkWell(
      key: const ValueKey('tafsir-language-selector'),
      borderRadius: BorderRadius.circular(12),
      onTap: group.variants.length < 2 ? null : () => _choose(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'اللغة',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          suffixIcon: const Icon(Icons.expand_more_rounded),
        ),
        child: Row(
          children: [
            Icon(
              (downloadedStatus[selected.id] ?? selected.isBuiltIn)
                  ? Icons.offline_pin_outlined
                  : Icons.cloud_download_outlined,
              size: 19,
              color: accent,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                group.variantLabel(selected),
                textDirection: selected.isRtl
                    ? TextDirection.rtl
                    : TextDirection.ltr,
                softWrap: true,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _choose(BuildContext context) async {
    final selected = await showModalBottomSheet<TafsirBook>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _TafsirLanguageSheet(
        group: group,
        selectedBookId: selectedBookId,
        downloadedStatus: downloadedStatus,
      ),
    );
    if (selected != null) onChanged(selected);
  }
}

class _TafsirLanguageSheet extends StatelessWidget {
  const _TafsirLanguageSheet({
    required this.group,
    required this.selectedBookId,
    required this.downloadedStatus,
  });

  final TafsirBookGroup group;
  final String selectedBookId;
  final Map<String, bool> downloadedStatus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.72,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('اختيار اللغة', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      group.displayName,
                      softWrap: true,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                  itemCount: group.variants.length,
                  itemBuilder: (context, index) {
                    final book = group.variants[index];
                    final isDownloaded =
                        downloadedStatus[book.id] ?? book.isBuiltIn;
                    final isSelected = book.id == selectedBookId;
                    return ListTile(
                      key: ValueKey('tafsir-language-option-${book.id}'),
                      leading: Icon(
                        isDownloaded
                            ? Icons.offline_pin_outlined
                            : Icons.cloud_download_outlined,
                        color: theme.primaryColor,
                      ),
                      title: Text(
                        group.variantLabel(book),
                        textDirection: book.isRtl
                            ? TextDirection.rtl
                            : TextDirection.ltr,
                        softWrap: true,
                      ),
                      trailing: isSelected
                          ? Icon(Icons.check_circle, color: theme.primaryColor)
                          : null,
                      onTap: () => Navigator.of(context).pop(book),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
