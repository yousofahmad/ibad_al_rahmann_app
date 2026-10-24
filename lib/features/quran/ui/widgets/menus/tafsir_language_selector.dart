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
    final selected = group.variants.any((book) => book.id == selectedBookId)
        ? selectedBookId
        : group.variants.first.id;
    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'اللغة',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          key: const ValueKey('tafsir-language-selector'),
          value: selected,
          isExpanded: true,
          items: [
            for (final book in group.variants)
              DropdownMenuItem(
                value: book.id,
                child: Row(
                  children: [
                    Icon(
                      (downloadedStatus[book.id] ?? book.isBuiltIn)
                          ? Icons.offline_pin_outlined
                          : Icons.cloud_download_outlined,
                      size: 18,
                      color: Theme.of(context).primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        group.variantLabel(book),
                        textDirection: book.isRtl
                            ? TextDirection.rtl
                            : TextDirection.ltr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
          ],
          onChanged: group.variants.length < 2
              ? null
              : (id) {
                  if (id == null) return;
                  onChanged(group.variants.firstWhere((book) => book.id == id));
                },
        ),
      ),
    );
  }
}
