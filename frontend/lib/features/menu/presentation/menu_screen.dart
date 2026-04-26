import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
      children: const [
        Row(
          children: [
            Icon(Icons.arrow_back, color: AppColors.primaryContainer),
            SizedBox(width: 14),
            Text('메뉴', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
          ],
        ),
        SizedBox(height: 32),
        CircleAvatar(
          radius: 50,
          backgroundColor: AppColors.primaryFixed,
          child: Icon(Icons.person, size: 54, color: AppColors.primary),
        ),
        SizedBox(height: 14),
        Center(child: Text('요리하는 철수', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900))),
        Center(child: Text('cheolsu.cook@example.com', style: TextStyle(color: AppColors.textMuted))),
        SizedBox(height: 32),
        _StatsRow(),
        SizedBox(height: 30),
        _MenuGroup(
          title: '나의 요리 활동',
          items: [
            _MenuItem(icon: Icons.analytics_outlined, label: '요리 통계'),
            _MenuItem(icon: Icons.favorite_outline, label: '즐겨찾기'),
            _MenuItem(icon: Icons.menu_book_outlined, label: '요리 목록'),
          ],
        ),
        SizedBox(height: 22),
        _MenuGroup(
          title: '앱 설정',
          items: [
            _MenuItem(icon: Icons.info_outline, label: '앱 버전', trailing: 'v0.1.0'),
            _MenuItem(icon: Icons.policy_outlined, label: '개인정보처리방침'),
            _MenuItem(icon: Icons.article_outlined, label: '서비스 이용약관'),
          ],
        ),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(label: '총 기록', value: '0', color: AppColors.surfaceLow),
        ),
        SizedBox(width: 14),
        Expanded(
          child: _StatCard(label: '이번 달 요리', value: '0', color: AppColors.secondaryContainer),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w800)),
            SizedBox(height: 8),
            Text(value, style: TextStyle(color: AppColors.primary, fontSize: 30, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
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
          child: Text(title, style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w800)),
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
            Expanded(child: Text(label, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
            Text(trailing ?? ''),
            Icon(Icons.chevron_right, color: AppColors.outline),
          ],
        ),
      ),
    );
  }
}
