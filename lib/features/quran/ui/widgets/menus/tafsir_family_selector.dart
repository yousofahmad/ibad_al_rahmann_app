import 'package:flutter/material.dart';
import 'package:ibad_al_rahmann/core/helpers/tafsir_catalog.dart';

class TafsirFamilySelector extends StatelessWidget {
  const TafsirFamilySelector({
    super.key,
    required this.groups,
    required this.selectedGroupId,
    required this.onChanged,
    this.downloadedStatus = const {},
    this.downloadingStatus = const {},
  });

  final List<TafsirBookGroup> groups;
  final String selectedGroupId;
  final ValueChanged<TafsirBookGroup> onChanged;
  final Map<String, bool> downloadedStatus;
  final Map<String, bool> downloadingStatus;

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) return const SizedBox.shrink();
    final selected = groups.firstWhere(
      (group) => group.id == selectedGroupId,
      orElse: () => groups.first,
    );
    return InkWell(
      key: const ValueKey('tafsir-family-selector'),
      borderRadius: BorderRadius.circular(12),
      onTap: groups.length < 2 ? null : () => _choose(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'التفسير',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          suffixIcon: const Icon(Icons.search_rounded),
        ),
        child: Row(
          children: [
            Icon(
              Icons.menu_book_outlined,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                selected.displayName,
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
    final selected = await showModalBottomSheet<TafsirBookGroup>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _TafsirFamilySheet(
        groups: groups,
        selectedGroupId: selectedGroupId,
        downloadedStatus: downloadedStatus,
        downloadingStatus: downloadingStatus,
      ),
    );
    if (selected != null) onChanged(selected);
  }
}

class _TafsirFamilySheet extends StatefulWidget {
  const _TafsirFamilySheet({
    required this.groups,
    required this.selectedGroupId,
    required this.downloadedStatus,
    required this.downloadingStatus,
  });

  final List<TafsirBookGroup> groups;
  final String selectedGroupId;
  final Map<String, bool> downloadedStatus;
  final Map<String, bool> downloadingStatus;

  @override
  State<_TafsirFamilySheet> createState() => _TafsirFamilySheetState();
}

class _TafsirFamilySheetState extends State<_TafsirFamilySheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = _query.trim().toLowerCase();
    final visibleGroups = widget.groups.where((group) {
      return query.isEmpty ||
          group.displayName.toLowerCase().contains(query) ||
          group.name.toLowerCase().contains(query) ||
          group.variants.any((book) => book.name.toLowerCase().contains(query));
    }).toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.82,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'اختيار التفسير',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  autofocus: false,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    hintText: 'ابحث عن تفسير',
                    prefixIcon: const Icon(Icons.search_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    isDense: true,
                  ),
                ),
              ),
              Flexible(
                child: visibleGroups.isEmpty
                    ? const Center(child: Text('لا توجد نتائج مطابقة'))
                    : ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                        itemCount: visibleGroups.length,
                        itemBuilder: (context, index) {
                          final group = visibleGroups[index];
                          final isDownloaded = group.variants.any(
                            (book) =>
                                widget.downloadedStatus[book.id] ??
                                book.isBuiltIn,
                          );
                          final isDownloading = group.variants.any(
                            (book) => widget.downloadingStatus[book.id] == true,
                          );
                          final isSelected = group.id == widget.selectedGroupId;
                          final languages = group.variants
                              .map((book) => book.languageLabel)
                              .toSet()
                              .join('، ');
                          return ListTile(
                            key: ValueKey('tafsir-family-option-${group.id}'),
                            leading: isDownloading
                                ? SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: theme.primaryColor,
                                    ),
                                  )
                                : Icon(
                                    isDownloaded
                                        ? Icons.offline_pin_outlined
                                        : Icons.cloud_download_outlined,
                                    color: theme.primaryColor,
                                  ),
                            title: Text(group.displayName, softWrap: true),
                            subtitle: Text(
                              group.variants.length == 1
                                  ? languages
                                  : 'اللغات: $languages',
                              softWrap: true,
                            ),
                            trailing: isSelected
                                ? Icon(
                                    Icons.check_circle,
                                    color: theme.primaryColor,
                                  )
                                : null,
                            onTap: () => Navigator.of(context).pop(group),
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
