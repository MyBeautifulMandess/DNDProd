/// Универсальный экран списка справочника: поиск, слот доменных фильтров,
/// ленивый список и открытие карточки записи.
library;

import 'package:flutter/material.dart';

import '../../core/models/catalog.dart';
import '../theme.dart';

/// Экран списка записей справочника.
///
/// Данные загружаются один раз ([entries]), отбор записей выполняет
/// [select] с текущим поисковым запросом, доменные фильтры рисует
/// [filtersBuilder] (владеет своим состоянием).
class CatalogListScreen<T extends CatalogEntry> extends StatefulWidget {
  const CatalogListScreen({
    super.key,
    required this.title,
    required this.entries,
    required this.select,
    required this.onOpenCard,
    this.searchPlaceholder = 'Поиск по названию',
    this.filtersBuilder,
  });

  final String title;
  final Future<List<T>> entries;

  /// Отбор записей из полного набора по поисковому запросу.
  final List<T> Function(List<T> raw, String query) select;

  /// Открытие карточки записи по нажатию на строку списка.
  final void Function(BuildContext context, T entry) onOpenCard;

  final String searchPlaceholder;

  /// Слот доменных фильтров; получает полный набор записей.
  final Widget Function(BuildContext context, List<T> raw)? filtersBuilder;

  @override
  State<CatalogListScreen<T>> createState() => _CatalogListScreenState<T>();
}

class _CatalogListScreenState<T extends CatalogEntry>
    extends State<CatalogListScreen<T>> {
  late Future<List<T>> _future;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = widget.entries;
  }

  @override
  void didUpdateWidget(covariant CatalogListScreen<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.entries, widget.entries)) {
      _future = widget.entries;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _retry() {
    setState(() {
      _future = widget.entries;
    });
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _query = value),
        decoration: InputDecoration(
          isDense: true,
          hintText: widget.searchPlaceholder,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Очистить',
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _query = '');
                  },
                  icon: const Icon(Icons.close),
                ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: FutureBuilder<List<T>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _CatalogErrorView(onRetry: _retry);
          }
          final raw = snapshot.data ?? <T>[];
          final visible = widget.select(raw, _query);
          final filters = widget.filtersBuilder;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSearchField(),
              if (filters != null)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: SingleChildScrollView(
                    child: filters(context, raw),
                  ),
                ),
              const Divider(height: 1),
              Expanded(
                child: visible.isEmpty
                    ? _CatalogEmptyView(
                        hint: raw.isEmpty
                            ? 'Справочник пока пуст.'
                            : 'Попробуйте изменить запрос или фильтры.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 16),
                        itemCount: visible.length,
                        itemBuilder: (context, index) {
                          final entry = visible[index];
                          return ListTile(
                            minVerticalPadding: 10,
                            title: Text(
                              entry.nameRu,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: entry.nameEn.trim().isEmpty
                                ? null
                                : Text(
                                    entry.nameEn,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: AppTheme.gold),
                                  ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => widget.onOpenCard(context, entry),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Лента чипов фильтра: одиночный выбор по умолчанию, чип «Все» снимает выбор.
class CatalogFilterChips extends StatelessWidget {
  const CatalogFilterChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.label,
    this.multiple = false,
    this.allLabel = 'Все',
  });

  final List<String> options;

  /// Выбранные значения (для одиночного выбора — не более одного).
  final Set<String> selected;
  final void Function(Set<String>) onChanged;
  final String? label;
  final bool multiple;
  final String allLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chips = <Widget>[];
    if (label != null) {
      chips.add(
        Center(
          child: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Text(label!, style: theme.textTheme.labelMedium),
          ),
        ),
      );
    }
    chips.add(
      Center(
        child: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: FilterChip(
            label: Text(allLabel),
            selected: selected.isEmpty,
            materialTapTargetSize: MaterialTapTargetSize.padded,
            selectedColor: AppTheme.gold.withValues(alpha: 0.28),
            checkmarkColor: AppTheme.gold,
            onSelected: (_) => onChanged(<String>{}),
          ),
        ),
      ),
    );
    for (final option in options) {
      chips.add(
        Center(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(option),
              selected: selected.contains(option),
              materialTapTargetSize: MaterialTapTargetSize.padded,
              selectedColor: AppTheme.gold.withValues(alpha: 0.28),
              checkmarkColor: AppTheme.gold,
              onSelected: (isSelected) {
                final next = Set<String>.of(selected);
                if (multiple) {
                  if (isSelected) {
                    next.add(option);
                  } else {
                    next.remove(option);
                  }
                } else {
                  if (isSelected) {
                    next
                      ..clear()
                      ..add(option);
                  } else {
                    next.clear();
                  }
                }
                onChanged(next);
              },
            ),
          ),
        ),
      );
    }
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: chips,
      ),
    );
  }
}

/// Переключатель сортировки: выбран ровно один вариант.
class CatalogSortChips extends StatelessWidget {
  const CatalogSortChips({
    super.key,
    required this.label,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final List<String> options;
  final String selected;
  final void Function(String) onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(label, style: theme.textTheme.labelMedium),
            ),
          ),
          for (final option in options)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(option),
                  selected: option == selected,
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  selectedColor: AppTheme.gold.withValues(alpha: 0.28),
                  checkmarkColor: AppTheme.gold,
                  onSelected: (_) => onChanged(option),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Горизонтальная лента произвольных чипов фильтра.
class CatalogFilterRow extends StatelessWidget {
  const CatalogFilterRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: children,
      ),
    );
  }
}

/// Переключатель-чип для булевых фильтров (концентрация, ритуал, настройка).
class CatalogFilterToggle extends StatelessWidget {
  const CatalogFilterToggle({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final void Function(bool) onChanged;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: FilterChip(
          label: Text(label),
          selected: value,
          materialTapTargetSize: MaterialTapTargetSize.padded,
          selectedColor: AppTheme.gold.withValues(alpha: 0.28),
          checkmarkColor: AppTheme.gold,
          onSelected: onChanged,
        ),
      ),
    );
  }
}

/// Выбор значения из длинного списка (источник, среда обитания) — выпадающим меню.
class CatalogFilterMenu extends StatelessWidget {
  const CatalogFilterMenu({
    super.key,
    required this.label,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final List<String> options;
  final String? selected;
  final void Function(String?) onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: PopupMenuButton<String?>(
        tooltip: label,
        onSelected: onChanged,
        itemBuilder: (context) => [
          const PopupMenuItem<String?>(value: null, child: Text('Все')),
          for (final option in options)
            PopupMenuItem<String?>(value: option, child: Text(option)),
        ],
        child: Chip(
          label: Text(selected == null ? label : '$label: $selected'),
          avatar: const Icon(Icons.arrow_drop_down, size: 18),
          materialTapTargetSize: MaterialTapTargetSize.padded,
          labelStyle: theme.textTheme.labelLarge,
        ),
      ),
    );
  }
}

class _CatalogEmptyView extends StatelessWidget {
  const _CatalogEmptyView({required this.hint});

  final String hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 40, color: theme.hintColor),
            const SizedBox(height: 12),
            Text('Ничего не найдено', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              hint,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _CatalogErrorView extends StatelessWidget {
  const _CatalogErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 40, color: theme.hintColor),
            const SizedBox(height: 12),
            Text(
              'Не удалось загрузить справочник',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Повторить'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 44),
                tapTargetSize: MaterialTapTargetSize.padded,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
