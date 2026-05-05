import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/star_rating.dart';
import '../data/record_models.dart';
import '../data/records_repository.dart';
import 'record_providers.dart';

class RecordFormScreen extends ConsumerStatefulWidget {
  const RecordFormScreen({
    super.key,
    this.recordId,
    this.initialDate,
    this.cloneFromRecordId,
  });

  final int? recordId;
  final DateTime? initialDate;
  final int? cloneFromRecordId;

  @override
  ConsumerState<RecordFormScreen> createState() => _RecordFormScreenState();
}

class _RecordFormScreenState extends ConsumerState<RecordFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dishController = TextEditingController();
  final _recipeController = TextEditingController();
  final _memoController = TextEditingController();
  final _ingredients = <_IngredientRow>[const _IngredientRow()];
  final _existingImages = <_ExistingImageDraft>[];
  final _pickedImages = <XFile>[];
  final _links = <_LinkDraft>[];
  final _deletedAttachmentIds = <int>[];
  final _picker = ImagePicker();
  late DateTime _date;
  int? _rating;
  bool _loaded = false;
  bool _saving = false;

  bool get _isEdit => widget.recordId != null;
  bool get _isClone => widget.cloneFromRecordId != null;
  int get _totalImageCount => _existingImages.length + _pickedImages.length;

  @override
  void initState() {
    super.initState();
    _date = _safeInitialDate(widget.initialDate);
  }

  @override
  void dispose() {
    _dishController.dispose();
    _recipeController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sourceRecordId = _isEdit ? widget.recordId : widget.cloneFromRecordId;
    final recordValue = sourceRecordId == null ? null : ref.watch(recordProvider(sourceRecordId));
    if (recordValue != null) {
      recordValue.whenData(_loadRecord);
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(onPressed: _confirmLeave, icon: const Icon(Icons.close)),
          title: Text(_screenTitle, style: const TextStyle(fontWeight: FontWeight.w900)),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? '저장 중' : '저장'),
              ),
            ),
          ],
        ),
        body: recordValue?.maybeWhen(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Center(child: Text('기록을 불러오지 못했어요\n$error')),
              orElse: _form,
            ) ??
            _form(),
      ),
    );
  }

  String get _screenTitle {
    if (_isEdit) return '기록 수정';
    if (_isClone) return '복제 기록 작성';
    return '새 요리 기록 작성';
  }

  Widget _form() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
        children: [
          TextFormField(
            controller: _dishController,
            decoration: const InputDecoration(labelText: '요리명', hintText: '예: 여름 바질 페스토 파스타'),
            maxLength: 40,
            validator: (value) => value == null || value.trim().isEmpty ? '요리명을 입력해주세요' : null,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _DateBox(date: _date, onTap: _pickDate),
              ),
              const SizedBox(width: 12),
              DecoratedBox(
                decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: StarRating(value: _rating, onChanged: (value) => setState(() => _rating = value), size: 24),
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          _FormSection(
            title: '시각적 기록',
            action: TextButton.icon(
              onPressed: _totalImageCount >= 5 ? null : _pickImages,
              icon: const Icon(Icons.add_a_photo),
              label: Text(_totalImageCount >= 5 ? '최대 5장' : '업로드'),
            ),
            child: _ImageDraftGrid(
              existingImages: _existingImages,
              pickedImages: _pickedImages,
              onRemoveExisting: _removeExistingImage,
              onRemovePicked: (index) => setState(() => _pickedImages.removeAt(index)),
            ),
          ),
          const SizedBox(height: 26),
          _FormSection(
            title: '재료',
            action: TextButton.icon(
              onPressed: () => setState(() => _ingredients.add(const _IngredientRow())),
              icon: const Icon(Icons.add_circle),
              label: const Text('행 추가'),
            ),
            child: Column(
              children: [
                for (var index = 0; index < _ingredients.length; index++)
                  _IngredientInputs(
                    row: _ingredients[index],
                    onChanged: (row) => setState(() => _ingredients[index] = row),
                    onRemove: _ingredients.length == 1 ? null : () => setState(() => _ingredients.removeAt(index)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          _FormSection(
            title: '조리 순서',
            child: TextFormField(
              controller: _recipeController,
              minLines: 5,
              maxLines: 10,
              decoration: const InputDecoration(hintText: '조리 순서나 참고한 비율을 적어두세요'),
            ),
          ),
          const SizedBox(height: 26),
          _FormSection(
            title: '쉐프의 메모',
            child: TextFormField(
              controller: _memoController,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(hintText: '다음에 바꾸고 싶은 점을 남겨보세요'),
            ),
          ),
          const SizedBox(height: 26),
          _FormSection(
            title: '외부 참고 자료',
            action: TextButton.icon(
              onPressed: _links.length >= 10 ? null : _showLinkDialog,
              icon: const Icon(Icons.add_link),
              label: const Text('링크 추가'),
            ),
            child: _LinkDraftList(
              links: _links,
              onRemove: _removeLink,
            ),
          ),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save),
            label: const Text('기록 저장하기'),
          ),
        ],
      ),
    );
  }

  void _loadRecord(CookingRecord record) {
    if (_loaded) return;
    _loaded = true;
    _dishController.text = record.dishName;
    _recipeController.text = record.recipe ?? '';
    _memoController.text = record.memo ?? '';
    _date = _isClone ? _safeInitialDate(widget.initialDate) : record.cookedDate;
    _rating = record.rating;
    _ingredients
      ..clear()
      ..addAll(
        record.ingredients.isEmpty
            ? [const _IngredientRow()]
            : record.ingredients.map((item) => _IngredientRow(name: item.name, quantity: item.quantity ?? '')),
      );
    _existingImages
      ..clear()
      ..addAll(
        record.attachments.where((item) => item.type == AttachmentType.image).map(
              (item) => _ExistingImageDraft(
                id: _isEdit ? item.id : null,
                title: item.title,
                thumbnailUrl: item.resolvedImageUrl,
                objectKey: item.objectKey,
              ),
            ),
      );
    _links
      ..clear()
      ..addAll(
        record.attachments
            .where((item) => item.type == AttachmentType.url || item.type == AttachmentType.youtube)
            .map(
              (item) => _LinkDraft(
                id: _isEdit ? item.id : null,
                url: item.url ?? '',
                title: item.title ?? '',
                description: item.description ?? '',
                type: item.type,
                thumbnailUrl: item.thumbnailUrl,
              ),
            ),
      );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  DateTime _safeInitialDate(DateTime? date) {
    final now = DateTime.now();
    if (date == null || date.isAfter(now)) {
      return now;
    }
    return date;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final draft = RecordDraft(
      dishName: _dishController.text.trim(),
      cookedDate: _date,
      recipe: _recipeController.text.trim().isEmpty ? null : _recipeController.text.trim(),
      memo: _memoController.text.trim().isEmpty ? null : _memoController.text.trim(),
      rating: _rating,
      ingredients: _ingredients
          .where((row) => row.name.trim().isNotEmpty)
          .map((row) => RecordIngredient(name: row.name.trim(), quantity: row.quantity.trim().isEmpty ? null : row.quantity.trim()))
          .toList(),
      attachments: _isEdit
          ? const []
          : [
              ..._existingImages.where((image) => image.objectKey != null).map(
                    (image) => RecordAttachment(
                      type: AttachmentType.image,
                      title: image.title,
                      thumbnailUrl: image.thumbnailUrl,
                      objectKey: image.objectKey,
                    ),
                  ),
              ..._links.map(
                (link) => RecordAttachment(
                  type: link.type,
                  url: link.url,
                  title: link.title.isEmpty ? null : link.title,
                  description: link.description.isEmpty ? null : link.description,
                  thumbnailUrl: link.thumbnailUrl,
                ),
              ),
            ],
    );

    try {
      final repository = ref.read(recordsRepositoryProvider);
      final record = _isEdit ? await repository.update(widget.recordId!, draft) : await repository.create(draft);
      for (final attachmentId in _deletedAttachmentIds) {
        await repository.deleteAttachment(recordId: record.id, attachmentId: attachmentId);
      }
      if (_isEdit) {
        for (final link in _links.where((item) => item.id == null)) {
          await repository.addLink(
            recordId: record.id,
            url: link.url,
            title: link.title.isEmpty ? null : link.title,
            description: link.description.isEmpty ? null : link.description,
          );
        }
      }
      for (final image in _pickedImages) {
        await repository.uploadImage(
          recordId: record.id,
          bytes: await image.readAsBytes(),
          fileName: image.name,
        );
      }
      ref.invalidate(todayRecordsProvider);
      ref.invalidate(recentRecordsProvider);
      ref.invalidate(recordProvider(record.id));
      if (!mounted) return;
      context.go('/records/${record.id}');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_saveErrorText(error))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickImages() async {
    final images = await _picker.pickMultiImage(limit: 5 - _totalImageCount);
    if (images.isEmpty) return;
    setState(() {
      _pickedImages.addAll(images.take(5 - _totalImageCount));
    });
  }

  Future<void> _showLinkDialog() async {
    final draft = await showDialog<_LinkDraft>(
      context: context,
      builder: (context) => _LinkDialog(existingLinks: List.unmodifiable(_links)),
    );

    if (!mounted || draft == null) return;
    setState(() => _links.add(draft));
  }

  void _removeLink(int index) {
    final link = _links[index];
    setState(() {
      if (link.id != null) {
        _deletedAttachmentIds.add(link.id!);
      }
      _links.removeAt(index);
    });
  }

  void _removeExistingImage(int index) {
    final image = _existingImages[index];
    setState(() {
      if (image.id != null) {
        _deletedAttachmentIds.add(image.id!);
      }
      _existingImages.removeAt(index);
    });
  }

  String _saveErrorText(Object error) {
    final message = error.toString();
    if (message.contains('XMLHttpRequest') ||
        message.contains('Connection refused') ||
        message.contains('SocketException')) {
      return '백엔드 API에 연결할 수 없어요. 백엔드를 실행한 뒤 다시 시도해주세요.';
    }
    if (message.contains('이미 추가된 링크입니다')) {
      return '이미 추가된 링크입니다.';
    }
    if (message.contains('지원하지 않는 이미지 형식입니다')) {
      return '지원하지 않는 이미지 형식입니다. JPG, PNG, WebP 파일을 선택해주세요.';
    }
    if (message.length > 140) {
      return '저장하지 못했어요. 입력값과 백엔드 실행 상태를 확인해주세요.';
    }
    return '저장하지 못했어요: $message';
  }

  Future<void> _confirmLeave() async {
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('작성을 그만둘까요?'),
        content: const Text('저장하지 않은 내용은 사라져요.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('나가기')),
        ],
      ),
    );
    if (shouldLeave == true && mounted) {
      if (_isEdit) {
        context.go('/records/${widget.recordId}');
      } else if (_isClone) {
        context.go('/records/${widget.cloneFromRecordId}/clone');
      } else {
        context.go('/home');
      }
    }
  }
}

