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
    final query = SearchQuery(text: _controller.text, filter: _filter);
    final results = ref.watch(searchResultsProvider(query));

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
      children: [
        Row(
          children: [
            IconButton(onPressed: () => context.go('/home'), icon: const Icon(Icons.arrow_back)),
            const Expanded(child: Text('검색', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900))),
            IconButton(onPressed: () {}, icon: const Icon(Icons.tune)),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _controller,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: '요리명, 재료, 메모 등으로 검색하세요',
            suffixIcon: _controller.text.isEmpty
                ? null
                : IconButton(
                    onPressed: () => setState(_controller.clear),
                    icon: const Icon(Icons.close),
                  ),
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: (value) {
            final trimmed = value.trim();
            if (trimmed.isEmpty) return;
            setState(() {
              _recent.remove(trimmed);
              _recent.insert(0, trimmed);
              if (_recent.length > 10) _recent.removeLast();
            });
          },
        ),
        const SizedBox(height: 24),
        if (_recent.isNotEmpty) _KeywordPanel(title: '최근 검색어', keywords: _recent, onTap: _setQuery),
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
            Text(_controller.text.trim().isEmpty ? '' : '최신순', style: const TextStyle(color: AppColors.textMuted)),
          ],
        ),
        const SizedBox(height: 14),
        AsyncContent(
          value: results,
          builder: (records) {
            if (_controller.text.trim().isEmpty) {
              return const EmptyState(message: '찾고 싶은 요리를 검색해보세요');
            }
            if (records.isEmpty) {
              return const EmptyState(message: '검색 결과가 없어요');
            }
            return Column(
              children: [
                for (final record in records) ...[
                  RecordCard(record: record, onTap: () => context.go('/records/${record.id}')),
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
    setState(() => _controller.text = value);
  }

  void _setFilter(String value) {
    setState(() => _filter = value);
  }
}

class _KeywordPanel extends StatelessWidget {
  const _KeywordPanel({
    required this.title,
    required this.keywords,
    required this.onTap,
    this.accent = false,
  });

  final String title;
  final List<String> keywords;
  final ValueChanged<String> onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.surfaceLow, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
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
