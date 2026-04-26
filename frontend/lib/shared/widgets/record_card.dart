import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../features/records/data/record_models.dart';
import 'attachment_badges.dart';

class RecordCard extends StatelessWidget {
  const RecordCard({
    super.key,
    required this.record,
    this.compact = false,
    this.onTap,
  });

  final CookingRecord record;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final image = record.attachments
        .where((item) => item.type == AttachmentType.image || item.thumbnailUrl != null)
        .cast<RecordAttachment?>()
        .firstOrNull;

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Ink(
        padding: EdgeInsets.all(compact ? 14 : 16),
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(24)),
        child: compact
            ? Row(
                children: [
                  _Thumb(url: image?.thumbnailUrl, size: 76),
                  const SizedBox(width: 14),
                  Expanded(child: _CardText(record: record, compact: true)),
                  const Icon(Icons.chevron_right, color: AppColors.outline),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Thumb(url: image?.thumbnailUrl, height: 190),
                  const SizedBox(height: 14),
                  _CardText(record: record),
                ],
              ),
      ),
    );
  }
}

class _CardText extends StatelessWidget {
  const _CardText({required this.record, this.compact = false});

  final CookingRecord record;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                record.dishName,
                maxLines: compact ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: compact ? 18 : 22, fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              DateFormat('M월 d일').format(record.cookedDate),
              style: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          record.preview,
          maxLines: compact ? 1 : 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppColors.textMuted, height: 1.4),
        ),
        const SizedBox(height: 12),
        AttachmentBadges(attachments: record.attachments),
      ],
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({this.url, this.size, this.height});

  final String? url;
  final double? size;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final width = size ?? double.infinity;
    final resolvedHeight = size ?? height ?? 160;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: width,
        height: resolvedHeight,
        color: AppColors.surfaceHigh,
        child: url == null
            ? const Icon(Icons.restaurant, color: AppColors.outline)
            : CachedNetworkImage(
                imageUrl: url!,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => const Icon(Icons.restaurant, color: AppColors.outline),
              ),
      ),
    );
  }
}

extension _IterableFirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
