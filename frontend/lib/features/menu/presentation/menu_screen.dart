import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/auth_providers.dart';

class MenuScreen extends ConsumerWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final user = authState.user;
    final displayName = user?.displayName ?? '해먹노트 사용자';
    final email = user?.email ?? '';
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
      children: [
        const Row(
          children: [
            Icon(Icons.arrow_back, color: AppColors.primaryContainer),
            SizedBox(width: 14),
            Text('메뉴', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
          ],
        ),
        const SizedBox(height: 32),
        const CircleAvatar(
          radius: 50,
          backgroundColor: AppColors.primaryFixed,
          child: Icon(Icons.person, size: 54, color: AppColors.primary),
        ),
        const SizedBox(height: 14),
        Center(
          child: Text(
            displayName,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
          ),
        ),
        Center(child: Text(email, style: const TextStyle(color: AppColors.textMuted))),
        const SizedBox(height: 32),
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
