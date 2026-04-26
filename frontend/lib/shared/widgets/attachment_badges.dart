import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../features/records/data/record_models.dart';

class AttachmentBadges extends StatelessWidget {
  const AttachmentBadges({super.key, required this.attachments});

  final List<RecordAttachment> attachments;

  @override
  Widget build(BuildContext context) {
    final hasImage = attachments.any((item) => item.type == AttachmentType.image);
    final hasUrl = attachments.any((item) => item.type == AttachmentType.url);
    final hasYoutube = attachments.any((item) => item.type == AttachmentType.youtube);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        if (hasImage) const _Badge(icon: Icons.image_outlined, label: '사진', color: AppColors.secondaryContainer),
        if (hasUrl) const _Badge(icon: Icons.link, label: '링크', color: AppColors.secondaryContainer),
        if (hasYoutube) const _Badge(icon: Icons.play_circle, label: '영상', color: AppColors.errorContainer),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}
