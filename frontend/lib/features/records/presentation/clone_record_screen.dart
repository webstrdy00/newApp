import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../data/records_repository.dart';
import 'record_providers.dart';

class CloneRecordScreen extends ConsumerStatefulWidget {
  const CloneRecordScreen({super.key, required this.recordId});

  final int recordId;

  @override
  ConsumerState<CloneRecordScreen> createState() => _CloneRecordScreenState();
}

class _CloneRecordScreenState extends ConsumerState<CloneRecordScreen> {
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final record = ref.watch(recordProvider(widget.recordId));
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(onPressed: () => context.go('/records/${widget.recordId}'), icon: const Icon(Icons.arrow_back)),
        title: const Text('기록 복제', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: record.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('기록을 불러오지 못했어요\n$error')),
        data: (data) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(color: AppColors.surfaceLow, borderRadius: BorderRadius.circular(24)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('원본 기록', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(data.dishName, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(DateFormat('yyyy년 M월 d일').format(data.cookedDate), style: const TextStyle(color: AppColors.textMuted)),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const Text('새 날짜', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: BorderRadius.circular(14)),
                child: Row(
                  children: [
                    Expanded(child: Text(DateFormat('yyyy.MM.dd').format(_date), style: const TextStyle(fontWeight: FontWeight.w800))),
                    const Icon(Icons.calendar_today),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text('원본 기록은 변경되지 않고 새 기록이 생성돼요.', style: TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _saving ? null : _clone,
              icon: const Icon(Icons.copy),
              label: Text(_saving ? '복제 중' : '복제 후 작성하기'),
            ),
          ],
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
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _clone() async {
    setState(() => _saving = true);
    try {
      final record = await ref.read(recordsRepositoryProvider).clone(widget.recordId, _date);
      ref.invalidate(todayRecordsProvider);
      ref.invalidate(recentRecordsProvider);
      if (mounted) context.go('/records/${record.id}');
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('복제하지 못했어요: $error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
