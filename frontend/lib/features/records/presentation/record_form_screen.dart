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
  const RecordFormScreen({super.key, this.recordId});

  final int? recordId;

  @override
  ConsumerState<RecordFormScreen> createState() => _RecordFormScreenState();
}

class _RecordFormScreenState extends ConsumerState<RecordFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dishController = TextEditingController();
  final _recipeController = TextEditingController();
  final _memoController = TextEditingController();
  final _linkController = TextEditingController();
  final _ingredients = <_IngredientRow>[const _IngredientRow()];
  final _pickedImages = <XFile>[];
  final _picker = ImagePicker();
  DateTime _date = DateTime.now();
  int? _rating;
  bool _loaded = false;
  bool _saving = false;

  bool get _isEdit => widget.recordId != null;

  @override
  void dispose() {
    _dishController.dispose();
    _recipeController.dispose();
    _memoController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recordValue = _isEdit ? ref.watch(recordProvider(widget.recordId!)) : null;
    if (recordValue != null) {
      recordValue.whenData(_loadRecord);
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(onPressed: _confirmLeave, icon: const Icon(Icons.close)),
        title: Text(_isEdit ? '기록 수정' : '새 요리 기록 작성', style: const TextStyle(fontWeight: FontWeight.w900)),
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
    );
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
              onPressed: _pickedImages.length >= 5 ? null : _pickImages,
              icon: const Icon(Icons.add_a_photo),
              label: const Text('업로드'),
            ),
            child: _PickedImageGrid(
              images: _pickedImages,
              onRemove: (index) => setState(() => _pickedImages.removeAt(index)),
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
            child: TextFormField(
              controller: _linkController,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.link), hintText: 'YouTube 또는 URL'),
              keyboardType: TextInputType.url,
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
    _date = record.cookedDate;
    _rating = record.rating;
    _ingredients
      ..clear()
      ..addAll(
        record.ingredients.isEmpty
            ? [const _IngredientRow()]
            : record.ingredients.map((item) => _IngredientRow(name: item.name, quantity: item.quantity ?? '')),
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
      attachments: _linkController.text.trim().isEmpty
          ? const []
          : [
              RecordAttachment(
                type: AttachmentType.url,
                url: _linkController.text.trim(),
                title: '참고 링크',
              ),
            ],
    );

    try {
      final repository = ref.read(recordsRepositoryProvider);
      final record = _isEdit ? await repository.update(widget.recordId!, draft) : await repository.create(draft);
      for (final image in _pickedImages) {
        await repository.uploadImage(recordId: record.id, path: image.path, fileName: image.name);
      }
      ref.invalidate(todayRecordsProvider);
      ref.invalidate(recentRecordsProvider);
      if (!mounted) return;
      context.go('/records/${record.id}');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('저장하지 못했어요: $error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickImages() async {
    final images = await _picker.pickMultiImage(limit: 5 - _pickedImages.length);
    if (images.isEmpty) return;
    setState(() {
      _pickedImages.addAll(images.take(5 - _pickedImages.length));
    });
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
      context.go('/home');
    }
  }
}

class _PickedImageGrid extends StatelessWidget {
  const _PickedImageGrid({required this.images, required this.onRemove});

  final List<XFile> images;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) {
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
      itemCount: images.length,
      itemBuilder: (context, index) {
        return Stack(
          children: [
            Container(
              width: double.infinity,
              height: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: BorderRadius.circular(16)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.image_outlined, color: AppColors.primary),
                  const SizedBox(height: 6),
                  Text(
                    images[index].name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton.filledTonal(
                tooltip: '사진 삭제',
                onPressed: () => onRemove(index),
                icon: const Icon(Icons.close, size: 16),
              ),
            ),
          ],
        );
      },
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