class _ImageDraftGrid extends StatelessWidget {
  const _ImageDraftGrid({
    required this.existingImages,
    required this.pickedImages,
    required this.onRemoveExisting,
    required this.onRemovePicked,
  });

  final List<_ExistingImageDraft> existingImages;
  final List<XFile> pickedImages;
  final ValueChanged<int> onRemoveExisting;
  final ValueChanged<int> onRemovePicked;

  @override
  Widget build(BuildContext context) {
    final itemCount = existingImages.length + pickedImages.length;
    if (itemCount == 0) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          color: AppColors.surfaceLow,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_photo_alternate_outlined, color: AppColors.outline),
              SizedBox(height: 8),
              Text('사진 추가', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        final existing = index < existingImages.length ? existingImages[index] : null;
        final pickedIndex = index - existingImages.length;
        return Stack(
          children: [
            Container(
              width: double.infinity,
              height: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: BorderRadius.circular(16)),
              child: existing == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.image_outlined, color: AppColors.primary),
                        const SizedBox(height: 6),
                        Text(
                          pickedImages[pickedIndex].name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ],
                    )
                  : _ExistingImageThumb(image: existing),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton.filledTonal(
                tooltip: '사진 삭제',
                onPressed: () => existing == null ? onRemovePicked(pickedIndex) : onRemoveExisting(index),
                icon: const Icon(Icons.close, size: 16),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ExistingImageDraft {
  const _ExistingImageDraft({
    this.id,
    this.title,
    this.thumbnailUrl,
    this.objectKey,
  });

  final int? id;
  final String? title;
  final String? thumbnailUrl;
  final String? objectKey;
}

class _ExistingImageThumb extends StatelessWidget {
  const _ExistingImageThumb({required this.image});

  final _ExistingImageDraft image;

  @override
  Widget build(BuildContext context) {
    if (image.thumbnailUrl == null) {
      return const Icon(Icons.image_outlined, color: AppColors.primary);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        image.thumbnailUrl!,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return const Icon(Icons.image_outlined, color: AppColors.primary);
        },
      ),
    );
  }
}

class _LinkDraft {
  const _LinkDraft({
    this.id,
    required this.url,
    required this.title,
    required this.description,
    required this.type,
    this.thumbnailUrl,
  });

