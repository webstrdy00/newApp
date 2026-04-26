import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/async_content.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/record_card.dart';
import 'record_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayRecords = ref.watch(todayRecordsProvider);
    final recentRecords = ref.watch(recentRecordsProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primaryContainer,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        onPressed: () => context.go('/records/new'),
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(todayRecordsProvider);
          ref.invalidate(recentRecordsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
          children: [
            _HomeHeader(today: DateFormat('M월 d일 EEEE', 'ko').format(DateTime.now())),
            const SizedBox(height: 24),
            TextField(
              readOnly: true,
              onTap: () => context.go('/search'),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: '요리 기록을 검색해보세요',
              ),
            ),
            const SizedBox(height: 34),
            _SectionTitle(title: '오늘의 기록', trailing: '저널'),
            const SizedBox(height: 14),
            AsyncContent(
              value: todayRecords,
              onRetry: () {
                ref.invalidate(todayRecordsProvider);
                ref.invalidate(recentRecordsProvider);
              },
              builder: (records) {
                if (records.isEmpty) {
                  return EmptyState(
                    message: '첫 요리 기록을 남겨보세요',
                    actionLabel: '새 기록 작성',
                    onAction: () => context.go('/records/new'),
                  );
                }
                return SizedBox(
                  height: 330,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (context, index) {
                      final record = records[index];
                      return SizedBox(
                        width: 310,
                        child: RecordCard(
                          record: record,
                          onTap: () => context.go('/records/${record.id}'),
                        ),
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(width: 16),
                    itemCount: records.length,
                  ),
                );
              },
            ),
            const SizedBox(height: 34),
            _SectionTitle(title: '최근 요리 로그', trailing: '이번 주'),
            const SizedBox(height: 14),
            AsyncContent(
              value: recentRecords,
              onRetry: () {
                ref.invalidate(todayRecordsProvider);
                ref.invalidate(recentRecordsProvider);
              },
              builder: (records) {
                if (records.isEmpty) {
                  return const EmptyState(message: '최근 기록이 없어요');
                }
                return Column(
                  children: [
                    for (final record in records) ...[
                      RecordCard(
                        record: record,
                        compact: true,
                        onTap: () => context.go('/records/${record.id}'),
                      ),
                      const SizedBox(height: 14),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.today});

  final String today;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(onPressed: () => context.go('/menu'), icon: const Icon(Icons.menu)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('해먹노트', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.primaryContainer)),
              Text(today, style: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        const CircleAvatar(
          radius: 23,
          backgroundColor: AppColors.primaryFixed,
          child: Icon(Icons.person, color: AppColors.primary),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.trailing});

  final String title;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(trailing, style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w900)),
              Text(title, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      ],
    );
  }
}
