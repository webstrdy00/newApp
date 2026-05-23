import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../features/records/presentation/record_providers.dart';
import '../../../shared/widgets/async_content.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/record_card.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _recent = <String>[];
  String _filter = 'all';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final queryText = _controller.text.trim();
    final query = SearchQuery(text: queryText, filter: _filter);
    final results = ref.watch(searchResultsProvider(query));

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
      children: [
        Row(
          children: [
            IconButton(onPressed: () => context.go('/home'), icon: const Icon(Icons.arrow_back)),
            const Expanded(child: Text('검색', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900))),
            IconButton(onPressed: _showFilterSheet, icon: const Icon(Icons.tune)),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _controller,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: '요리명, 재료, 메모 등으로 검색하세요',
            suffixIcon: queryText.isEmpty
                ? null
                : IconButton(
                    onPressed: _clearSearch,
                    icon: const Icon(Icons.close),
                  ),
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: _submitSearch,
        ),
        const SizedBox(height: 24),
        if (_recent.isNotEmpty)
          _KeywordPanel(
            title: '최근 검색어',
            keywords: _recent,
            onTap: _setQuery,
            onClear: () => setState(_recent.clear),
          ),
        if (_recent.isNotEmpty) const SizedBox(height: 18),
        _KeywordPanel(
          title: '추천 키워드',
          keywords: const ['김치찌개', '파스타', '닭가슴살', '샐러드', '마라탕'],
          accent: true,
          onTap: _setQuery,
        ),
        const SizedBox(height: 24),
        const Text('필터', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            _FilterChip(label: '전체', value: 'all', selected: _filter == 'all', onSelected: _setFilter),
            _FilterChip(label: '요리명', value: 'dish', selected: _filter == 'dish', onSelected: _setFilter),
            _FilterChip(label: '재료', value: 'ingredient', selected: _filter == 'ingredient', onSelected: _setFilter),
            _FilterChip(label: '메모', value: 'memo', selected: _filter == 'memo', onSelected: _setFilter),
            _FilterChip(label: '링크', value: 'link', selected: _filter == 'link', onSelected: _setFilter),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            const Text('검색 결과', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(width: 8),
            Text(queryText.isEmpty ? '' : '최신순', style: const TextStyle(color: AppColors.textMuted)),
          ],
        ),
        const SizedBox(height: 14),
        AsyncContent(
          value: results,
          onRetry: () => ref.invalidate(searchResultsProvider(query)),
          builder: (records) {
            if (_controller.text.trim().isEmpty) {
              return const EmptyState(
                message: '찾고 싶은 요리를 검색해보세요',
                description: '요리명, 재료, 메모, 링크 제목으로 찾을 수 있어요.',
                icon: Icons.search,
              );
            }
            if (records.isEmpty) {
              return const EmptyState(
                message: '검색 결과가 없어요',
                description: '다른 재료명이나 요리명으로 다시 검색해보세요.',
                icon: Icons.manage_search,
              );
            }
            return Column(
              children: [
                for (final record in records) ...[
                  RecordCard(record: record, onTap: () => context.push('/records/${record.id}')),
                  const SizedBox(height: 18),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  void _setQuery(String value) {
    _submitSearch(value);
  }

  void _setFilter(String value) {
    setState(() => _filter = value);
  }

  void _submitSearch(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      _controller.text = trimmed;
      _controller.selection = TextSelection.collapsed(offset: trimmed.length);
      _recent.remove(trimmed);
      _recent.insert(0, trimmed);
      if (_recent.length > 10) _recent.removeLast();
    });
  }

  void _clearSearch() {
    setState(_controller.clear);
  }

  Future<void> _showFilterSheet() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _FilterOption(label: '전체', value: 'all', selected: _filter == 'all'),
            _FilterOption(label: '요리명', value: 'dish', selected: _filter == 'dish'),
            _FilterOption(label: '재료', value: 'ingredient', selected: _filter == 'ingredient'),
            _FilterOption(label: '메모', value: 'memo', selected: _filter == 'memo'),
            _FilterOption(label: '링크', value: 'link', selected: _filter == 'link'),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (selected != null) {
      _setFilter(selected);
    }
  }
}

class _KeywordPanel extends StatelessWidget {
  const _KeywordPanel({
    required this.title,
    required this.keywords,
    required this.onTap,
    this.accent = false,
    this.onClear,
  });

  final String title;
  final List<String> keywords;
  final ValueChanged<String> onTap;
  final bool accent;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.surfaceLow, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900))),
              if (onClear != null)
                TextButton(
                  onPressed: onClear,
                  child: const Text('비우기'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final keyword in keywords)
                ActionChip(
                  label: Text(keyword),
                  backgroundColor: accent ? AppColors.secondaryContainer : AppColors.card,
                  onPressed: () => onTap(keyword),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterOption extends StatelessWidget {
  const _FilterOption({
    required this.label,
    required this.value,
    required this.selected,
  });

  final String label;
  final String value;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      trailing: selected ? const Icon(Icons.check, color: AppColors.primary) : null,
      onTap: () => Navigator.of(context).pop(value),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final String value;
  final bool selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(value),
      selectedColor: AppColors.primaryContainer,
      labelStyle: TextStyle(color: selected ? Colors.white : AppColors.text),
    );
  }
}
