import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/async_content.dart';
import '../../../shared/widgets/star_rating.dart';
import '../data/record_models.dart';
import '../data/records_repository.dart';
import 'record_providers.dart';

class RecordDetailScreen extends ConsumerWidget {
  const RecordDetailScreen({super.key, required this.recordId});

  final int recordId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final record = ref.watch(recordProvider(recordId));
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(onPressed: () => context.go('/home'), icon: const Icon(Icons.arrow_back)),
        title: const Text('기록 상세', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(onPressed: () => context.go('/records/$recordId/edit'), icon: const Icon(Icons.edit)),
          IconButton(onPressed: () => _confirmDelete(context, ref), icon: const Icon(Icons.delete_outline, color: AppColors.error)),
        ],
      ),
      body: AsyncContent(
        value: record,
        onRetry: () => ref.invalidate(recordProvider(recordId)),
        builder: (data) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
          children: [
            Text('저녁 로그', style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(data.dishName, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Text(DateFormat('yyyy년 M월 d일').format(data.cookedDate), style: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w700)),
                const SizedBox(width: 12),
                StarRating(value: data.rating, size: 20),
              ],
            ),
            const SizedBox(height: 24),
            _ImageGallery(attachments: data.attachments),
            const SizedBox(height: 26),
            _DetailSection(
              icon: Icons.restaurant_menu,
              title: '재료',
              child: data.ingredients.isEmpty
                  ? const Text('저장된 재료가 없어요')
                  : Column(
                      children: [
                        for (final ingredient in data.ingredients)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            child: Row(
                              children: [
                                Expanded(child: Text(ingredient.name, style: const TextStyle(color: AppColors.textMuted))),
                                Text(ingredient.quantity ?? '', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900)),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 20),
            if (data.memo != null && data.memo!.isNotEmpty)
              _NoteBox(icon: Icons.sticky_note_2_outlined, title: '맛 평가', text: data.memo!),
            const SizedBox(height: 20),
            _DetailSection(
              icon: Icons.format_list_numbered,
              title: '조리 순서',
              child: Text(data.recipe?.trim().isNotEmpty == true ? data.recipe! : '저장된 조리 순서가 없어요', style: const TextStyle(height: 1.6)),
            ),
            const SizedBox(height: 20),
            _DetailSection(
              icon: Icons.attachment,
              title: '참고 및 첨부 자료',
              child: _AttachmentsList(attachments: data.attachments),
            ),
            const SizedBox(height: 26),
            FilledButton.icon(
              onPressed: () => context.go('/records/$recordId/clone'),
              icon: const Icon(Icons.copy),
              label: const Text('이 기록으로 다시 요리하기'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('이 기록을 삭제할까요?'),
        content: const Text('삭제한 기록은 다시 복구할 수 없어요.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('삭제')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(recordsRepositoryProvider).delete(recordId);
      ref.invalidate(todayRecordsProvider);
      ref.invalidate(recentRecordsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('기록이 삭제되었어요')));
        context.go('/home');
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('기록을 삭제하지 못했어요')));
      }
    }
  }
}

class _ImageGallery extends StatelessWidget {
  const _ImageGallery({required this.attachments});

  final List<RecordAttachment> attachments;

  @override
  Widget build(BuildContext context) {
    final images = attachments.where((item) => item.type == AttachmentType.image && item.thumbnailUrl != null).toList();
    if (images.isEmpty) {
      return Container(
        height: 220,
        decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: BorderRadius.circular(24)),
        child: const Center(child: Icon(Icons.restaurant, size: 56, color: AppColors.outline)),
      );
    }

    return Column(
      children: [
        _ImageTile(
          url: images.first.thumbnailUrl!,
          height: 280,
          onTap: () => _openImageViewer(context, images, 0),
        ),
        if (images.length > 1) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) => _ImageTile(
                url: images[index].thumbnailUrl!,
                width: 72,
                height: 72,
                onTap: () => _openImageViewer(context, images, index),
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _openImageViewer(BuildContext context, List<RecordAttachment> images, int initialIndex) {
    showDialog<void>(
      context: context,
      builder: (context) => _ImageViewer(images: images, initialIndex: initialIndex),
    );
  }
}

class _ImageTile extends StatelessWidget {
  const _ImageTile({
    required this.url,
    required this.height,
    required this.onTap,
    this.width,
  });

  final String url;
  final double height;
  final double? width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(width == null ? 24 : 14),
      child: Material(
        color: AppColors.surfaceHigh,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: width ?? double.infinity,
            height: height,
            child: CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              errorWidget: (context, url, error) {
                return const Center(child: Icon(Icons.restaurant, size: 48, color: AppColors.outline));
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ImageViewer extends StatefulWidget {
  const _ImageViewer({required this.images, required this.initialIndex});

  final List<RecordAttachment> images;
  final int initialIndex;

  @override
  State<_ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<_ImageViewer> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            onPageChanged: (index) => setState(() => _index = index),
            itemCount: widget.images.length,
            itemBuilder: (context, index) {
              final url = widget.images[index].thumbnailUrl!;
              return InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.contain,
                    errorWidget: (context, url, error) {
                      return const Icon(Icons.broken_image_outlined, color: Colors.white70, size: 56);
                    },
                  ),
                ),
              );
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                  const Spacer(),
                  DecoratedBox(
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(999)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Text(
                        '${_index + 1} / ${widget.images.length}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.icon, required this.title, required this.child});

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.surfaceLow, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.secondary),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.secondary)),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _NoteBox extends StatelessWidget {
  const _NoteBox({required this.icon, required this.title, required this.text});

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.secondaryContainer, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(icon, size: 18), const SizedBox(width: 6), Text(title, style: const TextStyle(fontWeight: FontWeight.w900))]),
          const SizedBox(height: 8),
          Text(text, style: const TextStyle(height: 1.5)),
        ],
      ),
    );
  }
}

class _AttachmentsList extends StatelessWidget {
  const _AttachmentsList({required this.attachments});

  final List<RecordAttachment> attachments;

  @override
  Widget build(BuildContext context) {
    final links = attachments.where((item) => item.type != AttachmentType.image).toList();
    if (links.isEmpty) {
      return const Text('저장된 참고 자료가 없어요');
    }
    return Column(
      children: [
        for (final item in links)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(item.type == AttachmentType.youtube ? Icons.play_circle : Icons.link, color: AppColors.primaryContainer),
            title: Text(item.title ?? item.url ?? '참고 링크', maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              item.description?.isNotEmpty == true ? item.description! : item.url ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: item.url == null ? null : () => _openLink(context, item.url!),
          ),
      ],
    );
  }

  Future<void> _openLink(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      _showOpenError(context);
      return;
    }

    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && context.mounted) {
        _showOpenError(context);
      }
    } catch (_) {
      if (context.mounted) {
        _showOpenError(context);
      }
    }
  }

  void _showOpenError(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('링크를 열 수 없어요')));
  }
}
