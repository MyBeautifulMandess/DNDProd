/// Карточка записи справочника: поля записи и ссылка на источник dnd.su.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/catalog.dart';
import '../theme.dart';

/// Блок текста карточки: заголовок и список пунктов (название + текст).
class CatalogSection {
  const CatalogSection({required this.title, required this.entries});

  final String title;

  /// Пункты блока: (название, текст); название может быть пустым.
  final List<(String, String)> entries;
}

/// Карточка записи справочника с кнопкой перехода на dnd.su.
class CatalogCard extends StatelessWidget {
  const CatalogCard({
    super.key,
    required this.entry,
    this.lines = const <(String, String)>[],
    this.sections = const <CatalogSection>[],
    this.description,
  });

  final CatalogEntry entry;
  final List<(String, String)> lines;
  final List<CatalogSection> sections;
  final String? description;

  Future<void> _openSource(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(entry.url),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      opened = false;
    }
    if (!opened) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('Не удалось открыть ссылку')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final descriptionText = description?.trim() ?? '';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          entry.nameRu,
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (entry.nameEn.trim().isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            entry.nameEn,
            style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.gold),
          ),
        ],
        if (lines.isNotEmpty) const SizedBox(height: 12),
        for (final (label, value) in lines)
          _CardLine(label: label, value: value.trim().isEmpty ? '—' : value),
        for (final section in sections)
          if (section.entries.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              section.title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppTheme.gold,
              ),
            ),
            const SizedBox(height: 6),
            for (final (name, text) in section.entries)
              _CardEntry(name: name, text: text),
          ],
        if (descriptionText.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            descriptionText,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
          ),
        ],
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => unawaited(_openSource(context)),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('Источник'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.gold,
              minimumSize: const Size(0, 44),
              tapTargetSize: MaterialTapTargetSize.padded,
            ),
          ),
        ),
      ],
    );
  }
}

class _CardLine extends StatelessWidget {
  const _CardLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: theme.textTheme.bodyMedium,
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class _CardEntry extends StatelessWidget {
  const _CardEntry({required this.name, required this.text});

  final String name;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = theme.textTheme.bodyMedium?.copyWith(height: 1.45);
    final trimmedText = text.trim();
    final trimmedName = name.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: trimmedName.isEmpty
          ? Text(trimmedText, style: body)
          : RichText(
              text: TextSpan(
                style: body,
                children: [
                  TextSpan(
                    text: '$trimmedName. ',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: trimmedText),
                ],
              ),
            ),
    );
  }
}

/// Показывает карточку записи справочника в диалоге.
Future<void> showCatalogCard(
  BuildContext context,
  CatalogEntry entry, {
  List<(String, String)> lines = const <(String, String)>[],
  List<CatalogSection> sections = const <CatalogSection>[],
  String? description,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: AppTheme.surface,
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            child: CatalogCard(
              entry: entry,
              lines: lines,
              sections: sections,
              description: description,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Закрыть'),
          ),
        ],
      );
    },
  );
}