  final int? id;
  final String url;
  final String title;
  final String description;
  final AttachmentType type;
  final String? thumbnailUrl;
}

class _LinkDraftList extends StatelessWidget {
  const _LinkDraftList({
    required this.links,
    required this.onRemove,
  });

  final List<_LinkDraft> links;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    if (links.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: AppColors.surfaceLow, borderRadius: BorderRadius.circular(18)),
        child: const Row(
          children: [
            Icon(Icons.link, color: AppColors.outline),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'YouTube나 외부 레시피 링크를 추가해두세요',
                style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (var index = 0; index < links.length; index++) ...[
          _LinkDraftTile(
            link: links[index],
            onRemove: () => onRemove(index),
          ),
          if (index != links.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _LinkDialog extends ConsumerStatefulWidget {
  const _LinkDialog({required this.existingLinks});

  final List<_LinkDraft> existingLinks;

  @override
  ConsumerState<_LinkDialog> createState() => _LinkDialogState();
}

class _LinkDialogState extends ConsumerState<_LinkDialog> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  AttachmentPreview? _preview;
  bool _previewLoading = false;
  String? _previewError;

  @override
  void dispose() {
    _urlController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('참고 링크 추가'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _urlController,
                  decoration: InputDecoration(
                    labelText: 'URL',
                    hintText: 'https://...',
                    suffixIcon: IconButton(
                      tooltip: '미리보기',
                      onPressed: _previewLoading ? null : _loadPreview,
                      icon: _previewLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.travel_explore),
                    ),
                  ),
                  keyboardType: TextInputType.url,
                  onChanged: (_) {
                    setState(() {
                      _preview = null;
                      _previewError = null;
                    });
                  },
                  validator: _validateUrl,
                ),
                if (_preview != null || _previewError != null) ...[
                  const SizedBox(height: 12),
                  _LinkPreviewBox(preview: _preview, error: _previewError),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: '제목', hintText: '예: 참고한 레시피 영상'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: '메모', hintText: '참고한 부분을 적어두세요'),
                  minLines: 2,
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('취소')),
        FilledButton(
          onPressed: _addLink,
          child: const Text('추가'),
        ),
      ],
    );
  }

