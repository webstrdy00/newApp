import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../records/presentation/record_providers.dart';

class MenuScreen extends ConsumerWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final todayRecords = ref.watch(todayRecordsProvider);
    final user = authState.user;
    final displayName = user?.displayName ?? '해먹노트 사용자';
    final email = user?.email ?? '';
    final todaySummary = todayRecords.when(
      data: (records) => records.isEmpty ? '오늘은 아직 기록이 없어요' : '오늘 기록 ${records.length}개',
      loading: () => '오늘 기록 확인 중',
      error: (_, __) => '기록 정보를 불러오지 못했어요',
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
      children: [
        Row(
          children: [
            IconButton(
              tooltip: '홈으로 돌아가기',
              onPressed: () => context.go('/home'),
              icon: const Icon(Icons.arrow_back, color: AppColors.primaryContainer),
            ),
            const SizedBox(width: 8),
            const Text('메뉴', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
          ],
        ),
        const SizedBox(height: 22),
        _ProfileSummaryCard(
          displayName: displayName,
          email: email,
          todaySummary: todaySummary,
        ),
        const SizedBox(height: 24),
        _QuickActions(
          onNewRecord: () => context.go('/records/new'),
          onSearch: () => context.go('/search'),
          onCalendar: () => context.go('/calendar'),
        ),
        const SizedBox(height: 28),
        const _MenuGroup(
          title: '앱 설정',
          items: [
            _MenuItem(icon: Icons.info_outline, label: '앱 버전', trailing: 'v0.1.0'),
          ],
        ),
        const SizedBox(height: 22),
        FilledButton.icon(
          onPressed: () async {
            await ref.read(authControllerProvider.notifier).logout();
            if (context.mounted) context.go('/login');
          },
          icon: const Icon(Icons.logout),
          label: const Text('로그아웃'),
        ),
      ],
    );
  }
}

class _ProfileSummaryCard extends StatelessWidget {
  const _ProfileSummaryCard({
    required this.displayName,
    required this.email,
    required this.todaySummary,
  });

  final String displayName;
  final String email;
  final String todaySummary;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 30,
              backgroundColor: AppColors.primaryFixed,
              child: Icon(Icons.person, size: 32, color: AppColors.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(email,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textMuted)),
                  const SizedBox(height: 10),
                  _StatusPill(label: todaySummary),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: AppColors.secondaryContainer, borderRadius: BorderRadius.circular(999)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onNewRecord,
    required this.onSearch,
    required this.onCalendar,
  });

  final VoidCallback onNewRecord;
  final VoidCallback onSearch;
  final VoidCallback onCalendar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 6, bottom: 10),
          child: Text('빠른 실행', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w800)),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: onNewRecord,
              icon: const Icon(Icons.add),
              label: const Text('새 기록'),
            ),
            FilledButton.tonalIcon(
              onPressed: onSearch,
              icon: const Icon(Icons.search),
              label: const Text('검색'),
            ),
            FilledButton.tonalIcon(
              onPressed: onCalendar,
              icon: const Icon(Icons.calendar_today_outlined),
              label: const Text('캘린더'),
            ),
          ],
        ),
      ],
    );
  }
}

class _MenuGroup extends StatelessWidget {
  const _MenuGroup({required this.title, required this.items});

  final String title;
  final List<_MenuItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 6, bottom: 10),
          child: Text(
            title,
            style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w800),
          ),
        ),
        for (final item in items) ...[
          item,
          SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({required this.icon, required this.label, this.trailing});

  final IconData icon;
  final String label;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary),
            SizedBox(width: 14),
            Expanded(
              child: Text(label, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            ),
            Text(trailing ?? ''),
            Icon(Icons.chevron_right, color: AppColors.outline),
          ],
        ),
      ),
    );
  }
}