  String? _validateUrl(String? value) {
    final url = value?.trim() ?? '';
    final uri = Uri.tryParse(url);
    if (url.isEmpty || uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return '올바른 URL을 입력해주세요';
    }
    if (widget.existingLinks.any((item) => item.url == url)) {
      return '이미 추가된 링크입니다';
    }
    return null;
  }

  Future<void> _loadPreview() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _previewLoading = true;
      _previewError = null;
    });

    try {
      final result = await ref.read(recordsRepositoryProvider).previewLink(_urlController.text.trim());
      if (!mounted) return;
      setState(() {
        _preview = result;
        _previewLoading = false;
        if (_titleController.text.trim().isEmpty && result.title != null) {
          _titleController.text = result.title!;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _preview = null;
        _previewLoading = false;
        _previewError = '미리보기를 가져오지 못했어요. URL은 그대로 저장할 수 있어요.';
      });
    }
  }

  void _addLink() {
    if (!_formKey.currentState!.validate()) return;

    final url = _urlController.text.trim();
    Navigator.of(context).pop(
      _LinkDraft(
        url: url,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        type: _preview?.type ?? _linkType(url),
        thumbnailUrl: _preview?.thumbnailUrl,
      ),
    );
  }

  AttachmentType _linkType(String url) {
    final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
    final isYoutube = host == 'youtu.be' ||
        host == 'www.youtu.be' ||
        host == 'youtube.com' ||
        host.endsWith('.youtube.com');
    return isYoutube ? AttachmentType.youtube : AttachmentType.url;
  }
}

class _LinkPreviewBox extends StatelessWidget {
  const _LinkPreviewBox({this.preview, this.error});

  final AttachmentPreview? preview;
  final String? error;

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.surfaceLow, borderRadius: BorderRadius.circular(14)),
        child: Text(error!, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
      );
    }

    final data = preview;
    if (data == null) return const SizedBox.shrink();
    final isYoutube = data.type == AttachmentType.youtube;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surfaceLow, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          _LinkThumb(thumbnailUrl: data.thumbnailUrl, isYoutube: isYoutube),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title ?? (isYoutube ? 'YouTube 영상' : '참고 링크'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  data.url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkDraftTile extends StatelessWidget {
  const _LinkDraftTile({required this.link, required this.onRemove});

  final _LinkDraft link;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final isYoutube = link.type == AttachmentType.youtube;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surfaceLow, borderRadius: BorderRadius.circular(18)),
      child: Row(
        children: [
          _LinkThumb(thumbnailUrl: link.thumbnailUrl, isYoutube: isYoutube),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  link.title.isEmpty ? (isYoutube ? 'YouTube 링크' : '참고 링크') : link.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  link.url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
                if (link.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    link.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: '링크 삭제',
            onPressed: onRemove,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

class _LinkThumb extends StatelessWidget {
  const _LinkThumb({required this.thumbnailUrl, required this.isYoutube});

  final String? thumbnailUrl;
  final bool isYoutube;

  @override
  Widget build(BuildContext context) {
    if (thumbnailUrl == null) {
      return Icon(isYoutube ? Icons.play_circle : Icons.link, color: isYoutube ? AppColors.error : AppColors.primary);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 52,
        height: 40,
        child: Image.network(
          thumbnailUrl!,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Icon(isYoutube ? Icons.play_circle : Icons.link, color: isYoutube ? AppColors.error : AppColors.primary);
          },
        ),
      ),
    );
  }
}

class _DateBox extends StatelessWidget {
  const _DateBox({required this.date, required this.onTap});

  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            Expanded(child: Text(DateFormat('yyyy.MM.dd').format(date), style: const TextStyle(fontWeight: FontWeight.w800))),
            const Icon(Icons.calendar_today, size: 18),
          ],
        ),
      ),
    );
  }
}

class _FormSection extends StatelessWidget {
  const _FormSection({required this.title, required this.child, this.action});

  final String title;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
            if (action != null) action!,
          ],
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _IngredientRow {
  const _IngredientRow({this.name = '', this.quantity = ''});

  final String name;
  final String quantity;
}

class _IngredientInputs extends StatelessWidget {
  const _IngredientInputs({
    required this.row,
    required this.onChanged,
    this.onRemove,
  });

  final _IngredientRow row;
  final ValueChanged<_IngredientRow> onChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: TextFormField(
              initialValue: row.name,
              decoration: const InputDecoration(hintText: '재료명'),
              onChanged: (value) => onChanged(_IngredientRow(name: value, quantity: row.quantity)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: TextFormField(
              initialValue: row.quantity,
              decoration: const InputDecoration(hintText: '수량'),
              onChanged: (value) => onChanged(_IngredientRow(name: row.name, quantity: value)),
            ),
          ),
          IconButton(
            tooltip: '재료 삭제',
            onPressed: onRemove,
            icon: const Icon(Icons.remove_circle_outline),
          ),
        ],
      ),
    );
  }
}
